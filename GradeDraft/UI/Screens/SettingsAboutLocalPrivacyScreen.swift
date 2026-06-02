import SwiftUI

struct SettingsAboutLocalPrivacyScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    @State private var showingBackupToggleWarning = false

    var body: some View {
        Form {
            Section {
                ExportStationeryHeaderCard(
                    eyebrow: "Local privacy",
                    title: "Privacy & Storage",
                    note: "Local-first copy must match the real app path: no cloud claims beyond what the core workflow actually avoids.",
                    status: .teacherOnly
                )
            }
            .listRowBackground(Color.clear)

            Section("Local Privacy") {
                ExportStationeryCard(status: .teacherOnly, showsPerforation: true) {
                    HStack(alignment: .top, spacing: 10) {
                        TapeLabel("Device only", theme: .exportPrivacy)
                        Spacer(minLength: 8)
                        StatusChip(.teacherOnly, compact: true, theme: .exportPrivacy)
                        PaperclipDecoration(theme: .exportPrivacy)
                            .frame(width: 28, height: 40)
                    }
                    Text("Mark My Work stores and processes student work, grading records, rubrics, teacher notes, and feedback locally on your device. The core workflow does not upload or send this information.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label("No cloud text recognition in the core workflow.", systemImage: "checkmark.circle")
                    Label("No cloud AI grading in the core workflow.", systemImage: "checkmark.circle")
                    Label("No usage tracking in the core workflow.", systemImage: "checkmark.circle")
                    Label("No account or login required.", systemImage: "checkmark.circle")
                    Label("Teacher finalizes all grades.", systemImage: "person.badge.checkmark")
                }
            }
            .listRowBackground(Color.clear)

            Section {
                ExportStationeryCard(status: backupPolicyUIStatus, showsPerforation: true) {
                    TapeLabel("Storage ledger", theme: .exportPrivacy)
                    GradeDraftStatusLabeledContent(title: "Local Only", value: viewModel.persistenceSummary, status: .teacherOnly)
                    GradeDraftStatusLabeledContent(title: "Device Backup Setting", value: viewModel.deviceBackupStatusSummary, status: backupPolicyUIStatus)
                    LabeledContent("Assignments", value: "\(viewModel.assignments.count)")
                    LabeledContent("Classes", value: "\(viewModel.classGroups.count)")
                    LabeledContent("Students", value: "\(viewModel.students.count)")
                    HandwrittenAnnotation("Device backup behavior depends on this device and account configuration.", status: backupPolicyUIStatus, theme: .exportPrivacy)
                    Button {
                        if viewModel.localDataExcludedFromDeviceBackup {
                            showingBackupToggleWarning = true
                        } else {
                            viewModel.keepLocalDataExcludedFromDeviceBackup()
                        }
                    } label: {
                        Label(
                            viewModel.localDataExcludedFromDeviceBackup ? "Review Backup Inclusion" : "Keep Local Only",
                            systemImage: viewModel.localDataExcludedFromDeviceBackup ? "externaldrive.badge.icloud" : "lock.shield"
                        )
                    }
                }
            } header: {
                Text("Local Storage")
            } footer: {
                Text("Student records are stored locally. Device backup behavior depends on this device and account configuration.")
            }
            .listRowBackground(Color.clear)

            Section("Backup and Export Warnings") {
                ExportStationeryCard(status: .needsAttention, showsPerforation: true) {
                    TapeLabel("Warnings", theme: .exportPrivacy)
                    BlockingIssueRow(title: "Exports", detail: "Exports may contain sensitive student information. Review the confirmation sheet before creating a file.", status: .needsAttention)
                    BlockingIssueRow(title: "Exported backups", detail: "Full backup archive exports include all Mark My Work data stored on this device. Store exported files securely.", status: .teacherOnly)
                    Label("Opening the share sheet sends the selected file to another app.", systemImage: "square.and.arrow.up")
                    Label("Backup import must preview before mutating records.", systemImage: "archivebox")
                }
            }
            .listRowBackground(Color.clear)

            Section("About") {
                ExportStationeryCard(status: .studentFacing) {
                    TapeLabel("About", theme: .exportPrivacy)
                    LabeledContent("App", value: "Mark My Work")
                    LabeledContent("Mode", value: "Local-first teacher review")
                    LabeledContent("Core workflow", value: "Local text review, teacher final grade, local export")
                }
            }
            .listRowBackground(Color.clear)
        }
        .stationeryScreen(theme: .exportPrivacy)
        .navigationTitle("Privacy & Storage")
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
