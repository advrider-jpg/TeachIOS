import Foundation

// MARK: - Foundation Models prompt and audit metadata

enum GradeDraftPromptVersion {
    static let foundationModelsTypedV1 = "gradedraft.foundationmodels.typed.v1"
    static let foundationModelsTypedV2 = "gradedraft.foundationmodels.typed.v2"
    static let currentFoundationModelsTyped = foundationModelsTypedV2
    static let schemaVersion = "gradedraft.gradeproposal.schema.v1"
    static let validatorVersion = "gradedraft.validator.v1"
}

enum LocalModelGenerationMode: String, Codable, Equatable, Sendable {
    case fullPacket
    case compactFullPacket
    case perCriterion
    case unavailable
}

struct LocalModelDraftAudit: Codable, Equatable, Sendable {
    var provider: String
    /// `ProcessInfo.operatingSystemVersionString` (includes the build; the on-device model ships with the OS).
    var osVersion: String
    /// Sampling mode used for generation, for example "greedy".
    var sampling: String
    var framework: String
    var promptVersion: String
    var schemaVersion: String
    var validatorVersion: String
    var generationMode: LocalModelGenerationMode
    var generatedAt: Date
    var inputPacketFingerprint: String
    var promptFingerprint: String
    var selectedInstructionTemplateIDs: [String]
    var selectedInstructionTemplateFingerprint: String
    var contextSizeTokens: Int?
    var estimatedOrMeasuredInputTokens: Int?
    var reservedOutputTokens: Int?
    var criteriaRequested: Int
    var criteriaGenerated: Int
    var usedStructuredRubric: Bool
    var usedAnswerKey: Bool
    var usedExemplar: Bool
    var usedCurriculumReference: Bool
    var sourceInputCount: Int
    var ocrReviewStatus: OCRReviewStatus
    var ocrQualitySummary: OCRQualitySummary
    var validationWarnings: [String]
    var modelUnavailableMessage: String?
    var generationErrorSummary: String?

    init(
        provider: String = "Apple Foundation Models",
        osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        sampling: String,
        framework: String = "FoundationModels",
        promptVersion: String = GradeDraftPromptVersion.currentFoundationModelsTyped,
        schemaVersion: String = GradeDraftPromptVersion.schemaVersion,
        validatorVersion: String = GradeDraftPromptVersion.validatorVersion,
        generationMode: LocalModelGenerationMode,
        generatedAt: Date = Date(),
        inputPacketFingerprint: String,
        promptFingerprint: String,
        selectedInstructionTemplateIDs: [String],
        selectedInstructionTemplateFingerprint: String,
        contextSizeTokens: Int?,
        estimatedOrMeasuredInputTokens: Int?,
        reservedOutputTokens: Int?,
        criteriaRequested: Int,
        criteriaGenerated: Int,
        usedStructuredRubric: Bool,
        usedAnswerKey: Bool,
        usedExemplar: Bool,
        usedCurriculumReference: Bool,
        sourceInputCount: Int,
        ocrReviewStatus: OCRReviewStatus,
        ocrQualitySummary: OCRQualitySummary,
        validationWarnings: [String] = [],
        modelUnavailableMessage: String? = nil,
        generationErrorSummary: String? = nil
    ) {
        self.provider = provider
        self.osVersion = osVersion
        self.sampling = sampling
        self.framework = framework
        self.promptVersion = promptVersion
        self.schemaVersion = schemaVersion
        self.validatorVersion = validatorVersion
        self.generationMode = generationMode
        self.generatedAt = Date(timeIntervalSinceReferenceDate: floor(generatedAt.timeIntervalSinceReferenceDate * 1000) / 1000)
        self.inputPacketFingerprint = inputPacketFingerprint
        self.promptFingerprint = promptFingerprint
        self.selectedInstructionTemplateIDs = selectedInstructionTemplateIDs
        self.selectedInstructionTemplateFingerprint = selectedInstructionTemplateFingerprint
        self.contextSizeTokens = contextSizeTokens
        self.estimatedOrMeasuredInputTokens = estimatedOrMeasuredInputTokens
        self.reservedOutputTokens = reservedOutputTokens
        self.criteriaRequested = criteriaRequested
        self.criteriaGenerated = criteriaGenerated
        self.usedStructuredRubric = usedStructuredRubric
        self.usedAnswerKey = usedAnswerKey
        self.usedExemplar = usedExemplar
        self.usedCurriculumReference = usedCurriculumReference
        self.sourceInputCount = sourceInputCount
        self.ocrReviewStatus = ocrReviewStatus
        self.ocrQualitySummary = ocrQualitySummary
        self.validationWarnings = validationWarnings
        self.modelUnavailableMessage = modelUnavailableMessage
        self.generationErrorSummary = generationErrorSummary
    }

    static func make(input: GradingInput, plan: PromptBudgetPlan, generatedCriteriaCount: Int, sampling: String, extraWarnings: [String] = []) -> LocalModelDraftAudit {
        let estimatedTokens: Int?
        switch plan.mode {
        case .fullPacket:
            estimatedTokens = plan.report.fullPacketTokens
        case .compactFullPacket:
            estimatedTokens = plan.report.compactPacketTokens
        case .perCriterion:
            estimatedTokens = plan.report.perCriterionTokenCounts.values.max()
        case .unavailable:
            estimatedTokens = nil
        }

        return LocalModelDraftAudit(
            sampling: sampling,
            generationMode: plan.mode,
            inputPacketFingerprint: input.packetFingerprint,
            promptFingerprint: plan.report.promptFingerprint,
            selectedInstructionTemplateIDs: input.selectedInstructionTemplateIDs,
            selectedInstructionTemplateFingerprint: input.selectedInstructionTemplateFingerprint,
            contextSizeTokens: plan.report.contextSizeTokens,
            estimatedOrMeasuredInputTokens: estimatedTokens,
            reservedOutputTokens: plan.report.reservedOutputTokens,
            criteriaRequested: input.parsedRubric.criteria.count,
            criteriaGenerated: generatedCriteriaCount,
            usedStructuredRubric: !input.parsedRubric.criteria.isEmpty,
            usedAnswerKey: !input.answerKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            usedExemplar: !input.exemplarText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            usedCurriculumReference: !input.curriculumReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            sourceInputCount: input.sourceInputCount,
            ocrReviewStatus: input.ocrReviewStatus,
            ocrQualitySummary: input.ocrQualitySummary,
            validationWarnings: Array(Set(plan.report.warnings + extraWarnings)).sorted()
        )
    }
}
