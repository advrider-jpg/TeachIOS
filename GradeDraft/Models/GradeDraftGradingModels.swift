import CoreGraphics
import Foundation

// MARK: - Grading records

struct GradingInput: Codable, Equatable {
    var assignmentID: UUID
    var assignmentTitle: String
    var prompt: String
    var subject: String
    var gradeLevel: String
    var className: String
    var studentDisplayName: String
    var assignmentType: AssignmentType
    var rubricText: String
    var parsedRubric: ParsedRubric
    var customInstructions: String
    var selectedInstructionTemplateIDs: [String] = []
    var selectedInstructionTemplateText: String = ""
    var selectedInstructionTemplateFingerprint: String = ""
    var formativeFocusText: String = ""
    var answerKeyText: String
    var exemplarText: String
    var assessmentPurpose: AssessmentPurpose
    var curriculumReference: String
    var reviewedStudentText: String
    var reviewedTextWithSourceRefs: String
    var ocrQualitySummary: OCRQualitySummary
    var ocrReviewStatus: OCRReviewStatus
    var sourceInputCount: Int
    var packetFingerprint: String
    var hasGradingStandard: Bool
    var plannedContentGradingPacket: GradingPacket? = nil

    var isReadyForGrading: Bool {
        hasGradingStandard &&
        !reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !ocrReviewStatus.blocksGrading
    }
}

enum DraftStatus: String, Codable, Equatable {
    case generated
    case stale
    case teacherReviewRequired
}

struct GradeDraftResult: Identifiable, Codable, Equatable {
    var id: UUID
    var generatedAt: Date
    var packetFingerprint: String
    var status: DraftStatus
    var studentResponseSummary: String
    var criteria: [CriterionScore]
    var totalScore: Double
    var maxScore: Double
    var studentFeedback: String
    var teacherNotes: String
    var uncertaintyFlags: [String]
    var complianceFlags: [String]
    var rawModelResponse: String?
    var localModelAudit: LocalModelDraftAudit?

    init(
        id: UUID = UUID(),
        generatedAt: Date = Date(),
        packetFingerprint: String = "",
        status: DraftStatus = .teacherReviewRequired,
        studentResponseSummary: String,
        criteria: [CriterionScore],
        totalScore: Double,
        maxScore: Double,
        studentFeedback: String,
        teacherNotes: String,
        uncertaintyFlags: [String],
        complianceFlags: [String] = [],
        rawModelResponse: String? = nil,
        localModelAudit: LocalModelDraftAudit? = nil
    ) {
        self.id = id
        self.generatedAt = Date(timeIntervalSinceReferenceDate: floor(generatedAt.timeIntervalSinceReferenceDate * 1000) / 1000)
        self.packetFingerprint = packetFingerprint
        self.status = status
        self.studentResponseSummary = studentResponseSummary
        self.criteria = criteria
        self.totalScore = totalScore
        self.maxScore = maxScore
        self.studentFeedback = studentFeedback
        self.teacherNotes = teacherNotes
        self.uncertaintyFlags = uncertaintyFlags
        self.complianceFlags = complianceFlags
        self.rawModelResponse = rawModelResponse
        self.localModelAudit = localModelAudit
    }
}

struct CriterionScore: Identifiable, Codable, Equatable {
    var id: UUID
    var criterionID: String?
    var criterion: String
    var rating: String
    var proposedPoints: Double
    var maxPoints: Double
    var evidence: [String]
    var evidenceSourceRefs: [String]
    var explanation: String
    var teacherReviewRequired: Bool
    var nextStep: String
    var confidence: String
    var criterionUncertaintyFlags: [String]

    init(
        id: UUID = UUID(),
        criterionID: String? = nil,
        criterion: String,
        rating: String,
        proposedPoints: Double,
        maxPoints: Double,
        evidence: [String],
        evidenceSourceRefs: [String] = [],
        explanation: String,
        teacherReviewRequired: Bool,
        nextStep: String = "",
        confidence: String = "",
        criterionUncertaintyFlags: [String] = []
    ) {
        self.id = id
        self.criterionID = criterionID
        self.criterion = criterion
        self.rating = rating
        self.proposedPoints = proposedPoints
        self.maxPoints = maxPoints
        self.evidence = evidence
        self.evidenceSourceRefs = evidenceSourceRefs
        self.explanation = explanation
        self.teacherReviewRequired = teacherReviewRequired
        self.nextStep = nextStep
        self.confidence = confidence
        self.criterionUncertaintyFlags = criterionUncertaintyFlags
    }
}

enum FinalReviewStatus: String, Codable, Equatable {
    case inProgress
    case approved
    case stale
}

struct FinalGradeReview: Identifiable, Codable, Equatable {
    var id: UUID
    var createdAt: Date
    var finalizedAt: Date?
    var packetFingerprint: String
    var status: FinalReviewStatus
    var criteria: [FinalCriterionScore]
    var totalScore: Double
    var maxScore: Double
    var studentFeedback: String
    var privateTeacherNotes: String
    var teacherEdited: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        finalizedAt: Date? = nil,
        packetFingerprint: String = "",
        status: FinalReviewStatus = .inProgress,
        criteria: [FinalCriterionScore],
        totalScore: Double,
        maxScore: Double,
        studentFeedback: String,
        privateTeacherNotes: String,
        teacherEdited: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.finalizedAt = finalizedAt
        self.packetFingerprint = packetFingerprint
        self.status = status
        self.criteria = criteria
        self.totalScore = totalScore
        self.maxScore = maxScore
        self.studentFeedback = studentFeedback
        self.privateTeacherNotes = privateTeacherNotes
        self.teacherEdited = teacherEdited
    }

    var allCriteriaApproved: Bool {
        !criteria.isEmpty && criteria.allSatisfy(\.teacherApproved)
    }
}

struct FinalCriterionScore: Identifiable, Codable, Equatable {
    var id: UUID
    var criterionID: String?
    var criterion: String
    var rating: String
    var proposedPoints: Double
    var finalPoints: Double
    var maxPoints: Double
    var evidence: [String]
    var evidenceSourceRefs: [String]?
    var explanation: String
    var teacherApproved: Bool
    var teacherRationale: String

    init(
        id: UUID = UUID(),
        criterionID: String? = nil,
        criterion: String,
        rating: String,
        proposedPoints: Double,
        finalPoints: Double,
        maxPoints: Double,
        evidence: [String],
        evidenceSourceRefs: [String]? = nil,
        explanation: String,
        teacherApproved: Bool = false,
        teacherRationale: String = ""
    ) {
        self.id = id
        self.criterionID = criterionID
        self.criterion = criterion
        self.rating = rating
        self.proposedPoints = proposedPoints
        self.finalPoints = finalPoints
        self.maxPoints = maxPoints
        self.evidence = evidence
        self.evidenceSourceRefs = evidenceSourceRefs
        self.explanation = explanation
        self.teacherApproved = teacherApproved
        self.teacherRationale = teacherRationale
    }

    init(from draft: CriterionScore) {
        self.init(
            criterionID: draft.criterionID,
            criterion: draft.criterion,
            rating: draft.rating,
            proposedPoints: draft.proposedPoints,
            finalPoints: draft.proposedPoints,
            maxPoints: draft.maxPoints,
            evidence: draft.evidence,
            evidenceSourceRefs: draft.evidenceSourceRefs,
            explanation: draft.explanation,
            teacherApproved: false,
            teacherRationale: draft.teacherReviewRequired ? "Review required by draft." : ""
        )
    }
}
