import XCTest
@testable import GradeDraft

// MARK: - GradeTotals edge cases

final class GradeTotalsHardeningTests: XCTestCase {
    func testEmptyCriteriaProducesZeroTotals() {
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [],
            totalScore: 999,
            maxScore: 999,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        let normalized = GradeTotals.applyingDeterministicTotals(to: draft)
        XCTAssertEqual(normalized.totalScore, 0)
        XCTAssertEqual(normalized.maxScore, 0)
    }

    func testNegativeProposedPointsClampedToZero() {
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterion: "Claim",
                    rating: "Poor",
                    proposedPoints: -5,
                    maxPoints: 4,
                    evidence: [],
                    explanation: "",
                    teacherReviewRequired: true
                )
            ],
            totalScore: 999,
            maxScore: 999,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        let normalized = GradeTotals.applyingDeterministicTotals(to: draft)
        XCTAssertEqual(normalized.totalScore, 0, "Negative proposed points should clamp to 0")
        XCTAssertEqual(normalized.maxScore, 4)
    }

    func testNegativeMaxPointsClampedToZeroInDraft() {
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterion: "Claim",
                    rating: "OK",
                    proposedPoints: 2,
                    maxPoints: -1,
                    evidence: [],
                    explanation: "",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 999,
            maxScore: 999,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        let normalized = GradeTotals.applyingDeterministicTotals(to: draft)
        XCTAssertEqual(normalized.maxScore, 0, "Negative maxPoints should clamp to 0")
    }

    func testFinalReviewNegativeFinalPointsClampedToZero() {
        let review = FinalGradeReview(
            packetFingerprint: "p-1",
            criteria: [
                FinalCriterionScore(
                    criterion: "Claim",
                    rating: "",
                    proposedPoints: 0,
                    finalPoints: -3,
                    maxPoints: 4,
                    evidence: [],
                    explanation: "",
                    teacherApproved: true
                )
            ],
            totalScore: 999,
            maxScore: 999,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: true
        )
        let normalized = GradeTotals.applyingDeterministicTotals(to: review)
        XCTAssertEqual(normalized.totalScore, 0, "Negative finalPoints should clamp to 0")
    }

    func testFormattedWholeNumber() {
        XCTAssertEqual(GradeTotals.formatted(4.0), "4")
        XCTAssertEqual(GradeTotals.formatted(0.0), "0")
    }

    func testFormattedDecimalNumber() {
        XCTAssertEqual(GradeTotals.formatted(2.5), "2.5")
        XCTAssertEqual(GradeTotals.formatted(3.33), "3.3")
    }

    func testMultipleCriteriaAggregation() {
        let review = FinalGradeReview(
            packetFingerprint: "p-1",
            criteria: [
                FinalCriterionScore(criterion: "A", rating: "", proposedPoints: 0, finalPoints: 3, maxPoints: 4, evidence: [], explanation: "", teacherApproved: true),
                FinalCriterionScore(criterion: "B", rating: "", proposedPoints: 0, finalPoints: 2, maxPoints: 4, evidence: [], explanation: "", teacherApproved: true),
                FinalCriterionScore(criterion: "C", rating: "", proposedPoints: 0, finalPoints: 4, maxPoints: 4, evidence: [], explanation: "", teacherApproved: true)
            ],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: true
        )
        let normalized = GradeTotals.applyingDeterministicTotals(to: review)
        XCTAssertEqual(normalized.totalScore, 9)
        XCTAssertEqual(normalized.maxScore, 12)
    }
}
