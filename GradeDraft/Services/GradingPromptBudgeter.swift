import Foundation

struct PromptBudgetReport: Codable, Equatable, Sendable {
    var contextSizeTokens: Int?
    var fullPacketTokens: Int?
    var compactPacketTokens: Int?
    var perCriterionTokenCounts: [String: Int]
    var selectedMode: LocalModelGenerationMode
    var reservedOutputTokens: Int
    var promptFingerprint: String
    var warnings: [String]
}

struct PromptBudgetPlan: Equatable, Sendable {
    var mode: LocalModelGenerationMode
    var report: PromptBudgetReport
}

enum PromptBudgetError: LocalizedError, Equatable {
    case promptTooLargeForLocalModel(String)
    case tokenBudgetUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .promptTooLargeForLocalModel(let message), .tokenBudgetUnavailable(let message):
            return message
        }
    }
}

protocol GradingPromptBudgeting: Sendable {
    func plan(input: GradingInput) async throws -> PromptBudgetPlan
    func summaryFits(input: GradingInput, criteria: [CriterionScore]) async -> Bool
}

enum PromptBudgetPolicy {
    static let minimumContextSafetyMarginTokens = 128
    static let contextSafetyMarginFraction = 0.10
    static let defaultContextSizeTokens = 4096
    static let baseFullPacketReservedOutputTokens = 900
    static let perCriterionReservedOutputTokens = 350
    static let summaryReservedOutputTokens = 450

    static func reservedOutputTokens(criteriaCount: Int, mode: LocalModelGenerationMode) -> Int {
        switch mode {
        case .fullPacket, .compactFullPacket:
            return max(baseFullPacketReservedOutputTokens, min(1600, 350 + criteriaCount * 140))
        case .perCriterion:
            return perCriterionReservedOutputTokens
        case .unavailable:
            return 0
        }
    }

    static func usableInputBudget(contextSizeTokens: Int, reservedOutputTokens: Int) -> Int {
        let margin = max(minimumContextSafetyMarginTokens, Int(Double(contextSizeTokens) * contextSafetyMarginFraction))
        return max(0, contextSizeTokens - reservedOutputTokens - margin)
    }
}

struct GradingPromptBudgeter: GradingPromptBudgeting {
    var contextSizeTokens: Int

    init(contextSizeTokens: Int = PromptBudgetPolicy.defaultContextSizeTokens) {
        self.contextSizeTokens = contextSizeTokens
    }

    func plan(input: GradingInput) async throws -> PromptBudgetPlan {
        let fullPrompt = PromptBuilder.gradingInstructionsText(input: input) + "\n\n" + PromptBuilder.fullPacketPromptText(input: input, mode: .full)
        let compactPrompt = PromptBuilder.gradingInstructionsText(input: input) + "\n\n" + PromptBuilder.fullPacketPromptText(input: input, mode: .compact)
        let fullTokens = estimateTokenCount(fullPrompt)
        let compactTokens = estimateTokenCount(compactPrompt)
        let fullReserved = PromptBudgetPolicy.reservedOutputTokens(criteriaCount: input.parsedRubric.criteria.count, mode: .fullPacket)
        let compactReserved = PromptBudgetPolicy.reservedOutputTokens(criteriaCount: input.parsedRubric.criteria.count, mode: .compactFullPacket)
        let fullBudget = PromptBudgetPolicy.usableInputBudget(contextSizeTokens: contextSizeTokens, reservedOutputTokens: fullReserved)
        let compactBudget = PromptBudgetPolicy.usableInputBudget(contextSizeTokens: contextSizeTokens, reservedOutputTokens: compactReserved)
        let fullFingerprint = StableFingerprint.fingerprint([fullPrompt])
        var warnings: [String] = []

        if fullTokens <= fullBudget {
            return PromptBudgetPlan(
                mode: .fullPacket,
                report: PromptBudgetReport(
                    contextSizeTokens: contextSizeTokens,
                    fullPacketTokens: fullTokens,
                    compactPacketTokens: compactTokens,
                    perCriterionTokenCounts: [:],
                    selectedMode: .fullPacket,
                    reservedOutputTokens: fullReserved,
                    promptFingerprint: fullFingerprint,
                    warnings: warnings
                )
            )
        }

        if compactTokens <= compactBudget {
            warnings.append("Compact full-packet prompt was used because the full prompt was too large for the conservative local-model budget.")
            return PromptBudgetPlan(
                mode: .compactFullPacket,
                report: PromptBudgetReport(
                    contextSizeTokens: contextSizeTokens,
                    fullPacketTokens: fullTokens,
                    compactPacketTokens: compactTokens,
                    perCriterionTokenCounts: [:],
                    selectedMode: .compactFullPacket,
                    reservedOutputTokens: compactReserved,
                    promptFingerprint: StableFingerprint.fingerprint([compactPrompt]),
                    warnings: warnings
                )
            )
        }

        guard !input.parsedRubric.criteria.isEmpty else {
            throw GradeDraftError.promptTooLargeForLocalModel(Self.tooLargeMessage)
        }

        var perCriterionTokenCounts: [String: Int] = [:]
        let perCriterionReserved = PromptBudgetPolicy.reservedOutputTokens(criteriaCount: input.parsedRubric.criteria.count, mode: .perCriterion)
        let perCriterionBudget = PromptBudgetPolicy.usableInputBudget(contextSizeTokens: contextSizeTokens, reservedOutputTokens: perCriterionReserved)
        var perCriterionFingerprints: [String] = []

        for criterion in input.parsedRubric.criteria {
            let prompt = PromptBuilder.gradingInstructionsText(input: input) + "\n\n" + PromptBuilder.singleCriterionPromptText(input: input, criterion: criterion, mode: .compact)
            let tokens = estimateTokenCount(prompt)
            perCriterionTokenCounts[criterion.id] = tokens
            perCriterionFingerprints.append(prompt)
            if tokens > perCriterionBudget {
                throw GradeDraftError.promptTooLargeForLocalModel(Self.tooLargeMessage)
            }
        }

        warnings.append("Per-criterion generation was selected because the full grading packet exceeded the conservative local-model budget.")
        return PromptBudgetPlan(
            mode: .perCriterion,
            report: PromptBudgetReport(
                contextSizeTokens: contextSizeTokens,
                fullPacketTokens: fullTokens,
                compactPacketTokens: compactTokens,
                perCriterionTokenCounts: perCriterionTokenCounts,
                selectedMode: .perCriterion,
                reservedOutputTokens: perCriterionReserved,
                promptFingerprint: StableFingerprint.fingerprint(perCriterionFingerprints),
                warnings: warnings
            )
        )
    }

    func summaryFits(input: GradingInput, criteria: [CriterionScore]) async -> Bool {
        let prompt = PromptBuilder.gradingInstructionsText(input: input) + "\n\n" + PromptBuilder.summaryFeedbackPromptText(input: input, criteria: criteria)
        let tokens = estimateTokenCount(prompt)
        let budget = PromptBudgetPolicy.usableInputBudget(
            contextSizeTokens: contextSizeTokens,
            reservedOutputTokens: PromptBudgetPolicy.summaryReservedOutputTokens
        )
        return tokens <= budget
    }

    // Conservative approximation used before the official token counter is available.
    // The runtime still catches Foundation Models context-window errors and fails openly
    // without truncating student work.
    private func estimateTokenCount(_ text: String) -> Int {
        max(1, Int(ceil(Double(text.count) / 3.2)))
    }

    static let tooLargeMessage = "This grading packet is too large for the on-device model. GradeDraft did not truncate the student work or send it to a cloud model. Shorten or split the reviewed text, reduce the grading packet, or use manual final review."
}
