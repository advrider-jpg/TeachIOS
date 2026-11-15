import Foundation
import GRDB

// MARK: - Export and audit

enum ExportKind: String, Codable, Equatable, Hashable, Identifiable, Sendable {
    case studentMarkdown
    case teacherAuditMarkdown
    case studentPDF
    case teacherAuditPDF
    case csvGradebook
    case zipArchive
    case fullBackupArchive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .studentMarkdown:
            return "Student Report"
        case .teacherAuditMarkdown:
            return "Teacher Record"
        case .studentPDF:
            return "Student Report PDF"
        case .teacherAuditPDF:
            return "Teacher Record PDF"
        case .csvGradebook:
            return "Gradebook CSV"
        case .zipArchive:
            return "Teacher Archive"
        case .fullBackupArchive:
            return "Full Backup"
        }
    }
}


enum DeviceBackupPolicyStatus: Equatable, Sendable {
    case excluded
    case included
    case unknown(String)

    var isExcluded: Bool {
        if case .excluded = self { return true }
        return false
    }

    var summary: String {
        switch self {
        case .excluded:
            return "Student records are marked to stay out of device backup where the platform supports this file setting."
        case .included:
            return "Student records may be included in device backup according to this device and account configuration."
        case .unknown(let detail):
            return "MarkForMe could not verify whether local student records are excluded from device backup. \(detail)"
        }
    }
}

/// One export the teacher prepared. `assignmentID == nil` is a full backup; `submissionID == nil`
/// is a class-level export (for example the gradebook CSV).
struct ExportRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "exportRecord"

    var id: UUID
    var assignmentID: UUID?
    var submissionID: UUID?
    var kind: ExportKind
    var createdAt: Date
    var contentSHA256: String
    var includesPrivateTeacherNotes: Bool
    var includesOriginalSources: Bool

    init(
        id: UUID = UUID(),
        assignmentID: UUID?,
        submissionID: UUID?,
        kind: ExportKind,
        createdAt: Date = Date(),
        contentSHA256: String,
        includesPrivateTeacherNotes: Bool,
        includesOriginalSources: Bool
    ) {
        self.id = id
        self.assignmentID = assignmentID
        self.submissionID = submissionID
        self.kind = kind
        self.createdAt = createdAt
        self.contentSHA256 = contentSHA256
        self.includesPrivateTeacherNotes = includesPrivateTeacherNotes
        self.includesOriginalSources = includesOriginalSources
    }
}

enum AuditEventType: String, Codable, Equatable, Sendable {
    case assignmentCreated
    case sourceCaptured
    case ocrCompleted
    case ocrReviewed
    case inputChanged
    case draftGenerated
    case draftMarkedStale
    case finalReviewMarkedStale
    case localFileCleanupFailed
    case finalReviewStarted
    case finalApproved
    case feedbackRewritten
    case exportPrepared
    case persistenceSaved
}

/// A review-log entry. `submissionID == nil` is an assignment-level event.
struct AuditEvent: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "auditEvent"

    var id: UUID
    var assignmentID: UUID
    var submissionID: UUID?
    var timestamp: Date
    var eventType: AuditEventType
    var actor: String
    var detail: String

    init(
        id: UUID = UUID(),
        assignmentID: UUID,
        submissionID: UUID?,
        timestamp: Date = Date(),
        eventType: AuditEventType,
        actor: String = "teacher-or-local-system",
        detail: String
    ) {
        self.id = id
        self.assignmentID = assignmentID
        self.submissionID = submissionID
        self.timestamp = timestamp
        self.eventType = eventType
        self.actor = actor
        self.detail = detail
    }
}
