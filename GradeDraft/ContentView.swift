import PhotosUI
import SwiftUI
import VisionKit

struct ContentView: View {
    @StateObject private var viewModel = GradeDraftViewModel()
    @State private var showingScanner = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedTemplateID: String = RubricTemplates.builtIn.first?.id ?? ""

    var body: some View {
        NavigationSplitView {
            assignmentList
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LocalCapabilityBanner(status: viewModel.localAIStatus, message: viewModel.statusMessage)
                    assignmentSection
                    captureSection
                    ocrReviewSection
                    rubricSection
                    gradingSection
                    exportSection
                }
                .padding()
                .frame(maxWidth: 980, alignment: .leading)
            }
            .navigationTitle(viewModel.assignment.title)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Duplicate") { viewModel.duplicateCurrentAssignment() }
                    Button("Save") { save() }
                }
            }
            .task { viewModel.refreshCapabilityStatus() }
            .sheet(isPresented: $showingScanner) {
                DocumentScannerView { images in
                    Task { await viewModel.applyScannedImages(images) }
                } onCancel: {
                    viewModel.statusMessage = "Scan canceled."
                } onError: { error in
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            .alert("GradeDraft", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }

    private var assignmentList: some View {
        List(selection: $viewModel.selectedAssignmentID) {
            Section {
                ForEach(viewModel.assignments) { assignment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assignment.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(listSubtitle(for: assignment))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .tag(assignment.id)
                    .onTapGesture { viewModel.selectAssignment(assignment.id) }
                }
            } header: {
                Text("Assignments")
            }
        }
        .navigationTitle("GradeDraft")
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { viewModel.newAssignment() } label: {
                    Label("New", systemImage: "plus")
                }
                Button(role: .destructive) { viewModel.deleteCurrentAssignment() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var assignmentSection: some View {
        CardSection(title: "Assignment", systemImage: "tray.full") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("Title")
                        .foregroundStyle(.secondary)
                    TextField("Assignment title", text: assignmentBinding(\.title))
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Subject")
                        .foregroundStyle(.secondary)
                    TextField("Subject", text: assignmentBinding(\.subject))
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Grade level")
                        .foregroundStyle(.secondary)
                    TextField("Grade level", text: assignmentBinding(\.gradeLevel))
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Type")
                        .foregroundStyle(.secondary)
                    Picker("Assignment type", selection: assignmentBinding(\.assignmentType)) {
                        ForEach(AssignmentType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private var captureSection: some View {
        CardSection(title: "Student work", systemImage: "doc.text.viewfinder") {
            Text("Scan printed student work, import a photo, or paste text directly. The reviewed text below is the only content sent to the local grading model.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    showingScanner = true
                } label: {
                    Label("Scan", systemImage: "doc.viewfinder")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!VNDocumentCameraViewController.isSupported || viewModel.isWorking)

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Import Photo", systemImage: "photo")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isWorking)
                .onChange(of: selectedPhoto) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await viewModel.applyScannedImages([image])
                        }
                        selectedPhoto = nil
                    }
                }

                Button("Clear OCR") {
                    viewModel.updateAssignment { assignment in
                        assignment.ocrDocument = nil
                        assignment.reviewedStudentText = ""
                        assignment.latestDraft = nil
                        assignment.finalReview = nil
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.assignment.reviewedStudentText.isEmpty)
            }

            if !VNDocumentCameraViewController.isSupported {
                Label("Document scanning is not supported on this device.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var ocrReviewSection: some View {
        CardSection(title: "Reviewed student text", systemImage: "text.quote") {
            HStack {
                Text(viewModel.qualitySummary.displaySummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.hasLowConfidenceOCR {
                    Label("Review OCR", systemImage: "exclamationmark.triangle")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }

            TextEditor(text: assignmentBinding(\.reviewedStudentText))
                .frame(minHeight: 260)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if viewModel.assignment.reviewedStudentText.isEmpty {
                        Text("Paste or scan student text here...")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

            if let ocrDocument = viewModel.assignment.ocrDocument, !ocrDocument.pages.isEmpty {
                DisclosureGroup("OCR evidence and confidence") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(ocrDocument.pages, id: \.pageIndex) { page in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Page \(page.pageIndex + 1)")
                                    .font(.headline)
                                ForEach(page.lines) { line in
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(line.text)
                                            .font(.caption)
                                            .textSelection(.enabled)
                                        Spacer()
                                        Text("\(Int(line.confidence * 100))%")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(line.confidence < OCRQualitySummary.lowConfidenceThreshold ? .orange : .secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var rubricSection: some View {
        CardSection(title: "Rubric and instructions", systemImage: "list.bullet.clipboard") {
            HStack(alignment: .top, spacing: 12) {
                Picker("Template", selection: $selectedTemplateID) {
                    ForEach(RubricTemplates.builtIn) { template in
                        Text(template.name).tag(template.id)
                    }
                }
                .pickerStyle(.menu)

                Button("Apply Template") {
                    guard let template = RubricTemplates.builtIn.first(where: { $0.id == selectedTemplateID }) else { return }
                    viewModel.applyTemplate(template)
                }
                .buttonStyle(.bordered)
            }

            TextEditor(text: assignmentBinding(\.rubricText))
                .frame(minHeight: 180)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if viewModel.assignment.rubricText.isEmpty {
                        Text("Paste rubric, answer key, or grading criteria...")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

            TextEditor(text: assignmentBinding(\.customInstructions))
                .frame(minHeight: 110)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if viewModel.assignment.customInstructions.isEmpty {
                        Text("Optional custom grading rules, such as spelling leniency or required evidence...")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var gradingSection: some View {
        CardSection(title: "Draft and finalize", systemImage: "checklist.checked") {
            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.draftGrade() }
                } label: {
                    if viewModel.isWorking {
                        ProgressView()
                    } else {
                        Label("Draft Grade", systemImage: "checklist")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canDraftGrade)

                Button("Finalize Draft") { viewModel.finalizeLatestDraft() }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.assignment.latestDraft == nil)
            }

            Text("The generated grade is a draft for teacher review. The app calculates totals from criterion scores instead of trusting model-written totals.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let finalReview = viewModel.assignment.finalReview {
                FinalGradeReviewView(review: finalReview) { updated in
                    viewModel.updateFinalReview(updated)
                }
                .id(finalReview.id)
            } else if let result = viewModel.assignment.latestDraft {
                GradeResultView(result: result)
            } else {
                EmptyStateView(
                    title: "No draft yet",
                    message: "Add reviewed student text and a rubric, then generate a local draft grade."
                )
            }
        }
    }

    private var exportSection: some View {
        CardSection(title: "Local export", systemImage: "square.and.arrow.up") {
            Text("Export creates a local Markdown report from saved app state. Sharing is explicit and teacher-controlled.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("Prepare Report") { viewModel.exportCurrentAssignmentReport() }
                    .buttonStyle(.bordered)

                if let exportURL = viewModel.exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share Report", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func save() {
        do {
            try viewModel.saveCurrentAssignment()
            viewModel.statusMessage = "Assignment saved locally."
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func assignmentBinding<Value>(_ keyPath: WritableKeyPath<AssignmentRecord, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.assignment[keyPath: keyPath] },
            set: { newValue in
                viewModel.updateAssignment { assignment in
                    assignment[keyPath: keyPath] = newValue
                    assignment.latestDraft = nil
                    assignment.finalReview = nil
                }
            }
        )
    }

    private func listSubtitle(for assignment: AssignmentRecord) -> String {
        let state: String
        if assignment.finalReview != nil {
            state = "Finalized"
        } else if assignment.latestDraft != nil {
            state = "Drafted"
        } else if !assignment.reviewedStudentText.isEmpty {
            state = "Text ready"
        } else {
            state = "Setup"
        }
        return "\(assignment.assignmentType.displayName) · \(state)"
    }
}

private struct CardSection<Content: View>: View {
    var title: String
    var systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.title2.bold())
            }
            content
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}

private struct EmptyStateView: View {
    var title: String
    var message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
