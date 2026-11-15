import CoreGraphics
import Foundation
import XCTest
@testable import GradeDraft

// MARK: - Doubles shared by the XCTest suites in this folder

struct StubExportAuthenticationService: ExportAuthenticationServicing {
    var result: ExportAuthenticationResult
    func authenticateForSensitiveExport(reason: String) async -> ExportAuthenticationResult { result }
}

/// One suggestion per rubric criterion, scored 1 point, quoting the reviewed text.
private func makeTestDraft(for input: GradingInput) -> GradeDraftResult {
    GradeDraftResult(
        packetFingerprint: input.packetFingerprint,
        studentResponseSummary: "Summary",
        criteria: input.parsedRubric.criteria.map { criterion in
            CriterionScore(
                criterionID: criterion.id,
                rating: "Draft",
                proposedPoints: 1,
                evidenceQuotes: [input.reviewedStudentText],
                explanation: "Draft explanation.",
                teacherReviewRequired: false
            )
        },
        studentFeedback: "Draft feedback.",
        teacherNotes: "Teacher review required before final approval.",
        uncertaintyFlags: []
    )
}

final class SlowCancellableGradingService: GradingServicing, CapabilityChecking, Sendable {
    var localAIStatus: LocalAIStatus { .available }
    var supportsCurrentLocale: Bool { true }

    func draftGrade(input: GradingInput, progress: AIGenerationProgressHandler?) async throws -> GradeDraftResult {
        await progress?(
            AIGenerationProgress(
                stage: .requestingModel,
                detail: "Test service is waiting.",
                completedUnitCount: 0,
                totalUnitCount: 1,
                canCancel: true
            )
        )
        try await Task.sleep(nanoseconds: 5_000_000_000)
        try Task.checkCancellation()
        return makeTestDraft(for: input)
    }

    func rewriteFeedback(input: FeedbackRewriteInput, progress: AIGenerationProgressHandler?) async throws -> FeedbackRewriteResult {
        throw CancellationError()
    }
}

final class ImmediateProgressGradingService: GradingServicing, CapabilityChecking, Sendable {
    var localAIStatus: LocalAIStatus { .available }
    var supportsCurrentLocale: Bool { true }

    func draftGrade(input: GradingInput, progress: AIGenerationProgressHandler?) async throws -> GradeDraftResult {
        await progress?(
            AIGenerationProgress(
                stage: .validatingInputs,
                detail: "Inputs checked.",
                canCancel: true
            )
        )
        return makeTestDraft(for: input)
    }

    func rewriteFeedback(input: FeedbackRewriteInput, progress: AIGenerationProgressHandler?) async throws -> FeedbackRewriteResult {
        throw CancellationError()
    }
}

final class ImmediateRewriteGradingService: GradingServicing, CapabilityChecking, Sendable {
    static let rewrittenFeedback = "The response states a clear claim and can improve by adding one more supporting detail."

    var localAIStatus: LocalAIStatus { .available }
    var supportsCurrentLocale: Bool { true }

    func draftGrade(input: GradingInput, progress: AIGenerationProgressHandler?) async throws -> GradeDraftResult {
        try await ImmediateProgressGradingService().draftGrade(input: input, progress: progress)
    }

    func rewriteFeedback(input: FeedbackRewriteInput, progress: AIGenerationProgressHandler?) async throws -> FeedbackRewriteResult {
        await progress?(
            AIGenerationProgress(
                stage: .rewritingFeedback,
                detail: "Rewriting feedback.",
                canCancel: true
            )
        )
        return FeedbackRewriteResult(
            rewrittenFeedback: Self.rewrittenFeedback,
            teacherReviewNotes: ["Review rewritten feedback before export."]
        )
    }
}

/// Plans every packet as a full packet that fits.
struct TestBudgeter: GradingPromptBudgeting {
    func plan(input: GradingInput, after failedMode: LocalModelGenerationMode?) async throws -> PromptBudgetPlan {
        PromptBudgetPlan(
            mode: .fullPacket,
            report: PromptBudgetReport(
                contextSizeTokens: 4096, fullPacketTokens: 600, compactPacketTokens: nil, perCriterionTokenCounts: [:],
                selectedMode: .fullPacket, reservedOutputTokens: 900, promptFingerprint: "test", warnings: []
            )
        )
    }

    func summaryFits(input: GradingInput, criteria: [ModelCriterionProposal]) async throws -> Bool {
        true
    }
}

/// Holds suspended service calls until opened.
actor TestGate {
    private var isOpen: Bool
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(isOpen: Bool = false) {
        self.isOpen = isOpen
    }

    var hasWaiter: Bool { !waiters.isEmpty }

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}

/// An importer that returns one recognised line, or throws. When `writesFiles` is set it also writes the
/// original PDF and one page image under `Sources/<submissionID>/` in the storage folder, as the real
/// importer does, so a test can check that a failed save removes them. `duplicatesSourceID` makes the two
/// source records share an ID, which the store refuses, so the save fails and rolls back.
struct TestImporter: SourceImporting {
    static let recognisedText = "Imported student text."

    var root: URL?
    var gate: TestGate?
    var failure: (any Error)?
    var writesFiles = false
    var duplicatesSourceID = false

    func importScannedImages(_ images: [CGImage], submissionID: UUID) async throws -> ImportedInput {
        try await result(submissionID)
    }

    func importPhotos(_ imageData: [Data], submissionID: UUID) async throws -> ImportedInput {
        try await result(submissionID)
    }

    func importPDF(at url: URL, submissionID: UUID) async throws -> ImportedInput {
        try await result(submissionID)
    }

    private func result(_ submissionID: UUID) async throws -> ImportedInput {
        if let failure { throw failure }
        var sources: [SourceInputRef] = []
        if writesFiles, let root {
            for (index, name) in ["original.pdf", "page-1.png"].enumerated() {
                let relative = "Sources/\(submissionID.uuidString)/\(name)"
                let url = root.appendingPathComponent(relative)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data("bytes of \(name)".utf8).write(to: url)
                sources.append(SourceInputRef(
                    submissionID: submissionID, sourceType: index == 0 ? .pdf : .scan, pageIndex: index == 0 ? nil : 0,
                    localRelativePath: relative, fileName: name
                ))
            }
            if duplicatesSourceID, sources.count == 2 { sources[1].id = sources[0].id }
        }
        await gate?.wait()
        return ImportedInput(
            sources: sources,
            ocr: OCRDocument(pages: [
                OCRPage(pageIndex: 0, lines: [
                    OCRLine(text: Self.recognisedText, confidence: 0.95, boundingBox: nil, origin: .visionOCR, paragraphIndex: 0)
                ])
            ])
        )
    }
}

// MARK: - A real in-memory app

/// One class with one student and one class-level assignment (so one submission).
struct SeededSubmission {
    var classGroupID: UUID
    var studentID: UUID
    var assignmentID: UUID
    var submissionID: UUID
}

@MainActor
enum TestApp {
    /// The real `AppModel` over an in-memory store. Only the AI, import and authentication services are doubles.
    static func make(
        grading: any GradingServicing & CapabilityChecking = ImmediateProgressGradingService(),
        makeImporter: @escaping @Sendable (URL) -> any SourceImporting = { _ in TestImporter() },
        exportAuthentication: any ExportAuthenticationServicing = StubExportAuthenticationService(
            result: ExportAuthenticationResult(allowed: true, authenticationPerformed: false, message: nil)
        )
    ) throws -> AppModel {
        let database = try AppDatabase.inMemory()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftTests-\(UUID().uuidString)", isDirectory: true)
        let catalog = CurriculumCatalogService()
        let services = AppServices(
            grading: grading,
            budgeter: TestBudgeter(),
            rubricSuggestions: RubricSuggestionService(),
            curriculumCatalog: catalog,
            curriculumSuggestions: CurriculumSuggestionService(catalog: catalog),
            exportAuthentication: exportAuthentication,
            makeImporter: makeImporter
        )
        return AppModel(openStorage: { AppModel.Storage(database: database, root: root) }, services: services)
    }

    /// Creates the class, student and assignment; `studentWork` is saved as pasted work when given.
    @discardableResult
    static func seed(
        _ app: AppModel,
        rubric: String = "Claim: 0-4 points",
        studentWork: String? = "Student response",
        configure: (inout Assignment) -> Void = { _ in }
    ) async throws -> SeededSubmission {
        let database = try app.requireDatabase()
        let classGroup = ClassGroup(name: "6A")
        try await database.save(classGroup)
        let student = Student(displayName: "Kai")
        try await database.save(student, enrolledIn: classGroup.id)
        var assignment = Assignment(classGroupID: classGroup.id, title: "Essay", rubricText: rubric)
        configure(&assignment)
        try await database.createAssignment(assignment)
        guard let summary = try await database.submissionSummaries(assignmentID: assignment.id).first else {
            throw AppDatabaseError.notFound(assignment.id)
        }
        if let studentWork {
            _ = try await database.replaceInput(
                submissionID: summary.id, kind: .pasted, pastedText: studentWork, sources: [], ocr: nil
            )
        }
        return SeededSubmission(
            classGroupID: classGroup.id, studentID: student.id, assignmentID: assignment.id, submissionID: summary.id
        )
    }

    /// The submission's current grading-input fingerprint, for building a current draft or final review.
    static func fingerprint(_ app: AppModel, _ seeded: SeededSubmission) async throws -> String {
        let database = try app.requireDatabase()
        guard let graph = try await database.submission(id: seeded.submissionID),
              let setup = try await database.assignmentSetup(id: seeded.assignmentID) else {
            throw AppDatabaseError.notFound(seeded.submissionID)
        }
        return try graph.packetFingerprint(setup: setup)
    }
}

/// Polls until the condition holds, failing the test after the timeout.
@MainActor
func waitForCondition(
    timeout: Duration = .seconds(5),
    _ condition: @MainActor () async -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !(await condition()) {
        guard clock.now < deadline else {
            XCTFail("Timed out waiting for the expected state.")
            throw CancellationError()
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}

extension XCTestCase {
    /// A session over the submission, observing until the test ends. Returns once it has loaded.
    @MainActor
    func openSession(_ app: AppModel, _ submissionID: UUID) async throws -> SubmissionSession {
        let session = SubmissionSession(id: submissionID, app: app)
        let observing = Task { await session.observe() }
        addTeardownBlock { observing.cancel() }
        try await waitForCondition { session.hasLoaded }
        return session
    }

    /// Waits until the session has caught up with the saved submission (after an action that saves).
    @MainActor
    func waitForSession(_ session: SubmissionSession, _ app: AppModel) async throws {
        let database = try app.requireDatabase()
        try await waitForCondition {
            guard let saved = try? await database.submission(id: session.id) else { return false }
            return session.graph == saved && (session.reviewAutosave.holdsLocalEdits || session.review == saved.finalReview)
        }
    }

    @MainActor
    func openSetupModel(_ app: AppModel, _ assignmentID: UUID) async throws -> AssignmentSetupModel {
        let model = AssignmentSetupModel(assignmentID: assignmentID, app: app)
        let observing = Task { await model.observe() }
        addTeardownBlock { observing.cancel() }
        try await waitForCondition { model.hasLoaded }
        return model
    }
}

// MARK: - Shared input

@MainActor
final class GradeDraftTests: XCTestCase {
    func sampleInput(rubric: String = "Claim: 0-4 points") -> GradingInput {
        let parsed = RubricParser.parse(rubric)
        return GradingInput(
            assignmentID: UUID(),
            assignmentTitle: "Essay",
            prompt: "",
            subject: "ELA",
            gradeLevel: "6",
            className: "6A",
            studentDisplayName: "Student A",
            assignmentType: .essay,
            rubricText: rubric,
            parsedRubric: parsed,
            customInstructions: "",
            answerKeyText: "",
            exemplarText: "",
            assessmentPurpose: .summative,
            curriculumReference: "",
            reviewedStudentText: "Student response",
            reviewedTextWithSourceRefs: "Student response",
            ocrQualitySummary: OCRQualitySummary(),
            ocrReviewStatus: .notNeeded,
            sourceInputCount: 1,
            packetFingerprint: "packet-1",
            hasGradingStandard: !rubric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }
}
