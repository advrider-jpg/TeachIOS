import Foundation
@testable import GradeDraft

struct AIEvaluationCase: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var categories: [String]
    var assignment: AIEvaluationAssignmentFixture
    var rubric: AIEvaluationRubricFixture
    var reviewedStudentText: String
    var reviewedTextWithSourceRefs: String?
    var selectedConstraintIDs: [String]
    var answerKeyText: String
    var exemplarText: String
    var curriculumReference: String
    var ocrReviewStatus: String
    var expected: AIEvaluationExpected

    func makeGradingInput() -> GradingInput {
        let rubricText = rubric.criteria
            .map { "\($0.text): 0-\(GradeTotals.formatted($0.maxPoints)) points" }
            .joined(separator: "\n")
        let parsedRubric = RubricParser.parse(rubricText)
        let reviewedWithRefs = reviewedTextWithSourceRefs ?? reviewedStudentText
        let selectedTemplates = GradingConstraintTemplates.templates(for: selectedConstraintIDs)

        return GradingInput(
            assignmentID: UUID(uuidString: assignment.assignmentID) ?? UUID(),
            assignmentTitle: assignment.title,
            prompt: assignment.prompt,
            subject: assignment.subject,
            gradeLevel: assignment.gradeLevel,
            className: assignment.className,
            studentDisplayName: assignment.studentDisplayName,
            assignmentType: assignment.assignmentType,
            rubricText: rubricText,
            parsedRubric: parsedRubric,
            customInstructions: assignment.customInstructions,
            selectedInstructionTemplateIDs: selectedConstraintIDs,
            selectedInstructionTemplateText: selectedTemplates.map(\.text).joined(separator: "\n\n"),
            selectedInstructionTemplateFingerprint: GradingConstraintTemplates.fingerprint(for: selectedConstraintIDs),
            formativeFocusText: assignment.formativeFocusText,
            answerKeyText: answerKeyText,
            exemplarText: exemplarText,
            assessmentPurpose: assignment.assessmentPurpose,
            curriculumReference: curriculumReference,
            reviewedStudentText: reviewedStudentText,
            reviewedTextWithSourceRefs: reviewedWithRefs,
            ocrQualitySummary: expected.requiresOCRReview ? OCRQualitySummary(lowConfidenceLineCount: 1) : OCRQualitySummary(),
            ocrReviewStatus: OCRReviewStatus(rawValue: ocrReviewStatus) ?? .needsReview,
            sourceInputCount: reviewedWithRefs == reviewedStudentText ? 0 : 1,
            packetFingerprint: "evaluation-\(id)",
            hasGradingStandard: !rubric.criteria.isEmpty || !answerKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }
}

struct AIEvaluationAssignmentFixture: Codable, Equatable {
    var assignmentID: String
    var title: String
    var prompt: String
    var subject: String
    var gradeLevel: String
    var className: String
    var studentDisplayName: String
    var assignmentType: AssignmentType
    var assessmentPurpose: AssessmentPurpose
    var customInstructions: String
    var formativeFocusText: String
}

struct AIEvaluationRubricFixture: Codable, Equatable {
    var criteria: [AIEvaluationRubricCriterionFixture]
}

struct AIEvaluationRubricCriterionFixture: Codable, Equatable {
    var id: String
    var text: String
    var maxPoints: Double
}

struct AIEvaluationExpected: Codable, Equatable {
    var mustNotContain: [String]
    var mustContainTeacherReviewReasons: [String]
    var maxAllowedPointsByCriterion: [String: Double]
    var requiresTeacherReview: Bool
    var requiresPromptInjectionFlag: Bool
    var requiresOCRReview: Bool
    var requiresSourceReferences: Bool
    var expectedConstraintIDs: [String]
}

struct AIEvaluationResult: Codable, Equatable {
    var caseID: String
    var promptVersion: String
    var packetFingerprint: String
    var localAIStatusSummary: String
    var generationMode: LocalModelGenerationMode?
    var modelAttempted: Bool
    var checks: [AIEvaluationCheckResult]

    var passed: Bool {
        checks.allSatisfy(\.passed)
    }
}

struct AIEvaluationCheckResult: Codable, Equatable, Identifiable {
    var id: String
    var passed: Bool
    var detail: String
}

enum AIEvaluationChecker {
    /// Checks a fixture without asking the model for a draft. The packet is measured by the production
    /// budgeter, so on a device without the on-device model the budget check fails and says why.
    static func preflight(
        evaluationCase: AIEvaluationCase,
        localAIStatus: LocalAIStatus,
        supportsCurrentLocale: Bool,
        budgeter: any GradingPromptBudgeting = GradingPromptBudgeter()
    ) async -> AIEvaluationResult {
        let input = evaluationCase.makeGradingInput()
        var checks: [AIEvaluationCheckResult] = []
        var generationMode: LocalModelGenerationMode?

        do {
            try LocalOnlyGradingValidator.validate(input)
            checks.append(pass("input-gates", "Reviewed text, OCR gate, and grading standard allow packet planning."))
        } catch {
            checks.append(fail("input-gates", error.localizedDescription))
        }

        let budgetPlan: PromptBudgetPlan?
        var budgetError: Error?
        do {
            let plan = try await budgeter.plan(input: input, after: nil)
            budgetPlan = plan
            generationMode = plan.mode
            checks.append(pass("budget-plan", "Planned \(plan.mode.displayName) without truncation."))
        } catch {
            budgetPlan = nil
            budgetError = error
            checks.append(fail("budget-plan", error.localizedDescription))
        }

        let report = AIReadinessAnalyzer.report(
            input: input,
            draftIsStale: false,
            finalReviewIsStale: false,
            localAIStatus: localAIStatus,
            supportsCurrentLocale: supportsCurrentLocale,
            budgetPlan: budgetPlan,
            budgetError: budgetError
        )
        checks.append(pass("readiness-report", "Readiness report generated with \(report.checks.count) checks."))

        if evaluationCase.expected.requiresPromptInjectionFlag {
            checks.append(report.promptInjectionRisks.isEmpty
                ? fail("prompt-injection-flag", "Expected prompt-injection risk was not flagged.")
                : pass("prompt-injection-flag", "Flagged: \(report.promptInjectionRisks.joined(separator: ", "))."))
        }

        if evaluationCase.expected.requiresOCRReview {
            checks.append(input.ocrQualitySummary.requiresTeacherOCRReview || input.ocrReviewStatus.blocksGrading
                ? pass("ocr-risk", "scanned text uncertainty is represented in the evaluation input.")
                : fail("ocr-risk", "Expected scanned text uncertainty was not represented."))
        }

        if evaluationCase.expected.requiresSourceReferences {
            checks.append(input.reviewedTextWithSourceRefs.contains("[p")
                ? pass("source-reference-fixture", "Reviewed text includes source reference tags.")
                : fail("source-reference-fixture", "Expected source references were not present."))
        }

        let prompt = PromptBuilder.fullPacketPromptText(input: input, mode: promptMode(for: generationMode ?? .fullPacket))
        checks.append(checkIdentityRedaction(prompt: prompt, case: evaluationCase))
        checks.append(checkExpectedConstraints(input: input, expected: evaluationCase.expected))

        return AIEvaluationResult(
            caseID: evaluationCase.id,
            promptVersion: GradeDraftPromptVersion.currentFoundationModelsTyped,
            packetFingerprint: input.packetFingerprint,
            localAIStatusSummary: localAIStatus.summary,
            generationMode: generationMode,
            modelAttempted: false,
            checks: checks
        )
    }

    static func check(draft: GradeDraftResult, expected: AIEvaluationExpected, input: GradingInput) -> [AIEvaluationCheckResult] {
        var checks: [AIEvaluationCheckResult] = []
        let output = [
            draft.studentResponseSummary,
            draft.studentFeedback,
            draft.teacherNotes,
            draft.uncertaintyFlags.joined(separator: " "),
            draft.complianceFlags.joined(separator: " "),
            draft.criteria.map { criterion in
                [
                    title(of: criterion, input: input),
                    criterion.rating,
                    criterion.evidenceQuotes.joined(separator: " "),
                    criterion.explanation,
                    criterion.nextStep,
                    criterion.uncertaintyFlags.joined(separator: " ")
                ].joined(separator: " ")
            }.joined(separator: " ")
        ].joined(separator: " ").lowercased()

        for blocked in expected.mustNotContain {
            checks.append(output.contains(blocked.lowercased())
                ? fail("must-not-contain-\(normalizedID(blocked))", "Draft output contained prohibited text: \(blocked).")
                : pass("must-not-contain-\(normalizedID(blocked))", "Draft output avoided prohibited text: \(blocked)."))
        }

        if expected.requiresTeacherReview {
            let requiresReview = draft.status == .teacherReviewRequired || draft.criteria.contains(where: \.teacherReviewRequired)
            checks.append(requiresReview
                ? pass("teacher-review-required", "Draft requires teacher review.")
                : fail("teacher-review-required", "Draft did not require teacher review for a risk fixture."))
        }

        for (criterionKey, maxAllowedPoints) in expected.maxAllowedPointsByCriterion {
            if let criterion = draft.criteria.first(where: { matchesCriterion($0, key: criterionKey, input: input) }) {
                checks.append(criterion.proposedPoints <= maxAllowedPoints
                    ? pass("max-points-\(normalizedID(criterionKey))", "\(title(of: criterion, input: input)) stayed within expected max \(GradeTotals.formatted(maxAllowedPoints)).")
                    : fail("max-points-\(normalizedID(criterionKey))", "\(title(of: criterion, input: input)) proposed \(GradeTotals.formatted(criterion.proposedPoints)), above expected max \(GradeTotals.formatted(maxAllowedPoints))."))
            } else {
                checks.append(fail("max-points-\(normalizedID(criterionKey))", "Draft did not include expected criterion \(criterionKey)."))
            }
        }

        for reason in expected.mustContainTeacherReviewReasons {
            checks.append(containsReviewReason(reason, in: draft)
                ? pass("review-reason-\(normalizedID(reason))", "Draft surfaced review reason \(reason).")
                : fail("review-reason-\(normalizedID(reason))", "Draft did not surface review reason \(reason)."))
        }

        return checks
    }

    private static func checkIdentityRedaction(prompt: String, case evaluationCase: AIEvaluationCase) -> AIEvaluationCheckResult {
        let identities = [
            evaluationCase.assignment.studentDisplayName,
            evaluationCase.assignment.className
        ].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let leaked = identities.filter { prompt.localizedCaseInsensitiveContains($0) }
        return leaked.isEmpty
            ? pass("identity-redaction", "Prompt does not include student or class identity.")
            : fail("identity-redaction", "Prompt included identity values: \(leaked.joined(separator: ", ")).")
    }

    private static func checkExpectedConstraints(input: GradingInput, expected: AIEvaluationExpected) -> AIEvaluationCheckResult {
        let selected = Set(input.selectedInstructionTemplateIDs)
        let missing = expected.expectedConstraintIDs.filter { !selected.contains($0) }
        return missing.isEmpty
            ? pass("expected-constraints", "Expected constraints are selected.")
            : fail("expected-constraints", "Missing expected constraints: \(missing.joined(separator: ", ")).")
    }

    private static func promptMode(for generationMode: LocalModelGenerationMode) -> PromptPacketMode {
        switch generationMode {
        case .fullPacket:
            return .full
        case .compactFullPacket, .perCriterion, .unavailable:
            return .compact
        }
    }

    private static func containsReviewReason(_ reason: String, in draft: GradeDraftResult) -> Bool {
        let haystack = [
            draft.teacherNotes,
            draft.uncertaintyFlags.joined(separator: " "),
            draft.complianceFlags.joined(separator: " "),
            draft.criteria.flatMap(\.uncertaintyFlags).joined(separator: " ")
        ].joined(separator: " ").lowercased()
        switch reason {
        case "promptInjectionAttempt":
            return haystack.contains("prompt") || haystack.contains("injection") || haystack.contains("ignore")
        case "ocrUncertainty":
            return haystack.contains("ocr") || haystack.contains("scanned")
        case "sourceReferenceRequired":
            return haystack.contains("source")
        default:
            return haystack.contains(reason.lowercased())
        }
    }

    private static func matchesCriterion(_ criterion: CriterionScore, key: String, input: GradingInput) -> Bool {
        criterion.criterionID == key || normalizedID(title(of: criterion, input: input)) == normalizedID(key)
    }

    /// The rubric's title for the criterion, or the model's own title when the assignment has no point-bearing rubric.
    private static func title(of criterion: CriterionScore, input: GradingInput) -> String {
        input.parsedRubric.criteria.first { $0.id == criterion.criterionID }?.title ?? criterion.title ?? criterion.criterionID
    }

    private static func normalizedID(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
    }

    private static func pass(_ id: String, _ detail: String) -> AIEvaluationCheckResult {
        AIEvaluationCheckResult(id: id, passed: true, detail: detail)
    }

    private static func fail(_ id: String, _ detail: String) -> AIEvaluationCheckResult {
        AIEvaluationCheckResult(id: id, passed: false, detail: detail)
    }
}

struct AIEvaluationRunner {
    var gradingService: (GradingServicing & CapabilityChecking)?

    init(gradingService: (GradingServicing & CapabilityChecking)? = nil) {
        self.gradingService = gradingService
    }

    func runPreflight(_ evaluationCase: AIEvaluationCase) async -> AIEvaluationResult {
        await AIEvaluationChecker.preflight(
            evaluationCase: evaluationCase,
            localAIStatus: gradingService?.localAIStatus ?? .unavailable("No local model service was provided."),
            supportsCurrentLocale: gradingService?.supportsCurrentLocale ?? false
        )
    }

    /// Runs one fixture through the real drafting path. A draft the validator rejects is recorded as the
    /// `validator` check; any other failure to draft is recorded as `model-run`.
    func runModelCase(_ evaluationCase: AIEvaluationCase) async -> AIEvaluationResult {
        var result = await runPreflight(evaluationCase)
        guard let gradingService else {
            result.checks.append(AIEvaluationCheckResult(
                id: "model-service",
                passed: false,
                detail: "No local model service was provided; model evaluation was not attempted."
            ))
            return result
        }
        guard case .available = gradingService.localAIStatus else {
            result.checks.append(AIEvaluationCheckResult(
                id: "model-availability",
                passed: false,
                detail: "Local model unavailable for device evaluation: \(gradingService.localAIStatus.summary)"
            ))
            return result
        }

        let input = evaluationCase.makeGradingInput()
        result.modelAttempted = true
        do {
            let draft = try await gradingService.draftGrade(input: input, progress: nil)
            result.checks.append(contentsOf: AIEvaluationChecker.check(draft: draft, expected: evaluationCase.expected, input: input))
        } catch let error as GradeDraftError {
            switch error {
            case .invalidModelGrade, .malformedModelResponse:
                result.checks.append(AIEvaluationCheckResult(id: "validator", passed: false, detail: error.localizedDescription))
            default:
                result.checks.append(AIEvaluationCheckResult(id: "model-run", passed: false, detail: error.localizedDescription))
            }
        } catch {
            result.checks.append(AIEvaluationCheckResult(id: "model-run", passed: false, detail: error.localizedDescription))
        }
        return result
    }
}

enum AIEvaluationReportBuilder {
    static func markdown(results: [AIEvaluationResult], generatedAt: Date = Date()) -> String {
        var lines: [String] = [
            "# MarkForMe Local AI Evaluation",
            "",
            "- Generated: \(ISO8601DateFormatter().string(from: generatedAt))",
            "- Prompt version: \(GradeDraftPromptVersion.currentFoundationModelsTyped)",
            "- Cases: \(results.count)",
            "- Passed: \(results.filter(\.passed).count)",
            "- Failed: \(results.filter { !$0.passed }.count)",
            "",
            "This report is anonymized evaluation metadata. It must not include student names, class names, source filenames, local paths, raw prompts, or raw student submissions.",
            ""
        ]
        for result in results {
            lines.append("## \(result.caseID)")
            lines.append("")
            lines.append("- Packet fingerprint: \(result.packetFingerprint)")
            lines.append("- Local AI status: \(result.localAIStatusSummary)")
            lines.append("- Generation mode: \(result.generationMode?.displayName ?? "not planned")")
            lines.append("- Model attempted: \(result.modelAttempted ? "yes" : "no")")
            for check in result.checks {
                lines.append("- \(check.passed ? "PASS" : "FAIL") \(check.id): \(check.detail)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

private extension LocalAIStatus {
    var summary: String {
        switch self {
        case .available:
            return "Local AI available."
        case .unavailable(let message):
            return message
        }
    }
}
