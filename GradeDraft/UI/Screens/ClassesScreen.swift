import SwiftUI

struct ClassesScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    @State private var newClassName = ""

    var body: some View {
        List {
            Section {
                TextField("Class name", text: $newClassName)
                    .submitLabel(.done)
                    .onSubmit(addClass)
                Button(action: addClass) {
                    Label("Add Class", systemImage: "plus")
                }
                .disabled(trimmedClassName.isEmpty)
            } header: {
                Text("Add Class")
            } footer: {
                Text("Class records stay on this device.")
            }

            Section("Classes") {
                let summaries = viewModel.classSummaries
                if summaries.isEmpty {
                    ContentUnavailableView(
                        "No classes yet",
                        systemImage: "person.2",
                        description: Text("Add a class to group students and assignments.")
                    )
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
                    }
                }
            }
        }
        .gradeDraftNativeGroupedList()
        .navigationTitle("Classes")
    }

    private var trimmedClassName: String {
        newClassName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addClass() {
        guard !trimmedClassName.isEmpty else { return }
        viewModel.saveClassGroup(ClassGroupRecord(name: trimmedClassName, subject: viewModel.assignment.subject, gradeLevel: viewModel.assignment.gradeLevel))
        newClassName = ""
    }
}
