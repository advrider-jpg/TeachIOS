import Foundation
import GRDB

// Row records for the tables whose domain values (`OCRDocument`, `GradeDraftResult`,
// `FinalGradeReview`) are assembled in memory from several rows.

struct OCRDocumentRow: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "ocrDocument"

    var id: UUID
    var submissionID: UUID
    var engine: String
    var engineVersion: String
    var reviewStatus: OCRReviewStatus
    var reviewedAt: Date?
    var createdAt: Date
}

struct OCRPageRow: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "ocrPage"

    var id: UUID
    var documentID: UUID
    var sourceInputID: UUID?
    var pageIndex: Int
    var pixelWidth: Int?
    var pixelHeight: Int?
}

struct OCRLineRow: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "ocrLine"

    var id: UUID
    var pageID: UUID
    var lineOrder: Int
    var paragraphIndex: Int?
    var rawText: String
    var correctedText: String?
    var origin: OCRLineOrigin
    var confidence: Double?
    var bboxX: Double?
    var bboxY: Double?
    var bboxWidth: Double?
    var bboxHeight: Double?
    var teacherConfirmed: Bool
    var isRejected: Bool

    init(_ line: OCRLine, pageID: UUID, lineOrder: Int) {
        id = line.id
        self.pageID = pageID
        self.lineOrder = lineOrder
        paragraphIndex = line.paragraphIndex
        rawText = line.rawText
        correctedText = line.correctedText
        origin = line.origin
        confidence = line.confidence.map(Double.init)
        bboxX = line.boundingBox.map { Double($0.x) }
        bboxY = line.boundingBox.map { Double($0.y) }
        bboxWidth = line.boundingBox.map { Double($0.width) }
        bboxHeight = line.boundingBox.map { Double($0.height) }
        teacherConfirmed = line.teacherConfirmed
        isRejected = line.isRejected
    }

    var line: OCRLine {
        var box: NormalizedRect?
        if let bboxX, let bboxY, let bboxWidth, let bboxHeight {
            box = NormalizedRect(x: CGFloat(bboxX), y: CGFloat(bboxY), width: CGFloat(bboxWidth), height: CGFloat(bboxHeight))
        }
        return OCRLine(
            id: id,
            text: rawText,
            confidence: confidence.map(Float.init),
            boundingBox: box,
            origin: origin,
            paragraphIndex: paragraphIndex,
            correctedText: correctedText,
            teacherConfirmed: teacherConfirmed,
            isRejected: isRejected
        )
    }
}

struct DraftRow: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "draft"

    var id: UUID
    var submissionID: UUID
    var generatedAt: Date
    var packetFingerprint: String
    var status: DraftStatus
    var studentResponseSummary: String
    var studentFeedback: String
    var teacherNotes: String
    var uncertaintyFlags: [String]
    var complianceFlags: [String]
    var modelAudit: LocalModelDraftAudit?

    init(_ draft: GradeDraftResult, submissionID: UUID) {
        id = draft.id
        self.submissionID = submissionID
        generatedAt = draft.generatedAt
        packetFingerprint = draft.packetFingerprint
        status = draft.status
        studentResponseSummary = draft.studentResponseSummary
        studentFeedback = draft.studentFeedback
        teacherNotes = draft.teacherNotes
        uncertaintyFlags = draft.uncertaintyFlags
        complianceFlags = draft.complianceFlags
        modelAudit = draft.modelAudit
    }

    func draft(criteria: [CriterionScore]) -> GradeDraftResult {
        GradeDraftResult(
            id: id,
            generatedAt: generatedAt,
            packetFingerprint: packetFingerprint,
            status: status,
            studentResponseSummary: studentResponseSummary,
            criteria: criteria,
            studentFeedback: studentFeedback,
            teacherNotes: teacherNotes,
            uncertaintyFlags: uncertaintyFlags,
            complianceFlags: complianceFlags,
            modelAudit: modelAudit
        )
    }
}

struct DraftCriterionRow: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "draftCriterion"

    var id: UUID
    var draftID: UUID
    var sortOrder: Int
    var criterionID: String
    var criterionTitle: String?
    var maxPoints: Double?
    var rating: String
    var proposedPoints: Double
    var evidenceQuotes: [String]
    var explanation: String
    var teacherReviewRequired: Bool
    var nextStep: String
    var confidence: String
    var uncertaintyFlags: [String]

    init(_ score: CriterionScore, draftID: UUID, sortOrder: Int) {
        id = score.id
        self.draftID = draftID
        self.sortOrder = sortOrder
        criterionID = score.criterionID
        criterionTitle = score.title
        maxPoints = score.maxPoints
        rating = score.rating
        proposedPoints = score.proposedPoints
        evidenceQuotes = score.evidenceQuotes
        explanation = score.explanation
        teacherReviewRequired = score.teacherReviewRequired
        nextStep = score.nextStep
        confidence = score.confidence
        uncertaintyFlags = score.uncertaintyFlags
    }

    var score: CriterionScore {
        CriterionScore(
            id: id,
            criterionID: criterionID,
            rating: rating,
            proposedPoints: proposedPoints,
            evidenceQuotes: evidenceQuotes,
            explanation: explanation,
            teacherReviewRequired: teacherReviewRequired,
            nextStep: nextStep,
            confidence: confidence,
            uncertaintyFlags: uncertaintyFlags,
            title: criterionTitle,
            maxPoints: maxPoints
        )
    }
}

struct FinalReviewRow: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "finalReview"

    var id: UUID
    var submissionID: UUID
    var createdAt: Date
    var finalizedAt: Date?
    var packetFingerprint: String
    var status: FinalReviewStatus
    var studentFeedback: String
    var privateTeacherNotes: String
    var teacherEdited: Bool

    init(_ review: FinalGradeReview, submissionID: UUID) {
        id = review.id
        self.submissionID = submissionID
        createdAt = review.createdAt
        finalizedAt = review.finalizedAt
        packetFingerprint = review.packetFingerprint
        status = review.status
        studentFeedback = review.studentFeedback
        privateTeacherNotes = review.privateTeacherNotes
        teacherEdited = review.teacherEdited
    }

    func review(criteria: [FinalCriterionScore]) -> FinalGradeReview {
        FinalGradeReview(
            id: id,
            createdAt: createdAt,
            finalizedAt: finalizedAt,
            packetFingerprint: packetFingerprint,
            status: status,
            criteria: criteria,
            studentFeedback: studentFeedback,
            privateTeacherNotes: privateTeacherNotes,
            teacherEdited: teacherEdited
        )
    }
}

struct FinalReviewCriterionRow: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "finalReviewCriterion"

    var id: UUID
    var finalReviewID: UUID
    var sortOrder: Int
    var criterionID: String
    var criterionTitle: String?
    var maxPoints: Double?
    var rating: String
    var proposedPoints: Double
    var finalPoints: Double
    var explanation: String
    var teacherApproved: Bool
    var teacherRationale: String

    init(_ score: FinalCriterionScore, finalReviewID: UUID, sortOrder: Int) {
        id = score.id
        self.finalReviewID = finalReviewID
        self.sortOrder = sortOrder
        criterionID = score.criterionID
        criterionTitle = score.title
        maxPoints = score.maxPoints
        rating = score.rating
        proposedPoints = score.proposedPoints
        finalPoints = score.finalPoints
        explanation = score.explanation
        teacherApproved = score.teacherApproved
        teacherRationale = score.teacherRationale
    }

    func score(evidenceIDs: [UUID]) -> FinalCriterionScore {
        FinalCriterionScore(
            id: id,
            criterionID: criterionID,
            rating: rating,
            proposedPoints: proposedPoints,
            finalPoints: finalPoints,
            explanation: explanation,
            teacherApproved: teacherApproved,
            teacherRationale: teacherRationale,
            evidenceIDs: evidenceIDs,
            title: criterionTitle,
            maxPoints: maxPoints
        )
    }
}

struct FinalCriterionEvidenceID: Hashable, Sendable {
    var finalReviewCriterionID: UUID
    var evidenceID: UUID
}

struct FinalCriterionEvidenceRow: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "finalCriterionEvidence"

    var finalReviewCriterionID: UUID
    var evidenceID: UUID
    var sortOrder: Int

    var id: FinalCriterionEvidenceID {
        FinalCriterionEvidenceID(finalReviewCriterionID: finalReviewCriterionID, evidenceID: evidenceID)
    }
}
