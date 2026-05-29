import SwiftUI

struct ExportOptionRow: View {
    var title: String
    var subtitle: String
    var status: GradeDraftUIStatus
    var actionLabel: String
    var disabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: status == .studentFacing ? "person.crop.circle.badge.checkmark" : "lock.doc")
                    .foregroundStyle(status.color)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    StatusChip(status, compact: true)
                    Text(actionLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(disabled ? .secondary : .blue)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
            .padding(.vertical, 10)
            .frame(minHeight: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
    }
}

struct ExportDisclosureSection: Equatable {
    var title: String
    var systemImage: String
    var items: [String]
}

enum ExportConfirmationKind: String, Identifiable, CaseIterable {
    case studentReportPDF
    case teacherReviewPDF
    case fullBackup
    case teacherArchive
    case gradebookArchive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .studentReportPDF:
            return "Student Report PDF"
        case .teacherReviewPDF:
            return "Teacher Review PDF"
        case .fullBackup:
            return "Full Backup"
        case .teacherArchive:
            return "Teacher Archive"
        case .gradebookArchive:
            return "Gradebook Archive"
        }
    }

    var subtitle: String {
        switch self {
        case .studentReportPDF:
            return "For sharing with students or families."
        case .teacherReviewPDF:
            return "Teacher-only record. Do not share with students or families."
        case .fullBackup:
            return "Teacher-only backup. Store securely."
        case .teacherArchive:
            return "Teacher-only archive. It may include original files and private review records."
        case .gradebookArchive:
            return "Teacher-only gradebook file for local record keeping."
        }
    }

    var confirmTitle: String {
        switch self {
        case .studentReportPDF:
            return "Create Student Report PDF"
        case .teacherReviewPDF:
            return "Create Teacher Review PDF"
        case .fullBackup:
            return "Create Full Backup"
        case .teacherArchive:
            return "Create Teacher Archive"
        case .gradebookArchive:
            return "Create Gradebook Archive"
        }
    }

    var sections: [ExportDisclosureSection] {
        switch self {
        case .studentReportPDF:
            return [
                ExportDisclosureSection(title: "INCLUDED", systemImage: "checkmark.circle", items: [
                    "Final grade",
                    "Student-facing feedback",
                    "Approved evidence excerpts"
                ]),
                ExportDisclosureSection(title: "EXCLUDED", systemImage: "xmark.circle", items: [
                    "Private teacher notes",
                    "Review history",
                    "Unreviewed AI suggestions",
                    "Device file details",
                    "Internal source details",
                    "Other students' information"
                ])
            ]
        case .teacherReviewPDF:
            return [
                ExportDisclosureSection(title: "MAY INCLUDE", systemImage: "lock", items: [
                    "Private teacher notes",
                    "Review history",
                    "Scanned-text review details",
                    "Evidence links",
                    "Original-file details",
                    "Internal review details"
                ])
            ]
        case .fullBackup:
            return []
        case .teacherArchive:
            return [
                ExportDisclosureSection(title: "MAY INCLUDE", systemImage: "lock", items: [
                    "Student work",
                    "Reviewed text",
                    "Rubrics",
                    "Evidence links",
                    "Private teacher notes",
                    "Original-file details"
                ])
            ]
        case .gradebookArchive:
            return [
                ExportDisclosureSection(title: "MAY INCLUDE", systemImage: "lock", items: [
                    "Student names",
                    "Final grades",
                    "Rubric labels",
                    "Student-facing feedback"
                ])
            ]
        }
    }
}

struct ExportConfirmationSheet: View {
    var kind: ExportConfirmationKind
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(kind.title)
                        .font(.title.bold())
                        .lineLimit(2)
                    Text(kind.subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(kind.sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.headline)
                            ForEach(section.items, id: \.self) { item in
                                Label(item, systemImage: section.systemImage)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    if kind == .fullBackup {
                        WarningBanner(title: "Full Backup", message: "This backup includes all GradeDraft data stored on this device, including student work, original files, reviewed text, rubrics, evidence links, private notes, exports, and teacher-only review records. Store securely.", status: .teacherOnly)
                    }
                    PrimaryActionButton(title: kind.confirmTitle, systemImage: "square.and.arrow.up", action: onConfirm)
                }
                .padding(GradeDraftLayout.screenPadding)
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

struct RestorePreviewCard: View {
    var preview: BackupRestorePreview

    var body: some View {
        GroupedListCard(title: "Backup Preview", subtitle: preview.summary) {
            MetricStrip(metrics: [
                .init("Assignments", value: "\(preview.assignmentCount)"),
                .init("Classes", value: "\(preview.classCount)"),
                .init("Students", value: "\(preview.studentCount)"),
                .init("Original files", value: "\(preview.sourceFileCount)")
            ])
            .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
            .padding(.bottom, 10)
            if preview.conflictAssignmentIDs.isEmpty {
                BlockingIssueRow(title: "No matching records found", detail: "Import can continue with the selected option.", status: .onTrack)
            } else {
                RestoreConflictRow(count: preview.conflictAssignmentIDs.count)
            }
            ForEach(preview.warnings, id: \.self) { warning in
                BlockingIssueRow(title: "Needs attention", detail: warning, status: .needsAttention)
            }
        }
    }
}

struct RestoreConflictRow: View {
    var count: Int

    var body: some View {
        BlockingIssueRow(
            title: "Matching records found",
            detail: "\(count) record(s) already exist on this device. Choose how GradeDraft should handle them.",
            status: .needsAttention
        )
    }
}

struct RestoreConflictResolutionSheet: View {
    @Binding var selection: BackupConflictResolution
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Matching records found") {
                    Picker("Backup import option", selection: $selection) {
                        ForEach(BackupConflictResolution.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }
                Section("Import as New Copy") {
                    Text("Keep your current record and import the backup version separately. Original files from the backup will be copied to the new record.")
                }
            }
            .navigationTitle("Backup Import")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }
}
