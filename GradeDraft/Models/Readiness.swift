import Foundation

/// One reason a workflow step is not available yet. Each case's teacher-facing message is defined
/// here and only here; screens show `message` and never write their own copy for these states.
enum ReadinessIssue: Hashable, Sendable {
    case missingGradingStandard
    case missingStudentWork
    case scannedTextHasUnresolvedLines(Int)
    case scannedTextNotMarkedReviewed
    case localAIUnavailable(String)
    case aiReadinessNotChecked
    case aiCheckBlocked(String)
    case draftRunning
    case noCurrentDraft
    case draftStale
    case noFinalReview
    case finalReviewHasNoCriteria
    case finalReviewStale
    case criteriaNotApproved
    case scoreOutOfRange
    case finalReviewNotApproved
    case packetUnavailable(String)

    var message: String {
        switch self {
        case .missingGradingStandard:
            return "Add a rubric, answer key, exemplar, or grading criteria."
        case .missingStudentWork:
            return "Add student work or review scanned text."
        case .scannedTextHasUnresolvedLines(let count):
            return "Confirm, correct or reject the \(count) highlighted line(s) before marking the scanned text reviewed."
        case .scannedTextNotMarkedReviewed:
            return "Review scanned text before drafting feedback."
        case .localAIUnavailable(let detail):
            return detail
        case .aiReadinessNotChecked:
            return "Open the AI Draft screen to check the grading packet before drafting."
        case .aiCheckBlocked(let detail):
            return detail
        case .draftRunning:
            return "A local draft is already running for this student."
        case .noCurrentDraft:
            return "There is no current AI draft. Draft feedback locally or start manual final review."
        case .draftStale:
            return "Needs recheck: student work, rubric, or evidence changed after this draft."
        case .noFinalReview:
            return "Create a final review before final approval."
        case .finalReviewHasNoCriteria:
            return "Add at least one criterion before approval."
        case .finalReviewStale:
            return "This review needs rechecking because student work, rubric, or evidence changed."
        case .criteriaNotApproved:
            return "Approve all final-review criteria before finalizing."
        case .scoreOutOfRange:
            return "Correct out-of-range criterion scores before finalizing."
        case .finalReviewNotApproved:
            return "Student-facing export is blocked until the teacher approves the final grade."
        case .packetUnavailable(let detail):
            return "The grading inputs could not be read: \(detail)"
        }
    }
}

/// The single workflow-gating type. It answers, for one submission under its assignment setup, which
/// steps are open and why the others are not. AI checks come from `AIReadinessAnalyzer`'s report (built
/// when the AI Draft screen is open); they are not recomputed here.
struct AssignmentReadiness: Equatable, Sendable {
    let setupIssues: [ReadinessIssue]
    let scannedTextIssues: [ReadinessIssue]
    let draftIssues: [ReadinessIssue]
    let finalReviewStartIssues: [ReadinessIssue]
    let draftReviewStartIssues: [ReadinessIssue]
    let approvalIssues: [ReadinessIssue]
    let studentReportIssues: [ReadinessIssue]
    let draftIsStale: Bool
    let finalReviewIsStale: Bool

    var isSetupComplete: Bool { setupIssues.isEmpty }
    var isScannedTextReviewed: Bool { scannedTextIssues.isEmpty }
    var canDraft: Bool { draftIssues.isEmpty }
    /// A manual final review (no AI draft needed).
    var canStartFinalReview: Bool { finalReviewStartIssues.isEmpty }
    /// A final review that starts from the current AI draft.
    var canStartFinalReviewFromDraft: Bool { draftReviewStartIssues.isEmpty }
    var canApproveFinalReview: Bool { approvalIssues.isEmpty }
    var canExportStudentReport: Bool { studentReportIssues.isEmpty }

    /// - Parameters:
    ///   - aiStatus: the grading service's on-device model status.
    ///   - aiReport: the report from `AIReadinessAnalyzer`, or nil when the AI Draft screen has not built it.
    ///   - draftRunning: whether `BackgroundWork` is drafting for this submission.
    // swiftlint:disable:next cyclomatic_complexity
    init(
        setup: AssignmentSetup,
        submission: SubmissionGraph,
        aiStatus: LocalAIStatus,
        aiReport: AIReadinessReport?,
        draftRunning: Bool = false
    ) {
        let fingerprint: Result<String, any Error> = Result { try submission.packetFingerprint(setup: setup) }

        var setupIssues: [ReadinessIssue] = []
        if !setup.assignment.hasGradingStandard { setupIssues.append(.missingGradingStandard) }

        var scannedTextIssues: [ReadinessIssue] = []
        var studentWorkIssues: [ReadinessIssue] = []
        switch submission.submission.inputKind {
        case .none:
            studentWorkIssues.append(.missingStudentWork)
        case .pasted:
            if submission.reviewedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                studentWorkIssues.append(.missingStudentWork)
            }
        case .scanned:
            if let ocr = submission.ocr {
                if ocr.unresolvedLineCount > 0 {
                    scannedTextIssues.append(.scannedTextHasUnresolvedLines(ocr.unresolvedLineCount))
                } else if ocr.reviewStatus != .reviewed {
                    scannedTextIssues.append(.scannedTextNotMarkedReviewed)
                }
                if submission.reviewedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    studentWorkIssues.append(.missingStudentWork)
                }
            } else {
                studentWorkIssues.append(.missingStudentWork)
            }
        }

        var packetIssues: [ReadinessIssue] = []
        let currentFingerprint: String?
        switch fingerprint {
        case .success(let value):
            currentFingerprint = value
        case .failure(let error):
            currentFingerprint = nil
            packetIssues.append(.packetUnavailable(error.localizedDescription))
        }

        let draftIsStale = submission.draft.map { $0.packetFingerprint != currentFingerprint } ?? false
        let finalReviewIsStale = submission.finalReview.map { $0.packetFingerprint != currentFingerprint } ?? false

        let gradingInputIssues = packetIssues + setupIssues + studentWorkIssues + scannedTextIssues

        var draftIssues = gradingInputIssues
        if draftRunning { draftIssues.append(.draftRunning) }
        if case .unavailable(let detail) = aiStatus {
            draftIssues.append(.localAIUnavailable(detail))
        } else if let aiReport {
            if !aiReport.canGenerate { draftIssues.append(.aiCheckBlocked(aiReport.recommendedNextAction)) }
        } else {
            draftIssues.append(.aiReadinessNotChecked)
        }

        // A finishing draft replaces the final review, so no final review starts while one is running.
        let finalReviewStartIssues = gradingInputIssues + (draftRunning ? [.draftRunning] : [])
        var draftReviewStartIssues = finalReviewStartIssues
        if submission.draft == nil {
            draftReviewStartIssues.append(.noCurrentDraft)
        } else if draftIsStale {
            draftReviewStartIssues.append(.draftStale)
        }

        var approvalIssues = packetIssues
        if let review = submission.finalReview {
            if review.criteria.isEmpty { approvalIssues.append(.finalReviewHasNoCriteria) }
            if finalReviewIsStale { approvalIssues.append(.finalReviewStale) }
            if !review.criteria.isEmpty, !review.allCriteriaApproved { approvalIssues.append(.criteriaNotApproved) }
            if review.criteria.contains(where: { Self.isOutOfRange($0, setup: setup) }) { approvalIssues.append(.scoreOutOfRange) }
        } else {
            approvalIssues.append(.noFinalReview)
        }

        var studentReportIssues: [ReadinessIssue] = []
        if !ExportPolicy.allowsStudentReport(setup: setup, submission: submission) {
            if submission.finalReview == nil {
                studentReportIssues.append(.noFinalReview)
            } else if finalReviewIsStale {
                studentReportIssues.append(.finalReviewStale)
            } else {
                studentReportIssues.append(.finalReviewNotApproved)
            }
        }

        self.setupIssues = setupIssues
        self.scannedTextIssues = scannedTextIssues
        self.draftIssues = draftIssues
        self.finalReviewStartIssues = finalReviewStartIssues
        self.draftReviewStartIssues = draftReviewStartIssues
        self.approvalIssues = approvalIssues
        self.studentReportIssues = studentReportIssues
        self.draftIsStale = draftIsStale
        self.finalReviewIsStale = finalReviewIsStale
    }

    /// The criterion's maximum comes from the rubric, or from the criterion itself when the assignment
    /// has no point-bearing rubric. Without a positive maximum only negative scores are out of range.
    static func maximumPoints(for criterion: FinalCriterionScore, setup: AssignmentSetup) -> Double? {
        setup.parsedRubric.criterion(id: criterion.criterionID)?.maxPoints ?? criterion.maxPoints
    }

    private static func isOutOfRange(_ criterion: FinalCriterionScore, setup: AssignmentSetup) -> Bool {
        if criterion.finalPoints < 0 { return true }
        guard let maximum = maximumPoints(for: criterion, setup: setup), maximum > 0 else { return false }
        return criterion.finalPoints > maximum
    }
}
