import Foundation

// MARK: - Export, share, backup, and delete warnings

/// Source: docs/GRADING_CONTENT_SOURCE_OF_TRUTH.md, Section 18.
/// Use these definitions before export, sharing, clipboard, backup, and destructive flows.
enum ExportWarningCatalog {
    static let all: [ExportWarningDefinition] = [
        ExportWarningDefinition(
            id: "global-export-warning",
            name: "Global export confirmation",
            title: #"""
Export student information?
"""#,
            body: #"""
This export may include student names, assignment work, grades, rubric scores, feedback, and teacher notes. Once exported, the file may leave the app's protected local storage. Store and share it only through approved school channels.
"""#,
            warningLine: "This content may contain identifiable student information.",
            securityNote: "Use approved school storage and sharing channels only.",
            checklist: [
                "Confirm the destination is approved for student records.",
                "Confirm the export is needed for a current teaching or recordkeeping purpose.",
                "Confirm the file will not be shared with unintended recipients."
            ],
            primaryButton: "Continue to Export",
            secondaryButton: "Cancel",
            finalButton: "Export",
            acknowledgementText: "I understand this file may contain sensitive student information.",
            requiresAcknowledgement: true
        ),
        ExportWarningDefinition(
            id: "student-report-warning",
            name: "Student-facing report export",
            title: #"""
Review student-facing report
"""#,
            body: #"""
This report is intended for student or family review. Confirm that it includes only the feedback, scores, and evidence you want the student or family to see.
"""#,
            warningLine: "Student-facing exports must be previewed before release.",
            checklist: [
                "Confirm the final review is approved.",
                "Confirm teacher-only notes and draft reasoning are excluded.",
                "Confirm the wording is appropriate for the student or family."
            ],
            primaryButton: "Preview Report",
            secondaryButton: "Cancel",
            finalButton: "Export Student Report",
            postPreviewConfirmation: "I reviewed this report and confirmed it is appropriate to share.",
            acknowledgementText: "I reviewed the report and confirmed it is appropriate to share.",
            requiresAcknowledgement: true,
            blocksStudentFacingExportByDefault: true
        ),
        ExportWarningDefinition(
            id: "teacher-only-record-warning",
            name: "Teacher-only record export",
            title: #"""
Export teacher-only grading record?
"""#,
            body: #"""
This file may include internal grading notes, draft scores, rubric reasoning, OCR uncertainty flags, and teacher annotations. It is not intended for students or families unless reviewed and redacted.
"""#,
            warningLine: "This is a private teacher record, not a student-facing report.",
            securityNote: "Store only with internal school records or other approved teacher-only systems.",
            checklist: [
                "Confirm the export is for teacher or school recordkeeping.",
                "Confirm students or families will not receive teacher-only sections without review.",
                "Confirm draft and OCR uncertainty information is permitted in the destination."
            ],
            primaryButton: "Export Teacher Record",
            secondaryButton: "Cancel",
            finalButton: "Export Teacher Record",
            acknowledgementText: "I understand this export may include teacher-only content.",
            requiresAcknowledgement: true
        ),
        ExportWarningDefinition(
            id: "pdf-warning",
            name: "PDF export warning",
            title: #"""
Export PDF with student information?
"""#,
            body: #"""
This PDF may include student names, assignment text, grading feedback, rubric scores, and evidence quotes. Review the preview before sharing. Once exported, the PDF can be copied, printed, emailed, uploaded, or forwarded outside the app.
"""#,
            warningLine: "PDF files can be forwarded or printed outside the app.",
            checklist: [
                "Preview the generated PDF.",
                "Confirm the visible sections match the intended audience.",
                "Confirm the file name and destination are appropriate."
            ],
            primaryButton: "Preview PDF",
            secondaryButton: "Cancel",
            finalButton: "Export PDF",
            postPreviewConfirmation: "I reviewed the PDF preview and confirmed it is ready to export.",
            acknowledgementText: "I understand this PDF may expose student information if shared incorrectly.",
            requiresAcknowledgement: true
        ),
        ExportWarningDefinition(
            id: "csv-warning",
            name: "CSV export warning",
            title: #"""
Export spreadsheet data?
"""#,
            body: #"""
This CSV may include student names, scores, grades, rubric labels, and comments. CSV files are easy to copy, upload, email, and re-import into other systems. Use only approved school storage and transfer methods.
"""#,
            warningLine: "Spreadsheet exports can expose many records at once.",
            checklist: [
                "Confirm only permitted rows are included.",
                "Confirm the CSV does not include draft grades unless intended for teacher use.",
                "Confirm the destination is approved."
            ],
            primaryButton: "Export CSV",
            secondaryButton: "Cancel",
            finalButton: "Export CSV",
            acknowledgementText: "I understand this file may expose student records if shared incorrectly.",
            requiresAcknowledgement: true
        ),
        ExportWarningDefinition(
            id: "json-backup-warning",
            name: "JSON export warning",
            title: #"""
Export structured data?
"""#,
            body: #"""
This JSON file may contain full assignment records, OCR text, rubric data, scores, feedback, teacher notes, and internal metadata. JSON exports may reveal more information than a student-facing report.
"""#,
            warningLine: "Structured data exports can include complete local records.",
            checklist: [
                "Confirm the backup is permitted by your school or district.",
                "Confirm the storage location is protected.",
                "Confirm you understand this may include teacher-only metadata."
            ],
            primaryButton: "Export JSON",
            secondaryButton: "Cancel",
            finalButton: "Export JSON",
            acknowledgementText: "I understand this export may include complete local records.",
            requiresAcknowledgement: true
        ),
        ExportWarningDefinition(
            id: "zip-archive-warning",
            name: "ZIP/archive export warning",
            title: #"""
Export archive with source files?
"""#,
            body: #"""
This archive may include scanned work images, OCR text, grading records, feedback drafts, rubrics, and teacher notes. Archives can contain multiple files and may expose more student information than expected.
"""#,
            warningLine: "Archives can include original source files and private records.",
            securityNote: "Review archive contents before sharing or retaining the file.",
            checklist: [
                "Review the archive inventory.",
                "Confirm original source files are allowed in this export.",
                "Confirm the destination is approved for backups."
            ],
            primaryButton: "Review Archive Contents",
            secondaryButton: "Cancel",
            finalButton: "Create Archive",
            postPreviewConfirmation: "I reviewed the archive inventory and confirmed it is permitted.",
            acknowledgementText: "I understand this archive may include original student work and private teacher records.",
            requiresAcknowledgement: true
        ),
        ExportWarningDefinition(
            id: "clipboard-warning",
            name: "Clipboard warning",
            title: #"""
Copy student information?
"""#,
            body: #"""
The copied text may include student information. Other apps, shared devices, or clipboard history tools may expose copied content. Copy only what you need.
"""#,
            warningLine: "Clipboard content may be visible to other apps or tools.",
            primaryButton: "Copy",
            secondaryButton: "Cancel",
            finalButton: "Copy",
            acknowledgementText: "I understand copied content may be exposed outside GradeDraft.",
            requiresAcknowledgement: true
        ),
        ExportWarningDefinition(
            id: "share-sheet-warning",
            name: "Share sheet warning",
            title: #"""
Share outside the app?
"""#,
            body: #"""
You are about to send a file or text to another app. GradeDraft cannot control how that destination app stores, syncs, forwards, or protects the information.
"""#,
            warningLine: "The destination app controls the shared content after you send it.",
            checklist: [
                "Confirm the destination app is approved.",
                "Confirm the recipient or storage location is correct."
            ],
            primaryButton: "Open Share Sheet",
            secondaryButton: "Cancel",
            finalButton: "Open Share Sheet",
            acknowledgementText: "I understand the destination app controls the shared content after export.",
            requiresAcknowledgement: true
        ),
        ExportWarningDefinition(
            id: "backup-toggle-warning",
            name: "Backup toggle warning",
            title: #"""
Include student records in device backup?
"""#,
            body: #"""
By default, GradeDraft keeps student records local and excludes sensitive app files from backup where supported. If you enable backup for student records, copies may be stored outside this device according to your device and account settings.
"""#,
            warningLine: "Device backup may copy local student records outside this device.",
            securityNote: "Confirm this is permitted before changing the local backup exclusion setting.",
            checklist: [
                "Confirm your school or district permits device backup for these records.",
                "Confirm the device account and backup destination are appropriate.",
                "Confirm you can reverse the setting if required."
            ],
            primaryButton: "Enable Backup",
            secondaryButton: "Keep Local Only",
            finalButton: "Enable Backup",
            defaultChoice: "Keep Local Only",
            acknowledgementText: "I have confirmed this is permitted by my school or district.",
            requiresAcknowledgement: true
        ),
        ExportWarningDefinition(
            id: "delete-local-data-warning",
            name: "Delete local data warning",
            title: #"""
Delete local student records?
"""#,
            body: #"""
This will remove the selected records from this device. This action may delete scans, OCR text, scores, feedback, and teacher notes stored in the app. Export a permitted backup first if your school requires retention.
"""#,
            warningLine: "This destructive action cannot be undone from inside GradeDraft.",
            checklist: [
                "Confirm the selected local records should be deleted.",
                "Confirm required retention or backup obligations are satisfied.",
                "Confirm you are not deleting another student's work by mistake."
            ],
            primaryButton: "Delete Records",
            secondaryButton: "Cancel",
            finalButton: "Delete Records",
            escalatedConfirmation: "Type DELETE to confirm local record deletion.",
            acknowledgementText: "I understand this local deletion cannot be undone from inside GradeDraft.",
            requiresAcknowledgement: true
        ),
        ExportWarningDefinition(
            id: "teacher-notes-inclusion-warning",
            name: "Teacher notes inclusion warning",
            title: #"""
Include teacher-only notes?
"""#,
            body: #"""
Teacher-only notes may contain internal observations, draft reasoning, or information not intended for students or families. Include them only if this export is for internal school use.
"""#,
            warningLine: "Teacher notes are private by default.",
            checklist: [
                "Confirm the export audience is teacher-only or school-internal.",
                "Confirm student-facing copies will not include these notes."
            ],
            primaryButton: "Include Teacher Notes",
            secondaryButton: "Exclude Teacher Notes",
            finalButton: "Include Teacher Notes",
            acknowledgementText: "I understand this export may include private teacher notes.",
            requiresAcknowledgement: true
        ),
        ExportWarningDefinition(
            id: "draft-grade-export-warning",
            name: "Draft grade export warning",
            title: #"""
Export draft scores?
"""#,
            body: #"""
Some scores or comments are still marked as drafts. Draft grading content should not be shared with students or families unless you have reviewed and finalized it.
"""#,
            warningLine: "Draft grading content requires teacher review before student-facing sharing.",
            checklist: [
                "Confirm draft scores are intended for teacher-only use.",
                "Confirm student-facing exports are blocked until final approval."
            ],
            primaryButton: "Review Drafts",
            secondaryButton: "Export Teacher Copy",
            finalButton: "Export Teacher Copy",
            acknowledgementText: "I understand this export may include draft grading content.",
            requiresAcknowledgement: true
        )
    ]

    static let clearStudentWorkWarning = ExportWarningDefinition(
        id: "clear-student-work-warning",
        name: "Clear current assignment work warning",
        title: "Clear student work from this assignment?",
        body: "This clears the reviewed student text, OCR state, source-file references, draft grading, and final review for this assignment. It does not delete the assignment record itself.",
        warningLine: "Only the current assignment's student work and review state will be cleared.",
        checklist: [
            "Confirm this is the assignment you intend to clear.",
            "Confirm any required recordkeeping copy already exists."
        ],
        primaryButton: "Clear Work",
        secondaryButton: "Cancel",
        finalButton: "Clear Work",
        acknowledgementText: "I understand this clears the current assignment work and review state.",
        requiresAcknowledgement: true
    )

    static func warning(id: String) -> ExportWarningDefinition? {
        all.first { $0.id == id }
    }

    static func primaryWarning(for exportKind: ExportKind) -> ExportWarningDefinition? {
        warnings(for: exportKind).first
    }

    static func warnings(for exportKind: ExportKind) -> [ExportWarningDefinition] {
        warningIDs(for: exportKind).compactMap { warning(id: $0) }
    }

    static func warningIDs(for exportKind: ExportKind) -> [String] {
        switch exportKind {
        case .studentMarkdown:
            return ["student-report-warning"]
        case .teacherAuditMarkdown:
            return ["teacher-only-record-warning"]
        case .studentPDF:
            return ["pdf-warning", "student-report-warning"]
        case .teacherAuditPDF:
            return ["teacher-only-record-warning", "pdf-warning"]
        case .csvGradebook:
            return ["csv-warning"]
        case .zipArchive:
            return ["zip-archive-warning"]
        case .fullBackupArchive:
            return ["zip-archive-warning", "json-backup-warning"]
        case .backupJSON:
            return ["json-backup-warning"]
        case .assignmentGradebookArchive:
            return ["zip-archive-warning", "csv-warning"]
        }
    }
}
