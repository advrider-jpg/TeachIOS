import Foundation

enum AIBatchReadinessRowStatus: String, Codable, Equatable, Sendable {
    case ready
    case needsReview
    case blocked
}

struct AIBatchReadinessRow: Codable, Equatable, Identifiable, Sendable {
    var id: UUID { assignmentID }
    var assignmentID: UUID
    var displayTitle: String
    var status: AIBatchReadinessRowStatus
    var canQueueDraft: Bool
    var plannedGenerationMode: LocalModelGenerationMode
    var tokenEstimateSummary: String
    var blockers: [String]
    var reviewWarnings: [String]
}

struct AIBatchReadinessReport: Codable, Equatable, Sendable {
    var rows: [AIBatchReadinessRow]
    var readyCount: Int
    var needsReviewCount: Int
    var blockedCount: Int
    var canStartQueue: Bool
    var queuePolicySummary: String

    static let queuePolicy = "Batch drafts must run locally, one assignment at a time, with teacher pause/cancel controls. Batch readiness never creates drafts, final approvals, or student-facing exports."
}

enum AIBatchReadinessAnalyzer {
    static func report(
        for assignments: [AssignmentRecord],
        localAIStatus: LocalAIStatus,
        budgetPlans: [UUID: PromptBudgetPlan] = [:],
        budgetErrors: [UUID: Error] = [:]
    ) -> AIBatchReadinessReport {
        let rows = assignments.map { assignment in
            row(for: assignment, localAIStatus: localAIStatus, budgetPlan: budgetPlans[assignment.id], budgetError: budgetErrors[assignment.id])
        }
        let ready = rows.filter { $0.status == .ready }.count
        let needsReview = rows.filter { $0.status == .needsReview }.count
        let blocked = rows.filter { $0.status == .blocked }.count
        return AIBatchReadinessReport(
            rows: rows,
            readyCount: ready,
            needsReviewCount: needsReview,
            blockedCount: blocked,
            canStartQueue: ready > 0,
            queuePolicySummary: AIBatchReadinessReport.queuePolicy
        )
    }

    private static func row(
        for assignment: AssignmentRecord,
        localAIStatus: LocalAIStatus,
        budgetPlan: PromptBudgetPlan?,
        budgetError: Error?
    ) -> AIBatchReadinessRow {
        let readiness = AIReadinessAnalyzer.report(
            for: assignment,
            localAIStatus: localAIStatus,
            budgetPlan: budgetPlan,
            budgetError: budgetError
        )
        let blockers = readiness.checks
            .filter { $0.status == .blocked || $0.status == .unavailable }
            .map { "\($0.title): \($0.detail)" }
        let warnings = readiness.checks
            .filter { $0.status == .needsReview }
            .map { "\($0.title): \($0.detail)" }

        let status: AIBatchReadinessRowStatus
        if !blockers.isEmpty {
            status = .blocked
        } else if !warnings.isEmpty {
            status = .needsReview
        } else {
            status = .ready
        }

        return AIBatchReadinessRow(
            assignmentID: assignment.id,
            displayTitle: safeDisplayTitle(for: assignment),
            status: status,
            canQueueDraft: status == .ready,
            plannedGenerationMode: readiness.plannedGenerationMode,
            tokenEstimateSummary: readiness.tokenEstimateSummary,
            blockers: blockers,
            reviewWarnings: warnings
        )
    }

    private static func safeDisplayTitle(for assignment: AssignmentRecord) -> String {
        var title = assignment.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            title = "Untitled assignment"
        }
        let identityValues = [
            assignment.studentDisplayName,
            assignment.studentID?.uuidString ?? "",
            assignment.className
        ]
        return identityValues
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
            .reduce(title) { current, value in
                current.replacingOccurrences(of: value, with: "[redacted identity]", options: [.caseInsensitive])
            }
    }
}
