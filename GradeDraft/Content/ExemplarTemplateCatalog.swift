import Foundation

// MARK: - Exemplar templates

enum ExemplarTemplateCatalog {
    static let all: [ExemplarTemplate] = [
        ExemplarTemplate(
            id: "paragraph-essay-exemplar",
            name: "Paragraph/essay exemplar template",
            assignmentTypes: [.paragraphResponse, .essay],
            description: "Planned template content from Section 8: Paragraph/essay exemplar template.",
            markdownTemplate: #"""
# Exemplar Response

## Prompt
[Paste prompt.]

## Exemplar quality level
[High / proficient / developing / teacher-created reference]

## Exemplar text
[Paste exemplar.]

## Why this exemplar is useful
- [Feature 1, e.g., clear claim]
- [Feature 2, e.g., uses evidence]
- [Feature 3, e.g., explains reasoning]

## Important caution
Use this exemplar as a reference. Do not require the student's response to copy its wording or structure unless the rubric requires that structure.
"""#
        )
    ]

    static func templates(for assignmentType: AssignmentType) -> [ExemplarTemplate] {
        all.filter { $0.assignmentTypes.contains(assignmentType) }
    }

    static func template(id: String) -> ExemplarTemplate? {
        all.first { $0.id == id }
    }
}
