import XCTest
@testable import GradeDraft

// MARK: - FinalGradeReview / FinalCriterionScore edge cases

final class FinalGradeReviewHardeningTests: XCTestCase {
    func testAllCriteriaApprovedWhenEmpty() {
        let review = FinalGradeReview(
            criteria: [],
            totalScore: 0, maxScore: 0,
            studentFeedback: "", privateTeacherNotes: "", teacherEdited: false
        )
        XCTAssertFalse(review.allCriteriaApproved, "Empty criteria should not be 'all approved'")
    }

    func testAllCriteriaApprovedWhenAllApproved() {
        let review = FinalGradeReview(
            criteria: [
                FinalCriterionScore(criterion: "A", rating: "", proposedPoints: 0, finalPoints: 1, maxPoints: 1, evidence: [], explanation: "", teacherApproved: true),
                FinalCriterionScore(criterion: "B", rating: "", proposedPoints: 0, finalPoints: 1, maxPoints: 1, evidence: [], explanation: "", teacherApproved: true)
            ],
            totalScore: 2, maxScore: 2,
            studentFeedback: "", privateTeacherNotes: "", teacherEdited: true
        )
        XCTAssertTrue(review.allCriteriaApproved)
    }

    func testAllCriteriaApprovedFalseWhenOneUnapproved() {
        let review = FinalGradeReview(
            criteria: [
                FinalCriterionScore(criterion: "A", rating: "", proposedPoints: 0, finalPoints: 1, maxPoints: 1, evidence: [], explanation: "", teacherApproved: true),
                FinalCriterionScore(criterion: "B", rating: "", proposedPoints: 0, finalPoints: 1, maxPoints: 1, evidence: [], explanation: "", teacherApproved: false)
            ],
            totalScore: 2, maxScore: 2,
            studentFeedback: "", privateTeacherNotes: "", teacherEdited: true
        )
        XCTAssertFalse(review.allCriteriaApproved)
    }

    func testFinalCriterionScoreInitFromDraft() {
        let draft = CriterionScore(
            criterionID: "c-1",
            criterion: "Claim",
            rating: "Good",
            proposedPoints: 3,
            maxPoints: 4,
            evidence: ["evidence"],
            explanation: "explanation",
            teacherReviewRequired: true
        )
        let final = FinalCriterionScore(from: draft)
        XCTAssertEqual(final.criterionID, "c-1")
        XCTAssertEqual(final.criterion, "Claim")
        XCTAssertEqual(final.proposedPoints, 3)
        XCTAssertEqual(final.finalPoints, 3, "finalPoints should default to proposedPoints")
        XCTAssertEqual(final.maxPoints, 4)
        XCTAssertFalse(final.teacherApproved, "Should not be pre-approved")
        XCTAssertEqual(final.teacherRationale, "Review required by draft.")
    }

    func testFinalCriterionScoreInitFromDraftNoReviewRequired() {
        let draft = CriterionScore(
            criterion: "Claim",
            rating: "Good",
            proposedPoints: 3,
            maxPoints: 4,
            evidence: ["evidence"],
            explanation: "explanation",
            teacherReviewRequired: false
        )
        let final = FinalCriterionScore(from: draft)
        XCTAssertEqual(final.teacherRationale, "")
    }
}
