import Foundation

// MARK: - Answer-key templates

/// Source: docs/GRADING_CONTENT_SOURCE_OF_TRUTH.md, Section 8.
/// These are insertion templates for teacher-authored expected answers and partial-credit notes.
enum AnswerKeyTemplateCatalog {
    static let all: [AnswerKeyTemplate] = [
        AnswerKeyTemplate(
            id: "short-answer-answer-key",
            name: "Short-answer answer key template",
            assignmentTypes: [.shortAnswer, .paragraphResponse, .readingComprehension],
            description: "Planned template content from Section 8: Short-answer answer key template.",
            markdownTemplate: #"""
# Answer Key

## Prompt
[Paste the question or task.]

## Full-credit answer
[State the expected answer in teacher wording.]

## Required elements
1. [Required element 1]
2. [Required element 2]
3. [Required element 3]

## Acceptable equivalent wording
- [Alternative wording or synonym]
- [Alternative phrasing]

## Partial credit guidance
- Full credit: [conditions]
- Partial credit: [conditions]
- No credit: [conditions]

## Common misconceptions
- [Misconception 1]
- [Misconception 2]

## Do not penalize
- [Spelling unless meaning is unclear]
- [Equivalent wording]
"""#
        ),
        AnswerKeyTemplate(
            id: "science-explanation-answer-key",
            name: "Science explanation answer key template",
            assignmentTypes: [.shortAnswer, .labWriteup],
            description: "Planned template content from Section 8: Science explanation answer key template.",
            markdownTemplate: #"""
# Science Explanation Key

## Focus question
[Paste focus question.]

## Key concept(s)
- [Concept 1]
- [Concept 2]

## Expected evidence or data
- [Data/observation 1]
- [Data/observation 2]

## Expected reasoning
[Describe how the evidence should connect to the concept.]

## Scientific vocabulary
- [Term 1]
- [Term 2]

## Common misconceptions
- [Misconception]

## Unsupported evidence warning
If the response depends on a diagram, table, equation, or data not included in reviewed text, mark teacher review required.
"""#
        ),
        AnswerKeyTemplate(
            id: "hass-source-response-answer-key",
            name: "HASS source response answer key template",
            assignmentTypes: [.paragraphResponse, .essay],
            description: "Planned template content from Section 8: HASS source response answer key template.",
            markdownTemplate: #"""
# HASS Source Response Key

## Question
[Paste question.]

## Source/context provided to students
[Summarize or paste the relevant source context if appropriate.]

## Expected source understanding
- [Expected understanding]

## Expected evidence
- [Evidence students may cite]

## Expected reasoning
- [Cause/effect, perspective, pattern, significance, continuity/change, civic reasoning, geographic reasoning, etc.]

## Common weak responses
- [Weak response pattern]

## Teacher review trigger
Mark teacher review required if the student refers to source content that is not available in the reviewed text or teacher-provided context.
"""#
        )
    ]

    static func templates(for assignmentType: AssignmentType) -> [AnswerKeyTemplate] {
        all.filter { $0.assignmentTypes.contains(assignmentType) }
    }

    static func template(id: String) -> AnswerKeyTemplate? {
        all.first { $0.id == id }
    }
}
