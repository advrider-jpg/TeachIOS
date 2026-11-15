import SwiftUI

struct SettingsAboutLocalPrivacyScreen: View {
    @Environment(AppModel.self) private var appModel
    @State private var showingBackupToggleWarning = false

    /// The device-backup setting as the saved-work files report it.
    private var backupStatus: DeviceBackupPolicyStatus {
        switch appModel.deviceBackupIncluded {
        case .some(true): return .included
        case .some(false): return .excluded
        case .none: return .unknown("The platform did not report a consistent exclusion value for the saved work.")
        }
    }

    var body: some View {
        Form {
            Section {
                Text("MarkForMe stores and processes student work, grading records, rubrics, teacher notes, and feedback locally on your device. The core workflow does not upload or send this information.")
                Label("No cloud text recognition in the core workflow.", systemImage: "checkmark.circle")
                Label("No cloud AI grading in the core workflow.", systemImage: "checkmark.circle")
                Label("No usage tracking in the core workflow.", systemImage: "checkmark.circle")
                Label("No account or login required.", systemImage: "checkmark.circle")
                Label("Teacher finalizes all grades.", systemImage: "person.badge.checkmark")
            } header: {
                Text("Local Privacy")
            } footer: {
                Text("Student work is not sent to us for marking.")
            }

            Section {
                storageRows
                LabeledContent("Device Backup Setting") {
                    StatusLabel(backupPolicyUIStatus, subject: "Device backup status")
                        .accessibilityIdentifier("settings.backupStatus")
                }
                Text(backupStatus.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.backupSummary")
                Button {
                    if backupStatus.isExcluded {
                        showingBackupToggleWarning = true
                    } else {
                        Task { await appModel.setDeviceBackupIncluded(false) }
                    }
                } label: {
                    Label(
                        backupStatus.isExcluded ? "Review Backup Inclusion" : "Keep Local Only",
                        systemImage: backupStatus.isExcluded ? "externaldrive.badge.icloud" : "lock.shield"
                    )
                }
                .disabled(appModel.database == nil)
                .accessibilityIdentifier("settings.backupToggle")
            } header: {
                Text("Local Storage")
            } footer: {
                Text("Student records are stored locally. Device backup behavior depends on this device and account configuration.")
            }

            Section("Backup and Export Warnings") {
                Label("Exports may contain sensitive student information. Review the confirmation sheet before creating a file.", systemImage: "exclamationmark.triangle")
                Label("Full backup archive exports include all MarkForMe data stored on this device. Store exported files securely.", systemImage: "lock")
                Label("Opening the share sheet sends the selected file to another app.", systemImage: "square.and.arrow.up")
                Label("Backup import must preview before mutating records.", systemImage: "archivebox")
            }

            Section("About") {
                LabeledContent("App", value: "MarkForMe")
                LabeledContent("Mode", value: "Student work is not sent to us")
                LabeledContent("Core workflow", value: "Local text review, teacher final grade, local export")
            }
        }
        .navigationTitle("Privacy & Storage")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: appModel.storageRoot) {
            appModel.refreshDeviceBackupStatus()
        }
        .confirmationDialog(backupToggleWarningTitle, isPresented: $showingBackupToggleWarning, titleVisibility: .visible) {
            Button(backupTogglePrimaryButton) {
                Task { await appModel.setDeviceBackupIncluded(true) }
            }
            .accessibilityIdentifier("settings.backupEnable")
            Button(backupToggleSecondaryButton, role: .cancel) {
                Task { await appModel.setDeviceBackupIncluded(false) }
            }
            .accessibilityIdentifier("settings.backupKeepLocal")
        } message: {
            Text(backupToggleWarningBody)
        }
    }

    @ViewBuilder
    private var storageRows: some View {
        if appModel.database != nil {
            Label("Saved work is open and stored on this device.", systemImage: "internaldrive")
                .accessibilityIdentifier("settings.storageStatus")
            LabeledContent("Classes", value: "\(appModel.classGroups.count)")
            LabeledContent("Assignments", value: "\(appModel.assignmentSummaries.count)")
            LabeledContent("Submissions", value: "\(appModel.submissionSummaries.count)")
        } else {
            Label("Saved work is not open.", systemImage: "exclamationmark.octagon")
                .foregroundStyle(.red)
                .accessibilityIdentifier("settings.storageStatus")
            if let error = appModel.startupError {
                Text(error.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var backupPolicyUIStatus: GradeDraftUIStatus {
        backupStatus.isExcluded ? .teacherOnly : .needsAttention
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

#if DEBUG
private struct SettingsPreview: View {
    @State private var model = PreviewFixtures.makeAppModel()

    var body: some View {
        NavigationStack {
            SettingsAboutLocalPrivacyScreen()
        }
        .environment(model)
        .task { await model.observeLists() }
    }
}

#Preview("Light") {
    SettingsPreview()
}

#Preview("Dark") {
    SettingsPreview()
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    SettingsPreview()
        .dynamicTypeSize(.accessibility3)
}
#endif
