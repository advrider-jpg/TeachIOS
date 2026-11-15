import SwiftUI

/// The workflow and audience states screens show. Each has a label, an icon, a system colour and the
/// spoken consequence VoiceOver reads.
enum GradeDraftUIStatus: String, CaseIterable, Identifiable, Sendable {
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
            return .secondary
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    var systemImage: String {
        switch self {
        case .notStarted: return "circle"
        case .addStudentWork: return "plus.circle"
        case .reviewScannedText: return "text.viewfinder"
        case .textNeedsAttention: return "exclamationmark.octagon"
        case .readyForTeacherReview: return "person.badge.checkmark"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .reviewFinalGrade: return "checklist"
        case .needsRecheck: return "arrow.clockwise.circle"
        case .approved: return "checkmark.seal"
        case .readyToExport: return "square.and.arrow.up"
        case .exported: return "tray.and.arrow.up"
        case .studentFacing: return "person.crop.circle.badge.checkmark"
        case .teacherOnly: return "lock"
        case .fixBeforeContinuing: return "xmark.octagon"
        case .needsAttention: return "exclamationmark.triangle"
        case .onTrack: return "checkmark.circle"
        }
    }

    /// What the state means for the teacher, read after the label.
    var accessibilityConsequence: String {
        switch self {
        case .studentFacing: return "Suitable for students or families."
        case .teacherOnly: return "For teacher records only."
        case .fixBeforeContinuing, .textNeedsAttention: return "A required issue must be fixed before continuing."
        case .needsRecheck: return "Recheck because student work, rubric, or evidence changed."
        case .reviewScannedText: return "Teacher text review is required."
        case .readyForTeacherReview: return "Required setup is complete and the teacher can review."
        default: return rawValue
        }
    }

    var fullAccessibilityLabel: String {
        accessibilityConsequence == rawValue ? rawValue : "\(rawValue). \(accessibilityConsequence)"
    }
}

extension RosterStatus {
    var uiStatus: GradeDraftUIStatus {
        switch self {
        case .notStarted: return .addStudentWork
        case .ocrReviewNeeded: return .reviewScannedText
        case .readyForGrading: return .readyForTeacherReview
        case .draftGenerated, .finalReviewInProgress: return .reviewFinalGrade
        case .needsRecheck: return .needsRecheck
        case .approved: return .approved
        case .exported: return .exported
        }
    }
}

extension OCRReviewStatus {
    var uiStatus: GradeDraftUIStatus {
        switch self {
        case .notNeeded, .reviewed: return .readyForTeacherReview
        case .needsReview: return .reviewScannedText
        case .blocked: return .textNeedsAttention
        }
    }
}

/// A status shown as a standard `Label`, labelled by meaning for VoiceOver ("Approval status", then
/// "Approved").
struct StatusLabel: View {
    var status: GradeDraftUIStatus
    /// What the status describes, read before it: "Approval status", "Scanned text status".
    var subject: String

    init(_ status: GradeDraftUIStatus, subject: String = "Status") {
        self.status = status
        self.subject = subject
    }

    var body: some View {
        Label(status.rawValue, systemImage: status.systemImage)
            .foregroundStyle(status.color)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(subject)
            .accessibilityValue(status.fullAccessibilityLabel)
    }
}
