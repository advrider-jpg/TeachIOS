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
