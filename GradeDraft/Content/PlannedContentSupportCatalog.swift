import Foundation

// MARK: - Typed support catalogs for planned grading content

/// Runtime-safe planned-content copy. These entries are guardrails and UI/support text only;
/// they do not expose deferred features as working functionality.
enum PlannedContentSupportCatalog {
    static let ocrReviewStates: [PlannedCopyItem] = [
        PlannedCopyItem(id: "ocr-not-needed", title: "No OCR review needed", body: "The assignment uses typed or pasted text and does not require scanned-text review."),
        PlannedCopyItem(id: "ocr-needs-review", title: "Review scanned text", body: "Teacher review is required before scanned text can be used for drafting feedback."),
        PlannedCopyItem(id: "ocr-reviewed", title: "Scanned text reviewed", body: "A teacher confirmed the OCR text that will be used as student evidence."),
        PlannedCopyItem(id: "ocr-blocked", title: "OCR review blocked", body: "The scanned text is not ready. Fix or replace the source before drafting feedback.")
    ]

    static let ocrConfidenceBands: [PlannedCopyItem] = [
        PlannedCopyItem(id: "ocr-confidence-high", title: "High confidence", body: "Most recognized text appears reliable, but teacher review remains available."),
        PlannedCopyItem(id: "ocr-confidence-medium", title: "Mixed confidence", body: "Some text may need correction before it is used as grading evidence."),
        PlannedCopyItem(id: "ocr-confidence-low", title: "Low confidence", body: "Treat affected lines as uncertain and require teacher review before grading."),
        PlannedCopyItem(id: "ocr-confidence-unavailable", title: "No confidence data", body: "The app cannot verify OCR quality for this text. Review manually before grading.")
    ]

    static let localAIAvailabilityStates: [PlannedCopyItem] = [
        PlannedCopyItem(id: "local-ai-available", title: "Local draft feedback available", body: "Draft feedback can be generated locally when the grading packet is ready."),
        PlannedCopyItem(id: "local-ai-unavailable", title: "Local draft feedback unavailable", body: "No cloud fallback is provided. Continue with manual teacher review."),
        PlannedCopyItem(id: "local-ai-malformed-output", title: "Malformed local output", body: "The app must reject malformed draft output and ask the teacher to retry or grade manually."),
        PlannedCopyItem(id: "local-ai-needs-input", title: "More grading input needed", body: "Add reviewed student text and a grading standard before requesting local draft feedback.")
    ]

    static let teacherReviewWorkflowCopy: [PlannedCopyItem] = [
        PlannedCopyItem(id: "teacher-review-required", title: "Teacher review required", body: "The local draft is a proposal. The teacher must review, edit, and approve every final score."),
        PlannedCopyItem(id: "criterion-review", title: "Criterion review", body: "Each criterion score needs evidence, points within range, and teacher confirmation."),
        PlannedCopyItem(id: "final-review-stale", title: "Final review needs recheck", body: "A grading input changed after final review, so the teacher must recheck the record."),
        PlannedCopyItem(id: "student-export-blocked", title: "Student export blocked", body: "Student-facing export remains blocked until the final review is approved and current.")
    ]

    static let studentFeedbackRules: [PlannedRuleItem] = [
        PlannedRuleItem(id: "feedback-specific", text: "Use specific evidence-based feedback rather than broad praise."),
        PlannedRuleItem(id: "feedback-constructive", text: "Give next steps the student can act on."),
        PlannedRuleItem(id: "feedback-no-private-notes", text: "Exclude private teacher notes and internal uncertainty reasoning from student-facing reports."),
        PlannedRuleItem(id: "feedback-no-traits", text: "Do not infer personality, effort, intent, ability, demographic traits, or support needs."),
        PlannedRuleItem(id: "feedback-age-appropriate", text: "Keep wording appropriate for the class level and teacher-supplied context.")
    ]

    static let privacyCopy: [PlannedCopyItem] = [
        PlannedCopyItem(id: "privacy-local-first", title: "Local-first storage", body: "Student work and grading records are stored locally unless the teacher exports them."),
        PlannedCopyItem(id: "privacy-no-cloud-fallback", title: "No cloud fallback", body: "If a local feature is unavailable, the app does not silently switch to an external service."),
        PlannedCopyItem(id: "privacy-teacher-only", title: "Teacher-only by default", body: "Draft records, teacher notes, answer keys, exemplars, and audit data are private teacher content by default."),
        PlannedCopyItem(id: "privacy-export-control", title: "Teacher-controlled export", body: "The teacher must confirm export and share actions before content leaves local app storage.")
    ]

    static let emptyAndReadinessStates: [PlannedCopyItem] = [
        PlannedCopyItem(id: "empty-add-work", title: "Add student work", body: "Paste text or add scanned work before grading."),
        PlannedCopyItem(id: "empty-add-standard", title: "Add a grading standard", body: "Add a rubric, answer key, exemplar, or grading criteria before drafting feedback."),
        PlannedCopyItem(id: "empty-review-ocr", title: "Review scanned text", body: "Confirm OCR text before it is used as evidence."),
        PlannedCopyItem(id: "empty-start-review", title: "Start final review", body: "Review and approve criterion scores before student-facing export."),
        PlannedCopyItem(id: "empty-export-blocked", title: "Export blocked", body: "Student-facing export is blocked until final review is approved and current.")
    ]

    static let australianCurriculumGuardrails: [PlannedCopyItem] = [
        PlannedCopyItem(id: "curriculum-local-reference", title: "Local reference only", body: "Curriculum references are local teacher aids, not official reporting certification."),
        PlannedCopyItem(id: "curriculum-confirm", title: "Teacher confirmation required", body: "Confirm jurisdiction, year level, learning area, and wording before using curriculum references."),
        PlannedCopyItem(id: "curriculum-no-official-claim", title: "No official claim", body: "Do not present local curriculum mappings as official standards reporting unless that workflow is implemented and reviewed.")
    ]

    static let inclusiveSafeguards: [PlannedRuleItem] = [
        PlannedRuleItem(id: "inclusive-adjustments", text: "Use adjustment context only when the teacher supplies it and only for the intended grading purpose."),
        PlannedRuleItem(id: "inclusive-no-diagnosis", text: "Do not infer diagnosis, disability, EAL/D status, giftedness, or support level from student work."),
        PlannedRuleItem(id: "inclusive-evidence", text: "Separate submitted evidence from teacher-supplied adjustment notes."),
        PlannedRuleItem(id: "inclusive-teacher-review", text: "Flag inclusive-practice uncertainty for teacher review rather than resolving it automatically.")
    ]

    static let formativeModeSchema: [PlannedCopyItem] = [
        PlannedCopyItem(id: "formative-focus", title: "Formative focus", body: "Teacher-supplied formative focus shapes feedback emphasis without changing evidence requirements."),
        PlannedCopyItem(id: "formative-next-step", title: "Next step", body: "Feedback should identify a realistic next step tied to the submitted work."),
        PlannedCopyItem(id: "formative-no-final-claim", title: "No final-grade claim", body: "Formative mode does not remove teacher review or final approval requirements.")
    ]

    static let futureModeGuardrails: [PlannedRuleItem] = [
        PlannedRuleItem(id: "future-handwriting", text: "Handwriting-specific grading must not be exposed as working unless implemented and tested."),
        PlannedRuleItem(id: "future-diagram", text: "Diagram or visual-artifact grading must require teacher-confirmed evidence before scoring."),
        PlannedRuleItem(id: "future-math-working", text: "Math-working analysis must not be claimed unless implemented with matching tests."),
        PlannedRuleItem(id: "future-lms", text: "LMS sync and cloud backup must not be presented as working unless implemented with tests and privacy review.")
    ]

    static let exportFormatRequirements: [PlannedCopyItem] = [
        PlannedCopyItem(id: "export-student-report", title: "Student report", body: "Student reports exclude teacher-only notes, draft reasoning, and internal audit trail by default."),
        PlannedCopyItem(id: "export-teacher-audit", title: "Teacher audit", body: "Teacher audit reports include grading packet context, export records, and audit events."),
        PlannedCopyItem(id: "export-csv", title: "CSV grade summary", body: "CSV exports should be treated as student record exports and confirmed before sharing."),
        PlannedCopyItem(id: "export-archive", title: "Archive", body: "Archives may include original sources and private records, so inventory and confirmation are required."),
        PlannedCopyItem(id: "export-backup", title: "Backup", body: "Backups may include complete local records and must be treated as sensitive student data.")
    ]

    static let acceptanceCriteria: [PlannedRuleItem] = [
        PlannedRuleItem(id: "accept-rubrics", text: "Nine rubric templates are available from the new catalog."),
        PlannedRuleItem(id: "accept-instructions", text: "Eleven teacher instruction templates are available and insertable."),
        PlannedRuleItem(id: "accept-answer-exemplar-formative", text: "Answer-key, exemplar, and formative templates are available and insertable without silently deleting teacher content."),
        PlannedRuleItem(id: "accept-warnings", text: "Export, share, backup, and delete warnings are available and attached to the correct flows."),
        PlannedRuleItem(id: "accept-stale", text: "Template insertion changes the grading packet fingerprint and stale-state behavior remains intact."),
        PlannedRuleItem(id: "accept-report-separation", text: "Student reports exclude teacher-only content; teacher audit reports include grading context and audit trail."),
        PlannedRuleItem(id: "accept-prohibited", text: "Catalog and visible UI copy avoid prohibited product claims.")
    ]
}
