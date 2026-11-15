import SwiftUI

struct ClassesScreen: View {
    @Environment(AppModel.self) private var appModel
    @State private var showingAddClass = false
    @State private var pendingDeletion: ClassGroup?

    var body: some View {
        List {
            ForEach(appModel.classGroups) { group in
                NavigationLink(value: Route.classDetail(group.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.headline)
                        Text(detail(for: group))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                .accessibilityIdentifier("classes.row.\(group.id.uuidString)")
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingDeletion = group
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .accessibilityIdentifier("classes.delete")
                }
            }
        }
        .overlay {
            if appModel.listsLoaded && appModel.classGroups.isEmpty {
                ContentUnavailableView {
                    Label("No classes yet", systemImage: "person.2")
                } description: {
                    Text("Add a class to group students and assignments.")
                } actions: {
                    Button("Add Class") { showingAddClass = true }
                        .accessibilityIdentifier("classes.emptyAdd")
                }
            }
        }
        .navigationTitle("Classes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddClass = true
                } label: {
                    Label("Add Class", systemImage: "plus")
                }
                .accessibilityIdentifier("classes.add")
            }
        }
        .sheet(isPresented: $showingAddClass) {
            AddClassSheet()
        }
        .confirmationDialog(
            "Delete this class?",
            item: $pendingDeletion,
            titleVisibility: .visible
        ) { group in
            Button("Delete \(group.name)", role: .destructive) {
                Task { await appModel.deleteClass(id: group.id) }
            }
        } message: { _ in
            Text("This deletes the class, its assignments, their submissions and the saved files on this device. It can't be undone.")
        }
    }

    private func detail(for group: ClassGroup) -> String {
        let count = appModel.assignmentSummaries.filter { $0.assignment.classGroupID == group.id }.count
        let assignments = count == 1 ? "1 assignment" : "\(count) assignments"
        let studentCount = appModel.studentCounts[group.id] ?? 0
        let students = studentCount == 1 ? "1 student" : "\(studentCount) students"
        return [group.subject, students, assignments, group.isArchived ? "Archived" : ""]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

private struct AddClassSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isSaving = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        @Bindable var appModel = appModel
        NavigationStack {
            Form {
                TextField("Class name", text: $name)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .accessibilityIdentifier("classes.addSheet.name")
            }
            .navigationTitle("Add Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                        .accessibilityIdentifier("classes.addSheet.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .disabled(trimmedName.isEmpty || isSaving)
                        .accessibilityIdentifier("classes.addSheet.add")
                }
            }
            .alertMessage($appModel.alert)
        }
    }

    private func add() {
        guard !trimmedName.isEmpty, !isSaving else { return }
        if appModel.classGroups.contains(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            appModel.alert = AlertMessage(title: "Class not added", message: "A class with this name already exists locally.")
            return
        }
        isSaving = true
        Task {
            let id = await appModel.addClass(name: trimmedName)
            isSaving = false
            if id != nil { dismiss() }
        }
    }
}

#if DEBUG
private struct ClassesScreenPreview: View {
    @State private var model = PreviewFixtures.makeAppModel()

    var body: some View {
        NavigationStack {
            ClassesScreen()
                .navigationDestination(for: Route.self) { RouteDestination(route: $0, app: model) }
        }
        .environment(model)
        .task { await model.observeLists() }
    }
}

#Preview("Light") {
    ClassesScreenPreview()
}

#Preview("Dark") {
    ClassesScreenPreview()
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    ClassesScreenPreview()
        .dynamicTypeSize(.accessibility3)
}
#endif
