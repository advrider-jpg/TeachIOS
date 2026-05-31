import SwiftUI
import UniformTypeIdentifiers

struct ExportsRestoreScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    @State private var confirmationKind: ExportConfirmationKind?
    @State private var showingBackupImporter = false
    @State private var showingShareSheetWarning = false
    @State private var showingClipboardWarning = false
    @State private var readyToShareFile = false
    @State private var showingResolutionSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GradeDraftLayout.sectionSpacing) {
                TopLevelHeader(title: "Exports", subtitle: "Student-facing reports, teacher-only records, backups, and restore.") {
                    NavigationLink {
                        SettingsAboutLocalPrivacyScreen(viewModel: viewModel)
                    } label: {
                        Image(systemName: "lock.shield")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Local Privacy")
                }

                if !viewModel.canExportStudentReport {
                    WarningBanner(
                        title: "Final approval required",
                        message: "Student-facing export is blocked until the teacher approves the final grade.",
                        status: .teacherOnly
                    )
                    .padding(.horizontal, GradeDraftLayout.screenPadding)
                }

                GroupedListCard(title: "Create export", subtitle: "Audience labels show whether a file is student-facing or teacher-only.") {
                    ExportOptionRow(
                        title: "Student Report Markdown",
                        subtitle: "Student-facing text report for sharing after final approval.",
                        status: .studentFacing,
                        actionLabel: "Export",
                        disabled: !viewModel.canExportStudentReport,
                        action: { confirmationKind = .studentReportMarkdown }
                    )
                    Divider().padding(.leading, 56)
                    ExportOptionRow(
                        title: "Student Report PDF",
                        subtitle: "For sharing with students or families after final approval.",
                        status: .studentFacing,
                        actionLabel: "Export",
                        disabled: !viewModel.canExportStudentReport,
                        action: { confirmationKind = .studentReportPDF }
                    )
                    Divider().padding(.leading, 56)
                    ExportOptionRow(
                        title: "Teacher Review Markdown",
                        subtitle: "Teacher-only text record. Do not share with students or families.",
                        status: .teacherOnly,
                        actionLabel: "Export",
                        disabled: false,
                        action: { confirmationKind = .teacherReviewMarkdown }
                    )
                    Divider().padding(.leading, 56)
                    ExportOptionRow(
                        title: "Teacher Review PDF",
                        subtitle: "Teacher-only record. Do not share with students or families.",
                        status: .teacherOnly,
                        actionLabel: "Export",
                        disabled: false,
                        action: { confirmationKind = .teacherReviewPDF }
                    )
                    Divider().padding(.leading, 56)
                    ExportOptionRow(
                        title: "Teacher Archive",
                        subtitle: "Teacher-only ZIP with review records and original files when available.",
                        status: .teacherOnly,
                        actionLabel: "Create",
                        disabled: false,
                        action: { confirmationKind = .teacherArchive }
                    )
                    Divider().padding(.leading, 56)
                    ExportOptionRow(
                        title: "Gradebook CSV",
                        subtitle: "Teacher-only CSV for local gradebook records.",
                        status: .teacherOnly,
                        actionLabel: "Create",
                        disabled: false,
                        action: { confirmationKind = .gradebookCSV }
                    )
                    Divider().padding(.leading, 56)
                    ExportOptionRow(
                        title: "Gradebook Archive",
                        subtitle: "Teacher-only ZIP with gradebook CSV, assignment records, reports, OCR/evidence records, and original files when available.",
                        status: .teacherOnly,
                        actionLabel: "Create",
                        disabled: false,
                        action: { confirmationKind = .gradebookArchive }
                    )
                    Divider().padding(.leading, 56)
                    ExportOptionRow(
                        title: "Full Backup",
                        subtitle: "Teacher-only backup of GradeDraft data stored on this device.",
                        status: .teacherOnly,
                        actionLabel: "Create",
                        disabled: false,
                        action: { confirmationKind = .fullBackup }
                    )
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                GroupedListCard(title: "Import Backup", subtitle: "Choose a backup to preview records before importing. Records are not changed until you confirm.") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Backup import option", selection: $viewModel.backupConflictResolution) {
                            ForEach(BackupConflictResolution.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        HStack(spacing: 8) {
                            SecondaryActionButton(title: "Choose Option", systemImage: "slider.horizontal.3", action: { showingResolutionSheet = true })
                            PrimaryActionButton(title: "Choose Backup", systemImage: "square.and.arrow.down", action: { showingBackupImporter = true })
                        }
                        Text("Import as New Copy keeps your current record and imports the backup version separately. Original files from the backup will be copied to the new record.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(GradeDraftLayout.rowHorizontalPadding)
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                if let preview = viewModel.pendingRestorePreview {
                    RestorePreviewCard(preview: preview)
                        .padding(.horizontal, GradeDraftLayout.screenPadding)
                    HStack(spacing: 8) {
                        SecondaryActionButton(title: "Cancel Import", systemImage: "xmark", action: viewModel.cancelPendingRestore)
                        PrimaryActionButton(title: "Confirm Import", systemImage: "square.and.arrow.down", action: viewModel.confirmPendingRestore)
                    }
                    .padding(.horizontal, GradeDraftLayout.screenPadding)
                } else if let preview = viewModel.latestRestorePreview {
                    RestorePreviewCard(preview: preview)
                        .padding(.horizontal, GradeDraftLayout.screenPadding)
                }

                GroupedListCard(title: "Ready to share", subtitle: "Opening the share sheet sends the selected file to another app.") {
                    if let url = viewModel.exportURL {
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
                        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
                        .padding(.vertical, 10)
                        PrimaryActionButton(title: "Open Share Sheet", systemImage: "square.and.arrow.up", action: { showingShareSheetWarning = true })
                            .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
                        if clipboardCopyAvailable(for: viewModel.exportKind) {
                            SecondaryActionButton(title: "Copy Text", systemImage: "doc.on.clipboard", action: { showingClipboardWarning = true })
                                .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
                        }
                        Spacer(minLength: 12)
                    } else {
                        EmptyState(title: "No export selected", message: "Create an export before opening the share sheet.", systemImage: "square.and.arrow.up")
                    }
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $confirmationKind) { kind in
            ExportConfirmationSheet(kind: kind, assignment: viewModel.assignment, allAssignments: viewModel.assignments, onCancel: { confirmationKind = nil }, onConfirm: { confirm(kind) })
        }
        .sheet(isPresented: $readyToShareFile) {
            if let url = viewModel.exportURL {
                ActivityViewController(items: [url])
            }
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
            Button(shareSheetPrimaryButton) { readyToShareFile = true }
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
    }

    private func confirm(_ kind: ExportConfirmationKind) {
        confirmationKind = nil
        Task { await viewModel.performConfirmedExport(kind) }
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
        ExportWarningCatalog.warning(id: "share-sheet-warning")?.primaryButton.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Open Share Sheet"
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
