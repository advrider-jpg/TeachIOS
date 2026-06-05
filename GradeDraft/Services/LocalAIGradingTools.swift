import Foundation

enum LocalAIGradingToolName: String, CaseIterable, Codable, Equatable, Sendable {
    case findRubricCriterion
    case findStudentEvidence
    case findOCRLine
    case findSourceReference
    case findAnswerKeySegment
    case findExemplarSegment
    case findCurriculumReference
    case listAvailableCriteria
    case listSelectedAIConstraints
    case getPacketLimits
}

enum ForbiddenLocalAIToolName: String, CaseIterable, Codable, Equatable, Sendable {
    case approveFinalGrade
    case exportStudentReport
    case sendEmail
    case uploadData
    case fetchWeb
    case readContacts
    case readCalendar
    case readOtherStudents
    case writeAssignmentRecord
    case deleteData
}

struct LocalAIToolPolicy: Codable, Equatable, Sendable {
    var allowedTools: [LocalAIGradingToolName]
    var forbiddenTools: [ForbiddenLocalAIToolName]
    var policySummary: String

    static let gradingSession = LocalAIToolPolicy(
        allowedTools: LocalAIGradingToolName.allCases,
        forbiddenTools: ForbiddenLocalAIToolName.allCases,
        policySummary: "Local AI tools are read-only, assignment-scoped, network-free, and cannot approve grades, export reports, write records, delete data, or read other students."
    )

    func allows(_ name: LocalAIGradingToolName) -> Bool {
        allowedTools.contains(name)
    }

    func forbids(_ rawName: String) -> Bool {
        ForbiddenLocalAIToolName(rawValue: rawName) != nil
    }
}

struct LocalAIToolResult: Codable, Equatable, Sendable {
    var toolName: String
    var query: String
    var matches: [String]
    var warning: String?
}

enum LocalAIGradingToolbox {
    static let maxMatches = 5
    static let maxSnippetCharacters = 360

    static func listAvailableCriteria(in input: GradingInput) -> LocalAIToolResult {
        LocalAIToolResult(
            toolName: LocalAIGradingToolName.listAvailableCriteria.rawValue,
            query: "",
            matches: input.parsedRubric.criteria.map { criterion in
                "\(criterion.id): \(criterion.title), max \(GradeTotals.formatted(criterion.maxPoints)). \(criterion.descriptor)"
            },
            warning: nil
        )
    }

    static func listSelectedAIConstraints(in input: GradingInput) -> LocalAIToolResult {
        let matches = GradingConstraintTemplates.templates(for: input.selectedInstructionTemplateIDs)
            .map { "\($0.id): \($0.title). \($0.text)" }
        return LocalAIToolResult(
            toolName: LocalAIGradingToolName.listSelectedAIConstraints.rawValue,
            query: "",
            matches: matches,
            warning: matches.isEmpty ? "No AI constraint templates are selected." : nil
        )
    }

    static func getPacketLimits(plan: PromptBudgetPlan) -> LocalAIToolResult {
        let report = plan.report
        let full = report.fullPacketTokens.map { "\($0)" } ?? "unavailable"
        let compact = report.compactPacketTokens.map { "\($0)" } ?? "unavailable"
        let largestCriterion = report.perCriterionTokenCounts.values.max().map { "\($0)" } ?? "unavailable"
        return LocalAIToolResult(
            toolName: LocalAIGradingToolName.getPacketLimits.rawValue,
            query: "",
            matches: [
                "Selected mode: \(plan.mode.displayName).",
                "Context estimate: \(report.contextSizeTokens.map { "\($0)" } ?? "unknown") tokens.",
                "Full packet estimate: \(full) tokens.",
                "Compact packet estimate: \(compact) tokens.",
                "Largest per-criterion estimate: \(largestCriterion) tokens.",
                "Reserved output: \(report.reservedOutputTokens) tokens."
            ],
            warning: report.warnings.joined(separator: " ").nilIfBlank
        )
    }

    static func findRubricCriterion(query: String, in input: GradingInput) -> LocalAIToolResult {
        let matchingCriteria = input.parsedRubric.criteria
            .filter { criterion in Self.matches(query: query, fields: [criterion.id, criterion.title, criterion.descriptor, criterion.groupTitle ?? ""]) }
            .prefix(maxMatches)
            .map { criterion in "\(criterion.id): \(criterion.title), max \(GradeTotals.formatted(criterion.maxPoints)). \(criterion.descriptor)" }
        return result(.findRubricCriterion, query: query, matches: Array(matchingCriteria))
    }

    static func findStudentEvidence(query: String, in input: GradingInput) -> LocalAIToolResult {
        result(.findStudentEvidence, query: query, matches: matchingLines(query: query, text: reviewedText(in: input)))
    }

    static func findOCRLine(query: String, in packet: GradingPacket) -> LocalAIToolResult {
        let haystack = packet.studentEvidence.reviewedTextWithSourceRefs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? packet.studentEvidence.reviewedText
            : packet.studentEvidence.reviewedTextWithSourceRefs
        return result(.findOCRLine, query: query, matches: matchingLines(query: query, text: haystack))
    }

    static func findSourceReference(query: String, in packet: GradingPacket) -> LocalAIToolResult {
        let matchingReferences = packet.evidenceReferences
            .filter { Self.matches(query: query, fields: [$0.id.uuidString, $0.quote, $0.sourceKind, $0.sourceInputID?.uuidString ?? ""]) }
            .prefix(maxMatches)
            .map { evidence in
                let source = evidence.sourceInputID?.uuidString ?? "unknown-source"
                return "source:\(source) page:\(evidence.pageIndex.map { "\($0)" } ?? "unknown") quote:\(snippet(evidence.quote))"
            }
        return result(.findSourceReference, query: query, matches: Array(matchingReferences))
    }

    static func findAnswerKeySegment(query: String, in input: GradingInput) -> LocalAIToolResult {
        result(.findAnswerKeySegment, query: query, matches: matchingLines(query: query, text: input.answerKeyText))
    }

    static func findExemplarSegment(query: String, in input: GradingInput) -> LocalAIToolResult {
        result(.findExemplarSegment, query: query, matches: matchingLines(query: query, text: input.exemplarText))
    }

    static func findCurriculumReference(query: String, in input: GradingInput) -> LocalAIToolResult {
        result(.findCurriculumReference, query: query, matches: matchingLines(query: query, text: input.curriculumReference))
    }

    private static func result(_ tool: LocalAIGradingToolName, query: String, matches: [String]) -> LocalAIToolResult {
        LocalAIToolResult(
            toolName: tool.rawValue,
            query: query,
            matches: matches,
            warning: matches.isEmpty ? "No local assignment-scoped match was found." : nil
        )
    }

    private static func matchingLines(query: String, text: String) -> [String] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        return text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.localizedCaseInsensitiveContains(trimmedQuery) }
            .prefix(maxMatches)
            .map(snippet)
    }

    private static func matches(query: String, fields: [String]) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return false }
        return fields.contains { $0.localizedCaseInsensitiveContains(trimmedQuery) }
    }

    private static func reviewedText(in input: GradingInput) -> String {
        input.reviewedTextWithSourceRefs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? input.reviewedStudentText
            : input.reviewedTextWithSourceRefs
    }

    private static func snippet(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxSnippetCharacters else { return trimmed }
        return String(trimmed.prefix(maxSnippetCharacters)) + "..."
    }
}

enum FeedbackRewriteMode: String, CaseIterable, Codable, Identifiable, Equatable, Sendable {
    case warmer
    case concise
    case specific
    case ageAppropriate
    case strengthsNextStep
    case removeFinalGradeLanguage
    case teacherNotesToStudentSafe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warmer:
            return "Make warmer"
        case .concise:
            return "Make concise"
        case .specific:
            return "Make specific"
        case .ageAppropriate:
            return "Age appropriate"
        case .strengthsNextStep:
            return "Strengths + next step"
        case .removeFinalGradeLanguage:
            return "Remove final-grade language"
        case .teacherNotesToStudentSafe:
            return "Student-safe from notes"
        }
    }

    var instruction: String {
        switch self {
        case .warmer:
            return "Make the student-facing feedback warmer while preserving the teacher's meaning."
        case .concise:
            return "Make the student-facing feedback more concise while preserving specific evidence."
        case .specific:
            return "Make the student-facing feedback more specific using only the supplied reviewed evidence and final-review criteria."
        case .ageAppropriate:
            return "Convert the student-facing feedback to age-appropriate language for the supplied grade or year level."
        case .strengthsNextStep:
            return "Format the feedback as strengths plus one practical next step."
        case .removeFinalGradeLanguage:
            return "Remove final-grade or official-grade language while preserving the reviewed teacher meaning."
        case .teacherNotesToStudentSafe:
            return "Rewrite only the teacher-selected private notes into student-safe feedback. Do not include private concerns or hidden rules."
        }
    }
}

struct FeedbackRewriteInput: Codable, Equatable {
    var assignmentID: UUID
    var mode: FeedbackRewriteMode
    var currentStudentFeedback: String
    var selectedTeacherNotes: String
    var gradeLevel: String
    var criteria: [FinalCriterionScore]
    var reviewedStudentText: String
    var packetFingerprint: String
}

struct FeedbackRewriteResult: Codable, Equatable {
    var rewrittenFeedback: String
    var teacherReviewNotes: [String]
}

enum FeedbackRewriteValidator {
    static func validate(_ result: FeedbackRewriteResult, input: FeedbackRewriteInput) throws -> FeedbackRewriteResult {
        _ = input
        let feedback = result.rewrittenFeedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !feedback.isEmpty else {
            throw GradeDraftError.invalidModelGrade("The rewrite assistant returned empty feedback.")
        }
        if containsFinalGradeLanguage(feedback) {
            throw GradeDraftError.invalidModelGrade("The rewrite assistant returned final-grade language.")
        }
        if containsProhibitedInference(feedback) {
            throw GradeDraftError.invalidModelGrade("The rewrite assistant returned prohibited inference language.")
        }
        let notes = Array(Set(result.teacherReviewNotes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        return FeedbackRewriteResult(rewrittenFeedback: feedback, teacherReviewNotes: notes + ["Teacher approval is required before student-facing export."])
    }

    private static let prohibitedInferencePatterns: [String] = [
        #"\beffort\b"#,
        #"\btried hard\b"#,
        #"\bdid not try\b"#,
        #"\bintent\b"#,
        #"\bmotivat(?:ed|ion|ional|e|ed)\b"#,
        #"\bbehavior\b"#,
        #"\battitude\b"#,
        #"\bpersonality\b"#,
        #"\blazy\b"#,
        #"\bcareless(?:ness)?\b"#,
        #"\b(?:low|high) ability\b"#,
        #"\bdisab(?:ility|led)\b"#,
        #"\beal/d\b"#,
        #"\beald\b"#,
        #"\besl\b"#,
        #"\bdemographic\b"#,
        #"\bhome support\b"#,
        #"\bfuture performance\b"#,
        #"\bintelligence\b"#
    ]

    private static let finalGradeLanguagePatterns: [String] = [
        #"\bfinal grade\b"#,
        #"\bofficial grade\b"#,
        #"\bcertified score\b"#,
        #"\bthe student receives\b"#,
        #"\bi have graded\b"#
    ]

    private static func containsProhibitedInference(_ text: String) -> Bool {
        prohibitedInferencePatterns.contains { pattern in
            text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static func containsFinalGradeLanguage(_ text: String) -> Bool {
        var normalized = text.lowercased()
        normalized = normalized.replacingOccurrences(of: "not a final grade", with: "")
        normalized = normalized.replacingOccurrences(of: "not final grade", with: "")
        normalized = normalized.replacingOccurrences(of: "not the final grade", with: "")
        return finalGradeLanguagePatterns.contains { pattern in
            normalized.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
}
