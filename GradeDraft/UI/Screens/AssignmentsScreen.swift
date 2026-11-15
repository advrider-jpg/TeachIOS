import SwiftUI

struct AssignmentsScreen: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.appTab) private var tab
    @State private var searchText = ""
    @State private var showingNewAssignment = false
    @State private var pendingDeletion: AssignmentSummary?

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func progress(for summary: AssignmentSummary, in submissions: [UUID: [SubmissionSummary]]) -> GradeWizardProgress {
        GradeWizardProgress(assignment: summary.assignment, submissions: submissions[summary.id] ?? [])
    }

    var body: some View {
        let submissions = Dictionary(grouping: appModel.submissionSummaries, by: \.assignmentID)
        let matching = appModel.assignmentSummaries.filter { summary in
            guard !query.isEmpty else { return true }
            return [
                summary.assignment.title,
                summary.className,
                summary.assignment.assignmentType.displayName,
                progress(for: summary, in: submissions).overallStatus.rawValue
            ].contains { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
        List {
            ForEach(appModel.classGroups) { group in
                let rows = matching.filter { $0.assignment.classGroupID == group.id }
                if !rows.isEmpty {
                    Section(group.name) {
                        ForEach(rows) { summary in
                            NavigationLink(value: Route.assignment(summary.id)) {
                                row(summary, progress: progress(for: summary, in: submissions))
                            }
                            .accessibilityIdentifier("assignments.row.\(summary.id.uuidString)")
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDeletion = summary
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityIdentifier("assignments.delete")
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if appModel.listsLoaded && matching.isEmpty {
                if query.isEmpty {
                    ContentUnavailableView(
                        "No saved assignments",
                        systemImage: "doc.badge.plus",
                        description: Text("Create an assignment to begin.")
                    )
                } else {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .navigationTitle("Assignments")
        .searchable(text: $searchText, prompt: "Search assignments")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewAssignment = true
                } label: {
                    Label("New Assignment", systemImage: "plus")
                }
                .accessibilityIdentifier("assignments.new")
            }
        }
        .sheet(isPresented: $showingNewAssignment) {
            NewAssignmentSheet { id in
                appModel.setPath(appModel.path(for: tab) + [.assignment(id)], for: tab)
            }
        }
        .confirmationDialog(
            "Delete this assignment?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { summary in
            Button("Delete \(summary.assignment.title)", role: .destructive) {
                Task { await appModel.deleteAssignment(id: summary.id) }
            }
        } message: { _ in
            Text("This deletes the assignment, its submissions and their saved files on this device. It can't be undone.")
        }
    }

    private func row(_ summary: AssignmentSummary, progress: GradeWizardProgress) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.assignment.title.isEmpty ? "Untitled assignment" : summary.assignment.title)
                .font(.headline)
            Text("\(summary.assignment.assignmentType.displayName) · ^[\(summary.submissionCount) student](inflect: true)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            StatusLabel(progress.overallStatus, subject: "Assignment status")
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct NewAssignmentSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    var onCreated: (UUID) -> Void
    @State private var title = ""
    @State private var chosenClassID: UUID?
    @State private var isSaving = false

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var classID: UUID? {
        chosenClassID ?? appModel.classGroups.first?.id
    }

    var body: some View {
        @Bindable var appModel = appModel
        NavigationStack {
            Group {
                if appModel.classGroups.isEmpty {
                    ContentUnavailableView(
                        "Add a class first",
                        systemImage: "person.2",
                        description: Text("Assignments belong to a class. Add one from the Classes tab.")
                    )
                } else {
                    Form {
                        TextField("Assignment title", text: $title)
                            .submitLabel(.done)
                            .onSubmit(create)
                            .accessibilityIdentifier("assignments.newSheet.title")
                        Picker("Class", selection: Binding(get: { classID }, set: { chosenClassID = $0 })) {
                            ForEach(appModel.classGroups) { group in
                                Text(group.name).tag(Optional(group.id))
                            }
                        }
                        .accessibilityIdentifier("assignments.newSheet.class")
                    }
                }
            }
            .navigationTitle("New Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                        .accessibilityIdentifier("assignments.newSheet.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: create)
                        .disabled(trimmedTitle.isEmpty || classID == nil || isSaving)
                        .accessibilityIdentifier("assignments.newSheet.create")
                }
            }
            .alertMessage($appModel.alert)
        }
    }

    private func create() {
        guard !trimmedTitle.isEmpty, let classID, !isSaving else { return }
        isSaving = true
        Task {
            let id = await appModel.createAssignment(title: trimmedTitle, classGroupID: classID)
            isSaving = false
            if let id {
                dismiss()
                onCreated(id)
            }
        }
    }
}

#if DEBUG
private struct AssignmentsScreenPreview: View {
    @State private var model = PreviewFixtures.makeAppModel()

    var body: some View {
        NavigationStack {
            AssignmentsScreen()
                .navigationDestination(for: Route.self) { RouteDestination(route: $0, app: model) }
        }
        .environment(model)
        .task { await model.observeLists() }
    }
}

#Preview("Light") {
    AssignmentsScreenPreview()
}

#Preview("Dark") {
    AssignmentsScreenPreview()
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    AssignmentsScreenPreview()
        .dynamicTypeSize(.accessibility3)
}
#endif
