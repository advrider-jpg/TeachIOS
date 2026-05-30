import Foundation

// MARK: - Unified planned content catalog

enum GradeDraftContentCatalog {
    static let version = "1.0.0"
    static let generatedFrom = "docs/GRADING_CONTENT_SOURCE_OF_TRUTH.md"

    static let rubricTemplates = RubricTemplateCatalog.builtIn
    static let teacherInstructionTemplates = TeacherInstructionTemplateCatalog.all
    static let answerKeyTemplates = AnswerKeyTemplateCatalog.all
    static let exemplarTemplates = ExemplarTemplateCatalog.all
    static let formativeFocusTemplates = FormativeFocusTemplateCatalog.all
    static let exportWarnings = ExportWarningCatalog.all

    static var allTemplateIDs: [String] {
        rubricTemplates.map(\.id) +
        teacherInstructionTemplates.map(\.id) +
        answerKeyTemplates.map(\.id) +
        exemplarTemplates.map(\.id) +
        formativeFocusTemplates.map(\.id) +
        exportWarnings.map(\.id)
    }
}
