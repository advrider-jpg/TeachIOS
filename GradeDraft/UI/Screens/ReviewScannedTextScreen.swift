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
            let assignment = viewModel.assignment
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
                        Text("Review Gate")
                    } footer: {
                        Text("OCR text must be reviewed before grading.")
                    }

                    Section {
                        ScannedTextPageSelector(pages: pages, selectedPageID: $selectedPageID)
                        if let page {
                            let source = page.sourceInputID.flatMap { sourceID in
                                assignment.sourceInputs.first(where: { $0.id == sourceID })
                            }
                            ScannedTextDocumentPreview(
                                image: source.flatMap { viewModel.sourceImage(for: $0) },
                                page: page,
                                selectedLineID: selectedLineID
                            )
                        }
                    } header: {
                        Text("Work Preview")
                    } footer: {
                        Text("Selected line is outlined in blue. Lines needing review are outlined in orange.")
                    }

                    if let page {
                        Section {
                            if let finalReview = assignment.finalReview, !finalReview.criteria.isEmpty {
                                Picker("Evidence target", selection: $selectedEvidenceCriterionID) {
                                    Text("First criterion").tag(Optional<UUID>.none)
                                    ForEach(finalReview.criteria) { criterion in
                                        Text(criterion.criterion).tag(Optional(criterion.id))
                                    }
                                }
                            }
                            Button(action: selectNextLine) {
                                Label("Next Line", systemImage: "arrow.down.circle")
                            }
                            Button {
                                viewModel.markOCRPageReviewed(pageID: page.id)
                            } label: {
                                Label("Mark Page Reviewed", systemImage: "checkmark.rectangle")
                            }
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
                        .disabled(document.unresolvedLineCount > 0)
                    } header: {
                        Text("Review Actions")
                    } footer: {
                        Text("Only continue if the text shown here accurately reflects the student work you want GradeDraft to use.")
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
                    description: Text("Import a scan, photo, or PDF, or paste text from the Student Work screen.")
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
