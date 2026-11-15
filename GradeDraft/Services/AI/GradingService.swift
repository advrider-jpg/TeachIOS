import Foundation

enum LocalAIStatus: Equatable, Sendable {
    case available
    case unavailable(String)
}

protocol CapabilityChecking {
    var localAIStatus: LocalAIStatus { get }
    /// Whether the on-device model supports the device's current language and region.
    var supportsCurrentLocale: Bool { get }
}

typealias AIGenerationProgressHandler = @MainActor @Sendable (AIGenerationProgress) async -> Void

protocol GradingServicing: Sendable {
    func draftGrade(input: GradingInput, progress: AIGenerationProgressHandler?) async throws -> GradeDraftResult
    func rewriteFeedback(input: FeedbackRewriteInput, progress: AIGenerationProgressHandler?) async throws -> FeedbackRewriteResult
}

enum LocalOnlyGradingValidator {
    static func validate(_ input: GradingInput) throws {
        if !input.hasGradingStandard {
            throw GradeDraftError.missingRubric
        }
        if input.reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw GradeDraftError.missingStudentText
        }
        if input.ocrReviewStatus.blocksGrading {
            throw GradeDraftError.ocrReviewRequired
        }
    }
}

enum GradeDraftValidator {
    static let missingEvidenceMarker = "No supporting evidence found."

    /// Checks the model's proposal and turns it into the draft that is stored. With point-bearing rubric
    /// criteria, each proposal must name a rubric criterion ID and the title and maximum come from the rubric.
    /// Without them (answer key, exemplar or criteria text only), the model's own title and maximum are kept
    /// on the criterion. Totals are never taken from the model: `GradeDraftResult` sums the criterion points.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func validate(_ proposal: ModelDraftProposal, input: GradingInput, audit: LocalModelDraftAudit?) throws -> GradeDraftResult {
        guard !proposal.criteria.isEmpty else {
            throw GradeDraftError.invalidModelGrade("At least one rubric criterion is required.")
        }

        let reviewedText = input.reviewedStudentText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if reviewedText.isEmpty {
            throw GradeDraftError.invalidModelGrade("The reviewed student text is empty.")
        }

        var normalizedCriteria: [CriterionScore] = []
        var complianceFlags = proposal.complianceFlags
        var uncertaintyFlags = proposal.uncertaintyFlags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var mappedCriterionIDs: Set<String> = []
        var usedUnstructuredTitles: Set<String> = []
        var unmappedCriterionIDs: [String] = []

        if containsProhibitedInference(proposal.teacherNotes)
            || containsProhibitedInference(proposal.studentResponseSummary)
            || containsProhibitedInference(proposal.studentFeedback) {
            throw GradeDraftError.invalidModelGrade("The model output included prohibited inference language.")
        }

        if containsFinalGradeLanguage(proposal.studentResponseSummary) || containsFinalGradeLanguage(proposal.studentFeedback) {
            throw GradeDraftError.invalidModelGrade("The model output presented the draft as a final grade.")
        }

        if containsFinalGradeLanguage(proposal.teacherNotes) {
            uncertaintyFlags.append("Teacher notes used final-grade language; teacher review is required.")
            complianceFlags.append("Flagged final-grade language in private teacher notes for teacher review.")
        }

        if input.ocrQualitySummary.requiresTeacherOCRReview {
            uncertaintyFlags.append("Scanned text quality is uncertain; teacher review is required.")
        }

        if !input.parsedRubric.issues.isEmpty {
            uncertaintyFlags.append(contentsOf: input.parsedRubric.issues)
        }

        let parsedCriteria = input.parsedRubric.criteria
        let usesRubric = !parsedCriteria.isEmpty
        let parsedByID = Dictionary(parsedCriteria.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let availableSourceRefs = Set(sourceReferenceTags(in: input.reviewedTextWithSourceRefs))

        for (index, criterion) in proposal.criteria.enumerated() {
            guard !containsProhibitedInference(criterion.title ?? "")
                    && !containsProhibitedInference(criterion.explanation)
                    && !containsProhibitedInference(criterion.nextStep)
                    && !containsProhibitedInference(criterion.uncertaintyFlags.joined(separator: " ")) else {
                throw GradeDraftError.invalidModelGrade("The model output included prohibited inference language.")
            }

            if containsFinalGradeLanguage(criterion.explanation) || containsFinalGradeLanguage(criterion.nextStep) {
                throw GradeDraftError.invalidModelGrade("The model output presented a criterion suggestion as a final grade.")
            }

            let resolvedCriterionID: String
            let resolvedName: String
            let rubricMax: Double
            let storedTitle: String?
            let storedMaxPoints: Double?
            if usesRubric {
                // Titles and maximum points come from the rubric, never from model output.
                guard let matched = matchedCriterion(for: criterion, parsedCriteria: parsedCriteria, parsedByID: parsedByID) else {
                    unmappedCriterionIDs.append(criterion.criterionID.isEmpty ? "(no id)" : criterion.criterionID)
                    continue
                }
                if mappedCriterionIDs.contains(matched.id) {
                    throw GradeDraftError.invalidModelGrade("The criterion \(matched.title) was scored more than once.")
                }
                mappedCriterionIDs.insert(matched.id)
                resolvedCriterionID = matched.id
                resolvedName = matched.title
                rubricMax = matched.maxPoints
                storedTitle = nil
                storedMaxPoints = nil
            } else {
                let trimmedName = (criterion.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else {
                    throw GradeDraftError.invalidModelGrade("A criterion was missing its name.")
                }
                let titleKey = normalize(trimmedName)
                if usedUnstructuredTitles.contains(titleKey) {
                    throw GradeDraftError.invalidModelGrade("The criterion \(trimmedName) was scored more than once.")
                }
                usedUnstructuredTitles.insert(titleKey)
                let modelMax = criterion.maxPoints ?? 0
                resolvedCriterionID = RubricParser.stableCriterionID(order: index, title: trimmedName, maxPoints: modelMax)
                resolvedName = trimmedName
                rubricMax = modelMax
                storedTitle = trimmedName
                storedMaxPoints = modelMax
            }

            guard rubricMax >= 0 else {
                throw GradeDraftError.invalidModelGrade("\(resolvedName) had a negative maximum score.")
            }

            let clampedPoints = max(0, min(criterion.proposedPoints, rubricMax))
            if clampedPoints != criterion.proposedPoints {
                complianceFlags.append("Adjusted \(resolvedName) from \(criterion.proposedPoints) to \(clampedPoints) to keep the score within 0 and max points.")
            }

            let evidence = criterion.evidence
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let usesMissingEvidenceMarker = evidence.contains(where: isMissingEvidenceMarker)
            let missingEvidence = evidence.isEmpty || usesMissingEvidenceMarker

            var criteriaUncertainty: [String] = []
            var needsReview = criterion.teacherReviewRequired

            if missingEvidence {
                needsReview = true
                criteriaUncertainty.append("No supporting evidence found.")
                if !usesMissingEvidenceMarker {
                    complianceFlags.append("\(resolvedName) had no evidence quote and was marked for teacher review.")
                }
            }

            let evidenceOutsideReviewedText = evidence.filter { !isMissingEvidenceMarker($0) && !reviewedText.contains($0) }
            if !evidenceOutsideReviewedText.isEmpty {
                needsReview = true
                let evidenceFlag = "\(resolvedName): evidence not found in reviewed text."
                criteriaUncertainty.append(evidenceFlag)
                uncertaintyFlags.append(evidenceFlag)
                complianceFlags.append("\(resolvedName) included evidence not present in the reviewed text.")
            }

            let citedEvidence = evidence.filter { !isMissingEvidenceMarker($0) }
            let normalizedEvidenceSourceRefs = criterion.evidenceSourceRefs
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !availableSourceRefs.isEmpty && !citedEvidence.isEmpty {
                if normalizedEvidenceSourceRefs.isEmpty {
                    needsReview = true
                    let sourceFlag = "\(resolvedName): evidence source reference missing or unsupported; teacher review required."
                    criteriaUncertainty.append(sourceFlag)
                    uncertaintyFlags.append(sourceFlag)
                    complianceFlags.append("\(resolvedName) cited source-tagged text without matching source references.")
                } else {
                    let unsupportedRefs = normalizedEvidenceSourceRefs.filter { !availableSourceRefs.contains($0) }
                    if !unsupportedRefs.isEmpty {
                        needsReview = true
                        let sourceFlag = "\(resolvedName): evidence source reference missing or unsupported; teacher review required."
                        criteriaUncertainty.append(sourceFlag)
                        uncertaintyFlags.append(sourceFlag)
                        complianceFlags.append("\(resolvedName) cited unsupported source references: \(unsupportedRefs.joined(separator: ", ")).")
                    }
                }
            }

            if input.parsedRubric.issues.isNotEmpty {
                criteriaUncertainty.append("Rubric parsing issues were present in input.")
                needsReview = true
            }

            if input.ocrQualitySummary.requiresTeacherOCRReview {
                criteriaUncertainty.append("Scanned text quality or coverage requires teacher review.")
                needsReview = true
            }

            let modelUncertainty = criterion.uncertaintyFlags
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            var score = CriterionScore(
                criterionID: resolvedCriterionID,
                rating: criterion.rating.trimmingCharacters(in: .whitespacesAndNewlines),
                proposedPoints: clampedPoints,
                evidenceQuotes: evidence,
                explanation: criterion.explanation.trimmingCharacters(in: .whitespacesAndNewlines),
                teacherReviewRequired: needsReview,
                nextStep: criterion.nextStep.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: normalizeConfidence(criterion.confidence),
                uncertaintyFlags: Array(Set(modelUncertainty + criteriaUncertainty)).sorted()
            )
            score.title = storedTitle
            score.maxPoints = storedMaxPoints
            normalizedCriteria.append(score)
        }

        if !unmappedCriterionIDs.isEmpty {
            let ids = unmappedCriterionIDs.joined(separator: ", ")
            throw GradeDraftError.invalidModelGrade("The model output included unknown criteria not in the parsed rubric: \(ids).")
        }

        let missing = parsedCriteria.filter { !mappedCriterionIDs.contains($0.id) }
        if !missing.isEmpty {
            let names = missing.map(\.title).joined(separator: ", ")
            throw GradeDraftError.invalidModelGrade("The local model did not score every structured rubric criterion. Missing: \(names).")
        }

        let status: DraftStatus = normalizedCriteria.contains { $0.teacherReviewRequired } ? .teacherReviewRequired : .generated

        return GradeDraftResult(
            packetFingerprint: input.packetFingerprint,
            status: status,
            studentResponseSummary: proposal.studentResponseSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            criteria: normalizedCriteria,
            studentFeedback: proposal.studentFeedback.trimmingCharacters(in: .whitespacesAndNewlines),
            teacherNotes: proposal.teacherNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            uncertaintyFlags: Array(Set(uncertaintyFlags + input.parsedRubric.issues)).sorted(),
            complianceFlags: Array(Set(complianceFlags)).sorted(),
            modelAudit: audit
        )
    }

    private static func matchedCriterion(
        for criterion: ModelCriterionProposal,
        parsedCriteria: [RubricCriterion],
        parsedByID: [String: RubricCriterion]
    ) -> RubricCriterion? {
        let criterionID = criterion.criterionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !criterionID.isEmpty else { return nil }
        if let found = parsedByID[criterionID] {
            return found
        }
        let normalizedID = normalize(criterionID)
        return parsedCriteria.first { normalize($0.id) == normalizedID }
            ?? parsedCriteria.first { normalize($0.title) == normalizedID }
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
    }

    private static func isMissingEvidenceMarker(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(missingEvidenceMarker) == .orderedSame
    }

    private static func normalizeConfidence(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch trimmed {
        case "high", "medium", "low":
            return trimmed
        default:
            return "medium"
        }
    }

    private static let prohibitedInferencePatterns: [String] = [
        #"\beffort\b"#,
        #"\bno effort\b"#,
        #"\btried hard\b"#,
        #"\bdid not try\b"#,
        #"\bintent\b"#,
        #"\bmotivat(?:ed|ion|ional|e|ed)\b"#,
        #"\bunmotivated\b"#,
        #"\bbehavior\b"#,
        #"\battitude\b"#,
        #"\bpersonality\b"#,
        #"\blazy\b"#,
        #"\blaziness\b"#,
        #"\bcareless(?:ness)?\b"#,
        #"\b(?:low|high) ability\b"#,
        #"\bability level\b"#,
        #"\bdisab(?:ility|led)\b"#,
        #"\bimpairment\b"#,
        #"\bspecial needs\b"#,
        #"\beal/d\b"#,
        #"\beald\b"#,
        #"\besl\b"#,
        #"\blanguage background\b"#,
        #"\bdemographic\b"#,
        #"\bgifted(?:ness)?\b"#,
        #"\bhome support\b"#,
        #"\bfamily support\b"#,
        #"\bparent(?:al)? support\b"#,
        #"\bfuture performance\b"#,
        #"\bwill never\b"#,
        #"\balways will\b"#,
        #"\bintelligence\b"#,
        #"\bdiligence\b"#
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

    private static func sourceReferenceTags(in text: String) -> [String] {
        let pattern = #"\[p\d+-l\d+-[A-Fa-f0-9-]+\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }
}

private extension Array where Element == String {
    var isNotEmpty: Bool { !isEmpty }
}

final class UnavailableLocalGradingService: GradingServicing, CapabilityChecking, Sendable {
    var localAIStatus: LocalAIStatus {
        .unavailable("Local AI grading is unavailable. MarkForMe will not send this student work to a cloud model as a fallback.")
    }

    var supportsCurrentLocale: Bool { false }

    func draftGrade(input: GradingInput, progress: AIGenerationProgressHandler? = nil) async throws -> GradeDraftResult {
        await progress?(
            AIGenerationProgress(
                stage: .validatingInputs,
                detail: "Checking local grading inputs.",
                canCancel: true
            )
        )
        try LocalOnlyGradingValidator.validate(input)
        await progress?(
            AIGenerationProgress(
                stage: .checkingAvailability,
                detail: "Checking local AI availability.",
                canCancel: true
            )
        )
        throw GradeDraftError.localModelUnavailable("Local AI grading is unavailable. MarkForMe will not send this student work to a cloud model as a fallback.")
    }

    func rewriteFeedback(input: FeedbackRewriteInput, progress: AIGenerationProgressHandler? = nil) async throws -> FeedbackRewriteResult {
        await progress?(
            AIGenerationProgress(
                stage: .rewritingFeedback,
                detail: "Checking local AI availability for feedback rewriting.",
                canCancel: true
            )
        )
        throw GradeDraftError.localModelUnavailable("Local feedback rewriting is unavailable. MarkForMe will not send teacher feedback to a cloud model as a fallback.")
    }
}
