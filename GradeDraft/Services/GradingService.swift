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
        if input.rubricText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
    static func normalizeAndValidate(_ draft: GradeDraftResult, input: GradingInput) throws -> GradeDraftResult {
        guard !draft.criteria.isEmpty else {
            throw GradeDraftError.invalidModelGrade("At least one rubric criterion is required.")
        }

        var normalizedCriteria: [CriterionScore] = []
        var complianceFlags = draft.complianceFlags
        let parsedCriteria = input.parsedRubric.criteria
        let parsedByID = Dictionary(uniqueKeysWithValues: parsedCriteria.map { ($0.id, $0) })
        var seenCriterionIDs: Set<String> = []

        for criterion in draft.criteria {
            let trimmedName = criterion.criterion.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                throw GradeDraftError.invalidModelGrade("A criterion was missing its name.")
            }

            let matchedRubricCriterion = matchedCriterion(for: criterion, parsedCriteria: parsedCriteria, parsedByID: parsedByID)
            let resolvedCriterionID = criterion.criterionID ?? matchedRubricCriterion?.id
            let resolvedName = matchedRubricCriterion?.title ?? trimmedName
            let rubricMax = matchedRubricCriterion?.maxPoints ?? criterion.maxPoints

            if let resolvedCriterionID {
                if seenCriterionIDs.contains(resolvedCriterionID) {
                    throw GradeDraftError.invalidModelGrade("The criterion \(resolvedName) was scored more than once.")
                }
                seenCriterionIDs.insert(resolvedCriterionID)
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
            let hasEvidence = !evidence.isEmpty
            let needsReview = criterion.teacherReviewRequired || !hasEvidence || !input.parsedRubric.issues.isEmpty
            if !hasEvidence {
                complianceFlags.append("\(resolvedName) had no evidence and was marked for teacher review.")
            }

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
                    teacherReviewRequired: needsReview
                )
            )
        }

        if !parsedCriteria.isEmpty {
            let missing = parsedCriteria.filter { !seenCriterionIDs.contains($0.id) }
            if !missing.isEmpty {
                let names = missing.map(\.title).joined(separator: ", ")
                throw GradeDraftError.invalidModelGrade("The local model did not score every structured rubric criterion. Missing: \(names).")
            }
        }

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
            uncertaintyFlags: draft.uncertaintyFlags
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } + input.parsedRubric.issues,
            complianceFlags: Array(Set(complianceFlags)).sorted(),
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
}

final class UnavailableLocalGradingService: GradingServicing, CapabilityChecking {
    var localAIStatus: LocalAIStatus {
        .unavailable("Local AI grading is unavailable in this build.")
    }

    func draftGrade(input: GradingInput) async throws -> GradeDraftResult {
        try LocalOnlyGradingValidator.validate(input)
        throw GradeDraftError.localModelUnavailable("Local AI grading is unavailable in this build.")
    }
}
