import Foundation

// MARK: - Template application helpers

enum TemplateInsertionMode: String, Codable, Equatable {
    case replace
    case append
    case appendAgain
}

enum GradeDraftTemplateApplication {
    static func applyingRubricTemplate(_ template: RubricTemplate, to setup: AssignmentSetup) -> AssignmentSetup {
        var copy = setup
        copy.assignment.assignmentType = template.assignmentType
        copy.assignment.assessmentPurpose = template.assessmentPurpose
        copy.assignment.rubricText = template.rubricText
        copy.assignment.rubricImportMode = .automatic
        copy.assignment.confirmedRubric = nil
        copy.assignment.customInstructions = template.customInstructions
        copy.recordAppliedTemplate(id: template.id, name: template.name, kind: .rubric, mode: .replace)
        copy.assignment.updatedAt = Date()
        return copy
    }

    static func appendingInstructionTemplate(_ template: TeacherInstructionTemplate, to setup: AssignmentSetup, mode: TemplateInsertionMode = .append) -> AssignmentSetup {
        var copy = setup
        let incoming = markedMarkdown(kind: .teacherInstruction, templateID: template.id, content: "## \(template.name)\n\n\(template.text.trimmingCharacters(in: .whitespacesAndNewlines))")
        guard shouldApply(kind: .teacherInstruction, templateID: template.id, to: copy.assignment.customInstructions, mode: mode) else { return copy }
        copy.assignment.customInstructions = mergedMarkdown(existing: copy.assignment.customInstructions, incoming: incoming, mode: mode)
        copy.recordAppliedTemplate(id: template.id, name: template.name, kind: .teacherInstruction, mode: mode)
        copy.assignment.updatedAt = Date()
        return copy
    }

    static func insertingAnswerKeyTemplate(_ template: AnswerKeyTemplate, to setup: AssignmentSetup, mode: TemplateInsertionMode = .append) -> AssignmentSetup {
        var copy = setup
        let incoming = markedMarkdown(kind: .answerKey, templateID: template.id, content: template.markdownTemplate)
        guard shouldApply(kind: .answerKey, templateID: template.id, to: copy.assignment.answerKeyText, mode: mode) else { return copy }
        copy.assignment.answerKeyText = mergedMarkdown(existing: copy.assignment.answerKeyText, incoming: incoming, mode: mode)
        copy.recordAppliedTemplate(id: template.id, name: template.name, kind: .answerKey, mode: mode)
        copy.assignment.updatedAt = Date()
        return copy
    }

    static func insertingExemplarTemplate(_ template: ExemplarTemplate, to setup: AssignmentSetup, mode: TemplateInsertionMode = .append) -> AssignmentSetup {
        var copy = setup
        let incoming = markedMarkdown(kind: .exemplar, templateID: template.id, content: template.markdownTemplate)
        guard shouldApply(kind: .exemplar, templateID: template.id, to: copy.assignment.exemplarText, mode: mode) else { return copy }
        copy.assignment.exemplarText = mergedMarkdown(existing: copy.assignment.exemplarText, incoming: incoming, mode: mode)
        copy.recordAppliedTemplate(id: template.id, name: template.name, kind: .exemplar, mode: mode)
        copy.assignment.updatedAt = Date()
        return copy
    }

    static func insertingFormativeFocusTemplate(_ template: FormativeFocusTemplate, to setup: AssignmentSetup, mode: TemplateInsertionMode = .append) -> AssignmentSetup {
        var copy = setup
        let incoming = markedMarkdown(kind: .formativeFocus, templateID: template.id, content: template.markdownTemplate)
        guard shouldApply(kind: .formativeFocus, templateID: template.id, to: copy.assignment.formativeFocusText, mode: mode) else { return copy }
        copy.assignment.formativeFocusText = mergedMarkdown(existing: copy.assignment.formativeFocusText, incoming: incoming, mode: mode)
        copy.recordAppliedTemplate(id: template.id, name: template.name, kind: .formativeFocus, mode: mode)
        if copy.assignment.assessmentPurpose != .formative {
            copy.assignment.assessmentPurpose = .formative
        }
        copy.assignment.updatedAt = Date()
        return copy
    }

    static func withoutTemplateMarkers(_ markdown: String) -> String {
        markdown
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<!-- GradeDraftTemplate:") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func shouldApply(kind: GradeDraftTemplateKind, templateID: String, to existing: String, mode: TemplateInsertionMode) -> Bool {
        if mode == .appendAgain { return true }
        if mode == .replace { return true }
        return !existing.contains(marker(kind: kind, templateID: templateID))
    }

    private static func mergedMarkdown(existing: String, incoming: String, mode: TemplateInsertionMode) -> String {
        let trimmedIncoming = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIncoming.isEmpty else { return existing }
        switch mode {
        case .replace:
            return trimmedIncoming
        case .append, .appendAgain:
            let trimmedExisting = existing.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedExisting.isEmpty else { return trimmedIncoming }
            return trimmedExisting + "\n\n" + trimmedIncoming
        }
    }

    private static func markedMarkdown(kind: GradeDraftTemplateKind, templateID: String, content: String) -> String {
        "\(marker(kind: kind, templateID: templateID))\n\(content.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    private static func marker(kind: GradeDraftTemplateKind, templateID: String) -> String {
        "<!-- GradeDraftTemplate:\(kind.rawValue):\(templateID) -->"
    }
}

private extension AssignmentSetup {
    mutating func recordAppliedTemplate(id: String, name: String, kind: GradeDraftTemplateKind, mode: TemplateInsertionMode) {
        if mode != .appendAgain {
            appliedTemplates.removeAll { $0.templateID == id && $0.templateKind == kind }
        }
        appliedTemplates.append(
            AppliedTemplateRecord(
                assignmentID: assignment.id,
                templateID: id,
                templateName: name,
                templateKind: kind,
                insertionMode: mode
            )
        )
    }
}
