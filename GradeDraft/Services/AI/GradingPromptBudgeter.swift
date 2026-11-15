import Foundation

import FoundationModels

struct PromptBudgetReport: Codable, Equatable, Sendable {
    var contextSizeTokens: Int
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

protocol GradingPromptBudgeting: Sendable {
    /// Chooses the largest packet mode that fits. `failedMode` is the mode the model just rejected for context
    /// size, so only smaller modes are considered; nil considers every mode. Throws `DraftFailure.contextTooLarge`
    /// when nothing fits. Never shortens the reviewed text or grading materials.
    func plan(input: GradingInput, after failedMode: LocalModelGenerationMode?) async throws -> PromptBudgetPlan
    /// Whether a separate summary request fits after criterion-by-criterion drafting.
    func summaryFits(input: GradingInput, criteria: [ModelCriterionProposal]) async throws -> Bool
}

enum PromptBudgetPolicy {
    static let minimumContextSafetyMarginTokens = 128
    static let contextSafetyMarginFraction = 0.10
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

/// Measures each request with the on-device model's own token counter: the instructions, the prompt and the
/// output schema (as JSON) the framework adds to the request. The only counting overload takes `Instructions`,
/// so the prompt and schema text are wrapped in `Instructions` to be counted; this measures the real text.
struct GradingPromptBudgeter: GradingPromptBudgeting {
    func plan(input: GradingInput, after failedMode: LocalModelGenerationMode?) async throws -> PromptBudgetPlan {
        let allowFullPacket: Bool
        let allowCompactPacket: Bool
        switch failedMode {
        case nil:
            allowFullPacket = true
            allowCompactPacket = true
        case .fullPacket:
            allowFullPacket = false
            allowCompactPacket = true
        case .compactFullPacket:
            allowFullPacket = false
            allowCompactPacket = false
        case .perCriterion, .unavailable:
            throw DraftFailure.contextTooLarge
        }

        let model = SystemLanguageModel.default
        let contextSize = model.contextSize
        let criteriaCount = input.parsedRubric.criteria.count
        let instructionsTokens = try await Self.count(PromptBuilder.gradingInstructionsText(), model: model)
        var warnings: [String] = []
        var fullTokens: Int?
        var compactTokens: Int?

        if allowFullPacket {
            let prompt = PromptBuilder.fullPacketPromptText(input: input, mode: .full)
            let tokens = try await Self.requestTokens(
                instructionsTokens: instructionsTokens,
                prompt: prompt,
                packetSchema: input.parsedRubric.criteria.isEmpty,
                model: model
            )
            fullTokens = tokens
            let reserved = PromptBudgetPolicy.reservedOutputTokens(criteriaCount: criteriaCount, mode: .fullPacket)
            if tokens <= PromptBudgetPolicy.usableInputBudget(contextSizeTokens: contextSize, reservedOutputTokens: reserved) {
                return PromptBudgetPlan(
                    mode: .fullPacket,
                    report: PromptBudgetReport(
                        contextSizeTokens: contextSize,
                        fullPacketTokens: tokens,
                        compactPacketTokens: nil,
                        perCriterionTokenCounts: [:],
                        selectedMode: .fullPacket,
                        reservedOutputTokens: reserved,
                        promptFingerprint: ContentDigest.sha256Hex(prompt),
                        warnings: warnings
                    )
                )
            }
        }

        if allowCompactPacket {
            let prompt = PromptBuilder.fullPacketPromptText(input: input, mode: .compact)
            let tokens = try await Self.requestTokens(
                instructionsTokens: instructionsTokens,
                prompt: prompt,
                packetSchema: input.parsedRubric.criteria.isEmpty,
                model: model
            )
            compactTokens = tokens
            let reserved = PromptBudgetPolicy.reservedOutputTokens(criteriaCount: criteriaCount, mode: .compactFullPacket)
            if tokens <= PromptBudgetPolicy.usableInputBudget(contextSizeTokens: contextSize, reservedOutputTokens: reserved) {
                warnings.append(allowFullPacket
                    ? "Compact packet was used because the full packet was too large for the on-device model."
                    : "Compact packet was used after the on-device model rejected the full packet for context size.")
                return PromptBudgetPlan(
                    mode: .compactFullPacket,
                    report: PromptBudgetReport(
                        contextSizeTokens: contextSize,
                        fullPacketTokens: fullTokens,
                        compactPacketTokens: tokens,
                        perCriterionTokenCounts: [:],
                        selectedMode: .compactFullPacket,
                        reservedOutputTokens: reserved,
                        promptFingerprint: ContentDigest.sha256Hex(prompt),
                        warnings: warnings
                    )
                )
            }
        }

        guard !input.parsedRubric.criteria.isEmpty else {
            throw DraftFailure.contextTooLarge
        }
        let reserved = PromptBudgetPolicy.reservedOutputTokens(criteriaCount: criteriaCount, mode: .perCriterion)
        let budget = PromptBudgetPolicy.usableInputBudget(contextSizeTokens: contextSize, reservedOutputTokens: reserved)
        var perCriterionTokenCounts: [String: Int] = [:]
        var prompts: [String] = []
        for criterion in input.parsedRubric.criteria {
            let prompt = PromptBuilder.singleCriterionPromptText(input: input, criterion: criterion, mode: .compact)
            let tokens = try await Self.requestTokens(
                instructionsTokens: instructionsTokens,
                prompt: prompt,
                schema: FoundationModelGradeProposalSchema.SingleCriterionDraft.self,
                model: model
            )
            guard tokens <= budget else {
                throw DraftFailure.contextTooLarge
            }
            perCriterionTokenCounts[criterion.id] = tokens
            prompts.append(prompt)
        }
        warnings.append(allowCompactPacket
            ? "Criterion-by-criterion drafting was used because the full grading packet was too large for the on-device model."
            : "Criterion-by-criterion drafting was used after the on-device model rejected the previous packet for context size.")
        return PromptBudgetPlan(
            mode: .perCriterion,
            report: PromptBudgetReport(
                contextSizeTokens: contextSize,
                fullPacketTokens: fullTokens,
                compactPacketTokens: compactTokens,
                perCriterionTokenCounts: perCriterionTokenCounts,
                selectedMode: .perCriterion,
                reservedOutputTokens: reserved,
                promptFingerprint: ContentDigest.sha256Hex(prompts.joined(separator: "\n\u{1F}\n")),
                warnings: warnings
            )
        )
    }

    func summaryFits(input: GradingInput, criteria: [ModelCriterionProposal]) async throws -> Bool {
        let model = SystemLanguageModel.default
        let instructionsTokens = try await Self.count(PromptBuilder.gradingInstructionsText(), model: model)
        let tokens = try await Self.requestTokens(
            instructionsTokens: instructionsTokens,
            prompt: PromptBuilder.summaryFeedbackPromptText(input: input, criteria: criteria),
            schema: FoundationModelGradeProposalSchema.DraftSummaryFeedback.self,
            model: model
        )
        let budget = PromptBudgetPolicy.usableInputBudget(
            contextSizeTokens: model.contextSize,
            reservedOutputTokens: PromptBudgetPolicy.summaryReservedOutputTokens
        )
        return tokens <= budget
    }

    /// Whole-packet requests use the rubric schema, or the schema with criterion titles and maximums when the
    /// assignment has no point-bearing rubric criteria.
    private static func requestTokens(
        instructionsTokens: Int,
        prompt: String,
        packetSchema unstructured: Bool,
        model: SystemLanguageModel
    ) async throws -> Int {
        if unstructured {
            return try await requestTokens(instructionsTokens: instructionsTokens, prompt: prompt, schema: FoundationModelGradeProposalSchema.UnstructuredGradeDraftProposal.self, model: model)
        }
        return try await requestTokens(instructionsTokens: instructionsTokens, prompt: prompt, schema: FoundationModelGradeProposalSchema.GradeDraftProposal.self, model: model)
    }

    private static func requestTokens<T: Generable>(
        instructionsTokens: Int,
        prompt: String,
        schema: T.Type,
        model: SystemLanguageModel
    ) async throws -> Int {
        let promptTokens = try await count(prompt, model: model)
        let schemaTokens = try await count(schemaJSON(schema), model: model)
        return instructionsTokens + promptTokens + schemaTokens
    }

    private static func count(_ text: String, model: SystemLanguageModel) async throws -> Int {
        do {
            return try await model.tokenCount(for: Instructions(text))
        } catch {
            throw FoundationModelErrorMapper.map(error)
        }
    }

    static func schemaJSON<T: Generable>(_ type: T.Type) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(T.generationSchema), as: UTF8.self)
    }
}
