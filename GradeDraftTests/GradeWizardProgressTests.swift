import XCTest

@testable import GradeDraft

final class GradeWizardProgressTests: XCTestCase {
    private func blankAssignment() -> AssignmentRecord {
        var assignment = AssignmentRecord()
        assignment.title = ""
        assignment.studentDisplayName = ""
        assignment.rubricText = ""
        assignment.answerKeyText = ""
        assignment.exemplarText = ""
        assignment.reviewedStudentText = ""
        assignment.ocrReviewStatus = .needsReview
        assignment.finalReview = nil
        assignment.exportRecords = []
        return assignment
    }

    func testSetupGate() {
        var assignment = blankAssignment()
        XCTAssertFalse(GradeWizardProgress.isComplete(.setup, for: assignment))
        XCTAssertFalse(GradeWizardProgress.blockingReasons(.setup, for: assignment).isEmpty)
        XCTAssertEqual(GradeWizardProgress.firstIncompleteStep(for: assignment), .setup)

        assignment.title = "Persuasive Essay"
        assignment.studentDisplayName = "Alex"
        XCTAssertTrue(GradeWizardProgress.isComplete(.setup, for: assignment))
        XCTAssertTrue(GradeWizardProgress.blockingReasons(.setup, for: assignment).isEmpty)
    }

    func testStudentWorkAndTextReviewGates() {
        var assignment = blankAssignment()
        XCTAssertFalse(GradeWizardProgress.isComplete(.studentWork, for: assignment))
        assignment.reviewedStudentText = "The school day should be longer."
        XCTAssertTrue(GradeWizardProgress.isComplete(.studentWork, for: assignment))

        // needsReview blocks grading → text review incomplete.
        assignment.ocrReviewStatus = .needsReview
        XCTAssertFalse(GradeWizardProgress.isComplete(.textReview, for: assignment))
        assignment.ocrReviewStatus = .reviewed
        XCTAssertTrue(GradeWizardProgress.isComplete(.textReview, for: assignment))
        assignment.ocrReviewStatus = .notNeeded
        XCTAssertTrue(GradeWizardProgress.isComplete(.textReview, for: assignment))
    }

    func testRubricGate() {
        var assignment = blankAssignment()
        XCTAssertFalse(GradeWizardProgress.isComplete(.rubric, for: assignment))
        assignment.rubricText = "Claim: 0-4 points\nEvidence: 0-3 points"
        XCTAssertTrue(GradeWizardProgress.isComplete(.rubric, for: assignment))
    }

    func testFinalReviewGateRequiresFreshApproval() {
        var assignment = blankAssignment()
        assignment.title = "Essay"
        assignment.studentDisplayName = "Alex"
        assignment.rubricText = "Claim: 0-4 points"
        assignment.reviewedStudentText = "Student response."
        assignment.ocrReviewStatus = .reviewed

        XCTAssertFalse(GradeWizardProgress.isComplete(.finalReview, for: assignment), "No review yet")

        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "Clear work.",
            privateTeacherNotes: "",
            teacherEdited: true
        )
        XCTAssertTrue(GradeWizardProgress.isComplete(.finalReview, for: assignment), "Fresh approved review")

        // A stale fingerprint must make the approval incomplete again.
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: "stale-fingerprint",
            status: .approved,
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "Clear work.",
            privateTeacherNotes: "",
            teacherEdited: true
        )
        XCTAssertFalse(GradeWizardProgress.isComplete(.finalReview, for: assignment), "Stale approved review")
    }

    func testExportGateRequiresStudentFacingExportRecord() {
        var assignment = blankAssignment()
        XCTAssertFalse(GradeWizardProgress.isComplete(.export, for: assignment))
        assignment.exportRecords = [
            ExportRecord(
                exportKind: .studentPDF,
                contentFingerprint: "fp",
                includesPrivateTeacherNotes: false,
                includesOriginalSources: false
            )
        ]
        XCTAssertTrue(GradeWizardProgress.isComplete(.export, for: assignment))
    }

    func testCompletedCountAndOrderedFirstIncomplete() {
        var assignment = blankAssignment()
        XCTAssertEqual(GradeWizardProgress.completedCount(for: assignment), 0)

        assignment.title = "Essay"
        assignment.studentDisplayName = "Alex"
        XCTAssertEqual(GradeWizardProgress.firstIncompleteStep(for: assignment), .studentWork)

        assignment.reviewedStudentText = "Response."
        assignment.ocrReviewStatus = .reviewed
        assignment.rubricText = "Claim: 0-4 points"
        // setup, studentWork, textReview, rubric complete → first incomplete is finalReview.
        XCTAssertEqual(GradeWizardProgress.firstIncompleteStep(for: assignment), .finalReview)
        XCTAssertEqual(GradeWizardProgress.completedCount(for: assignment), 4)
    }

    func testWorkflowTimelineStepIdentityDoesNotUsePosition() {
        let first = WorkflowTimeline.Step(index: 1, title: "Text Review", detail: "Check OCR", status: .needsAttention)
        let reordered = WorkflowTimeline.Step(index: 4, title: "Text Review", detail: "Check OCR", status: .needsAttention)

        XCTAssertEqual(first.id, reordered.id)
        XCTAssertFalse(first.id.contains("1-"))
        XCTAssertFalse(reordered.id.contains("4-"))
    }
}
