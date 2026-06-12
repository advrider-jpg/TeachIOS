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
                        ScannedTextPaperHeader(
                            assignmentTitle: assignment.title,
                            status: assignment.ocrReviewStatus.v6Status,
                            pageCount: pages.count,
                            unresolvedLineCount: document.unresolvedLineCount
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    Section {
                        ScannedTextPaperCard(status: assignment.ocrReviewStatus.v6Status, tape: "review gate") {
                            ReviewGateBanner(
                                title: GradeDraftUIStatus.reviewScannedText.rawValue,
                                message: reviewSubtitle(for: assignment),
                                status: assignment.ocrReviewStatus.v6Status
                            )
                        }
                    } header: {
                        ScannedTextTapeSectionHeader(title: "Text Review Needed")
                    } footer: {
                        Text("Check the scanned text before marking.")
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    Section {
                        ScannedTextPaperCard(status: page?.v6PageStatus ?? assignment.ocrReviewStatus.v6Status, tape: "work preview") {
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
                        }
                    } header: {
                        ScannedTextTapeSectionHeader(title: "Work Preview")
                    } footer: {
                        Text(workPreviewFooter(for: page, assignment: assignment))
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

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
                            ScannedTextTapeSectionHeader(title: "Text Lines")
                        } footer: {
                            Text(document.qualitySummary.displaySummary)
                        }
                        .listRowBackground(ScannedTextPaperStyle.paper)
                    }

                    Section {
                        Button {
                            showingReviewConfirm = true
                        } label: {
                            Label("Mark Text Reviewed", systemImage: "checkmark.seal")
                        }
                        .disabled(!canMarkDocumentReviewed(document: document, assignment: assignment))
                    } header: {
                        ScannedTextTapeSectionHeader(title: "Review Actions")
                    } footer: {
                        Text(reviewActionFooter(document: document, assignment: assignment))
                    }
                    .listRowBackground(ScannedTextPaperStyle.paper)

                    if !assignment.evidenceReferences.isEmpty {
                        Section {
                            ScannedTextPaperCard(status: .teacherOnly, tape: "linked evidence") {
                                EvidenceSourcePreview(evidence: assignment.evidenceReferences)
                            }
                        } header: {
                            ScannedTextTapeSectionHeader(title: "Evidence")
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .gradeDraftNativeGroupedList()
                .scrollContentBackground(.hidden)
                .background(ScannedTextPaperStyle.background.ignoresSafeArea())
            } else {
                ScannedTextUnavailablePaper()
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
            Text("Only continue if the text shown here accurately reflects the student work you want MarkForMe to use. The app will draft feedback from this reviewed text, not from the original image.")
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
        return "Only continue if the text shown here accurately reflects the student work you want MarkForMe to use."
    }

    private func reviewSubtitle(for assignment: AssignmentRecord) -> String {
        let unresolved = assignment.ocrDocument?.unresolvedLineCount ?? 0
        if assignment.ocrReviewStatus == .reviewed { return "All text lines have been checked." }
        if unresolved == 1 { return "1 text line needs checking." }
        return "\(unresolved) text lines need checking."
    }
}

private enum ScannedTextPaperStyle {
    static let background = Color(red: 0.98, green: 0.95, blue: 0.88)
    static let paper = Color(red: 1.0, green: 0.985, blue: 0.94)
    static let ink = Color(red: 0.24, green: 0.18, blue: 0.13)
    static let rule = Color(red: 0.74, green: 0.52, blue: 0.30)
    static let tape = Color(red: 0.96, green: 0.84, blue: 0.55)
    static let shadow = Color.black.opacity(0.08)
}

private struct ScannedTextPaperHeader: View {
    var assignmentTitle: String
    var status: GradeDraftUIStatus
    var pageCount: Int
    var unresolvedLineCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(GradeDraftWorkflowLanguage.reviewScannedTextScreenTitle)
                        .font(.system(.title, design: .serif).weight(.semibold))
                        .foregroundStyle(ScannedTextPaperStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(assignmentTitle.isEmpty ? "Teacher text review" : assignmentTitle)
                        .font(.system(.subheadline, design: .serif).italic())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                StatusChip(status, compact: true)
            }
            HStack(spacing: 8) {
                ScannedTextMetricPill(label: "Pages", value: "\(pageCount)", status: status)
                ScannedTextMetricPill(label: "Open lines", value: "\(unresolvedLineCount)", status: unresolvedLineCount == 0 ? .onTrack : .reviewScannedText)
            }
        }
        .padding(18)
        .background(ScannedTextPaperStyle.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topLeading) {
            ScannedTextTapeLabel(text: "ocr notes")
                .offset(x: 18, y: -11)
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "paperclip")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ScannedTextPaperStyle.rule)
                .rotationEffect(.degrees(11))
                .padding(.top, 10)
                .padding(.trailing, 16)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .leading) {
            ScannedTextPerforation()
                .offset(x: 7)
        }
        .shadow(color: ScannedTextPaperStyle.shadow, radius: 12, x: 0, y: 6)
    }
}

private struct ScannedTextMetricPill: View {
    var label: String
    var value: String
    var status: GradeDraftUIStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(status.color)
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

private struct ScannedTextPaperCard<Content: View>: View {
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
            .background(ScannedTextPaperStyle.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(status.color.opacity(0.25), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                ScannedTextTapeLabel(text: tape)
                    .offset(x: 14, y: -10)
            }
            .overlay(alignment: .leading) {
                ScannedTextPerforation()
                    .offset(x: 7)
            }
            .shadow(color: ScannedTextPaperStyle.shadow, radius: 8, x: 0, y: 4)
    }
}

private struct ScannedTextTapeSectionHeader: View {
    var title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(ScannedTextPaperStyle.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(ScannedTextPaperStyle.tape.opacity(0.92), in: Capsule())
            .overlay(Capsule().stroke(ScannedTextPaperStyle.rule.opacity(0.22), lineWidth: 1))
            .padding(.top, 6)
            .textCase(nil)
    }
}

private struct ScannedTextTapeLabel: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(ScannedTextPaperStyle.ink.opacity(0.78))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(ScannedTextPaperStyle.tape.opacity(0.92), in: Capsule())
            .rotationEffect(.degrees(-2))
            .accessibilityHidden(true)
    }
}

private struct ScannedTextPerforation: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { _ in
                Circle()
                    .fill(ScannedTextPaperStyle.background)
                    .frame(width: 5, height: 5)
                    .overlay(Circle().stroke(ScannedTextPaperStyle.rule.opacity(0.18), lineWidth: 0.5))
            }
        }
        .padding(.vertical, 8)
        .accessibilityHidden(true)
    }
}

private struct ScannedTextUnavailablePaper: View {
    var body: some View {
        VStack {
            ContentUnavailableView(
                "No scanned text",
                systemImage: "text.viewfinder",
                description: Text("Use Student Work to scan, import a photo or PDF, or save pasted text. Scanned, photo, and PDF text appears here only when local text review is required.")
            )
            .padding(20)
            .background(ScannedTextPaperStyle.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(ScannedTextPaperStyle.rule.opacity(0.20), lineWidth: 1)
            )
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ScannedTextPaperStyle.background.ignoresSafeArea())
    }
}

private extension OCRPage {
    var v6PageStatus: GradeDraftUIStatus {
        unresolvedLineCount == 0 ? .onTrack : .reviewScannedText
    }
}
