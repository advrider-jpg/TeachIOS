import XCTest
@testable import GradeDraft

// MARK: - Per-route model hardening tests (sessions and setup models over a real in-memory store)

@MainActor
final class ViewModelHardeningTests: XCTestCase {
    private func scannedDocument(_ lines: [OCRLine]) -> OCRDocument {
        OCRDocument(pages: [OCRPage(pageIndex: 0, lines: lines)])
    }

    private func currentDraft(_ app: AppModel, _ seeded: SeededSubmission) async throws -> GradeDraftResult {
        let setupSaved = try await app.requireDatabase().assignmentSetup(id: seeded.assignmentID)
        let setup = try XCTUnwrap(setupSaved)
        return GradeDraftResult(
            packetFingerprint: try await TestApp.fingerprint(app, seeded),
            studentResponseSummary: "Summary",
            criteria: [CriterionScore(
                criterionID: setup.parsedRubric.criteria[0].id,
                rating: "Good",
                proposedPoints: 3,
                evidenceQuotes: ["Quote"],
                explanation: "Met.",
                teacherReviewRequired: false
            )],
            studentFeedback: "Good",
            teacherNotes: "Notes",
            uncertaintyFlags: []
        )
    }

    private func finalReview(
        _ app: AppModel,
        _ seeded: SeededSubmission,
        finalPoints: Double,
        approved: Bool = true,
        status: FinalReviewStatus = .inProgress
    ) async throws -> FinalGradeReview {
        let setupSaved = try await app.requireDatabase().assignmentSetup(id: seeded.assignmentID)
        let setup = try XCTUnwrap(setupSaved)
        return FinalGradeReview(
            packetFingerprint: try await TestApp.fingerprint(app, seeded),
            status: status,
            criteria: [FinalCriterionScore(
                criterionID: setup.parsedRubric.criteria[0].id, rating: "", proposedPoints: 0, finalPoints: finalPoints,
                explanation: "", teacherApproved: approved
            )],
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: true
        )
    }

    func testRosterFileImportCreatesAStudentAndSubmissionForEachName() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, studentWork: nil)
        let database = try app.requireDatabase()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("roster-\(UUID().uuidString).csv")
        try Data("Alice\nBob\nCharlie".utf8).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let model = RosterModel(classGroupID: seeded.classGroupID, app: app)

        model.previewRosterFile(at: url)
        XCTAssertEqual(model.rosterPreview?.rows.map(\.displayName), ["Alice", "Bob", "Charlie"])
        await model.confirmRosterImport()

        XCTAssertNil(model.alert)
        XCTAssertEqual(model.lastImportResult?.imported, 3)
        let submissions = try await database.submissionSummaries(assignmentID: seeded.assignmentID)
        XCTAssertEqual(submissions.count, 4, "The original student plus 3 roster students each get a submission")
    }

    func testEmptyRosterReportsThatTheRosterIsEmpty() {
        let (rows, result) = RosterImportService.parse(text: "")
        XCTAssertTrue(rows.isEmpty)
        XCTAssertEqual(result.skippedRows, ["The roster is empty."])
    }

    /// Changed expectation: confirming the last unresolved line no longer marks the scanned text reviewed by
    /// itself; the teacher marks it reviewed explicitly, and that works once no line needs action.
    func testConfirmingTheOnlyLowConfidenceLineAllowsMarkingScannedTextReviewed() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, studentWork: nil)
        let database = try app.requireDatabase()
        let line = OCRLine(text: "line", confidence: 0.4, boundingBox: .zero, origin: .visionOCR)
        _ = try await database.replaceInput(
            submissionID: seeded.submissionID, kind: .scanned, pastedText: nil, sources: [], ocr: scannedDocument([line])
        )
        let session = try await openSession(app, seeded.submissionID)

        await session.confirmLine(line.id)
        try await waitForSession(session, app)
        XCTAssertEqual(session.graph?.ocr?.unresolvedLineCount, 0)
        await session.markScannedTextReviewed()

        let graph = try await database.submission(id: seeded.submissionID)
        XCTAssertEqual(graph?.ocr?.allLines.first?.teacherConfirmed, true)
        XCTAssertEqual(graph?.ocr?.reviewStatus, .reviewed)
        XCTAssertNil(session.alert)
    }

    func testUpdateOCRLineChangesReviewStatus() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: nil)
        let database = try app.requireDatabase()
        let line = OCRLine(text: "Extracted text", confidence: 0.95, boundingBox: .zero, origin: .visionOCR, teacherConfirmed: true)
        _ = try await database.replaceInput(
            submissionID: seeded.submissionID, kind: .scanned, pastedText: nil, sources: [], ocr: scannedDocument([line])
        )
        try await database.setOCRReviewStatus(.reviewed, submissionID: seeded.submissionID)
        let session = try await openSession(app, seeded.submissionID)

        await session.correctLine(line.id, text: "Corrected text")

        let graph = try await database.submission(id: seeded.submissionID)
        XCTAssertEqual(graph?.ocr?.reviewStatus, .needsReview, "Editing OCR should reset to needsReview")
    }

    func testRejectOCRLineKeepsTheLineButExcludesItFromReviewedText() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, studentWork: nil)
        let database = try app.requireDatabase()
        let rejected = OCRLine(text: "line1", confidence: 0.95, boundingBox: .zero, origin: .visionOCR)
        let kept = OCRLine(text: "line2", confidence: 0.95, boundingBox: .zero, origin: .visionOCR, teacherConfirmed: true)
        _ = try await database.replaceInput(
            submissionID: seeded.submissionID, kind: .scanned, pastedText: nil, sources: [], ocr: scannedDocument([rejected, kept])
        )
        let session = try await openSession(app, seeded.submissionID)

        await session.rejectLine(rejected.id)

        let graphSaved = try await database.submission(id: seeded.submissionID)
        let graph = try XCTUnwrap(graphSaved)
        XCTAssertEqual(graph.ocr?.pages[0].lines.count, 2, "Rejected line metadata should be preserved for traceability")
        XCTAssertEqual(graph.ocr?.pages[0].lines[0].isRejected, true)
        XCTAssertFalse(graph.reviewedText.contains("line1"), "Rejected line text should be excluded from reviewed text")
        XCTAssertTrue(graph.reviewedText.contains("line2"))
    }

    /// Changed expectation: applying a rubric template no longer deletes the draft and final review; they stay
    /// on record and are marked as needing recheck, because their grading inputs no longer match.
    func testApplyTemplateMarksDraftAndFinalReviewStale() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Old rubric: 0-2 points", studentWork: "text")
        let database = try app.requireDatabase()
        try await database.replaceDraft(try await currentDraft(app, seeded), submissionID: seeded.submissionID)
        try await database.saveFinalReview(try await finalReview(app, seeded, finalPoints: 1), submissionID: seeded.submissionID)
        let model = try await openSetupModel(app, seeded.assignmentID)
        let template = RubricTemplates.builtIn[0]

        await model.applyRubricTemplate(template)

        let setupSaved = try await database.assignmentSetup(id: seeded.assignmentID)
        let setup = try XCTUnwrap(setupSaved)
        let graphSaved = try await database.submission(id: seeded.submissionID)
        let graph = try XCTUnwrap(graphSaved)
        XCTAssertEqual(setup.assignment.rubricText, template.rubricText)
        XCTAssertTrue(try graph.draftIsStale(setup: setup), "Applying a template should make the draft stale")
        XCTAssertTrue(try graph.finalReviewIsStale(setup: setup), "Applying a template should make the final review stale")
    }

    func testSavingPastedStudentTextReplacesScannedWork() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, studentWork: nil)
        let database = try app.requireDatabase()
        let line = OCRLine(text: "OCR", confidence: 0.9, boundingBox: .zero, origin: .visionOCR)
        _ = try await database.replaceInput(
            submissionID: seeded.submissionID, kind: .scanned, pastedText: nil, sources: [], ocr: scannedDocument([line])
        )
        let session = try await openSession(app, seeded.submissionID)

        await session.savePastedText("New pasted text")

        let graphSaved = try await database.submission(id: seeded.submissionID)
        let graph = try XCTUnwrap(graphSaved)
        XCTAssertEqual(graph.reviewedText, "New pasted text")
        XCTAssertEqual(graph.submission.inputKind, .pasted)
        XCTAssertNil(graph.ocr, "Pasted text should clear the scanned text")
    }

    func testCannotApproveFinalReviewWithOutOfRangeScore() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "text")
        try await app.requireDatabase().saveFinalReview(try await finalReview(app, seeded, finalPoints: 5), submissionID: seeded.submissionID)
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canApproveFinalReview, false, "Out-of-range scores should block approval")
        await session.approveFinalReview()

        XCTAssertEqual(session.alert?.message, ReadinessIssue.scoreOutOfRange.message)
        let saved = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertEqual(saved?.finalReview?.status, .inProgress)
    }

    func testCannotApproveFinalReviewWithEmptyCriteria() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "text")
        try await app.requireDatabase().saveFinalReview(
            FinalGradeReview(
                packetFingerprint: try await TestApp.fingerprint(app, seeded),
                criteria: [], studentFeedback: "", privateTeacherNotes: "", teacherEdited: false
            ),
            submissionID: seeded.submissionID
        )
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canApproveFinalReview, false, "Empty criteria should block approval")
        XCTAssertTrue(session.readiness?.approvalIssues.contains(.finalReviewHasNoCriteria) == true)
    }

    func testChangingTheRubricMarksTheDraftStale() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "text")
        let database = try app.requireDatabase()
        try await database.replaceDraft(try await currentDraft(app, seeded), submissionID: seeded.submissionID)
        let model = try await openSetupModel(app, seeded.assignmentID)

        model.edit { $0.assignment.rubricText = "Evidence: 0-2 points" }
        await model.flushPendingEdits()

        let setupSaved = try await database.assignmentSetup(id: seeded.assignmentID)
        let setup = try XCTUnwrap(setupSaved)
        let graphSaved = try await database.submission(id: seeded.submissionID)
        let graph = try XCTUnwrap(graphSaved)
        XCTAssertNotNil(graph.draft, "The draft stays on record")
        XCTAssertTrue(try graph.draftIsStale(setup: setup), "Draft should be stale after an input change")
    }

    func testReadinessIncludesLocalAIUnavailable() async throws {
        let app = try TestApp.make(grading: UnavailableLocalGradingService())
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "text")
        let session = try await openSession(app, seeded.submissionID)

        let issues = try XCTUnwrap(session.readiness?.draftIssues)
        XCTAssertTrue(issues.contains { $0.message.lowercased().contains("unavailable") })
    }

    func testStudentReportBlockedWhenNoFinalReview() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "text")
        let session = try await openSession(app, seeded.submissionID)

        await session.prepareExport(.studentMarkdown)

        XCTAssertNotNil(session.alert)
        XCTAssertNil(session.preparedExport)
    }

    func testStartFinalReviewFromCurrentDraft() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "text")
        try await app.requireDatabase().replaceDraft(try await currentDraft(app, seeded), submissionID: seeded.submissionID)
        let session = try await openSession(app, seeded.submissionID)

        await session.startFinalReviewFromDraft()

        let review = try XCTUnwrap(session.review)
        XCTAssertEqual(review.status, .inProgress)
        XCTAssertEqual(review.criteria.count, 1)
        XCTAssertFalse(review.criteria[0].teacherApproved)
    }

    func testNewAssignmentFromTemplate() async throws {
        let app = try TestApp.make()
        let classIDSaved = await app.addClass(name: "6A")
        let classID = try XCTUnwrap(classIDSaved)
        let assignmentIDSaved = await app.createAssignment(title: "From template", classGroupID: classID)
        let assignmentID = try XCTUnwrap(assignmentIDSaved)
        let model = try await openSetupModel(app, assignmentID)
        let template = RubricTemplates.builtIn[0]

        await model.applyRubricTemplate(template)

        XCTAssertEqual(model.setup?.assignment.rubricText, template.rubricText)
        let saved = try await app.requireDatabase().assignmentSetup(id: assignmentID)
        XCTAssertEqual(saved?.assignment.rubricText, template.rubricText)
    }

    func testNewAssignmentWithoutTemplate() async throws {
        let app = try TestApp.make()
        let classIDSaved = await app.addClass(name: "6A")
        let classID = try XCTUnwrap(classIDSaved)
        let database = try app.requireDatabase()
        let before = try await database.assignmentSummaries(inClass: nil).count

        _ = await app.createAssignment(title: "Blank assignment", classGroupID: classID)

        let after = try await database.assignmentSummaries(inClass: nil).count
        XCTAssertEqual(after, before + 1)
    }

    /// A route to a deleted assignment shows not-found and changes nothing (the per-submission version of this
    /// is `SessionTests.missingRouteShowsNotFoundAndChangesNothing`).
    func testMissingAssignmentRouteBlocksSetupActions() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Original rubric: 0-4 points", studentWork: "Original reviewed text")
        let database = try app.requireDatabase()
        let model = try await openSetupModel(app, seeded.assignmentID)
        await app.deleteAssignment(id: seeded.assignmentID)
        try await waitForCondition { model.isMissing }
        let before = try await database.backupSnapshot()

        await model.applyRubricTemplate(RubricTemplates.builtIn[0])
        model.toggleConstraintTemplate(GradingConstraintTemplates.builtIn[0].id)
        model.edit { $0.assignment.rubricText = "Wrong rubric: 0-1 points" }
        model.previewRubric(text: "Claim: 0-4 points")
        await model.addMapping(itemID: "acara-test-item")
        await model.flushPendingEdits()
        await model.prepareGradebookCSV()

        XCTAssertTrue(model.isMissing)
        XCTAssertNil(model.rubricPreview)
        XCTAssertNil(model.preparedExport)
        let after = try await database.backupSnapshot()
        XCTAssertEqual(after, before)
    }
}
