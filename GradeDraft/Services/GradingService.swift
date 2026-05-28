import Foundation

enum LocalAIStatus: Equatable {
    case available
    case unavailable(String)
}

protocol CapabilityChecking {
    var localAIStatus: LocalAIStatus { get }
}

protocol GradingServicing {
    func draftGrade(input: GradingInput) async throws -> GradeDraftResult
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

    // swiftlint:disable:next cyclomatic_complexity
    static func normalizeAndValidate(_ draft: GradeDraftResult, input: GradingInput) throws -> GradeDraftResult {
        guard !draft.criteria.isEmpty else {
            throw GradeDraftError.invalidModelGrade("At least one rubric criterion is required.")
        }

        let reviewedText = input.reviewedStudentText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if reviewedText.isEmpty {
            throw GradeDraftError.invalidModelGrade("The reviewed student text is empty.")
        }

        var normalizedCriteria: [CriterionScore] = []
        var complianceFlags = draft.complianceFlags
        var uncertaintyFlags = draft.uncertaintyFlags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var mappedCriterionIDs: Set<String> = []
        var usedFallbackCriterionNames: Set<String> = []
        var unmappedCriterionNames: [String] = []

        if containsProhibitedInference(draft.teacherNotes)
            || containsProhibitedInference(draft.studentResponseSummary)
            || containsProhibitedInference(draft.studentFeedback) {
            throw GradeDraftError.invalidModelGrade("The model output included prohibited inference language.")
        }

        if input.ocrQualitySummary.requiresTeacherOCRReview {
            uncertaintyFlags.append("OCR quality is uncertain; teacher review is required.")
        }

        if !input.parsedRubric.issues.isEmpty {
            uncertaintyFlags.append(contentsOf: input.parsedRubric.issues)
        }

        let parsedCriteria = input.parsedRubric.criteria
        let parsedByID = Dictionary(uniqueKeysWithValues: parsedCriteria.map { ($0.id, $0) })

        for criterion in draft.criteria {
            guard !containsProhibitedInference(criterion.criterion)
                    && !containsProhibitedInference(criterion.explanation)
                    && !containsProhibitedInference(criterion.nextStep)
                    && !containsProhibitedInference(criterion.criterionUncertaintyFlags.joined(separator: " ")) else {
                throw GradeDraftError.invalidModelGrade("The model output included prohibited inference language.")
            }

            let trimmedName = criterion.criterion.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                throw GradeDraftError.invalidModelGrade("A criterion was missing its name.")
            }

            let matchedRubricCriterion = matchedCriterion(for: criterion, parsedCriteria: parsedCriteria, parsedByID: parsedByID)
            let resolvedCriterionID = criterion.criterionID ?? matchedRubricCriterion?.id
            let resolvedName = matchedRubricCriterion?.title ?? trimmedName
            let rubricMax = matchedRubricCriterion?.maxPoints ?? criterion.maxPoints

            if let resolvedCriterionID {
                if mappedCriterionIDs.contains(resolvedCriterionID) {
                    throw GradeDraftError.invalidModelGrade("The criterion \(resolvedName) was scored more than once.")
                }
                mappedCriterionIDs.insert(resolvedCriterionID)
            } else {
                let fallbackKey = normalize(trimmedName)
                if usedFallbackCriterionNames.contains(fallbackKey) {
                    throw GradeDraftError.invalidModelGrade("The criterion \(resolvedName) was scored more than once.")
                }
                usedFallbackCriterionNames.insert(fallbackKey)
                if !parsedCriteria.isEmpty {
                    unmappedCriterionNames.append(resolvedName)
                }
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

            if criterion.teacherReviewRequired && !needsReview {
                needsReview = true
            }

            if input.parsedRubric.issues.isNotEmpty {
                criteriaUncertainty.append("Rubric parsing issues were present in input.")
                needsReview = true
            }

            if input.ocrQualitySummary.requiresTeacherOCRReview {
                criteriaUncertainty.append("OCR quality/coverage uncertainty requires teacher review.")
                needsReview = true
            }

            let normalizedConfidence = normalizeConfidence(criterion.confidence)
            let normalizedNextStep = criterion.nextStep.trimmingCharacters(in: .whitespacesAndNewlines)

            let modelUncertainty = criterion.criterionUncertaintyFlags
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            normalizedCriteria.append(
                CriterionScore(
                    id: criterion.id,
                    criterionID: resolvedCriterionID,
                    criterion: resolvedName,
                    rating: criterion.rating.trimmingCharacters(in: .whitespacesAndNewlines),
                    proposedPoints: clampedPoints,
                    maxPoints: rubricMax,
                    evidence: evidence,
                    evidenceSourceRefs: criterion.evidenceSourceRefs,
                    explanation: criterion.explanation.trimmingCharacters(in: .whitespacesAndNewlines),
                    teacherReviewRequired: needsReview,
                    nextStep: normalizedNextStep,
                    confidence: normalizedConfidence,
                    criterionUncertaintyFlags: Array(Set(modelUncertainty + criteriaUncertainty))
                )
            )
        }

        if !unmappedCriterionNames.isEmpty {
            let names = unmappedCriterionNames.joined(separator: ", ")
            throw GradeDraftError.invalidModelGrade("The model output included unknown criteria not in the parsed rubric: \(names).")
        }

        if !parsedCriteria.isEmpty {
            let missing = parsedCriteria.filter { !mappedCriterionIDs.contains($0.id) }
            if !missing.isEmpty {
                let names = missing.map(\.title).joined(separator: ", ")
                throw GradeDraftError.invalidModelGrade("The local model did not score every structured rubric criterion. Missing: \(names).")
            }
        }

        var complianceList = Array(Set(complianceFlags)).sorted()
        let finalUncertaintyFlags = Array(Set(uncertaintyFlags + input.parsedRubric.issues)).sorted()

        let status: DraftStatus = normalizedCriteria.contains { $0.teacherReviewRequired } ? .teacherReviewRequired : .generated

        let withNormalizedCriteria = GradeDraftResult(
            id: draft.id,
            generatedAt: draft.generatedAt,
            packetFingerprint: input.packetFingerprint,
            status: status,
            studentResponseSummary: draft.studentResponseSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            criteria: normalizedCriteria,
            totalScore: draft.totalScore,
            maxScore: draft.maxScore,
            studentFeedback: draft.studentFeedback.trimmingCharacters(in: .whitespacesAndNewlines),
            teacherNotes: draft.teacherNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            uncertaintyFlags: finalUncertaintyFlags,
            complianceFlags: complianceList,
            rawModelResponse: draft.rawModelResponse
        )

        return GradeTotals.applyingDeterministicTotals(to: withNormalizedCriteria)
    }

    private static func matchedCriterion(
        for criterion: CriterionScore,
        parsedCriteria: [RubricCriterion],
        parsedByID: [String: RubricCriterion]
    ) -> RubricCriterion? {
        if let criterionID = criterion.criterionID, let found = parsedByID[criterionID] {
            return found
        }

        let normalizedName = normalize(criterion.criterion)
        return parsedCriteria.first { normalize($0.title) == normalizedName }
            ?? parsedCriteria.first { normalize($0.title).contains(normalizedName) || normalizedName.contains(normalize($0.title)) }
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

    private static let prohibitedInferenceTokens: [String] = [
        "effort",
        "intent",
        "motivation",
        "behavior",
        "personality",
        "ability",
        "disability",
        "eal",
        "eal/d",
        "giftedness",
        "demographic",
        "support level",
        "intelligence",
        "diligence",
        "laziness"
    ]

    private static func containsProhibitedInference(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return prohibitedInferenceTokens.contains { token in
            normalized.contains(token)
        }
    }
}

private extension Array where Element == String {
    var isNotEmpty: Bool { !isEmpty }
}

final class UnavailableLocalGradingService: GradingServicing, CapabilityChecking {
    var localAIStatus: LocalAIStatus {
        .unavailable("Local AI grading is unavailable. GradeDraft will not send this student work to a cloud model as a fallback.")
    }

    func draftGrade(input: GradingInput) async throws -> GradeDraftResult {
        try LocalOnlyGradingValidator.validate(input)
        throw GradeDraftError.localModelUnavailable("Local AI grading is unavailable. GradeDraft will not send this student work to a cloud model as a fallback.")
    }
}
