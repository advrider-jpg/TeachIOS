import Foundation

import FoundationModels

final class FoundationModelGradingService: GradingServicing, CapabilityChecking, Sendable {
    private let generator: any DraftGenerating
    private let budgeter: any GradingPromptBudgeting
    private let availability: @Sendable () -> LocalAIStatus

    /// `availability` defaults to the device's real model state; tests that script the generator pass `.available`.
    init(
        generator: any DraftGenerating = SystemModelDraftGenerator(),
        budgeter: any GradingPromptBudgeting = GradingPromptBudgeter(),
        availability: @escaping @Sendable () -> LocalAIStatus = { FoundationModelGradingService.systemModelStatus() }
    ) {
        self.generator = generator
        self.budgeter = budgeter
        self.availability = availability
    }

    var localAIStatus: LocalAIStatus {
        availability()
    }

    var supportsCurrentLocale: Bool {
        SystemLanguageModel.default.supportsLocale(Locale.current)
    }

    static func systemModelStatus() -> LocalAIStatus {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(message(for: reason))
        @unknown default:
            return .unavailable("The on-device language model is unavailable for an unknown reason.")
        }
    }

    /// Prepares the session the next draft request will use. Called when the AI Draft screen opens.
    func prewarmIfAvailable() {
        guard localAIStatus == .available else { return }
        (generator as? SystemModelDraftGenerator)?.prewarm(instructions: PromptBuilder.gradingInstructionsText())
    }

    func draftGrade(input: GradingInput, progress: AIGenerationProgressHandler? = nil) async throws -> GradeDraftResult {
        do {
            await progress?(
                AIGenerationProgress(
                    stage: .validatingInputs,
                    detail: "Checking reviewed text, scanned text review, and grading standards.",
                    canCancel: true
                )
            )
            try LocalOnlyGradingValidator.validate(input)
            try Task.checkCancellation()

            await progress?(
                AIGenerationProgress(
                    stage: .checkingAvailability,
                    detail: "Checking the on-device model on this device.",
                    canCancel: true
                )
            )
            try requireAvailableModel()

            await progress?(
                AIGenerationProgress(
                    stage: .planningPacket,
                    detail: "Measuring the grading packet without truncating reviewed student text.",
                    canCancel: true
                )
            )
            var plan = try await budgeter.plan(input: input, after: nil)
            while true {
                try Task.checkCancellation()
                do {
                    return try await generateDraft(input: input, plan: plan, progress: progress)
                } catch {
                    // Only a context-size rejection steps down: full packet → compact packet → criterion by criterion.
                    guard !(error is GradeDraftError),
                          FoundationModelErrorMapper.map(error) == .contextTooLarge,
                          plan.mode != .perCriterion else {
                        throw error
                    }
                    plan = try await budgeter.plan(input: input, after: plan.mode)
                    await progress?(
                        AIGenerationProgress(
                            stage: .planningPacket,
                            detail: "The on-device model rejected the packet for context size. Retrying with \(plan.mode.displayName) without truncating reviewed text.",
                            canCancel: true
                        )
                    )
                }
            }
        } catch is CancellationError {
            throw DraftFailure.cancelled
        } catch let error as GradeDraftError {
            throw error
        } catch {
            throw FoundationModelErrorMapper.map(error)
        }
    }

    func rewriteFeedback(input: FeedbackRewriteInput, progress: AIGenerationProgressHandler? = nil) async throws -> FeedbackRewriteResult {
        do {
            await progress?(
                AIGenerationProgress(
                    stage: .rewritingFeedback,
                    detail: "Rewriting feedback with the on-device model for teacher review.",
                    canCancel: true
                )
            )
            try requireAvailableModel()
            try Task.checkCancellation()
            let draft = try await generator.respond(
                FoundationModelGradeProposalSchema.FeedbackRewriteDraft.self,
                instructions: PromptBuilder.gradingInstructionsText(),
                prompt: PromptBuilder.feedbackRewritePromptText(input: input),
                options: SystemModelDraftGenerator.options
            )
            try Task.checkCancellation()
            return try FeedbackRewriteValidator.validate(draft.asFeedbackRewriteResult(), input: input)
        } catch is CancellationError {
            throw DraftFailure.cancelled
        } catch let error as GradeDraftError {
            throw error
        } catch {
            throw FoundationModelErrorMapper.map(error)
        }
    }

    private func requireAvailableModel() throws {
        if case .unavailable(let message) = localAIStatus {
            throw GradeDraftError.localModelUnavailable(message)
        }
    }

    private func generateDraft(
        input: GradingInput,
        plan: PromptBudgetPlan,
        progress: AIGenerationProgressHandler?
    ) async throws -> GradeDraftResult {
        switch plan.mode {
        case .fullPacket, .compactFullPacket:
            return try await generateFullPacketDraft(input: input, plan: plan, progress: progress)
        case .perCriterion:
            return try await generatePerCriterionDraft(input: input, plan: plan, progress: progress)
        case .unavailable:
            throw GradeDraftError.localModelUnavailable("The on-device language model is unavailable.")
        }
    }

    private func generateFullPacketDraft(
        input: GradingInput,
        plan: PromptBudgetPlan,
        progress: AIGenerationProgressHandler?
    ) async throws -> GradeDraftResult {
        let mode: PromptPacketMode = plan.mode == .compactFullPacket ? .compact : .full
        let prompt = PromptBuilder.fullPacketPromptText(input: input, mode: mode)
        await progress?(
            AIGenerationProgress(
                stage: .requestingModel,
                detail: "Drafting criterion suggestions with the on-device model.",
                completedUnitCount: 0,
                totalUnitCount: 1,
                canCancel: true
            )
        )
        let proposal: ModelDraftProposal
        if input.parsedRubric.criteria.isEmpty {
            proposal = try await draftShowingPartials(
                FoundationModelGradeProposalSchema.UnstructuredGradeDraftProposal.self,
                prompt: prompt,
                progress: progress,
                completedUnits: 0,
                totalUnits: 1,
                partialRows: { $0.partialCriteria }
            ).proposal
        } else {
            proposal = try await draftShowingPartials(
                FoundationModelGradeProposalSchema.GradeDraftProposal.self,
                prompt: prompt,
                progress: progress,
                completedUnits: 0,
                totalUnits: 1,
                partialRows: { $0.partialCriteria }
            ).proposal
        }
        try Task.checkCancellation()
        await progress?(
            AIGenerationProgress(
                stage: .validatingDraft,
                detail: "Checking the draft against the rubric, evidence, and safety rules.",
                completedUnitCount: 1,
                totalUnitCount: 1,
                canCancel: true
            )
        )
        let audit = Self.audit(input: input, plan: plan, generatedCriteriaCount: proposal.criteria.count)
        return try GradeDraftValidator.validate(proposal, input: input, audit: audit)
    }

    /// Criterion by criterion is used only with point-bearing rubric criteria; without them a packet that is too
    /// large cannot be split and fails with the too-large message.
    private func generatePerCriterionDraft(
        input: GradingInput,
        plan: PromptBudgetPlan,
        progress: AIGenerationProgressHandler?
    ) async throws -> GradeDraftResult {
        let rubricCriteria = input.parsedRubric.criteria
        guard !rubricCriteria.isEmpty else {
            throw DraftFailure.contextTooLarge
        }

        var criteria: [ModelCriterionProposal] = []
        var finished: [PartialCriterion] = []
        let totalCriteria = rubricCriteria.count
        for (index, rubricCriterion) in rubricCriteria.enumerated() {
            await progress?(
                AIGenerationProgress(
                    stage: .generatingCriteria,
                    detail: "Drafting criterion \(index + 1) of \(totalCriteria): \(rubricCriterion.title).",
                    completedUnitCount: index,
                    totalUnitCount: totalCriteria,
                    canCancel: true
                )
            )
            try Task.checkCancellation()
            let earlierRows = finished
            let criterionID = rubricCriterion.id
            let single = try await draftShowingPartials(
                FoundationModelGradeProposalSchema.SingleCriterionDraft.self,
                prompt: PromptBuilder.singleCriterionPromptText(input: input, criterion: rubricCriterion, mode: .compact),
                progress: progress,
                completedUnits: index,
                totalUnits: totalCriteria,
                partialRows: { partial in
                    earlierRows + (partial.criterion?.partialCriterion(knownCriterionID: criterionID).map { [$0] } ?? [])
                }
            )
            try Task.checkCancellation()
            let proposal = single.criterion.proposal(knownCriterionID: criterionID)
            criteria.append(proposal)
            finished.append(PartialCriterion(
                criterionID: criterionID,
                rating: proposal.rating,
                proposedPoints: proposal.proposedPoints,
                explanation: proposal.explanation
            ))
        }

        try Task.checkCancellation()
        let summary = try await summaryFeedback(input: input, criteria: criteria, progress: progress)
        try Task.checkCancellation()
        await progress?(
            AIGenerationProgress(
                stage: .validatingDraft,
                detail: "Checking the criterion suggestions against the rubric, evidence, and safety rules.",
                completedUnitCount: totalCriteria,
                totalUnitCount: totalCriteria,
                canCancel: true
            )
        )
        let extraWarnings = summary.generatedByModel ? [] : ["Student feedback summary was written without a model request because the packet was too large for a summary request."]
        let audit = Self.audit(input: input, plan: plan, generatedCriteriaCount: criteria.count, extraWarnings: extraWarnings)
        let proposal = ModelDraftProposal(
            studentResponseSummary: summary.studentResponseSummary,
            criteria: criteria,
            studentFeedback: summary.studentFeedback,
            teacherNotes: summary.teacherNotes,
            uncertaintyFlags: summary.uncertaintyFlags + ["Generated criterion-by-criterion because the full grading packet was too large for one on-device model request."],
            complianceFlags: summary.complianceFlags
        )
        return try GradeDraftValidator.validate(proposal, input: input, audit: audit)
    }

    /// Runs one streamed request and passes each partial value to the AI Draft screen as
    /// "Draft in progress — not saved" rows, in order. Returns the complete value from the model.
    private func draftShowingPartials<T: Generable>(
        _ type: T.Type,
        prompt: String,
        progress: AIGenerationProgressHandler?,
        completedUnits: Int,
        totalUnits: Int,
        partialRows: @escaping @Sendable (T.PartiallyGenerated) -> [PartialCriterion]
    ) async throws -> T {
        let (rows, rowSink) = AsyncStream<[PartialCriterion]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let relay = Task {
            for await current in rows {
                await progress?(
                    AIGenerationProgress(
                        stage: .partial(current),
                        detail: "Draft in progress — not saved.",
                        completedUnitCount: completedUnits,
                        totalUnitCount: totalUnits,
                        canCancel: true
                    )
                )
            }
        }
        do {
            let result = try await generator.draft(
                type,
                instructions: PromptBuilder.gradingInstructionsText(),
                prompt: prompt,
                options: SystemModelDraftGenerator.options,
                onPartial: { partial in rowSink.yield(partialRows(partial)) }
            )
            rowSink.finish()
            await relay.value
            return result
        } catch {
            rowSink.finish()
            relay.cancel()
            throw error
        }
    }

    private func summaryFeedback(
        input: GradingInput,
        criteria: [ModelCriterionProposal],
        progress: AIGenerationProgressHandler?
    ) async throws -> SummaryFeedbackResult {
        guard try await budgeter.summaryFits(input: input, criteria: criteria) else {
            return SummaryFeedbackResult.withoutModel(criteria: criteria, rubric: input.parsedRubric)
        }
        await progress?(
            AIGenerationProgress(
                stage: .synthesizingSummary,
                detail: "Writing the summary feedback with the on-device model.",
                canCancel: true
            )
        )
        try Task.checkCancellation()
        let summary = try await generator.respond(
            FoundationModelGradeProposalSchema.DraftSummaryFeedback.self,
            instructions: PromptBuilder.gradingInstructionsText(),
            prompt: PromptBuilder.summaryFeedbackPromptText(input: input, criteria: criteria),
            options: SystemModelDraftGenerator.options
        )
        return SummaryFeedbackResult(
            studentResponseSummary: summary.studentResponseSummary,
            studentFeedback: summary.studentFeedback,
            teacherNotes: summary.teacherNotes,
            uncertaintyFlags: summary.uncertaintyFlags,
            complianceFlags: summary.complianceFlags,
            generatedByModel: true
        )
    }

    private static func audit(
        input: GradingInput,
        plan: PromptBudgetPlan,
        generatedCriteriaCount: Int,
        extraWarnings: [String] = []
    ) -> LocalModelDraftAudit {
        LocalModelDraftAudit.make(
            input: input,
            plan: plan,
            generatedCriteriaCount: generatedCriteriaCount,
            sampling: SystemModelDraftGenerator.samplingDescription,
            extraWarnings: extraWarnings
        )
    }

    private static func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled. Enable it in Settings to use local AI grading."
        case .deviceNotEligible:
            return "This device does not support the on-device language model required for local AI grading."
        case .modelNotReady:
            return "The on-device language model is not ready yet. Try again after the system finishes preparing it."
        @unknown default:
            return "The on-device language model is unavailable for an unknown reason."
        }
    }

    private struct SummaryFeedbackResult {
        var studentResponseSummary: String
        var studentFeedback: String
        var teacherNotes: String
        var uncertaintyFlags: [String]
        var complianceFlags: [String]
        var generatedByModel: Bool

        static func withoutModel(criteria: [ModelCriterionProposal], rubric: ParsedRubric) -> SummaryFeedbackResult {
            let reviewRequired = criteria.filter(\.teacherReviewRequired).compactMap { score in
                rubric.criteria.first { $0.id == score.criterionID }?.title
            }
            let status = reviewRequired.isEmpty
                ? "Review the criterion evidence, edit feedback, and approve only after confirming the draft against the full student response and rubric."
                : "Review required for: \(reviewRequired.joined(separator: ", "))."
            return SummaryFeedbackResult(
                studentResponseSummary: "Draft generated criterion-by-criterion from reviewed text and teacher-supplied grading materials.",
                studentFeedback: "Draft generated criterion-by-criterion. Review the criterion evidence, edit feedback, and approve only after confirming the draft against the full student response and rubric.",
                teacherNotes: "\(status) The summary was assembled without an additional model request because the grading packet was too large for a summary request.",
                uncertaintyFlags: ["Criterion-by-criterion generation requires careful teacher synthesis before approval."],
                complianceFlags: ["No reviewed student text was truncated for local model generation."],
                generatedByModel: false
            )
        }
    }
}
