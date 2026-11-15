import Foundation
import Testing
@testable import GradeDraft

/// Final review editing follows the one autosave rule: typed text and criterion actions edit the same
/// local review and go through the same save, so an action never wipes text that has not been saved yet.
@MainActor
struct FinalReviewTests {
    // T16
    @Test
    func acceptingCriterionKeepsUnsavedFeedback() async throws {
        let app = try FinalReviewFixtures.makeApp()
        let database = try #require(app.database)
        let seeded = try await FinalReviewFixtures.seedInProgressReview(database)

        let session = SubmissionSession(id: seeded.submissionID, app: app)
        let observing = Task { await session.observe() }
        defer { observing.cancel() }
        try await waitFor { session.hasLoaded && session.review != nil }
        let criterionID = try #require(session.review?.criteria.first?.id)

        session.reviewText(\.studentFeedback).wrappedValue = "Clear claim; add one more piece of evidence."
        #expect(session.reviewAutosave.hasPendingChanges)
        #expect(try await database.submission(id: seeded.submissionID)?.finalReview?.studentFeedback.isEmpty == true)

        session.acceptCriterion(criterionID)

        let edited = try #require(session.review)
        #expect(edited.studentFeedback == "Clear claim; add one more piece of evidence.")
        #expect(edited.criteria.first?.teacherApproved == true)
        #expect(edited.criteria.first?.finalPoints == 3)

        try await waitFor { !session.reviewAutosave.holdsLocalEdits }
        let saved = try #require(await database.submission(id: seeded.submissionID)?.finalReview)
        #expect(saved.studentFeedback == "Clear claim; add one more piece of evidence.")
        #expect(saved.criteria.first?.teacherApproved == true)
        #expect(saved.criteria.first?.finalPoints == 3)

        // The observed copy that arrives after the save carries the same text.
        try await waitFor { session.graph?.finalReview?.studentFeedback == saved.studentFeedback }
        #expect(session.review?.studentFeedback == "Clear claim; add one more piece of evidence.")
    }
}

// MARK: - Fixtures

@MainActor
private enum FinalReviewFixtures {
    struct Seeded {
        var submissionID: UUID
    }

    /// An app over an in-memory store. On-device AI is reported unavailable; this test drafts nothing.
    static func makeApp() throws -> AppModel {
        let database = try AppDatabase.inMemory()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FinalReviewTests-\(UUID().uuidString)", isDirectory: true)
        let catalog = CurriculumCatalogService()
        let services = AppServices(
            grading: UnavailableLocalGradingService(),
            budgeter: GradingPromptBudgeter(),
            rubricSuggestions: RubricSuggestionService(),
            curriculumCatalog: catalog,
            curriculumSuggestions: CurriculumSuggestionService(catalog: catalog),
            exportAuthentication: LocalExportAuthenticationService(),
            makeImporter: { storageRoot in SourceImportService(sourcesRoot: storageRoot.appendingPathComponent("Sources", isDirectory: true)) }
        )
        return AppModel(openStorage: { AppModel.Storage(database: database, root: root) }, services: services)
    }

    /// One student with pasted work and an in-progress final review: one rubric criterion, suggested 3 of 4,
    /// not yet accepted, final points 0, empty feedback.
    static func seedInProgressReview(_ database: AppDatabase) async throws -> Seeded {
        let classGroup = ClassGroup(name: "Year 8 English")
        try await database.save(classGroup)
        try await database.save(Student(displayName: "Mia Patel"), enrolledIn: classGroup.id)
        let assignment = Assignment(classGroupID: classGroup.id, title: "Persuasive paragraph", rubricText: "Claim: 0-4 points")
        try await database.createAssignment(assignment)

        let summary = try #require(try await database.submissionSummaries(assignmentID: assignment.id).first)
        _ = try await database.replaceInput(
            submissionID: summary.id, kind: .pasted, pastedText: "School should start later because students learn better when rested.",
            sources: [], ocr: nil
        )
        let setup = try #require(await database.assignmentSetup(id: assignment.id))
        let criterionID = try #require(setup.parsedRubric.criteria.first?.id)
        let graph = try #require(await database.submission(id: summary.id))
        try await database.saveFinalReview(
            FinalGradeReview(
                packetFingerprint: try graph.packetFingerprint(setup: setup),
                criteria: [FinalCriterionScore(criterionID: criterionID, rating: "", proposedPoints: 3, finalPoints: 0, explanation: "")],
                studentFeedback: "",
                privateTeacherNotes: "",
                teacherEdited: false
            ),
            submissionID: summary.id
        )
        return Seeded(submissionID: summary.id)
    }
}

/// Polls until the condition holds, failing after the timeout.
@MainActor
private func waitFor(timeout: Duration = .seconds(5), _ condition: @MainActor () async -> Bool) async throws {
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
