import Foundation

// MARK: - Planned content validation

enum GradeDraftContentValidationError: Error, Equatable, CustomStringConvertible {
    case missingRequiredTemplate(String)
    case duplicateIdentifier(String)
    case prohibitedLabelPresent(String)

    var description: String {
        switch self {
        case .missingRequiredTemplate(let id): return "Missing required content template: \(id)"
        case .duplicateIdentifier(let id): return "Duplicate content identifier: \(id)"
        case .prohibitedLabelPresent(let label): return "Prohibited user-facing label is present: \(label)"
        }
    }
}

enum GradeDraftContentValidator {
    static let requiredRubricTemplateIDs = [
        "short-answer-4pt", "paragraph-response-8pt", "essay-20pt", "lab-writeup-16pt",
        "reading-comprehension-10pt", "science-explanation-12pt", "hass-source-response-12pt",
        "formative-exit-ticket-8pt", "reflection-response-12pt"
    ]

    static let requiredInstructionTemplateIDs = [
        "general-evidence-first", "do-not-penalize-conventions", "strict-answer-key", "exemplar-comparison",
        "formative-feedback", "summative-caution", "ocr-uncertainty", "eald-sensitive",
        "adjustment-context", "off-prompt", "misconception"
    ]

    static let requiredAnswerKeyTemplateIDs = [
        "short-answer-answer-key", "science-explanation-answer-key", "hass-source-response-answer-key"
    ]

    static let requiredExemplarTemplateIDs = ["paragraph-essay-exemplar"]
    static let requiredFormativeFocusTemplateIDs = ["formative-focus"]

    static let requiredExportWarningIDs = [
        "global-export-warning", "student-report-warning", "teacher-only-record-warning", "pdf-warning",
        "csv-warning", "json-backup-warning", "zip-archive-warning", "clipboard-warning",
        "share-sheet-warning", "backup-toggle-warning", "delete-local-data-warning",
        "teacher-notes-inclusion-warning", "draft-grade-export-warning"
    ]

    static func validateAllCatalogs() throws {
        try assertNoDuplicates(GradeDraftContentCatalog.allTemplateIDs)
        try assertPresent(requiredRubricTemplateIDs, in: Set(RubricTemplateCatalog.builtIn.map(\.id)))
        try assertPresent(requiredInstructionTemplateIDs, in: Set(TeacherInstructionTemplateCatalog.all.map(\.id)))
        try assertPresent(requiredAnswerKeyTemplateIDs, in: Set(AnswerKeyTemplateCatalog.all.map(\.id)))
        try assertPresent(requiredExemplarTemplateIDs, in: Set(ExemplarTemplateCatalog.all.map(\.id)))
        try assertPresent(requiredFormativeFocusTemplateIDs, in: Set(FormativeFocusTemplateCatalog.all.map(\.id)))
        try assertPresent(requiredExportWarningIDs, in: Set(ExportWarningCatalog.all.map(\.id)))
    }

    static func assertNoProhibitedLabels(in visibleCopy: [String]) throws {
        let loweredCopy = visibleCopy.joined(separator: "\n").lowercased()
        for label in GradeDraftCopyCatalog.Labels.prohibited where loweredCopy.contains(label.lowercased()) {
            throw GradeDraftContentValidationError.prohibitedLabelPresent(label)
        }
    }

    private static func assertPresent(_ expected: [String], in actual: Set<String>) throws {
        for id in expected where !actual.contains(id) {
            throw GradeDraftContentValidationError.missingRequiredTemplate(id)
        }
    }

    private static func assertNoDuplicates(_ ids: [String]) throws {
        var seen = Set<String>()
        for id in ids {
            if seen.contains(id) { throw GradeDraftContentValidationError.duplicateIdentifier(id) }
            seen.insert(id)
        }
    }
}
