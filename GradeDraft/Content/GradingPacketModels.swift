import Foundation

// MARK: - Typed grading packet adapter

struct GradingPacket: Codable, Equatable {
    var packetVersion: String
    var fingerprintSchemaVersion: String
    var assignment: GradingPacketAssignment
    var curriculumReference: GradingPacketCurriculumReference?
    var rubric: GradingPacketRubric
    var teacherInstructions: [GradingPacketTeacherInstruction]
    var formativeFocus: GradingPacketFormativeFocus?
    var answerKey: GradingPacketAnswerKey?
    var exemplar: GradingPacketExemplar?
    var studentEvidence: GradingPacketStudentEvidence
    var sourceInputs: [GradingPacketSourceInput]
    var evidenceReferences: [GradingPacketEvidenceReference]
    var appliedTemplates: [AppliedTemplateRecord]
    var outputRules: GradingPacketOutputRules
}

struct GradingPacketAssignment: Codable, Equatable {
    var assignmentID: UUID
    var classGroupID: UUID?
    var studentID: UUID?
    var title: String
    var prompt: String
    var subject: String
    var gradeLevel: String
    var className: String
    var studentDisplayName: String
    var assignmentType: AssignmentType
    var assessmentPurpose: AssessmentPurpose
}

struct GradingPacketCurriculumReference: Codable, Equatable {
    var rawText: String
    var mappings: [String]
}

struct GradingPacketRubric: Codable, Equatable {
    var rawText: String
    var criteria: [GradingPacketRubricCriterion]
}

struct GradingPacketRubricCriterion: Codable, Equatable {
    var id: String
    var title: String
    var maxPoints: Double
    var descriptor: String
    var groupTitle: String?
}

struct GradingPacketTeacherInstruction: Codable, Equatable {
    var id: String?
    var name: String?
    var text: String
    var privateTeacherOnly: Bool
}

struct GradingPacketFormativeFocus: Codable, Equatable {
    var rawText: String
}

struct GradingPacketAnswerKey: Codable, Equatable {
    var rawText: String
}

struct GradingPacketExemplar: Codable, Equatable {
    var rawText: String
}

struct GradingPacketStudentEvidence: Codable, Equatable {
    var reviewedText: String
    var reviewedTextWithSourceRefs: String
    var ocrReviewStatus: OCRReviewStatus
    var ocrReviewedAt: Date?
    var ocrQualitySummary: String
    var hasLowConfidenceOCRText: Bool
    var sourceInputCount: Int
    var evidenceReferenceQuotes: [String]
}

struct GradingPacketSourceInput: Codable, Equatable {
    var id: UUID
    var sourceType: SourceType
    var pageIndex: Int?
    var localRelativePath: String?
    var fileName: String?
    var contentDigest: String?
    var digestAlgorithm: String?
    var teacherIncludedInExport: Bool
}

struct GradingPacketEvidenceReference: Codable, Equatable {
    var id: UUID
    var sourceInputID: UUID?
    var ocrLineID: UUID?
    var pageIndex: Int?
    var quote: String
    var sourceKind: String
    var teacherConfirmed: Bool
    var boundingBox: String?
}

struct GradingPacketOutputRules: Codable, Equatable {
    var requireEvidenceQuotes: Bool
    var requireTeacherReviewForFinalGrade: Bool
    var doNotInferIntentAbilityEffort: Bool
    var studentFacingFeedbackOnly: Bool
}

// MARK: - AI readiness and packet preview

enum AIReadinessStatus: String, Codable, Equatable, Sendable {
    case ready
    case needsReview
    case blocked
    case unavailable
    case info
}

struct AIReadinessCheck: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var title: String
    var detail: String
    var status: AIReadinessStatus
}

struct AIReadinessReport: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var assignmentID: UUID
    var generatedAt: Date
    var localAIStatusSummary: String
    var canGenerate: Bool
    var checks: [AIReadinessCheck]
    var promptInjectionRisks: [String]
    var piiRedactionSummary: String
    var plannedGenerationMode: LocalModelGenerationMode
    var tokenEstimateSummary: String
    var recommendedNextAction: String

    init(
        id: UUID = UUID(),
        assignmentID: UUID,
        generatedAt: Date = Date(),
        localAIStatusSummary: String,
        canGenerate: Bool,
        checks: [AIReadinessCheck],
        promptInjectionRisks: [String],
        piiRedactionSummary: String,
        plannedGenerationMode: LocalModelGenerationMode,
        tokenEstimateSummary: String,
        recommendedNextAction: String
    ) {
        self.id = id
        self.assignmentID = assignmentID
        self.generatedAt = Date(timeIntervalSinceReferenceDate: floor(generatedAt.timeIntervalSinceReferenceDate * 1000) / 1000)
        self.localAIStatusSummary = localAIStatusSummary
        self.canGenerate = canGenerate
        self.checks = checks
        self.promptInjectionRisks = promptInjectionRisks
        self.piiRedactionSummary = piiRedactionSummary
        self.plannedGenerationMode = plannedGenerationMode
        self.tokenEstimateSummary = tokenEstimateSummary
        self.recommendedNextAction = recommendedNextAction
    }
}

struct AIPacketPreview: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var assignmentID: UUID
    var generatedAt: Date
    var includedInLocalDraft: [String]
    var notSentToModel: [String]
    var generationPlan: [String]
    var promptVersion: String
    var promptFingerprint: String
    var packetFingerprint: String
    var modelVisibleMetadata: [String]
    var technicalPromptPreview: String

    init(
        id: UUID = UUID(),
        assignmentID: UUID,
        generatedAt: Date = Date(),
        includedInLocalDraft: [String],
        notSentToModel: [String],
        generationPlan: [String],
        promptVersion: String,
        promptFingerprint: String,
        packetFingerprint: String,
        modelVisibleMetadata: [String],
        technicalPromptPreview: String
    ) {
        self.id = id
        self.assignmentID = assignmentID
        self.generatedAt = Date(timeIntervalSinceReferenceDate: floor(generatedAt.timeIntervalSinceReferenceDate * 1000) / 1000)
        self.includedInLocalDraft = includedInLocalDraft
        self.notSentToModel = notSentToModel
        self.generationPlan = generationPlan
        self.promptVersion = promptVersion
        self.promptFingerprint = promptFingerprint
        self.packetFingerprint = packetFingerprint
        self.modelVisibleMetadata = modelVisibleMetadata
        self.technicalPromptPreview = technicalPromptPreview
    }
}

enum AIGenerationStage: String, Codable, Equatable, Sendable {
    case idle
    case validatingInputs
    case checkingAvailability
    case planningPacket
    case requestingModel
    case generatingCriteria
    case synthesizingSummary
    case rewritingFeedback
    case validatingDraft
    case storingDraft
    case cancellationRequested
    case cancelled
    case failed
    case completed
}

struct RubricReadinessReport: Codable, Equatable, Sendable {
    var issues: [String]
    var warnings: [String]
    var canUseForDrafting: Bool
}

struct AIGenerationProgress: Codable, Equatable, Sendable {
    var stage: AIGenerationStage
    var detail: String
    var completedUnitCount: Int
    var totalUnitCount: Int?
    var canCancel: Bool

    init(
        stage: AIGenerationStage,
        detail: String,
        completedUnitCount: Int = 0,
        totalUnitCount: Int? = nil,
        canCancel: Bool = false
    ) {
        self.stage = stage
        self.detail = detail
        self.completedUnitCount = completedUnitCount
        self.totalUnitCount = totalUnitCount
        self.canCancel = canCancel
    }

    static let idle = AIGenerationProgress(
        stage: .idle,
        detail: "No local draft is running.",
        canCancel: false
    )

    var fractionCompleted: Double? {
        guard let totalUnitCount, totalUnitCount > 0 else { return nil }
        return min(1.0, max(0.0, Double(completedUnitCount) / Double(totalUnitCount)))
    }
}
