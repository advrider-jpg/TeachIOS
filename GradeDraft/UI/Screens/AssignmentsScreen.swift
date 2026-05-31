import SwiftUI

struct AssignmentsScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                if filteredAssignments.isEmpty {
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView(
                            "No saved assignments",
                            systemImage: "doc.badge.plus",
                            description: Text("Create an assignment to begin.")
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    ForEach(filteredAssignments) { assignment in
                        NavigationLink {
                            AssignmentOverviewScreen(viewModel: viewModel, assignmentID: assignment.id)
                        } label: {
                            AssignmentRow(assignment: assignment, status: viewModel.v6Status(for: assignment), actionLabel: viewModel.v6ActionLabel(for: assignment))
                        }
                    }
                }
            } header: {
                Text("Assignments")
            } footer: {
                Text("Each row shows the current status and next teacher action.")
            }
        }
        .gradeDraftNativeGroupedList()
        .navigationTitle("Assignments")
        .searchable(text: $searchText, prompt: "Search assignments")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.newAssignment()
                } label: {
                    Label("New Assignment", systemImage: "plus")
                }
            }
        }
    }

    private var filteredAssignments: [AssignmentRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.assignments }
        return viewModel.assignments.filter { assignment in
            [
                assignment.title,
                assignment.studentDisplayName,
                assignment.className,
                assignment.subject,
                assignment.assignmentType.displayName,
                viewModel.v6Status(for: assignment).rawValue
            ].contains { value in
                value.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }
}
