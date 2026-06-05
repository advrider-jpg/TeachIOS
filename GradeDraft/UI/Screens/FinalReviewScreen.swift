import SwiftUI

struct FinalReviewScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var assignmentID: UUID
    @State private var gradingTarget: GradingTarget?
    @State private var sourceReviewTarget: SourceReviewTarget?

    private struct GradingTarget: Identifiable { let id: UUID }
    private struct SourceReviewTarget: Identifiable { let id: UUID }

    var body: some View {
        Form {
            if let assignment = viewModel.assignment(for: assignmentID) {
                Section {
                    FinalReviewPaperHeader(
                        assignmentTitle: assignment.title,
                        studentName: assignment.studentDisplayName,
                        status: assignment.finalReview?.status.v6Status ?? viewModel.v6Status(for: assignment),
                        scoreText: finalReviewScoreText(for: assignment),
                        exportReady: assignment.isStudentFacingExportReady
                    )
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if assignment.finalReviewIsStale {
                    Section {
                        FinalReviewPaperCard(status: .needsRecheck, tape: "recheck") {
                            WarningBanner(
                                title: "This review needs rechecking.",
                                message: "Student work, rubric, or evidence changed after this review was last saved.",
                                status: .needsRecheck
                            )
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    FinalReviewPaperCard(status: .reviewFinalGrade, tape: "review actions") {
                        VStack(alignment: .leading, spacing: 12) {
                            if let report = aiReadinessReport(for: assignment) {
                                AIReadinessSummaryView(report: report)
                            }

                            SecondaryActionButton(
                                title: "Prepare Packet Preview",
                                systemImage: "doc.text.magnifyingglass",
                                action: {
                                    viewModel.selectAssignment(assignmentID)
                                    viewModel.buildAIPacketPreview()
                                },
                                disabled: viewModel.isWorking
                            )

                            if let preview = aiPacketPreview(for: assignment) {
                                AIPacketPreviewSummaryView(preview: preview)
                            }

                            PrimaryActionButton(
                                title: viewModel.isWorking ? "Drafting Locally" : "Draft Feedback Suggestion Locally",
                                systemImage: "sparkles",
                                action: {
                                    viewModel.selectAssignment(assignmentID)
                                    viewModel.confirmAndDraftGrade()
                                },
                                disabled: !canDraftGrade(for: assignment)
                            )

                            if viewModel.aiGenerationProgress.stage != .idle {
                                AIGenerationProgressView(
                                    progress: viewModel.aiGenerationProgress,
                                    canCancel: viewModel.canCancelDraftGeneration,
                                    onCancel: {
                                        viewModel.cancelDraftGeneration()
                                    }
                                )
                            }

                            ForEach(draftReadinessIssues(for: assignment), id: \.self) { issue in
                                FinalReviewNoteRow(issue)
                            }

                            SecondaryActionButton(
                                title: "Start Final Review",
                                systemImage: "checklist",
                                action: {
                                    viewModel.selectAssignment(assignmentID)
                                    viewModel.startFinalReviewFromLatestDraft()
                                },
                                disabled: !canStartFromLatestDraft(for: assignment)
                            )

                            if let issue = latestDraftIssue(for: assignment) {
                                FinalReviewNoteRow(issue)
                            }

                            SecondaryActionButton(
                                title: "Start Manual Final Review",
                                systemImage: "pencil.and.list.clipboard",
                                action: {
                                    viewModel.selectAssignment(assignmentID)
                                    viewModel.startManualFinalReview()
                                },
                                disabled: !canStartManualFinalReview(for: assignment)
                            )

                            if !canStartManualFinalReview(for: assignment) {
                                ForEach(manualGradingReadinessIssues(for: assignment), id: \.self) { issue in
                                    FinalReviewNoteRow(issue)
                                }
                            }
                        }
                    }
                } header: {
                    FinalReviewTapeSectionHeader(title: "Review Actions")
                } footer: {
                    Text("Mark My Work drafts suggestions only. The teacher approves the final grade.")
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section {
                    FinalReviewPaperCard(status: .teacherOnly, tape: "evidence") {
                        if assignment.evidenceReferences.isEmpty {
                            ContentUnavailableView(
                                "No evidence added",
                                systemImage: "quote.bubble",
                                description: Text("Add evidence from reviewed text during final review.")
                            )
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(assignment.evidenceReferences) { item in
                                    EvidenceSourceRow(evidence: item)
                                }
                            }
                        }
                    }
                } header: {
                    FinalReviewTapeSectionHeader(title: "Evidence")
                } footer: {
                    Text("Evidence remains linked to reviewed student work or teacher notes.")
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if let finalReview = assignment.finalReview {
                    Section {
                        FinalReviewPaperCard(status: finalReview.status.v6Status, tape: "teacher final") {
                            FinalGradeReviewView(
                                review: finalReview,
                                isStale: assignment.finalReviewIsStale,
                                onChange: {
                                    viewModel.selectAssignment(assignmentID)
                                    viewModel.updateFinalReview($0)
                                },
                                onApprove: {
                                    viewModel.selectAssignment(assignmentID)
                                    viewModel.approveFinalReview()
                                },
                                onAddCriterion: {
                                    viewModel.selectAssignment(assignmentID)
                                    viewModel.addCriterionToFinalReview()
                                },
                                onDeleteCriterion: {
                                    viewModel.selectAssignment(assignmentID)
                                    viewModel.deleteCriterionFromFinalReview(id: $0)
                                },
                                onAddManualEvidence: { criterionID, quote in
                                    viewModel.selectAssignment(assignmentID)
                                    viewModel.addManualEvidenceToFinalReview(criterionID: criterionID, quote: quote)
                                },
                                onRemoveEvidence: { criterionID, index in
                                    viewModel.selectAssignment(assignmentID)
                                    viewModel.removeEvidenceFromFinalReview(criterionID: criterionID, evidenceIndex: index)
                                },
                                onClearEvidence: { criterionID in
                                    viewModel.selectAssignment(assignmentID)
                                    viewModel.clearEvidenceFromFinalReview(criterionID: criterionID)
                                },
                                onAcceptCriterionSuggestion: { criterionID in
                                    viewModel.selectAssignment(assignmentID)
                                    viewModel.acceptFinalReviewCriterion(id: criterionID)
                                },
                                onRejectCriterionSuggestion: { criterionID in
                                    viewModel.selectAssignment(assignmentID)
                                    viewModel.rejectFinalReviewCriterion(id: criterionID)
                                },
                                onReviewEvidenceSources: {
                                    sourceReviewTarget = SourceReviewTarget(id: assignmentID)
                                },
                                onRewriteFeedback: { mode in
                                    viewModel.selectAssignment(assignmentID)
                                    Task {
                                        await viewModel.rewriteFinalReviewFeedback(mode: mode)
                                    }
                                }
                            )
                            .id(finalReview.id)
                        }
                    } header: {
                        FinalReviewTapeSectionHeader(title: "Criterion Review")
                    } footer: {
                        Text("Approve every criterion before treating the score as final.")
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else if let result = assignment.latestDraft {
                    Section {
                        FinalReviewPaperCard(status: result.status.v6Status, tape: "draft note") {
                            VStack(alignment: .leading, spacing: 12) {
                                LabeledContent("Suggested Score", value: "\(GradeTotals.formatted(result.totalScore)) / \(GradeTotals.formatted(result.maxScore))")
                                if assignment.latestDraftIsStale || result.status == .stale {
                                    Label("Needs recheck: student work, rubric, or evidence changed.", systemImage: "exclamationmark.triangle")
                                        .foregroundStyle(.orange)
                                }
                                Text(result.studentResponseSummary)
                                    .font(.system(.subheadline, design: .serif).italic())
                                    .foregroundStyle(.secondary)
                                if !result.uncertaintyFlags.isEmpty {
                                    DisclosureGroup("Needs Attention") {
                                        ForEach(result.uncertaintyFlags, id: \.self) { flag in
                                            Label(flag, systemImage: "exclamationmark.triangle")
                                                .font(.subheadline)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }
                                ForEach(result.criteria) { criterion in
                                    DraftCriterionReviewCard(
                                        criterion: criterion,
                                        onReviewSourceText: {
                                            sourceReviewTarget = SourceReviewTarget(id: assignmentID)
                                        },
                                        onStartFinalReview: {
                                            viewModel.selectAssignment(assignmentID)
                                            viewModel.startFinalReviewFromLatestDraft()
                                        }
                                    )
                                }
                                Text(result.studentFeedback.isEmpty ? "No feedback suggested." : result.studentFeedback)
                                    .textSelection(.enabled)
                                if !result.complianceFlags.isEmpty {
                                    DisclosureGroup("Review Notes") {
                                        ForEach(result.complianceFlags, id: \.self) { flag in
                                            Label(flag, systemImage: "checkmark.shield")
                                                .font(.subheadline)
                                        }
                                    }
                                }
                            }
                        }
                    } header: {
                        FinalReviewTapeSectionHeader(title: "Draft Suggestion")
                    } footer: {
                        Text("Review this suggestion and start final review before export.")
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    Section {
                        FinalReviewPaperCard(status: .reviewFinalGrade, tape: "final review") {
                            ContentUnavailableView(
                                "Review final grade",
                                systemImage: "checklist",
                                description: Text("Draft a feedback suggestion or start manual final review.")
                            )
                        }
                    } header: {
                        FinalReviewTapeSectionHeader(title: "Final Review")
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    FinalReviewPaperCard(status: assignment.isStudentFacingExportReady ? .readyToExport : .reviewFinalGrade, tape: "approval") {
                        VStack(alignment: .leading, spacing: 12) {
                            GradeDraftStatusLabeledContent(
                                title: "Approval Status",
                                value: finalReviewStatusText(assignment.finalReview?.status),
                                status: assignment.finalReview?.status.v6Status ?? .reviewFinalGrade
                            )
                            if let review = assignment.finalReview, !review.criteria.isEmpty {
                                LabeledContent("Criteria approved", value: "\(review.criteria.filter(\.teacherApproved).count) / \(review.criteria.count)")
                            }
                            LabeledContent("Student-facing export", value: assignment.isStudentFacingExportReady ? "Ready" : "Blocked")
                        }
                    }
                } header: {
                    FinalReviewTapeSectionHeader(title: "Teacher Approval")
                } footer: {
                    Text("Student-facing export is blocked until the teacher approves the final grade.")
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if let next = nextStudent(after: assignment) {
                    Section {
                        FinalReviewPaperCard(status: .reviewFinalGrade, tape: "next up") {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Keep grading \(assignment.className.nilIfBlank ?? "this class")")
                                    .font(.system(.headline, design: .serif))
                                Button {
                                    viewModel.selectAssignment(next.id)
                                    gradingTarget = GradingTarget(id: next.id)
                                } label: {
                                    Label("Next student: \(next.studentDisplayName.nilIfBlank ?? "Untitled")", systemImage: "arrow.right.circle")
                                        .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    } header: {
                        FinalReviewTapeSectionHeader(title: "Class Throughput")
                    } footer: {
                        Text("Jump straight to the next student in this class who still needs grading.")
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    FinalReviewPaperCard(status: .needsAttention, tape: "assignment") {
                        ContentUnavailableView(
                            "Assignment not found",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("Return to Assignments and choose a saved assignment.")
                        )
                    }
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .scrollContentBackground(.hidden)
        .background(FinalReviewPaperStyle.background.ignoresSafeArea())
        .navigationTitle("Final Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(item: $gradingTarget) { target in
            FinalReviewScreen(viewModel: viewModel, assignmentID: target.id)
        }
        .navigationDestination(item: $sourceReviewTarget) { target in
            ReviewScannedTextScreen(viewModel: viewModel, assignmentID: target.id)
        }
        .onAppear { viewModel.selectAssignment(assignmentID) }
    }

    private func nextStudent(after assignment: AssignmentRecord) -> AssignmentRecord? {
        guard !assignment.className.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return viewModel.assignments
            .filter { $0.className.caseInsensitiveCompare(assignment.className) == .orderedSame }
            .sorted { $0.studentDisplayName.localizedCaseInsensitiveCompare($1.studentDisplayName) == .orderedAscending }
            .first { record in
                record.id != assignment.id && (record.finalReview?.status != .approved || record.finalReviewIsStale)
            }
    }

    private func finalReviewStatusText(_ status: FinalReviewStatus?) -> String {
        switch status {
        case .approved:
            return "Approved"
        case .inProgress:
            return "In progress"
        case .stale:
            return "Needs recheck"
        case nil:
            return "Not approved"
        }
    }

    private func canDraftGrade(for assignment: AssignmentRecord) -> Bool {
        guard assignment.assignmentInputReady, !viewModel.isWorking else { return false }
        if case .available = viewModel.localAIStatus { return true }
        return false
    }

    private func draftReadinessIssues(for assignment: AssignmentRecord) -> [String] {
        guard !canDraftGrade(for: assignment) else { return [] }
        var issues: [String] = []
        if viewModel.isWorking {
            issues.append("A local draft operation is already running.")
        }
        if case .unavailable(let message) = viewModel.localAIStatus {
            issues.append(message)
        }
        if !assignment.hasGradingStandard {
            issues.append("Add a rubric, answer key, exemplar, or grading criteria before drafting feedback.")
        }
        if assignment.reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Add or review the student text before drafting feedback.")
        }
        if assignment.ocrReviewStatus.blocksGrading {
            issues.append("Review and confirm scanned text before drafting feedback.")
        }
        if assignment.latestDraftIsStale {
            issues.append("The existing local AI draft is stale. Generate a fresh draft or use manual final review.")
        }
        return issues
    }

    private func canStartFromLatestDraft(for assignment: AssignmentRecord) -> Bool {
        assignment.latestDraft != nil && !assignment.latestDraftIsStale
    }

    private func latestDraftIssue(for assignment: AssignmentRecord) -> String? {
        if assignment.latestDraft == nil {
            return "No current local AI draft is available. Generate a draft or start manual final review."
        }
        if assignment.latestDraftIsStale {
            return "The latest local AI draft is stale because the grading packet changed."
        }
        return nil
    }

    private func canStartManualFinalReview(for assignment: AssignmentRecord) -> Bool {
        manualGradingReadinessIssues(for: assignment).isEmpty
    }

    private func manualGradingReadinessIssues(for assignment: AssignmentRecord) -> [String] {
        var issues: [String] = []
        if !assignment.hasGradingStandard {
            issues.append("Add a rubric, answer key, exemplar, or grading criteria before manual final review.")
        }
        if assignment.reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Add or review the student text before manual final review.")
        }
        if assignment.ocrReviewStatus.blocksGrading {
            issues.append("Review and confirm scanned text before manual final review.")
        }
        return issues
    }

    private func finalReviewScoreText(for assignment: AssignmentRecord) -> String {
        if let review = assignment.finalReview {
            return "\(GradeTotals.formatted(review.totalScore)) / \(GradeTotals.formatted(review.maxScore))"
        }
        if let draft = assignment.latestDraft {
            return "\(GradeTotals.formatted(draft.totalScore)) / \(GradeTotals.formatted(draft.maxScore)) suggested"
        }
        return "Not scored"
    }

    private func aiReadinessReport(for assignment: AssignmentRecord) -> AIReadinessReport? {
        guard viewModel.aiReadinessReport?.assignmentID == assignment.id else { return nil }
        return viewModel.aiReadinessReport
    }

    private func aiPacketPreview(for assignment: AssignmentRecord) -> AIPacketPreview? {
        guard viewModel.aiPacketPreview?.assignmentID == assignment.id else { return nil }
        return viewModel.aiPacketPreview
    }
}

private enum FinalReviewPaperStyle {
    static let background = Color(red: 0.98, green: 0.95, blue: 0.88)
    static let paper = Color(red: 1.0, green: 0.985, blue: 0.94)
    static let ink = Color(red: 0.24, green: 0.18, blue: 0.13)
    static let rule = Color(red: 0.74, green: 0.52, blue: 0.30)
    static let tape = Color(red: 0.96, green: 0.84, blue: 0.55)
    static let shadow = Color.black.opacity(0.08)
}

private struct FinalReviewPaperHeader: View {
    var assignmentTitle: String
    var studentName: String
    var status: GradeDraftUIStatus
    var scoreText: String
    var exportReady: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Final Review")
                        .font(.system(.title, design: .serif).weight(.semibold))
                        .foregroundStyle(FinalReviewPaperStyle.ink)
                    Text(headerNote)
                        .font(.system(.subheadline, design: .serif).italic())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "paperclip")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FinalReviewPaperStyle.rule)
                    .rotationEffect(.degrees(11))
                    .accessibilityHidden(true)
            }
            HStack(spacing: 8) {
                FinalReviewMetricPill(label: "Status", value: status.chipLabel, status: status)
                FinalReviewMetricPill(label: "Score", value: scoreText, status: status)
                FinalReviewMetricPill(label: "Export", value: exportReady ? "Ready" : "Blocked", status: exportReady ? .readyToExport : .reviewFinalGrade)
            }
        }
        .padding(18)
        .background(FinalReviewPaperStyle.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topLeading) {
            FinalReviewTapeLabel(text: "teacher notes")
                .offset(x: 18, y: -11)
        }
        .overlay(alignment: .leading) {
            FinalReviewPerforation()
                .offset(x: 7)
        }
        .shadow(color: FinalReviewPaperStyle.shadow, radius: 12, x: 0, y: 6)
    }

    private var headerNote: String {
        let student = studentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = assignmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if student.isEmpty && title.isEmpty { return "Teacher approval controls student-facing export." }
        if student.isEmpty { return "\(title). Teacher approval controls student-facing export." }
        if title.isEmpty { return "\(student). Teacher approval controls student-facing export." }
        return "\(student) · \(title). Teacher approval controls student-facing export."
    }
}

private struct FinalReviewMetricPill: View {
    var label: String
    var value: String
    var status: GradeDraftUIStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(status.color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(status.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(status.color.opacity(0.20), lineWidth: 1)
        )
    }
}

private struct FinalReviewPaperCard<Content: View>: View {
    var status: GradeDraftUIStatus
    var tape: String
    let content: Content

    init(status: GradeDraftUIStatus, tape: String, @ViewBuilder content: () -> Content) {
        self.status = status
        self.tape = tape
        self.content = content()
    }

    var body: some View {
        content
            .padding(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FinalReviewPaperStyle.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(status.color.opacity(0.25), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                FinalReviewTapeLabel(text: tape)
                    .offset(x: 14, y: -10)
            }
            .overlay(alignment: .leading) {
                FinalReviewPerforation()
                    .offset(x: 7)
            }
            .shadow(color: FinalReviewPaperStyle.shadow, radius: 8, x: 0, y: 4)
    }
}

private struct FinalReviewNoteRow: View {
    var issue: String

    init(_ issue: String) {
        self.issue = issue
    }

    var body: some View {
        Label(issue, systemImage: "info.circle")
            .font(.system(.subheadline, design: .serif).italic())
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct AIReadinessSummaryView: View {
    var report: AIReadinessReport

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(report.canGenerate ? "AI ready" : "AI not ready", systemImage: report.canGenerate ? "checkmark.shield" : "exclamationmark.triangle")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(report.canGenerate ? .green : .orange)
            Text(report.recommendedNextAction)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(report.checks) { check in
                Label(check.detail, systemImage: iconName(for: check.status))
                    .font(.caption)
                    .foregroundStyle(color(for: check.status))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func iconName(for status: AIReadinessStatus) -> String {
        switch status {
        case .ready:
            return "checkmark.circle"
        case .needsReview:
            return "exclamationmark.circle"
        case .blocked, .unavailable:
            return "xmark.octagon"
        case .info:
            return "info.circle"
        }
    }

    private func color(for status: AIReadinessStatus) -> Color {
        switch status {
        case .ready:
            return .green
        case .needsReview, .info:
            return .orange
        case .blocked, .unavailable:
            return .red
        }
    }
}

private struct AIPacketPreviewSummaryView: View {
    var preview: AIPacketPreview

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                packetList(title: "Included in local draft", items: preview.includedInLocalDraft, icon: "checkmark.circle")
                packetList(title: "Not sent to model", items: preview.notSentToModel, icon: "eye.slash")
                packetList(title: "Generation plan", items: preview.generationPlan, icon: "slider.horizontal.3")
                DisclosureGroup("Technical packet") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Prompt version", value: preview.promptVersion)
                        LabeledContent("Prompt fingerprint", value: preview.promptFingerprint)
                        LabeledContent("Packet fingerprint", value: preview.packetFingerprint)
                        ForEach(preview.modelVisibleMetadata, id: \.self) { item in
                            Label(item, systemImage: "number")
                                .font(.caption)
                        }
                        Text(preview.technicalPromptPreview)
                            .font(.caption.monospaced())
                            .lineLimit(16)
                            .textSelection(.enabled)
                    }
                }
            }
        } label: {
            Label("Local AI Packet Preview", systemImage: "doc.text")
                .font(.system(.headline, design: .serif))
        }
    }

    private func packetList(title: String, items: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            ForEach(items, id: \.self) { item in
                Label(item, systemImage: icon)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AIGenerationProgressView: View {
    var progress: AIGenerationProgress
    var canCancel: Bool
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(progressTitle, systemImage: iconName)
                .font(.system(.subheadline, design: .serif).weight(.semibold))
                .foregroundStyle(color)
            Text(progress.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let fraction = progress.fractionCompleted {
                ProgressView(value: fraction)
            } else if progress.canCancel {
                ProgressView()
            }
            if canCancel {
                Button(role: .cancel, action: onCancel) {
                    Label("Cancel Local Draft", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(color.opacity(0.20), lineWidth: 1)
        )
    }

    private var progressTitle: String {
        switch progress.stage {
        case .idle:
            return "Local draft"
        case .validatingInputs:
            return "Checking inputs"
        case .checkingAvailability:
            return "Checking local AI"
        case .planningPacket:
            return "Planning packet"
        case .requestingModel:
            return "Drafting locally"
        case .generatingCriteria:
            return "Drafting criteria"
        case .synthesizingSummary:
            return "Synthesizing summary"
        case .rewritingFeedback:
            return "Rewriting feedback"
        case .validatingDraft:
            return "Validating draft"
        case .storingDraft:
            return "Saving draft"
        case .cancellationRequested:
            return "Cancelling"
        case .cancelled:
            return "Cancelled"
        case .failed:
            return "Draft failed"
        case .completed:
            return "Draft saved"
        }
    }

    private var iconName: String {
        switch progress.stage {
        case .failed:
            return "exclamationmark.triangle"
        case .cancelled, .cancellationRequested:
            return "xmark.circle"
        case .completed:
            return "checkmark.circle"
        default:
            return "sparkles"
        }
    }

    private var color: Color {
        switch progress.stage {
        case .failed:
            return .red
        case .cancelled, .cancellationRequested:
            return .orange
        case .completed:
            return .green
        default:
            return .blue
        }
    }
}

private struct DraftCriterionReviewCard: View {
    var criterion: CriterionScore
    var onReviewSourceText: () -> Void
    var onStartFinalReview: () -> Void

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Suggested points", value: "\(GradeTotals.formatted(criterion.proposedPoints)) / \(GradeTotals.formatted(criterion.maxPoints))")
                LabeledContent("Confidence", value: criterion.confidence.nilIfBlank ?? "Not provided")

                if criterion.teacherReviewRequired {
                    Label("Teacher review required for this criterion.", systemImage: "person.crop.circle.badge.exclamationmark")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }

                if !criterion.criterionUncertaintyFlags.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Review reasons")
                            .font(.caption.weight(.semibold))
                        ForEach(criterion.criterionUncertaintyFlags, id: \.self) { reason in
                            Label(reason, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Text(criterion.explanation.isEmpty ? "No explanation provided." : criterion.explanation)
                    .font(.subheadline)
                    .textSelection(.enabled)

                if !criterion.nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LabeledContent("Suggested next step", value: criterion.nextStep)
                }

                evidenceSection

                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        onReviewSourceText()
                    } label: {
                        Label("Show in Reviewed Text", systemImage: "text.viewfinder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        onStartFinalReview()
                    } label: {
                        Label("Accept, Edit, or Reject", systemImage: "checklist")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(criterion.criterion)
                    .font(.headline)
                Text(criterion.rating.isEmpty ? "No rating selected" : criterion.rating)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
    }

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Evidence used")
                .font(.caption.weight(.semibold))
            if criterion.evidence.isEmpty {
                Text(GradeDraftValidator.missingEvidenceMarker)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(criterion.evidence.enumerated()), id: \.offset) { index, evidence in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\u{201C}\(evidence)\u{201D}")
                            .font(.caption)
                            .textSelection(.enabled)
                        if index < criterion.evidenceSourceRefs.count {
                            Text(criterion.evidenceSourceRefs[index])
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        } else if !criterion.evidenceSourceRefs.isEmpty {
                            Text("No direct source reference matched this quote.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
    }

    private var accessibilitySummary: String {
        let confidence = criterion.confidence.nilIfBlank ?? "confidence not provided"
        let review = criterion.teacherReviewRequired ? "teacher review required" : "teacher review still required before approval"
        return "\(criterion.criterion), suggested score \(GradeTotals.formatted(criterion.proposedPoints)) out of \(GradeTotals.formatted(criterion.maxPoints)), \(confidence), \(review)."
    }
}

private struct FinalReviewTapeSectionHeader: View {
    var title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(FinalReviewPaperStyle.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(FinalReviewPaperStyle.tape.opacity(0.92), in: Capsule())
            .overlay(Capsule().stroke(FinalReviewPaperStyle.rule.opacity(0.22), lineWidth: 1))
            .padding(.top, 6)
            .textCase(nil)
    }
}

private struct FinalReviewTapeLabel: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(FinalReviewPaperStyle.ink.opacity(0.78))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(FinalReviewPaperStyle.tape.opacity(0.92), in: Capsule())
            .rotationEffect(.degrees(-2))
            .accessibilityHidden(true)
    }
}

private struct FinalReviewPerforation: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { _ in
                Circle()
                    .fill(FinalReviewPaperStyle.background)
                    .frame(width: 5, height: 5)
                    .overlay(Circle().stroke(FinalReviewPaperStyle.rule.opacity(0.18), lineWidth: 0.5))
            }
        }
        .padding(.vertical, 8)
        .accessibilityHidden(true)
    }
}

private extension DraftStatus {
    var v6Status: GradeDraftUIStatus {
        switch self {
        case .generated:
            return .reviewFinalGrade
        case .teacherReviewRequired:
            return .needsAttention
        case .stale:
            return .needsRecheck
        }
    }
}
