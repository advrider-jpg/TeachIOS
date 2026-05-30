import Foundation

enum GradeTotals {
    static func applyingDeterministicTotals(to result: GradeDraftResult) -> GradeDraftResult {
        let total = result.criteria.reduce(0) { $0 + max(0, $1.proposedPoints) }
        let maxScore = result.criteria.reduce(0) { $0 + max(0, $1.maxPoints) }
        return GradeDraftResult(
            id: result.id,
            generatedAt: result.generatedAt,
            packetFingerprint: result.packetFingerprint,
            status: result.status,
            studentResponseSummary: result.studentResponseSummary,
            criteria: result.criteria,
            totalScore: total,
            maxScore: maxScore,
            studentFeedback: result.studentFeedback,
            teacherNotes: result.teacherNotes,
            uncertaintyFlags: result.uncertaintyFlags,
            complianceFlags: result.complianceFlags,
            rawModelResponse: result.rawModelResponse,
            localModelAudit: result.localModelAudit
        )
    }

    static func applyingDeterministicTotals(to review: FinalGradeReview) -> FinalGradeReview {
        FinalGradeReview(
            id: review.id,
            createdAt: review.createdAt,
            finalizedAt: review.finalizedAt,
            packetFingerprint: review.packetFingerprint,
            status: review.status,
            criteria: review.criteria,
            totalScore: review.criteria.reduce(0) { $0 + max(0, $1.finalPoints) },
            maxScore: review.criteria.reduce(0) { $0 + max(0, $1.maxPoints) },
            studentFeedback: review.studentFeedback,
            privateTeacherNotes: review.privateTeacherNotes,
            teacherEdited: review.teacherEdited
        )
    }

    static func formatted(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
