import CoreGraphics
import Foundation

// MARK: - Export and audit

enum ExportKind: String, Codable, Equatable, Hashable, Identifiable {
    case studentMarkdown
    case teacherAuditMarkdown
    case studentPDF
    case teacherAuditPDF
    case csvGradebook
    case zipArchive
    case fullBackupArchive
    case backupJSON
    case assignmentGradebookArchive

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
        case .backupJSON:
            return "Full Backup"
        case .assignmentGradebookArchive:
            return "Gradebook Archive"
        }
    }
}


enum DeviceBackupPolicyStatus: Equatable {
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

struct ExportRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var exportKind: ExportKind
    var createdAt: Date
    var contentFingerprint: String
    var includesPrivateTeacherNotes: Bool
    var includesOriginalSources: Bool

    init(
        id: UUID = UUID(),
        exportKind: ExportKind,
        createdAt: Date = Date(),
        contentFingerprint: String,
        includesPrivateTeacherNotes: Bool,
        includesOriginalSources: Bool
    ) {
        self.id = id
        self.exportKind = exportKind
        self.createdAt = createdAt
        self.contentFingerprint = contentFingerprint
        self.includesPrivateTeacherNotes = includesPrivateTeacherNotes
        self.includesOriginalSources = includesOriginalSources
    }
}

enum AuditEventType: String, Codable, Equatable {
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
