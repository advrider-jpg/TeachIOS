import XCTest
@testable import GradeDraft

// MARK: - FinalGradeReview / FinalCriterionScore edge cases

final class FinalGradeReviewHardeningTests: XCTestCase {
    private func review(_ criteria: [FinalCriterionScore], teacherEdited: Bool) -> FinalGradeReview {
        FinalGradeReview(
            packetFingerprint: "fp",
            criteria: criteria,
            studentFeedback: "", privateTeacherNotes: "", teacherEdited: teacherEdited
        )
    }

    private func criterion(_ id: String, approved: Bool) -> FinalCriterionScore {
        FinalCriterionScore(criterionID: id, rating: "", proposedPoints: 0, finalPoints: 1, explanation: "", teacherApproved: approved)
    }

    func testAllCriteriaApprovedWhenEmpty() {
        XCTAssertFalse(review([], teacherEdited: false).allCriteriaApproved, "Empty criteria should not be 'all approved'")
    }

    func testAllCriteriaApprovedWhenAllApproved() {
        XCTAssertTrue(review([criterion("A", approved: true), criterion("B", approved: true)], teacherEdited: true).allCriteriaApproved)
    }

    func testAllCriteriaApprovedFalseWhenOneUnapproved() {
        XCTAssertFalse(review([criterion("A", approved: true), criterion("B", approved: false)], teacherEdited: true).allCriteriaApproved)
    }

    func testFinalCriterionScoreInitFromDraft() {
        let draft = CriterionScore(
            criterionID: "c-1",
            rating: "Good",
            proposedPoints: 3,
            evidenceQuotes: ["evidence"],
            explanation: "explanation",
            teacherReviewRequired: true,
            title: "Claim",
            maxPoints: 4
        )
        let final = FinalCriterionScore(from: draft)
        XCTAssertEqual(final.criterionID, "c-1")
        XCTAssertEqual(final.title, "Claim")
        XCTAssertEqual(final.proposedPoints, 3)
        XCTAssertEqual(final.finalPoints, 3, "finalPoints should default to proposedPoints")
        XCTAssertEqual(final.maxPoints, 4)
        XCTAssertFalse(final.teacherApproved, "Should not be pre-approved")
        XCTAssertEqual(final.teacherRationale, "Review required by draft.")
    }

    func testFinalCriterionScoreInitFromDraftNoReviewRequired() {
        let draft = CriterionScore(
            criterionID: "c-1",
            rating: "Good",
            proposedPoints: 3,
            evidenceQuotes: ["evidence"],
            explanation: "explanation",
            teacherReviewRequired: false
        )
        let final = FinalCriterionScore(from: draft)
        XCTAssertEqual(final.teacherRationale, "")
    }
}
