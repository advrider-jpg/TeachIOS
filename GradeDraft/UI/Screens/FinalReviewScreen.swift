import SwiftUI

struct FinalReviewScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var assignmentID: UUID

    var body: some View {
        Form {
            let assignment = viewModel.assignment
            if assignment.finalReviewIsStale {
                Section("Needs Recheck") {
                    WarningBanner(
                        title: "This review needs rechecking.",
                        message: "Student work, rubric, or evidence changed after this review was last saved.",
                        status: .needsRecheck
                    )
                }
            }

            Section("Review Actions") {
                Button {
                    Task { await viewModel.draftGrade() }
                } label: {
                    Label(viewModel.isWorking ? "Drafting" : "Draft Feedback Suggestion", systemImage: "sparkles")
                }
                .disabled(!viewModel.canDraftGrade)

                Button {
                    viewModel.startFinalReviewFromLatestDraft()
                } label: {
                    Label("Start Final Review", systemImage: "checklist")
                }
                .disabled(assignment.latestDraft == nil || assignment.latestDraftIsStale)

                Button {
                    viewModel.startManualFinalReview()
                } label: {
                    Label("Start Manual Final Review", systemImage: "pencil.and.list.clipboard")
                }
                .disabled(!viewModel.canStartManualFinalReview)

                if !viewModel.canStartManualFinalReview {
                    ForEach(viewModel.manualGradingReadinessIssues, id: \.self) { issue in
                        Label(issue, systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("GradeDraft drafts suggestions only. The teacher approves the final grade.")
            }

            Section("Evidence") {
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
            } footer: {
                Text("Evidence remains linked to reviewed student work or teacher notes.")
            }

            if let finalReview = assignment.finalReview {
                Section("Criterion Review") {
                    FinalGradeReviewView(
                        review: finalReview,
                        isStale: assignment.finalReviewIsStale,
                        onChange: { viewModel.updateFinalReview($0) },
                        onApprove: { viewModel.approveFinalReview() },
                        onAddCriterion: { viewModel.addCriterionToFinalReview() },
                        onDeleteCriterion: { viewModel.deleteCriterionFromFinalReview(id: $0) },
                        onAddManualEvidence: { criterionID, quote in viewModel.addManualEvidenceToFinalReview(criterionID: criterionID, quote: quote) },
                        onRemoveEvidence: { criterionID, index in viewModel.removeEvidenceFromFinalReview(criterionID: criterionID, evidenceIndex: index) },
                        onClearEvidence: { criterionID in viewModel.clearEvidenceFromFinalReview(criterionID: criterionID) }
                    )
                    .id(finalReview.id)
                } footer: {
                    Text("Approve every criterion before treating the score as final.")
                }
            } else if let result = assignment.latestDraft {
                Section("Draft Suggestion") {
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
                            Text(criterion.explanation.isEmpty ? “No explanation provided.” : criterion.explanation)
                                .font(.subheadline)
                            LabeledContent(“Suggested Points”, value: “\(GradeTotals.formatted(criterion.proposedPoints)) / \(GradeTotals.formatted(criterion.maxPoints))”)
                            if criterion.teacherReviewRequired {
                                Label(“Teacher review required for this criterion.”, systemImage: “exclamationmark.triangle”)
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                            if !criterion.evidence.isEmpty {
                                ForEach(criterion.evidence, id: \.self) { evidence in
                                    Text(“”\(evidence)””)
                                        .font(.caption)
                                        .textSelection(.enabled)
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(criterion.criterion)
                                    .font(.headline)
                                Text(criterion.rating.isEmpty ? “No rating selected” : criterion.rating)
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

            Section("Teacher Approval") {
                GradeDraftStatusLabeledContent(
                    title: "Approval Status",
                    value: finalReviewStatusText(assignment.finalReview?.status),
                    status: assignment.finalReview?.status.v6Status ?? .reviewFinalGrade
                )
                LabeledContent("Student-facing export", value: viewModel.canExportStudentReport ? "Ready" : "Blocked")
            } footer: {
                Text("Student-facing export is blocked until the teacher approves the final grade.")
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

}
