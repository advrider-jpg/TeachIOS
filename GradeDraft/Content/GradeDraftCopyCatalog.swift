import Foundation

// MARK: - Central app copy and safety language

/// Copy and label rules generated from the grading content source of truth.
enum GradeDraftCopyCatalog {
    enum ProductIdentity {
        static let appName = "MarkForMe"
        static let shortDescription = "Teacher marking help that uses reviewed student work, rubrics and teacher notes to draft feedback."
        static let teacherPositioning = "MarkForMe drafts suggestions. Nothing is final until the teacher approves it."
    }

    enum Labels {
        static let safe = [
            #"""
Generate Draft Feedback
"""#,
            #"""
Review Draft
"""#,
            #"""
Teacher Review
"""#,
            #"""
Review Evidence
"""#,
            #"""
Finalize Grade
"""#,
            #"""
Teacher-Approved Grade
"""#,
            #"""
Draft Feedback
"""#,
            #"""
Needs Teacher Review
"""#
    ]
        static let prohibited = [
            #"""
Auto-grade
"""#,
            #"""
Accept AI Grade
"""#,
            #"""
AI final grade
"""#,
            #"""
Grade instantly
"""#,
            #"""
Fully automated
"""#,
            #"""
Guaranteed score
"""#,
            #"""
Objective AI marking
"""#,
            #"""
AI Teacher
"""#,
            #"""
Mark without review
"""#,
            #"""
Skip review
"""#,
            #"""
One-click grade
"""#
    ]
    }

    enum Readiness {
        static let ready = "Ready for draft feedback"
        static let missingStudentText = "Add or review student work before generating draft feedback."
        static let missingStandard = "Add a rubric, answer key, or exemplar before generating draft feedback."
        static let ocrReviewRequired = "Check scanned text before draft feedback."
        static let finalReviewRequired = "Teacher review is required before a final grade is recorded."
    }

    enum ReviewWorkflow {
        static let draftGenerated = "Draft feedback generated. Review evidence before finalizing."
        static let staleDraft = "Inputs changed after this draft was generated. Generate a new draft or complete a fresh teacher review."
        static let finalApproved = "Teacher-approved final grade."
        static let notFinal = "Not a final grade until teacher-approved."
    }

    enum Privacy {
        static let localFirst = "Student work and grading records are stored locally on this device unless the teacher explicitly exports or shares them."
        static let backupClarification = "Device backups and teacher-created exports may copy local files outside the app."
        static let notSecurityCertification = "Local fingerprints are used for app-state tracking and are not a security certification."
    }

    enum LocalAI {
        static let noCloudFallback = "Draft feedback is not available on this device. MarkForMe does not send student work away for marking."
        static let unavailable = "Draft feedback is not available on this device."
    }

    enum Australia {
        static let noOfficialImport = "No official curriculum import is enabled. Teacher-entered curriculum references are for local planning and review."
        static let notEndorsed = "Do not describe the app as officially endorsed by ACARA, NESA, VCAA, QCAA, SACE, TASC, SCSA, ACT BSSS, or NT authorities unless a real integration and permission exist."
    }

    enum OCRReview {
        static let states = [
            "Not needed: no scanned text requires review.",
            "Needs review: extracted text must be confirmed before draft feedback.",
            "Reviewed: teacher-confirmed text may be used in the grading packet.",
            "Blocked: scanned text is too uncertain or incomplete for draft feedback."
        ]
        static let confidenceBands = [
            "High confidence: review normally and confirm before grading.",
            "Medium confidence: check wording, spelling, and line breaks before grading.",
            "Low confidence: require close teacher review and cite uncertainty where relevant."
        ]
        static let copy = [
            "Review extracted text before draft feedback.",
            "Reject garbled lines rather than grading from them.",
            "Use teacher-confirmed text as the grading source."
        ]
    }

    enum TeacherReview {
        static let workflowCopy = [
            "Draft feedback is for teacher review only.",
            "Teacher-final scores remain separate from suggested scores.",
            "Evidence, uncertainty flags, and OCR concerns must be checked before approval.",
            "Final approval records the teacher-approved grade."
        ]
    }

    enum StudentFeedbackRules {
        static let rules = [
            "Use student-facing language that is specific, constructive, and concise.",
            "Do not include private teacher notes in student reports.",
            "Do not disclose raw model responses, internal compliance flags, or audit history to students by default.",
            "Do not infer effort, intent, motivation, behavior, demographics, disability, EAL/D status, giftedness, support level, or ability beyond submitted work.",
            "Cite reviewed student evidence when explaining a score."
        ]
    }

    enum ReadinessCopy {
        static let emptyStates = [
            "Add student work before draft feedback.",
            "Review scanned text before draft feedback.",
            "Add a grading standard before draft feedback.",
            "Draft feedback is not available on this device.",
            "Student-facing export is blocked until teacher approval."
        ]
    }

    enum RegionalCurriculum {
        static let safeguards = [
            "Teacher-entered curriculum references are local reference material.",
            "No official curriculum scoring or jurisdiction reporting compliance is claimed.",
            "Confirm curriculum references against your jurisdiction before reporting."
        ]
    }

    enum InclusiveSafeguards {
        static let rules = [
            "Do not infer disability, EAL/D status, giftedness, support level, behavior, or ability beyond submitted work.",
            "Use adjustment context only when teacher-supplied and relevant to the submitted work.",
            "Flag subjective criteria such as creativity, craftsmanship, effort, and presentation quality for teacher review."
        ]
    }

    enum FormativeMode {
        static let schema = [
            "Current evidence of learning",
            "Next small step",
            "Teacher follow-up prompt",
            "Confidence or uncertainty flag"
        ]
    }

    enum FutureModeGuardrails {
        static let unavailableModes = [
            "Handwriting grading is unavailable without teacher-confirmed text evidence.",
            "Diagram grading is unavailable without teacher-confirmed evidence.",
            "Poster, model, and visual artifact grading are unavailable without teacher-confirmed evidence.",
            "Math-working analysis is unavailable unless the reasoning is represented in reviewed text.",
            "LMS sync and cloud backup are unavailable unless separately implemented and tested."
        ]
    }

    enum ExportFormatRequirements {
        static let requirements = [
            "Student-facing reports exclude private teacher notes and internal review history by default.",
            "Teacher records are sensitive student records.",
            "CSV exports must be treated as student-record data.",
            "ZIP archives and backups may include original files and complete local records.",
            "Clipboard and share-sheet actions require explicit teacher confirmation."
        ]
    }

    enum AcceptanceCriteria {
        static let criteria = [
            "Rubric, instruction, answer-key, exemplar, and formative templates are available from typed catalogs.",
            "Template insertion changes the grading packet fingerprint without silently deleting teacher-entered content.",
            "Prompt generation includes optional teacher-supplied fields only when supplied.",
            "Student reports exclude teacher-only/internal fields by default.",
            "Teacher records include grading packet context and audit trail.",
            "Tests prevent catalog drift and prohibited wording."
        ]
    }

    enum SourceOfTruth {
        static let nonNegotiableRules: [String] = [
            "The default grading workflow must not require a server.",
            "The default workflow must not upload student work.",
            "The default workflow must not use cloud OCR.",
            "The default workflow must not use cloud AI grading.",
            "The app must not generate a proposed grade without at least one teacher-provided grading standard: rubric, answer key, exemplar, achievement-standard aspect, or custom grading criteria.",
            "The app must not grade scanned text until required scanned text review has been completed.",
            "Every proposed criterion score must cite student evidence or be marked for teacher review.",
            "The AI proposes; the teacher finalizes.",
            "Proposed points and teacher-final points must remain separate.",
            "Totals must be calculated deterministically in app code, not trusted from model output.",
            "Raw source input, scanned text, reviewed text, model proposal, teacher edits, final grade, exports, and audit events must remain separate records.",
            "A draft or final review must become stale when its source grading packet changes.",
            "Student-facing exports must exclude private teacher notes by default.",
            "Teacher record exports are sensitive student records.",
            "The UI must not imply that unavailable OCR, local AI, export, or grading functionality is working.",
            "The app must fail openly on OCR failure, local AI unavailability, malformed model output, persistence failure, or export failure.",
            "Handwriting, diagrams, posters, physical models, and visual artifacts require explicit teacher-confirmed evidence before grading.",
            "Subjective criteria such as creativity, craftsmanship, effort, or presentation quality require teacher review and must not be presented as fully automated judgements.",
            "The app must not infer student effort, intent, motivation, behavior, disability, EAL/D status, giftedness, demographic traits, support level, or ability beyond the submitted work.",
            "The app must not claim official curriculum scoring, official standards certification, or jurisdiction reporting compliance unless those features are separately implemented and reviewed."
        ]
    }
}
