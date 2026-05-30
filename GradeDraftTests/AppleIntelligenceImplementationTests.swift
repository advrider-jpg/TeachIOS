import XCTest
@testable import GradeDraft

final class AppleIntelligenceImplementationTests: XCTestCase {

    func testBuiltInConstraintTemplatesAreCompleteAndUnique() {
        let templates = GradingConstraintTemplates.builtIn
        XCTAssertEqual(templates.count, 11)
        XCTAssertEqual(Set(templates.map(\.id)).count, templates.count)

        let expectedIDs: Set<String> = [
            "general-evidence-first",
            "do-not-penalize-conventions",
            "strict-answer-key",
            "exemplar-comparison",
            "formative-feedback",
            "summative-caution",
            "ocr-uncertainty",
            "eald-sensitive",
            "adjustment-context",
            "off-prompt",
            "misconception"
        ]
        XCTAssertEqual(Set(templates.map(\.id)), expectedIDs)
    }

    func testSensitiveTemplatesAreManualOnlyAndNeverRecommendedAutomatically() {
        let sensitive = GradingConstraintTemplates.builtIn.filter(\.sensitiveContextRequired)
        XCTAssertEqual(Set(sensitive.map(\.id)), ["eald-sensitive", "adjustment-context"])
        XCTAssertTrue(sensitive.allSatisfy { $0.recommendedWhen == .manualOnly })

        var assignment = AssignmentRecord(
            title: "Short answer",
            assessmentPurpose: .summative,
            rubricText: "Claim: 0-4 points",
            answerKeyText: "A correct response includes a clear claim.",
            exemplarText: "The claim is supported by the evidence.",
            reviewedStudentText: "The student includes a clear claim.",
            ocrReviewStatus: .reviewed
        )
        assignment.sourceInputs = [SourceInputRef(sourceType: .photo, fileName: "scan.png", mimeType: "image/png")]

        let recommended = Set(GradingConstraintTemplates.recommendedIDs(for: assignment))
        XCTAssertFalse(recommended.contains("eald-sensitive"))
        XCTAssertFalse(recommended.contains("adjustment-context"))
    }

    func testConstraintTemplateFingerprintParticipatesInAssignmentFingerprint() {
        var assignment = AssignmentRecord(
            title: "Short answer",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "The student includes a clear claim."
        )
        assignment.selectedInstructionTemplateIDs = []
        let originalFingerprint = assignment.gradingPacketFingerprint
        assignment.selectedInstructionTemplateIDs.append("strict-answer-key")
        XCTAssertNotEqual(originalFingerprint, assignment.gradingPacketFingerprint)
    }

    func testPromptBuilderIncludesTemplateTextInInstructionsText() {
        let input = sampleInput(
            selectedTemplateIDs: ["general-evidence-first", "strict-answer-key"],
            answerKey: "The response should include a claim."
        )
        let instructionsText = PromptBuilder.gradingInstructionsText(input: input)
        XCTAssertTrue(instructionsText.contains("Grade only from the reviewed student text"))
        let fullPacketText = PromptBuilder.fullPacketPromptText(input: input, mode: .full)
        XCTAssertTrue(fullPacketText.contains("Use the answer key as the main scoring reference"))
        XCTAssertFalse(fullPacketText.contains("Required JSON schema"))
    }

    func testLocalModelAuditSurvivesDeterministicTotals() {
        let input = sampleInput()
        let audit = LocalModelDraftAudit(
            generationMode: .fullPacket,
            inputPacketFingerprint: input.packetFingerprint,
            promptFingerprint: "prompt-1",
            selectedInstructionTemplateIDs: input.selectedInstructionTemplateIDs,
            selectedInstructionTemplateFingerprint: input.selectedInstructionTemplateFingerprint,
            contextSizeTokens: 4096,
            estimatedOrMeasuredInputTokens: 900,
            reservedOutputTokens: 900,
            criteriaRequested: 1,
            criteriaGenerated: 1,
            usedStructuredRubric: true,
            usedAnswerKey: false,
            usedExemplar: false,
            usedCurriculumReference: false,
            sourceInputCount: input.sourceInputCount,
            ocrReviewStatus: input.ocrReviewStatus,
            ocrQualitySummary: input.ocrQualitySummary
        )
        let draft = GradeDraftResult(
            packetFingerprint: input.packetFingerprint,
            status: .generated,
            studentResponseSummary: "Summary",
            criteria: [CriterionScore(
                criterionID: input.parsedRubric.criteria.first?.id,
                criterion: "Claim",
                rating: "Proficient",
                proposedPoints: 3,
                maxPoints: 4,
                evidence: ["Clear claim"],
                explanation: "The response includes a clear claim.",
                teacherReviewRequired: false
            )],
            totalScore: 999,
            maxScore: 999,
            studentFeedback: "Feedback",
            teacherNotes: "Notes",
            uncertaintyFlags: [],
            localModelAudit: audit
        )

        let normalized = GradeTotals.applyingDeterministicTotals(to: draft)
        XCTAssertEqual(normalized.totalScore, 3)
        XCTAssertEqual(normalized.localModelAudit, audit)
    }

    func testFinalGradeLanguageIsRejectedInStudentFacingFeedback() {
        let input = sampleInput(reviewedText: "Clear claim")
        let draft = validDraft(for: input, studentFeedback: "This is the final grade for the student.")
        XCTAssertThrowsError(try GradeDraftValidator.normalizeAndValidate(draft, input: input)) { error in
            XCTAssertEqual(error as? GradeDraftError, .invalidModelGrade("The model output presented the draft as a final grade."))
        }
    }

    func testFinalGradeLanguageIsAllowedInNegatedContext() throws {
        let input = sampleInput(reviewedText: "Clear claim")
        let draft = validDraft(for: input, studentFeedback: "This is not a final grade — the teacher must review.")
        XCTAssertNoThrow(try GradeDraftValidator.normalizeAndValidate(draft, input: input))
    }

    func testEvidenceWithoutSourceReferenceRequiresTeacherReviewWhenSourceTagsArePresent() throws {
        let input = sampleInput(
            reviewedText: "Clear claim",
            reviewedTextWithSourceRefs: "[p1-l1-abcdef12] Clear claim"
        )
        let draft = validDraft(for: input)
        let normalized = try GradeDraftValidator.normalizeAndValidate(draft, input: input)
        XCTAssertTrue(normalized.criteria[0].teacherReviewRequired)
        XCTAssertTrue(normalized.criteria[0].criterionUncertaintyFlags.joined(separator: " ").contains("source reference missing"))
    }

    func testPromptBudgetPlanSurvivesFullPacketBudget() async throws {
        let input = sampleInput()
        let budgeter = GradingPromptBudgeter(contextSizeTokens: 8192)
        let plan = try await budgeter.plan(input: input)
        XCTAssertEqual(plan.mode, .fullPacket)
    }

    func testPromptBudgetPlanFailsOpenWhenTooLarge() async {
        let input = sampleInput(reviewedText: String(repeating: "A", count: 50_000))
        let budgeter = GradingPromptBudgeter(contextSizeTokens: 1024)
        do {
            _ = try await budgeter.plan(input: input)
        } catch let error as GradeDraftError {
            if case .promptTooLargeForLocalModel = error { return }
            XCTFail("Expected promptTooLargeForLocalModel, got \(error)")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Helpers

    private func validDraft(for input: GradingInput, studentFeedback: String = "The response includes a clear claim.") -> GradeDraftResult {
        GradeDraftResult(
            packetFingerprint: input.packetFingerprint,
            status: .generated,
            studentResponseSummary: "The response includes a clear claim.",
            criteria: [CriterionScore(
                criterionID: input.parsedRubric.criteria.first?.id,
                criterion: "Claim",
                rating: "Proficient",
                proposedPoints: 3,
                maxPoints: 4,
                evidence: ["Clear claim"],
                explanation: "The response includes a clear claim.",
                teacherReviewRequired: false
            )],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: studentFeedback,
            teacherNotes: "Teacher should review before approval.",
            uncertaintyFlags: []
        )
    }

    private func sampleInput(
        selectedTemplateIDs: [String] = [],
        answerKey: String = "",
        reviewedText: String = "Clear claim",
        reviewedTextWithSourceRefs: String = "Clear claim"
    ) -> GradingInput {
        let rubric = "Claim: 0-4 points"
        let parsed = RubricParser.parse(rubric)
        return GradingInput(
            assignmentID: UUID(),
            assignmentTitle: "Short answer",
            prompt: "State a claim.",
            subject: "ELA",
            gradeLevel: "6",
            className: "6A",
            studentDisplayName: "Student A",
            assignmentType: .shortAnswer,
            rubricText: rubric,
            parsedRubric: parsed,
            customInstructions: "",
            selectedInstructionTemplateIDs: selectedTemplateIDs,
            selectedInstructionTemplateText: GradingConstraintTemplates.combinedText(for: selectedTemplateIDs),
            selectedInstructionTemplateFingerprint: GradingConstraintTemplates.fingerprint(for: selectedTemplateIDs),
            answerKeyText: answerKey,
            exemplarText: "",
            assessmentPurpose: .summative,
            curriculumReference: "",
            reviewedStudentText: reviewedText,
            reviewedTextWithSourceRefs: reviewedTextWithSourceRefs,
            ocrQualitySummary: OCRQualitySummary(),
            ocrReviewStatus: .notNeeded,
            sourceInputCount: 1,
            packetFingerprint: "packet-1",
            hasGradingStandard: true
        )
    }
}
