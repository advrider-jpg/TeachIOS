import SwiftUI

/// AI readiness, the packet preview and local drafting for one student, on one screen. Readiness and the
/// model prewarm run only while this screen is open, and again whenever the grading inputs change.
struct AIDraftScreen: View {
    @Bindable var session: SubmissionSession

    var body: some View {
        List {
            if let graph = session.graph, let setup = session.setup {
                localAISection
                readinessSection
                if let preview = session.packetPreview {
                    packetPreviewSection(preview)
                }
                draftActionSection
                failureSection
                if !session.partialCriteria.isEmpty {
                    partialDraftSection(setup)
                }
                savedDraftSections(graph: graph, setup: setup)
            }
        }
        .navigationTitle("AI Draft")
        .navigationBarTitleDisplayMode(.inline)
        .alertMessage($session.alert)
        .task(id: session.packetFingerprint) {
            await session.prepareAIDraft()
        }
    }

    // MARK: - Readiness

    @ViewBuilder
    private var localAISection: some View {
        if case .unavailable(let message) = session.localAIStatus {
            Section {
                ContentUnavailableView {
                    Label("On-device AI unavailable", systemImage: "cpu")
                } description: {
                    Text("\(message) Manual final review is still available.")
                } actions: {
                    NavigationLink(value: Route.finalReview(session.id)) {
                        Text("Open Final Review")
                    }
                    .accessibilityIdentifier("aiDraft.openFinalReviewUnavailable")
                }
            }
        }
    }

    private var readinessSection: some View {
        Section {
            if let report = session.aiReadiness {
                Label(report.localAIStatusSummary, systemImage: report.canGenerate ? "checkmark.shield" : "exclamationmark.triangle")
                    .foregroundStyle(report.canGenerate ? Color.green : Color.orange)
                Text(report.recommendedNextAction)
                    .foregroundStyle(.secondary)
                ForEach(report.checks) { check in
                    Label {
                        Text(check.title)
                        Text(check.detail)
                    } icon: {
                        Image(systemName: icon(for: check.status))
                            .foregroundStyle(color(for: check.status))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(statusName(check.status))
                }
                if !report.promptInjectionRisks.isEmpty {
                    Label {
                        Text("Review these fields before drafting: \(report.promptInjectionRisks.joined(separator: ", ")).")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                LabeledContent("Personal details", value: report.piiRedactionSummary)
                LabeledContent("Packet size", value: report.tokenEstimateSummary)
            } else if session.localAIStatus == .available {
                Label {
                    Text("Checking the grading packet…")
                } icon: {
                    ProgressView()
                }
            }
            if sensitiveConstraintsSelected {
                Label("A sensitive grading constraint is selected. Check that the teacher-provided context exists in the grading materials.", systemImage: "lock")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Readiness")
        }
    }

    private func packetPreviewSection(_ preview: AIPacketPreview) -> some View {
        Section {
            DisclosureGroup("Packet Preview") {
                packetList("Included in local draft", items: preview.includedInLocalDraft, systemImage: "checkmark.circle")
                packetList("Not sent to the model", items: preview.notSentToModel, systemImage: "eye.slash")
                packetList("Generation plan", items: preview.generationPlan, systemImage: "slider.horizontal.3")
                DisclosureGroup("Technical details") {
                    LabeledContent("Prompt version", value: preview.promptVersion)
                    LabeledContent("Prompt fingerprint", value: preview.promptFingerprint)
                    LabeledContent("Packet fingerprint", value: preview.packetFingerprint)
                    ForEach(preview.modelVisibleMetadata, id: \.self) { item in
                        Label(item, systemImage: "number")
                    }
                    Text(preview.technicalPromptPreview)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                .accessibilityIdentifier("aiDraft.technicalDetails")
            }
            .accessibilityIdentifier("aiDraft.packetPreview")
        } footer: {
            Text("This is exactly what the on-device model would read. Nothing leaves this device.")
        }
    }

    @ViewBuilder
    private func packetList(_ title: String, items: [String], systemImage: String) -> some View {
        if !items.isEmpty {
            Text(title)
                .font(.headline)
            ForEach(items, id: \.self) { item in
                Label(item, systemImage: systemImage)
            }
        }
    }

    // MARK: - Drafting

    private var draftActionSection: some View {
        Section {
            if session.runningWork == .draft {
                let progress = session.generationProgress
                Label {
                    Text(progressTitle(progress.stage))
                    Text(progress.detail)
                } icon: {
                    ProgressView()
                }
                if let fraction = progress.fractionCompleted {
                    ProgressView(value: fraction)
                        .accessibilityLabel("Draft progress")
                }
                Button(role: .cancel) {
                    session.cancelDraft()
                } label: {
                    Label("Cancel Local Draft", systemImage: "xmark.circle")
                }
                .disabled(progress.stage == .cancellationRequested)
                .accessibilityIdentifier("aiDraft.cancel")
            } else {
                Button {
                    session.startDraft()
                } label: {
                    Label("Draft Feedback Suggestion Locally", systemImage: "sparkles")
                }
                .disabled(session.readiness?.canDraft != true)
                .accessibilityIdentifier("aiDraft.draft")
                ForEach(session.readiness?.draftIssues ?? [], id: \.self) { issue in
                    Label(issue.message, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("MarkForMe drafts suggestions only. The teacher approves the final grade. Drafting keeps running if you leave this screen.")
        }
    }

    @ViewBuilder
    private var failureSection: some View {
        if let failure = session.workFailure {
            Section {
                Label {
                    Text(failure.title)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                Text(failure.message)
                Button("Dismiss") { session.dismissWorkFailure() }
                    .accessibilityIdentifier("aiDraft.dismissFailure")
            }
        }
    }

    private func partialDraftSection(_ setup: AssignmentSetup) -> some View {
        Section {
            ForEach(session.partialCriteria, id: \.criterionID) { criterion in
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent(
                        setup.displayTitle(criterionID: criterion.criterionID, ownTitle: nil),
                        value: criterion.proposedPoints.map { points in
                            pointsText(points, maximum: setup.maximumPoints(criterionID: criterion.criterionID, ownMaximum: nil))
                        } ?? "Writing…"
                    )
                    if let rating = criterion.rating, !rating.isWhitespaceOnly {
                        Text(rating)
                            .foregroundStyle(.secondary)
                    }
                    if let explanation = criterion.explanation, !explanation.isWhitespaceOnly {
                        Text(explanation)
                    }
                }
            }
        } header: {
            Text("Draft in progress — not saved")
        } footer: {
            Text(session.runningWork == .draft
                 ? "These rows are what the model has written so far. They are checked and saved only when drafting finishes."
                 : "This draft did not finish and was not saved.")
        }
    }

    // MARK: - Saved draft

    @ViewBuilder
    private func savedDraftSections(graph: SubmissionGraph, setup: AssignmentSetup) -> some View {
        if let draft = graph.draft {
            Section {
                LabeledContent("Suggested score", value: pointsText(draft.totalScore, maximum: setup.parsedRubric.isStructured ? setup.parsedRubric.totalMaxPoints : nil))
                if session.readiness?.draftIsStale == true {
                    StatusLabel(.needsRecheck, subject: "Draft status")
                } else if draft.status == .teacherReviewRequired {
                    StatusLabel(.needsAttention, subject: "Draft status")
                } else {
                    StatusLabel(.reviewFinalGrade, subject: "Draft status")
                }
                LabeledContent("Drafted", value: draft.generatedAt.formatted(date: .abbreviated, time: .shortened))
                if !draft.studentResponseSummary.isWhitespaceOnly {
                    Text(draft.studentResponseSummary)
                        .foregroundStyle(.secondary)
                }
                ForEach(draft.uncertaintyFlags, id: \.self) { flag in
                    Label {
                        Text(flag)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                NavigationLink(value: Route.finalReview(session.id)) {
                    Label("Open Final Review", systemImage: "checklist")
                }
                .accessibilityIdentifier("aiDraft.openFinalReview")
            } header: {
                Text("Saved Draft")
            } footer: {
                Text("Review this suggestion and approve the final grade in Final Review before any student-facing export.")
            }

            ForEach(draft.criteria) { criterion in
                Section(setup.displayTitle(criterionID: criterion.criterionID, ownTitle: criterion.title)) {
                    LabeledContent(
                        "Suggested points",
                        value: pointsText(criterion.proposedPoints, maximum: setup.maximumPoints(criterionID: criterion.criterionID, ownMaximum: criterion.maxPoints))
                    )
                    if !criterion.rating.isWhitespaceOnly {
                        LabeledContent("Rating", value: criterion.rating)
                    }
                    if !criterion.confidence.isWhitespaceOnly {
                        LabeledContent("Confidence", value: criterion.confidence)
                    }
                    if criterion.teacherReviewRequired {
                        Label {
                            Text("Teacher review required for this criterion.")
                        } icon: {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                                .foregroundStyle(.orange)
                        }
                    }
                    ForEach(criterion.uncertaintyFlags, id: \.self) { flag in
                        Label {
                            Text(flag)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(criterion.explanation.isWhitespaceOnly ? "No explanation provided." : criterion.explanation)
                        .textSelection(.enabled)
                    if criterion.evidenceQuotes.isEmpty {
                        Label {
                            Text("No evidence cited — teacher review required.")
                        } icon: {
                            Image(systemName: "quote.bubble")
                                .foregroundStyle(.orange)
                        }
                    } else {
                        ForEach(criterion.evidenceQuotes, id: \.self) { quote in
                            Label("\u{201C}\(quote)\u{201D}", systemImage: "quote.opening")
                                .textSelection(.enabled)
                        }
                    }
                    if !criterion.nextStep.isWhitespaceOnly {
                        LabeledContent("Suggested next step", value: criterion.nextStep)
                    }
                }
            }

            Section("Suggested Student Feedback") {
                Text(draft.studentFeedback.isWhitespaceOnly ? "No feedback suggested." : draft.studentFeedback)
                    .textSelection(.enabled)
                ForEach(draft.complianceFlags, id: \.self) { flag in
                    Label(flag, systemImage: "checkmark.shield")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private var sensitiveConstraintsSelected: Bool {
        guard let setup = session.setup else { return false }
        return GradingConstraintTemplates.templates(for: setup.assignment.constraintTemplateIDs).contains(where: \.sensitiveContextRequired)
    }

    private func pointsText(_ points: Double, maximum: Double?) -> String {
        guard let maximum, maximum > 0 else { return GradeTotals.formatted(points) }
        return "\(GradeTotals.formatted(points)) / \(GradeTotals.formatted(maximum))"
    }

    private func icon(for status: AIReadinessStatus) -> String {
        switch status {
        case .ready: return "checkmark.circle"
        case .needsReview: return "exclamationmark.circle"
        case .blocked, .unavailable: return "xmark.octagon"
        case .info: return "info.circle"
        }
    }

    private func color(for status: AIReadinessStatus) -> Color {
        switch status {
        case .ready: return .green
        case .needsReview: return .orange
        case .blocked, .unavailable: return .red
        case .info: return .secondary
        }
    }

    private func statusName(_ status: AIReadinessStatus) -> String {
        switch status {
        case .ready: return "Ready"
        case .needsReview: return "Needs review"
        case .blocked: return "Blocked"
        case .unavailable: return "Unavailable"
        case .info: return "Information"
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func progressTitle(_ stage: AIGenerationStage) -> String {
        switch stage {
        case .idle: return "Local draft"
        case .validatingInputs: return "Checking inputs"
        case .checkingAvailability: return "Checking on-device AI"
        case .planningPacket: return "Planning packet"
        case .requestingModel: return "Drafting locally"
        case .generatingCriteria, .partial: return "Drafting criteria"
        case .synthesizingSummary: return "Writing summary"
        case .rewritingFeedback: return "Rewriting feedback"
        case .validatingDraft: return "Checking draft"
        case .storingDraft: return "Saving draft"
        case .cancellationRequested: return "Cancelling"
        case .cancelled: return "Cancelled"
        case .failed: return "Draft failed"
        case .completed: return "Draft saved"
        }
    }
}

#if DEBUG
#Preview("Light") {
    ScreenPreview { app in RouteDestination(route: .aiDraft(PreviewFixtures.approvedSubmissionID), app: app) }
}

#Preview("Dark") {
    ScreenPreview { app in RouteDestination(route: .aiDraft(PreviewFixtures.scannedSubmissionID), app: app) }
        .preferredColorScheme(.dark)
}

#Preview("Accessibility XXXL") {
    ScreenPreview { app in RouteDestination(route: .aiDraft(PreviewFixtures.approvedSubmissionID), app: app) }
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
