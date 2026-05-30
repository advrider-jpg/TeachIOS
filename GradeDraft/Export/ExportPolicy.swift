import Foundation

struct ExportContentPolicy: Equatable, Identifiable {
    var id: ExportKind { kind }
    var kind: ExportKind
    var warningTitle: String
    var warningBody: String
    var primaryButtonTitle: String
    var secondaryButtonTitle: String
    var isStudentFacing: Bool
    var isTeacherOnly: Bool
    var requiresApprovedFinalReview: Bool
    var requiresShareWarning: Bool
    var requiresLocalAuthenticationWhenAvailable: Bool
    var includesStudentNames: Bool
    var includesAssignmentWork: Bool
    var includesReviewedText: Bool
    var includesOCRText: Bool
    var includesSourceFiles: Bool
    var includesFinalGrades: Bool
    var includesDraftGrades: Bool
    var includesStudentFeedback: Bool
    var includesPrivateTeacherNotes: Bool
    var includesAuditEvents: Bool
    var includesInternalMetadata: Bool

    var inclusionSummaryLines: [String] {
        var lines: [String] = []
        lines.append(includesStudentNames ? "Includes student names or local identifiers." : "Does not include student names beyond report header/context.")
        if includesAssignmentWork { lines.append("Includes student work or reviewed text.") }
        if includesReviewedText { lines.append("Includes teacher-reviewed student text.") }
        if includesOCRText { lines.append("Includes OCR text or OCR review state.") }
        if includesSourceFiles { lines.append("Includes original or rendered source files when available.") }
        if includesFinalGrades { lines.append("Includes teacher-final grades or scores.") }
        if includesDraftGrades { lines.append("Includes draft grading content for teacher review.") }
        if includesStudentFeedback { lines.append("Includes student-facing feedback.") }
        if includesPrivateTeacherNotes { lines.append("Includes private teacher notes.") }
        if includesAuditEvents { lines.append("Includes audit events.") }
        if includesInternalMetadata { lines.append("Includes internal metadata or fingerprints.") }
        if kind == .csvGradebook || kind == .assignmentGradebookArchive { lines.append("Spreadsheet formula-like text is neutralized before export.") }
        return lines
    }
}

extension ExportKind {
    var contentPolicy: ExportContentPolicy {
        switch self {
        case .studentMarkdown:
            return ExportContentPolicy(
                kind: self,
                warningTitle: "Review student-facing report",
                warningBody: "This report is intended for student or family review. Confirm that it includes only final teacher-approved feedback, scores, and evidence you want the student or family to see.",
                primaryButtonTitle: "Export Student Report",
                secondaryButtonTitle: "Cancel",
                isStudentFacing: true,
                isTeacherOnly: false,
                requiresApprovedFinalReview: true,
                requiresShareWarning: true,
                requiresLocalAuthenticationWhenAvailable: false,
                includesStudentNames: true,
                includesAssignmentWork: false,
                includesReviewedText: false,
                includesOCRText: false,
                includesSourceFiles: false,
                includesFinalGrades: true,
                includesDraftGrades: false,
                includesStudentFeedback: true,
                includesPrivateTeacherNotes: false,
                includesAuditEvents: false,
                includesInternalMetadata: false
            )
        case .studentPDF:
            return ExportContentPolicy(
                kind: self,
                warningTitle: "Review student-facing PDF",
                warningBody: "This PDF is intended for student or family review. It is generated from the same final-only student report content as the Markdown export.",
                primaryButtonTitle: "Create Student Report PDF",
                secondaryButtonTitle: "Cancel",
                isStudentFacing: true,
                isTeacherOnly: false,
                requiresApprovedFinalReview: true,
                requiresShareWarning: true,
                requiresLocalAuthenticationWhenAvailable: false,
                includesStudentNames: true,
                includesAssignmentWork: false,
                includesReviewedText: false,
                includesOCRText: false,
                includesSourceFiles: false,
                includesFinalGrades: true,
                includesDraftGrades: false,
                includesStudentFeedback: true,
                includesPrivateTeacherNotes: false,
                includesAuditEvents: false,
                includesInternalMetadata: false
            )
        case .teacherAuditMarkdown:
            return ExportContentPolicy(
                kind: self,
                warningTitle: "Teacher-only review report",
                warningBody: "This report is a teacher-only audit record. Do not share it with students or families unless you have separately reviewed and redacted it.",
                primaryButtonTitle: "Export Teacher Review",
                secondaryButtonTitle: "Cancel",
                isStudentFacing: false,
                isTeacherOnly: true,
                requiresApprovedFinalReview: false,
                requiresShareWarning: true,
                requiresLocalAuthenticationWhenAvailable: true,
                includesStudentNames: true,
                includesAssignmentWork: true,
                includesReviewedText: true,
                includesOCRText: true,
                includesSourceFiles: false,
                includesFinalGrades: true,
                includesDraftGrades: true,
                includesStudentFeedback: true,
                includesPrivateTeacherNotes: true,
                includesAuditEvents: true,
                includesInternalMetadata: true
            )
        case .teacherAuditPDF:
            return ExportContentPolicy(
                kind: self,
                warningTitle: "Teacher-only review PDF",
                warningBody: "This PDF is a teacher-only audit record. Do not share it with students or families unless you have separately reviewed and redacted it.",
                primaryButtonTitle: "Create Teacher Review PDF",
                secondaryButtonTitle: "Cancel",
                isStudentFacing: false,
                isTeacherOnly: true,
                requiresApprovedFinalReview: false,
                requiresShareWarning: true,
                requiresLocalAuthenticationWhenAvailable: true,
                includesStudentNames: true,
                includesAssignmentWork: true,
                includesReviewedText: true,
                includesOCRText: true,
                includesSourceFiles: false,
                includesFinalGrades: true,
                includesDraftGrades: true,
                includesStudentFeedback: true,
                includesPrivateTeacherNotes: true,
                includesAuditEvents: true,
                includesInternalMetadata: true
            )
        case .csvGradebook:
            return ExportContentPolicy(
                kind: self,
                warningTitle: "Teacher-only CSV grade summary",
                warningBody: "This CSV is for local teacher gradebook records. It quotes every cell and neutralizes spreadsheet formula-like text, but it may still contain student identifiers and grade statuses.",
                primaryButtonTitle: "Create Gradebook CSV",
                secondaryButtonTitle: "Cancel",
                isStudentFacing: false,
                isTeacherOnly: true,
                requiresApprovedFinalReview: false,
                requiresShareWarning: true,
                requiresLocalAuthenticationWhenAvailable: true,
                includesStudentNames: true,
                includesAssignmentWork: false,
                includesReviewedText: false,
                includesOCRText: false,
                includesSourceFiles: false,
                includesFinalGrades: true,
                includesDraftGrades: false,
                includesStudentFeedback: false,
                includesPrivateTeacherNotes: false,
                includesAuditEvents: false,
                includesInternalMetadata: true
            )
        case .zipArchive:
            return ExportContentPolicy(
                kind: self,
                warningTitle: "Teacher-only archive ZIP",
                warningBody: "This ZIP may include private teacher notes, audit records, OCR review state, original files, and internal metadata. Treat it as a sensitive student record.",
                primaryButtonTitle: "Create Teacher Archive",
                secondaryButtonTitle: "Cancel",
                isStudentFacing: false,
                isTeacherOnly: true,
                requiresApprovedFinalReview: false,
                requiresShareWarning: true,
                requiresLocalAuthenticationWhenAvailable: true,
                includesStudentNames: true,
                includesAssignmentWork: true,
                includesReviewedText: true,
                includesOCRText: true,
                includesSourceFiles: true,
                includesFinalGrades: true,
                includesDraftGrades: true,
                includesStudentFeedback: true,
                includesPrivateTeacherNotes: true,
                includesAuditEvents: true,
                includesInternalMetadata: true
            )
        case .fullBackupArchive:
            return ExportContentPolicy(
                kind: self,
                warningTitle: "Full local backup archive",
                warningBody: "This backup includes GradeDraft records stored on this device, including teacher-only records and original files when available. Store it only in school-approved locations.",
                primaryButtonTitle: "Create Full Backup",
                secondaryButtonTitle: "Cancel",
                isStudentFacing: false,
                isTeacherOnly: true,
                requiresApprovedFinalReview: false,
                requiresShareWarning: true,
                requiresLocalAuthenticationWhenAvailable: true,
                includesStudentNames: true,
                includesAssignmentWork: true,
                includesReviewedText: true,
                includesOCRText: true,
                includesSourceFiles: true,
                includesFinalGrades: true,
                includesDraftGrades: true,
                includesStudentFeedback: true,
                includesPrivateTeacherNotes: true,
                includesAuditEvents: true,
                includesInternalMetadata: true
            )
        case .backupJSON:
            return ExportContentPolicy(
                kind: self,
                warningTitle: "Legacy backup record",
                warningBody: "This legacy backup classification represents complete sensitive local records if used. Prefer the full backup archive flow.",
                primaryButtonTitle: "Create Backup",
                secondaryButtonTitle: "Cancel",
                isStudentFacing: false,
                isTeacherOnly: true,
                requiresApprovedFinalReview: false,
                requiresShareWarning: true,
                requiresLocalAuthenticationWhenAvailable: true,
                includesStudentNames: true,
                includesAssignmentWork: true,
                includesReviewedText: true,
                includesOCRText: true,
                includesSourceFiles: false,
                includesFinalGrades: true,
                includesDraftGrades: true,
                includesStudentFeedback: true,
                includesPrivateTeacherNotes: true,
                includesAuditEvents: true,
                includesInternalMetadata: true
            )
        case .assignmentGradebookArchive:
            return ExportContentPolicy(
                kind: self,
                warningTitle: "Gradebook archive ZIP",
                warningBody: "This ZIP contains teacher-only gradebook records including assignment data, reports, OCR documents, evidence references, and original files when available. Treat it as sensitive student data.",
                primaryButtonTitle: "Create Gradebook Archive",
                secondaryButtonTitle: "Cancel",
                isStudentFacing: false,
                isTeacherOnly: true,
                requiresApprovedFinalReview: false,
                requiresShareWarning: true,
                requiresLocalAuthenticationWhenAvailable: true,
                includesStudentNames: true,
                includesAssignmentWork: true,
                includesReviewedText: true,
                includesOCRText: true,
                includesSourceFiles: true,
                includesFinalGrades: true,
                includesDraftGrades: true,
                includesStudentFeedback: true,
                includesPrivateTeacherNotes: true,
                includesAuditEvents: true,
                includesInternalMetadata: true
            )
        }
    }
}
