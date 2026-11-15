import SwiftUI

/// The teacher's final review of one student's grade. Every edit is saved automatically (0.6 s after the
/// last change, and at once when the screen closes or the app goes to the background); approval is the
/// only explicit step.
struct FinalReviewScreen: View {
    @Bindable var session: SubmissionSession

    @Environment(AppModel.self) private var appModel
    @Environment(\.appTab) private var appTab

    @State private var showingApproveConfirm = false
    @State private var pendingRestart: RestartKind?
    @State private var newEvidence: [UUID: String] = [:]

    private enum RestartKind: String, Identifiable {
        case fromDraft
        case manual
        var id: String { rawValue }
    }

    var body: some View {
        List {
            if let graph = session.graph, let setup = session.setup {
                summarySection(graph: graph, setup: setup)
                failureSection
                if let review = session.review {
                    ForEach(Array(review.criteria.enumerated()), id: \.element.id) { index, criterion in
                        criterionSection(criterion, index: index, graph: graph, setup: setup)
                    }
                    Section {
                        Button {
                            session.addCriterion()
                        } label: {
                            Label("Add Criterion", systemImage: "plus.circle")
                        }
                        .accessibilityIdentifier("finalReview.addCriterion")
                    }
                    feedbackSection(review)
                    notesSection
                    approvalSection
                    restartSection
                } else {
                    startSection(graph: graph, setup: setup)
                }
            }
        }
        .navigationTitle("Final Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let nextID = session.nextSubmissionID {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        appModel.replaceLast(in: appTab, with: .finalReview(nextID))
                    } label: {
                        Label("Next Student", systemImage: "arrow.right.circle")
                    }
                    .accessibilityIdentifier("finalReview.nextStudent")
                }
            }
        }
        .alertMessage($session.alert)
        .confirmationDialog("Approve Final Grade", isPresented: $showingApproveConfirm, titleVisibility: .visible) {
            Button("Approve Final Grade") {
                Task { await session.approveFinalReview() }
            }
            .accessibilityIdentifier("finalReview.approveConfirm")
            Button("Keep Reviewing", role: .cancel) {}
        } message: {
            Text("Approve this as the final grade? The AI suggestion stays in teacher-only review history; the final score and feedback reflect your reviewed edits.")
        }
        .confirmationDialog(
            "Replace this final review?",
            isPresented: Binding(get: { pendingRestart != nil }, set: { if !$0 { pendingRestart = nil } }),
            titleVisibility: .visible,
            presenting: pendingRestart
        ) { kind in
            Button(kind == .fromDraft ? "Replace with AI Draft" : "Replace with Blank Review", role: .destructive) {
                Task {
                    switch kind {
                    case .fromDraft: await session.startFinalReviewFromDraft()
                    case .manual: await session.startManualFinalReview()
                    }
                }
            }
            .accessibilityIdentifier("finalReview.restartConfirm")
            Button("Keep Current Review", role: .cancel) {}
        } message: { _ in
            Text("Your current scores, evidence links and feedback for this student will be replaced.")
        }
    }

    // MARK: - Summary

    private func summarySection(graph: SubmissionGraph, setup: AssignmentSetup) -> some View {
        let readiness = session.readiness
        return Section {
            LabeledContent("Student", value: graph.student.displayName)
            LabeledContent("Assignment", value: setup.assignment.title)
            if let review = session.review {
                LabeledContent("Final score", value: pointsText(review.totalScore, maximum: totalMaximum(review, setup: setup)))
                LabeledContent("Criteria approved", value: "\(review.criteria.filter(\.teacherApproved).count) of \(review.criteria.count)")
                StatusLabel(approvalStatus(review), subject: "Approval status")
                LabeledContent("Student-facing export", value: readiness?.canExportStudentReport == true ? "Ready" : "Blocked")
                if readiness?.finalReviewIsStale == true {
                    Label {
                        Text(ReadinessIssue.finalReviewStale.message)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                Text(session.reviewAutosave.holdsLocalEdits ? "Saving changes…" : "Changes are saved automatically.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("finalReview.saveStatus")
            } else {
                StatusLabel(.reviewFinalGrade, subject: "Approval status")
            }
        } footer: {
            Text("MarkForMe drafts suggestions only. The teacher approves the final grade.")
        }
    }

    @ViewBuilder
    private var failureSection: some View {
        if let kind = session.runningWork {
            Section {
                Label {
                    Text(kind.displayName)
                } icon: {
                    ProgressView()
                }
            }
        }
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
                    .accessibilityIdentifier("finalReview.dismissFailure")
            }
        }
    }

    // MARK: - Starting a review

    private func startSection(graph: SubmissionGraph, setup: AssignmentSetup) -> some View {
        let readiness = session.readiness
        let manualIssues = readiness?.finalReviewStartIssues ?? []
        let draftOnlyIssues = (readiness?.draftReviewStartIssues ?? []).filter { !manualIssues.contains($0) }
        return Section {
            if let draft = graph.draft {
                LabeledContent(
                    "AI draft",
                    value: "\(pointsText(draft.totalScore, maximum: setup.parsedRubric.isStructured ? setup.parsedRubric.totalMaxPoints : nil)) suggested"
                )
                if readiness?.draftIsStale == true {
                    StatusLabel(.needsRecheck, subject: "Draft status")
                }
            }
            Button {
                Task { await session.startFinalReviewFromDraft() }
            } label: {
                Label("Start Final Review from AI Draft", systemImage: "checklist")
            }
            .disabled(readiness?.canStartFinalReviewFromDraft != true)
            .accessibilityIdentifier("finalReview.startFromDraft")
            Button {
                Task { await session.startManualFinalReview() }
            } label: {
                Label("Start Manual Final Review", systemImage: "pencil.and.list.clipboard")
            }
            .disabled(readiness?.canStartFinalReview != true)
            .accessibilityIdentifier("finalReview.startManual")
            ForEach(manualIssues + draftOnlyIssues, id: \.self) { issue in
                Label(issue.message, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
            NavigationLink(value: Route.aiDraft(session.id)) {
                Label("Open AI Draft", systemImage: "sparkles")
            }
            .accessibilityIdentifier("finalReview.openAIDraft")
        } header: {
            Text("Start Final Review")
        }
    }

    // MARK: - Criteria

    private func criterionSection(_ criterion: FinalCriterionScore, index: Int, graph: SubmissionGraph, setup: AssignmentSetup) -> some View {
        let maximum = setup.maximumPoints(criterionID: criterion.criterionID, ownMaximum: criterion.maxPoints)
        let hasRubricRow = setup.parsedRubric.criterion(id: criterion.criterionID) != nil
        let evidence = criterion.evidenceIDs.compactMap { id in graph.evidence.first { $0.id == id } }
        return Section {
            StatusLabel(criterion.teacherApproved ? .approved : .reviewFinalGrade, subject: "Criterion status")
            if graph.draft != nil {
                LabeledContent("AI suggestion", value: pointsText(criterion.proposedPoints, maximum: maximum))
            }
            HStack {
                Button("Accept Suggestion") { session.acceptCriterion(criterion.id) }
                    .accessibilityIdentifier("finalReview.accept.\(index)")
                Button("Reject Suggestion", role: .destructive) { session.rejectCriterion(criterion.id) }
                    .accessibilityIdentifier("finalReview.reject.\(index)")
            }
            .buttonStyle(.bordered)
            Stepper(
                value: Binding(get: { criterion.finalPoints }, set: { session.setFinalPoints($0, for: criterion.id) }),
                in: 0...upperBound(maximum),
                step: 0.5
            ) {
                LabeledContent("Final points", value: pointsText(criterion.finalPoints, maximum: maximum))
            }
            .accessibilityIdentifier("finalReview.points.\(index)")
            if !hasRubricRow {
                TextField("Criterion title", text: session.criterionTitle(criterion.id))
                    .accessibilityIdentifier("finalReview.criterionTitle.\(index)")
                Stepper(
                    value: Binding(get: { criterion.maxPoints ?? 0 }, set: { session.setMaximumPoints($0, for: criterion.id) }),
                    in: 0...1000,
                    step: 1
                ) {
                    LabeledContent("Maximum points", value: GradeTotals.formatted(criterion.maxPoints ?? 0))
                }
                .accessibilityIdentifier("finalReview.maximum.\(index)")
            }
            TextField("Rating (optional, e.g. Proficient)", text: session.criterionText(criterion.id, \.rating), axis: .vertical)
                .accessibilityIdentifier("finalReview.rating.\(index)")
            TextField("Explanation", text: session.criterionText(criterion.id, \.explanation), axis: .vertical)
                .accessibilityIdentifier("finalReview.explanation.\(index)")
            TextField("Teacher rationale (teacher-only)", text: session.criterionText(criterion.id, \.teacherRationale), axis: .vertical)
                .accessibilityIdentifier("finalReview.rationale.\(index)")

            if evidence.isEmpty {
                Text("No evidence cited. Add a quote from the reviewed student text.")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(evidence.enumerated()), id: \.element.id) { evidenceIndex, item in
                evidenceRow(item)
                    .swipeActions {
                        Button("Remove", role: .destructive) {
                            Task { await session.removeEvidence(item.id, from: criterion.id) }
                        }
                        .accessibilityIdentifier("finalReview.removeEvidence.\(index).\(evidenceIndex)")
                    }
            }
            HStack {
                TextField("Quote from the student's work", text: evidenceText(for: criterion.id), axis: .vertical)
                    .accessibilityIdentifier("finalReview.newEvidence.\(index)")
                Button("Add") {
                    let quote = newEvidence[criterion.id] ?? ""
                    newEvidence[criterion.id] = nil
                    Task { await session.addManualEvidence(quote: quote, to: criterion.id) }
                }
                .buttonStyle(.borderless)
                .disabled((newEvidence[criterion.id] ?? "").isWhitespaceOnly)
                .accessibilityIdentifier("finalReview.addEvidence.\(index)")
            }
            if let lines = graph.ocr?.activeLines.filter({ !$0.reviewedText.isWhitespaceOnly }), !lines.isEmpty {
                Menu {
                    ForEach(lines) { line in
                        Button(line.reviewedText) {
                            Task { await session.addLineEvidence(lineID: line.id, to: criterion.id) }
                        }
                    }
                } label: {
                    Label("Add Scanned Line as Evidence", systemImage: "text.quote")
                }
                .accessibilityIdentifier("finalReview.addLineEvidence.\(index)")
            }
            Button(role: .destructive) {
                session.deleteCriterion(criterion.id)
            } label: {
                Label("Delete Criterion", systemImage: "trash")
            }
            .accessibilityIdentifier("finalReview.deleteCriterion.\(index)")
        } header: {
            Text(setup.displayTitle(
                criterionID: criterion.criterionID,
                ownTitle: criterion.title?.isWhitespaceOnly == false ? criterion.title : nil
            ))
        }
    }

    private func evidenceRow(_ evidence: EvidenceReference) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\u{201C}\(evidence.quote)\u{201D}")
                .textSelection(.enabled)
            Text(evidenceSource(evidence))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func evidenceSource(_ evidence: EvidenceReference) -> String {
        switch evidence.sourceKind {
        case .ocrLine:
            return evidence.pageIndex.map { "Scanned text, page \($0 + 1)" } ?? "Scanned text"
        case .manualTeacherEntry:
            return "Added by the teacher"
        }
    }

    // MARK: - Feedback, notes and approval

    private func feedbackSection(_ review: FinalGradeReview) -> some View {
        Section {
            StatusLabel(.studentFacing, subject: "Audience")
            TextField("Student feedback", text: session.reviewText(\.studentFeedback), axis: .vertical)
                .accessibilityIdentifier("finalReview.studentFeedback")
            if review.status != .approved, session.localAIStatus == .available {
                Menu {
                    ForEach(FeedbackRewriteMode.allCases) { mode in
                        Button(mode.displayName) {
                            Task { await session.rewriteFeedback(mode: mode) }
                        }
                    }
                } label: {
                    Label("Rewrite Feedback Locally", systemImage: "sparkles")
                }
                .disabled(session.runningWork != nil)
                .accessibilityIdentifier("finalReview.rewriteFeedback")
            }
        } header: {
            Text("Student Feedback")
        } footer: {
            Text("Visible to the student. Keep it constructive and evidence-linked. Rewrites run on this device and do not change scores or evidence.")
        }
    }

    private var notesSection: some View {
        Section {
            StatusLabel(.teacherOnly, subject: "Audience")
            TextField("Private teacher note", text: session.reviewText(\.privateTeacherNotes), axis: .vertical)
                .accessibilityIdentifier("finalReview.privateNotes")
        } header: {
            Text("Private Teacher Note")
        } footer: {
            Text("Not visible to the student. Included only in teacher-only records.")
        }
    }

    private var approvalSection: some View {
        let readiness = session.readiness
        return Section {
            ForEach(readiness?.approvalIssues ?? [], id: \.self) { issue in
                Label(issue.message, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
            Button {
                showingApproveConfirm = true
            } label: {
                Label("Approve Final Grade", systemImage: "checkmark.seal")
            }
            .disabled(readiness?.canApproveFinalReview != true)
            .accessibilityIdentifier("finalReview.approve")
            NavigationLink(value: Route.submissionExports(session.id)) {
                Label("Exports", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("finalReview.exports")
        } header: {
            Text("Teacher Approval")
        } footer: {
            Text(ReadinessIssue.finalReviewNotApproved.message)
        }
    }

    private var restartSection: some View {
        Section {
            Button {
                pendingRestart = .fromDraft
            } label: {
                Label("Restart from AI Draft", systemImage: "arrow.counterclockwise")
            }
            .disabled(session.readiness?.canStartFinalReviewFromDraft != true)
            .accessibilityIdentifier("finalReview.restartFromDraft")
            Button {
                pendingRestart = .manual
            } label: {
                Label("Restart Manual Review", systemImage: "arrow.counterclockwise")
            }
            .disabled(session.readiness?.canStartFinalReview != true)
            .accessibilityIdentifier("finalReview.restartManual")
        } footer: {
            Text("Use this when the student work or rubric changed and this review needs to start again.")
        }
    }

    // MARK: - Helpers

    private func approvalStatus(_ review: FinalGradeReview) -> GradeDraftUIStatus {
        if session.readiness?.finalReviewIsStale == true { return .needsRecheck }
        return review.status == .approved ? .approved : .inProgress
    }

    private func totalMaximum(_ review: FinalGradeReview, setup: AssignmentSetup) -> Double? {
        let maxima = review.criteria.compactMap { setup.maximumPoints(criterionID: $0.criterionID, ownMaximum: $0.maxPoints) }
        let total = maxima.reduce(0, +)
        return total > 0 ? total : nil
    }

    private func upperBound(_ maximum: Double?) -> Double {
        guard let maximum, maximum > 0 else { return 1000 }
        return maximum
    }

    private func pointsText(_ points: Double, maximum: Double?) -> String {
        guard let maximum, maximum > 0 else { return GradeTotals.formatted(points) }
        return "\(GradeTotals.formatted(points)) / \(GradeTotals.formatted(maximum))"
    }

    private func evidenceText(for criterionID: UUID) -> Binding<String> {
        Binding(
            get: { newEvidence[criterionID] ?? "" },
            set: { newEvidence[criterionID] = $0 }
        )
    }
}

#if DEBUG
#Preview("Light") {
    ScreenPreview { app in RouteDestination(route: .finalReview(PreviewFixtures.approvedSubmissionID), app: app) }
}

#Preview("Dark") {
    ScreenPreview { app in RouteDestination(route: .finalReview(PreviewFixtures.approvedSubmissionID), app: app) }
        .preferredColorScheme(.dark)
}

#Preview("Accessibility XXXL") {
    ScreenPreview { app in RouteDestination(route: .finalReview(PreviewFixtures.scannedSubmissionID), app: app) }
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
