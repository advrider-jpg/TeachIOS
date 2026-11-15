import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

/// One student's hub for the assignment: add or replace their work, see what is attached, and go on to
/// scanned text review, the AI draft, final review and exports.
struct StudentWorkScreen: View {
    @Bindable var session: SubmissionSession

    @State private var showingScanner = false
    @State private var showingPDFImporter = false
    @State private var showingPasteSheet = false
    @State private var showingClearConfirm = false
    @State private var photoItems: [PhotosPickerItem] = []

    private var isBusy: Bool { session.runningWork != nil }

    var body: some View {
        List {
            if let graph = session.graph, let setup = session.setup {
                headerSection(graph, setup: setup)
                workStatusSections
                addWorkSection
                attachmentsSection(graph)
                reviewedTextSection(graph)
                nextStepsSection(graph)
                clearSection(graph)
            }
        }
        .navigationTitle(session.graph?.student.displayName ?? "Student Work")
        .navigationBarTitleDisplayMode(.inline)
        .alertMessage($session.alert)
        .fullScreenCover(isPresented: $showingScanner) {
            DocumentScannerView { images in
                showingScanner = false
                session.importScan(images)
            } onCancel: {
                showingScanner = false
            } onError: { error in
                showingScanner = false
                session.alert = AlertMessage(title: "Scan failed", error: error)
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showingPDFImporter, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url):
                session.importPDF(at: url)
            case .failure(let error):
                session.alert = AlertMessage(title: "PDF import failed", error: error)
            }
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPhotos(items) }
        }
        .sheet(isPresented: $showingPasteSheet) {
            PasteStudentWorkSheet(
                session: session,
                initialText: session.graph?.submission.inputKind == .pasted ? session.graph?.reviewedText ?? "" : ""
            )
        }
        .confirmationDialog(
            ExportWarningCatalog.clearStudentWorkWarning.title.trimmingCharacters(in: .whitespacesAndNewlines),
            isPresented: $showingClearConfirm,
            titleVisibility: .visible
        ) {
            Button(ExportWarningCatalog.clearStudentWorkWarning.primaryButton.trimmingCharacters(in: .whitespacesAndNewlines), role: .destructive) {
                Task { await session.clearStudentWork() }
            }
            .accessibilityIdentifier("studentWork.clearConfirm")
            Button(ExportWarningCatalog.clearStudentWorkWarning.secondaryButton.trimmingCharacters(in: .whitespacesAndNewlines), role: .cancel) {}
        } message: {
            Text(ExportWarningCatalog.clearStudentWorkWarning.body.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    // MARK: - Sections

    private func headerSection(_ graph: SubmissionGraph, setup: AssignmentSetup) -> some View {
        Section {
            LabeledContent("Student", value: graph.student.displayName)
            LabeledContent("Assignment", value: setup.assignment.title)
            if !session.className.isEmpty {
                LabeledContent("Class", value: session.className)
            }
            if let status = try? graph.rosterStatus(setup: setup) {
                StatusLabel(status.uiStatus, subject: "Grading status")
            }
        }
    }

    @ViewBuilder
    private var workStatusSections: some View {
        if let kind = session.runningWork {
            Section {
                Label {
                    Text(kind.displayName)
                } icon: {
                    ProgressView()
                }
            } footer: {
                Text("This keeps running if you leave this screen. The result is saved for this student only.")
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
                    .accessibilityIdentifier("studentWork.dismissFailure")
            }
        }
    }

    private var addWorkSection: some View {
        Section {
            Button {
                showingScanner = true
            } label: {
                Label("Scan Paper Work", systemImage: "doc.viewfinder")
            }
            .disabled(!VNDocumentCameraViewController.isSupported || isBusy)
            .accessibilityIdentifier("studentWork.scan")
            if !VNDocumentCameraViewController.isSupported {
                Text("Document scanning is not available on this device. Choose photos, import a PDF, or paste text instead.")
                    .foregroundStyle(.secondary)
            }

            PhotosPicker(selection: $photoItems, maxSelectionCount: 20, selectionBehavior: .ordered, matching: .images) {
                Label("Choose Photos", systemImage: "photo.on.rectangle")
            }
            .disabled(isBusy)
            .accessibilityIdentifier("studentWork.choosePhotos")

            Button {
                showingPDFImporter = true
            } label: {
                Label("Import PDF", systemImage: "doc.richtext")
            }
            .disabled(isBusy)
            .accessibilityIdentifier("studentWork.importPDF")

            Button {
                showingPasteSheet = true
            } label: {
                Label("Paste Text", systemImage: "doc.on.clipboard")
            }
            .disabled(isBusy)
            .accessibilityIdentifier("studentWork.pasteText")
        } header: {
            Text("Add Student Work")
        } footer: {
            Text("Work is read on this device; nothing is uploaded. Adding new work replaces this student's current work.")
        }
    }

    private func attachmentsSection(_ graph: SubmissionGraph) -> some View {
        Section("Attached Files") {
            if graph.sources.isEmpty {
                if graph.submission.inputKind == .none {
                    ContentUnavailableView(
                        "Add student work",
                        systemImage: "doc.badge.plus",
                        description: Text("Scan, choose photos, import a PDF, or paste text.")
                    )
                } else {
                    Text(graph.submission.inputKind == .pasted ? "Pasted text has no attached file." : "No original files are attached.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(graph.sources) { source in
                    LabeledContent {
                        Text(source.includedInTeacherArchive ? "In Teacher Record" : "Kept on device")
                    } label: {
                        Label(sourceTitle(source), systemImage: sourceIcon(source.sourceType))
                        if let detail = sourceDetail(source) {
                            Text(detail)
                        }
                    }
                }
            }
        }
    }

    private func reviewedTextSection(_ graph: SubmissionGraph) -> some View {
        Section {
            if graph.reviewedText.isWhitespaceOnly {
                Text("No reviewed text has been saved for this student.")
                    .foregroundStyle(.secondary)
            } else {
                Text(graph.reviewedText)
                    .textSelection(.enabled)
            }
        } header: {
            Text("Reviewed Text")
        } footer: {
            if graph.submission.inputKind == .scanned, graph.ocr?.reviewStatus != .reviewed {
                Text("Scanned text is used for grading only after you review it.")
            }
        }
    }

    private func nextStepsSection(_ graph: SubmissionGraph) -> some View {
        let readiness = session.readiness
        return Section("Next Steps") {
            if graph.submission.inputKind == .scanned {
                NavigationLink(value: Route.scannedText(session.id)) {
                    LabeledContent {
                        StatusLabel(readiness?.isScannedTextReviewed == true ? .onTrack : .reviewScannedText, subject: "Scanned text status")
                    } label: {
                        Label("Review Scanned Text", systemImage: "text.viewfinder")
                    }
                }
                .accessibilityIdentifier("studentWork.scannedText")
            }
            NavigationLink(value: Route.aiDraft(session.id)) {
                Label("AI Draft", systemImage: "sparkles")
            }
            .accessibilityIdentifier("studentWork.aiDraft")
            NavigationLink(value: Route.finalReview(session.id)) {
                Label("Final Review", systemImage: "checklist")
            }
            .accessibilityIdentifier("studentWork.finalReview")
            NavigationLink(value: Route.submissionExports(session.id)) {
                Label("Exports", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("studentWork.exports")
            ForEach(readiness?.finalReviewStartIssues ?? [], id: \.self) { issue in
                Label(issue.message, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func clearSection(_ graph: SubmissionGraph) -> some View {
        Section {
            Button(role: .destructive) {
                showingClearConfirm = true
            } label: {
                Label("Clear Work", systemImage: "trash")
            }
            .disabled(graph.submission.inputKind == .none || isBusy)
            .accessibilityIdentifier("studentWork.clear")
        } footer: {
            Text("Removes this student's work, scanned text and evidence from this device.")
        }
    }

    // MARK: - Helpers

    /// Loads every chosen photo in the order picked. If any photo cannot be read, none is imported.
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        defer { photoItems = [] }
        var images: [Data] = []
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    session.alert = AlertMessage(title: "Photos not imported", message: "One of the selected photos could not be read. No photos were imported.")
                    return
                }
                images.append(data)
            } catch {
                session.alert = AlertMessage(title: "Photos not imported", error: error)
                return
            }
        }
        session.importPhotos(images)
    }

    private func sourceTitle(_ source: SourceInputRef) -> String {
        if let fileName = source.fileName, !fileName.isWhitespaceOnly { return fileName }
        if let pageIndex = source.pageIndex { return "\(source.sourceType.displayName), page \(pageIndex + 1)" }
        return source.sourceType.displayName
    }

    private func sourceDetail(_ source: SourceInputRef) -> String? {
        if let pages = source.pdfPageCount { return "\(pages) page(s)" }
        if let width = source.pixelWidth, let height = source.pixelHeight { return "\(width) × \(height) pixels" }
        return nil
    }

    private func sourceIcon(_ type: SourceType) -> String {
        switch type {
        case .pastedText: return "doc.plaintext"
        case .scan: return "doc.viewfinder"
        case .photo: return "photo"
        case .pdf: return "doc.richtext"
        case .handwrittenWork: return "pencil.and.scribble"
        case .visualArtifact: return "photo.artframe"
        }
    }
}

/// Pasted student work. Saving records it as teacher-reviewed text and replaces the current work.
private struct PasteStudentWorkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: SubmissionSession
    @State private var text: String
    @State private var isSaving = false

    init(session: SubmissionSession, initialText: String) {
        self.session = session
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Student work", text: $text, axis: .vertical)
                        .accessibilityIdentifier("pasteWork.text")
                } footer: {
                    Text("Saving records this text as teacher-reviewed student work and replaces any work already attached for this student.")
                }
            }
            .navigationTitle("Paste Student Work")
            .navigationBarTitleDisplayMode(.inline)
            .alertMessage($session.alert)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("pasteWork.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save as Reviewed") {
                        isSaving = true
                        Task {
                            await session.savePastedText(text)
                            isSaving = false
                            if session.alert == nil { dismiss() }
                        }
                    }
                    .disabled(text.isWhitespaceOnly || isSaving)
                    .accessibilityIdentifier("pasteWork.save")
                }
            }
        }
    }
}

#if DEBUG
#Preview("Light") {
    ScreenPreview { app in RouteDestination(route: .submission(PreviewFixtures.scannedSubmissionID), app: app) }
}

#Preview("Dark") {
    ScreenPreview { app in RouteDestination(route: .submission(PreviewFixtures.noWorkSubmissionID), app: app) }
        .preferredColorScheme(.dark)
}

#Preview("Accessibility XXXL") {
    ScreenPreview { app in RouteDestination(route: .submission(PreviewFixtures.approvedSubmissionID), app: app) }
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
