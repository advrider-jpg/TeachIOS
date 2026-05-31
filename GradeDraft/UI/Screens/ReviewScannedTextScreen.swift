import SwiftUI

struct ReviewScannedTextScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var assignmentID: UUID
    @State private var selectedPageID: UUID?
    @State private var selectedLineID: UUID?
    @State private var selectedEvidenceCriterionID: UUID?
    @State private var showingReviewConfirm = false

    var body: some View {
        Group {
            let assignment = viewModel.assignment(for: assignmentID) ?? viewModel.assignment
            if let document = assignment.ocrDocument, !document.pages.isEmpty {
                let pages = document.pages.sorted { $0.pageIndex < $1.pageIndex }
                let page = selectedPage(from: pages)
                List {
                    Section {
                        ReviewGateBanner(
                            title: GradeDraftUIStatus.reviewScannedText.rawValue,
                            message: reviewSubtitle(for: assignment),
                            status: assignment.ocrReviewStatus.v6Status
                        )
                    } header: {
                        Text("Text Review Needed")
                    } footer: {
                        Text("OCR text must be reviewed before grading.")
                    }

                    Section {
                        if pages.count > 1 {
                            ScannedTextPageSelector(pages: pages, selectedPageID: $selectedPageID)
                        }
                        if let page {
                            let source = page.sourceInputID.flatMap { sourceID in
                                assignment.sourceInputs.first(where: { $0.id == sourceID })
                            }
                            let image = source.flatMap { viewModel.sourceImage(for: $0) }
                            ScannedTextDocumentPreview(
                                image: image,
                                page: page,
                                selectedLineID: selectedLineID
                            )
                        }
                    } header: {
                        Text("Work Preview")
                    } footer: {
                        Text(workPreviewFooter(for: page, assignment: assignment))
                    }

                    if let page {
                        Section {
                            if let finalReview = assignment.finalReview, !finalReview.criteria.isEmpty {
                                Picker("Link evidence to criterion", selection: $selectedEvidenceCriterionID) {
                                    Text("First final-review criterion").tag(Optional<UUID>.none)
                                    ForEach(finalReview.criteria) { criterion in
                                        Text(criterion.criterion).tag(Optional(criterion.id))
                                    }
                                }
                            }
                            Button(action: selectNextLine) {
                                Label("Next Line", systemImage: "arrow.down.circle")
                            }
                            .disabled(nextUnreviewedLineTarget == nil)
                            Button {
                                viewModel.selectAssignment(assignmentID)
                                viewModel.markOCRPageReviewed(pageID: page.id)
                            } label: {
                                Label("Mark Page Reviewed", systemImage: "checkmark.rectangle")
                            }
                            .disabled(page.unresolvedLineCount > 0 || assignment.ocrReviewStatus == .reviewed)
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
                                        viewModel.selectAssignment(assignmentID)
                                        viewModel.updateOCRLine(pageID: page.id, lineID: line.id, correctedText: text)
                                    },
                                    onConfirm: {
                                        selectedPageID = page.id
                                        selectedLineID = line.id
                                        viewModel.selectAssignment(assignmentID)
                                        viewModel.confirmOCRLine(pageID: page.id, lineID: line.id)
                                    },
                                    onReject: {
                                        selectedPageID = page.id
                                        selectedLineID = line.id
                                        viewModel.selectAssignment(assignmentID)
                                        viewModel.rejectOCRLine(pageID: page.id, lineID: line.id)
                                    },
                                    onAddEvidence: {
                                        selectedPageID = page.id
                                        selectedLineID = line.id
                                        viewModel.selectAssignment(assignmentID)
                                        viewModel.addOCRLineEvidenceToFinalReview(pageID: page.id, lineID: line.id, criterionID: selectedEvidenceCriterionID)
                                    },
                                    evidenceEnabled: assignment.finalReview != nil && !line.reviewedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                )
                            }
                        } header: {
                            Text("Text Lines")
                        } footer: {
                            Text(document.qualitySummary.displaySummary)
                        }
                    }

                    Section {
                        Button {
                            showingReviewConfirm = true
                        } label: {
                            Label("Mark Text Reviewed", systemImage: "checkmark.seal")
                        }
                        .disabled(!canMarkDocumentReviewed(document: document, assignment: assignment))
                    } header: {
                        Text("Review Actions")
                    } footer: {
                        Text(reviewActionFooter(document: document, assignment: assignment))
                    }

                    if !assignment.evidenceReferences.isEmpty {
                        Section("Evidence") {
                            EvidenceSourcePreview(evidence: assignment.evidenceReferences)
                        }
                    }
                }
                .gradeDraftNativeGroupedList()
            } else {
                ContentUnavailableView(
                    "No scanned text",
                    systemImage: "text.viewfinder",
                    description: Text("Use Student Work to scan, import a photo or PDF, or save pasted text. Scanned, photo, and PDF text appears here only when local text review is required.")
                )
            }
        }
        .navigationTitle(GradeDraftWorkflowLanguage.reviewScannedTextScreenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            viewModel.selectAssignment(assignmentID)
            if selectedPageID == nil {
                selectedPageID = viewModel.assignment.ocrDocument?.pages.sorted { $0.pageIndex < $1.pageIndex }.first?.id
            }
        }
        .confirmationDialog(GradeDraftWorkflowLanguage.reviewScannedTextScreenTitle, isPresented: $showingReviewConfirm, titleVisibility: .visible) {
            Button("Mark Reviewed") {
                viewModel.selectAssignment(assignmentID)
                viewModel.markOCRReviewed()
            }
            Button("Keep Reviewing", role: .cancel) {}
        } message: {
            Text("Only continue if the text shown here accurately reflects the student work you want GradeDraft to use. The app will draft feedback from this reviewed text, not from the original image.")
        }
    }

    private func selectedPage(from pages: [OCRPage]) -> OCRPage? {
        pages.first(where: { $0.id == selectedPageID }) ?? pages.first
    }

    private func selectNextLine() {
        viewModel.selectAssignment(assignmentID)
        if let target = nextUnreviewedLineTarget {
            selectedPageID = target.pageID
            selectedLineID = target.lineID
        }
    }

    private var nextUnreviewedLineTarget: (pageID: UUID, lineID: UUID)? {
        viewModel.nextUnreviewedLine(after: selectedLineID)
    }

    private func workPreviewFooter(for page: OCRPage?, assignment: AssignmentRecord) -> String {
        guard let page else {
            return "No page is selected."
        }
        let source = page.sourceInputID.flatMap { sourceID in
            assignment.sourceInputs.first(where: { $0.id == sourceID })
        }
        if source.flatMap({ viewModel.sourceImage(for: $0) }) == nil {
            return "No page image is available. Review the extracted text lines below before grading."
        }
        return "Selected line is outlined in blue. Lines needing review are outlined in orange."
    }

    private func canMarkDocumentReviewed(document: OCRDocument, assignment: AssignmentRecord) -> Bool {
        document.unresolvedLineCount == 0 && assignment.ocrReviewStatus != .reviewed
    }

    private func reviewActionFooter(document: OCRDocument, assignment: AssignmentRecord) -> String {
        if assignment.ocrReviewStatus == .reviewed {
            return "This scanned text has already been marked reviewed."
        }
        if document.unresolvedLineCount > 0 {
            return "Confirm or reject every text line before marking the scanned text reviewed."
        }
        return "Only continue if the text shown here accurately reflects the student work you want GradeDraft to use."
    }

    private func reviewSubtitle(for assignment: AssignmentRecord) -> String {
        let unresolved = assignment.ocrDocument?.unresolvedLineCount ?? 0
        if assignment.ocrReviewStatus == .reviewed { return "All text lines have been checked." }
        if unresolved == 1 { return "1 text line needs checking." }
        return "\(unresolved) text lines need checking."
    }
}
