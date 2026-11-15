import XCTest
@testable import GradeDraft

extension GradeDraftTests {
    /// The first rubric criterion's ID (rubric criteria are read from the saved assignment).
    fileprivate func firstCriterionID(_ app: AppModel, _ seeded: SeededSubmission) async throws -> String {
        let saved = try await app.requireDatabase().assignmentSetup(id: seeded.assignmentID)
        let setup = try XCTUnwrap(saved)
        return try XCTUnwrap(setup.parsedRubric.criteria.first).id
    }

    /// Saves a final review for the submission. A nil fingerprint means the current grading inputs.
    @discardableResult
    fileprivate func saveReview(
        _ app: AppModel,
        _ seeded: SeededSubmission,
        status: FinalReviewStatus = .inProgress,
        fingerprint: String? = nil,
        criteria: [FinalCriterionScore],
        feedback: String = ""
    ) async throws -> FinalGradeReview {
        let current = try await TestApp.fingerprint(app, seeded)
        let review = FinalGradeReview(
            packetFingerprint: fingerprint ?? current,
            status: status,
            criteria: criteria,
            studentFeedback: feedback,
            privateTeacherNotes: "",
            teacherEdited: true
        )
        try await app.requireDatabase().saveFinalReview(review, submissionID: seeded.submissionID)
        return review
    }

    func testCannotApproveFinalReviewWithUnapprovedCriteria() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Student response")
        let criterion = FinalCriterionScore(
            criterionID: try await firstCriterionID(app, seeded), rating: "Developing", proposedPoints: 3, finalPoints: 3,
            explanation: "Partially met.", teacherApproved: false
        )
        try await saveReview(app, seeded, criteria: [criterion], feedback: "Good.")
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canApproveFinalReview, false)
        await session.approveFinalReview()

        XCTAssertEqual(session.alert?.message, "Approve all final-review criteria before finalizing.")
        let saved = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertEqual(saved?.finalReview?.status, .inProgress)
    }

    func testCannotApproveStaleFinalReview() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Student response")
        let criterion = FinalCriterionScore(
            criterionID: try await firstCriterionID(app, seeded), rating: "Proficient", proposedPoints: 3, finalPoints: 4,
            explanation: "Met.", teacherApproved: true
        )
        try await saveReview(app, seeded, fingerprint: "legacy-packet", criteria: [criterion], feedback: "Good.")
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canApproveFinalReview, false)
        await session.approveFinalReview()

        XCTAssertEqual(session.alert?.message, ReadinessIssue.finalReviewStale.message)
        let saved = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertEqual(saved?.finalReview?.status, .inProgress)
    }

    func testBuiltInTemplateInstructionsIncludeEvidenceSafeguards() {
        let evidenceKeywords = ["evidence", "cite", "teacher review", "teacher review required"]
        for template in RubricTemplates.builtIn {
            let instructions = template.customInstructions.lowercased()
            let hasEvidenceGuard = evidenceKeywords.contains { instructions.contains($0) }
            XCTAssertTrue(hasEvidenceGuard,
                          "Template \(template.id) instructions must reference evidence or teacher review. Got: \(template.customInstructions)")
        }
    }

    func testManualFinalReviewCanStartWithoutAIDraft() async throws {
        let app = try TestApp.make(grading: UnavailableLocalGradingService())
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points\nEvidence: 0-2 points", studentWork: "Student wrote something.")
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertNil(session.graph?.draft, "No AI draft should exist")
        XCTAssertEqual(session.readiness?.canStartFinalReview, true, "Manual review should be available")
        await session.startManualFinalReview()

        XCTAssertEqual(session.review?.status, .inProgress, "Final review should be created")
        let saved = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertNotNil(saved?.finalReview)
    }

    func testManualFinalReviewBlockedWithoutReviewedText() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: nil)
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canStartFinalReview, false, "Manual review blocked without reviewed text")
        await session.startManualFinalReview()

        XCTAssertNil(session.review)
        XCTAssertNotNil(session.alert)
        let saved = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertNil(saved?.finalReview)
    }

    func testManualFinalReviewBlockedByScannedTextNeedingReview() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: nil)
        let line = OCRLine(text: "Student text from OCR", confidence: 0.95, boundingBox: .zero, origin: .visionOCR)
        _ = try await app.requireDatabase().replaceInput(
            submissionID: seeded.submissionID, kind: .scanned, pastedText: nil, sources: [],
            ocr: OCRDocument(pages: [OCRPage(pageIndex: 0, lines: [line])], reviewStatus: .needsReview)
        )
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canStartFinalReview, false, "Manual review blocked when scanned text needs review")
    }

    func testManualFinalReviewBlockedByBlockedScannedText() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: nil)
        let line = OCRLine(text: "Text", confidence: 0.95, boundingBox: .zero, origin: .visionOCR, teacherConfirmed: true)
        _ = try await app.requireDatabase().replaceInput(
            submissionID: seeded.submissionID, kind: .scanned, pastedText: nil, sources: [],
            ocr: OCRDocument(pages: [OCRPage(pageIndex: 0, lines: [line])], reviewStatus: .blocked)
        )
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canStartFinalReview, false, "Manual review blocked when scanned text is blocked")
    }

    func testManualFinalReviewBlockedWithoutGradingStandard() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "", studentWork: "Student text")
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canStartFinalReview, false, "Manual review blocked without any grading standard")
    }

    func testFeedbackRewriteSavesTeacherEditedFinalReviewWithoutApproving() async throws {
        let app = try TestApp.make(grading: ImmediateRewriteGradingService())
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: "Student text")
        let criterion = FinalCriterionScore(
            criterionID: try await firstCriterionID(app, seeded), rating: "Draft", proposedPoints: 1, finalPoints: 1,
            explanation: "Draft explanation."
        )
        try await saveReview(app, seeded, criteria: [criterion], feedback: "Original feedback.")
        let session = try await openSession(app, seeded.submissionID)

        await session.rewriteFeedback(mode: .strengthsNextStep)
        await app.backgroundWork.waitUntilFinished(submissionID: seeded.submissionID)

        XCTAssertNil(session.workFailure)
        let graphSaved = try await app.requireDatabase().submission(id: seeded.submissionID)
        let graph = try XCTUnwrap(graphSaved)
        XCTAssertEqual(graph.finalReview?.studentFeedback, ImmediateRewriteGradingService.rewrittenFeedback)
        XCTAssertEqual(graph.finalReview?.status, .inProgress)
        XCTAssertTrue(graph.finalReview?.teacherEdited == true)
        XCTAssertEqual(graph.audit.last?.eventType, .feedbackRewritten)
    }

    func testManualFinalReviewWithAnswerKeyOnlyCreatesTeacherReviewCriterion() async throws {
        let app = try TestApp.make(grading: UnavailableLocalGradingService())
        let seeded = try await TestApp.seed(app, rubric: "", studentWork: "Student answer here.") { assignment in
            assignment.answerKeyText = "Expected: two specific examples."
        }
        let session = try await openSession(app, seeded.submissionID)

        await session.startManualFinalReview()

        let review = try XCTUnwrap(session.review)
        XCTAssertEqual(review.criteria.count, 1, "One teacher-review criterion expected when no parsed rubric")
        XCTAssertEqual(review.criteria[0].title, "Teacher-entered grading standard")
        XCTAssertFalse(review.criteria[0].teacherApproved)
    }

    func testManualFinalReviewCannotBeApprovedUntilAllCriteriaApproved() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: "Student text.")
        let criterion = FinalCriterionScore(
            criterionID: try await firstCriterionID(app, seeded), rating: "", proposedPoints: 0, finalPoints: 2,
            explanation: "", teacherApproved: false
        )
        try await saveReview(app, seeded, criteria: [criterion])
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canApproveFinalReview, false, "Cannot approve while criterion is unapproved")
    }

    func testAddCriterionToFinalReview() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: "Student text.")
        try await saveReview(app, seeded, criteria: [])
        let session = try await openSession(app, seeded.submissionID)

        session.addCriterion()

        XCTAssertEqual(session.review?.criteria.count, 1, "One criterion should be added")
        XCTAssertEqual(session.review?.criteria[0].teacherApproved, false, "New criterion should not be pre-approved")
    }

    func testDeleteCriterionFromFinalReview() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: "Student text.")
        let criterion = FinalCriterionScore(
            criterionID: try await firstCriterionID(app, seeded), rating: "", proposedPoints: 0, finalPoints: 2,
            explanation: "", teacherApproved: true
        )
        try await saveReview(app, seeded, criteria: [criterion])
        let session = try await openSession(app, seeded.submissionID)

        session.deleteCriterion(criterion.id)

        XCTAssertEqual(session.review?.criteria.count, 0, "Criterion should be deleted")
        XCTAssertEqual(session.review?.totalScore, 0, "Total should recalculate to 0")
    }

    func testApprovalBlockedAfterAddingUnapprovedCriterion() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: "Student text.")
        let approved = FinalCriterionScore(
            criterionID: try await firstCriterionID(app, seeded), rating: "", proposedPoints: 0, finalPoints: 2,
            explanation: "", teacherApproved: true
        )
        try await saveReview(app, seeded, criteria: [approved])
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canApproveFinalReview, true, "Should be approvable before adding unapproved criterion")
        session.addCriterion()
        XCTAssertEqual(session.readiness?.canApproveFinalReview, false, "Should be blocked after adding unapproved criterion")
    }

    func testFinalReviewEvidenceEditRemainsApprovable() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Student text.")
        let database = try app.requireDatabase()
        try await database.replaceDraft(
            GradeDraftResult(
                packetFingerprint: try await TestApp.fingerprint(app, seeded),
                studentResponseSummary: "The student makes a claim.",
                criteria: [CriterionScore(
                    criterionID: try await firstCriterionID(app, seeded), rating: "Proficient", proposedPoints: 3,
                    evidenceQuotes: ["Student text."], explanation: "The claim is clear.", teacherReviewRequired: false
                )],
                studentFeedback: "Good work.",
                teacherNotes: "",
                uncertaintyFlags: []
            ),
            submissionID: seeded.submissionID
        )
        let session = try await openSession(app, seeded.submissionID)
        await session.startFinalReviewFromDraft()
        let criterionID = try XCTUnwrap(session.review?.criteria.first?.id)

        await session.addManualEvidence(quote: "Teacher-observed evidence", to: criterionID)

        XCTAssertEqual(session.readiness?.finalReviewIsStale, false,
                       "Teacher evidence edits during final review must not stale-lock the source fingerprint.")
        XCTAssertEqual(session.readiness?.canApproveFinalReview, false, "Evidence edits require the teacher to re-approve the edited criterion.")
        session.acceptCriterion(criterionID)
        XCTAssertEqual(session.readiness?.canApproveFinalReview, true)
    }

    // MARK: - Gradebook status

    private func gradebookStatus(final status: FinalReviewStatus?, fingerprint: String?) throws -> String {
        let setup = AssignmentSetup(assignment: Assignment(classGroupID: UUID(), title: "Status", rubricText: "Claim: 0-4 points"))
        var graph = SubmissionGraph(
            submission: Submission(assignmentID: setup.id, studentID: UUID(), inputKind: .pasted, pastedText: "text"),
            student: Student(displayName: "Kai")
        )
        if let status {
            graph.finalReview = FinalGradeReview(
                packetFingerprint: try fingerprint ?? graph.packetFingerprint(setup: setup),
                status: status,
                criteria: [FinalCriterionScore(
                    criterionID: setup.parsedRubric.criteria[0].id, rating: "", proposedPoints: 0, finalPoints: 3,
                    explanation: "", teacherApproved: true
                )],
                studentFeedback: "",
                privateTeacherNotes: "",
                teacherEdited: true
            )
        }
        let rows = try CSVParser.parseRows(CSVExportService.gradebookCSV(setup: setup, submissions: [graph]).replacingOccurrences(of: "\u{FEFF}", with: ""))
        return rows[1][2]
    }

    func testGradebookStatusForNoFinalReview() throws {
        XCTAssertEqual(try gradebookStatus(final: nil, fingerprint: nil), "pending_final_review",
                       "Status should be pending_final_review when no final review")
    }

    func testGradebookStatusForApprovedFinalReview() throws {
        XCTAssertEqual(try gradebookStatus(final: .approved, fingerprint: nil), "approved", "Status should be approved")
    }

    func testGradebookStatusForStaleReview() throws {
        XCTAssertEqual(try gradebookStatus(final: .approved, fingerprint: "old-fingerprint"), "stale_review",
                       "Status should be stale_review when fingerprint mismatch")
    }

    // MARK: - Manual review with AI unavailable, and the teacher record's evidence

    func testLocalAIUnavailableDoesNotDisableManualFinalReview() async throws {
        let app = try TestApp.make(grading: UnavailableLocalGradingService())
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: "Student text.")
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canStartFinalReview, true, "Manual review should be available when local AI is unavailable")
    }

    func testTeacherRecordIncludesEvidenceTraceability() throws {
        let setup = AssignmentSetup(assignment: Assignment(classGroupID: UUID(), title: "Audit", rubricText: "Claim: 0-4 points"))
        var graph = SubmissionGraph(
            submission: Submission(assignmentID: setup.id, studentID: UUID(), inputKind: .pasted, pastedText: "Evidence"),
            student: Student(displayName: "Kai")
        )
        graph.evidence = [EvidenceReference(
            submissionID: graph.submission.id,
            ocrLineID: UUID(),
            pageIndex: 0,
            quote: "Evidence",
            boundingBox: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            sourceKind: .ocrLine,
            teacherConfirmed: true
        )]

        let record = MarkdownRenderer.render(ReportBuilder.teacherRecord(setup: setup, submission: graph, generatedAt: Date()))

        XCTAssertTrue(record.contains("Evidence"))
        XCTAssertTrue(record.contains("\"Evidence\" (page 1)"))
        XCTAssertTrue(record.contains("bbox: x:0.1000 y:0.2000 w:0.3000 h:0.4000"))
    }
}
