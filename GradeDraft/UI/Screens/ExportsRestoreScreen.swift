import SwiftUI
import UniformTypeIdentifiers

struct ExportsRestoreScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var assignmentID: UUID? = nil
    @State private var confirmationKind: ExportConfirmationKind?
    @State private var showingBackupImporter = false
    @State private var showingShareSheetWarning = false
    @State private var showingClipboardWarning = false
    @State private var shareLinkApproved = false
    @State private var showingResolutionSheet = false

    var body: some View {
        Form {
            let assignment = selectedAssignment
            Section {
                ExportStationeryHeaderCard(
                    eyebrow: "Local files",
                    title: "Exports & Backup",
                    note: "Create only the export the current teacher-reviewed state actually allows.",
                    status: .teacherOnly
                )
            }
            .listRowBackground(Color.clear)

            if !assignment.isStudentFacingExportReady {
                Section {
                    WarningBanner(
                        title: "Final approval required",
                        message: "Student-facing export is blocked until the teacher approves the final grade.",
                        status: .teacherOnly
                    )
                }
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(ExportConfirmationKind.allCases) { kind in
                    ExportOptionRow(
                        title: kind.title,
                        subtitle: kind.subtitle,
                        status: kind.warningStatus,
                        actionLabel: exportActionLabel(for: kind),
                        disabled: exportDisabled(for: kind, assignment: assignment),
                        action: { confirmationKind = kind }
                    )
                }
            } header: {
                Text("Create Export")
            } footer: {
                Text("Audience labels show whether a file is student-facing or teacher-only. Student-facing exports omit private teacher notes.")
            }
            .listRowBackground(Color.clear)

            Section {
                ExportStationeryCard(status: .teacherOnly, showsPerforation: true) {
                    HStack(alignment: .top, spacing: 10) {
                        TapeLabel("Preview first", theme: .exportPrivacy)
                        Spacer(minLength: 8)
                        StatusChip(.teacherOnly, compact: true, theme: .exportPrivacy)
                        PaperclipDecoration(theme: .exportPrivacy)
                            .frame(width: 28, height: 40)
                    }
                    HandwrittenAnnotation("Backup imports preview records before changing anything.", status: .teacherOnly, theme: .exportPrivacy)
                    Picker("Backup import option", selection: $viewModel.backupConflictResolution) {
                        ForEach(BackupConflictResolution.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    Button {
                        showingResolutionSheet = true
                    } label: {
                        Label("Choose Option", systemImage: "slider.horizontal.3")
                    }
                    Button {
                        showingBackupImporter = true
                    } label: {
                        Label("Choose Backup", systemImage: "tray.and.arrow.down")
                    }
                }
            } header: {
                Text("Import Backup")
            } footer: {
                Text("Choose a backup to preview records before importing. Records are not changed until you confirm.")
            }
            .listRowBackground(Color.clear)

            if let preview = viewModel.pendingRestorePreview {
                restorePreviewSection(preview, title: "Preview Import", pending: true)
            } else if let preview = viewModel.latestRestorePreview {
                restorePreviewSection(preview, title: "Backup Preview", pending: false)
            }

            if let url = viewModel.exportURL {
                Section {
                    ExportStationeryCard(status: viewModel.exportKind?.v6AudienceStatus ?? .teacherOnly, showsPerforation: true) {
                        HStack(alignment: .top, spacing: 10) {
                            TapeLabel("Ready", theme: .exportPrivacy)
                            Spacer(minLength: 8)
                            StatusChip(viewModel.exportKind?.v6AudienceStatus ?? .teacherOnly, compact: true, theme: .exportPrivacy)
                            PaperclipDecoration(theme: .exportPrivacy)
                                .frame(width: 28, height: 40)
                        }
                        HStack(spacing: 12) {
                            StatusIconBubble(viewModel.exportKind?.v6AudienceStatus ?? .teacherOnly, theme: .exportPrivacy)
                                .frame(width: 34, height: 34)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.exportKind?.v6DisplayName ?? "Local export")
                                    .font(.system(.headline, design: .serif).weight(.semibold))
                                    .lineLimit(1)
                                Text(url.lastPathComponent)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                        }
                        LabeledContent("Audience", value: viewModel.exportKind?.v6DisplayName ?? "Unknown")
                        LabeledContent("Stored", value: "Local file")
                        if shareLinkApproved {
                            ShareLink(item: url) {
                                Label("Share Export", systemImage: "square.and.arrow.up")
                            }
                        } else {
                            Button {
                                showingShareSheetWarning = true
                            } label: {
                                Label("Review Share Warning", systemImage: "exclamationmark.triangle")
                            }
                        }
                        if clipboardCopyAvailable(for: viewModel.exportKind) {
                            Button {
                                showingClipboardWarning = true
                            } label: {
                                Label("Copy Text", systemImage: "doc.on.clipboard")
                            }
                        }
                    }
                } header: {
                    Text("Ready to Share")
                } footer: {
                    Text("Opening the share sheet sends the selected file to another app.")
                }
                .listRowBackground(Color.clear)
            }

            Section("Recent Exports") {
                let records = viewModel.recentExportRows
                if records.isEmpty {
                    ContentUnavailableView(
                        "No exports yet",
                        systemImage: "square.and.arrow.up",
                        description: Text("Create an export before opening the share sheet.")
                    )
                } else {
                    ForEach(records) { record in
                        ExportStationeryCard(status: record.kind.v6AudienceStatus) {
                            HStack(spacing: 12) {
                                StatusIconBubble(record.kind.v6AudienceStatus, theme: .exportPrivacy)
                                    .frame(width: 34, height: 34)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.kind.v6DisplayName)
                                        .font(.system(.headline, design: .serif).weight(.semibold))
                                        .lineLimit(1)
                                    Text(record.assignmentTitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                StatusChip(record.kind.v6AudienceStatus, compact: true, theme: .exportPrivacy)
                            }
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)

            Section("Export Safety") {
                ExportStationeryCard(status: .teacherOnly, showsPerforation: true) {
                    TapeLabel("Warnings", theme: .exportPrivacy)
                    Label("Student-facing exports omit private teacher notes.", systemImage: "person.crop.circle.badge.checkmark")
                    Label("Teacher-only exports may include private notes, review history, and source details.", systemImage: "lock.doc")
                    Label("Backup import previews before mutating records.", systemImage: "archivebox")
                    HandwrittenAnnotation("Teacher-only files may include sensitive student records.", status: .teacherOnly, theme: .exportPrivacy)
                }
            }
            .listRowBackground(Color.clear)
        }
        .stationeryScreen(theme: .exportPrivacy)
        .navigationTitle("Exports & Backup")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $confirmationKind) { kind in
            ExportConfirmationSheet(kind: kind, assignment: selectedAssignment, allAssignments: viewModel.assignments, onCancel: { confirmationKind = nil }, onConfirm: { confirm(kind) })
        }
        .sheet(isPresented: $showingResolutionSheet) {
            RestoreConflictResolutionSheet(selection: $viewModel.backupConflictResolution) {
                showingResolutionSheet = false
            }
        }
        .fileImporter(isPresented: $showingBackupImporter, allowedContentTypes: [.json, .zip, .item]) { result in
            switch result {
            case .success(let url):
                viewModel.previewBackupRestore(from: url)
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .confirmationDialog(shareSheetWarningTitle, isPresented: $showingShareSheetWarning, titleVisibility: .visible) {
            Button(shareSheetPrimaryButton) { shareLinkApproved = true }
            Button(shareSheetSecondaryButton, role: .cancel) {}
        } message: {
            Text(shareSheetWarningBody)
        }
        .confirmationDialog(clipboardWarningTitle, isPresented: $showingClipboardWarning, titleVisibility: .visible) {
            Button(clipboardWarningPrimaryButton) { viewModel.copyPreparedExportTextToClipboard() }
            Button(clipboardWarningSecondaryButton, role: .cancel) {}
        } message: {
            Text(clipboardWarningBody)
        }
        .onChange(of: viewModel.exportURL) { _, _ in
            shareLinkApproved = false
        }
        .onChange(of: viewModel.exportKind) { _, _ in
            shareLinkApproved = false
        }
        .onAppear {
            if let assignmentID {
                viewModel.selectAssignment(assignmentID)
            }
        }
    }

    private var selectedAssignment: AssignmentRecord {
        assignmentID.flatMap { viewModel.assignment(for: $0) } ?? viewModel.assignment
    }

    @ViewBuilder
    private func restorePreviewSection(_ preview: BackupRestorePreview, title: String, pending: Bool) -> some View {
        Section {
            ExportStationeryCard(status: pending ? .needsAttention : .teacherOnly, showsPerforation: true) {
                TapeLabel(pending ? "Preview before import" : "Backup preview", theme: .exportPrivacy)
                Text(preview.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                LabeledContent("Assignments", value: "\(preview.assignmentCount)")
                LabeledContent("Classes", value: "\(preview.classCount)")
                LabeledContent("Students", value: "\(preview.studentCount)")
                LabeledContent("Original files", value: "\(preview.sourceFileCount)")
                if preview.conflictAssignmentIDs.isEmpty {
                    BlockingIssueRow(title: "No matching records found", detail: "Import can continue with the selected option.", status: .onTrack)
                } else {
                    RestoreConflictRow(count: preview.conflictAssignmentIDs.count)
                }
                ForEach(preview.warnings, id: \.self) { warning in
                    BlockingIssueRow(title: "Needs attention", detail: warning, status: .needsAttention)
                }
                if pending {
                    Button(role: .cancel, action: viewModel.cancelPendingRestore) {
                        Label("Cancel Import", systemImage: "xmark")
                    }
                    Button(action: viewModel.confirmPendingRestore) {
                        Label("Confirm Import", systemImage: "tray.and.arrow.down")
                    }
                }
            }
        } header: {
            Text(title)
        } footer: {
            Text("Records are not changed until you confirm the import.")
        }
        .listRowBackground(Color.clear)
    }

    private func confirm(_ kind: ExportConfirmationKind) {
        confirmationKind = nil
        if let assignmentID {
            viewModel.selectAssignment(assignmentID)
        }
        Task { await viewModel.performConfirmedExport(kind) }
    }

    private func exportActionLabel(for kind: ExportConfirmationKind) -> String {
        switch kind {
        case .studentReportMarkdown, .teacherReviewMarkdown, .studentReportPDF, .teacherReviewPDF:
            return "Export"
        case .fullBackup, .teacherArchive, .gradebookCSV, .gradebookArchive:
            return "Create"
        }
    }

    private func exportDisabled(for kind: ExportConfirmationKind, assignment: AssignmentRecord) -> Bool {
        switch kind {
        case .studentReportMarkdown, .studentReportPDF:
            return !assignment.isStudentFacingExportReady
        case .teacherReviewMarkdown, .teacherReviewPDF, .fullBackup, .teacherArchive, .gradebookCSV, .gradebookArchive:
            return false
        }
    }

    private func clipboardCopyAvailable(for kind: ExportKind?) -> Bool {
        guard let kind else { return false }
        switch kind {
        case .studentMarkdown, .teacherAuditMarkdown, .csvGradebook, .backupJSON:
            return true
        case .studentPDF, .teacherAuditPDF, .zipArchive, .fullBackupArchive, .assignmentGradebookArchive:
            return false
        }
    }

    private var shareSheetWarningTitle: String {
        ExportWarningCatalog.warning(id: "share-sheet-warning")?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Share outside the app?"
    }

    private var shareSheetWarningBody: String {
        ExportWarningCatalog.warning(id: "share-sheet-warning")?.body.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Confirm before sharing this export outside GradeDraft."
    }

    private var shareSheetPrimaryButton: String {
        "Show Share Link"
    }

    private var shareSheetSecondaryButton: String {
        ExportWarningCatalog.warning(id: "share-sheet-warning")?.secondaryButton.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Cancel"
    }

    private var clipboardWarningTitle: String {
        ExportWarningCatalog.warning(id: "clipboard-warning")?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Copy student information?"
    }

    private var clipboardWarningBody: String {
        ExportWarningCatalog.warning(id: "clipboard-warning")?.body.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Confirm before copying this export."
    }

    private var clipboardWarningPrimaryButton: String {
        ExportWarningCatalog.warning(id: "clipboard-warning")?.primaryButton.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Copy"
    }

    private var clipboardWarningSecondaryButton: String {
        ExportWarningCatalog.warning(id: "clipboard-warning")?.secondaryButton.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Cancel"
    }
}
