import Foundation

struct LocalGradingToolPolicy: Codable, Equatable, Sendable {
    var allowRubricLookup: Bool
    var allowEvidenceLookup: Bool
    var allowOCRLineLookup: Bool
    var allowSourceReferenceLookup: Bool
    var allowAnswerKeyLookup: Bool
    var allowExemplarLookup: Bool
    var allowCurriculumLookup: Bool
    var allowConstraintLookup: Bool
    var allowPacketLimitLookup: Bool
    var allowWrites: Bool
    var allowNetwork: Bool
    var maxToolCallsPerRequest: Int
    var maxToolOutputCharacters: Int

    static let productionDefault = LocalGradingToolPolicy(
        allowRubricLookup: true,
        allowEvidenceLookup: true,
        allowOCRLineLookup: true,
        allowSourceReferenceLookup: true,
        allowAnswerKeyLookup: true,
        allowExemplarLookup: true,
        allowCurriculumLookup: true,
        allowConstraintLookup: true,
        allowPacketLimitLookup: true,
        allowWrites: false,
        allowNetwork: false,
        maxToolCallsPerRequest: 8,
        maxToolOutputCharacters: 1_500
    )

    var summary: String {
        "Read-only local lookup tools. Writes: \(allowWrites ? "allowed" : "forbidden"). Network: \(allowNetwork ? "allowed" : "forbidden"). Max calls: \(maxToolCallsPerRequest). Max output: \(maxToolOutputCharacters) characters."
    }

    func allows(_ tool: LocalAIGradingToolName) -> Bool {
        switch tool {
        case .findRubricCriterion, .listAvailableCriteria:
            return allowRubricLookup
        case .findStudentEvidence:
            return allowEvidenceLookup
        case .findOCRLine:
            return allowOCRLineLookup
        case .findSourceReference:
            return allowSourceReferenceLookup
        case .findAnswerKeySegment:
            return allowAnswerKeyLookup
        case .findExemplarSegment:
            return allowExemplarLookup
        case .findCurriculumReference:
            return allowCurriculumLookup
        case .listSelectedAIConstraints:
            return allowConstraintLookup
        case .getPacketLimits:
            return allowPacketLimitLookup
        }
    }
}

struct LocalToolSnippet: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var sourceRef: String
    var title: String
    var text: String
    var characterRangeDescription: String?
    var confidence: Double?
}

struct LocalToolOutput: Codable, Equatable, Sendable {
    var toolName: LocalAIGradingToolName
    var query: String
    var snippets: [LocalToolSnippet]
    var truncated: Bool
    var warning: String?

    var legacyMatches: [String] {
        snippets.map { snippet in
            let source = snippet.sourceRef.trimmingCharacters(in: .whitespacesAndNewlines)
            return source.isEmpty ? snippet.text : "\(source): \(snippet.text)"
        }
    }
}

struct LocalToolCallAudit: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var toolName: LocalAIGradingToolName
    var assignmentID: UUID
    var promptVersion: String
    var criterionID: String?
    var argumentsHash: String
    var outputSnippetIDs: [String]
    var outputCharacterCount: Int
    var truncated: Bool
    var elapsedMilliseconds: Int
    var errorCategory: String?
}

struct LocalToolInvocationReport: Codable, Equatable, Sendable {
    var output: LocalToolOutput
    var audit: LocalToolCallAudit
}

struct StudentEvidenceIndex: Sendable {
    private let snippets: [LocalToolSnippet]

    init(input: GradingInput) {
        let text = input.reviewedTextWithSourceRefs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? input.reviewedStudentText
            : input.reviewedTextWithSourceRefs
        self.snippets = Self.makeLineSnippets(
            text: text,
            sourcePrefix: "reviewed-student-text",
            title: "Reviewed student evidence"
        )
    }

    func search(query: String, maxCharacters: Int, maxMatches: Int = 5) -> (snippets: [LocalToolSnippet], truncated: Bool) {
        Self.search(snippets: snippets, query: query, maxCharacters: maxCharacters, maxMatches: maxMatches)
    }

    static func makeLineSnippets(text: String, sourcePrefix: String, title: String) -> [LocalToolSnippet] {
        var offset = 0
        return text
            .components(separatedBy: .newlines)
            .enumerated()
            .compactMap { lineIndex, rawLine in
                defer { offset += rawLine.count + 1 }
                let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                let sourceRef = sourceReference(in: trimmed) ?? "\(sourcePrefix)-line-\(lineIndex + 1)"
                return LocalToolSnippet(
                    id: stableID(sourceRef),
                    sourceRef: sourceRef,
                    title: title,
                    text: trimmed,
                    characterRangeDescription: "\(offset)..<\(offset + rawLine.count)",
                    confidence: nil
                )
            }
    }

    static func search(
        snippets: [LocalToolSnippet],
        query: String,
        maxCharacters: Int,
        maxMatches: Int = 5
    ) -> (snippets: [LocalToolSnippet], truncated: Bool) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, maxCharacters > 0 else { return ([], false) }

        var usedCharacters = 0
        var truncated = false
        var matches: [LocalToolSnippet] = []
        for snippet in snippets where snippet.text.localizedCaseInsensitiveContains(trimmedQuery) || snippet.title.localizedCaseInsensitiveContains(trimmedQuery) || snippet.sourceRef.localizedCaseInsensitiveContains(trimmedQuery) {
            if matches.count >= maxMatches {
                truncated = true
                break
            }
            let remaining = maxCharacters - usedCharacters
            guard remaining > 0 else {
                truncated = true
                break
            }
            var capped = snippet
            if capped.text.count > remaining {
                if remaining > 3 {
                    capped.text = String(capped.text.prefix(remaining - 3)) + "..."
                } else {
                    capped.text = String(capped.text.prefix(remaining))
                }
                truncated = true
            }
            usedCharacters += capped.text.count
            matches.append(capped)
        }
        return (matches, truncated)
    }

    private static func sourceReference(in text: String) -> String? {
        let pattern = #"\[p\d+-l\d+-[A-Fa-f0-9-]+\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text) else { return nil }
        return String(text[range])
    }

    private static func stableID(_ value: String) -> String {
        let hash = value.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { partial, scalar in
            (partial ^ UInt64(scalar.value)).multipliedReportingOverflow(by: 1_099_511_628_211).partialValue
        }
        return String(hash, radix: 16)
    }
}

final class LocalGradingToolSession {
    private let assignmentID: UUID
    private let promptVersion: String
    private let input: GradingInput
    private let packet: GradingPacket?
    private let budgetPlan: PromptBudgetPlan?
    private let policy: LocalGradingToolPolicy
    private var callCount = 0

    init(
        input: GradingInput,
        packet: GradingPacket? = nil,
        budgetPlan: PromptBudgetPlan? = nil,
        promptVersion: String = GradeDraftPromptVersion.currentFoundationModelsTyped,
        policy: LocalGradingToolPolicy = .productionDefault
    ) {
        self.assignmentID = input.assignmentID
        self.promptVersion = promptVersion
        self.input = input
        self.packet = packet
        self.budgetPlan = budgetPlan
        self.policy = policy
    }

    func call(_ tool: LocalAIGradingToolName, query: String = "", criterionID: String? = nil) -> LocalToolInvocationReport {
        let start = Date()
        callCount += 1
        let output: LocalToolOutput
        if callCount > policy.maxToolCallsPerRequest {
            output = LocalToolOutput(
                toolName: tool,
                query: query,
                snippets: [],
                truncated: false,
                warning: "Tool call limit reached for this local grading request."
            )
        } else if !policy.allows(tool) || policy.allowWrites || policy.allowNetwork {
            output = LocalToolOutput(
                toolName: tool,
                query: query,
                snippets: [],
                truncated: false,
                warning: "This local tool is disabled by the read-only/no-network grading policy."
            )
        } else {
            output = makeOutput(tool, query: query)
        }
        let elapsed = max(0, Int(Date().timeIntervalSince(start) * 1000))
        return LocalToolInvocationReport(
            output: output,
            audit: LocalToolCallAudit(
                id: UUID(),
                toolName: tool,
                assignmentID: assignmentID,
                promptVersion: promptVersion,
                criterionID: criterionID,
                argumentsHash: Self.stableHash("\(tool.rawValue)|\(query)|\(criterionID ?? "")"),
                outputSnippetIDs: output.snippets.map(\.id),
                outputCharacterCount: output.snippets.reduce(0) { $0 + $1.text.count },
                truncated: output.truncated,
                elapsedMilliseconds: elapsed,
                errorCategory: output.warning == nil ? nil : "policy-or-empty-result"
            )
        )
    }

    private func makeOutput(_ tool: LocalAIGradingToolName, query: String) -> LocalToolOutput {
        switch tool {
        case .findStudentEvidence:
            let result = StudentEvidenceIndex(input: input).search(query: query, maxCharacters: policy.maxToolOutputCharacters)
            return output(tool, query: query, snippets: result.snippets, truncated: result.truncated)
        case .findOCRLine:
            let text = packet?.studentEvidence.reviewedTextWithSourceRefs ?? input.reviewedTextWithSourceRefs
            let snippets = StudentEvidenceIndex.makeLineSnippets(text: text, sourcePrefix: "ocr", title: "Reviewed OCR/source line")
            let result = StudentEvidenceIndex.search(snippets: snippets, query: query, maxCharacters: policy.maxToolOutputCharacters)
            return output(tool, query: query, snippets: result.snippets, truncated: result.truncated)
        case .findSourceReference:
            let snippets = (packet?.evidenceReferences ?? []).map { evidence in
                LocalToolSnippet(
                    id: evidence.id.uuidString,
                    sourceRef: evidence.sourceInputID?.uuidString ?? "unknown-source",
                    title: "Evidence reference",
                    text: evidence.quote,
                    characterRangeDescription: evidence.pageIndex.map { "page \($0 + 1)" },
                    confidence: nil
                )
            }
            let result = StudentEvidenceIndex.search(snippets: snippets, query: query, maxCharacters: policy.maxToolOutputCharacters)
            return output(tool, query: query, snippets: result.snippets, truncated: result.truncated)
        case .findRubricCriterion:
            let snippets = input.parsedRubric.criteria.map { criterion in
                LocalToolSnippet(
                    id: criterion.id,
                    sourceRef: "rubric:\(criterion.id)",
                    title: criterion.title,
                    text: "\(criterion.title), max \(GradeTotals.formatted(criterion.maxPoints)). \(criterion.descriptor)",
                    characterRangeDescription: nil,
                    confidence: nil
                )
            }
            let result = StudentEvidenceIndex.search(snippets: snippets, query: query, maxCharacters: policy.maxToolOutputCharacters)
            return output(tool, query: query, snippets: result.snippets, truncated: result.truncated)
        case .findAnswerKeySegment:
            return lineOutput(tool, query: query, text: input.answerKeyText, sourcePrefix: "answer-key", title: "Answer key")
        case .findExemplarSegment:
            return lineOutput(tool, query: query, text: input.exemplarText, sourcePrefix: "exemplar", title: "Exemplar")
        case .findCurriculumReference:
            return lineOutput(tool, query: query, text: input.curriculumReference, sourcePrefix: "curriculum", title: "Curriculum reference")
        case .listAvailableCriteria:
            let snippets = input.parsedRubric.criteria.map { criterion in
                LocalToolSnippet(
                    id: criterion.id,
                    sourceRef: "rubric:\(criterion.id)",
                    title: criterion.title,
                    text: "\(criterion.title), max \(GradeTotals.formatted(criterion.maxPoints)). \(criterion.descriptor)",
                    characterRangeDescription: nil,
                    confidence: nil
                )
            }
            return output(tool, query: query, snippets: snippets, truncated: false)
        case .listSelectedAIConstraints:
            let snippets = GradingConstraintTemplates.templates(for: input.selectedInstructionTemplateIDs).map { template in
                LocalToolSnippet(
                    id: template.id,
                    sourceRef: "constraint:\(template.id)",
                    title: template.title,
                    text: template.text,
                    characterRangeDescription: nil,
                    confidence: nil
                )
            }
            return output(tool, query: query, snippets: snippets, truncated: false, emptyWarning: "No AI constraint templates are selected.")
        case .getPacketLimits:
            guard let budgetPlan else {
                return output(tool, query: query, snippets: [], truncated: false, emptyWarning: "Prompt budget plan is unavailable.")
            }
            let report = budgetPlan.report
            let lines = [
                "Selected mode: \(budgetPlan.mode.displayName).",
                "Context estimate: \(report.contextSizeTokens.map { "\($0)" } ?? "unknown") tokens.",
                "Full packet estimate: \(report.fullPacketTokens.map { "\($0)" } ?? "unavailable") tokens.",
                "Compact packet estimate: \(report.compactPacketTokens.map { "\($0)" } ?? "unavailable") tokens.",
                "Reserved output: \(report.reservedOutputTokens) tokens."
            ]
            let snippets = lines.enumerated().map { index, line in
                LocalToolSnippet(
                    id: "packet-limit-\(index + 1)",
                    sourceRef: "packet-budget",
                    title: "Packet limit",
                    text: line,
                    characterRangeDescription: nil,
                    confidence: nil
                )
            }
            return output(tool, query: query, snippets: snippets, truncated: false, emptyWarning: report.warnings.joined(separator: " ").nilIfBlank)
        }
    }

    private func lineOutput(
        _ tool: LocalAIGradingToolName,
        query: String,
        text: String,
        sourcePrefix: String,
        title: String
    ) -> LocalToolOutput {
        let snippets = StudentEvidenceIndex.makeLineSnippets(text: text, sourcePrefix: sourcePrefix, title: title)
        let result = StudentEvidenceIndex.search(snippets: snippets, query: query, maxCharacters: policy.maxToolOutputCharacters)
        return output(tool, query: query, snippets: result.snippets, truncated: result.truncated)
    }

    private func output(
        _ tool: LocalAIGradingToolName,
        query: String,
        snippets: [LocalToolSnippet],
        truncated: Bool,
        emptyWarning: String? = nil
    ) -> LocalToolOutput {
        LocalToolOutput(
            toolName: tool,
            query: query,
            snippets: snippets,
            truncated: truncated,
            warning: snippets.isEmpty ? (emptyWarning ?? "No local assignment-scoped match was found.") : (truncated ? "Results were shortened to fit the local tool output budget." : emptyWarning)
        )
    }

    private static func stableHash(_ value: String) -> String {
        let hash = value.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { partial, scalar in
            (partial ^ UInt64(scalar.value)).multipliedReportingOverflow(by: 1_099_511_628_211).partialValue
        }
        return String(hash, radix: 16)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
