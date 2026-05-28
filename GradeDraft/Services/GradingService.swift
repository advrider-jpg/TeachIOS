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
    }
}

enum GradeDraftValidator {
    static func normalizeAndValidate(_ draft: GradeDraftResult) throws -> GradeDraftResult {
        guard !draft.criteria.isEmpty else {
            throw GradeDraftError.invalidModelGrade("At least one rubric criterion is required.")
        }

        var normalizedCriteria: [CriterionScore] = []
        var complianceFlags = draft.complianceFlags

        for criterion in draft.criteria {
            let trimmedName = criterion.criterion.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                throw GradeDraftError.invalidModelGrade("A criterion was missing its name.")
            }
            guard criterion.maxPoints >= 0 else {
                throw GradeDraftError.invalidModelGrade("\(trimmedName) had a negative maximum score.")
            }

            let clampedPoints = max(0, min(criterion.proposedPoints, criterion.maxPoints))
            if clampedPoints != criterion.proposedPoints {
                complianceFlags.append("Adjusted \(trimmedName) from \(criterion.proposedPoints) to \(clampedPoints) to keep the score within 0 and max points.")
            }

            let hasEvidence = !criterion.evidence.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.isEmpty
            let needsReview = criterion.teacherReviewRequired || !hasEvidence
            if !hasEvidence {
                complianceFlags.append("\(trimmedName) had no evidence and was marked for teacher review.")
            }

            normalizedCriteria.append(
                CriterionScore(
                    id: criterion.id,
                    criterion: trimmedName,
                    rating: criterion.rating.trimmingCharacters(in: .whitespacesAndNewlines),
                    proposedPoints: clampedPoints,
                    maxPoints: criterion.maxPoints,
                    evidence: criterion.evidence
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty },
                    explanation: criterion.explanation.trimmingCharacters(in: .whitespacesAndNewlines),
                    teacherReviewRequired: needsReview
                )
            )
        }

        let withNormalizedCriteria = GradeDraftResult(
            id: draft.id,
            generatedAt: draft.generatedAt,
            studentResponseSummary: draft.studentResponseSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            criteria: normalizedCriteria,
            totalScore: draft.totalScore,
            maxScore: draft.maxScore,
            studentFeedback: draft.studentFeedback.trimmingCharacters(in: .whitespacesAndNewlines),
            teacherNotes: draft.teacherNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            uncertaintyFlags: draft.uncertaintyFlags
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            complianceFlags: Array(Set(complianceFlags)).sorted(),
            rawModelResponse: draft.rawModelResponse
        )

        return GradeTotals.applyingDeterministicTotals(to: withNormalizedCriteria)
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
