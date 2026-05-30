import Foundation

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
