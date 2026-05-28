import CoreGraphics
import Foundation

// MARK: - Stable local fingerprints

/// A deterministic local fingerprint used to detect stale grading packets and source changes.
/// This is intentionally not represented as encryption or authentication. It is an app-state
/// fingerprint for offline recordkeeping, not a security boundary.
enum StableFingerprint {
    static func fingerprint(_ components: [String]) -> String {
        fingerprint(Data(components.joined(separator: "\u{001F}").utf8))
    }

    static func fingerprint(_ data: Data) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "fnv1a64-%016llx", hash)
    }
}

// MARK: - Assignment and classroom records

struct AssignmentRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var subject: String
    var gradeLevel: String
    var className: String
    var studentDisplayName: String
    var assignmentType: AssignmentType
    var rubricText: String
    var customInstructions: String
    var answerKeyText: String
    var exemplarText: String
    var reviewedStudentText: String
    var sourceInputs: [SourceInputRef]
    var ocrDocument: OCRDocument?
    var ocrReviewStatus: OCRReviewStatus
    var ocrReviewedAt: Date?
    var latestDraft: GradeDraftResult?
    var finalReview: FinalGradeReview?
    var exportRecords: [ExportRecord]
    var auditEvents: [AuditEvent]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "New Assignment",
        subject: String = "",
        gradeLevel: String = "",
        className: String = "",
        studentDisplayName: String = "",
        assignmentType: AssignmentType = .shortAnswer,
        rubricText: String = "",
        customInstructions: String = "",
        answerKeyText: String = "",
        exemplarText: String = "",
        reviewedStudentText: String = "",
        sourceInputs: [SourceInputRef] = [],
        ocrDocument: OCRDocument? = nil,
        ocrReviewStatus: OCRReviewStatus = .notNeeded,
        ocrReviewedAt: Date? = nil,
        latestDraft: GradeDraftResult? = nil,
        finalReview: FinalGradeReview? = nil,
        exportRecords: [ExportRecord] = [],
        auditEvents: [AuditEvent] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.subject = subject
        self.gradeLevel = gradeLevel
        self.className = className
        self.studentDisplayName = studentDisplayName
        self.assignmentType = assignmentType
        self.rubricText = rubricText
        self.customInstructions = customInstructions
        self.answerKeyText = answerKeyText
        self.exemplarText = exemplarText
        self.reviewedStudentText = reviewedStudentText
        self.sourceInputs = sourceInputs
        self.ocrDocument = ocrDocument
        self.ocrReviewStatus = ocrReviewStatus
        self.ocrReviewedAt = ocrReviewedAt
        self.latestDraft = latestDraft
        self.finalReview = finalReview
        self.exportRecords = exportRecords
        self.auditEvents = auditEvents
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var assignmentInputReady: Bool {
        gradingInput.isReadyForGrading
    }

    var parsedRubric: ParsedRubric {
        RubricParser.parse(rubricText)
    }

    var gradingPacketFingerprint: String {
        StableFingerprint.fingerprint([
            title,
            subject,
            gradeLevel,
            assignmentType.rawValue,
            rubricText,
            customInstructions,
            answerKeyText,
            exemplarText,
            reviewedStudentText,
            ocrReviewStatus.rawValue,
            sourceInputs.map { $0.contentDigest ?? $0.id.uuidString }.joined(separator: "|")
        ])
    }

    var latestDraftIsStale: Bool {
        guard let latestDraft else { return false }
        return latestDraft.packetFingerprint != gradingPacketFingerprint
    }

    var finalReviewIsStale: Bool {
        guard let finalReview else { return false }
        return finalReview.packetFingerprint != gradingPacketFingerprint
    }

    var requiresOCRReviewBeforeGrading: Bool {
        ocrReviewStatus == .needsReview || ocrReviewStatus == .blocked
    }

    var gradingInput: GradingInput {
        GradingInput(
            assignmentID: id,
            assignmentTitle: title,
            subject: subject,
            gradeLevel: gradeLevel,
            className: className,
            studentDisplayName: studentDisplayName,
            assignmentType: assignmentType,
            rubricText: rubricText,
            parsedRubric: parsedRubric,
            customInstructions: customInstructions,
            answerKeyText: answerKeyText,
            exemplarText: exemplarText,
            reviewedStudentText: reviewedStudentText,
            ocrQualitySummary: ocrDocument?.qualitySummary ?? OCRQualitySummary(),
            ocrReviewStatus: ocrReviewStatus,
            sourceInputCount: sourceInputs.count,
            packetFingerprint: gradingPacketFingerprint
        )
    }

    mutating func appendAuditEvent(_ eventType: AuditEventType, detail: String) {
        auditEvents.append(AuditEvent(eventType: eventType, detail: detail))
    }
}

struct StudentRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var displayName: String
    var className: String
    var localIdentifier: String
    var isActive: Bool = true
}

struct ClassGroupRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var schoolYear: String
    var term: String
    var isArchived: Bool = false
}

enum AssignmentType: String, CaseIterable, Codable, Identifiable {
    case shortAnswer
    case essay
    case paragraphResponse
    case labWriteup
    case readingComprehension

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shortAnswer:
            return "Short answer"
        case .essay:
            return "Essay"
        case .paragraphResponse:
            return "Paragraph response"
        case .labWriteup:
            return "Lab write-up"
        case .readingComprehension:
            return "Reading comprehension"
        }
    }
}

// MARK: - Source input and OCR records

enum SourceType: String, CaseIterable, Codable, Identifiable {
    case pastedText
    case scan
    case photo
    case pdf
    case handwrittenWork
    case visualArtifact

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pastedText:
            return "Pasted text"
        case .scan:
            return "Document scan"
        case .photo:
            return "Imported photo"
        case .pdf:
            return "PDF"
        case .handwrittenWork:
            return "Handwritten work"
        case .visualArtifact:
            return "Visual artifact"
        }
    }
}

struct SourceInputRef: Identifiable, Codable, Equatable {
    var id: UUID
    var sourceType: SourceType
    var pageIndex: Int?
    var localRelativePath: String?
    var contentDigest: String?
    var digestAlgorithm: String?
    var imageWidth: Double?
    var imageHeight: Double?
    var teacherIncludedInExport: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sourceType: SourceType,
        pageIndex: Int? = nil,
        localRelativePath: String? = nil,
        contentDigest: String? = nil,
        digestAlgorithm: String? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        teacherIncludedInExport: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceType = sourceType
        self.pageIndex = pageIndex
        self.localRelativePath = localRelativePath
        self.contentDigest = contentDigest
        self.digestAlgorithm = digestAlgorithm
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.teacherIncludedInExport = teacherIncludedInExport
        self.createdAt = createdAt
    }
}

enum OCRReviewStatus: String, CaseIterable, Codable, Identifiable {
    case notNeeded
    case needsReview
    case reviewed
    case blocked

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notNeeded:
            return "No OCR review needed"
        case .needsReview:
            return "Needs OCR review"
        case .reviewed:
            return "OCR reviewed"
        case .blocked:
            return "OCR blocked"
        }
    }

    var blocksGrading: Bool {
        self == .needsReview || self == .blocked
    }
}

struct OCRDocument: Identifiable, Codable, Equatable {
    var id: UUID
    var engine: String
    var engineVersion: String
    var pages: [OCRPage]
    var createdAt: Date
    var reviewStatus: OCRReviewStatus
    var reviewedAt: Date?

    init(
        id: UUID = UUID(),
        engine: String = "Apple Vision",
        engineVersion: String = "system",
        pages: [OCRPage],
        createdAt: Date = Date(),
        reviewStatus: OCRReviewStatus = .needsReview,
        reviewedAt: Date? = nil
    ) {
        self.id = id
        self.engine = engine
        self.engineVersion = engineVersion
        self.pages = pages
        self.createdAt = createdAt
        self.reviewStatus = reviewStatus
        self.reviewedAt = reviewedAt
    }

    var rawCombinedText: String {
        pages
            .sorted { $0.pageIndex < $1.pageIndex }
            .map { $0.lines.map(\.rawText).joined(separator: "\n") }
            .joined(separator: "\n\n")
    }

    var combinedText: String {
        pages
            .sorted { $0.pageIndex < $1.pageIndex }
            .map { $0.lines.map(\.reviewedText).joined(separator: "\n") }
            .joined(separator: "\n\n")
    }

    var allLines: [OCRLine] {
        pages.flatMap(\.lines)
    }

    var hasLowConfidenceText: Bool {
        allLines.contains { $0.confidence < OCRQualitySummary.lowConfidenceThreshold }
    }

    var hasUnconfirmedLines: Bool {
        allLines.contains { !$0.teacherConfirmed }
    }

    var qualitySummary: OCRQualitySummary {
        OCRQualitySummary(lines: allLines)
    }

    func markingAllLinesConfirmed(reviewedAt: Date = Date()) -> OCRDocument {
        var copy = self
        copy.reviewStatus = .reviewed
        copy.reviewedAt = reviewedAt
        copy.pages = copy.pages.map { page in
            var page = page
            page.lines = page.lines.map { line in
                var line = line
                line.teacherConfirmed = true
                return line
            }
            return page
        }
        return copy
    }
}

struct OCRPage: Identifiable, Codable, Equatable {
    var id: UUID
    var sourceInputID: UUID?
    var pageIndex: Int
    var imageWidth: Double?
    var imageHeight: Double?
    var lines: [OCRLine]

    init(
        id: UUID = UUID(),
        sourceInputID: UUID? = nil,
        pageIndex: Int,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        lines: [OCRLine]
    ) {
        self.id = id
        self.sourceInputID = sourceInputID
        self.pageIndex = pageIndex
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.lines = lines
    }
}

struct OCRLine: Identifiable, Codable, Equatable {
    var id: UUID
    var rawText: String
    var correctedText: String?
    var confidence: Float
    var boundingBox: NormalizedRect
    var teacherConfirmed: Bool

    init(
        id: UUID = UUID(),
        text: String,
        confidence: Float,
        boundingBox: NormalizedRect,
        correctedText: String? = nil,
        teacherConfirmed: Bool = false
    ) {
        self.id = id
        self.rawText = text
        self.correctedText = correctedText
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.teacherConfirmed = teacherConfirmed
    }

    var text: String {
        reviewedText
    }

    var reviewedText: String {
        let corrected = correctedText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return corrected?.isEmpty == false ? corrected! : rawText
    }

    var needsReview: Bool {
        confidence < OCRQualitySummary.lowConfidenceThreshold || !teacherConfirmed
    }
}

struct OCRQualitySummary: Codable, Equatable {
    static let lowConfidenceThreshold: Float = 0.70

    var lineCount: Int
    var lowConfidenceLineCount: Int
    var unconfirmedLineCount: Int
    var averageConfidence: Float
    var minimumConfidence: Float?

    init(
        lineCount: Int = 0,
        lowConfidenceLineCount: Int = 0,
        unconfirmedLineCount: Int = 0,
        averageConfidence: Float = 0,
        minimumConfidence: Float? = nil
    ) {
        self.lineCount = lineCount
        self.lowConfidenceLineCount = lowConfidenceLineCount
        self.unconfirmedLineCount = unconfirmedLineCount
        self.averageConfidence = averageConfidence
        self.minimumConfidence = minimumConfidence
    }

    init(lines: [OCRLine]) {
        lineCount = lines.count
        lowConfidenceLineCount = lines.filter { $0.confidence < Self.lowConfidenceThreshold }.count
        unconfirmedLineCount = lines.filter { !$0.teacherConfirmed }.count
        if lines.isEmpty {
            averageConfidence = 0
            minimumConfidence = nil
        } else {
            averageConfidence = lines.map(\.confidence).reduce(0, +) / Float(lines.count)
            minimumConfidence = lines.map(\.confidence).min()
        }
    }

    var requiresTeacherOCRReview: Bool {
        lowConfidenceLineCount > 0 || unconfirmedLineCount > 0
    }

    var displaySummary: String {
        guard lineCount > 0 else {
            return "No OCR text has been captured."
        }
        let average = Int((averageConfidence * 100).rounded())
        if lowConfidenceLineCount == 0 && unconfirmedLineCount == 0 {
            return "OCR captured \(lineCount) confirmed text line(s) with average confidence \(average)%."
        }
        return "OCR captured \(lineCount) text line(s); \(lowConfidenceLineCount) low-confidence and \(unconfirmedLineCount) unconfirmed. Average confidence \(average)%."
    }
}

struct NormalizedRect: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    static let zero = NormalizedRect(x: 0, y: 0, width: 0, height: 0)
}

// MARK: - Rubric records

struct ParsedRubric: Codable, Equatable {
    var criteria: [RubricCriterion]
    var issues: [String]

    var isStructured: Bool {
        !criteria.isEmpty
    }
}

struct RubricCriterion: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var maxPoints: Double
    var descriptor: String
    var sortOrder: Int
}

struct RubricLevel: Identifiable, Codable, Equatable {
    var id: String
    var label: String
    var points: Double
    var descriptor: String
    var sortOrder: Int
}

enum RubricParser {
    static func parse(_ text: String) -> ParsedRubric {
        let lines = text.components(separatedBy: .newlines)
        var criteria: [RubricCriterion] = []
        var issues: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard !trimmed.hasPrefix("-") && !trimmed.hasPrefix("*") else { continue }
            guard let maxPoints = maxPoints(in: trimmed) else { continue }

            let title: String
            if let colon = trimmed.firstIndex(of: ":") {
                title = String(trimmed[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                title = trimmed.replacingOccurrences(of: #"\b\d+(?:\.\d+)?\s*(?:points?|pts?)\b"#, with: "", options: [.regularExpression, .caseInsensitive])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            guard !title.isEmpty else { continue }
            let order = criteria.count
            let id = "criterion-\(order + 1)-\(StableFingerprint.fingerprint([title, String(maxPoints)]).suffix(8))"
            criteria.append(
                RubricCriterion(
                    id: id,
                    title: title,
                    maxPoints: maxPoints,
                    descriptor: trimmed,
                    sortOrder: order
                )
            )
        }

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Rubric text is empty.")
        } else if criteria.isEmpty {
            issues.append("No explicit point-bearing criteria were detected. The model may still use the raw rubric text, but teacher review is required.")
        }

        return ParsedRubric(criteria: criteria, issues: issues)
    }

    private static func maxPoints(in line: String) -> Double? {
        let pattern = #"(?i)(?:0\s*[-–]\s*)?(\d+(?:\.\d+)?)\s*(?:points?|pts?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range), match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return Double(line[valueRange])
    }
}

// MARK: - Grading records

struct GradingInput: Codable, Equatable {
    var assignmentID: UUID
    var assignmentTitle: String
    var subject: String
    var gradeLevel: String
    var className: String
    var studentDisplayName: String
    var assignmentType: AssignmentType
    var rubricText: String
    var parsedRubric: ParsedRubric
    var customInstructions: String
    var answerKeyText: String
    var exemplarText: String
    var reviewedStudentText: String
    var ocrQualitySummary: OCRQualitySummary
    var ocrReviewStatus: OCRReviewStatus
    var sourceInputCount: Int
    var packetFingerprint: String

    var isReadyForGrading: Bool {
        !rubricText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
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
        rawModelResponse: String? = nil
    ) {
        self.id = id
        self.generatedAt = generatedAt
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
        teacherReviewRequired: Bool
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
            explanation: draft.explanation,
            teacherApproved: false,
            teacherRationale: draft.teacherReviewRequired ? "Review required by draft." : ""
        )
    }
}

// MARK: - Export and audit

enum ExportKind: String, Codable, Equatable, Identifiable {
    case studentMarkdown
    case teacherAuditMarkdown
    case backupJSON

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .studentMarkdown:
            return "Student Markdown report"
        case .teacherAuditMarkdown:
            return "Teacher audit Markdown report"
        case .backupJSON:
            return "Local JSON backup"
        }
    }
}

struct ExportRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var exportKind: ExportKind
    var createdAt: Date = Date()
    var contentFingerprint: String
    var includesPrivateTeacherNotes: Bool
    var includesOriginalSources: Bool
}

enum AuditEventType: String, Codable, Equatable {
    case assignmentCreated
    case sourceCaptured
    case ocrCompleted
    case ocrReviewed
    case inputChanged
    case draftGenerated
    case draftMarkedStale
    case finalReviewStarted
    case finalApproved
    case exportPrepared
    case persistenceSaved
}

struct AuditEvent: Identifiable, Codable, Equatable {
    var id: UUID
    var timestamp: Date
    var eventType: AuditEventType
    var actor: String
    var detail: String

    init(id: UUID = UUID(), timestamp: Date = Date(), eventType: AuditEventType, actor: String = "teacher-or-local-system", detail: String) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.actor = actor
        self.detail = detail
    }
}

// MARK: - Templates and errors

struct RubricTemplate: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var assignmentType: AssignmentType
    var description: String
    var rubricText: String
    var customInstructions: String
}

enum RubricTemplates {
    static let builtIn: [RubricTemplate] = [
        RubricTemplate(
            id: "short-answer-4pt",
            name: "4-point short answer",
            assignmentType: .shortAnswer,
            description: "Fast rubric for constructed responses and exit tickets.",
            rubricText: """
            Claim / direct answer: 0-1 point
            - 1: directly answers the question or makes a clear claim.
            - 0: does not answer the question or is off topic.

            Evidence / support: 0-2 points
            - 2: includes accurate, relevant evidence or details.
            - 1: includes partial, vague, or minimally relevant evidence.
            - 0: includes no relevant evidence.

            Explanation: 0-1 point
            - 1: explains how the evidence supports the answer.
            - 0: gives evidence without explanation or has no explanation.
            """,
            customInstructions: "Do not penalize spelling, grammar, or handwriting unless they materially interfere with meaning. Award equivalent wording when the meaning is correct."
        ),
        RubricTemplate(
            id: "paragraph-response-8pt",
            name: "8-point paragraph response",
            assignmentType: .paragraphResponse,
            description: "Claim, evidence, reasoning, and clarity for one-paragraph responses.",
            rubricText: """
            Clear claim/topic sentence: 0-2 points
            - 2: clear, focused claim that answers the prompt.
            - 1: claim is present but vague, incomplete, or only partly responsive.
            - 0: no clear claim.

            Relevant evidence: 0-2 points
            - 2: at least two accurate and relevant details, examples, or quotations.
            - 1: one relevant detail or partially relevant evidence.
            - 0: no relevant evidence.

            Reasoning/explanation: 0-2 points
            - 2: clearly explains how the evidence supports the claim.
            - 1: explanation is present but underdeveloped.
            - 0: no reasoning or explanation.

            Organization and clarity: 0-2 points
            - 2: coherent, complete paragraph with logical flow.
            - 1: understandable but choppy, repetitive, or incomplete.
            - 0: difficult to follow or not written as a response.
            """,
            customInstructions: "Keep feedback specific and actionable. Do not invent missing evidence. If OCR quality is uncertain, flag teacher review."
        ),
        RubricTemplate(
            id: "essay-20pt",
            name: "20-point essay",
            assignmentType: .essay,
            description: "General essay rubric for claim, structure, evidence, analysis, and conventions.",
            rubricText: """
            Thesis/claim: 0-4 points
            Evidence: 0-4 points
            Analysis/reasoning: 0-4 points
            Organization: 0-4 points
            Language/conventions: 0-4 points

            For each criterion:
            - 4: strong and complete.
            - 3: proficient with minor gaps.
            - 2: developing with meaningful gaps.
            - 1: minimal attempt.
            - 0: missing or off topic.
            """,
            customInstructions: "Use the rubric criteria exactly. The draft grade must cite text evidence for each criterion. Avoid comments about student ability, effort, or intent."
        ),
        RubricTemplate(
            id: "lab-writeup-16pt",
            name: "16-point lab write-up",
            assignmentType: .labWriteup,
            description: "For written science reports and lab conclusions.",
            rubricText: """
            Question / purpose: 0-2 points
            Hypothesis or prediction: 0-2 points
            Method / procedure summary: 0-3 points
            Data / observations: 0-3 points
            Conclusion: 0-3 points
            Scientific reasoning: 0-3 points
            """,
            customInstructions: "Grade only the written content provided. Do not infer experimental performance beyond the text. Flag missing data or unclear scientific vocabulary for teacher review."
        )
    ]
}

enum GradeDraftError: LocalizedError, Equatable {
    case missingRubric
    case missingStudentText
    case ocrReviewRequired
    case localModelUnavailable(String)
    case malformedModelResponse(String)
    case invalidModelGrade(String)
    case ocrFailed(String)
    case persistenceFailed(String)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingRubric:
            return "Add a rubric, answer key, or grading criteria before drafting a grade."
        case .missingStudentText:
            return "Add or review the student text before drafting a grade."
        case .ocrReviewRequired:
            return "Review and confirm OCR text before drafting a grade."
        case .localModelUnavailable(let message):
            return message
        case .malformedModelResponse(let message):
            return "The local model returned a response the app could not parse: \(message)"
        case .invalidModelGrade(let message):
            return "The local model returned an invalid grade draft: \(message)"
        case .ocrFailed(let message):
            return "OCR failed: \(message)"
        case .persistenceFailed(let message):
            return "Could not save local data: \(message)"
        case .exportFailed(let message):
            return "Could not export the local report: \(message)"
        }
    }
}
