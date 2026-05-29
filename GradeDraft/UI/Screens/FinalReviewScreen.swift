import SwiftUI

struct FinalReviewScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var assignmentID: UUID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GradeDraftLayout.deepSectionSpacing) {
                let assignment = viewModel.assignment
                DeepWorkflowHeader(
                    title: "Final Review",
                    subtitle: "Teacher score, feedback, evidence, and final approval.",
                    status: assignment.finalReview?.status.v6Status ?? .reviewFinalGrade
                )

                if assignment.finalReviewIsStale {
                    WarningBanner(
                        title: "This review needs rechecking.",
                        message: "Student work, rubric, or evidence changed after this review was last saved.",
                        status: .needsRecheck
                    )
                    .padding(.horizontal, GradeDraftLayout.screenPadding)
                }

                GroupedListCard(title: "Review actions", subtitle: "GradeDraft drafts suggestions only. The teacher approves the final grade.") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            PrimaryActionButton(title: viewModel.isWorking ? "Drafting" : "Draft Feedback Suggestion", systemImage: "sparkles", action: { Task { await viewModel.draftGrade() } }, disabled: !viewModel.canDraftGrade)
                            SecondaryActionButton(title: "Start Final Review", systemImage: "checklist", action: { viewModel.startFinalReviewFromLatestDraft() }, disabled: assignment.latestDraft == nil || assignment.latestDraftIsStale)
                        }
                        SecondaryActionButton(title: "Start Manual Final Review", systemImage: "pencil.and.list.clipboard", action: { viewModel.startManualFinalReview() }, disabled: !viewModel.canStartManualFinalReview)
                        if !viewModel.canStartManualFinalReview {
                            ForEach(viewModel.manualGradingReadinessIssues, id: \.self) { issue in
                                Label(issue, systemImage: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(GradeDraftLayout.rowHorizontalPadding)
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                EvidenceSourcePreview(evidence: assignment.evidenceReferences)
                    .padding(.horizontal, GradeDraftLayout.screenPadding)

                if let finalReview = assignment.finalReview {
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
                    .padding(.horizontal, GradeDraftLayout.screenPadding)
                    .id(finalReview.id)
                } else if let result = assignment.latestDraft {
                    GradeResultView(result: result, isStale: assignment.latestDraftIsStale)
                        .padding(.horizontal, GradeDraftLayout.screenPadding)
                } else {
                    GroupedListCard(title: "Final Review", subtitle: "No final review yet.") {
                        EmptyState(title: "Review final grade", message: "Draft a feedback suggestion or start manual final review.", systemImage: "checklist")
                    }
                    .padding(.horizontal, GradeDraftLayout.screenPadding)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { viewModel.selectAssignment(assignmentID) }
    }
}
