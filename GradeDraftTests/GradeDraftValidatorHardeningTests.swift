import XCTest
@testable import GradeDraft

/// What the model proposed, in the form the validator receives it.
enum ProposalFixtures {
    static func criterion(
        id: String,
        points: Double = 3,
        evidence: [String] = ["Student response"],
        title: String? = nil,
        maxPoints: Double? = nil,
        confidence: String = "high",
        teacherReviewRequired: Bool = false
    ) -> ModelCriterionProposal {
        ModelCriterionProposal(
            criterionID: id,
            title: title,
            maxPoints: maxPoints,
            rating: "Good",
            proposedPoints: points,
            evidence: evidence,
            evidenceSourceRefs: [],
            explanation: "Met.",
            nextStep: "",
            confidence: confidence,
            teacherReviewRequired: teacherReviewRequired,
            uncertaintyFlags: []
        )
    }

    static func proposal(
        _ criteria: [ModelCriterionProposal],
        summary: String = "Summary",
        feedback: String = "",
        teacherNotes: String = ""
    ) -> ModelDraftProposal {
        ModelDraftProposal(
            studentResponseSummary: summary,
            criteria: criteria,
            studentFeedback: feedback,
            teacherNotes: teacherNotes,
            uncertaintyFlags: [],
            complianceFlags: []
        )
    }
}

// MARK: - GradeDraftValidator hardening

final class GradeDraftValidatorHardeningTests: XCTestCase {
    func testProhibitedInferenceInSummaryThrows() {
        let input = sampleInput()
        let proposal = ProposalFixtures.proposal(
            [ProposalFixtures.criterion(id: input.parsedRubric.criteria[0].id, evidence: ["Direct quote"])],
            summary: "This student shows great effort and ability",
            feedback: "Good job"
        )
        XCTAssertThrowsError(try GradeDraftValidator.validate(proposal, input: input, audit: nil)) { error in
            XCTAssertEqual(error as? GradeDraftError, .invalidModelGrade("The model output included prohibited inference language."))
        }
    }

    func testProhibitedInferenceInFeedbackThrows() {
        let input = sampleInput()
        let proposal = ProposalFixtures.proposal(
            [ProposalFixtures.criterion(id: input.parsedRubric.criteria[0].id, evidence: ["Quote"])],
            summary: "Summary of work",
            feedback: "The student shows strong motivation and intelligence"
        )
        XCTAssertThrowsError(try GradeDraftValidator.validate(proposal, input: input, audit: nil))
    }

    func testEmptyCriteriaThrows() {
        let input = sampleInput()
        XCTAssertThrowsError(try GradeDraftValidator.validate(ProposalFixtures.proposal([]), input: input, audit: nil)) { error in
            XCTAssertEqual(error as? GradeDraftError, .invalidModelGrade("At least one rubric criterion is required."))
        }
    }

    func testEmptyReviewedTextInInputThrows() {
        var input = sampleInput()
        input.reviewedStudentText = "  "
        let proposal = ProposalFixtures.proposal(
            [ProposalFixtures.criterion(id: input.parsedRubric.criteria[0].id, evidence: ["Quote"])]
        )
        XCTAssertThrowsError(try GradeDraftValidator.validate(proposal, input: input, audit: nil))
    }

    func testDuplicateCriterionIDThrows() {
        let input = sampleInput(rubric: "Claim: 0-2 points\nEvidence: 0-4 points")
        let id = input.parsedRubric.criteria[0].id
        let proposal = ProposalFixtures.proposal([
            ProposalFixtures.criterion(id: id, points: 2, evidence: ["Quote"]),
            ProposalFixtures.criterion(id: id, points: 2, evidence: ["Quote"])
        ])
        XCTAssertThrowsError(try GradeDraftValidator.validate(proposal, input: input, audit: nil))
    }

    /// With no point-bearing rubric the model names each criterion itself; an empty name is rejected.
    func testEmptyCriterionNameThrows() {
        var input = sampleInput(rubric: "")
        input.answerKeyText = "Expected: two specific examples."
        input.hasGradingStandard = true
        let proposal = ProposalFixtures.proposal([
            ProposalFixtures.criterion(id: "model-criterion", points: 3, evidence: ["Quote"], title: "   ", maxPoints: 4)
        ])
        XCTAssertThrowsError(try GradeDraftValidator.validate(proposal, input: input, audit: nil)) { error in
            XCTAssertEqual(error as? GradeDraftError, .invalidModelGrade("A criterion was missing its name."))
        }
    }

    func testEvidenceOutsideReviewedTextFlaggedForReview() throws {
        let input = sampleInput()
        let proposal = ProposalFixtures.proposal([
            ProposalFixtures.criterion(
                id: input.parsedRubric.criteria[0].id,
                evidence: ["This text is NOT in the student response"]
            )
        ])
        let normalized = try GradeDraftValidator.validate(proposal, input: input, audit: nil)
        XCTAssertTrue(normalized.criteria[0].teacherReviewRequired, "Evidence not in reviewed text should flag for review")
    }

    func testMissingEvidenceMarkerIsRecognized() throws {
        let input = sampleInput()
        let proposal = ProposalFixtures.proposal([
            ProposalFixtures.criterion(
                id: input.parsedRubric.criteria[0].id,
                evidence: ["No supporting evidence found."]
            )
        ])
        let normalized = try GradeDraftValidator.validate(proposal, input: input, audit: nil)
        XCTAssertTrue(normalized.criteria[0].teacherReviewRequired, "Missing evidence marker should flag for review")
    }

    func testConfidenceNormalization() throws {
        let input = sampleInput()
        let proposal = ProposalFixtures.proposal([
            ProposalFixtures.criterion(id: input.parsedRubric.criteria[0].id, confidence: "HIGH")
        ])
        let normalized = try GradeDraftValidator.validate(proposal, input: input, audit: nil)
        XCTAssertEqual(normalized.criteria[0].confidence, "high")
    }

    func testUnknownConfidenceDefaultsToMedium() throws {
        let input = sampleInput()
        let proposal = ProposalFixtures.proposal([
            ProposalFixtures.criterion(id: input.parsedRubric.criteria[0].id, confidence: "very confident")
        ])
        let normalized = try GradeDraftValidator.validate(proposal, input: input, audit: nil)
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
