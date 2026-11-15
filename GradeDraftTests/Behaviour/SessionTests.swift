import CoreGraphics
import Foundation
import GRDB
import Synchronization
import Testing
@testable import GradeDraft

/// App-state behaviour: slow work saves to the submission it started for, routes to deleted records fail
/// closed, and typing in a setup saves once. Real in-memory store; only the AI and import services are doubles.
@MainActor
struct SessionTests {
    enum SlowTask: String, CaseIterable, Sendable {
        case scan
        case pdfImport
        case draft
        case feedbackRewrite
    }

    // T1
    @Test(arguments: SlowTask.allCases)
    func slowTaskSavesToOriginatingSubmission(kind: SlowTask) async throws {
        let gate = Gate()
        let app = try SessionFixtures.makeApp(
            grading: SuspendedGrading(gate: gate),
            importer: SuspendedImporter(gate: gate)
        )
        let database = try #require(app.database)
        let ids = try await SessionFixtures.seedTwoSubmissions(database)

        let sessionFirst = SubmissionSession(id: ids.first, app: app)
        let observingFirst = Task { await sessionFirst.observe() }
        defer { observingFirst.cancel() }
        try await waitUntil { sessionFirst.hasLoaded }

        switch kind {
        case .scan:
            sessionFirst.importScan([try SessionFixtures.image()])
        case .pdfImport:
            sessionFirst.importPDF(at: FileManager.default.temporaryDirectory.appendingPathComponent("not-read.pdf"))
        case .draft:
            await sessionFirst.prepareAIDraft()
            sessionFirst.startDraft()
        case .feedbackRewrite:
            await sessionFirst.rewriteFeedback(mode: .warmer)
        }
        #expect(sessionFirst.alert == nil)
        try await waitUntil { await gate.hasWaiter }

        let before = try SessionFixtures.encoded(await database.submission(id: ids.second))
        let sessionSecond = SubmissionSession(id: ids.second, app: app)
        let observingSecond = Task { await sessionSecond.observe() }
        defer { observingSecond.cancel() }
        try await waitUntil { sessionSecond.hasLoaded }

        await gate.open()
        await app.backgroundWork.waitUntilFinished(submissionID: ids.first)

        #expect(app.backgroundWork.failures[ids.first] == nil)
        let resultFirst = try #require(await database.submission(id: ids.first))
        switch kind {
        case .scan, .pdfImport:
            #expect(resultFirst.submission.inputKind == .scanned)
            #expect(resultFirst.ocr?.allLines.map(\.rawText) == [SuspendedImporter.recognisedText])
        case .draft:
            #expect(resultFirst.draft?.studentFeedback == SuspendedGrading.draftFeedback)
        case .feedbackRewrite:
            #expect(resultFirst.finalReview?.studentFeedback == SuspendedGrading.rewrittenFeedback)
        }
        let after = try SessionFixtures.encoded(await database.submission(id: ids.second))
        #expect(after == before)
    }

    // T2
    @Test
    func missingRouteShowsNotFoundAndChangesNothing() async throws {
        let app = try SessionFixtures.makeApp(
            grading: SuspendedGrading(gate: Gate(isOpen: true)),
            importer: SuspendedImporter(gate: Gate(isOpen: true))
        )
        let database = try #require(app.database)
        let ids = try await SessionFixtures.seedTwoSubmissions(database)

        let session = SubmissionSession(id: ids.first, app: app)
        let observing = Task { await session.observe() }
        defer { observing.cancel() }
        try await waitUntil { session.hasLoaded }
        let studentID = try #require(session.graph?.student.id)
        let criterionID = try #require(session.review?.criteria.first?.id)

        _ = try await database.deleteStudent(id: studentID)
        try await waitUntil { session.isMissing }
        let before = try await database.backupSnapshot()

        session.importScan([try SessionFixtures.image()])
        session.importPhotos([Data()])
        session.importPDF(at: FileManager.default.temporaryDirectory.appendingPathComponent("not-read.pdf"))
        await session.savePastedText("Replacement work")
        await session.clearStudentWork()
        await session.confirmLine(UUID())
        await session.correctLine(UUID(), text: "Corrected")
        await session.rejectLine(UUID())
        await session.confirmAllConfidentLines()
        await session.markScannedTextReviewed()
        await session.prepareAIDraft()
        session.startDraft()
        session.cancelDraft()
        await session.rewriteFeedback(mode: .warmer)
        await session.startFinalReviewFromDraft()
        await session.startManualFinalReview()
        session.reviewText(\.studentFeedback).wrappedValue = "Edited feedback"
        session.criterionText(criterionID, \.rating).wrappedValue = "Edited rating"
        session.setFinalPoints(1, for: criterionID)
        session.setMaximumPoints(4, for: criterionID)
        session.acceptCriterion(criterionID)
        session.rejectCriterion(criterionID)
        session.addCriterion()
        session.deleteCriterion(criterionID)
        await session.addLineEvidence(lineID: UUID(), to: criterionID)
        await session.addManualEvidence(quote: "A quote", to: criterionID)
        await session.removeEvidence(UUID(), from: criterionID)
        await session.approveFinalReview()
        await session.flushPendingEdits()
        for kind in SubmissionSession.exportKinds {
            await session.prepareExport(kind)
        }

        #expect(session.isMissing)
        #expect(app.backgroundWork.running.isEmpty)
        #expect(session.preparedExport == nil)
        #expect(try await database.backupSnapshot() == before)
    }

    // T15
    @Test
    func typingInSetupSavesOnceAndMarksStaleOnce() async throws {
        let app = try SessionFixtures.makeApp(
            grading: SuspendedGrading(gate: Gate(isOpen: true)),
            importer: SuspendedImporter(gate: Gate(isOpen: true))
        )
        let database = try #require(app.database)
        let ids = try await SessionFixtures.seedTwoSubmissions(database)
        let setup = try #require(await database.assignmentSetup(id: ids.assignmentID))
        let graph = try #require(await database.submission(id: ids.first))
        try await database.replaceDraft(
            GradeDraftResult(
                packetFingerprint: try graph.packetFingerprint(setup: setup),
                studentResponseSummary: "", criteria: [], studentFeedback: "", teacherNotes: "", uncertaintyFlags: []
            ),
            submissionID: ids.first
        )

        let model = AssignmentSetupModel(assignmentID: ids.assignmentID, app: app)
        let observing = Task { await model.observe() }
        defer { observing.cancel() }
        try await waitUntil { model.hasLoaded }

        let writes = WriteCounter()
        let observer = try DatabaseRegionObservation(tracking: Table("assignment")).start(
            in: database.writer,
            onError: { _ in },
            onChange: { _ in writes.increment() }
        )
        defer { observer.cancel() }

        let title = model.text(\.title)
        for index in 0..<40 {
            title.wrappedValue = "Revised title \(index)"
        }
        #expect(model.autosave.hasPendingChanges)
        try await waitUntil { !model.autosave.holdsLocalEdits }
        try await Task.sleep(for: .milliseconds(800))

        #expect(writes.value == 1)
        #expect(try await database.assignmentSetup(id: ids.assignmentID)?.assignment.title == "Revised title 39")
        let audit = try #require(await database.submission(id: ids.first)).audit
        #expect(audit.filter { $0.eventType == .draftMarkedStale }.count == 1)
    }
}

// MARK: - Fixtures

@MainActor
private enum SessionFixtures {
    struct Seeded {
        var assignmentID: UUID
        var first: UUID
        var second: UUID
    }

    static func makeApp(grading: SuspendedGrading, importer: SuspendedImporter) throws -> AppModel {
        let database = try AppDatabase.inMemory()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SessionTests-\(UUID().uuidString)", isDirectory: true)
        let catalog = CurriculumCatalogService()
        let services = AppServices(
            grading: grading,
            budgeter: FixedBudgeter(),
            rubricSuggestions: RubricSuggestionService(),
            curriculumCatalog: catalog,
            curriculumSuggestions: CurriculumSuggestionService(catalog: catalog),
            exportAuthentication: LocalExportAuthenticationService(),
            makeImporter: { _ in importer }
        )
        return AppModel(openStorage: { AppModel.Storage(database: database, root: root) }, services: services)
    }

    /// One class with two students, one assignment (so two submissions, A and B), pasted work for both and
    /// an in-progress final review for both.
    static func seedTwoSubmissions(_ database: AppDatabase) async throws -> Seeded {
        let classGroup = ClassGroup(name: "Year 7 English")
        try await database.save(classGroup)
        try await database.save(Student(displayName: "Student A"), enrolledIn: classGroup.id)
        try await database.save(Student(displayName: "Student B"), enrolledIn: classGroup.id)
        let assignment = Assignment(classGroupID: classGroup.id, title: "Persuasive paragraph", rubricText: "Claim: 0-4 points")
        try await database.createAssignment(assignment)

        let summaries = try await database.submissionSummaries(assignmentID: assignment.id)
        try #require(summaries.count == 2)
        let setup = try #require(await database.assignmentSetup(id: assignment.id))
        let criterionID = try #require(setup.parsedRubric.criteria.first?.id)
        for summary in summaries {
            _ = try await database.replaceInput(
                submissionID: summary.id, kind: .pasted, pastedText: "\(summary.studentName) argues that school should start later.",
                sources: [], ocr: nil
            )
            let graph = try #require(await database.submission(id: summary.id))
            try await database.saveFinalReview(
                FinalGradeReview(
                    packetFingerprint: try graph.packetFingerprint(setup: setup),
                    criteria: [FinalCriterionScore(criterionID: criterionID, rating: "", proposedPoints: 3, finalPoints: 3, explanation: "")],
                    studentFeedback: "Original feedback for \(summary.studentName).",
                    privateTeacherNotes: "",
                    teacherEdited: false
                ),
                submissionID: summary.id
            )
        }
        let byName = Dictionary(summaries.map { ($0.studentName, $0.id) }, uniquingKeysWith: { first, _ in first })
        return Seeded(
            assignmentID: assignment.id,
            first: try #require(byName["Student A"]),
            second: try #require(byName["Student B"])
        )
    }

    static func encoded(_ graph: SubmissionGraph?) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(try #require(graph))
    }

    static func image() throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        return try #require(context.makeImage())
    }
}

/// Polls until the condition holds, failing after the timeout.
@MainActor
private func waitUntil(timeout: Duration = .seconds(5), _ condition: @MainActor () async -> Bool) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !(await condition()) {
        guard clock.now < deadline else {
            Issue.record("Timed out waiting for the expected state.")
            throw CancellationError()
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}

/// Holds suspended service calls until opened.
private actor Gate {
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

private struct SuspendedImporter: SourceImporting {
    static let recognisedText = "Imported for the first student."
    let gate: Gate

    func importScannedImages(_ images: [CGImage], submissionID: UUID) async throws -> ImportedInput {
        await result()
    }

    func importPhotos(_ imageData: [Data], submissionID: UUID) async throws -> ImportedInput {
        await result()
    }

    func importPDF(at url: URL, submissionID: UUID) async throws -> ImportedInput {
        await result()
    }

    private func result() async -> ImportedInput {
        await gate.wait()
        return ImportedInput(
            sources: [],
            ocr: OCRDocument(pages: [
                OCRPage(pageIndex: 0, lines: [
                    OCRLine(text: Self.recognisedText, confidence: 0.95, boundingBox: nil, origin: .visionOCR, paragraphIndex: 0)
                ])
            ])
        )
    }
}

private final class SuspendedGrading: GradingServicing, CapabilityChecking, Sendable {
    static let draftFeedback = "Drafted for the first student."
    static let rewrittenFeedback = "Rewritten for the first student."
    let gate: Gate

    init(gate: Gate) {
        self.gate = gate
    }

    var localAIStatus: LocalAIStatus { .available }
    var supportsCurrentLocale: Bool { true }

    func draftGrade(input: GradingInput, progress: AIGenerationProgressHandler?) async throws -> GradeDraftResult {
        await gate.wait()
        return GradeDraftResult(
            packetFingerprint: input.packetFingerprint,
            studentResponseSummary: "",
            criteria: [],
            studentFeedback: Self.draftFeedback,
            teacherNotes: "",
            uncertaintyFlags: []
        )
    }

    func rewriteFeedback(input: FeedbackRewriteInput, progress: AIGenerationProgressHandler?) async throws -> FeedbackRewriteResult {
        await gate.wait()
        return FeedbackRewriteResult(rewrittenFeedback: Self.rewrittenFeedback, teacherReviewNotes: [])
    }
}

private struct FixedBudgeter: GradingPromptBudgeting {
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

private final class WriteCounter: Sendable {
    private let count = Mutex(0)

    func increment() {
        count.withLock { $0 += 1 }
    }

    var value: Int {
        count.withLock { $0 }
    }
}
