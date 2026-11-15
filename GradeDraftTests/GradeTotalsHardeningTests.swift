import XCTest
@testable import GradeDraft

// MARK: - Totals edge cases

final class GradeTotalsHardeningTests: XCTestCase {
    private func sampleInput(rubric: String) -> GradingInput {
        GradingInput(
            assignmentID: UUID(),
            assignmentTitle: "Essay",
            prompt: "",
            subject: "ELA",
            gradeLevel: "6",
            className: "6A",
            studentDisplayName: "Student A",
            assignmentType: .essay,
            rubricText: rubric,
            parsedRubric: RubricParser.parse(rubric),
            customInstructions: "",
            answerKeyText: "",
            exemplarText: "",
            assessmentPurpose: .summative,
            curriculumReference: "",
            reviewedStudentText: "Student response",
            reviewedTextWithSourceRefs: "Student response",
            ocrQualitySummary: OCRQualitySummary(),
            ocrReviewStatus: .notNeeded,
            sourceInputCount: 1,
            packetFingerprint: "packet-1",
            hasGradingStandard: true
        )
    }

    func testEmptyCriteriaProducesZeroTotals() {
        let draft = GradeDraftResult(
            packetFingerprint: "p-1",
            studentResponseSummary: "Summary",
            criteria: [],
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        let review = FinalGradeReview(
            packetFingerprint: "p-1", criteria: [], studentFeedback: "", privateTeacherNotes: "", teacherEdited: false
        )
        XCTAssertEqual(draft.totalScore, 0)
        XCTAssertEqual(review.totalScore, 0)
    }

    func testNegativeProposedPointsClampedToZero() throws {
        let input = sampleInput(rubric: "Claim: 0-4 points")
        let proposal = ProposalFixtures.proposal([
            ProposalFixtures.criterion(id: input.parsedRubric.criteria[0].id, points: -5, evidence: [], teacherReviewRequired: true)
        ])
        let normalized = try GradeDraftValidator.validate(proposal, input: input, audit: nil)
        XCTAssertEqual(normalized.totalScore, 0, "Negative proposed points should clamp to 0")
        XCTAssertEqual(normalized.criteria[0].proposedPoints, 0)
    }

    /// The model-supplied maximum is only used when there is no point-bearing rubric. A negative maximum is
    /// no longer clamped to 0; the validator rejects the draft (changed expectation, see the porting report).
    func testNegativeModelMaxPointsRejected() {
        var input = sampleInput(rubric: "")
        input.answerKeyText = "Expected: a clear claim."
        let proposal = ProposalFixtures.proposal([
            ProposalFixtures.criterion(id: "model-claim", points: 2, evidence: [], title: "Claim", maxPoints: -1)
        ])
        XCTAssertThrowsError(try GradeDraftValidator.validate(proposal, input: input, audit: nil)) { error in
            XCTAssertEqual(error as? GradeDraftError, .invalidModelGrade("Claim had a negative maximum score."))
        }
    }

    /// Negative final points are no longer clamped inside the total; they block approval until corrected.
    func testFinalReviewNegativeFinalPointsBlockApproval() throws {
        let setup = AssignmentSetup(assignment: Assignment(classGroupID: UUID(), title: "Essay", rubricText: "Claim: 0-4 points"))
        var graph = SubmissionGraph(
            submission: Submission(assignmentID: setup.id, studentID: UUID(), inputKind: .pasted, pastedText: "Student text"),
            student: Student(displayName: "Kai")
        )
        graph.finalReview = FinalGradeReview(
            packetFingerprint: try graph.packetFingerprint(setup: setup),
            criteria: [
                FinalCriterionScore(
                    criterionID: setup.parsedRubric.criteria[0].id, rating: "", proposedPoints: 0, finalPoints: -3,
                    explanation: "", teacherApproved: true
                )
            ],
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: true
        )

        let readiness = AssignmentReadiness(setup: setup, submission: graph, aiStatus: .available, aiReport: nil)

        XCTAssertTrue(readiness.approvalIssues.contains(.scoreOutOfRange), "Negative finalPoints must block approval")
        XCTAssertFalse(readiness.canApproveFinalReview)
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
        // No point-bearing rubric: each criterion carries its own title and maximum.
        let setup = AssignmentSetup(assignment: Assignment(classGroupID: UUID(), title: "Essay", answerKeyText: "Key"))
        let review = FinalGradeReview(
            packetFingerprint: "p-1",
            criteria: [
                FinalCriterionScore(criterionID: "a", rating: "", proposedPoints: 0, finalPoints: 3, explanation: "", teacherApproved: true, title: "A", maxPoints: 4),
                FinalCriterionScore(criterionID: "b", rating: "", proposedPoints: 0, finalPoints: 2, explanation: "", teacherApproved: true, title: "B", maxPoints: 4),
                FinalCriterionScore(criterionID: "c", rating: "", proposedPoints: 0, finalPoints: 4, explanation: "", teacherApproved: true, title: "C", maxPoints: 4)
            ],
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: true
        )
        XCTAssertEqual(review.totalScore, 9)
        XCTAssertEqual(review.criteria.compactMap { AssignmentReadiness.maximumPoints(for: $0, setup: setup) }.reduce(0, +), 12)
    }
}
