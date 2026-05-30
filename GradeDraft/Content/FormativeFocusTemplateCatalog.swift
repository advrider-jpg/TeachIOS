import Foundation

// MARK: - Formative focus templates

enum FormativeFocusTemplateCatalog {
    static let all: [FormativeFocusTemplate] = [
        FormativeFocusTemplate(
            id: "formative-focus",
            name: "Formative focus template",
            assignmentTypes: [.shortAnswer, .paragraphResponse, .readingComprehension, .labWriteup],
            description: "Planned template content from Section 8: Formative focus template.",
            markdownTemplate: #"""
# Formative Focus

## Learning focus
[What understanding or skill is being checked?]

## Aim
[Why is this evidence being collected now?]

## Timing
[Before teaching / during teaching / after practice / exit ticket / revision check]

## Expected evidence
[What should the student response show?]

## Possible next teaching decisions
- [Reteach]
- [Small group]
- [Move on]
- [Give extension]
- [Clarify misconception]

## Student feedback style
Short, specific, and next-step focused.
"""#
        )
    ]

    static func templates(for assignmentType: AssignmentType) -> [FormativeFocusTemplate] {
        all.filter { $0.assignmentTypes.contains(assignmentType) }
    }

    static func template(id: String) -> FormativeFocusTemplate? {
        all.first { $0.id == id }
    }
}
