import Foundation

// MARK: - Template application helpers

enum TemplateInsertionMode: String, Codable, Equatable {
    case replace
    case append
    case appendAgain
}

enum GradeDraftTemplateApplication {
    static func applyingRubricTemplate(_ template: RubricTemplate, to assignment: AssignmentRecord, resetDrafts: Bool = false) -> AssignmentRecord {
        var copy = assignment
        copy.assignmentType = template.assignmentType
        copy.assessmentPurpose = template.assessmentPurpose
        copy.rubricText = template.rubricText
        copy.customInstructions = template.customInstructions
        copy.recordAppliedTemplate(id: template.id, name: template.name, kind: .rubric, mode: .replace)
        if resetDrafts {
            copy.latestDraft = nil
            copy.finalReview = nil
        }
        copy.updatedAt = Date()
        copy.appendAuditEvent(.inputChanged, detail: "Applied rubric template: \(template.name)")
        return copy
    }

    static func appendingInstructionTemplate(_ template: TeacherInstructionTemplate, to assignment: AssignmentRecord, mode: TemplateInsertionMode = .append) -> AssignmentRecord {
        var copy = assignment
        let incoming = markedMarkdown(kind: .teacherInstruction, templateID: template.id, content: "## \(template.name)\n\n\(template.text.trimmingCharacters(in: .whitespacesAndNewlines))")
        guard shouldApply(kind: .teacherInstruction, templateID: template.id, to: copy.customInstructions, mode: mode) else { return copy }
        copy.customInstructions = mergedMarkdown(existing: copy.customInstructions, incoming: incoming, mode: mode)
        copy.recordAppliedTemplate(id: template.id, name: template.name, kind: .teacherInstruction, mode: mode)
        copy.updatedAt = Date()
        copy.appendAuditEvent(.inputChanged, detail: "Appended teacher instruction template: \(template.name)")
        return copy
    }

    static func insertingAnswerKeyTemplate(_ template: AnswerKeyTemplate, to assignment: AssignmentRecord, mode: TemplateInsertionMode = .append) -> AssignmentRecord {
        var copy = assignment
        let incoming = markedMarkdown(kind: .answerKey, templateID: template.id, content: template.markdownTemplate)
        guard shouldApply(kind: .answerKey, templateID: template.id, to: copy.answerKeyText, mode: mode) else { return copy }
        copy.answerKeyText = mergedMarkdown(existing: copy.answerKeyText, incoming: incoming, mode: mode)
        copy.recordAppliedTemplate(id: template.id, name: template.name, kind: .answerKey, mode: mode)
        copy.updatedAt = Date()
        copy.appendAuditEvent(.inputChanged, detail: "Inserted answer-key template: \(template.name)")
        return copy
    }

    static func insertingExemplarTemplate(_ template: ExemplarTemplate, to assignment: AssignmentRecord, mode: TemplateInsertionMode = .append) -> AssignmentRecord {
        var copy = assignment
        let incoming = markedMarkdown(kind: .exemplar, templateID: template.id, content: template.markdownTemplate)
        guard shouldApply(kind: .exemplar, templateID: template.id, to: copy.exemplarText, mode: mode) else { return copy }
        copy.exemplarText = mergedMarkdown(existing: copy.exemplarText, incoming: incoming, mode: mode)
        copy.recordAppliedTemplate(id: template.id, name: template.name, kind: .exemplar, mode: mode)
        copy.updatedAt = Date()
        copy.appendAuditEvent(.inputChanged, detail: "Inserted exemplar template: \(template.name)")
        return copy
    }

    static func insertingFormativeFocusTemplate(_ template: FormativeFocusTemplate, to assignment: AssignmentRecord, mode: TemplateInsertionMode = .append) -> AssignmentRecord {
        var copy = assignment
        let incoming = markedMarkdown(kind: .formativeFocus, templateID: template.id, content: template.markdownTemplate)
        guard shouldApply(kind: .formativeFocus, templateID: template.id, to: copy.formativeFocusText, mode: mode) else { return copy }
        copy.formativeFocusText = mergedMarkdown(existing: copy.formativeFocusText, incoming: incoming, mode: mode)
        copy.recordAppliedTemplate(id: template.id, name: template.name, kind: .formativeFocus, mode: mode)
        if copy.assessmentPurpose != .formative {
            copy.assessmentPurpose = .formative
        }
        copy.updatedAt = Date()
        copy.appendAuditEvent(.inputChanged, detail: "Inserted formative focus template: \(template.name)")
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

private extension AssignmentRecord {
    mutating func recordAppliedTemplate(id: String, name: String, kind: GradeDraftTemplateKind, mode: TemplateInsertionMode) {
        if mode != .appendAgain {
            appliedTemplates.removeAll { $0.templateID == id && $0.templateKind == kind }
        }
        appliedTemplates.append(
            AppliedTemplateRecord(
                templateID: id,
                templateName: name,
                templateKind: kind,
                insertionMode: mode
            )
        )
    }
}
