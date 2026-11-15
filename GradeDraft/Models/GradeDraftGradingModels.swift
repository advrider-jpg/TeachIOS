import Foundation

// MARK: - Grading packet input

struct GradingInput: Codable, Equatable, Sendable {
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

// MARK: - AI draft (model output, kept separate from the teacher's final review)

/// Whether the draft is current is never stored: compare `packetFingerprint` with
/// `SubmissionGraph.packetFingerprint(setup:)`.
enum DraftStatus: String, Codable, Equatable, Sendable {
    case generated
    case teacherReviewRequired
}

struct GradeDraftResult: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var generatedAt: Date
    var packetFingerprint: String
    var status: DraftStatus
    var studentResponseSummary: String
    var criteria: [CriterionScore]
    var studentFeedback: String
    var teacherNotes: String
    var uncertaintyFlags: [String]
    var complianceFlags: [String]
    var modelAudit: LocalModelDraftAudit?

    init(
        id: UUID = UUID(),
        generatedAt: Date = Date(),
        packetFingerprint: String,
        status: DraftStatus = .teacherReviewRequired,
        studentResponseSummary: String,
        criteria: [CriterionScore],
        studentFeedback: String,
        teacherNotes: String,
        uncertaintyFlags: [String],
        complianceFlags: [String] = [],
        modelAudit: LocalModelDraftAudit? = nil
    ) {
        self.id = id
        self.generatedAt = generatedAt
        self.packetFingerprint = packetFingerprint
        self.status = status
        self.studentResponseSummary = studentResponseSummary
        self.criteria = criteria
        self.studentFeedback = studentFeedback
        self.teacherNotes = teacherNotes
        self.uncertaintyFlags = uncertaintyFlags
        self.complianceFlags = complianceFlags
        self.modelAudit = modelAudit
    }

    /// Always the sum of the stored criterion points (never a model-written total).
    var totalScore: Double {
        criteria.reduce(0) { $0 + $1.proposedPoints }
    }
}

/// One AI-proposed criterion score. The criterion's title and maximum come from the assignment's rubric.
struct CriterionScore: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var criterionID: String
    var rating: String
    var proposedPoints: Double
    /// Quotes as the model wrote them.
    var evidenceQuotes: [String]
    var explanation: String
    var teacherReviewRequired: Bool
    var nextStep: String
    var confidence: String
    var uncertaintyFlags: [String]
    /// Set only when the assignment has no structured point-bearing rubric (answer-key or exemplar-only
    /// drafting); otherwise the title and maximum come from the rubric.
    var title: String?
    var maxPoints: Double?

    init(
        id: UUID = UUID(),
        criterionID: String,
        rating: String,
        proposedPoints: Double,
        evidenceQuotes: [String],
        explanation: String,
        teacherReviewRequired: Bool,
        nextStep: String = "",
        confidence: String = "",
        uncertaintyFlags: [String] = [],
        title: String? = nil,
        maxPoints: Double? = nil
    ) {
        self.id = id
        self.criterionID = criterionID
        self.rating = rating
        self.proposedPoints = proposedPoints
        self.evidenceQuotes = evidenceQuotes
        self.explanation = explanation
        self.teacherReviewRequired = teacherReviewRequired
        self.nextStep = nextStep
        self.confidence = confidence
        self.uncertaintyFlags = uncertaintyFlags
        self.title = title
        self.maxPoints = maxPoints
    }
}

// MARK: - Teacher final review

/// Whether the review is current is never stored: compare `packetFingerprint` with
/// `SubmissionGraph.packetFingerprint(setup:)`.
enum FinalReviewStatus: String, Codable, Equatable, Sendable {
    case inProgress
    case approved
}

struct FinalGradeReview: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var createdAt: Date
    var finalizedAt: Date?
    var packetFingerprint: String
    var status: FinalReviewStatus
    var criteria: [FinalCriterionScore]
    var studentFeedback: String
    var privateTeacherNotes: String
    var teacherEdited: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        finalizedAt: Date? = nil,
        packetFingerprint: String,
        status: FinalReviewStatus = .inProgress,
        criteria: [FinalCriterionScore],
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
        self.studentFeedback = studentFeedback
        self.privateTeacherNotes = privateTeacherNotes
        self.teacherEdited = teacherEdited
    }

    /// Always the sum of the stored final criterion points.
    var totalScore: Double {
        criteria.reduce(0) { $0 + $1.finalPoints }
    }

    var allCriteriaApproved: Bool {
        !criteria.isEmpty && criteria.allSatisfy(\.teacherApproved)
    }
}

struct FinalCriterionScore: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var criterionID: String
    var rating: String
    var proposedPoints: Double
    var finalPoints: Double
    var explanation: String
    var teacherApproved: Bool
    var teacherRationale: String
    /// Evidence records (`EvidenceReference.id`) the teacher attached, in order.
    var evidenceIDs: [UUID]
    /// Set only when the assignment has no structured point-bearing rubric; otherwise from the rubric.
    var title: String?
    var maxPoints: Double?

    init(
        id: UUID = UUID(),
        criterionID: String,
        rating: String,
        proposedPoints: Double,
        finalPoints: Double,
        explanation: String,
        teacherApproved: Bool = false,
        teacherRationale: String = "",
        evidenceIDs: [UUID] = [],
        title: String? = nil,
        maxPoints: Double? = nil
    ) {
        self.id = id
        self.criterionID = criterionID
        self.rating = rating
        self.proposedPoints = proposedPoints
        self.finalPoints = finalPoints
        self.explanation = explanation
        self.teacherApproved = teacherApproved
        self.teacherRationale = teacherRationale
        self.evidenceIDs = evidenceIDs
        self.title = title
        self.maxPoints = maxPoints
    }

    /// Starts the teacher's review of one criterion from the AI draft's proposal.
    init(from draft: CriterionScore) {
        self.init(
            criterionID: draft.criterionID,
            rating: draft.rating,
            proposedPoints: draft.proposedPoints,
            finalPoints: draft.proposedPoints,
            explanation: draft.explanation,
            teacherApproved: false,
            teacherRationale: draft.teacherReviewRequired ? "Review required by draft." : "",
            title: draft.title,
            maxPoints: draft.maxPoints
        )
    }
}
