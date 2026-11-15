import SwiftUI

extension AssignmentSetup {
    /// The rubric's title for a criterion, or the criterion's own title when the assignment has no
    /// point-bearing rubric.
    func displayTitle(criterionID: String, ownTitle: String?) -> String {
        parsedRubric.criterion(id: criterionID)?.title ?? ownTitle ?? "Criterion"
    }

    /// The rubric's maximum for a criterion, or the criterion's own maximum when there is no rubric row.
    func maximumPoints(criterionID: String, ownMaximum: Double?) -> Double? {
        parsedRubric.criterion(id: criterionID)?.maxPoints ?? ownMaximum
    }
}

extension String {
    /// True when the text is empty or only whitespace.
    var isWhitespaceOnly: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

#if DEBUG
/// Hosts a screen over the shared preview fixture, inside a navigation stack that resolves routes the
/// same way the app shell does.
struct ScreenPreview<Content: View>: View {
    @State private var app: AppModel
    private let content: (AppModel) -> Content

    init(@ViewBuilder content: @escaping (AppModel) -> Content) {
        _app = State(initialValue: PreviewFixtures.makeAppModel())
        self.content = content
    }

    var body: some View {
        NavigationStack {
            content(app)
                .navigationDestination(for: Route.self) { route in
                    RouteDestination(route: route, app: app)
                }
        }
        .environment(app)
        .task { await app.observeLists() }
    }
}
#endif
