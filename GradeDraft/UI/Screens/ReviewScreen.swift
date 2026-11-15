import SwiftUI

/// Submissions waiting on the teacher, grouped by assignment.
struct ReviewScreen: View {
    @Environment(AppModel.self) private var appModel
    @State private var searchText = ""

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var queue: [SubmissionSummary] {
        appModel.submissionSummaries.filter { summary in
            guard summary.rosterStatus.needsTeacherReview || summary.rosterStatus.hasDraftReady else { return false }
            guard !query.isEmpty else { return true }
            return [summary.studentName, summary.assignmentTitle, summary.className, summary.rosterStatus.displayName]
                .contains { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    var body: some View {
        let items = queue
        List {
            ForEach(appModel.assignmentSummaries) { assignment in
                let rows = items.filter { $0.assignmentID == assignment.id }
                if !rows.isEmpty {
                    Section("\(assignment.assignment.title) · \(assignment.className)") {
                        ForEach(rows) { row in
                            NavigationLink(value: Route.submission(row.id)) {
                                SubmissionSummaryRow(summary: row, showsAssignment: false)
                            }
                            .accessibilityIdentifier("review.submission.\(row.id.uuidString)")
                        }
                    }
                }
            }
        }
        .overlay {
            if appModel.listsLoaded && items.isEmpty {
                if query.isEmpty {
                    ContentUnavailableView(
                        "No reviews pending",
                        systemImage: "checklist.checked",
                        description: Text("Assignments needing teacher review will appear here.")
                    )
                } else {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .navigationTitle("Review")
        .searchable(text: $searchText, prompt: "Search review queue")
    }
}

#if DEBUG
private struct ReviewScreenPreview: View {
    @State private var model = PreviewFixtures.makeAppModel()

    var body: some View {
        NavigationStack {
            ReviewScreen()
                .navigationDestination(for: Route.self) { RouteDestination(route: $0, app: model) }
        }
        .environment(model)
        .task { await model.observeLists() }
    }
}

#Preview("Light") {
    ReviewScreenPreview()
}

#Preview("Dark") {
    ReviewScreenPreview()
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    ReviewScreenPreview()
        .dynamicTypeSize(.accessibility3)
}
#endif
