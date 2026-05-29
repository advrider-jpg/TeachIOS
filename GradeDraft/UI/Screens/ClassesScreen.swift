import SwiftUI

struct ClassesScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    @State private var newClassName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GradeDraftLayout.sectionSpacing) {
                TopLevelHeader(title: "Classes", subtitle: "Rosters, class gradebook entry points, and assignments by class.") {
                    Button {
                        let trimmed = newClassName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let name = trimmed.isEmpty ? "New Class" : trimmed
                        viewModel.saveClassGroup(ClassGroupRecord(name: name, subject: viewModel.assignment.subject, gradeLevel: viewModel.assignment.gradeLevel))
                        newClassName = ""
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Add class")
                }

                GroupedListCard(title: "Add class", subtitle: "Class records stay on this device.") {
                    HStack(spacing: 8) {
                        TextField("Class name", text: $newClassName)
                            .textFieldStyle(.roundedBorder)
                        SecondaryActionButton(title: "Save Class", systemImage: "checkmark", action: {
                            viewModel.saveClassGroup(ClassGroupRecord(name: newClassName, subject: viewModel.assignment.subject, gradeLevel: viewModel.assignment.gradeLevel))
                            newClassName = ""
                        }, disabled: newClassName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .frame(maxWidth: 150)
                    }
                    .padding(GradeDraftLayout.rowHorizontalPadding)
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                GroupedListCard(title: "Class list", subtitle: "Students live under Classes.") {
                    let summaries = viewModel.classSummaries
                    if summaries.isEmpty {
                        EmptyState(title: "Roster not started", message: "Add a class or import a roster CSV from a class detail screen.", systemImage: "person.2")
                    } else {
                        ForEach(summaries) { summary in
                            NavigationLink {
                                ClassDetailRosterScreen(viewModel: viewModel, classSummary: summary)
                            } label: {
                                ClassRow(
                                    name: summary.name,
                                    subject: summary.subject,
                                    studentCount: summary.studentCount,
                                    assignmentCount: summary.assignmentCount,
                                    status: summary.studentCount == 0 ? .notStarted : .onTrack
                                )
                            }
                            .buttonStyle(.plain)
                            if summary.id != summaries.last?.id { Divider().padding(.leading, 56) }
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
