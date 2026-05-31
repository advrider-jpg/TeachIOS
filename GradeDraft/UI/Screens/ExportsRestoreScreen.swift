import SwiftUI
import UniformTypeIdentifiers

struct ExportsRestoreScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    @State private var confirmationKind: ExportConfirmationKind?
    @State private var showingBackupImporter = false
    @State private var showingShareSheetWarning = false
    @State private var showingClipboardWarning = false
    @State private var shareLinkApproved = false
    @State private var showingResolutionSheet = false

    var body: some View {
        Form {
            if !viewModel.canExportStudentReport {
                Section {
                    WarningBanner(
                        title: "Final approval required",
                        message: "Student-facing export is blocked until the teacher approves the final grade.",
                        status: .teacherOnly
                    )
                }
            }

            Section {
                ForEach(ExportConfirmationKind.allCases) { kind in
                    ExportOptionRow(
                        title: kind.title,
                        subtitle: kind.subtitle,
                        status: kind.warningStatus,
                        actionLabel: exportActionLabel(for: kind),
                        disabled: exportDisabled(for: kind),
                        action: { confirmationKind = kind }
                    )
                }
            } header: {
                Text("Create Export")
            } footer: {
                Text("Audience labels show whether a file is student-facing or teacher-only. Student-facing exports omit private teacher notes.")
            }

            Section {
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
            } header: {
                Text("Import Backup")
            } footer: {
                Text("Choose a backup to preview records before importing. Records are not changed until you confirm.")
            }

            if let preview = viewModel.pendingRestorePreview {
                restorePreviewSection(preview, title: "Preview Import", pending: true)
            } else if let preview = viewModel.latestRestorePreview {
                restorePreviewSection(preview, title: "Backup Preview", pending: false)
            }

            if let url = viewModel.exportURL {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "doc")
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.exportKind?.v6DisplayName ?? "Local export")
                                .font(.headline)
                                .lineLimit(1)
                            Text(url.lastPathComponent)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        StatusChip(viewModel.exportKind?.v6AudienceStatus ?? .teacherOnly, compact: true)
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
                } header: {
                    Text("Ready to Share")
                } footer: {
                    Text("Opening the share sheet sends the selected file to another app.")
                }
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
                        HStack(spacing: 12) {
                            Image(systemName: record.kind.v6AudienceStatus.systemImage)
                                .foregroundStyle(record.kind.v6AudienceStatus.color)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.kind.v6DisplayName)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(record.assignmentTitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            StatusChip(record.kind.v6AudienceStatus, compact: true)
                        }
                    }
                }
            }

            Section("Export Safety") {
                Label("Student-facing exports omit private teacher notes.", systemImage: "person.crop.circle.badge.checkmark")
                Label("Teacher-only exports may include private notes, review history, and source details.", systemImage: "lock.doc")
                Label("Backup import previews before mutating records.", systemImage: "archivebox")
            }
        }
        .navigationTitle("Exports & Backup")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $confirmationKind) { kind in
            ExportConfirmationSheet(kind: kind, assignment: viewModel.assignment, allAssignments: viewModel.assignments, onCancel: { confirmationKind = nil }, onConfirm: { confirm(kind) })
        }
        .sheet(isPresented: $showingResolutionSheet) {
            RestoreConflictResolutionSheet(selection: $viewModel.backupConflictResolution) {
                showingResolutionSheet = false
            }
        }
        .fileImporter(isPresented: $showingBackupImporter, allowedContentTypes: [.json, .zip, .item]) { result in
            if case .success(let url) = result { viewModel.previewBackupRestore(from: url) }
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
    }

    @ViewBuilder
    private func restorePreviewSection(_ preview: BackupRestorePreview, title: String, pending: Bool) -> some View {
        Section {
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
        } header: {
            Text(title)
        } footer: {
            Text("Records are not changed until you confirm the import.")
        }
    }

    private func confirm(_ kind: ExportConfirmationKind) {
        confirmationKind = nil
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

    private func exportDisabled(for kind: ExportConfirmationKind) -> Bool {
        switch kind {
        case .studentReportMarkdown, .studentReportPDF:
            return !viewModel.canExportStudentReport
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
