import Foundation
import PDFKit
import UIKit
import ZIPFoundation

@MainActor
extension GradeDraftViewModel {
    func refreshAIReadiness() {
        guard let currentAssignment = currentSavedAssignmentForAction("AI readiness") else {
            aiReadinessReport = nil
            aiPacketPreview = nil
            return
        }
        let budgetResult = localPromptBudgetPlan()
        aiReadinessReport = AIReadinessAnalyzer.report(
            for: currentAssignment,
            localAIStatus: localAIStatus,
            budgetPlan: budgetResult.plan,
            budgetError: budgetResult.error
        )
        if let plan = budgetResult.plan {
            aiPacketPreview = AIPacketPreviewBuilder.preview(for: currentAssignment, plan: plan)
        } else {
            aiPacketPreview = nil
        }
    }

    func buildAIPacketPreview() {
        guard let currentAssignment = currentSavedAssignmentForAction("AI packet preview") else {
            aiReadinessReport = nil
            aiPacketPreview = nil
            return
        }
        refreshAIReadiness()
        guard aiPacketPreview?.assignmentID == currentAssignment.id else {
            errorMessage = aiReadinessReport?.recommendedNextAction ?? "The local AI packet is not ready for preview."
            return
        }
        statusMessage = "Local AI packet preview prepared. Review it before drafting feedback."
    }

    func confirmAndDraftGrade() {
        guard let currentAssignment = currentSavedAssignmentForAction("Local draft generation") else { return }
        guard draftGenerationTask == nil else {
            statusMessage = "A local draft operation is already running."
            return
        }
        buildAIPacketPreview()
        guard aiPacketPreview?.assignmentID == currentAssignment.id else { return }
        draftGenerationTask = Task { [weak self] in
            await self?.draftGrade()
        }
    }

    func cancelDraftGeneration() {
        guard let draftGenerationTask else {
            statusMessage = "No local draft is running."
            return
        }
        aiGenerationProgress = AIGenerationProgress(
            stage: .cancellationRequested,
            detail: "Cancelling the local draft request. No draft will be saved if cancellation completes.",
            canCancel: false
        )
        statusMessage = aiGenerationProgress.detail
        draftGenerationTask.cancel()
    }

    func draftGrade() async {
        guard let currentAssignment = currentSavedAssignmentForAction("Local draft generation") else { return }
        guard canDraftGrade else {
            errorMessage = readinessIssues.first ?? "Draft feedback is not ready."
            return
        }
        isWorking = true
        errorMessage = nil
        clearPreparedExport()
        defer {
            isWorking = false
            draftGenerationTask = nil
            if aiGenerationProgress.stage != .completed && aiGenerationProgress.stage != .cancelled && aiGenerationProgress.stage != .failed {
                aiGenerationProgress = .idle
            }
        }

        do {
            let input = currentAssignment.gradingInput
            let progressHandler: AIGenerationProgressHandler = { [weak self] progress in
                self?.aiGenerationProgress = progress
                self?.statusMessage = progress.detail
            }
            let result = try await gradingService.draftGrade(input: input, progress: progressHandler)
            try Task.checkCancellation()
            aiGenerationProgress = AIGenerationProgress(
                stage: .storingDraft,
                detail: "Saving the validated local draft to this assignment.",
                canCancel: false
            )
            updateAssignment { assignment in
                assignment.latestDraft = result
                assignment.finalReview = nil
                assignment.appendAuditEvent(.draftGenerated, detail: "Local grading draft generated from packet \(input.packetFingerprint).")
            }
            let draftSavedMessage: String
            if result.localModelAudit?.generationMode == .perCriterion {
                draftSavedMessage = "Draft generated locally criterion-by-criterion because the full packet was too large. Review every criterion carefully before approval."
            } else {
                draftSavedMessage = "Draft feedback suggestion generated locally using Apple Foundation Models. Start teacher final review before using it."
            }
            try saveCurrentAssignment()
            statusMessage = draftSavedMessage
            aiGenerationProgress = AIGenerationProgress(
                stage: .completed,
                detail: "Local draft saved. Start teacher final review before using it.",
                completedUnitCount: 1,
                totalUnitCount: 1,
                canCancel: false
            )
        } catch {
            if Task.isCancelled || error.localizedDescription.localizedCaseInsensitiveContains("cancel") {
                aiGenerationProgress = AIGenerationProgress(
                    stage: .cancelled,
                    detail: "Local draft cancelled. No draft was saved.",
                    canCancel: false
                )
                statusMessage = aiGenerationProgress.detail
            } else {
                aiGenerationProgress = AIGenerationProgress(
                    stage: .failed,
                    detail: error.localizedDescription,
                    canCancel: false
                )
                errorMessage = error.localizedDescription
            }
        }
    }

    func rewriteFinalReviewFeedback(mode: FeedbackRewriteMode) async {
        guard let currentAssignment = currentSavedAssignmentForAction("Feedback rewrite") else { return }
        guard !isWorking else {
            statusMessage = "A local operation is already running."
            return
        }
        guard let review = currentAssignment.finalReview else {
            errorMessage = "Start final review before using the feedback rewrite assistant."
            return
        }
        guard review.status != .approved else {
            errorMessage = "Approved final feedback cannot be rewritten by AI. Reopen or edit the review manually if a correction is needed."
            return
        }
        guard case .available = localAIStatus else {
            if case .unavailable(let message) = localAIStatus {
                errorMessage = message
            } else {
                errorMessage = "Local AI is unavailable for feedback rewriting."
            }
            return
        }
        let rewriteInput = FeedbackRewriteInput(
            assignmentID: currentAssignment.id,
            mode: mode,
            currentStudentFeedback: review.studentFeedback,
            selectedTeacherNotes: mode == .teacherNotesToStudentSafe ? review.privateTeacherNotes : "",
            gradeLevel: currentAssignment.gradeLevel,
            criteria: review.criteria,
            reviewedStudentText: currentAssignment.reviewedStudentText,
            packetFingerprint: currentAssignment.gradingPacketFingerprint
        )
        isWorking = true
        errorMessage = nil
        aiGenerationProgress = AIGenerationProgress(
            stage: .rewritingFeedback,
            detail: "Rewriting feedback locally for teacher review.",
            canCancel: true
        )
        defer {
            isWorking = false
            if aiGenerationProgress.stage != .completed && aiGenerationProgress.stage != .failed {
                aiGenerationProgress = .idle
            }
        }
        do {
            let progressHandler: AIGenerationProgressHandler = { [weak self] progress in
                self?.aiGenerationProgress = progress
                self?.statusMessage = progress.detail
            }
            let result = try await gradingService.rewriteFeedback(input: rewriteInput, progress: progressHandler)
            var updatedReview = review
            updatedReview.studentFeedback = result.rewrittenFeedback
            updatedReview.teacherEdited = true
            updatedReview.status = .inProgress
            updateAssignment { assignment in
                assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: updatedReview)
                assignment.appendAuditEvent(.feedbackRewritten, detail: "Student-facing feedback rewritten locally in \(mode.displayName) mode. Teacher approval remains required.")
            }
            try saveCurrentAssignment()
            aiGenerationProgress = AIGenerationProgress(
                stage: .completed,
                detail: "Rewritten feedback saved for teacher review. Approve final review before export.",
                completedUnitCount: 1,
                totalUnitCount: 1,
                canCancel: false
            )
            statusMessage = result.teacherReviewNotes.joined(separator: " ")
        } catch {
            aiGenerationProgress = AIGenerationProgress(
                stage: .failed,
                detail: error.localizedDescription,
                canCancel: false
            )
            errorMessage = error.localizedDescription
        }
    }

    func localPromptBudgetPlan() -> (plan: PromptBudgetPlan?, error: Error?) {
        guard let currentAssignment = currentSavedAssignmentForAction("Prompt budget planning") else {
            return (nil, GradeDraftError.persistenceFailed("No saved assignment is selected."))
        }
        do {
            try LocalOnlyGradingValidator.validate(currentAssignment.gradingInput)
            return (try GradingPromptBudgeter.makePlan(input: currentAssignment.gradingInput), nil)
        } catch {
            return (nil, error)
        }
    }

    func startFinalReviewFromLatestDraft() {
        guard let currentAssignment = currentSavedAssignmentForAction("Start final review from draft") else { return }
        guard let draft = currentAssignment.latestDraft else { return }
        guard !currentAssignment.latestDraftIsStale else {
            errorMessage = "The latest local AI draft is stale because the grading packet changed. Generate a new draft or start manual final review."
            return
        }
        guard draft.packetFingerprint == currentAssignment.gradingPacketFingerprint else {
            errorMessage = "The latest local AI draft does not match the current grading packet. Generate a new draft or start manual final review."
            return
        }
        let final = FinalGradeReview(
            packetFingerprint: currentAssignment.gradingSourceFingerprint,
            status: .inProgress,
            criteria: draft.criteria.map(FinalCriterionScore.init(from:)),
            totalScore: draft.totalScore,
            maxScore: draft.maxScore,
            studentFeedback: draft.studentFeedback,
            privateTeacherNotes: draft.teacherNotes,
            teacherEdited: false
        )
        updateAssignment { assignment in
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: final)
            assignment.appendAuditEvent(.finalReviewStarted, detail: "Teacher review started from the latest local draft.")
        }
        guard persistOrSurfaceError() else { return }
        statusMessage = "Final review started. Approve each criterion before exporting as final."
    }

    func startManualFinalReview() {
        guard let currentAssignment = currentSavedAssignmentForAction("Start manual final review") else { return }
        guard canStartManualFinalReview else {
            errorMessage = manualGradingReadinessIssues.first ?? "Cannot start manual final review yet."
            return
        }

        let parsedCriteria = currentAssignment.parsedRubric.criteria
        let finalCriteria: [FinalCriterionScore]

        if !parsedCriteria.isEmpty {
            finalCriteria = parsedCriteria.map { criterion in
                FinalCriterionScore(
                    criterionID: criterion.id,
                    criterion: criterion.title,
                    rating: "",
                    proposedPoints: 0,
                    finalPoints: 0,
                    maxPoints: criterion.maxPoints,
                    evidence: [],
                    explanation: "",
                    teacherApproved: false,
                    teacherRationale: "Manual teacher-created final review."
                )
            }
        } else {
            finalCriteria = [FinalCriterionScore(
                criterionID: nil,
                criterion: "Teacher-entered grading standard",
                rating: "",
                proposedPoints: 0,
                finalPoints: 0,
                maxPoints: 0,
                evidence: [],
                explanation: "",
                teacherApproved: false,
                teacherRationale: "Manual teacher-created final review. Edit this criterion to match the grading standard, then approve it."
            )]
        }

        let review = FinalGradeReview(
            packetFingerprint: currentAssignment.gradingSourceFingerprint,
            status: .inProgress,
            criteria: finalCriteria,
            totalScore: 0,
            maxScore: finalCriteria.map(\.maxPoints).reduce(0, +),
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: false
        )
        updateAssignment { assignment in
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
            assignment.appendAuditEvent(.finalReviewStarted, detail: "Teacher started manual final review without AI draft.")
        }
        guard persistOrSurfaceError() else { return }
        statusMessage = "Manual final review started. Edit criteria, approve each one, then approve the final grade."
    }

    func addCriterionToFinalReview() {
        guard let currentAssignment = currentSavedAssignmentForAction("Add final-review criterion"),
              var review = currentAssignment.finalReview else { return }
        let newCriterion = FinalCriterionScore(
            criterionID: nil,
            criterion: "New criterion",
            rating: "",
            proposedPoints: 0,
            finalPoints: 0,
            maxPoints: 0,
            evidence: [],
            explanation: "",
            teacherApproved: false,
            teacherRationale: ""
        )
        review.criteria.append(newCriterion)
        review.teacherEdited = true
        review = GradeTotals.applyingDeterministicTotals(to: review)
        updateAssignment { assignment in
            assignment.finalReview = review
        }
        persistOrSurfaceError()
    }

    func deleteCriterionFromFinalReview(id: UUID) {
        guard let currentAssignment = currentSavedAssignmentForAction("Delete final-review criterion"),
              var review = currentAssignment.finalReview else { return }
        review.criteria.removeAll { $0.id == id }
        review.teacherEdited = true
        review = GradeTotals.applyingDeterministicTotals(to: review)
        updateAssignment { assignment in
            assignment.finalReview = review
        }
        persistOrSurfaceError()
    }

    func updateFinalReview(_ review: FinalGradeReview) {
        guard currentSavedAssignmentForAction("Update final review") != nil else { return }
        var review = review
        review.teacherEdited = true
        updateAssignment { assignment in
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
        }
        persistOrSurfaceError()
    }

    func acceptFinalReviewCriterion(id: UUID) {
        guard let currentAssignment = currentSavedAssignmentForAction("Accept final-review criterion"),
              var review = currentAssignment.finalReview,
              let index = review.criteria.firstIndex(where: { $0.id == id }) else { return }
        review.criteria[index].finalPoints = clampedFinalPoints(
            review.criteria[index].proposedPoints,
            maxPoints: review.criteria[index].maxPoints
        )
        review.criteria[index].teacherApproved = true
        if review.criteria[index].teacherRationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            review.criteria[index].teacherRationale = "Teacher accepted this criterion suggestion after review."
        }
        review.teacherEdited = true
        review.status = .inProgress
        review.finalizedAt = nil
        updateAssignment { assignment in
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
            assignment.appendAuditEvent(.inputChanged, detail: "Teacher accepted a final-review criterion suggestion.")
        }
        guard persistOrSurfaceError() else { return }
        statusMessage = "Criterion suggestion accepted locally. Final approval is still required."
    }

    func rejectFinalReviewCriterion(id: UUID) {
        guard let currentAssignment = currentSavedAssignmentForAction("Reject final-review criterion"),
              var review = currentAssignment.finalReview,
              let index = review.criteria.firstIndex(where: { $0.id == id }) else { return }
        review.criteria[index].teacherApproved = false
        review.criteria[index].teacherRationale = "Teacher rejected this criterion suggestion; edit score, evidence, and feedback before approval."
        review.teacherEdited = true
        review.status = .inProgress
        review.finalizedAt = nil
        updateAssignment { assignment in
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
            assignment.appendAuditEvent(.inputChanged, detail: "Teacher rejected a final-review criterion suggestion.")
        }
        guard persistOrSurfaceError() else { return }
        statusMessage = "Criterion suggestion rejected locally. Edit it before final approval."
    }

    func approveFinalReview() {
        guard let currentAssignment = currentSavedAssignmentForAction("Approve final review"),
              var review = currentAssignment.finalReview else { return }
        guard canApproveFinalReview else {
            errorMessage = finalReviewApprovalBlockMessage ?? "This final review is not ready for final approval."
            return
        }
        review.criteria = review.criteria.map { criterion in
            var criterion = criterion
            criterion.teacherApproved = true
            return criterion
        }
        review.status = .approved
        review.packetFingerprint = currentAssignment.gradingSourceFingerprint
        review.finalizedAt = Date()
        review = GradeTotals.applyingDeterministicTotals(to: review)
        updateAssignment { assignment in
            assignment.finalReview = review
            assignment.appendAuditEvent(.finalApproved, detail: "Teacher approved final grade \(GradeTotals.formatted(review.totalScore)) / \(GradeTotals.formatted(review.maxScore)).")
        }
        guard persistOrSurfaceError() else { return }
        statusMessage = "Final grade approved and saved locally."
    }

    func clampedFinalPoints(_ value: Double, maxPoints: Double) -> Double {
        if maxPoints > 0 {
            return max(0, min(value, maxPoints))
        }
        return max(0, value)
    }
}
