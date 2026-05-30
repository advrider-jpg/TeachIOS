import Foundation

// MARK: - Teacher instruction templates

/// Source: docs/GRADING_CONTENT_SOURCE_OF_TRUTH.md, Section 7.
/// Applying these should append to customInstructions by default.
enum TeacherInstructionTemplateCatalog {
    static let all: [TeacherInstructionTemplate] = [
        TeacherInstructionTemplate(
            id: "general-evidence-first",
            name: "General evidence-first instruction",
            description: "Source-of-truth teacher instruction template: General evidence-first instruction.",
            text: #"""
Grade only from the reviewed student text and the grading materials I provided. For every criterion, cite evidence from the reviewed text or mark teacher review required if evidence is missing or unclear.
"""#,
            scope: .grading,
            priority: .standard,
            studentFacing: false,
            privateTeacherOnly: true
        ),
        TeacherInstructionTemplate(
            id: "do-not-penalize-conventions",
            name: "Do-not-penalize conventions instruction",
            description: "Source-of-truth teacher instruction template: Do-not-penalize conventions instruction.",
            text: #"""
Do not penalize spelling, grammar, punctuation, capitalization, or handwriting unless the rubric explicitly assesses conventions or the errors materially interfere with meaning.
"""#,
            scope: .accessibility,
            priority: .standard,
            studentFacing: false,
            privateTeacherOnly: true
        ),
        TeacherInstructionTemplate(
            id: "strict-answer-key",
            name: "Strict answer-key instruction",
            description: "Source-of-truth teacher instruction template: Strict answer-key instruction.",
            text: #"""
Use the answer key as the main scoring reference. Award equivalent wording when the meaning is correct. If the response is partially correct, identify which expected elements are present and which are missing.
"""#,
            scope: .answerKey,
            priority: .required,
            studentFacing: false,
            privateTeacherOnly: true
        ),
        TeacherInstructionTemplate(
            id: "exemplar-comparison",
            name: "Exemplar comparison instruction",
            description: "Source-of-truth teacher instruction template: Exemplar comparison instruction.",
            text: #"""
Use the exemplar only as a reference for quality and completeness. Do not require the student's response to match the exemplar wording. Score against the rubric criteria, not against stylistic similarity to the exemplar.
"""#,
            scope: .exemplar,
            priority: .standard,
            studentFacing: false,
            privateTeacherOnly: true
        ),
        TeacherInstructionTemplate(
            id: "formative-feedback",
            name: "Formative feedback instruction",
            description: "Source-of-truth teacher instruction template: Formative feedback instruction.",
            text: #"""
This is formative feedback. Emphasize current evidence of understanding, one misconception or gap if present, and one practical next step. Do not frame the output as a final grade unless I approve it as summative.
"""#,
            scope: .formative,
            priority: .standard,
            studentFacing: false,
            privateTeacherOnly: true
        ),
        TeacherInstructionTemplate(
            id: "summative-caution",
            name: "Summative caution instruction",
            description: "Source-of-truth teacher instruction template: Summative caution instruction.",
            text: #"""
This may be used for a summative record after teacher review. Keep score suggestions conservative when evidence is incomplete. Mark teacher review required for ambiguous rubric interpretation, missing evidence, or OCR uncertainty.
"""#,
            scope: .summative,
            priority: .standard,
            studentFacing: false,
            privateTeacherOnly: true
        ),
        TeacherInstructionTemplate(
            id: "ocr-uncertainty",
            name: "OCR uncertainty instruction",
            description: "Source-of-truth teacher instruction template: OCR uncertainty instruction.",
            text: #"""
Some text may have come from OCR. If a quote appears garbled, incomplete, or inconsistent, mark teacher review required and do not rely on that text for a confident score.
"""#,
            scope: .ocrReview,
            priority: .required,
            studentFacing: false,
            privateTeacherOnly: true
        ),
        TeacherInstructionTemplate(
            id: "eald-sensitive",
            name: "EAL/D-sensitive instruction",
            description: "Source-of-truth teacher instruction template: EAL/D-sensitive instruction.",
            text: #"""
Assess the content and reasoning shown in the reviewed student text. Do not infer the student's language background. Do not penalize language features unless the rubric assesses language control or the wording prevents reliable understanding.
"""#,
            scope: .accessibility,
            priority: .standard,
            studentFacing: false,
            privateTeacherOnly: true
        ),
        TeacherInstructionTemplate(
            id: "adjustment-context",
            name: "Adjustment-context instruction",
            description: "Source-of-truth teacher instruction template: Adjustment-context instruction.",
            text: #"""
Use only the teacher-provided adjustment context. Do not infer disability, support needs, giftedness, EAL/D status, effort, or intent. Keep adjustment notes private unless I explicitly include them in student-facing feedback.
"""#,
            scope: .adjustment,
            priority: .standard,
            studentFacing: false,
            privateTeacherOnly: true
        ),
        TeacherInstructionTemplate(
            id: "off-prompt",
            name: "Off-prompt instruction",
            description: "Source-of-truth teacher instruction template: Off-prompt instruction.",
            text: #"""
If the response does not address the prompt, identify the mismatch and score only the evidence that can be connected to the rubric. Do not invent relevance.
"""#,
            scope: .grading,
            priority: .required,
            studentFacing: false,
            privateTeacherOnly: true
        ),
        TeacherInstructionTemplate(
            id: "misconception",
            name: "Misconception instruction",
            description: "Source-of-truth teacher instruction template: Misconception instruction.",
            text: #"""
If the response shows a misconception listed in the answer key or visible in the reviewed text, identify it specifically and suggest a next step. Do not diagnose broader ability or future performance.
"""#,
            scope: .misconception,
            priority: .standard,
            studentFacing: false,
            privateTeacherOnly: true
        )
    ]

    static func template(id: String) -> TeacherInstructionTemplate? {
        all.first { $0.id == id }
    }
}
