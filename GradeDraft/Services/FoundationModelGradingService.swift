import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

final class FoundationModelGradingService: GradingServicing, CapabilityChecking, Sendable {
    private let budgeter: GradingPromptBudgeting

    init(budgeter: GradingPromptBudgeting = GradingPromptBudgeter()) {
        self.budgeter = budgeter
    }

    var localAIStatus: LocalAIStatus {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                return .unavailable(Self.message(for: reason))
            @unknown default:
                return .unavailable("The on-device language model is unavailable for an unknown reason.")
            }
        } else {
            return .unavailable("Foundation Models requires a newer operating system.")
        }
        #else
        return .unavailable("This build was compiled without the Foundation Models framework.")
        #endif
    }

    func draftGrade(input: GradingInput) async throws -> GradeDraftResult {
        try LocalOnlyGradingValidator.validate(input)

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard localAIStatus == .available else {
                if case .unavailable(let message) = localAIStatus {
                    throw GradeDraftError.localModelUnavailable(message)
                }
                throw GradeDraftError.localModelUnavailable("The on-device language model is unavailable.")
            }

            let plan = try await budgeter.plan(input: input)
            do {
                switch plan.mode {
                case .fullPacket, .compactFullPacket:
                    return try await generateFullPacketDraft(input: input, plan: plan)
                case .perCriterion:
                    return try await generatePerCriterionDraft(input: input, plan: plan)
                case .unavailable:
                    throw GradeDraftError.localModelUnavailable("The on-device language model is unavailable.")
                }
            } catch {
                throw FoundationModelErrorMapper.map(error)
            }
        } else {
            throw GradeDraftError.localModelUnavailable("Foundation Models requires a newer operating system.")
        }
        #else
        throw GradeDraftError.localModelUnavailable("This build was compiled without the Foundation Models framework.")
        #endif
    }

    func prewarmIfAvailable() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), localAIStatus == .available {
            let session = LanguageModelSession(instructions: PromptBuilder.gradingInstructions(input: Self.prewarmInput))
            session.prewarm()
        }
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateFullPacketDraft(input: GradingInput, plan: PromptBudgetPlan) async throws -> GradeDraftResult {
        let mode: PromptPacketMode = plan.mode == .compactFullPacket ? .compact : .full
        let session = LanguageModelSession(instructions: PromptBuilder.gradingInstructions(input: input))
        let response = try await session.respond(
            to: PromptBuilder.fullPacketPrompt(input: input, mode: mode),
            generating: FoundationModelGradeProposalSchema.GradeDraftProposal.self,
            includeSchemaInPrompt: false
        )
        let audit = LocalModelDraftAudit.make(input: input, plan: plan, generatedCriteriaCount: response.content.criteria.count)
        let draft = response.content.asGradeDraftResult(input: input, audit: audit)
        return try GradeDraftValidator.normalizeAndValidate(draft, input: input)
    }

    @available(iOS 26.0, *)
    private func generatePerCriterionDraft(input: GradingInput, plan: PromptBudgetPlan) async throws -> GradeDraftResult {
        guard !input.parsedRubric.criteria.isEmpty else {
            throw GradeDraftError.promptTooLargeForLocalModel(GradingPromptBudgeter.tooLargeMessage)
        }

        var criteria: [CriterionScore] = []
        for rubricCriterion in input.parsedRubric.criteria {
            let session = LanguageModelSession(instructions: PromptBuilder.gradingInstructions(input: input))
            let response = try await session.respond(
                to: PromptBuilder.singleCriterionPrompt(input: input, criterion: rubricCriterion, mode: .compact),
                generating: FoundationModelGradeProposalSchema.SingleCriterionDraft.self,
                includeSchemaInPrompt: false
            )
            criteria.append(response.content.criterion.asCriterionScore())
        }

        let summary = try await maybeGenerateSummaryFeedback(input: input, criteria: criteria)
        let extraWarnings = summary.generatedByModel ? [] : ["Student feedback summary was generated deterministically because the packet was too large for a summary generation pass."]
        let audit = LocalModelDraftAudit.make(input: input, plan: plan, generatedCriteriaCount: criteria.count, extraWarnings: extraWarnings)
        let draft = GradeDraftResult(
            packetFingerprint: input.packetFingerprint,
            status: .teacherReviewRequired,
            studentResponseSummary: summary.studentResponseSummary,
            criteria: criteria,
            totalScore: criteria.reduce(0) { $0 + $1.proposedPoints },
            maxScore: criteria.reduce(0) { $0 + $1.maxPoints },
            studentFeedback: summary.studentFeedback,
            teacherNotes: summary.teacherNotes,
            uncertaintyFlags: summary.uncertaintyFlags + ["Generated criterion-by-criterion because the full grading packet was too large for one local model request."],
            complianceFlags: summary.complianceFlags,
            rawModelResponse: nil,
            localModelAudit: audit
        )
        return try GradeDraftValidator.normalizeAndValidate(draft, input: input)
    }

    @available(iOS 26.0, *)
    private func maybeGenerateSummaryFeedback(input: GradingInput, criteria: [CriterionScore]) async throws -> SummaryFeedbackResult {
        guard await budgeter.summaryFits(input: input, criteria: criteria) else {
            return SummaryFeedbackResult.deterministic(criteria: criteria)
        }
        let session = LanguageModelSession(instructions: PromptBuilder.gradingInstructions(input: input))
        let response = try await session.respond(
            to: PromptBuilder.summaryFeedbackPrompt(input: input, criteria: criteria),
            generating: FoundationModelGradeProposalSchema.DraftSummaryFeedback.self,
            includeSchemaInPrompt: false
        )
        return SummaryFeedbackResult(
            studentResponseSummary: response.content.studentResponseSummary,
            studentFeedback: response.content.studentFeedback,
            teacherNotes: response.content.teacherNotes,
            uncertaintyFlags: response.content.uncertaintyFlags,
            complianceFlags: response.content.complianceFlags,
            generatedByModel: true
        )
    }

    @available(iOS 26.0, *)
    private static func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled. Enable it in Settings to use local AI grading."
        case .deviceNotEligible:
            return "This device does not support the on-device language model required for local AI grading."
        case .modelNotReady:
            return "The on-device language model is not ready yet. Try again after the system finishes preparing it."
        @unknown default:
            return "The on-device language model is unavailable for an unknown reason."
        }
    }
    #endif

    private struct SummaryFeedbackResult {
        var studentResponseSummary: String
        var studentFeedback: String
        var teacherNotes: String
        var uncertaintyFlags: [String]
        var complianceFlags: [String]
        var generatedByModel: Bool

        static func deterministic(criteria: [CriterionScore]) -> SummaryFeedbackResult {
            let reviewRequired = criteria.filter(\.teacherReviewRequired).map(\.criterion)
            let status = reviewRequired.isEmpty
                ? "Review the criterion evidence, edit feedback, and approve only after confirming the draft against the full student response and rubric."
                : "Review required for: \(reviewRequired.joined(separator: ", "))."
            return SummaryFeedbackResult(
                studentResponseSummary: "Draft generated criterion-by-criterion from reviewed text and teacher-supplied grading materials.",
                studentFeedback: "Draft generated criterion-by-criterion. Review the criterion evidence, edit feedback, and approve only after confirming the draft against the full student response and rubric.",
                teacherNotes: "\(status) The summary was assembled without an additional model pass because the grading packet was too large for a safe summary request.",
                uncertaintyFlags: ["Criterion-by-criterion generation requires careful teacher synthesis before approval."],
                complianceFlags: ["No reviewed student text was truncated for local model generation."],
                generatedByModel: false
            )
        }
    }

    private static let prewarmInput = GradingInput(
        assignmentID: UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID(),
        assignmentTitle: "Prewarm",
        prompt: "",
        subject: "",
        gradeLevel: "",
        className: "",
        studentDisplayName: "",
        assignmentType: .shortAnswer,
        rubricText: "Prewarm: 0-1 points",
        parsedRubric: RubricParser.parse("Prewarm: 0-1 points"),
        customInstructions: "",
        answerKeyText: "",
        exemplarText: "",
        assessmentPurpose: .formative,
        curriculumReference: "",
        reviewedStudentText: "Prewarm text.",
        reviewedTextWithSourceRefs: "Prewarm text.",
        ocrQualitySummary: OCRQualitySummary(),
        ocrReviewStatus: .notNeeded,
        sourceInputCount: 0,
        packetFingerprint: "prewarm",
        hasGradingStandard: true
    )
}

// Retained for debug, compatibility, and test use. Production Foundation Models
// drafting uses typed guided generation (FoundationModelGradeProposalSchema).
enum JSONExtractor {
    static func extractFirstJSONObject(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{") else {
            return trimmed
        }

        var depth = 0
        var isInsideString = false
        var isEscaped = false
        var index = start

        while index < trimmed.endIndex {
            let character = trimmed[index]

            if isEscaped {
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == "\"" {
                isInsideString.toggle()
            } else if !isInsideString {
                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(trimmed[start...index])
                    }
                }
            }

            index = trimmed.index(after: index)
        }

        return trimmed
    }
}
