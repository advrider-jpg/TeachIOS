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
                        .foregroundStyle(disabled ? Color(.secondaryLabel) : Color.blue)
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
    case studentReportMarkdown
    case teacherReviewMarkdown
    case studentReportPDF
    case teacherReviewPDF
    case fullBackup
    case teacherArchive
    case gradebookArchive

    var id: String { rawValue }

    var exportKind: ExportKind {
        switch self {
        case .studentReportMarkdown:
            return .studentMarkdown
        case .teacherReviewMarkdown:
            return .teacherAuditMarkdown
        case .studentReportPDF:
            return .studentPDF
        case .teacherReviewPDF:
            return .teacherAuditPDF
        case .fullBackup:
            return .fullBackupArchive
        case .teacherArchive:
            return .zipArchive
        case .gradebookArchive:
            return .csvGradebook
        }
    }

    var title: String {
        switch self {
        case .studentReportMarkdown:
            return "Student Report Markdown"
        case .teacherReviewMarkdown:
            return "Teacher Review Markdown"
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
        case .studentReportMarkdown:
            return "Student-facing text report for sharing after final approval."
        case .teacherReviewMarkdown:
            return "Teacher-only text record. Do not share with students or families."
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
        case .studentReportMarkdown:
            return "Create Student Report Markdown"
        case .teacherReviewMarkdown:
            return "Create Teacher Review Markdown"
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

    var baseWarnings: [ExportWarningDefinition] {
        ExportWarningCatalog.warnings(for: exportKind)
    }

    var warningStatus: GradeDraftUIStatus {
        switch self {
        case .studentReportMarkdown, .studentReportPDF:
            return .studentFacing
        default:
            return .teacherOnly
        }
    }

    var sections: [ExportDisclosureSection] {
        switch self {
        case .studentReportMarkdown, .studentReportPDF:
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
        case .teacherReviewMarkdown, .teacherReviewPDF:
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
            return [
                ExportDisclosureSection(title: "MAY INCLUDE", systemImage: "lock", items: [
                    "All local assignment records",
                    "Class, student, and roster records",
                    "Reviewed student text and original files",
                    "Rubrics, answer keys, exemplars, and teacher instructions",
                    "Private teacher notes",
                    "Export records and review history"
                ])
            ]
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

enum ExportConfirmationStep: Equatable {
    case warning
    case preview
    case finalConfirm
}

struct ExportConfirmationSheet: View {
    var kind: ExportConfirmationKind
    var assignment: AssignmentRecord
    var allAssignments: [AssignmentRecord]
    var onCancel: () -> Void
    var onConfirm: () -> Void

    @State private var acknowledgedWarningIDs: Set<String> = []
    @State private var previewConfirmed = false
    @State private var step: ExportConfirmationStep = .warning

    private var riskSummary: ExportRiskSummary {
        ExportRiskSummary(kind: kind, assignment: assignment, allAssignments: allAssignments)
    }

    private var warningDefinitions: [ExportWarningDefinition] {
        var definitions: [ExportWarningDefinition] = []
        func append(_ warning: ExportWarningDefinition?) {
            guard let warning, !definitions.contains(where: { $0.id == warning.id }) else { return }
            definitions.append(warning)
        }
        append(ExportWarningCatalog.warning(id: "global-export-warning"))
        kind.baseWarnings.forEach { append($0) }
        if riskSummary.includesPrivateNotes { append(ExportWarningCatalog.warning(id: "teacher-notes-inclusion-warning")) }
        if riskSummary.includesDraftContent { append(ExportWarningCatalog.warning(id: "draft-grade-export-warning")) }
        return definitions
    }

    private var acknowledgementWarnings: [ExportWarningDefinition] {
        warningDefinitions.filter(\.requiresAcknowledgement)
    }

    private var requiresPreview: Bool {
        warningDefinitions.contains { $0.postPreviewConfirmation != nil } || kind.requiresPreviewBeforeExport
    }

    private var canAdvanceFromWarnings: Bool {
        acknowledgementWarnings.allSatisfy { acknowledgedWarningIDs.contains($0.id) }
    }

    private var canConfirm: Bool {
        canAdvanceFromWarnings && (!requiresPreview || previewConfirmed)
    }

    private var primaryButtonTitle: String {
        switch step {
        case .warning:
            if requiresPreview { return warningDefinitions.first(where: { $0.postPreviewConfirmation != nil })?.primaryButton ?? "Preview Export" }
            return warningDefinitions.first?.finalButton ?? kind.confirmTitle
        case .preview:
            return warningDefinitions.first(where: { $0.finalButton != nil })?.finalButton ?? kind.confirmTitle
        case .finalConfirm:
            return warningDefinitions.first(where: { $0.finalButton != nil })?.finalButton ?? kind.confirmTitle
        }
    }

    private var previewText: String {
        switch kind {
        case .studentReportMarkdown, .studentReportPDF:
            return MarkdownReportBuilder.studentMarkdown(for: assignment)
        case .teacherReviewMarkdown, .teacherReviewPDF:
            return MarkdownReportBuilder.teacherAuditMarkdown(for: assignment, generatedForExportKind: kind.exportKind)
        case .teacherArchive:
            return archiveInventory(title: "Teacher archive inventory", assignments: [assignment])
        case .fullBackup:
            return archiveInventory(title: "Full backup inventory", assignments: allAssignments.isEmpty ? [assignment] : allAssignments)
        case .gradebookArchive:
            return archiveInventory(title: "Gradebook CSV inventory", assignments: allAssignments.isEmpty ? [assignment] : allAssignments)
        }
    }

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

                    switch step {
                    case .warning:
                        warningStep
                    case .preview:
                        previewStep
                    case .finalConfirm:
                        finalConfirmStep
                    }
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

    private var warningStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(warningDefinitions) { warning in
                warningCard(warning)
            }
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
            if riskSummary.affectedAssignmentCount > 1 {
                BlockingIssueRow(
                    title: "Export scope",
                    detail: "This export may include records for \(riskSummary.affectedAssignmentCount) assignment(s).",
                    status: .teacherOnly
                )
            }
            ForEach(acknowledgementWarnings) { warning in
                Toggle(isOn: binding(for: warning.id)) {
                    Text(warning.acknowledgementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "I understand: \(warning.title.trimmingCharacters(in: .whitespacesAndNewlines))" : warning.acknowledgementText.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.subheadline.weight(.semibold))
                }
                .toggleStyle(.switch)
            }
            PrimaryActionButton(
                title: primaryButtonTitle,
                systemImage: requiresPreview ? "doc.text.magnifyingglass" : "square.and.arrow.up",
                action: advanceOrConfirm,
                disabled: !canAdvanceFromWarnings
            )
        }
    }

    private var previewStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Preview before export")
                .font(.headline)
            Text(previewInstruction)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(previewText)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            Toggle(isOn: $previewConfirmed) {
                Text(previewConfirmationText)
                    .font(.subheadline.weight(.semibold))
            }
            .toggleStyle(.switch)
            PrimaryActionButton(title: primaryButtonTitle, systemImage: "square.and.arrow.up", action: onConfirm, disabled: !canConfirm)
        }
    }

    private var finalConfirmStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(warningDefinitions) { warning in warningCard(warning) }
            PrimaryActionButton(title: primaryButtonTitle, systemImage: "square.and.arrow.up", action: onConfirm, disabled: !canConfirm)
        }
    }

    private var previewInstruction: String {
        warningDefinitions.compactMap(\.postPreviewConfirmation).first ?? "Review the export content before creating the file."
    }

    private var previewConfirmationText: String {
        warningDefinitions.compactMap(\.postPreviewConfirmation).first ?? "I reviewed this export preview."
    }

    private func warningCard(_ warning: ExportWarningDefinition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            WarningBanner(
                title: warning.title.trimmingCharacters(in: .whitespacesAndNewlines),
                message: warning.body.trimmingCharacters(in: .whitespacesAndNewlines),
                status: kind.warningStatus
            )
            if let warningLine = warning.warningLine, !warningLine.isEmpty {
                Label(warningLine, systemImage: "exclamationmark.triangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            if let securityNote = warning.securityNote, !securityNote.isEmpty {
                Label(securityNote, systemImage: "lock.shield")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !warning.checklist.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Checklist")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(warning.checklist, id: \.self) { item in
                        Label(item, systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                }
            }
        }
    }

    private func binding(for warningID: String) -> Binding<Bool> {
        Binding(
            get: { acknowledgedWarningIDs.contains(warningID) },
            set: { newValue in
                if newValue { acknowledgedWarningIDs.insert(warningID) }
                else { acknowledgedWarningIDs.remove(warningID) }
            }
        )
    }

    private func advanceOrConfirm() {
        if requiresPreview {
            step = .preview
        } else {
            onConfirm()
        }
    }

    private func archiveInventory(title: String, assignments: [AssignmentRecord]) -> String {
        let records = assignments.isEmpty ? [assignment] : assignments
        let draftCount = records.filter(\.containsDraftGradingContent).count
        let sourceCount = records.reduce(0) { $0 + $1.sourceInputs.count }
        return """
        \(title)
        Assignment records: \(records.count)
        Assignments with draft or stale grading content: \(draftCount)
        Source file references: \(sourceCount)
        Includes private teacher notes: \(riskSummary.includesPrivateNotes ? "Yes" : "No")
        Includes original-source references: \(riskSummary.includesOriginalSources ? "Yes" : "No")
        """
    }
}

private extension ExportConfirmationKind {
    var requiresPreviewBeforeExport: Bool {
        switch self {
        case .studentReportMarkdown, .studentReportPDF, .teacherReviewPDF, .fullBackup, .teacherArchive:
            return true
        case .teacherReviewMarkdown, .gradebookArchive:
            return false
        }
    }
}

private extension ExportRiskSummary {
    init(kind: ExportConfirmationKind, assignment: AssignmentRecord, allAssignments: [AssignmentRecord]) {
        let scopedAssignments: [AssignmentRecord]
        switch kind {
        case .fullBackup, .gradebookArchive:
            scopedAssignments = allAssignments.isEmpty ? [assignment] : allAssignments
        default:
            scopedAssignments = [assignment]
        }

        let includesDraft: Bool
        switch kind {
        case .studentReportMarkdown, .studentReportPDF:
            includesDraft = false
        case .gradebookArchive:
            includesDraft = scopedAssignments.contains { $0.gradebookExportContainsDraftState }
        case .teacherReviewMarkdown, .teacherReviewPDF, .teacherArchive, .fullBackup:
            includesDraft = scopedAssignments.contains { $0.containsDraftGradingContent }
        }

        let includesPrivate: Bool
        switch kind {
        case .studentReportMarkdown, .studentReportPDF:
            includesPrivate = false
        case .teacherReviewMarkdown, .teacherReviewPDF, .fullBackup, .teacherArchive:
            includesPrivate = true
        case .gradebookArchive:
            includesPrivate = false
        }

        let includesSources: Bool
        switch kind {
        case .teacherArchive, .fullBackup:
            includesSources = scopedAssignments.contains { !$0.sourceInputs.isEmpty }
        default:
            includesSources = false
        }

        self.init(
            includesDraftContent: includesDraft,
            includesPrivateNotes: includesPrivate,
            includesOriginalSources: includesSources,
            affectedAssignmentCount: scopedAssignments.count
        )
    }
}

private extension AssignmentRecord {
    var containsDraftGradingContent: Bool {
        latestDraft != nil || (finalReview.map { $0.status != .approved } ?? false) || finalReviewIsStale
    }

    var gradebookExportContainsDraftState: Bool {
        if finalReview == nil, latestDraft != nil { return true }
        if let finalReview, finalReview.status != .approved { return true }
        return finalReviewIsStale
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
