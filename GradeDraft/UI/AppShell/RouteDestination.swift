import SwiftUI

/// Builds the screen for a route. Each host owns its per-route model (created once, keyed by the route's
/// ID), keeps it observing while the screen is shown, saves pending edits when the screen goes away or the
/// app moves to the background, and shows `MissingAssignmentRouteView` when the record no longer exists.
struct RouteDestination: View {
    var route: Route
    var app: AppModel

    var body: some View {
        switch route {
        case .classDetail(let id):
            RosterRouteHost(classGroupID: id, app: app)
        case .assignment(let id):
            SetupRouteHost(assignmentID: id, app: app, actionName: "Assignment overview") { model in
                AssignmentOverviewScreen(model: model)
            }
        case .rubric(let id):
            SetupRouteHost(assignmentID: id, app: app, actionName: "Rubric & instructions") { model in
                RubricInstructionsScreen(model: model)
            }
        case .curriculum(let assignmentID):
            CurriculumRouteHost(assignmentID: assignmentID, app: app)
        case .submission(let id):
            SubmissionRouteHost(submissionID: id, app: app, actionName: "Student work") { session in
                StudentWorkScreen(session: session)
            }
        case .scannedText(let id):
            SubmissionRouteHost(submissionID: id, app: app, actionName: "Scanned text review") { session in
                ReviewScannedTextScreen(session: session)
            }
        case .aiDraft(let id):
            SubmissionRouteHost(submissionID: id, app: app, actionName: "AI draft") { session in
                AIDraftScreen(session: session)
            }
        case .finalReview(let id):
            SubmissionRouteHost(submissionID: id, app: app, actionName: "Final review") { session in
                FinalReviewScreen(session: session)
            }
        case .submissionExports(let id):
            SubmissionRouteHost(submissionID: id, app: app, actionName: "Export") { session in
                SubmissionExportsScreen(session: session)
            }
        }
    }
}

/// Saves pending edits when the screen disappears or the app moves to the background.
private struct FlushOnLeave: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    var flush: @MainActor () async -> Void

    func body(content: Content) -> some View {
        content
            .onDisappear { Task { await flush() } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { Task { await flush() } }
            }
    }
}

struct SubmissionRouteHost<Screen: View>: View {
    @State private var session: SubmissionSession
    private let actionName: String
    private let screen: (SubmissionSession) -> Screen

    init(submissionID: UUID, app: AppModel, actionName: String, @ViewBuilder screen: @escaping (SubmissionSession) -> Screen) {
        _session = State(initialValue: SubmissionSession(id: submissionID, app: app))
        self.actionName = actionName
        self.screen = screen
    }

    var body: some View {
        Group {
            if session.isMissing {
                MissingAssignmentRouteView(assignmentID: session.id, actionName: actionName)
            } else if session.hasLoaded {
                screen(session)
            } else {
                ProgressView()
            }
        }
        .task { await session.observe() }
        .modifier(FlushOnLeave { [session] in await session.flushPendingEdits() })
    }
}

struct SetupRouteHost<Screen: View>: View {
    @State private var model: AssignmentSetupModel
    private let actionName: String
    private let screen: (AssignmentSetupModel) -> Screen

    init(assignmentID: UUID, app: AppModel, actionName: String, @ViewBuilder screen: @escaping (AssignmentSetupModel) -> Screen) {
        _model = State(initialValue: AssignmentSetupModel(assignmentID: assignmentID, app: app))
        self.actionName = actionName
        self.screen = screen
    }

    var body: some View {
        Group {
            if model.isMissing {
                MissingAssignmentRouteView(assignmentID: model.assignmentID, actionName: actionName)
            } else if model.hasLoaded {
                screen(model)
            } else {
                ProgressView()
            }
        }
        .task { await model.observe() }
        .modifier(FlushOnLeave { [model] in await model.flushPendingEdits() })
    }
}

struct CurriculumRouteHost: View {
    @State private var browser: CurriculumBrowserModel
    private let assignmentID: UUID
    private let app: AppModel

    init(assignmentID: UUID, app: AppModel) {
        _browser = State(initialValue: CurriculumBrowserModel(app: app))
        self.assignmentID = assignmentID
        self.app = app
    }

    var body: some View {
        SetupRouteHost(assignmentID: assignmentID, app: app, actionName: "Curriculum references") { setup in
            CurriculumBrowserScreen(setup: setup, browser: browser)
        }
    }
}

struct RosterRouteHost: View {
    @State private var model: RosterModel

    init(classGroupID: UUID, app: AppModel) {
        _model = State(initialValue: RosterModel(classGroupID: classGroupID, app: app))
    }

    var body: some View {
        Group {
            if model.isMissing {
                MissingAssignmentRouteView(assignmentID: model.classGroupID, actionName: "Class roster")
            } else if model.hasLoaded {
                ClassDetailRosterScreen(model: model)
            } else {
                ProgressView()
            }
        }
        .task { await model.observe() }
    }
}
