import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum PromptPacketMode: String, Codable, Equatable, Sendable {
    case full
    case compact
}

enum PromptTemplateRenderer {
    static func render(_ template: String, replacements: [String: String]) -> String {
        var output = ""
        var index = template.startIndex
        while let range = template[index...].range(of: #"\{\{[A-Za-z0-9_]+\}\}"#, options: .regularExpression) {
            output += template[index..<range.lowerBound]
            let token = String(template[range])
            output += replacements[token] ?? token
            index = range.upperBound
        }
        output += template[index...]
        return output
    }
}

enum PromptBuilder {
    static let missingEvidenceMarker = "No supporting evidence found."

    // MARK: - Packet-based prompt (existing production path, used by planned-content packet)

    static func gradingPrompt(input: GradingInput) -> String {
        let packet = input.plannedContentGradingPacket ?? GradingPacketBuilder.packet(from: input)
        return gradingPrompt(packet: packet, fallbackInput: input)
    }

    static func gradingPrompt(packet: GradingPacket, fallbackInput: GradingInput? = nil) -> String {
        let assignment = packet.assignment
        let evidence = packet.studentEvidence
        let reviewedText = preferredReviewedText(
            reviewedWithRefs: evidence.reviewedTextWithSourceRefs,
            reviewedText: evidence.reviewedText
        )
        let ocrQualityText: String
        if let fallbackInput {
            ocrQualityText = fallbackInput.ocrQualitySummary.requiresTeacherOCRReview
                ? "Scanned text quality warning: \(fallbackInput.ocrQualitySummary.displaySummary) Treat unclear or garbled text as an uncertainty flag."
                : fallbackInput.ocrQualitySummary.displaySummary
        } else {
            ocrQualityText = evidence.ocrQualitySummary
        }

        let teacherInstructions = packet.teacherInstructions
            .map(\.text)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")

        let replacements: [String: String] = [
            "{{assignmentTitle}}": assignment.title,
            "{{promptOrNone}}": notSupplied(assignment.prompt),
            "{{studentDisplayNameOrNotSpecified}}": notSpecified(assignment.studentDisplayName),
            "{{classNameOrNotSpecified}}": notSpecified(assignment.className),
            "{{subjectOrNotSpecified}}": notSpecified(assignment.subject),
            "{{gradeLevelOrNotSpecified}}": notSpecified(assignment.gradeLevel),
            "{{assignmentTypeDisplayName}}": assignment.assignmentType.displayName,
            "{{assessmentPurpose}}": assignment.assessmentPurpose.rawValue,
            "{{sourceInputCount}}": "\(evidence.sourceInputCount)",
            "{{ocrReviewStatus}}": evidence.ocrReviewStatus.displayName,
            "{{ocrQualitySummary}}": ocrQualityText,
            "{{packetVersion}}": packet.packetVersion,
            "{{curriculumReferenceSection}}": optionalTripleQuotedSection(title: "Curriculum reference", body: packet.curriculumReference?.rawText ?? ""),
            "{{structuredRubricCriteria}}": structuredCriteriaText(from: packet.rubric.criteria),
            "{{rubricText}}": notSupplied(packet.rubric.rawText),
            "{{customInstructionsSection}}": optionalTripleQuotedSection(title: "Custom teacher instructions", body: teacherInstructions),
            "{{formativeFocusSection}}": optionalTripleQuotedSection(title: "Formative focus", body: packet.formativeFocus?.rawText ?? ""),
            "{{answerKeySection}}": optionalTripleQuotedSection(title: "Answer key", body: packet.answerKey?.rawText ?? ""),
            "{{exemplarSection}}": optionalTripleQuotedSection(title: "Exemplar response", body: packet.exemplar?.rawText ?? ""),
            "{{reviewedStudentText}}": reviewedText
        ]

        return PromptTemplateRenderer.render(
            GradeDraftCopyCatalog.SourceOfTruth.canonicalPromptTemplate,
            replacements: replacements
        )
    }

    // MARK: - Foundation Models typed generation (instructions + prompt text)

    static func gradingInstructionsText(input: GradingInput) -> String {
        """
        You are GradeDraft's local-only rubric feedback assistant for a teacher.
        You are not the final grader.
        The teacher supplies the assignment prompt, rubric or criteria, reviewed student text, answer key, exemplar, curriculum reference, and optional grading instructions.
        Your job is to propose evidence-linked draft suggestions only.
        The teacher must review, edit, and approve every final grade.

        Mandatory rules:
        1. Grade only from the reviewed student text and the grading materials supplied in this prompt.
        2. Do not infer effort, intent, motivation, behavior, personality, ability, disability, EAL/D status, demographic traits, giftedness, home support, family support, laziness, carelessness, or future performance.
        3. Do not invent evidence. For every criterion, cite exact evidence from the reviewed student text or use this exact marker: \(missingEvidenceMarker).
        4. When source reference tags such as [p1-l2-abcdef12] are present, include matching evidence source refs for cited quotes.
        5. Do not invent curriculum references, official standards, answer-key elements, source facts, exemplar content, or teacher instructions.
        6. If the rubric is ambiguous, use the most conservative reasonable score and add an uncertainty flag.
        7. If OCR quality is uncertain, mark affected criteria as teacherReviewRequired.
        8. If the response is weak, unclear, off-prompt, or relies on unsupported source material, diagram interpretation, symbolic math, visual artifacts, handwriting uncertainty, or notation the app cannot reliably assess from reviewed text, mark teacherReviewRequired and explain the limitation.
        9. Keep student-facing feedback constructive, specific, concise, and based on evidence.
        10. Keep teacher notes private and use them for ambiguity, OCR concerns, evidence concerns, conservative scoring calls, and grading limitations.
        11. Do not present the draft as a final grade. Every criterion must remain teacher-reviewable.
        12. No cloud model fallback exists in this app.
        """
    }

    static func fullPacketPromptText(input: GradingInput, mode: PromptPacketMode) -> String {
        let rubricText = input.rubricText.trimmingCharacters(in: .whitespacesAndNewlines)
        let includeRawRubric = mode == .full || input.parsedRubric.criteria.isEmpty
        let rawRubric = includeRawRubric ? rubricText.nonEmptyOr("Not supplied.") : "Structured criteria above are the active rubric source for compact mode."

        return """
        Draft evidence-linked rubric suggestions for this assignment.
        Return one generated GradeDraftProposal object using the app schema.
        Return exactly one criterion draft for each structured criterion listed below.
        Do not include totalScore or maxScore. The app calculates totals.

        Assignment metadata:
        \(metadataText(input: input))

        AI grading constraint templates selected by teacher:
        \(constraintTemplateSection(input: input))

        Custom teacher instructions:
        -- BEGIN CUSTOM INSTRUCTIONS --
        \(input.customInstructions.nonEmptyOr("None."))
        -- END CUSTOM INSTRUCTIONS --

        Formative focus:
        -- BEGIN FORMATIVE FOCUS --
        \(input.formativeFocusText.nonEmptyOr("None."))
        -- END FORMATIVE FOCUS --

        Curriculum/reference material:
        -- BEGIN CURRICULUM REFERENCE --
        \(input.curriculumReference.nonEmptyOr("None."))
        -- END CURRICULUM REFERENCE --

        Structured rubric criteria:
        \(structuredCriteriaTypedText(input: input))

        Raw rubric / grading criteria:
        -- BEGIN RUBRIC --
        \(rawRubric)
        -- END RUBRIC --

        Answer key:
        -- BEGIN ANSWER KEY --
        \(input.answerKeyText.nonEmptyOr("None."))
        -- END ANSWER KEY --

        Exemplar response:
        -- BEGIN EXEMPLAR --
        \(input.exemplarText.nonEmptyOr("None."))
        -- END EXEMPLAR --

        Reviewed student text with source references:
        -- BEGIN REVIEWED STUDENT TEXT --
        \(reviewedText(input: input))
        -- END REVIEWED STUDENT TEXT --
        """
    }

    static func singleCriterionPromptText(input: GradingInput, criterion: RubricCriterion, mode: PromptPacketMode = .compact) -> String {
        """
        Draft an evidence-linked suggestion for one rubric criterion only.
        Return one generated SingleCriterionDraft object using the app schema.
        Do not score any other criterion.
        Do not include totalScore or maxScore.

        Assignment metadata:
        \(metadataText(input: input))

        AI grading constraint templates selected by teacher:
        \(constraintTemplateSection(input: input))

        Custom teacher instructions:
        -- BEGIN CUSTOM INSTRUCTIONS --
        \(input.customInstructions.nonEmptyOr("None."))
        -- END CUSTOM INSTRUCTIONS --

        Formative focus:
        -- BEGIN FORMATIVE FOCUS --
        \(input.formativeFocusText.nonEmptyOr("None."))
        -- END FORMATIVE FOCUS --

        Curriculum/reference material:
        -- BEGIN CURRICULUM REFERENCE --
        \(input.curriculumReference.nonEmptyOr("None."))
        -- END CURRICULUM REFERENCE --

        Criterion to score:
        - ID: \(criterion.id)
        - Title: \(criterion.title)
        - Max points: \(GradeTotals.formatted(criterion.maxPoints))
        - Descriptor: \(criterion.descriptor)
        - Levels: \(levelsText(criterion))

        Answer key:
        -- BEGIN ANSWER KEY --
        \(input.answerKeyText.nonEmptyOr("None."))
        -- END ANSWER KEY --

        Exemplar response:
        -- BEGIN EXEMPLAR --
        \(input.exemplarText.nonEmptyOr("None."))
        -- END EXEMPLAR --

        Reviewed student text with source references:
        -- BEGIN REVIEWED STUDENT TEXT --
        \(reviewedText(input: input))
        -- END REVIEWED STUDENT TEXT --
        """
    }

    static func summaryFeedbackPromptText(input: GradingInput, criteria: [CriterionScore]) -> String {
        let criteriaText = criteria.map { criterion in
            "- \(criterion.criterion): \(GradeTotals.formatted(criterion.proposedPoints))/\(GradeTotals.formatted(criterion.maxPoints)); evidence: \(criterion.evidence.joined(separator: " | ")); review required: \(criterion.teacherReviewRequired)"
        }.joined(separator: "\n")

        return """
        Create a concise summary and feedback synthesis from these already-generated criterion suggestions.
        Return one generated DraftSummaryFeedback object using the app schema.
        Do not change criterion scores. Do not add criteria. Do not present this as a final grade.

        Assignment metadata:
        \(metadataText(input: input))

        Criteria suggestions to synthesize:
        \(criteriaText)

        Reviewed student text with source references:
        -- BEGIN REVIEWED STUDENT TEXT --
        \(reviewedText(input: input))
        -- END REVIEWED STUDENT TEXT --
        """
    }

    // MARK: - Helpers

    private static func metadataText(input: GradingInput) -> String {
        let ocrWarning = input.ocrQualitySummary.requiresTeacherOCRReview
            ? "OCR warning: \(input.ocrQualitySummary.displaySummary). Treat unclear or garbled text as an uncertainty flag."
            : "OCR warning: None."
        return """
        - Assignment ID: \(input.assignmentID.uuidString)
        - Title: \(input.assignmentTitle)
        - Prompt: \(input.prompt.nonEmptyOr("Not supplied."))
        - Student: \(input.studentDisplayName.nonEmptyOr("Not specified."))
        - Class: \(input.className.nonEmptyOr("Not specified."))
        - Subject: \(input.subject.nonEmptyOr("Not specified."))
        - Grade level: \(input.gradeLevel.nonEmptyOr("Not specified."))
        - Assignment type: \(input.assignmentType.displayName)
        - Assessment purpose: \(input.assessmentPurpose.rawValue)
        - Source input count: \(input.sourceInputCount)
        - OCR review status: \(input.ocrReviewStatus.displayName)
        - OCR quality summary: \(input.ocrQualitySummary.displaySummary)
        - \(ocrWarning)
        """
    }

    private static func constraintTemplateSection(input: GradingInput) -> String {
        let selected = GradingConstraintTemplates.templates(for: input.selectedInstructionTemplateIDs)
        guard !selected.isEmpty else { return "None." }
        return selected.map { template in
            "- \(template.title): \(template.text)"
        }.joined(separator: "\n")
    }

    private static func structuredCriteriaTypedText(input: GradingInput) -> String {
        guard !input.parsedRubric.criteria.isEmpty else {
            return "No structured point-bearing criteria were detected. Use the raw rubric text and mark teacherReviewRequired true for every criterion."
        }
        return input.parsedRubric.criteria.map { criterion in
            "- id: \(criterion.id); title: \(criterion.title); maxPoints: \(GradeTotals.formatted(criterion.maxPoints)); descriptor: \(criterion.descriptor); levels: \(levelsText(criterion))"
        }.joined(separator: "\n")
    }

    private static func levelsText(_ criterion: RubricCriterion) -> String {
        guard !criterion.levels.isEmpty else { return "None supplied." }
        return criterion.levels.map { level in
            "\(level.label) [\(GradeTotals.formatted(level.minPoints ?? 0))-\(GradeTotals.formatted(level.maxPoints ?? level.points))]: \(level.descriptor)"
        }.joined(separator: " | ")
    }

    private static func reviewedText(input: GradingInput) -> String {
        input.reviewedTextWithSourceRefs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? input.reviewedStudentText
            : input.reviewedTextWithSourceRefs
    }

    private static func structuredCriteriaText(from criteria: [GradingPacketRubricCriterion]) -> String {
        guard !criteria.isEmpty else {
            return "No structured point-bearing criteria were detected. Use the raw rubric text and mark teacherReviewRequired true for every criterion."
        }
        return criteria.map { criterion in
            let group = criterion.groupTitle.map { "; group: \($0)" } ?? ""
            return "- criterionId: \(criterion.id); title: \(criterion.title); maxPoints: \(GradeTotals.formatted(criterion.maxPoints)); descriptor: \(criterion.descriptor)\(group)"
        }.joined(separator: "\n")
    }

    private static func preferredReviewedText(reviewedWithRefs: String, reviewedText: String) -> String {
        let withRefs = reviewedWithRefs.trimmingCharacters(in: .whitespacesAndNewlines)
        if !withRefs.isEmpty { return reviewedWithRefs }
        return reviewedText
    }

    private static func optionalTripleQuotedSection(title: String, body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return """
        \(title):
        \"\"\"
        \(trimmed)
        \"\"\"

        """
    }

    private static func notSupplied(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not supplied." : text
    }

    private static func notSpecified(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not specified" : text
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
extension PromptBuilder {
    static func gradingInstructions(input: GradingInput) -> Instructions {
        Instructions(gradingInstructionsText(input: input))
    }

    static func fullPacketPrompt(input: GradingInput, mode: PromptPacketMode) -> Prompt {
        Prompt { fullPacketPromptText(input: input, mode: mode) }
    }

    static func singleCriterionPrompt(input: GradingInput, criterion: RubricCriterion, mode: PromptPacketMode) -> Prompt {
        Prompt { singleCriterionPromptText(input: input, criterion: criterion, mode: mode) }
    }

    static func summaryFeedbackPrompt(input: GradingInput, criteria: [CriterionScore]) -> Prompt {
        Prompt { summaryFeedbackPromptText(input: input, criteria: criteria) }
    }
}
#endif

private extension String {
    func nonEmptyOr(_ fallback: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : self
    }
}
