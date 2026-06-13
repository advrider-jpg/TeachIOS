import CoreGraphics
import Foundation

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
    var fileName: String?
    var mimeType: String?
    var contentDigest: String?
    var digestAlgorithm: String?
    var imageWidth: Double?
    var imageHeight: Double?
    var pdfPageCount: Int?
    var teacherIncludedInExport: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sourceType: SourceType,
        pageIndex: Int? = nil,
        localRelativePath: String? = nil,
        fileName: String? = nil,
        mimeType: String? = nil,
        contentDigest: String? = nil,
        digestAlgorithm: String? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        pdfPageCount: Int? = nil,
        teacherIncludedInExport: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceType = sourceType
        self.pageIndex = pageIndex
        self.localRelativePath = localRelativePath
        self.fileName = fileName
        self.mimeType = mimeType
        self.contentDigest = contentDigest
        self.digestAlgorithm = digestAlgorithm
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.pdfPageCount = pdfPageCount
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
            return "Ready for teacher review"
        case .needsReview:
            return "Review scanned text"
        case .reviewed:
            return "Ready for teacher review"
        case .blocked:
            return "Text needs attention"
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
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }

    var combinedText: String {
        pages
            .sorted { $0.pageIndex < $1.pageIndex }
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
        activeLines.contains { $0.confidence < OCRQualitySummary.lowConfidenceThreshold }
    }

    var hasUnconfirmedLines: Bool {
        activeLines.contains { !$0.teacherConfirmed }
    }

    var unresolvedLineCount: Int {
        activeLines.filter { $0.needsReview }.count
    }

    var qualitySummary: OCRQualitySummary {
        OCRQualitySummary(lines: allLines)
    }

    func markingAllLinesConfirmed(reviewedAt: Date = Date()) -> OCRDocument {
        var copy = self
        copy.pages = copy.pages.map { page in
            var page = page
            page.lines = page.lines.map { line in
                var line = line
                if !line.isRejected && line.confidence >= OCRQualitySummary.lowConfidenceThreshold {
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
        return page.lines.filter { !$0.isRejected }.contains { !$0.teacherConfirmed } ? .needsReview : .reviewed
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

    var unresolvedLineCount: Int {
        lines.filter { $0.needsReview }.count
    }
}

struct OCRLine: Identifiable, Codable, Equatable {
    var id: UUID
    var rawText: String
    var correctedText: String?
    var confidence: Float
    var boundingBox: NormalizedRect
    var teacherConfirmed: Bool
    var isRejected: Bool

    init(
        id: UUID = UUID(),
        text: String,
        confidence: Float,
        boundingBox: NormalizedRect,
        correctedText: String? = nil,
        teacherConfirmed: Bool = false,
        isRejected: Bool = false
    ) {
        self.id = id
        self.rawText = text
        self.correctedText = correctedText
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.teacherConfirmed = teacherConfirmed
        self.isRejected = isRejected
    }

    private enum CodingKeys: String, CodingKey {
        case id, rawText, correctedText, confidence, boundingBox, teacherConfirmed, isRejected
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        rawText = try container.decode(String.self, forKey: .rawText)
        correctedText = try container.decodeIfPresent(String.self, forKey: .correctedText)
        confidence = try container.decode(Float.self, forKey: .confidence)
        boundingBox = try container.decode(NormalizedRect.self, forKey: .boundingBox)
        teacherConfirmed = try container.decode(Bool.self, forKey: .teacherConfirmed)
        isRejected = (try? container.decode(Bool.self, forKey: .isRejected)) ?? false
    }

    var text: String {
        reviewedText
    }

    var reviewedText: String {
        guard !isRejected else { return "" }
        let corrected = correctedText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return corrected?.isEmpty == false ? corrected! : rawText
    }

    var needsReview: Bool {
        guard !isRejected else { return false }
        return confidence < OCRQualitySummary.lowConfidenceThreshold || !teacherConfirmed
    }

    var reviewStatusLabel: String {
        if isRejected { return "Text needs attention" }
        if teacherConfirmed { return "On track" }
        if correctedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { return "Fix before continuing" }
        return "Needs attention"
    }
}

struct OCRLineCorrection: Equatable {
    var pageID: UUID
    var lineID: UUID
    var correctedText: String

    init(pageID: UUID, lineID: UUID, correctedText: String) {
        self.pageID = pageID
        self.lineID = lineID
        self.correctedText = correctedText
    }
}

struct OCRQualitySummary: Codable, Equatable {
    static let lowConfidenceThreshold: Float = 0.70

    var lineCount: Int
    var lowConfidenceLineCount: Int
    var unconfirmedLineCount: Int
    var averageConfidence: Float
    var minimumConfidence: Float?
    var rejectedLineCount: Int

    init(
        lineCount: Int = 0,
        lowConfidenceLineCount: Int = 0,
        unconfirmedLineCount: Int = 0,
        averageConfidence: Float = 0,
        minimumConfidence: Float? = nil,
        rejectedLineCount: Int = 0
    ) {
        self.lineCount = lineCount
        self.lowConfidenceLineCount = lowConfidenceLineCount
        self.unconfirmedLineCount = unconfirmedLineCount
        self.averageConfidence = averageConfidence
        self.minimumConfidence = minimumConfidence
        self.rejectedLineCount = rejectedLineCount
    }

    private enum CodingKeys: String, CodingKey {
        case lineCount, lowConfidenceLineCount, unconfirmedLineCount, averageConfidence, minimumConfidence, rejectedLineCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lineCount = try container.decode(Int.self, forKey: .lineCount)
        lowConfidenceLineCount = try container.decode(Int.self, forKey: .lowConfidenceLineCount)
        unconfirmedLineCount = try container.decode(Int.self, forKey: .unconfirmedLineCount)
        averageConfidence = try container.decode(Float.self, forKey: .averageConfidence)
        minimumConfidence = try container.decodeIfPresent(Float.self, forKey: .minimumConfidence)
        rejectedLineCount = (try? container.decode(Int.self, forKey: .rejectedLineCount)) ?? 0
    }

    init(lines: [OCRLine]) {
        rejectedLineCount = lines.filter(\.isRejected).count
        let activeLines = lines.filter { !$0.isRejected }
        lineCount = activeLines.count
        lowConfidenceLineCount = activeLines.filter { $0.confidence < Self.lowConfidenceThreshold }.count
        unconfirmedLineCount = activeLines.filter { !$0.teacherConfirmed }.count
        if activeLines.isEmpty {
            averageConfidence = 0
            minimumConfidence = nil
        } else {
            averageConfidence = activeLines.map(\.confidence).reduce(0, +) / Float(activeLines.count)
            minimumConfidence = activeLines.map(\.confidence).min()
        }
    }

    var requiresTeacherOCRReview: Bool {
        lowConfidenceLineCount > 0 || unconfirmedLineCount > 0
    }

    var displaySummary: String {
        guard lineCount > 0 || rejectedLineCount > 0 else {
            return "No scanned text has been captured."
        }
        let average = Int((averageConfidence * 100).rounded())
        let rejectedText = rejectedLineCount > 0 ? " \(rejectedLineCount) rejected line(s) excluded from reviewed text." : ""
        if lowConfidenceLineCount == 0 && unconfirmedLineCount == 0 {
            return "Text recognition captured \(lineCount) confirmed text line(s) with average confidence \(average)%.\(rejectedText)"
        }
        return "Text recognition captured \(lineCount) text line(s); \(lowConfidenceLineCount) low-confidence and \(unconfirmedLineCount) unconfirmed. Average confidence \(average)%.\(rejectedText)"
    }
}

// swiftlint:disable identifier_name
struct NormalizedRect: Codable, Equatable {
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
