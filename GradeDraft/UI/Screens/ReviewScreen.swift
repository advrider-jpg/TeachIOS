import SwiftUI

struct ReviewScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    @State private var searchText = ""

    var body: some View {
        List {
            if textNeedsReview.isEmpty && finalReview.isEmpty && needsRecheck.isEmpty && readyToExport.isEmpty {
                ContentUnavailableView(
                    emptyStateTitle,
                    systemImage: "checklist.checked",
                    description: Text(emptyStateDescription)
                )
            }

            if !textNeedsReview.isEmpty {
                reviewSection("Text Needs Review", items: textNeedsReview)
            }
            if !finalReview.isEmpty {
                reviewSection("Final Review", items: finalReview)
            }
            if !needsRecheck.isEmpty {
                reviewSection("Needs Recheck", items: needsRecheck)
            }
            if !readyToExport.isEmpty {
                Section("Ready to Export") {
                    ForEach(readyToExport) { assignment in
                        NavigationLink {
                            ExportsRestoreScreen(viewModel: viewModel, assignmentID: assignment.id)
                                .toolbar(.hidden, for: .tabBar)
                        } label: {
                            AssignmentRow(assignment: assignment, status: viewModel.v6Status(for: assignment), actionLabel: viewModel.v6ActionLabel(for: assignment))
                        }
                    }
                }
            }
        }
        .gradeDraftNativeGroupedList()
        .navigationTitle("Review")
        .searchable(text: $searchText, prompt: "Search review queue")
    }

    @ViewBuilder
    private func reviewSection(_ title: String, items: [ReviewNavigationItem]) -> some View {
        Section(title) {
            ForEach(items) { item in
                NavigationLink {
                    item.destinationView(viewModel: viewModel)
                } label: {
                    ReviewQueueRow(title: item.title, detail: item.detail, countText: item.countText, status: item.status, actionLabel: item.actionLabel)
                }
            }
        }
    }

    private var textNeedsReview: [ReviewNavigationItem] {
        filtered(viewModel.reviewItems(for: .scannedText))
    }

    private var finalReview: [ReviewNavigationItem] {
        filtered(viewModel.reviewItems(for: .finalReview))
    }

    private var needsRecheck: [ReviewNavigationItem] {
        filtered(viewModel.reviewItems(for: .needsRecheck))
    }

    private var readyToExport: [AssignmentRecord] {
        let rows = viewModel.readyToExportAssignments
        let query = normalizedSearchText
        guard !query.isEmpty else { return rows }
        return rows.filter { assignment in
            [assignment.title, assignment.studentDisplayName, assignment.className, assignment.subject, viewModel.v6Status(for: assignment).rawValue]
                .contains { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    private func filtered(_ items: [ReviewNavigationItem]) -> [ReviewNavigationItem] {
        let query = normalizedSearchText
        guard !query.isEmpty else { return items }
        return items.filter { item in
            [item.title, item.detail, item.countText ?? "", item.status.rawValue, item.actionLabel]
                .contains { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emptyStateTitle: String {
        normalizedSearchText.isEmpty ? "No reviews pending" : "No matching reviews"
    }

    private var emptyStateDescription: String {
        normalizedSearchText.isEmpty
            ? "Assignments needing teacher review will appear here."
            : "No review rows match this search."
    }
}
