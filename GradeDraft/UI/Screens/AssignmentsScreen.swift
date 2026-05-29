import SwiftUI

struct AssignmentsScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GradeDraftLayout.sectionSpacing) {
                TopLevelHeader(title: "Assignments", subtitle: "Add work, review text, approve final grades, and export.") {
                    Button { viewModel.newAssignment() } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("New assignment")
                }

                GroupedListCard(title: "Assignment list", subtitle: "Each row shows the current status and next teacher action.") {
                    if viewModel.assignments.isEmpty {
                        EmptyState(title: "No saved assignments", message: "Create an assignment to begin.", systemImage: "doc.badge.plus")
                    } else {
                        ForEach(viewModel.assignments) { assignment in
                            NavigationLink {
                                AssignmentOverviewScreen(viewModel: viewModel, assignmentID: assignment.id)
                            } label: {
                                AssignmentRow(assignment: assignment, status: viewModel.v6Status(for: assignment), actionLabel: viewModel.v6ActionLabel(for: assignment))
                            }
                            .buttonStyle(.plain)
                            if assignment.id != viewModel.assignments.last?.id { Divider().padding(.leading, 56) }
                        }
                    }
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}
