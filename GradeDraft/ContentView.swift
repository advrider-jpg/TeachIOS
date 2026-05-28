import PhotosUI
import SwiftUI
import VisionKit

struct ContentView: View {
    @StateObject private var viewModel = GradeDraftViewModel()
    @State private var showingScanner = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedTemplateID: String = RubricTemplates.builtIn.first?.id ?? ""

    // Export warning state
    @State private var showingStudentReportWarning = false
    @State private var showingTeacherAuditWarning = false
    @State private var showingCSVWarning = false

    var body: some View {
        NavigationSplitView {
            assignmentList
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LocalCapabilityBanner(status: viewModel.localAIStatus, message: viewModel.statusMessage)
                    readinessSection
                    assignmentSection
                    captureSection
                    ocrReviewSection
                    rubricSection
                    gradingSection
                    exportSection
                }
                .padding()
                .frame(maxWidth: 1040, alignment: .leading)
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
            // Student report export warning
            .confirmationDialog(
                "Review student-facing report",
                isPresented: $showingStudentReportWarning,
                titleVisibility: .visible
            ) {
                Button("Export Student Report") {
                    viewModel.exportStudentReport()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This report is intended for student or family review. Confirm that it includes only the feedback, scores, and evidence you want the student or family to see.\n\nTeacher-only notes and internal review flags are excluded by default.")
            }
            // Teacher audit export warning
            .confirmationDialog(
                "Export teacher-only grading record?",
                isPresented: $showingTeacherAuditWarning,
                titleVisibility: .visible
            ) {
                Button("Export Teacher Record") {
                    viewModel.exportTeacherAuditReport()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This file may include internal grading notes, draft scores, rubric reasoning, OCR uncertainty flags, and teacher annotations. It is not intended for students or families unless reviewed and redacted.")
            }
            // CSV export warning
            .confirmationDialog(
                "Export spreadsheet data?",
                isPresented: $showingCSVWarning,
                titleVisibility: .visible
            ) {
                Button("Export CSV") {
                    viewModel.exportCSVGradebook()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This CSV may include student names, scores, grades, rubric labels, and comments. Use only approved school storage and transfer methods.\n\nGradeDraft neutralizes spreadsheet formula-injection risks before export. Review free-text fields before sharing.")
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

    private var readinessSection: some View {
        CardSection(title: "Readiness", systemImage: "checkmark.shield") {
            Text(viewModel.persistenceSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if viewModel.readinessIssues.isEmpty {
                Label("Ready for local draft feedback.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.readinessIssues, id: \.self) { issue in
                        Label(issue, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
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
                    Text("Prompt")
                        .foregroundStyle(.secondary)
                    TextField("Assignment question or prompt (optional)", text: promptBinding)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Student")
                        .foregroundStyle(.secondary)
                    TextField("Student name or local identifier", text: assignmentBinding(\.studentDisplayName))
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Class")
                        .foregroundStyle(.secondary)
                    TextField("Class or section", text: assignmentBinding(\.className))
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
            Text("Scan printed student work, import a photo, or paste text directly. OCR text must be marked reviewed before local grading.")
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
                            await viewModel.applyPhotoImages([image])
                        } else {
                            viewModel.errorMessage = "The selected photo could not be imported."
                        }
                        selectedPhoto = nil
                    }
                }

                Button("Clear Source") {
                    viewModel.updateAssignment { assignment in
                        assignment.ocrDocument = nil
                        assignment.ocrReviewStatus = .notNeeded
                        assignment.ocrReviewedAt = nil
                        assignment.sourceInputs = []
                        assignment.reviewedStudentText = ""
                        assignment.latestDraft = nil
                        assignment.finalReview = nil
                        assignment.appendAuditEvent(.inputChanged, detail: "Teacher cleared source input and OCR text.")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.assignment.reviewedStudentText.isEmpty && viewModel.assignment.sourceInputs.isEmpty)
            }

            if !VNDocumentCameraViewController.isSupported {
                Label("Document scanning is not supported on this device.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if !viewModel.assignment.sourceInputs.isEmpty {
                DisclosureGroup("Stored local source references") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.assignment.sourceInputs) { source in
                            Text("\(source.sourceType.displayName) · page \(source.pageIndex.map { String($0 + 1) } ?? "n/a") · \(source.contentDigest ?? "no digest")")
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.top, 6)
                }
            }
        }
    }

    private var ocrReviewSection: some View {
        CardSection(title: "Reviewed student text", systemImage: "text.quote") {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.qualitySummary.displaySummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("OCR review status: \(viewModel.assignment.ocrReviewStatus.displayName)")
                        .font(.caption)
                        .foregroundStyle(viewModel.assignment.ocrReviewStatus.blocksGrading ? .orange : .secondary)
                }
                Spacer()
                if viewModel.assignment.ocrReviewStatus.blocksGrading {
                    Button("Mark OCR Reviewed") { viewModel.markOCRReviewed() }
                        .buttonStyle(.borderedProminent)
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

            Button("Treat Current Text as Pasted / Teacher Reviewed") {
                viewModel.applyPastedStudentText(viewModel.assignment.reviewedStudentText)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.assignment.reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let ocrDocument = viewModel.assignment.ocrDocument, !ocrDocument.pages.isEmpty {
                DisclosureGroup("OCR evidence, confidence, and review state") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(ocrDocument.pages) { page in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Page \(page.pageIndex + 1)")
                                    .font(.headline)
                                ForEach(page.lines) { line in
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(line.reviewedText)
                                            .font(.caption)
                                            .textSelection(.enabled)
                                        Spacer()
                                        if line.teacherConfirmed {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        }
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
        CardSection(title: "Rubric, answer key, and instructions", systemImage: "list.bullet.clipboard") {
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

            if !viewModel.assignment.parsedRubric.criteria.isEmpty {
                DisclosureGroup("Detected structured criteria") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.assignment.parsedRubric.criteria) { criterion in
                            Text("\(criterion.id): \(criterion.title) — \(GradeTotals.formatted(criterion.maxPoints)) pts")
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.top, 6)
                }
            } else if !viewModel.assignment.rubricText.isEmpty {
                Label("No structured point-bearing criteria detected. Drafts will require teacher review.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Text("Rubric / grading criteria")
                .font(.headline)
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

            Text("Custom teacher instructions")
                .font(.headline)
            TextEditor(text: assignmentBinding(\.customInstructions))
                .frame(minHeight: 100)
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

            Text("Answer key")
                .font(.headline)
            TextEditor(text: assignmentBinding(\.answerKeyText))
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("Exemplar response")
                .font(.headline)
            TextEditor(text: assignmentBinding(\.exemplarText))
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                        Label("Draft Feedback Suggestion", systemImage: "checklist")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canDraftGrade)

                Button("Start Teacher Final Review") { viewModel.startFinalReviewFromLatestDraft() }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.assignment.latestDraft == nil || viewModel.assignment.latestDraftIsStale)
            }

            Text("The generated suggestion is a draft for teacher review. The app calculates totals from criterion scores instead of trusting model-written totals.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let finalReview = viewModel.assignment.finalReview {
                FinalGradeReviewView(
                    review: finalReview,
                    isStale: viewModel.assignment.finalReviewIsStale,
                    onChange: { updated in viewModel.updateFinalReview(updated) },
                    onApprove: { viewModel.approveFinalReview() }
                )
                .id(finalReview.id)
            } else if let result = viewModel.assignment.latestDraft {
                GradeResultView(result: result, isStale: viewModel.assignment.latestDraftIsStale)
            } else {
                EmptyStateView(
                    title: "No draft yet",
                    message: "Add reviewed student text and a rubric, confirm OCR if needed, then generate a local draft feedback suggestion."
                )
            }
        }
    }

    private var exportSection: some View {
        CardSection(title: "Local export", systemImage: "square.and.arrow.up") {
            Text("Exports are generated locally. Student reports exclude private teacher notes by default. Teacher audit reports may contain sensitive student data, OCR state, and private notes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("Preview Student Report") {
                    showingStudentReportWarning = true
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canExportStudentReport)

                Button("Export Teacher Audit Report") {
                    showingTeacherAuditWarning = true
                }
                .buttonStyle(.bordered)

                Button("Export CSV") {
                    showingCSVWarning = true
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.assignment.finalReview == nil && viewModel.assignment.latestDraft == nil)

                if let exportURL = viewModel.exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share \(viewModel.exportKind?.displayName ?? "Report")", systemImage: "square.and.arrow.up")
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
                }
            }
        )
    }

    /// Binding for the optional `prompt` field, presenting nil as an empty string.
    private var promptBinding: Binding<String> {
        Binding(
            get: { viewModel.assignment.prompt ?? "" },
            set: { newValue in
                viewModel.updateAssignment { assignment in
                    assignment.prompt = newValue.isEmpty ? nil : newValue
                }
            }
        )
    }

    private func listSubtitle(for assignment: AssignmentRecord) -> String {
        let state: String
        if assignment.finalReview?.status == .approved {
            state = "Final approved"
        } else if assignment.finalReview != nil {
            state = "Final review"
        } else if assignment.latestDraftIsStale {
            state = "Draft stale"
        } else if assignment.latestDraft != nil {
            state = "Drafted"
        } else if assignment.ocrReviewStatus.blocksGrading {
            state = "Needs OCR review"
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
