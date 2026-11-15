import ImageIO
import SwiftUI

/// The teacher checks each recognised line against the page image before the scanned text is used for
/// grading. Every line action saves at once.
struct ReviewScannedTextScreen: View {
    @Bindable var session: SubmissionSession

    @State private var selectedPageID: UUID?
    @State private var selectedLineID: UUID?
    @State private var correcting: OCRLine?
    @State private var showingReviewConfirm = false

    var body: some View {
        Group {
            if let graph = session.graph, let ocr = graph.ocr, !ocr.pages.isEmpty {
                content(graph: graph, ocr: ocr)
            } else {
                ContentUnavailableView(
                    "No scanned text",
                    systemImage: "text.viewfinder",
                    description: Text("Use Student Work to scan, choose photos or import a PDF. Scanned and imported text appears here for review.")
                )
            }
        }
        .navigationTitle("Review Scanned Text")
        .navigationBarTitleDisplayMode(.inline)
        .alertMessage($session.alert)
        .sheet(item: $correcting) { line in
            CorrectLineSheet(session: session, line: line)
        }
        .confirmationDialog("Mark Scanned Text Reviewed", isPresented: $showingReviewConfirm, titleVisibility: .visible) {
            Button("Mark Reviewed") {
                Task { await session.markScannedTextReviewed() }
            }
            .accessibilityIdentifier("scannedText.markReviewedConfirm")
            Button("Keep Reviewing", role: .cancel) {}
        } message: {
            Text("Only continue if the text shown here accurately reflects the student work you want MarkForMe to use. Feedback is drafted from this reviewed text, not from the original image.")
        }
    }

    private func content(graph: SubmissionGraph, ocr: OCRDocument) -> some View {
        let pages = ocr.pages.sorted { $0.pageIndex < $1.pageIndex }
        let page = pages.first { $0.id == selectedPageID } ?? pages[0]
        let source = graph.sources.first { $0.id == page.sourceInputID }
        let imageURL = source.flatMap { source in
            session.app.storageRoot.flatMap {
                SourcePathSafety.resolvedLocalSourceURL(source.localRelativePath, applicationSupportDirectory: $0)
            }
        }
        return ScrollViewReader { proxy in
            List {
                Section {
                    StatusLabel(ocr.reviewStatus.uiStatus, subject: "Scanned text status")
                    LabeledContent("Pages", value: "\(pages.count)")
                    LabeledContent("Lines needing your action", value: "\(ocr.unresolvedLineCount)")
                    Text(ocr.qualitySummary.displaySummary)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Highlighted lines need you to confirm, correct or reject them. Typed PDF text always needs your check.")
                }

                Section {
                    if pages.count > 1 {
                        Picker("Page", selection: Binding(get: { page.id }, set: { selectedPageID = $0 })) {
                            ForEach(pages) { page in
                                Text("Page \(page.pageIndex + 1)").tag(page.id)
                            }
                        }
                        .accessibilityIdentifier("scannedText.pagePicker")
                    }
                    PageImageView(page: page, imageURL: imageURL, selectedLineID: selectedLineID)
                } header: {
                    Text("Page \(page.pageIndex + 1)")
                } footer: {
                    Text("Pinch to zoom. The selected line is outlined in the accent colour; lines needing review in orange.")
                }

                Section("Text Lines") {
                    Button {
                        selectNextLine(after: selectedLineID, pages: pages, proxy: proxy)
                    } label: {
                        Label("Next Line Needing Action", systemImage: "arrow.down.circle")
                    }
                    .disabled(ocr.unresolvedLineCount == 0)
                    .accessibilityIdentifier("scannedText.nextLine")
                    ForEach(Array(page.lines.enumerated()), id: \.element.id) { index, line in
                        lineRow(line, index: index)
                            .id(line.id)
                    }
                }

                Section {
                    Button {
                        Task { await session.confirmAllConfidentLines() }
                    } label: {
                        Label("Confirm All Confident Lines", systemImage: "checkmark.circle")
                    }
                    .disabled(ocr.reviewStatus == .reviewed)
                    .accessibilityIdentifier("scannedText.confirmAll")
                    Button {
                        showingReviewConfirm = true
                    } label: {
                        Label("Mark Scanned Text Reviewed", systemImage: "checkmark.seal")
                    }
                    .disabled(ocr.unresolvedLineCount > 0 || ocr.reviewStatus == .reviewed)
                    .accessibilityIdentifier("scannedText.markReviewed")
                } header: {
                    Text("Review Actions")
                } footer: {
                    if ocr.reviewStatus == .reviewed {
                        Text("This scanned text has been marked reviewed.")
                    } else {
                        Text(((session.readiness?.scannedTextIssues ?? []).map(\.message)
                            + ["Confirm all accepts only lines read with high confidence; low-confidence and typed PDF lines still need your action."])
                            .joined(separator: " "))
                    }
                }
            }
        }
    }

    private func lineRow(_ line: OCRLine, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                selectedLineID = line.id
            } label: {
                if line.isRejected {
                    Text(line.rawText)
                        .strikethrough()
                        .foregroundStyle(.secondary)
                } else {
                    Text(line.reviewedText)
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("scannedText.lineSelect.\(index)")
            if let corrected = line.correctedText, !corrected.isWhitespaceOnly, !line.isRejected {
                Text("Recognised as: \(line.rawText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            StatusLabel(line.reviewUIStatus, subject: "Line status")
            switch line.origin {
            case .pdfTextLayer:
                Label("From PDF text layer", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .visionOCR:
                Label(
                    line.confidence.map { "Confidence \(Int((min(max($0, 0), 1) * 100).rounded()))%" } ?? "No confidence score",
                    systemImage: "text.viewfinder"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            HStack {
                Button("Confirm") {
                    selectedLineID = line.id
                    Task { await session.confirmLine(line.id) }
                }
                .accessibilityIdentifier("scannedText.lineConfirm.\(index)")
                Button("Correct") {
                    selectedLineID = line.id
                    correcting = line
                }
                .accessibilityIdentifier("scannedText.lineCorrect.\(index)")
                Button("Reject", role: .destructive) {
                    selectedLineID = line.id
                    Task { await session.rejectLine(line.id) }
                }
                .accessibilityIdentifier("scannedText.lineReject.\(index)")
            }
            .buttonStyle(.bordered)
        }
        .listRowBackground(line.id == selectedLineID ? Color.accentColor.opacity(0.12) : nil)
    }

    private func selectNextLine(after lineID: UUID?, pages: [OCRPage], proxy: ScrollViewProxy) {
        let ordered = pages.flatMap { page in page.lines.map { (pageID: page.id, line: $0) } }
        let start = lineID.flatMap { id in ordered.firstIndex { $0.line.id == id } }.map { $0 + 1 } ?? 0
        let candidates = ordered[min(start, ordered.count)...] + ordered[..<min(start, ordered.count)]
        guard let next = candidates.first(where: { $0.line.needsReview }) else { return }
        selectedPageID = next.pageID
        selectedLineID = next.line.id
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation { proxy.scrollTo(next.line.id, anchor: .center) }
        }
    }
}

/// The page image, read once per page (and again only if the displayed width changes), scaled down off
/// the main actor to the size it is shown at, with the line highlights drawn over it.
private struct PageImageView: View {
    var page: OCRPage
    var imageURL: URL?
    var selectedLineID: UUID?

    @Environment(\.displayScale) private var displayScale
    @State private var image: CGImage?
    @State private var loadedPageID: UUID?
    @State private var loadFailed = false
    @State private var width: CGFloat = 0
    @State private var zoom: CGFloat = 1
    @State private var settledZoom: CGFloat = 1

    private struct LoadKey: Equatable {
        var pageID: UUID
        var pixelWidth: Int
    }

    var body: some View {
        Group {
            if let image, loadedPageID == page.id {
                Image(decorative: image, scale: displayScale)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        TextLineHighlightOverlay(
                            page: page,
                            imageSize: CGSize(width: image.width, height: image.height),
                            selectedLineID: selectedLineID
                        )
                    }
                    .scaleEffect(zoom)
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in zoom = min(max(settledZoom * value.magnification, 1), 4) }
                            .onEnded { _ in settledZoom = zoom }
                    )
                    .onTapGesture(count: 2) {
                        zoom = 1
                        settledZoom = 1
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Page \(page.pageIndex + 1) image")
            } else if imageURL == nil || loadFailed {
                Label("No page image is available. Review the text lines below.", systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            width = newWidth
        }
        .task(id: LoadKey(pageID: page.id, pixelWidth: Int((width * displayScale).rounded()))) {
            await load(pixelWidth: Int((width * displayScale).rounded()))
        }
    }

    private func load(pixelWidth: Int) async {
        if loadedPageID != page.id {
            image = nil
            loadFailed = false
            zoom = 1
            settledZoom = 1
        }
        guard pixelWidth > 0, let imageURL else { return }
        // The thumbnail size limits the longer side; a portrait page is taller than it is wide.
        let aspect: Double
        if let pixelWidthOfPage = page.pixelWidth, let pixelHeightOfPage = page.pixelHeight, pixelWidthOfPage > 0 {
            aspect = max(1, Double(pixelHeightOfPage) / Double(pixelWidthOfPage))
        } else {
            aspect = 1.5
        }
        let maxPixelSize = Int((Double(pixelWidth) * aspect).rounded())
        let loaded = await Task.detached(priority: .userInitiated) {
            PageImageLoader.downsample(imageURL, maxPixelSize: maxPixelSize)
        }.value
        guard !Task.isCancelled else { return }
        image = loaded
        loadedPageID = page.id
        loadFailed = loaded == nil
    }
}

private enum PageImageLoader {
    /// Decodes the image file straight to the requested size without loading the full-resolution bitmap.
    static func downsample(_ url: URL, maxPixelSize: Int) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as [CFString: Any] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}

/// Corrects one line's text. Saving confirms the line.
private struct CorrectLineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: SubmissionSession
    var line: OCRLine
    @State private var text: String
    @State private var isSaving = false

    init(session: SubmissionSession, line: OCRLine) {
        self.session = session
        self.line = line
        _text = State(initialValue: line.reviewedText.isWhitespaceOnly ? line.rawText : line.reviewedText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recognised Text") {
                    Text(line.rawText)
                        .foregroundStyle(.secondary)
                }
                Section("Corrected Text") {
                    TextField("Corrected text", text: $text, axis: .vertical)
                        .accessibilityIdentifier("correctLine.text")
                }
            }
            .navigationTitle("Correct Line")
            .navigationBarTitleDisplayMode(.inline)
            .alertMessage($session.alert)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("correctLine.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        Task {
                            await session.correctLine(line.id, text: text)
                            isSaving = false
                            if session.alert == nil { dismiss() }
                        }
                    }
                    .disabled(text.isWhitespaceOnly || isSaving)
                    .accessibilityIdentifier("correctLine.save")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#if DEBUG
#Preview("Light") {
    ScreenPreview { app in RouteDestination(route: .scannedText(PreviewFixtures.scannedSubmissionID), app: app) }
}

#Preview("Dark") {
    ScreenPreview { app in RouteDestination(route: .scannedText(PreviewFixtures.scannedSubmissionID), app: app) }
        .preferredColorScheme(.dark)
}

#Preview("Accessibility XXXL") {
    ScreenPreview { app in RouteDestination(route: .scannedText(PreviewFixtures.scannedSubmissionID), app: app) }
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
