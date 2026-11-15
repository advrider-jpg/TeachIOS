import SwiftUI
import UniformTypeIdentifiers

struct ClassDetailRosterScreen: View {
    let model: RosterModel
    @State private var showingAddStudent = false
    @State private var showingRosterImporter = false
    @State private var pendingRemoval: Student?

    private var rosterTypes: [UTType] {
        [.commaSeparatedText, .plainText] + [UTType(filenameExtension: "xlsx")].compactMap { $0 }
    }

    var body: some View {
        @Bindable var model = model
        let classGroup = model.classGroup
        let submissions = Dictionary(grouping: model.app.submissionSummaries, by: \.assignmentID)
        List {
            Section("Class Summary") {
                if let subject = classGroup?.subject, !subject.isEmpty {
                    LabeledContent("Subject", value: subject)
                }
                if let level = classGroup?.gradeLevel, !level.isEmpty {
                    LabeledContent("Grade level", value: level)
                }
                if let term = classGroup?.term, !term.isEmpty {
                    LabeledContent("Term", value: term)
                }
                LabeledContent("Students", value: "\(model.students.count)")
                LabeledContent("Assignments", value: "\(model.assignments.count)")
            }

            Section("Assignments") {
                if model.assignments.isEmpty {
                    ContentUnavailableView(
                        "No saved assignments",
                        systemImage: "doc.text",
                        description: Text("Add an assignment from the Assignments tab.")
                    )
                } else {
                    ForEach(model.assignments) { summary in
                        NavigationLink(value: Route.assignment(summary.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(summary.assignment.title.isEmpty ? "Untitled assignment" : summary.assignment.title)
                                    .font(.headline)
                                StatusLabel(
                                    GradeWizardProgress(assignment: summary.assignment, submissions: submissions[summary.id] ?? []).overallStatus,
                                    subject: "Assignment status"
                                )
                                .font(.subheadline)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        .accessibilityIdentifier("classDetail.assignment.\(summary.id.uuidString)")
                    }
                }
            }

            Section("Students") {
                Button {
                    showingAddStudent = true
                } label: {
                    Label("Add Student", systemImage: "person.badge.plus")
                }
                .accessibilityIdentifier("classDetail.addStudent")
                Button {
                    showingRosterImporter = true
                } label: {
                    Label("Import Roster File", systemImage: "doc.badge.plus")
                }
                .accessibilityIdentifier("classDetail.importRoster")

                if model.students.isEmpty {
                    ContentUnavailableView(
                        "Roster not started",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Add student names or import a roster file.")
                    )
                } else {
                    ForEach(model.students) { student in
                        LabeledContent(student.displayName, value: student.localIdentifier)
                            .accessibilityIdentifier("classDetail.student.\(student.id.uuidString)")
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingRemoval = student
                                } label: {
                                    Label("Remove", systemImage: "person.badge.minus")
                                }
                                .accessibilityIdentifier("classDetail.removeStudent")
                            }
                    }
                }
            }

            if let result = model.lastImportResult {
                Section("Last Roster Import") {
                    LabeledContent("Students added", value: "\(result.imported)")
                    ForEach(result.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .navigationTitle(classGroup?.name ?? "Class")
        .navigationBarTitleDisplayMode(.inline)
        .alertMessage($model.alert)
        .sheet(isPresented: $showingAddStudent) {
            AddStudentSheet(model: model)
        }
        .sheet(isPresented: Binding(
            get: { model.rosterPreview != nil },
            set: { if !$0 { model.discardRosterPreview() } }
        )) {
            RosterPreviewSheet(model: model)
        }
        .fileImporter(isPresented: $showingRosterImporter, allowedContentTypes: rosterTypes) { result in
            switch result {
            case .success(let url):
                model.previewRosterFile(at: url)
            case .failure(let error):
                model.alert = AlertMessage(title: "Roster not read", error: error)
            }
        }
        .confirmationDialog(
            "Remove this student?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { student in
            Button("Remove \(student.displayName)", role: .destructive) {
                Task { await model.removeStudent(student.id) }
            }
        } message: { _ in
            Text("This removes the student and all of their submissions and saved files from this device. It can't be undone.")
        }
    }
}

private struct AddStudentSheet: View {
    let model: RosterModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var localID = ""
    @State private var isSaving = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                TextField("Student name", text: $name)
                    .submitLabel(.next)
                    .accessibilityIdentifier("classDetail.addSheet.name")
                TextField("Local ID", text: $localID)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .accessibilityIdentifier("classDetail.addSheet.localID")
            }
            .navigationTitle("Add Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                        .accessibilityIdentifier("classDetail.addSheet.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .disabled(trimmedName.isEmpty || isSaving)
                        .accessibilityIdentifier("classDetail.addSheet.add")
                }
            }
            .alertMessage($model.alert)
        }
    }

    private func add() {
        let trimmedID = localID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !isSaving else { return }
        let duplicate = model.students.contains { student in
            student.displayName.caseInsensitiveCompare(trimmedName) == .orderedSame
                || (!trimmedID.isEmpty && student.localIdentifier.caseInsensitiveCompare(trimmedID) == .orderedSame)
        }
        if duplicate {
            model.alert = AlertMessage(
                title: "Student not added",
                message: "A matching student already exists in this class. Edit the existing roster record instead of creating a duplicate."
            )
            return
        }
        isSaving = true
        Task {
            await model.enrol(displayName: trimmedName, localIdentifier: trimmedID)
            isSaving = false
            if model.alert == nil { dismiss() }
        }
    }
}

private struct RosterPreviewSheet: View {
    let model: RosterModel

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                if let preview = model.rosterPreview {
                    Section {
                        LabeledContent("File", value: preview.fileName)
                        LabeledContent("Students found", value: "\(preview.rows.count)")
                        LabeledContent("Header row", value: preview.fileResult.hasHeaderRow ? "Detected" : "Not detected")
                        if preview.fileResult.ignoredBlankColumns > 0 {
                            Label("^[\(preview.fileResult.ignoredBlankColumns) empty column](inflect: true) ignored", systemImage: "rectangle.dashed")
                        }
                    }

                    if !preview.fileResult.unrecognisedColumns.isEmpty {
                        Section {
                            ForEach(preview.fileResult.unrecognisedColumns, id: \.self) { column in
                                Text(column)
                            }
                        } header: {
                            Text("Columns Not Imported")
                        } footer: {
                            Text("These columns are not recognised, so their contents are not imported.")
                        }
                    }

                    if !preview.fileResult.skippedRows.isEmpty {
                        Section("Rows Skipped") {
                            ForEach(preview.fileResult.skippedRows, id: \.self) { row in
                                Label(row, systemImage: "xmark.octagon")
                            }
                        }
                    }

                    if !preview.fileResult.warnings.isEmpty {
                        Section("Warnings") {
                            ForEach(preview.fileResult.warnings, id: \.self) { warning in
                                Label(warning, systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    Section("Students to Add") {
                        ForEach(Array(preview.rows.enumerated()), id: \.offset) { _, row in
                            LabeledContent(row.displayName, value: row.localIdentifier)
                        }
                    }
                }
            }
            .navigationTitle("Import Roster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .cancel) { model.discardRosterPreview() }
                        .accessibilityIdentifier("classDetail.preview.discard")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        Task { await model.confirmRosterImport() }
                    }
                    .disabled(model.rosterPreview?.rows.isEmpty ?? true)
                    .accessibilityIdentifier("classDetail.preview.confirm")
                }
            }
            .alertMessage($model.alert)
        }
    }
}

#if DEBUG
private struct ClassDetailPreview: View {
    @State private var model = PreviewFixtures.makeAppModel()

    var body: some View {
        NavigationStack {
            RouteDestination(route: .classDetail(PreviewFixtures.classGroupID), app: model)
                .navigationDestination(for: Route.self) { RouteDestination(route: $0, app: model) }
        }
        .environment(model)
        .task { await model.observeLists() }
    }
}

#Preview("Light") {
    ClassDetailPreview()
}

#Preview("Dark") {
    ClassDetailPreview()
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    ClassDetailPreview()
        .dynamicTypeSize(.accessibility3)
}
#endif
