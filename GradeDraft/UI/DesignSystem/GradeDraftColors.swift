import SwiftUI

enum GradeDraftUIStatus: String, CaseIterable, Identifiable {
    case notStarted = "Not started"
    case addStudentWork = "Add student work"
    case reviewScannedText = "Review scanned text"
    case textNeedsAttention = "Text needs attention"
    case readyForTeacherReview = "Ready for teacher review"
    case inProgress = "In progress"
    case reviewFinalGrade = "Review final grade"
    case needsRecheck = "Needs recheck"
    case approved = "Approved"
    case readyToExport = "Ready to export"
    case exported = "Exported"
    case studentFacing = "Student-facing"
    case teacherOnly = "Teacher-only"
    case fixBeforeContinuing = "Fix before continuing"
    case needsAttention = "Needs attention"
    case onTrack = "On track"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .addStudentWork, .reviewScannedText, .reviewFinalGrade, .needsRecheck, .needsAttention:
            return .orange
        case .textNeedsAttention, .fixBeforeContinuing:
            return .red
        case .readyForTeacherReview, .approved, .readyToExport, .studentFacing, .onTrack:
            return .green
        case .inProgress:
            return .blue
        case .notStarted, .exported, .teacherOnly:
            return .gray
        }
    }

    var systemImage: String {
        switch self {
        case .notStarted:
            return "circle"
        case .addStudentWork:
            return "plus.circle"
        case .reviewScannedText:
            return "text.viewfinder"
        case .textNeedsAttention:
            return "exclamationmark.octagon"
        case .readyForTeacherReview:
            return "person.badge.checkmark"
        case .inProgress:
            return "arrow.triangle.2.circlepath"
        case .reviewFinalGrade:
            return "checklist"
        case .needsRecheck:
            return "arrow.clockwise.circle"
        case .approved:
            return "checkmark.seal"
        case .readyToExport:
            return "square.and.arrow.up"
        case .exported:
            return "tray.and.arrow.up"
        case .studentFacing:
            return "person.crop.circle.badge.checkmark"
        case .teacherOnly:
            return "lock"
        case .fixBeforeContinuing:
            return "xmark.octagon"
        case .needsAttention:
            return "exclamationmark.triangle"
        case .onTrack:
            return "checkmark.circle"
        }
    }

    var accessibilityConsequence: String {
        switch self {
        case .studentFacing:
            return "Suitable for students or families."
        case .teacherOnly:
            return "For teacher records only."
        case .fixBeforeContinuing, .textNeedsAttention:
            return "A required issue must be fixed before continuing."
        case .needsRecheck:
            return "Recheck because student work, rubric, or evidence changed."
        case .reviewScannedText:
            return "Teacher text review is required."
        default:
            return rawValue
        }
    }
}



// Visible workflow copy is centralized to keep v6 labels consistent across compact rows and deep screens.
enum GradeDraftWorkflowLanguage {
    static let ocrReviewStepLabel = "OCR Review"
    static let reviewScannedTextScreenTitle = "Review Scanned Text"
    static let reviewTextActionLabel = "Review Text"
    static let reviewScannedTextExplanation = "Review scanned text before drafting feedback."
}

extension GradeDraftUIStatus {
    var chipLabel: String {
        switch self {
        case .reviewScannedText:
            return "Review text"
        case .fixBeforeContinuing:
            return "Fix first"
        case .readyForTeacherReview:
            return "Ready"
        case .needsRecheck:
            return "Recheck"
        case .studentFacing:
            return "Student-facing"
        case .teacherOnly:
            return "Teacher-only"
        case .readyToExport:
            return "Ready to export"
        case .textNeedsAttention:
            return "Text attention"
        case .reviewFinalGrade:
            return "Final review"
        case .addStudentWork:
            return "Add work"
        case .needsAttention:
            return "Attention"
        default:
            return rawValue
        }
    }

    var fullAccessibilityLabel: String {
        switch self {
        case .reviewScannedText:
            return "Review scanned text. Teacher text review is required."
        case .fixBeforeContinuing:
            return "Fix before continuing. A required issue must be fixed before continuing."
        case .readyForTeacherReview:
            return "Ready for teacher review. Required setup is complete and the teacher can review."
        case .needsRecheck:
            return "Needs recheck. Recheck because student work, rubric, or evidence changed."
        default:
            return "\(rawValue). \(accessibilityConsequence)"
        }
    }
}

extension AssignmentRosterStatus {
    var v6Status: GradeDraftUIStatus {
        switch self {
        case .notStarted:
            return .notStarted
        case .sourceNeeded:
            return .addStudentWork
        case .ocrReviewNeeded:
            return .reviewScannedText
        case .readyForGrading:
            return .readyForTeacherReview
        case .draftGenerated, .finalReviewInProgress:
            return .reviewFinalGrade
        case .needsRecheck:
            return .needsRecheck
        case .approved:
            return .approved
        case .exported:
            return .exported
        }
    }
}


extension OCRReviewStatus {
    var v6Status: GradeDraftUIStatus {
        switch self {
        case .notNeeded:
            return .readyForTeacherReview
        case .needsReview:
            return .reviewScannedText
        case .reviewed:
            return .readyForTeacherReview
        case .blocked:
            return .textNeedsAttention
        }
    }
}


extension FinalReviewStatus {
    var v6Status: GradeDraftUIStatus {
        switch self {
        case .inProgress:
            return .reviewFinalGrade
        case .approved:
            return .approved
        case .stale:
            return .needsRecheck
        }
    }
}


extension ExportKind {
    var v6DisplayName: String {
        switch self {
        case .studentMarkdown:
            return "Student Report"
        case .teacherAuditMarkdown:
            return "Teacher Review"
        case .studentPDF:
            return "Student Report PDF"
        case .teacherAuditPDF:
            return "Teacher Review PDF"
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

    var v6AudienceStatus: GradeDraftUIStatus {
        switch self {
        case .studentMarkdown, .studentPDF:
            return .studentFacing
        case .teacherAuditMarkdown, .teacherAuditPDF, .csvGradebook, .zipArchive, .fullBackupArchive, .backupJSON, .assignmentGradebookArchive:
            return .teacherOnly
        }
    }
}
