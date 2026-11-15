import SwiftUI

/// Every pushed screen, identified by record ID. A route whose record no longer exists shows
/// `MissingAssignmentRouteView`; it never falls back to another record.
enum Route: Hashable, Codable, Sendable {
    case classDetail(UUID)
    case assignment(UUID)
    case rubric(UUID)
    /// The student's work screen: that student's hub for the assignment.
    case submission(UUID)
    case scannedText(UUID)
    /// AI readiness, packet preview and drafting, on one screen.
    case aiDraft(UUID)
    case finalReview(UUID)
    case submissionExports(UUID)
    case curriculum(assignmentID: UUID)
}

enum AppTab: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case home
    case classes
    case assignments
    case review
    case exports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .classes: return "Classes"
        case .assignments: return "Assignments"
        case .review: return "Review"
        case .exports: return "Exports"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .classes: return "person.2"
        case .assignments: return "doc.text"
        case .review: return "checklist"
        case .exports: return "square.and.arrow.up"
        }
    }
}

extension EnvironmentValues {
    /// The tab whose navigation stack shows the current screen; used by "Next student".
    @Entry var appTab: AppTab = .home
}
