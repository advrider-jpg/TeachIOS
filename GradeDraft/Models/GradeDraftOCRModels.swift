import CoreGraphics
import Foundation
import GRDB

// MARK: - Source input

enum SourceType: String, CaseIterable, Codable, Identifiable, Sendable {
    case pastedText
    case scan
    case photo
    case pdf
    case handwrittenWork
    case visualArtifact

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pastedText: return "Pasted text"
        case .scan: return "Document scan"
        case .photo: return "Imported photo"
        case .pdf: return "PDF"
        case .handwrittenWork: return "Handwritten work"
        case .visualArtifact: return "Visual artifact"
        }
    }
}

/// A source file (scan page, photo, original PDF) kept on the device for one submission.
struct SourceInputRef: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "sourceInput"

    var id: UUID
    var submissionID: UUID
    var sourceType: SourceType
    var pageIndex: Int?
    /// `Sources/<submissionID>/<file>`, relative to `AppDatabase.storageDirectory`.
    var localRelativePath: String?
    var fileName: String?
    var mimeType: String?
    var sha256: String?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var pdfPageCount: Int?
    var includedInTeacherArchive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        submissionID: UUID,
        sourceType: SourceType,
        pageIndex: Int? = nil,
        localRelativePath: String? = nil,
        fileName: String? = nil,
        mimeType: String? = nil,
        sha256: String? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        pdfPageCount: Int? = nil,
        includedInTeacherArchive: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.submissionID = submissionID
        self.sourceType = sourceType
        self.pageIndex = pageIndex
        self.localRelativePath = localRelativePath
        self.fileName = fileName
        self.mimeType = mimeType
        self.sha256 = sha256
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.pdfPageCount = pdfPageCount
        self.includedInTeacherArchive = includedInTeacherArchive
        self.createdAt = createdAt
    }
}

// MARK: - Scanned text

enum OCRReviewStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case notNeeded
    case needsReview
    case reviewed
    case blocked

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notNeeded: return "Ready for teacher review"
        case .needsReview: return "Review scanned text"
        case .reviewed: return "Ready for teacher review"
        case .blocked: return "Text needs attention"
        }
    }

    var blocksGrading: Bool {
        self == .needsReview || self == .blocked
    }
}

enum OCRLineOrigin: String, CaseIterable, Codable, Equatable, Sendable {
    /// Recognised by Apple Vision from an image.
    case visionOCR
    /// Read from a typed PDF's own text layer (no confidence score).
    case pdfTextLayer
}

/// Scanned text for one submission, assembled by `AppDatabase` from its document, page and line rows.
struct OCRDocument: Identifiable, Codable, Equatable, Sendable {
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

    private var orderedPages: [OCRPage] {
        pages.sorted { $0.pageIndex < $1.pageIndex }
    }

    var rawCombinedText: String {
        orderedPages
            .map { $0.lines.map(\.rawText).joined(separator: "\n") }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }

    /// The teacher-reviewed text: corrected or raw text of every line that was not rejected.
    var combinedText: String {
        orderedPages
            .map { page in
                page.lines
                    .filter { !$0.isRejected }
                    .map(\.reviewedText)
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .joined(separator: "\n")
            }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }

    var allLines: [OCRLine] {
        pages.flatMap(\.lines)
    }

    var activeLines: [OCRLine] {
        allLines.filter { !$0.isRejected }
    }

    var hasLowConfidenceText: Bool {
        activeLines.contains(where: \.isLowConfidence)
    }

    var unresolvedLineCount: Int {
        activeLines.filter(\.needsReview).count
    }

    var qualitySummary: OCRQualitySummary {
        OCRQualitySummary(lines: allLines)
    }

    /// "Confirm all": confirms only Vision lines at or above the confidence threshold. Low-confidence
    /// lines and PDF text-layer lines still need the teacher's line-by-line action.
    func markingAllLinesConfirmed(reviewedAt: Date = Date()) -> OCRDocument {
        var copy = self
        copy.pages = copy.pages.map { page in
            var page = page
            page.lines = page.lines.map { line in
                var line = line
                if !line.isRejected, line.origin == .visionOCR, !line.isLowConfidence {
                    line.teacherConfirmed = true
                }
                return line
            }
            return page
        }
        if copy.unresolvedLineCount == 0 {
            copy.reviewStatus = .reviewed
            copy.reviewedAt = reviewedAt
        } else {
            copy.reviewStatus = .needsReview
            copy.reviewedAt = nil
        }
        return copy
    }

    func pageReviewStatus(pageID: UUID) -> OCRReviewStatus {
        guard let page = pages.first(where: { $0.id == pageID }) else { return .blocked }
        return page.unresolvedLineCount > 0 ? .needsReview : .reviewed
    }
}

struct OCRPage: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var sourceInputID: UUID?
    var pageIndex: Int
    var pixelWidth: Int?
    var pixelHeight: Int?
    /// In reading order.
    var lines: [OCRLine]

    init(
        id: UUID = UUID(),
        sourceInputID: UUID? = nil,
        pageIndex: Int,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        lines: [OCRLine]
    ) {
        self.id = id
        self.sourceInputID = sourceInputID
        self.pageIndex = pageIndex
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.lines = lines
    }

    var unresolvedLineCount: Int {
        lines.filter(\.needsReview).count
    }
}

struct OCRLine: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var rawText: String
    var correctedText: String?
    var origin: OCRLineOrigin
    /// Vision's confidence; nil for PDF text-layer lines.
    var confidence: Float?
    /// Normalised to the page, bottom-left origin (Vision's convention).
    var boundingBox: NormalizedRect?
    var paragraphIndex: Int?
    var teacherConfirmed: Bool
    var isRejected: Bool

    init(
        id: UUID = UUID(),
        text: String,
        confidence: Float?,
        boundingBox: NormalizedRect?,
        origin: OCRLineOrigin,
        paragraphIndex: Int? = nil,
        correctedText: String? = nil,
        teacherConfirmed: Bool = false,
        isRejected: Bool = false
    ) {
        self.id = id
        self.rawText = text
        self.correctedText = correctedText
        self.origin = origin
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.paragraphIndex = paragraphIndex
        self.teacherConfirmed = teacherConfirmed
        self.isRejected = isRejected
    }

    var reviewedText: String {
        guard !isRejected else { return "" }
        if let corrected = correctedText?.trimmingCharacters(in: .whitespacesAndNewlines), !corrected.isEmpty {
            return corrected
        }
        return rawText
    }

    /// A Vision line below the threshold (or with no score). Text-layer lines have no confidence to judge.
    var isLowConfidence: Bool {
        guard origin == .visionOCR else { return false }
        guard let confidence else { return true }
        return confidence < OCRQualitySummary.lowConfidenceThreshold
    }

    /// Text-layer lines always need the teacher's action; Vision lines only when low-confidence.
    var needsReview: Bool {
        guard !teacherConfirmed, !isRejected else { return false }
        switch origin {
        case .pdfTextLayer: return true
        case .visionOCR: return isLowConfidence
        }
    }

    var reviewStatusLabel: String {
        if isRejected { return "Text needs attention" }
        if teacherConfirmed { return "On track" }
        if correctedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { return "Fix before continuing" }
        return needsReview ? "Needs attention" : "On track"
    }
}

struct OCRLineCorrection: Equatable, Sendable {
    var pageID: UUID
    var lineID: UUID
    var correctedText: String
}

struct OCRQualitySummary: Codable, Equatable, Sendable {
    static let lowConfidenceThreshold: Float = 0.70

    var lineCount: Int
    var lowConfidenceLineCount: Int
    var textLayerLineCount: Int
    var unresolvedLineCount: Int
    /// Average Vision confidence; nil when no line has a confidence score.
    var averageConfidence: Float?
    var minimumConfidence: Float?
    var rejectedLineCount: Int

    init(
        lineCount: Int = 0,
        lowConfidenceLineCount: Int = 0,
        textLayerLineCount: Int = 0,
        unresolvedLineCount: Int = 0,
        averageConfidence: Float? = nil,
        minimumConfidence: Float? = nil,
        rejectedLineCount: Int = 0
    ) {
        self.lineCount = lineCount
        self.lowConfidenceLineCount = lowConfidenceLineCount
        self.textLayerLineCount = textLayerLineCount
        self.unresolvedLineCount = unresolvedLineCount
        self.averageConfidence = averageConfidence
        self.minimumConfidence = minimumConfidence
        self.rejectedLineCount = rejectedLineCount
    }

    init(lines: [OCRLine]) {
        rejectedLineCount = lines.filter(\.isRejected).count
        let activeLines = lines.filter { !$0.isRejected }
        lineCount = activeLines.count
        lowConfidenceLineCount = activeLines.filter(\.isLowConfidence).count
        textLayerLineCount = activeLines.filter { $0.origin == .pdfTextLayer }.count
        unresolvedLineCount = activeLines.filter(\.needsReview).count
        let scores = activeLines.compactMap(\.confidence)
        averageConfidence = scores.isEmpty ? nil : scores.reduce(0, +) / Float(scores.count)
        minimumConfidence = scores.min()
    }

    var requiresTeacherOCRReview: Bool {
        unresolvedLineCount > 0
    }

    var displaySummary: String {
        guard lineCount > 0 || rejectedLineCount > 0 else {
            return "No scanned text has been captured."
        }
        var parts: [String] = []
        if unresolvedLineCount == 0 {
            parts.append("Text recognition captured \(lineCount) reviewed text line(s).")
        } else {
            parts.append("Text recognition captured \(lineCount) text line(s); \(unresolvedLineCount) still need teacher review (\(lowConfidenceLineCount) low-confidence).")
        }
        if let averageConfidence {
            parts.append("Average confidence \(Int((averageConfidence * 100).rounded()))%.")
        }
        if textLayerLineCount > 0 {
            parts.append("\(textLayerLineCount) line(s) came from the PDF text layer.")
        }
        if rejectedLineCount > 0 {
            parts.append("\(rejectedLineCount) rejected line(s) excluded from reviewed text.")
        }
        return parts.joined(separator: " ")
    }
}

// swiftlint:disable identifier_name
struct NormalizedRect: Codable, Equatable, Sendable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    static let zero = NormalizedRect(x: 0, y: 0, width: 0, height: 0)

    var stableDisplay: String {
        "x:\(Self.format(x)) y:\(Self.format(y)) w:\(Self.format(width)) h:\(Self.format(height))"
    }

    private static func format(_ value: CGFloat) -> String {
        String(format: "%.4f", Double(value))
    }
}
// swiftlint:enable identifier_name
