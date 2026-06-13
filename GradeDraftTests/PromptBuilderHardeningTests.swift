import XCTest
@testable import GradeDraft

// MARK: - PromptBuilder hardening

final class PromptBuilderHardeningTests: XCTestCase {
    func testPromptIncludesAnswerKeyWhenProvided() {
        var input = sampleInput()
        input.answerKeyText = "Expected answer: photosynthesis converts CO2."
        let prompt = PromptBuilder.gradingPrompt(input: input)
        XCTAssertTrue(prompt.contains("photosynthesis converts CO2"))
        XCTAssertTrue(prompt.contains("Answer key"))
    }

    func testPromptIncludesExemplarWhenProvided() {
        var input = sampleInput()
        input.exemplarText = "Exemplar: The student should mention both reactants."
        let prompt = PromptBuilder.gradingPrompt(input: input)
        XCTAssertTrue(prompt.contains("Exemplar"))
        XCTAssertTrue(prompt.contains("both reactants"))
    }

    func testPromptIncludesCustomInstructions() {
        var input = sampleInput()
        input.customInstructions = "Be lenient with spelling errors."
        let prompt = PromptBuilder.gradingPrompt(input: input)
        XCTAssertTrue(prompt.contains("lenient with spelling"))
    }

    func testPromptIncludesStructuredCriteriaWhenParsed() {
        let input = sampleInput(rubric: "Claim: 0-4 points\nEvidence: 0-2 points")
        let prompt = PromptBuilder.gradingPrompt(input: input)
        XCTAssertTrue(prompt.contains("Claim"))
        XCTAssertTrue(prompt.contains("Evidence"))
        XCTAssertTrue(prompt.contains("maxPoints"))
    }

    func testPromptShowsFallbackWhenNoCriteria() {
        let input = sampleInput(rubric: "This rubric has no points.")
        let prompt = PromptBuilder.gradingPrompt(input: input)
        XCTAssertTrue(prompt.contains("No structured point-bearing criteria"))
    }

    func testPromptIncludesCurriculumReference() {
        var input = sampleInput()
        input.curriculumReference = "ACELA1234 — Year 7 English literacy standard"
        let prompt = PromptBuilder.gradingPrompt(input: input)
        XCTAssertTrue(prompt.contains("ACELA1234"))
    }

    func testPromptIncludesOCRWarningWhenQualityUncertain() {
        var input = sampleInput()
        input.ocrQualitySummary = OCRQualitySummary(
            lineCount: 5,
            lowConfidenceLineCount: 2,
            unconfirmedLineCount: 3,
            averageConfidence: 0.6
        )
        let prompt = PromptBuilder.gradingPrompt(input: input)
        XCTAssertTrue(prompt.contains("Scanned text quality warning"))
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
