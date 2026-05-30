import Foundation

// MARK: - AI grading constraint templates

// These are selectable teacher-controlled constraints that guide the local AI draft pass.
// They are distinct from TeacherInstructionTemplate (content catalog templates that append
// text to the instructions field). These are structured checkboxes included in the prompt.

struct GradingConstraintTemplate: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var category: GradingConstraintCategory
    var text: String
    var sensitiveContextRequired: Bool
    var recommendedWhen: GradingConstraintRecommendation
}

enum GradingConstraintCategory: String, Codable, Equatable, Sendable {
    case evidence
    case conventions
    case answerKey
    case exemplar
    case formative
    case summative
    case ocr
    case inclusion
    case adjustment
    case promptAlignment
    case misconception
}

enum GradingConstraintRecommendation: String, Codable, Equatable, Sendable {
    case always
    case whenAnswerKeyPresent
    case whenExemplarPresent
    case whenFormative
    case whenSummative
    case whenOCRPresent
    case manualOnly
}

enum GradingConstraintTemplates {
    static let defaultSelectedIDs = ["general-evidence-first", "do-not-penalize-conventions"]

    static let builtIn: [GradingConstraintTemplate] = [
        GradingConstraintTemplate(
            id: "general-evidence-first",
            title: "General evidence-first",
            category: .evidence,
            text: "Grade only from the reviewed student text and the grading materials I provided. For every criterion, cite evidence from the reviewed text or mark teacher review required if evidence is missing or unclear.",
            sensitiveContextRequired: false,
            recommendedWhen: .always
        ),
        GradingConstraintTemplate(
            id: "do-not-penalize-conventions",
            title: "Do not penalize conventions unless assessed",
            category: .conventions,
            text: "Do not penalize spelling, grammar, punctuation, capitalization, or handwriting unless the rubric explicitly assesses conventions or the errors materially interfere with meaning.",
            sensitiveContextRequired: false,
            recommendedWhen: .always
        ),
        GradingConstraintTemplate(
            id: "strict-answer-key",
            title: "Strict answer-key scoring",
            category: .answerKey,
            text: "Use the answer key as the main scoring reference. Award equivalent wording when the meaning is correct. If the response is partially correct, identify which expected elements are present and which are missing.",
            sensitiveContextRequired: false,
            recommendedWhen: .whenAnswerKeyPresent
        ),
        GradingConstraintTemplate(
            id: "exemplar-comparison",
            title: "Exemplar comparison",
            category: .exemplar,
            text: "Use the exemplar only as a reference for quality and completeness. Do not require the student's response to match the exemplar wording. Score against the rubric criteria, not against stylistic similarity to the exemplar.",
            sensitiveContextRequired: false,
            recommendedWhen: .whenExemplarPresent
        ),
        GradingConstraintTemplate(
            id: "formative-feedback",
            title: "Formative feedback",
            category: .formative,
            text: "This is formative feedback. Emphasize current evidence of understanding, one misconception or gap if present, and one practical next step. Do not frame the output as a final grade unless I approve it as summative.",
            sensitiveContextRequired: false,
            recommendedWhen: .whenFormative
        ),
        GradingConstraintTemplate(
            id: "summative-caution",
            title: "Summative caution",
            category: .summative,
            text: "This may be used for a summative record after teacher review. Keep score suggestions conservative when evidence is incomplete. Mark teacher review required for ambiguous rubric interpretation, missing evidence, or OCR uncertainty.",
            sensitiveContextRequired: false,
            recommendedWhen: .whenSummative
        ),
        GradingConstraintTemplate(
            id: "ocr-uncertainty",
            title: "OCR uncertainty",
            category: .ocr,
            text: "Some text may have come from OCR. If a quote appears garbled, incomplete, or inconsistent, mark teacher review required and do not rely on that text for a confident score.",
            sensitiveContextRequired: false,
            recommendedWhen: .whenOCRPresent
        ),
        GradingConstraintTemplate(
            id: "eald-sensitive",
            title: "EAL/D-sensitive assessment",
            category: .inclusion,
            text: "Assess the content and reasoning shown in the reviewed student text. Do not infer the student's language background. Do not penalize language features unless the rubric assesses language control or the wording prevents reliable understanding.",
            sensitiveContextRequired: true,
            recommendedWhen: .manualOnly
        ),
        GradingConstraintTemplate(
            id: "adjustment-context",
            title: "Adjustment context",
            category: .adjustment,
            text: "Use only the teacher-provided adjustment context. Do not infer disability, support needs, giftedness, EAL/D status, effort, or intent. Keep adjustment notes private unless I explicitly include them in student-facing feedback.",
            sensitiveContextRequired: true,
            recommendedWhen: .manualOnly
        ),
        GradingConstraintTemplate(
            id: "off-prompt",
            title: "Off-prompt response",
            category: .promptAlignment,
            text: "If the response does not address the prompt, identify the mismatch and score only the evidence that can be connected to the rubric. Do not invent relevance.",
            sensitiveContextRequired: false,
            recommendedWhen: .manualOnly
        ),
        GradingConstraintTemplate(
            id: "misconception",
            title: "Misconception-focused feedback",
            category: .misconception,
            text: "If the response shows a misconception listed in the answer key or visible in the reviewed text, identify it specifically and suggest a next step. Do not diagnose broader ability or future performance.",
            sensitiveContextRequired: false,
            recommendedWhen: .manualOnly
        )
    ]

    private static var byID: [String: GradingConstraintTemplate] {
        Dictionary(uniqueKeysWithValues: builtIn.map { ($0.id, $0) })
    }

    static func recommendedIDs(for assignment: AssignmentRecord) -> [String] {
        var ids = defaultSelectedIDs
        let answerKeyPresent = !assignment.answerKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let exemplarPresent = !assignment.exemplarText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let ocrPresent = assignment.ocrDocument != nil || assignment.ocrReviewStatus != .notNeeded

        if answerKeyPresent { ids.append("strict-answer-key") }
        if exemplarPresent { ids.append("exemplar-comparison") }
        if assignment.assessmentPurpose == .formative { ids.append("formative-feedback") }
        if assignment.assessmentPurpose == .summative { ids.append("summative-caution") }
        if ocrPresent { ids.append("ocr-uncertainty") }

        return Array(Set(ids)).sorted { lhs, rhs in
            sortIndex(for: lhs) < sortIndex(for: rhs)
        }
    }

    static func templates(for ids: [String]) -> [GradingConstraintTemplate] {
        ids.compactMap { byID[$0] }
    }

    static func combinedText(for ids: [String]) -> String {
        templates(for: ids).map { "## \($0.title)\n\($0.text)" }.joined(separator: "\n\n")
    }

    static func fingerprint(for ids: [String]) -> String {
        let values = templates(for: ids).map { "\($0.id):\($0.text)" }
        return StableFingerprint.fingerprint(values)
    }

    private static func sortIndex(for id: String) -> Int {
        builtIn.firstIndex { $0.id == id } ?? Int.max
    }
}
