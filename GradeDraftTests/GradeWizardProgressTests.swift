import XCTest

@testable import GradeDraft

/// The step model on the assignment overview: one assignment, with each student's status.
final class GradeWizardProgressTests: XCTestCase {
    private func blankAssignment() -> Assignment {
        Assignment(classGroupID: UUID(), title: "", rubricText: "", answerKeyText: "", exemplarText: "")
    }

    private func summary(_ status: RosterStatus, for assignment: Assignment) -> SubmissionSummary {
        SubmissionSummary(
            id: UUID(),
            assignmentID: assignment.id,
            assignmentTitle: assignment.title,
            classGroupID: assignment.classGroupID,
            className: "6A",
            studentID: UUID(),
            studentName: "Alex",
            localIdentifier: "",
            rosterOrder: 0,
            rosterStatus: status,
            lastExportedAt: nil,
            updatedAt: Date()
        )
    }

    private func progress(_ assignment: Assignment, _ statuses: [RosterStatus]) -> GradeWizardProgress {
        GradeWizardProgress(assignment: assignment, submissions: statuses.map { summary($0, for: assignment) })
    }

    /// Changed expectation: the setup step is complete once the assignment has a grading standard (rubric,
    /// answer key or exemplar). The title and student name are no longer part of it (the student comes from
    /// the roster), and the separate "rubric" step is merged into setup.
    func testSetupGate() {
        var assignment = blankAssignment()
        XCTAssertFalse(progress(assignment, []).isComplete(.setup))
        XCTAssertEqual(progress(assignment, []).issue(for: .setup), .missingGradingStandard)
        XCTAssertEqual(progress(assignment, []).currentStep, .setup)

        assignment.rubricText = "Claim: 0-4 points\nEvidence: 0-3 points"
        XCTAssertTrue(progress(assignment, []).isComplete(.setup))
        XCTAssertNil(progress(assignment, []).issue(for: .setup))
    }

    func testStudentWorkAndTextReviewGates() {
        var assignment = blankAssignment()
        assignment.rubricText = "Claim: 0-4 points"
        XCTAssertFalse(progress(assignment, [.notStarted]).isComplete(.studentWork))
        XCTAssertEqual(progress(assignment, [.notStarted]).issue(for: .studentWork), .missingStudentWork)
        XCTAssertTrue(progress(assignment, [.readyForGrading]).isComplete(.studentWork))

        // Scanned text that still needs review blocks the scanned-text step; reviewed or pasted work does not.
        XCTAssertFalse(progress(assignment, [.ocrReviewNeeded]).isComplete(.scannedText))
        XCTAssertEqual(progress(assignment, [.ocrReviewNeeded]).issue(for: .scannedText), .scannedTextNotMarkedReviewed)
        XCTAssertTrue(progress(assignment, [.readyForGrading]).isComplete(.scannedText))
    }

    func testFinalReviewGateRequiresFreshApproval() {
        var assignment = blankAssignment()
        assignment.rubricText = "Claim: 0-4 points"

        XCTAssertFalse(progress(assignment, [.draftGenerated]).isComplete(.finalReview), "No review yet")
        XCTAssertFalse(progress(assignment, [.finalReviewInProgress]).isComplete(.finalReview), "Review not approved")
        XCTAssertTrue(progress(assignment, [.approved]).isComplete(.finalReview), "Fresh approved review")

        // A stale approval (the grading inputs changed since) makes the step incomplete again.
        XCTAssertFalse(progress(assignment, [.needsRecheck]).isComplete(.finalReview), "Stale approved review")
        XCTAssertEqual(progress(assignment, [.needsRecheck]).issue(for: .finalReview), .finalReviewStale)
    }

    func testExportGateRequiresExport() {
        var assignment = blankAssignment()
        assignment.rubricText = "Claim: 0-4 points"
        XCTAssertFalse(progress(assignment, [.approved]).isComplete(.export))
        XCTAssertTrue(progress(assignment, [.exported]).isComplete(.export))
    }

    func testStepIsCompleteOnlyWhenEveryStudentHasPassedIt() {
        var assignment = blankAssignment()
        assignment.rubricText = "Claim: 0-4 points"
        XCTAssertTrue(progress(assignment, [.approved, .approved]).isComplete(.finalReview))
        XCTAssertFalse(progress(assignment, [.approved, .draftGenerated]).isComplete(.finalReview))
    }

    func testCompletedCountAndOrderedFirstIncomplete() {
        var assignment = blankAssignment()
        XCTAssertEqual(progress(assignment, []).completedCount, 0)

        assignment.rubricText = "Claim: 0-4 points"
        XCTAssertEqual(progress(assignment, [.notStarted]).currentStep, .studentWork)

        // Setup, student work, scanned text and AI draft are done, so the first incomplete step is final review.
        let drafted = progress(assignment, [.draftGenerated])
        XCTAssertEqual(drafted.currentStep, .finalReview)
        XCTAssertEqual(drafted.completedCount, 4)
    }
}
