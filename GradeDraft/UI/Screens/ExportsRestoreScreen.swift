import QuickLook
import SwiftUI
import UniformTypeIdentifiers

// MARK: - One student's exports

/// The exports one submission offers. Each file is created on this device, opened for preview, and can be
/// shared only after the teacher confirms they reviewed it. Student-facing files need an approved, current
/// final grade (the session refuses them otherwise).
struct SubmissionExportsScreen: View {
    @Bindable var session: SubmissionSession
    @State private var preparing: ExportKind?

    var body: some View {
        List {
            if let graph = session.graph, let setup = session.setup {
                headerSection(graph: graph, setup: setup)
                exportsSection
                if !graph.exports.isEmpty {
                    Section("Previous Exports") {
                        ForEach(graph.exports.sorted { $0.createdAt > $1.createdAt }) { record in
                            LabeledContent(record.kind.displayName, value: record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                }
                ExportSafetySection()
            }
        }
        .navigationTitle("Exports")
        .navigationBarTitleDisplayMode(.inline)
        .alertMessage($session.alert)
        .sheet(isPresented: Binding(
            get: { session.preparedExport != nil },
            set: { if !$0 { session.finishSharing() } }
        )) {
            if let export = session.preparedExport {
                PreparedExportSheet(export: export, onCopyText: { session.copyPreparedExportText() })
            }
        }
    }

    private func headerSection(graph: SubmissionGraph, setup: AssignmentSetup) -> some View {
        let readiness = session.readiness
        return Section {
            LabeledContent("Student", value: graph.student.displayName)
            LabeledContent("Assignment", value: setup.assignment.title)
            StatusLabel(readiness?.canExportStudentReport == true ? .readyToExport : .reviewFinalGrade, subject: "Student-facing export")
            ForEach(readiness?.studentReportIssues ?? [], id: \.self) { issue in
                Label(issue.message, systemImage: "lock")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var exportsSection: some View {
        let studentReportAllowed = session.readiness?.canExportStudentReport == true
        return Section {
            ForEach(SubmissionSession.exportKinds) { kind in
                let policy = kind.contentPolicy
                Button {
                    preparing = kind
                    Task {
                        await session.prepareExport(kind)
                        preparing = nil
                    }
                } label: {
                    LabeledContent {
                        if preparing == kind {
                            ProgressView()
                        } else {
                            StatusLabel(policy.isStudentFacing ? .studentFacing : .teacherOnly, subject: "Audience")
                        }
                    } label: {
                        Text(kind.displayName)
                        Text(policy.warningTitle)
                    }
                }
                .disabled(preparing != nil || (policy.isStudentFacing && !studentReportAllowed))
                .accessibilityIdentifier("exports.\(kind.rawValue)")
            }
        } header: {
            Text("Create Export")
        } footer: {
            Text("Each file is created on this device and opened for preview before you can share it. Student-facing files omit private teacher notes.")
        }
    }
}

// MARK: - Exports tab

/// The Exports tab: students whose approved grade is current, class-level gradebooks, full backup and restore.
struct ExportsTabScreen: View {
    @Environment(AppModel.self) private var appModel

    @State private var backupPassword = ""
    @State private var showingRestoreImporter = false
    @State private var restoreURL: URL?
    @State private var restorePassword = ""

    private static let backupType = UTType(exportedAs: "com.markforme.backup")

    var body: some View {
        @Bindable var backup = appModel.backupRestore
        List {
            readySection
            recentExportsSection
            gradebookSection
            backupSection(backup)
            restoreSection(backup)
            ExportSafetySection()
        }
        .navigationTitle("Exports")
        .alertMessage($backup.alert)
        .sheet(isPresented: Binding(
            get: { backup.preparedExport != nil },
            set: { if !$0 { backup.finishSharing() } }
        )) {
            if let export = backup.preparedExport {
                PreparedExportSheet(export: export)
            }
        }
    }

    private var readySection: some View {
        let ready = appModel.submissionSummaries.filter { $0.rosterStatus == .approved || $0.rosterStatus == .exported }
        return Section {
            if !appModel.listsLoaded {
                ProgressView()
            } else if ready.isEmpty {
                ContentUnavailableView(
                    "No approved grades yet",
                    systemImage: "checkmark.seal",
                    description: Text("A student appears here once their final grade is approved and still current.")
                )
            }
            ForEach(Array(ready.enumerated()), id: \.element.id) { index, summary in
                NavigationLink(value: Route.submissionExports(summary.id)) {
                    LabeledContent {
                        StatusLabel(summary.rosterStatus.uiStatus, subject: "Export status")
                    } label: {
                        Text(summary.studentName)
                        Text("\(summary.assignmentTitle) · \(summary.className)")
                    }
                }
                .accessibilityIdentifier("exportsTab.submission.\(index)")
            }
        } header: {
            Text("Ready to Export")
        }
    }

    private var recentExportsSection: some View {
        Section {
            if appModel.listsLoaded && appModel.recentExports.isEmpty {
                ContentUnavailableView(
                    "No exports yet",
                    systemImage: "square.and.arrow.up",
                    description: Text("Create an export before opening the share sheet.")
                )
            }
            ForEach(Array(appModel.recentExports.enumerated()), id: \.element.id) { index, record in
                LabeledContent {
                    StatusLabel(record.kind.contentPolicy.isStudentFacing ? .studentFacing : .teacherOnly, subject: "Audience")
                } label: {
                    Text(record.kind.displayName)
                    let detail = [record.assignmentTitle, record.studentName].compactMap { $0 }.joined(separator: " · ")
                    if !detail.isEmpty {
                        Text(detail)
                    }
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("exportsTab.recent.\(index)")
            }
        } header: {
            Text("Recent Exports")
        }
    }

    private var gradebookSection: some View {
        Section {
            if appModel.listsLoaded, appModel.assignmentSummaries.isEmpty {
                ContentUnavailableView(
                    "No assignments",
                    systemImage: "tablecells",
                    description: Text("Create an assignment to export its gradebook.")
                )
            }
            ForEach(Array(appModel.assignmentSummaries.enumerated()), id: \.element.id) { index, summary in
                GradebookExportRow(summary: summary, index: index, app: appModel)
            }
        } header: {
            Text("Class Gradebooks")
        } footer: {
            Text("One CSV per assignment. A total appears only for a student whose final grade is approved and current.")
        }
    }

    private func backupSection(_ backup: BackupRestoreModel) -> some View {
        Section {
            SecureField("Backup password", text: $backupPassword)
                .accessibilityIdentifier("exportsTab.backupPassword")
            Button {
                let password = backupPassword
                Task {
                    await backup.createFullBackup(password: password)
                    if backup.alert == nil { backupPassword = "" }
                }
            } label: {
                if backup.isWorking {
                    Label {
                        Text("Working…")
                    } icon: {
                        ProgressView()
                    }
                } else {
                    Label("Create Full Backup", systemImage: "archivebox")
                }
            }
            .disabled(backupPassword.isEmpty || backup.isWorking)
            .accessibilityIdentifier("exportsTab.createBackup")
        } header: {
            Text("Full Backup")
        } footer: {
            Text(ExportKind.fullBackupArchive.contentPolicy.warningBody + " The backup is encrypted with this password and cannot be opened without it.")
        }
    }

    private func restoreSection(_ backup: BackupRestoreModel) -> some View {
        Section {
            Button {
                showingRestoreImporter = true
            } label: {
                Label("Choose Backup File", systemImage: "tray.and.arrow.down")
            }
            .disabled(backup.isWorking)
            .accessibilityIdentifier("exportsTab.chooseBackup")
            .fileImporter(isPresented: $showingRestoreImporter, allowedContentTypes: [Self.backupType]) { result in
                switch result {
                case .success(let url):
                    restorePassword = ""
                    restoreURL = url
                case .failure(let error):
                    backup.alert = AlertMessage(title: "Backup not opened", error: error)
                }
            }
            .alert("Backup Password", isPresented: Binding(get: { restoreURL != nil }, set: { if !$0 { restoreURL = nil } })) {
                SecureField("Password", text: $restorePassword)
                    .accessibilityIdentifier("exportsTab.restorePassword")
                Button("Open Backup") {
                    guard let url = restoreURL else { return }
                    let password = restorePassword
                    restoreURL = nil
                    restorePassword = ""
                    Task { await backup.prepareRestore(from: url, password: password) }
                }
                .accessibilityIdentifier("exportsTab.openBackup")
                Button("Cancel", role: .cancel) {
                    restoreURL = nil
                    restorePassword = ""
                }
            } message: {
                Text("Enter the password used when this backup was created. Nothing on this device changes until you confirm the restore.")
            }

            if let preview = backup.preview {
                LabeledContent("Backup created", value: preview.manifest.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Classes", value: "\(preview.classCount)")
                LabeledContent("Assignments", value: "\(preview.assignmentCount)")
                LabeledContent("Students", value: "\(preview.studentCount)")
                LabeledContent("Original files", value: "\(preview.sourceFileCount)")
                if backup.conflicts.isEmpty {
                    Label("No assignment in this backup already exists on this device.", systemImage: "checkmark.circle")
                }
                ForEach(Array(backup.conflicts.enumerated()), id: \.element.id) { index, setup in
                    Picker(selection: Binding(
                        get: { backup.resolutions[setup.id] },
                        set: { resolution in
                            if let resolution { backup.setResolution(resolution, for: setup.id) }
                        }
                    )) {
                        Text("Choose…").tag(RestoreResolution?.none)
                        ForEach(RestoreResolution.allCases) { resolution in
                            Text(resolution.displayName).tag(RestoreResolution?.some(resolution))
                        }
                    } label: {
                        Text(setup.assignment.title)
                        Text("Already on this device")
                    }
                    .accessibilityIdentifier("exportsTab.conflict.\(index)")
                }
                Button {
                    Task { await backup.commitRestore() }
                } label: {
                    Label("Restore", systemImage: "arrow.down.doc")
                }
                .disabled(!backup.canCommitRestore)
                .accessibilityIdentifier("exportsTab.commitRestore")
                Button(role: .destructive) {
                    backup.discardRestore()
                } label: {
                    Label("Discard", systemImage: "xmark.circle")
                }
                .disabled(backup.isWorking)
                .accessibilityIdentifier("exportsTab.discardRestore")
            }
        } header: {
            Text("Restore from Backup")
        } footer: {
            Text("Restore never overwrites local work silently. For each assignment that already exists here, choose to keep it, replace it, or import the backup as a copy. Nothing changes until you tap Restore.")
        }
    }
}

/// One assignment's gradebook CSV. The row owns that assignment's setup model and keeps it observing
/// while shown, so the export reads the current setup.
private struct GradebookExportRow: View {
    var summary: AssignmentSummary
    var index: Int
    @State private var model: AssignmentSetupModel

    init(summary: AssignmentSummary, index: Int, app: AppModel) {
        self.summary = summary
        self.index = index
        _model = State(initialValue: AssignmentSetupModel(assignmentID: summary.id, app: app))
    }

    var body: some View {
        Button {
            Task { await model.prepareGradebookCSV() }
        } label: {
            LabeledContent {
                if model.hasLoaded {
                    StatusLabel(.teacherOnly, subject: "Audience")
                } else {
                    ProgressView()
                }
            } label: {
                Text("Gradebook CSV")
                Text("\(summary.assignment.title) · \(summary.className)")
            }
        }
        .disabled(!model.hasLoaded)
        .accessibilityIdentifier("exportsTab.gradebook.\(index)")
        .task { await model.observe() }
        .alertMessage($model.alert)
        .sheet(isPresented: Binding(
            get: { model.preparedExport != nil },
            set: { if !$0 { model.finishSharing() } }
        )) {
            if let export = model.preparedExport {
                PreparedExportSheet(export: export, onCopyText: { model.copyPreparedExportText() })
            }
        }
    }
}

// MARK: - Preview, review and share

/// Shows a prepared export: who it is for, what it contains, a Quick Look preview of the real file, the
/// "I reviewed this export" confirmation, then Share. Closing the sheet deletes the prepared file.
private struct PreparedExportSheet: View {
    var export: PreparedExport
    /// Copies the export's text to the clipboard after the teacher confirms the clipboard warning; nil when
    /// the owner offers no copy (the full backup).
    var onCopyText: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var previewURL: URL?
    @State private var hasPreviewed = false
    @State private var reviewed = false
    @State private var showingClipboardWarning = false

    private var policy: ExportContentPolicy { export.kind.contentPolicy }

    /// Encrypted backups and archives cannot be shown by Quick Look; their contents are described instead.
    private var canPreview: Bool { export.kind != .fullBackupArchive && export.kind != .zipArchive }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(export.title)
                        .font(.headline)
                    StatusLabel(policy.isStudentFacing ? .studentFacing : .teacherOnly, subject: "Audience")
                    LabeledContent("File", value: export.url.lastPathComponent)
                    Text(policy.warningBody)
                        .foregroundStyle(.secondary)
                }
                Section("What This File Contains") {
                    ForEach(policy.inclusionSummaryLines, id: \.self) { line in
                        Label(line, systemImage: "doc.text")
                    }
                }
                if canPreview {
                    Section {
                        Button {
                            hasPreviewed = true
                            previewURL = export.url
                        } label: {
                            Label(hasPreviewed ? "Preview Again" : "Preview", systemImage: "eye")
                        }
                        .accessibilityIdentifier("exportSheet.preview")
                    }
                }
                if hasPreviewed || !canPreview {
                    Section {
                        Toggle("I reviewed this export", isOn: $reviewed)
                            .accessibilityIdentifier("exportSheet.reviewed")
                        if reviewed {
                            ShareLink(item: export.url, subject: Text(export.title), preview: SharePreview(export.title)) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .accessibilityIdentifier("exportSheet.share")
                            if export.kind.canCopyAsText, onCopyText != nil {
                                Button {
                                    showingClipboardWarning = true
                                } label: {
                                    Label("Copy Text", systemImage: "doc.on.clipboard")
                                }
                                .accessibilityIdentifier("exportSheet.copyText")
                            }
                        }
                    } footer: {
                        Text("Sharing sends this file to another app. MarkForMe cannot recall it afterwards. The file is deleted from this device when you tap Done.")
                    }
                }
            }
            .navigationTitle(export.kind.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("exportSheet.done")
                }
            }
            .quickLookPreview($previewURL)
            .confirmationDialog(clipboardWarningTitle, isPresented: $showingClipboardWarning, titleVisibility: .visible) {
                Button(clipboardWarningPrimaryButton) { onCopyText?() }
                    .accessibilityIdentifier("exportSheet.copyConfirm")
                Button(clipboardWarningSecondaryButton, role: .cancel) {}
            } message: {
                Text(clipboardWarningBody)
            }
            .onAppear {
                guard canPreview, !hasPreviewed else { return }
                hasPreviewed = true
                previewURL = export.url
            }
        }
    }
}

extension PreparedExportSheet {
    fileprivate var clipboardWarningTitle: String {
        ExportWarningCatalog.warning(id: "clipboard-warning")?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Copy student information?"
    }

    fileprivate var clipboardWarningBody: String {
        ExportWarningCatalog.warning(id: "clipboard-warning")?.body.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Confirm before copying this export."
    }

    fileprivate var clipboardWarningPrimaryButton: String {
        ExportWarningCatalog.warning(id: "clipboard-warning")?.primaryButton.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Copy"
    }

    fileprivate var clipboardWarningSecondaryButton: String {
        ExportWarningCatalog.warning(id: "clipboard-warning")?.secondaryButton.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Cancel"
    }
}

/// The audience rules every export screen repeats.
private struct ExportSafetySection: View {
    var body: some View {
        Section("Export Safety") {
            Label("Student-facing exports omit private teacher notes.", systemImage: "person.crop.circle.badge.checkmark")
            Label("Teacher-only exports may include private notes, review history and source files.", systemImage: "lock.doc")
            Label("Backup restore shows what it contains before anything changes.", systemImage: "archivebox")
        }
    }
}

#if DEBUG
#Preview("Exports tab — Light") {
    ScreenPreview { _ in ExportsTabScreen() }
}

#Preview("Exports tab — Dark") {
    ScreenPreview { _ in ExportsTabScreen() }
        .preferredColorScheme(.dark)
}

#Preview("Exports tab — Accessibility XXXL") {
    ScreenPreview { _ in ExportsTabScreen() }
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Student exports — Light") {
    ScreenPreview { app in RouteDestination(route: .submissionExports(PreviewFixtures.approvedSubmissionID), app: app) }
}

#Preview("Student exports — Dark") {
    ScreenPreview { app in RouteDestination(route: .submissionExports(PreviewFixtures.approvedSubmissionID), app: app) }
        .preferredColorScheme(.dark)
}

#Preview("Student exports — Accessibility XXXL") {
    ScreenPreview { app in RouteDestination(route: .submissionExports(PreviewFixtures.scannedSubmissionID), app: app) }
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
