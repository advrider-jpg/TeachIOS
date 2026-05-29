import SwiftUI

struct ReviewScannedTextScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var assignmentID: UUID
    @State private var selectedPageID: UUID?
    @State private var selectedLineID: UUID?
    @State private var selectedEvidenceCriterionID: UUID?
    @State private var showingReviewConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GradeDraftLayout.deepSectionSpacing) {
                let assignment = viewModel.assignment
                DeepWorkflowHeader(
                    title: GradeDraftWorkflowLanguage.reviewScannedTextScreenTitle,
                    subtitle: reviewSubtitle(for: assignment),
                    status: assignment.ocrReviewStatus.v6Status
                ) {
                    Button("Mark Reviewed") { showingReviewConfirm = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(assignment.ocrDocument == nil)
                }

                ReviewGateBanner(
                    title: GradeDraftUIStatus.reviewScannedText.rawValue,
                    message: reviewSubtitle(for: assignment),
                    status: assignment.ocrReviewStatus.v6Status
                )
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                if let document = assignment.ocrDocument, !document.pages.isEmpty {
                    let pages = document.pages.sorted { $0.pageIndex < $1.pageIndex }
                    ScannedTextPageSelector(pages: pages, selectedPageID: $selectedPageID)
                    if let page = selectedPage(from: pages) {
                        let source = page.sourceInputID.flatMap { sourceID in
                            assignment.sourceInputs.first(where: { $0.id == sourceID })
                        }
                        GroupedListCard(title: "Work preview", subtitle: "Selected line is outlined in blue. Lines needing review are outlined in orange.") {
                            ScannedTextDocumentPreview(
                                image: source.flatMap { viewModel.sourceImage(for: $0) },
                                page: page,
                                selectedLineID: selectedLineID
                            )
                        }
                        .padding(.horizontal, GradeDraftLayout.screenPadding)

                        GroupedListCard(title: "Text lines", subtitle: "Line 1 of \(document.qualitySummary.unconfirmedLineCount + document.qualitySummary.lowConfidenceLineCount) to review") {
                            if let finalReview = assignment.finalReview, !finalReview.criteria.isEmpty {
                                Picker("Evidence target", selection: $selectedEvidenceCriterionID) {
                                    Text("First criterion").tag(Optional<UUID>.none)
                                    ForEach(finalReview.criteria) { criterion in
                                        Text(criterion.criterion).tag(Optional(criterion.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding(GradeDraftLayout.rowHorizontalPadding)
                            }
                            HStack(spacing: 8) {
                                SecondaryActionButton(title: "Next line", systemImage: "arrow.down.circle", action: selectNextLine)
                                SecondaryActionButton(title: "Mark Page Reviewed", systemImage: "checkmark.rectangle", action: { viewModel.markOCRPageReviewed(pageID: page.id) })
                            }
                            .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
                            .padding(.bottom, 8)
                            ForEach(page.lines) { line in
                                TextLineEditorCard(
                                    pageID: page.id,
                                    line: line,
                                    isSelected: selectedLineID == line.id,
                                    onSelect: {
                                        selectedPageID = page.id
                                        selectedLineID = line.id
                                    },
                                    onTextChange: { text in
                                        viewModel.updateOCRLine(pageID: page.id, lineID: line.id, correctedText: text)
                                    },
                                    onConfirm: {
                                        selectedPageID = page.id
                                        selectedLineID = line.id
                                        viewModel.confirmOCRLine(pageID: page.id, lineID: line.id)
                                    },
                                    onReject: {
                                        selectedPageID = page.id
                                        selectedLineID = line.id
                                        viewModel.rejectOCRLine(pageID: page.id, lineID: line.id)
                                    },
                                    onAddEvidence: {
                                        selectedPageID = page.id
                                        selectedLineID = line.id
                                        viewModel.addOCRLineEvidenceToFinalReview(pageID: page.id, lineID: line.id, criterionID: selectedEvidenceCriterionID)
                                    },
                                    evidenceEnabled: assignment.finalReview != nil && !line.reviewedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                )
                                .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
                                .padding(.bottom, 8)
                            }
                        }
                        .padding(.horizontal, GradeDraftLayout.screenPadding)
                    }
                    EvidenceSourcePreview(evidence: assignment.evidenceReferences)
                        .padding(.horizontal, GradeDraftLayout.screenPadding)
                } else {
                    GroupedListCard(title: GradeDraftUIStatus.reviewScannedText.rawValue, subtitle: "Add student work before reviewing scanned text.") {
                        EmptyState(title: "No scanned text", message: "Import a scan, photo, or PDF, or paste text from the Student Work screen.", systemImage: "text.viewfinder")
                    }
                    .padding(.horizontal, GradeDraftLayout.screenPadding)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            viewModel.selectAssignment(assignmentID)
            if selectedPageID == nil {
                selectedPageID = viewModel.assignment.ocrDocument?.pages.sorted { $0.pageIndex < $1.pageIndex }.first?.id
            }
        }
        .confirmationDialog(GradeDraftWorkflowLanguage.reviewScannedTextScreenTitle, isPresented: $showingReviewConfirm, titleVisibility: .visible) {
            Button("Mark Reviewed") { viewModel.markOCRReviewed() }
            Button("Keep Reviewing", role: .cancel) {}
        } message: {
            Text("Only continue if the text shown here accurately reflects the student work you want GradeDraft to use. The app will draft feedback from this reviewed text, not from the original image.")
        }
    }

    private func selectedPage(from pages: [OCRPage]) -> OCRPage? {
        pages.first(where: { $0.id == selectedPageID }) ?? pages.first
    }

    private func selectNextLine() {
        if let target = viewModel.nextUnreviewedLine(after: selectedLineID) {
            selectedPageID = target.pageID
            selectedLineID = target.lineID
        }
    }

    private func reviewSubtitle(for assignment: AssignmentRecord) -> String {
        let unresolved = assignment.ocrDocument?.unresolvedLineCount ?? 0
        if unresolved == 1 { return "1 text line needs checking." }
        return "\(unresolved) text lines need checking."
    }
}
