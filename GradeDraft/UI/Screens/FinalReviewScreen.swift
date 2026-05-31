import SwiftUI

struct FinalReviewScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var assignmentID: UUID

    var body: some View {
        Form {
            if let assignment = viewModel.assignment(for: assignmentID) {
                if assignment.finalReviewIsStale {
                    Section {
                        WarningBanner(
                            title: "This review needs rechecking.",
                            message: "Student work, rubric, or evidence changed after this review was last saved.",
                            status: .needsRecheck
                        )
                    }
                }

                Section {
                    Button {
                        viewModel.selectAssignment(assignmentID)
                        Task { await viewModel.draftGrade() }
                    } label: {
                        Label(viewModel.isWorking ? "Drafting" : "Draft Feedback Suggestion", systemImage: "sparkles")
                    }
                    .disabled(!canDraftGrade(for: assignment))

                    ForEach(draftReadinessIssues(for: assignment), id: \.self) { issue in
                        Label(issue, systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        viewModel.selectAssignment(assignmentID)
                        viewModel.startFinalReviewFromLatestDraft()
                    } label: {
                        Label("Start Final Review", systemImage: "checklist")
                    }
                    .disabled(!canStartFromLatestDraft(for: assignment))

                    if let issue = latestDraftIssue(for: assignment) {
                        Label(issue, systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        viewModel.selectAssignment(assignmentID)
                        viewModel.startManualFinalReview()
                    } label: {
                        Label("Start Manual Final Review", systemImage: "pencil.and.list.clipboard")
                    }
                    .disabled(!canStartManualFinalReview(for: assignment))

                    if !canStartManualFinalReview(for: assignment) {
                        ForEach(manualGradingReadinessIssues(for: assignment), id: \.self) { issue in
                            Label(issue, systemImage: "info.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Review Actions")
                } footer: {
                    Text("GradeDraft drafts suggestions only. The teacher approves the final grade.")
                }

                Section {
                    if assignment.evidenceReferences.isEmpty {
                        ContentUnavailableView(
                            "No evidence added",
                            systemImage: "quote.bubble",
                            description: Text("Add evidence from reviewed text during final review.")
                        )
                    } else {
                        ForEach(assignment.evidenceReferences) { item in
                            EvidenceSourceRow(evidence: item)
                        }
                    }
                } header: {
                    Text("Evidence")
                } footer: {
                    Text("Evidence remains linked to reviewed student work or teacher notes.")
                }

                if let finalReview = assignment.finalReview {
                    Section {
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
                            }
                        )
                        .id(finalReview.id)
                    } header: {
                        Text("Criterion Review")
                    } footer: {
                        Text("Approve every criterion before treating the score as final.")
                    }
                } else if let result = assignment.latestDraft {
                    Section {
                        LabeledContent("Suggested Score", value: "\(GradeTotals.formatted(result.totalScore)) / \(GradeTotals.formatted(result.maxScore))")
                        if assignment.latestDraftIsStale || result.status == .stale {
                            Label("Needs recheck: student work, rubric, or evidence changed.", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                        Text(result.studentResponseSummary)
                            .font(.subheadline)
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
                            DisclosureGroup {
                                Text(criterion.explanation.isEmpty ? "No explanation provided." : criterion.explanation)
                                    .font(.subheadline)
                                LabeledContent("Suggested Points", value: "\(GradeTotals.formatted(criterion.proposedPoints)) / \(GradeTotals.formatted(criterion.maxPoints))")
                                if criterion.teacherReviewRequired {
                                    Label("Teacher review required for this criterion.", systemImage: "exclamationmark.triangle")
                                        .font(.subheadline)
                                        .foregroundStyle(.orange)
                                }
                                if !criterion.evidence.isEmpty {
                                    ForEach(criterion.evidence, id: \.self) { evidence in
                                        Text("\u{201C}\(evidence)\u{201D}")
                                            .font(.caption)
                                            .textSelection(.enabled)
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
                    } header: {
                        Text("Draft Suggestion")
                    } footer: {
                        Text("Review this suggestion and start final review before export.")
                    }
                } else {
                    Section("Final Review") {
                        ContentUnavailableView(
                            "Review final grade",
                            systemImage: "checklist",
                            description: Text("Draft a feedback suggestion or start manual final review.")
                        )
                    }
                }

                Section {
                    GradeDraftStatusLabeledContent(
                        title: "Approval Status",
                        value: finalReviewStatusText(assignment.finalReview?.status),
                        status: assignment.finalReview?.status.v6Status ?? .reviewFinalGrade
                    )
                    LabeledContent("Student-facing export", value: assignment.isStudentFacingExportReady ? "Ready" : "Blocked")
                } header: {
                    Text("Teacher Approval")
                } footer: {
                    Text("Student-facing export is blocked until the teacher approves the final grade.")
                }
            } else {
                Section {
                    ContentUnavailableView(
                        "Assignment not found",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Return to Assignments and choose a saved assignment.")
                    )
                }
            }
        }
        .navigationTitle("Final Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { viewModel.selectAssignment(assignmentID) }
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
}
