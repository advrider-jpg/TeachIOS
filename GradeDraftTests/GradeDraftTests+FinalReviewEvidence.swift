import XCTest
import ZIPFoundation
@testable import GradeDraft

extension GradeDraftTests {
    func testCannotApproveFinalReviewWithUnapprovedCriteria() {
        let criterion = FinalCriterionScore(
            criterionID: "claim",
            criterion: "Claim",
            rating: "Developing",
            proposedPoints: 3,
            finalPoints: 3,
            maxPoints: 4,
            evidence: ["Evidence"],
            explanation: "Partially met.",
            teacherApproved: false
        )
        let assignment = AssignmentRecord(
            title: "Essay",
            subject: "ELA",
            gradeLevel: "7",
            studentDisplayName: "Kai",
            assignmentType: .essay,
            reviewedStudentText: "Student response",
            latestDraft: nil,
            finalReview: FinalGradeReview(
                packetFingerprint: "packet-1",
                status: .inProgress,
                criteria: [criterion],
                totalScore: 0,
                maxScore: 0,
                studentFeedback: "Good.",
                privateTeacherNotes: "Hidden",
                teacherEdited: true
            )
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canApproveFinalReview)
        viewModel.approveFinalReview()
        XCTAssertEqual(viewModel.errorMessage, "Approve all final-review criteria before finalizing.")
        XCTAssertEqual(viewModel.assignment.finalReview?.status, .inProgress)
    }

    @MainActor
    func testCannotApproveStaleFinalReview() {
        let staleCriterion = FinalCriterionScore(
            criterionID: "claim",
            criterion: "Claim",
            rating: "Proficient",
            proposedPoints: 3,
            finalPoints: 4,
            maxPoints: 4,
            evidence: ["Evidence"],
            explanation: "Met.",
            teacherApproved: true
        )
        let assignment = AssignmentRecord(
            title: "Essay",
            subject: "ELA",
            gradeLevel: "7",
            studentDisplayName: "Kai",
            assignmentType: .essay,
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "Student response",
            finalReview: FinalGradeReview(
                packetFingerprint: "legacy-packet",
                status: .inProgress,
                criteria: [staleCriterion],
                totalScore: 4,
                maxScore: 4,
                studentFeedback: "Good.",
                privateTeacherNotes: "",
                teacherEdited: true
            )
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canApproveFinalReview)
        viewModel.approveFinalReview()
        XCTAssertEqual(viewModel.errorMessage, "Recheck final review because student work, rubric, or evidence changed.")
        XCTAssertEqual(viewModel.assignment.finalReview?.status, .inProgress)
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

    func testManualFinalReviewCanStartWithoutAIDraft() {
        let assignment = AssignmentRecord(
            title: "Short answer",
            rubricText: "Claim: 0-2 points\nEvidence: 0-2 points",
            reviewedStudentText: "Student wrote something."
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            gradingService: UnavailableLocalGradingService(),
            store: store
        )

        XCTAssertNil(viewModel.assignment.latestDraft, "No AI draft should exist")
        XCTAssertTrue(viewModel.canStartManualFinalReview, "Manual review should be available")
        viewModel.startManualFinalReview()
        XCTAssertNotNil(viewModel.assignment.finalReview, "Final review should be created")
        XCTAssertEqual(viewModel.assignment.finalReview?.status, .inProgress)
    }

    func testShortcutManualFinalReviewFailsOpenWhenAssignmentIsNotReady() {
        let assignment = AssignmentRecord(
            title: "Short answer",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: ""
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.handleLaunchRequest(AppLaunchRequest(
            destination: .finalReview,
            assignmentID: assignment.id,
            action: .startManualFinalReview
        ))

        XCTAssertNil(viewModel.assignment.finalReview)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    @MainActor
    func testManualFinalReviewBlockedWithoutReviewedText() {
        let assignment = AssignmentRecord(
            title: "Short answer",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: ""
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canStartManualFinalReview, "Manual review blocked without reviewed text")
    }

    @MainActor
    func testManualFinalReviewBlockedByOCRNeedsReview() {
        let assignment = AssignmentRecord(
            title: "Scanned work",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text from OCR",
            ocrReviewStatus: .needsReview
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canStartManualFinalReview, "Manual review blocked when OCR needs review")
    }

    @MainActor
    func testManualFinalReviewBlockedByOCRBlocked() {
        let assignment = AssignmentRecord(
            title: "Blocked OCR",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Text",
            ocrReviewStatus: .blocked
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canStartManualFinalReview, "Manual review blocked when OCR is blocked")
    }

    @MainActor
    func testManualFinalReviewBlockedWithoutGradingStandard() {
        let assignment = AssignmentRecord(
            title: "No rubric",
            rubricText: "",
            answerKeyText: "",
            exemplarText: "",
            reviewedStudentText: "Student text"
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canStartManualFinalReview, "Manual review blocked without any grading standard")
    }

    @MainActor
    func testFeedbackRewriteSavesTeacherEditedFinalReviewWithoutApproving() async {
        let draft = GradeDraftResult(
            packetFingerprint: "test-packet",
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterion: "Claim",
                    rating: "Draft",
                    proposedPoints: 1,
                    maxPoints: 2,
                    evidence: ["Student text"],
                    explanation: "Draft explanation.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 1,
            maxScore: 2,
            studentFeedback: "Original feedback.",
            teacherNotes: "Private note.",
            uncertaintyFlags: []
        )
        var assignment = AssignmentRecord(
            title: "Rewrite",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text"
        )
        assignment.latestDraft = GradeDraftResult(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: draft.status,
            studentResponseSummary: draft.studentResponseSummary,
            criteria: draft.criteria,
            totalScore: draft.totalScore,
            maxScore: draft.maxScore,
            studentFeedback: draft.studentFeedback,
            teacherNotes: draft.teacherNotes,
            uncertaintyFlags: draft.uncertaintyFlags
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: assignment.latestDraft?.criteria.map(FinalCriterionScore.init(from:)) ?? [],
            totalScore: 1,
            maxScore: 2,
            studentFeedback: "Original feedback.",
            privateTeacherNotes: "Private note.",
            teacherEdited: true
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            gradingService: ImmediateRewriteGradingService(),
            store: store
        )

        await viewModel.rewriteFinalReviewFeedback(mode: .strengthsNextStep)

        XCTAssertEqual(viewModel.assignment.finalReview?.studentFeedback, "The response states a clear claim and can improve by adding one more supporting detail.")
        XCTAssertEqual(viewModel.assignment.finalReview?.status, .inProgress)
        XCTAssertTrue(viewModel.assignment.finalReview?.teacherEdited == true)
        XCTAssertEqual(viewModel.assignment.auditEvents.last?.eventType, .feedbackRewritten)
    }

    @MainActor
    func testManualFinalReviewWithAnswerKeyOnlyCreatesTeacherReviewCriterion() {
        let assignment = AssignmentRecord(
            title: "Short answer",
            rubricText: "",
            answerKeyText: "Expected: two specific examples.",
            reviewedStudentText: "Student answer here."
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            gradingService: UnavailableLocalGradingService(),
            store: store
        )

        viewModel.startManualFinalReview()

        let review = viewModel.assignment.finalReview
        XCTAssertNotNil(review)
        XCTAssertEqual(review?.criteria.count, 1, "One teacher-review criterion expected when no parsed rubric")
        XCTAssertEqual(review?.criteria[0].criterion, "Teacher-entered grading standard")
        XCTAssertFalse(review?.criteria[0].teacherApproved ?? true)
    }

    @MainActor
    func testManualFinalReviewCannotBeApprovedUntilAllCriteriaApproved() {
        var assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text."
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 0,
                finalPoints: 2,
                maxPoints: 2,
                evidence: [],
                explanation: "",
                teacherApproved: false
            )],
            totalScore: 2,
            maxScore: 2,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: true
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canApproveFinalReview, "Cannot approve while criterion is unapproved")
    }

    @MainActor
    func testAddCriterionToFinalReview() {
        var assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text."
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: false
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.addCriterionToFinalReview()
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria.count, 1, "One criterion should be added")
        XCTAssertFalse(viewModel.assignment.finalReview?.criteria[0].teacherApproved ?? true, "New criterion should not be pre-approved")
    }

    @MainActor
    func testDeleteCriterionFromFinalReview() {
        let criterion = FinalCriterionScore(
            criterion: "Claim",
            rating: "",
            proposedPoints: 0,
            finalPoints: 2,
            maxPoints: 2,
            evidence: [],
            explanation: "",
            teacherApproved: true
        )
        var assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text."
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [criterion],
            totalScore: 2,
            maxScore: 2,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: false
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.deleteCriterionFromFinalReview(id: criterion.id)
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria.count, 0, "Criterion should be deleted")
        XCTAssertEqual(viewModel.assignment.finalReview?.totalScore, 0, "Total should recalculate to 0")
    }

    @MainActor
    func testApprovalBlockedAfterAddingUnapprovedCriterion() {
        let approvedCriterion = FinalCriterionScore(
            criterion: "Claim",
            rating: "",
            proposedPoints: 0,
            finalPoints: 2,
            maxPoints: 2,
            evidence: [],
            explanation: "",
            teacherApproved: true
        )
        var assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text."
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [approvedCriterion],
            totalScore: 2,
            maxScore: 2,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: true
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertTrue(viewModel.canApproveFinalReview, "Should be approvable before adding unapproved criterion")
        viewModel.addCriterionToFinalReview()
        XCTAssertFalse(viewModel.canApproveFinalReview, "Should be blocked after adding unapproved criterion")
    }

    @MainActor
    func testFinalReviewEvidenceEditRemainsApprovable() {
        var assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "Student text."
        )
        assignment.latestDraft = GradeDraftResult(
            packetFingerprint: assignment.gradingPacketFingerprint,
            studentResponseSummary: "The student makes a claim.",
            criteria: [CriterionScore(
                criterionID: "claim",
                criterion: "Claim",
                rating: "Proficient",
                proposedPoints: 3,
                maxScore: 4,
                evidence: ["Student text."],
                evidenceSourceRefs: [],
                explanation: "The claim is clear.",
                teacherReviewRequired: false
            )],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "Good work.",
            teacherNotes: "",
            uncertaintyFlags: []
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)
        viewModel.startFinalReviewFromLatestDraft()

        guard let criterionID = viewModel.assignment.finalReview?.criteria.first?.id else {
            XCTFail("Expected final review criterion")
            return
        }
        viewModel.addManualEvidenceToFinalReview(criterionID: criterionID, quote: "Teacher-observed evidence")

        XCTAssertFalse(
            viewModel.assignment.finalReviewIsStale,
            "Teacher evidence edits during final review must not stale-lock the source fingerprint."
        )
        XCTAssertFalse(viewModel.canApproveFinalReview, "Evidence edits require the teacher to re-approve the edited criterion.")
        viewModel.acceptFinalReviewCriterion(id: criterionID)
        XCTAssertTrue(viewModel.canApproveFinalReview)
    }

    func testCSVStatusForNoFinalReview() {
        let assignment = AssignmentRecord(title: "No review", rubricText: "Claim: 0-4 points", reviewedStudentText: "text")
        let rows = CSVExportService.buildStudentRows(from: [assignment])
        let dataRow = rows[1]
        XCTAssertEqual(dataRow[10], "pending_final_review", "Status should be pending_final_review when no final review")
    }

    func testCSVStatusForApprovedFinalReview() {
        var assignment = AssignmentRecord(title: "Approved")
        assignment.rubricText = "Claim: 0-4 points"
        assignment.reviewedStudentText = "text"
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim", rating: "", proposedPoints: 0, finalPoints: 3,
                maxPoints: 4, evidence: [], explanation: "", teacherApproved: true
            )],
            totalScore: 3, maxScore: 4, studentFeedback: "", privateTeacherNotes: "", teacherEdited: true
        )
        let rows = CSVExportService.buildStudentRows(from: [assignment])
        XCTAssertEqual(rows[1][10], "approved", "Status should be approved")
    }

    func testCSVStatusForStaleReview() {
        var assignment = AssignmentRecord(title: "Stale")
        assignment.rubricText = "Claim: 0-4 points"
        assignment.reviewedStudentText = "text"
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: "old-fingerprint",
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim", rating: "", proposedPoints: 0, finalPoints: 3,
                maxPoints: 4, evidence: [], explanation: "", teacherApproved: true
            )],
            totalScore: 3, maxScore: 4, studentFeedback: "", privateTeacherNotes: "", teacherEdited: true
        )
        let rows = CSVExportService.buildStudentRows(from: [assignment])
        XCTAssertEqual(rows[1][10], "stale_review", "Status should be stale_review when fingerprint mismatch")
    }

    // MARK: - Source file cleanup test

    @MainActor
    func testLocalAIUnavailableDoesNotDisableManualFinalReview() {
        let assignment = AssignmentRecord(
            title: "Manual review",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text."
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            gradingService: UnavailableLocalGradingService(),
            store: store
        )
        XCTAssertTrue(viewModel.canStartManualFinalReview, "Manual review should be available when local AI is unavailable")
    }

    // MARK: - scanned text review tests

    @MainActor
    func testTeacherAuditReportIncludesEvidenceTraceability() {
        let lineID = UUID()
        var assignment = AssignmentRecord(title: "Audit", reviewedStudentText: "Evidence")
        assignment.evidenceReferences = [EvidenceReference(
            sourceInputID: UUID(),
            ocrLineID: lineID,
            pageIndex: 0,
            quote: "Evidence",
            startOffset: nil,
            endOffset: nil,
            boundingBox: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            sourceKind: "ocrLine",
            teacherConfirmed: true
        )]
        let audit = MarkdownReportBuilder.teacherAuditMarkdown(for: assignment)
        XCTAssertTrue(audit.contains("Evidence"))
        XCTAssertTrue(audit.contains("bbox"))
    }
}
