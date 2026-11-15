import CoreGraphics
import Foundation
import GRDB

enum EvidenceSourceKind: String, CaseIterable, Codable, Equatable, Sendable {
    /// A quote taken from a scanned-text line.
    case ocrLine
    /// A quote the teacher typed or selected from the reviewed text.
    case manualTeacherEntry
}

/// A quote from the student's work that supports a final criterion score.
struct EvidenceReference: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "evidence"

    var id: UUID
    var submissionID: UUID
    var ocrLineID: UUID?
    var pageIndex: Int?
    var quote: String
    var startOffset: Int?
    var endOffset: Int?
    var bboxX: Double?
    var bboxY: Double?
    var bboxWidth: Double?
    var bboxHeight: Double?
    var sourceKind: EvidenceSourceKind
    var teacherConfirmed: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        submissionID: UUID,
        ocrLineID: UUID? = nil,
        pageIndex: Int? = nil,
        quote: String,
        startOffset: Int? = nil,
        endOffset: Int? = nil,
        boundingBox: NormalizedRect? = nil,
        sourceKind: EvidenceSourceKind,
        teacherConfirmed: Bool,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.submissionID = submissionID
        self.ocrLineID = ocrLineID
        self.pageIndex = pageIndex
        self.quote = quote
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.sourceKind = sourceKind
        self.teacherConfirmed = teacherConfirmed
        self.createdAt = createdAt
        self.boundingBox = boundingBox
    }

    /// The highlighted region on the page, stored as the four `bbox` columns.
    var boundingBox: NormalizedRect? {
        get {
            guard let bboxX, let bboxY, let bboxWidth, let bboxHeight else { return nil }
            return NormalizedRect(x: CGFloat(bboxX), y: CGFloat(bboxY), width: CGFloat(bboxWidth), height: CGFloat(bboxHeight))
        }
        set {
            bboxX = newValue.map { Double($0.x) }
            bboxY = newValue.map { Double($0.y) }
            bboxWidth = newValue.map { Double($0.width) }
            bboxHeight = newValue.map { Double($0.height) }
        }
    }

    var displaySource: String {
        let page = pageIndex.map { "page \($0 + 1)" } ?? "reviewed text"
        if let ocrLineID { return "\(page), text line \(ocrLineID.uuidString.prefix(8))" }
        return page
    }
}
