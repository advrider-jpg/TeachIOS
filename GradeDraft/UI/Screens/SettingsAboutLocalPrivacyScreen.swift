import SwiftUI

struct SettingsAboutLocalPrivacyScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    @State private var showingBackupToggleWarning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GradeDraftLayout.deepSectionSpacing) {
                DeepWorkflowHeader(
                    title: "Settings / About / Local Privacy",
                    subtitle: "Local storage, backups, teacher-only records, and device processing.",
                    status: .teacherOnly
                )

                GroupedListCard(title: "Local Privacy", subtitle: "GradeDraft is local-first and offline-first.") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("GradeDraft stores and processes student work, grading records, rubrics, teacher notes, and feedback locally on your device. The developer does not receive, upload, or access this information in the core app workflow.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Label("No cloud text recognition in the core workflow.", systemImage: "checkmark.circle")
                        Label("No cloud AI grading in the core workflow.", systemImage: "checkmark.circle")
                        Label("No usage tracking in this repo.", systemImage: "checkmark.circle")
                        Label("No account or login required.", systemImage: "checkmark.circle")
                        Label("Teacher finalizes all grades.", systemImage: "person.badge.checkmark")
                    }
                    .font(.subheadline)
                    .padding(GradeDraftLayout.rowHorizontalPadding)
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                GroupedListCard(title: "Local storage", subtitle: "Persistence details for teacher awareness.") {
                    BlockingIssueRow(title: "Local only", detail: viewModel.persistenceSummary, status: .teacherOnly)
                    BlockingIssueRow(title: "Exports", detail: "Exports may contain sensitive student information. Review the confirmation sheet before creating a file.", status: .needsAttention)
                    BlockingIssueRow(title: "Device backup setting", detail: viewModel.deviceBackupStatusSummary, status: backupPolicyUIStatus)
                    SecondaryActionButton(
                        title: viewModel.localDataExcludedFromDeviceBackup ? "Review Backup Inclusion" : "Keep Local Only",
                        systemImage: viewModel.localDataExcludedFromDeviceBackup ? "externaldrive.badge.icloud" : "lock.shield",
                        action: {
                            if viewModel.localDataExcludedFromDeviceBackup {
                                showingBackupToggleWarning = true
                            } else {
                                viewModel.keepLocalDataExcludedFromDeviceBackup()
                            }
                        }
                    )
                    .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
                    .padding(.bottom, 10)
                    BlockingIssueRow(title: "Exported backups", detail: "Full backup archive exports include all GradeDraft data stored on this device. Store exported files securely.", status: .teacherOnly)
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { viewModel.refreshDeviceBackupPolicyStatus() }
        .confirmationDialog(backupToggleWarningTitle, isPresented: $showingBackupToggleWarning, titleVisibility: .visible) {
            Button(backupTogglePrimaryButton) { viewModel.includeLocalDataInDeviceBackupAfterWarning() }
            Button(backupToggleSecondaryButton, role: .cancel) { viewModel.keepLocalDataExcludedFromDeviceBackup() }
        } message: {
            Text(backupToggleWarningBody)
        }
    }

    private var backupPolicyUIStatus: GradeDraftUIStatus {
        switch viewModel.deviceBackupPolicyStatus {
        case .excluded:
            return .teacherOnly
        case .included, .unknown:
            return .needsAttention
        }
    }

    private var backupToggleWarningTitle: String {
        ExportWarningCatalog.warning(id: "backup-toggle-warning")?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Include student records in device backup?"
    }

    private var backupToggleWarningBody: String {
        ExportWarningCatalog.warning(id: "backup-toggle-warning")?.body.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Confirm this is permitted before changing device backup handling."
    }

    private var backupTogglePrimaryButton: String {
        ExportWarningCatalog.warning(id: "backup-toggle-warning")?.primaryButton.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Enable Backup"
    }

    private var backupToggleSecondaryButton: String {
        ExportWarningCatalog.warning(id: "backup-toggle-warning")?.secondaryButton.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Keep Local Only"
    }
}
