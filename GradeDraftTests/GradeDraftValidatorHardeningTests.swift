import XCTest
@testable import GradeDraft

// MARK: - GradeDraftValidator hardening

final class GradeDraftValidatorHardeningTests: XCTestCase {
    func testProhibitedInferenceInSummaryThrows() {
        let input = sampleInput()
        let draft = GradeDraftResult(
            studentResponseSummary: "This student shows great effort and ability",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria[0].id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["Direct quote"],
                    explanation: "Met claim.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "Good job",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        XCTAssertThrowsError(try GradeDraftValidator.normalizeAndValidate(draft, input: input)) { error in
            XCTAssertEqual(error as? GradeDraftError, .invalidModelGrade("The model output included prohibited inference language."))
        }
    }

    func testProhibitedInferenceInFeedbackThrows() {
        let input = sampleInput()
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary of work",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria[0].id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["Quote"],
                    explanation: "Met claim.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "The student shows strong motivation and intelligence",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        XCTAssertThrowsError(try GradeDraftValidator.normalizeAndValidate(draft, input: input))
    }

    func testEmptyCriteriaThrows() {
        let input = sampleInput()
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        XCTAssertThrowsError(try GradeDraftValidator.normalizeAndValidate(draft, input: input)) { error in
            XCTAssertEqual(error as? GradeDraftError, .invalidModelGrade("At least one rubric criterion is required."))
        }
    }

    func testEmptyReviewedTextInInputThrows() {
        var input = sampleInput()
        input.reviewedStudentText = "  "
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria[0].id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["Quote"],
                    explanation: "Met.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        XCTAssertThrowsError(try GradeDraftValidator.normalizeAndValidate(draft, input: input))
    }

    func testDuplicateCriterionIDThrows() {
        let input = sampleInput(rubric: "Claim: 0-2 points\nEvidence: 0-4 points")
        let id = input.parsedRubric.criteria[0].id
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 2,
                    maxPoints: 2,
                    evidence: ["Quote"],
                    explanation: "Met.",
                    teacherReviewRequired: false
                ),
                CriterionScore(
                    criterionID: id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 2,
                    maxPoints: 2,
                    evidence: ["Quote"],
                    explanation: "Met.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 4,
            maxScore: 4,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        XCTAssertThrowsError(try GradeDraftValidator.normalizeAndValidate(draft, input: input))
    }

    func testEmptyCriterionNameThrows() {
        let input = sampleInput()
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria[0].id,
                    criterion: "   ",
                    rating: "Good",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["Quote"],
                    explanation: "Met.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        XCTAssertThrowsError(try GradeDraftValidator.normalizeAndValidate(draft, input: input))
    }

    func testEvidenceOutsideReviewedTextFlaggedForReview() throws {
        let input = sampleInput()
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria[0].id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["This text is NOT in the student response"],
                    explanation: "Met.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        let normalized = try GradeDraftValidator.normalizeAndValidate(draft, input: input)
        XCTAssertTrue(normalized.criteria[0].teacherReviewRequired, "Evidence not in reviewed text should flag for review")
    }

    func testMissingEvidenceMarkerIsRecognized() throws {
        let input = sampleInput()
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria[0].id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["No supporting evidence found."],
                    explanation: "Met.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        let normalized = try GradeDraftValidator.normalizeAndValidate(draft, input: input)
        XCTAssertTrue(normalized.criteria[0].teacherReviewRequired, "Missing evidence marker should flag for review")
    }

    func testConfidenceNormalization() throws {
        let input = sampleInput()
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria[0].id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["Student response"],
                    explanation: "Met.",
                    teacherReviewRequired: false,
                    confidence: "HIGH"
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        let normalized = try GradeDraftValidator.normalizeAndValidate(draft, input: input)
        XCTAssertEqual(normalized.criteria[0].confidence, "high")
    }

    func testUnknownConfidenceDefaultsToMedium() throws {
        let input = sampleInput()
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria[0].id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["Student response"],
                    explanation: "Met.",
                    teacherReviewRequired: false,
                    confidence: "very confident"
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        let normalized = try GradeDraftValidator.normalizeAndValidate(draft, input: input)
        XCTAssertEqual(normalized.criteria[0].confidence, "medium")
    }

    private func sampleInput(rubric: String = "Claim: 0-4 points") -> GradingInput {
        let parsed = RubricParser.parse(rubric)
        return GradingInput(
            assignmentID: UUID(),
            assignmentTitle: "Essay",
            prompt: "",
            subject: "ELA",
            gradeLevel: "6",
            className: "6A",
            studentDisplayName: "Student A",
            assignmentType: .essay,
            rubricText: rubric,
            parsedRubric: parsed,
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
            hasGradingStandard: !rubric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }
}
