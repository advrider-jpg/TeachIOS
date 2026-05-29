import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

// MARK: - Share sheet bridge

private struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var viewModel = GradeDraftViewModel()
    @State private var showingScanner = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedTemplateID: String = RubricTemplates.builtIn.first?.id ?? ""
    @State private var rosterCSV = ""
    @State private var newClassName = ""
    @State private var newStudentName = ""
    @State private var newStudentLocalID = ""

    @State private var showingPDFImporter = false
    @State private var showingRubricImporter = false
    @State private var showingCurriculumImporter = false
    @State private var showingBackupImporter = false

    @State private var showingStudentReportWarning = false
    @State private var showingTeacherAuditWarning = false
    @State private var showingCSVWarning = false
    @State private var showingArchiveWarning = false
    @State private var showingBackupWarning = false
    @State private var pendingStudentExportKind: ExportKind = .studentMarkdown
    @State private var pendingTeacherExportKind: ExportKind = .teacherAuditMarkdown

    @State private var showingOCRReviewConfirm = false
    @State private var selectedOCRPageID: UUID?
    @State private var selectedOCRLineID: UUID?
    @State private var selectedEvidenceCriterionID: UUID?

    @State private var showingShareSheetWarning = false
    @State private var readyToShareFile = false

    var body: some View {
        NavigationSplitView {
            assignmentList
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LocalCapabilityBanner(status: viewModel.localAIStatus, message: viewModel.statusMessage)
                    readinessSection
                    assignmentSection
                    rosterSection
                    captureSection
                    ocrReviewSection
                    rubricSection
                    gradingSection
                    exportSection
                    aboutSection
                }
                .padding()
                .frame(maxWidth: 1100, alignment: .leading)
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
            .sheet(isPresented: $readyToShareFile) {
                if let url = viewModel.exportURL {
                    ActivityViewController(items: [url])
                }
            }
            .fileImporter(isPresented: $showingPDFImporter, allowedContentTypes: [.pdf]) { result in
                if case .success(let url) = result {
                    Task { await viewModel.applyPDFFile(url) }
                }
            }
            .fileImporter(isPresented: $showingRubricImporter, allowedContentTypes: [.plainText, .item]) { result in
                if case .success(let url) = result {
                    viewModel.importMarkdownRubric(from: url)
                }
            }
            .fileImporter(isPresented: $showingCurriculumImporter, allowedContentTypes: [.plainText, .commaSeparatedText, .item]) { result in
                if case .success(let url) = result {
                    viewModel.importCurriculumReference(from: url)
                }
            }
            .fileImporter(isPresented: $showingBackupImporter, allowedContentTypes: [.json, .zip, .item]) { result in
                if case .success(let url) = result {
                    viewModel.restoreBackup(from: url)
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
            .confirmationDialog("Mark OCR reviewed?", isPresented: $showingOCRReviewConfirm, titleVisibility: .visible) {
                Button("Mark Reviewed") { viewModel.markOCRReviewed() }
                Button("Keep Reviewing", role: .cancel) {}
            } message: {
                Text("Only continue if the text shown here accurately reflects the student work you want GradeDraft to use. The app will draft feedback from this reviewed text, not from the original image.")
            }
            .confirmationDialog("Review student-facing report", isPresented: $showingStudentReportWarning, titleVisibility: .visible) {
                Button(pendingStudentExportKind == .studentPDF ? "Export PDF" : "Export Student Report") {
                    if pendingStudentExportKind == .studentPDF {
                        viewModel.exportStudentPDF()
                    } else {
                        viewModel.exportStudentReport()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This report is intended for student or family review. Confirm that it includes only the feedback, scores, and evidence you want the student or family to see. Teacher-only notes and internal review flags should not be included unless you intentionally add them.")
            }
            .confirmationDialog("Export teacher-only grading record?", isPresented: $showingTeacherAuditWarning, titleVisibility: .visible) {
                Button(pendingTeacherExportKind == .teacherAuditPDF ? "Export Teacher PDF" : "Export Teacher Record") {
                    if pendingTeacherExportKind == .teacherAuditPDF {
                        viewModel.exportTeacherAuditPDF()
                    } else {
                        viewModel.exportTeacherAuditReport()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This file may include internal grading notes, draft scores, rubric reasoning, OCR uncertainty flags, and teacher annotations. It is not intended for students or families unless reviewed and redacted.")
            }
            .confirmationDialog("Export spreadsheet data?", isPresented: $showingCSVWarning, titleVisibility: .visible) {
                Button("Export CSV") { viewModel.exportCSVGradebook() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This CSV may include student names, scores, grades, rubric labels, and comments. CSV files are easy to copy, upload, email, and re-import into other systems. GradeDraft neutralizes spreadsheet formula-injection risks before export.")
            }
            .confirmationDialog("Export archive with source files?", isPresented: $showingArchiveWarning, titleVisibility: .visible) {
                Button("Export Archive") { viewModel.exportArchiveBundle() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This archive may include scanned work images, OCR text, grading records, feedback drafts, rubrics, and teacher notes. Review which records and source files are included before sharing.")
            }
            .confirmationDialog("Export structured data?", isPresented: $showingBackupWarning, titleVisibility: .visible) {
                Button("Export Backup Archive") { viewModel.exportBackupJSON() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This backup archive may contain full assignment records, OCR text, source files, rubric data, scores, feedback, teacher notes, and internal metadata. Backups may reveal more information than a student-facing report.")
            }
            .confirmationDialog("Share outside the app?", isPresented: $showingShareSheetWarning, titleVisibility: .visible) {
                Button("Open Share Sheet") { readyToShareFile = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You are about to send a file or text to another app. GradeDraft cannot control how that destination app stores, syncs, forwards, or protects the information.")
            }
        }
    }

    private var assignmentList: some View {
        List(selection: $viewModel.selectedAssignmentID) {
            Section("Assignments") {
                ForEach(viewModel.assignments) { assignment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assignment.title).font(.headline).lineLimit(1)
                        Text(listSubtitle(for: assignment)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    .tag(assignment.id)
                    .onTapGesture { viewModel.selectAssignment(assignment.id) }
                }
            }
        }
        .navigationTitle("GradeDraft")
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { viewModel.newAssignment() } label: { Label("New", systemImage: "plus") }
                Button(role: .destructive) { viewModel.deleteCurrentAssignment() } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }

    private var readinessSection: some View {
        CardSection(title: "Readiness", systemImage: "checkmark.shield") {
            Text(viewModel.persistenceSummary).font(.subheadline).foregroundStyle(.secondary)
            if viewModel.readinessIssues.isEmpty {
                Label("Ready for local draft feedback.", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.readinessIssues, id: \.self) { issue in
                        Label(issue, systemImage: "exclamationmark.triangle").font(.subheadline).foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var assignmentSection: some View {
        CardSection(title: "Assignment", systemImage: "tray.full") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow { Text("Title").foregroundStyle(.secondary); TextField("Assignment title", text: assignmentBinding(\.title)).textFieldStyle(.roundedBorder) }
                GridRow { Text("Prompt").foregroundStyle(.secondary); TextField("Assignment question or prompt", text: promptBinding).textFieldStyle(.roundedBorder) }
                GridRow { Text("Student").foregroundStyle(.secondary); TextField("Student name or local identifier", text: assignmentBinding(\.studentDisplayName)).textFieldStyle(.roundedBorder) }
                GridRow { Text("Class").foregroundStyle(.secondary); TextField("Class or section", text: assignmentBinding(\.className)).textFieldStyle(.roundedBorder) }
                GridRow { Text("Subject").foregroundStyle(.secondary); TextField("Subject", text: assignmentBinding(\.subject)).textFieldStyle(.roundedBorder) }
                GridRow { Text("Grade level").foregroundStyle(.secondary); TextField("Grade level", text: assignmentBinding(\.gradeLevel)).textFieldStyle(.roundedBorder) }
                GridRow {
                    Text("Type").foregroundStyle(.secondary)
                    Picker("Assignment type", selection: assignmentBinding(\.assignmentType)) {
                        ForEach(AssignmentType.allCases) { type in Text(type.displayName).tag(type) }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private var rosterSection: some View {
        CardSection(title: "Classes, students, roster, and gradebook", systemImage: "person.3") {
            Text("Manage local class rosters, preview CSV imports, create per-student assignment records, and review gradebook status without accounts or cloud services.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow { Text("Classes").foregroundStyle(.secondary); Text(viewModel.classGroups.map(\.name).joined(separator: ", ").nilIfEmpty ?? "No class records saved yet.") }
                GridRow { Text("Students").foregroundStyle(.secondary); Text("\(viewModel.students.count) local student record(s)") }
                GridRow { Text("Roster status").foregroundStyle(.secondary); Text("\(viewModel.assignmentRosterEntries.count) per-student assignment record(s)") }
            }
            .font(.caption)

            VStack(alignment: .leading, spacing: 8) {
                Text("Quick class and student records").font(.headline)
                HStack {
                    TextField("Class name", text: $newClassName)
                        .textFieldStyle(.roundedBorder)
                    Button("Save Class") {
                        viewModel.saveClassGroup(ClassGroupRecord(name: newClassName, subject: viewModel.assignment.subject, gradeLevel: viewModel.assignment.gradeLevel))
                        newClassName = ""
                    }
                    .buttonStyle(.bordered)
                    .disabled(newClassName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if !viewModel.classGroups.isEmpty {
                    ForEach(viewModel.classGroups.prefix(6)) { classGroup in
                        HStack {
                            Text(classGroup.name)
                            Spacer()
                            Button("Delete", role: .destructive) { viewModel.deleteClassGroup(id: classGroup.id) }
                                .font(.caption)
                        }
                        .font(.caption)
                    }
                }
                HStack {
                    TextField("Student display name", text: $newStudentName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Local ID", text: $newStudentLocalID)
                        .textFieldStyle(.roundedBorder)
                    Button("Save Student") {
                        viewModel.saveStudent(StudentRecord(displayName: newStudentName, className: newClassName.isEmpty ? viewModel.assignment.className : newClassName, localIdentifier: newStudentLocalID))
                        newStudentName = ""
                        newStudentLocalID = ""
                    }
                    .buttonStyle(.bordered)
                    .disabled(newStudentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if !viewModel.students.isEmpty {
                    ForEach(viewModel.students.prefix(8)) { student in
                        HStack {
                            Text(student.displayName)
                            if !student.localIdentifier.isEmpty { Text("· \(student.localIdentifier)").foregroundStyle(.secondary) }
                            Spacer()
                            Button("Delete", role: .destructive) { viewModel.deleteStudent(id: student.id) }
                                .font(.caption)
                        }
                        .font(.caption)
                    }
                }
            }

            TextEditor(text: $rosterCSV)
                .frame(minHeight: 90)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 12) {
                Button("Preview Roster CSV") { _ = viewModel.previewRosterCSV(rosterCSV) }
                    .buttonStyle(.bordered)
                    .disabled(rosterCSV.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Create Assignments From Roster") { viewModel.createAssignmentsFromRosterCSV(rosterCSV) }
                    .buttonStyle(.borderedProminent)
                    .disabled(rosterCSV.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let preview = viewModel.latestRosterPreview {
                DisclosureGroup("Roster import preview") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Class: \(preview.className.isEmpty ? viewModel.assignment.className : preview.className)")
                        Text("Accepted students: \(preview.students.count)")
                        if !preview.duplicateNames.isEmpty { Text("Duplicate names/IDs: \(preview.duplicateNames.joined(separator: ", "))").foregroundStyle(.orange) }
                        ForEach(preview.rejectedRowDetails) { rejected in
                            Text("Row \(rejected.rowNumber): \(rejected.reason)")
                                .foregroundStyle(.red)
                        }
                        ForEach(preview.warnings, id: \.self) { warning in Text(warning).foregroundStyle(.orange) }
                    }
                    .font(.caption)
                }
            }

            if !viewModel.gradebookAssignments.isEmpty {
                DisclosureGroup("Gradebook summary") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.gradebookAssignments.prefix(20)) { record in
                            HStack {
                                Text(record.studentDisplayName.isEmpty ? "Unnamed student" : record.studentDisplayName)
                                Spacer()
                                Text(viewModel.assignmentRosterStatus(for: record).displayName)
                                    .foregroundStyle(.secondary)
                                if let final = record.finalReview {
                                    Text("\(GradeTotals.formatted(final.totalScore)) / \(GradeTotals.formatted(final.maxScore))")
                                        .monospacedDigit()
                                }
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
    }

    private var captureSection: some View {
        CardSection(title: "Student work", systemImage: "doc.text.viewfinder") {
            Text("Scan printed work, import a photo or PDF, or paste text directly. OCR text must be reviewed before grading.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button { showingScanner = true } label: { Label("Scan", systemImage: "doc.viewfinder") }
                    .buttonStyle(.borderedProminent)
                    .disabled(!VNDocumentCameraViewController.isSupported || viewModel.isWorking)

                PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("Import Photo", systemImage: "photo") }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isWorking)
                    .onChange(of: selectedPhoto) { _, newItem in
                        guard let newItem else { return }
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                                await viewModel.applyPhotoImages([image])
                            } else {
                                viewModel.errorMessage = "The selected photo could not be imported."
                            }
                            selectedPhoto = nil
                        }
                    }

                Button("Import PDF") { showingPDFImporter = true }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isWorking)

                Button("Clear Source") { clearSource() }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.assignment.reviewedStudentText.isEmpty && viewModel.assignment.sourceInputs.isEmpty)
            }

            Button("Treat Current Text as Pasted / Teacher Reviewed") {
                viewModel.applyPastedStudentText(viewModel.assignment.reviewedStudentText)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.assignment.reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var ocrReviewSection: some View {
        CardSection(title: "Side-by-side OCR review", systemImage: "text.viewfinder") {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.qualitySummary.displaySummary).font(.subheadline).foregroundStyle(.secondary)
                    Text("OCR review status: \(viewModel.assignment.ocrReviewStatus.displayName)").font(.caption).foregroundStyle(viewModel.assignment.ocrReviewStatus.blocksGrading ? .orange : .secondary)
                }
                Spacer()
                if viewModel.assignment.ocrReviewStatus.blocksGrading {
                    Button("Mark OCR Reviewed") { showingOCRReviewConfirm = true }.buttonStyle(.borderedProminent)
                }
            }

            TextEditor(text: assignmentBinding(\.reviewedStudentText))
                .frame(minHeight: 160)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let document = viewModel.assignment.ocrDocument, !document.pages.isEmpty {
                let pages = document.pages.sorted { $0.pageIndex < $1.pageIndex }
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source pages").font(.headline)
                        ForEach(pages) { page in
                            Button {
                                selectedOCRPageID = page.id
                                selectedOCRLineID = nil
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Page \(page.pageIndex + 1)").font(.caption.bold())
                                    if let sourceID = page.sourceInputID,
                                       let source = viewModel.assignment.sourceInputs.first(where: { $0.id == sourceID }),
                                       let image = viewModel.sourceImage(for: source) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: 260, maxHeight: 220)
                                            .border(selectedOCRPageID == page.id ? Color.accentColor : Color.secondary)
                                    } else {
                                        RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)).frame(width: 220, height: 120).overlay(Text("No preview"))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        selectedPagePreview(pages: pages)
                    }
                    Divider()
                    ocrLinesPanel(pages: pages)
                }
            } else {
                Text("No OCR document is attached. Import a scan, photo, or PDF, or paste student text manually.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func selectedPagePreview(pages: [OCRPage]) -> some View {
        let page = pages.first(where: { $0.id == selectedOCRPageID }) ?? pages.first
        if let page {
            let source = page.sourceInputID.flatMap { sourceID in
                viewModel.assignment.sourceInputs.first(where: { $0.id == sourceID })
            }
            OCRPagePreview(
                image: source.flatMap { viewModel.sourceImage(for: $0) },
                page: page,
                selectedLineID: selectedOCRLineID
            )
        }
    }

    private func ocrLinesPanel(pages: [OCRPage]) -> some View {
        let page = pages.first(where: { $0.id == selectedOCRPageID }) ?? pages.first
        return VStack(alignment: .leading, spacing: 8) {
            Text("OCR lines and evidence links").font(.headline)
            if let finalReview = viewModel.assignment.finalReview, !finalReview.criteria.isEmpty {
                Picker("Evidence target", selection: $selectedEvidenceCriterionID) {
                    Text("First criterion").tag(Optional<UUID>.none)
                    ForEach(finalReview.criteria) { criterion in Text(criterion.criterion).tag(Optional(criterion.id)) }
                }
                .pickerStyle(.menu)
            }
            if let page {
                HStack {
                    Text("Page \(page.pageIndex + 1) · \(page.unresolvedLineCount) unresolved line(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Previous/Next Unreviewed") {
                        if let target = viewModel.nextUnreviewedLine(after: selectedOCRLineID) {
                            selectedOCRPageID = target.pageID
                            selectedOCRLineID = target.lineID
                        }
                    }
                    .font(.caption)
                    Button("Mark Page Reviewed") { viewModel.markOCRPageReviewed(pageID: page.id) }
                        .font(.caption)
                }
                ForEach(page.lines) { line in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(line.reviewStatusLabel.capitalized)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(.secondarySystemBackground), in: Capsule())
                            Text("Confidence \(Int(line.confidence * 100))% · bbox \(line.boundingBox.stableDisplay)")
                                .font(.caption.monospaced())
                                .foregroundStyle(line.needsReview ? .orange : .secondary)
                        }
                        Text("Raw: \(line.rawText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Corrected OCR text", text: Binding(
                            get: { line.reviewedText },
                            set: { viewModel.updateOCRLine(pageID: page.id, lineID: line.id, correctedText: $0) }
                        ), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        HStack {
                            Button("Confirm Line") {
                                selectedOCRLineID = line.id
                                viewModel.confirmOCRLine(pageID: page.id, lineID: line.id)
                            }
                            Button("Reject") {
                                selectedOCRLineID = line.id
                                viewModel.rejectOCRLine(pageID: page.id, lineID: line.id)
                            }
                            Button("Add as Evidence") {
                                selectedOCRLineID = line.id
                                selectedOCRPageID = page.id
                                viewModel.addOCRLineEvidenceToFinalReview(pageID: page.id, lineID: line.id, criterionID: selectedEvidenceCriterionID)
                            }
                            .disabled(viewModel.assignment.finalReview == nil || line.reviewedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .font(.caption)
                    }
                    .padding(8)
                    .background(selectedOCRLineID == line.id ? Color.accentColor.opacity(0.10) : Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(selectedOCRLineID == line.id ? Color.accentColor : Color.clear, lineWidth: 1))
                    .onTapGesture {
                        selectedOCRPageID = page.id
                        selectedOCRLineID = line.id
                    }
                }
            }
        }
    }

    private var rubricSection: some View {
        CardSection(title: "Rubric, answer key, curriculum, and instructions", systemImage: "list.bullet.clipboard") {
            HStack(alignment: .top, spacing: 12) {
                Picker("Template", selection: $selectedTemplateID) {
                    ForEach(RubricTemplates.builtIn) { template in Text(template.name).tag(template.id) }
                }
                .pickerStyle(.menu)
                Button("Apply Template") {
                    guard let template = RubricTemplates.builtIn.first(where: { $0.id == selectedTemplateID }) else { return }
                    viewModel.applyTemplate(template)
                }
                .buttonStyle(.bordered)
                Button("Import Markdown Rubric") { showingRubricImporter = true }.buttonStyle(.bordered)
                Button("Import Curriculum Reference") { showingCurriculumImporter = true }.buttonStyle(.bordered)
            }

            if let preview = viewModel.latestRubricPreview {
                DisclosureGroup("Markdown rubric import preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detected \(preview.detectedCriteria.count) criterion/criteria and \(preview.detectedLevels.count) scoring band(s).")
                            .font(.caption)
                        ForEach(preview.detectedCriteria) { criterion in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(criterion.title) — \(GradeTotals.formatted(criterion.maxPoints)) pts")
                                    .font(.caption.bold())
                                if !criterion.levels.isEmpty {
                                    Text(criterion.levels.map { "\($0.label) \(GradeTotals.formatted($0.points))" }.joined(separator: " · "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        ForEach(preview.issues, id: \.id) { issue in
                            Label(issue.message, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        HStack {
                            Button("Confirm Structured Import") { viewModel.confirmMarkdownRubricImport(preview, useStructuredImport: true) }
                                .buttonStyle(.borderedProminent)
                                .disabled(preview.detectedCriteria.isEmpty)
                            Button("Use Raw Rubric Text") { viewModel.confirmMarkdownRubricImport(preview, useStructuredImport: false) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            DisclosureGroup("Local curriculum catalog") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.curriculumCatalog.warning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("Search local curriculum", text: $viewModel.curriculumSearchText)
                            .textFieldStyle(.roundedBorder)
                        TextField("Learning area", text: $viewModel.curriculumLearningAreaFilter)
                            .textFieldStyle(.roundedBorder)
                        TextField("Year level", text: $viewModel.curriculumYearLevelFilter)
                            .textFieldStyle(.roundedBorder)
                    }
                    ForEach(viewModel.filteredCurriculumItems.prefix(12)) { item in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(CurriculumCatalogService.displaySummary(for: item))
                                    .font(.caption)
                                    .textSelection(.enabled)
                                Text(item.shortDescription)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Map") { viewModel.mapCurriculumItemToCurrentAssignment(item) }
                                .buttonStyle(.bordered)
                                .font(.caption)
                        }
                    }
                }
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

            textEditor(title: "Rubric / grading criteria", text: assignmentBinding(\.rubricText), minHeight: 160, hintText: "Paste rubric, answer key, or grading criteria...")
            textEditor(title: "Custom teacher instructions", text: assignmentBinding(\.customInstructions), minHeight: 90, hintText: "Optional custom grading rules...")
            textEditor(title: "Answer key", text: assignmentBinding(\.answerKeyText), minHeight: 80, hintText: "Expected elements, misconceptions, partial credit...")
            textEditor(title: "Exemplar response", text: assignmentBinding(\.exemplarText), minHeight: 80, hintText: "Teacher-supplied exemplar...")
            textEditor(title: "Curriculum / reference material", text: assignmentBinding(\.curriculumReference), minHeight: 100, hintText: "Teacher-entered or imported curriculum reference...")
        }
    }

    private var gradingSection: some View {
        CardSection(title: "Draft and finalize", systemImage: "checklist.checked") {
            HStack(spacing: 12) {
                Button { Task { await viewModel.draftGrade() } } label: {
                    if viewModel.isWorking { ProgressView() } else { Label("Draft Feedback Suggestion", systemImage: "checklist") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canDraftGrade)

                Button("Start Teacher Final Review") { viewModel.startFinalReviewFromLatestDraft() }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.assignment.latestDraft == nil || viewModel.assignment.latestDraftIsStale)

                Button("Start Manual Final Review") { viewModel.startManualFinalReview() }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canStartManualFinalReview)
            }

            if !viewModel.canStartManualFinalReview {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.manualGradingReadinessIssues, id: \.self) { issue in
                        Label(issue, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if case .unavailable = viewModel.localAIStatus {
                Label("Local AI grading is unavailable. GradeDraft will not send this student work to a cloud model as a fallback. Manual grading is available above.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let finalReview = viewModel.assignment.finalReview {
                FinalGradeReviewView(
                    review: finalReview,
                    isStale: viewModel.assignment.finalReviewIsStale,
                    onChange: { updated in viewModel.updateFinalReview(updated) },
                    onApprove: { viewModel.approveFinalReview() },
                    onAddCriterion: { viewModel.addCriterionToFinalReview() },
                    onDeleteCriterion: { id in viewModel.deleteCriterionFromFinalReview(id: id) },
                    onAddManualEvidence: { criterionID, quote in viewModel.addManualEvidenceToFinalReview(criterionID: criterionID, quote: quote) },
                    onRemoveEvidence: { criterionID, index in viewModel.removeEvidenceFromFinalReview(criterionID: criterionID, evidenceIndex: index) },
                    onClearEvidence: { criterionID in viewModel.clearEvidenceFromFinalReview(criterionID: criterionID) }
                )
                .id(finalReview.id)
            } else if let result = viewModel.assignment.latestDraft {
                GradeResultView(result: result, isStale: viewModel.assignment.latestDraftIsStale)
            } else {
                EmptyStateView(title: "No final review yet", message: "Start final review from a draft or grade manually.")
            }
        }
    }

    private var exportSection: some View {
        CardSection(title: "Local export, archive, and backup", systemImage: "square.and.arrow.up") {
            Text("Exports are generated locally. Student reports exclude private teacher notes by default. Teacher audit reports and archives may contain sensitive student data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !viewModel.canExportStudentReport {
                Label("Student-facing export is blocked until the teacher approves the final grade.", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button("Export Student Report") { pendingStudentExportKind = .studentMarkdown; showingStudentReportWarning = true }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canExportStudentReport)
                Button("Export Student PDF") { pendingStudentExportKind = .studentPDF; showingStudentReportWarning = true }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canExportStudentReport)
                Button("Export Teacher Audit Report") { pendingTeacherExportKind = .teacherAuditMarkdown; showingTeacherAuditWarning = true }
                    .buttonStyle(.bordered)
                Button("Export Teacher PDF") { pendingTeacherExportKind = .teacherAuditPDF; showingTeacherAuditWarning = true }
                    .buttonStyle(.bordered)
                Button("Export CSV") { showingCSVWarning = true }.buttonStyle(.bordered)
                Button("Export Archive ZIP") { showingArchiveWarning = true }.buttonStyle(.bordered)
            }
            HStack(spacing: 12) {
                Button("Export Full Local Backup") { showingBackupWarning = true }.buttonStyle(.bordered)
                Picker("Restore conflict handling", selection: $viewModel.backupConflictResolution) {
                    ForEach(BackupConflictResolution.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                Button("Restore Backup") { showingBackupImporter = true }.buttonStyle(.bordered)
                if viewModel.exportURL != nil {
                    Button { showingShareSheetWarning = true } label: { Label("Share \(viewModel.exportKind?.displayName ?? "Report")", systemImage: "square.and.arrow.up") }
                        .buttonStyle(.borderedProminent)
                }
            }
            if let preview = viewModel.latestRestorePreview {
                DisclosureGroup("Restore preview and summary") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(preview.summary)
                        if !preview.conflictAssignmentIDs.isEmpty {
                            Text("Conflicts: \(preview.conflictAssignmentIDs.map(\.uuidString).joined(separator: ", "))")
                                .font(.caption.monospaced())
                                .foregroundStyle(.orange)
                        }
                        ForEach(preview.warnings, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.caption)
                }
            }
        }
    }

    private var aboutSection: some View {
        CardSection(title: "About / Local Privacy", systemImage: "lock.shield") {
            VStack(alignment: .leading, spacing: 10) {
                Text("GradeDraft stores and processes student work, grading records, rubrics, teacher notes, and feedback locally on your device. The developer does not receive, upload, or access this information in the core app workflow.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    Label("No cloud OCR in core workflow.", systemImage: "checkmark.circle")
                    Label("No cloud AI grading in core workflow.", systemImage: "checkmark.circle")
                    Label("No usage-tracking or telemetry SDK in this repo.", systemImage: "checkmark.circle")
                    Label("No account or login required.", systemImage: "checkmark.circle")
                    Label("Local AI may be unavailable on some devices.", systemImage: "info.circle")
                    Label("Exports may contain sensitive student information.", systemImage: "exclamationmark.triangle")
                    Label("Teacher finalizes all grades.", systemImage: "person.badge.checkmark")
                }
                .font(.subheadline)
                Text("Out of scope: official standards certification, handwriting grading, autonomous visual artifact grading, math notation grading, LMS sync, cloud backup, accounts, and subscriptions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func textEditor(title: String, text: Binding<String>, minHeight: CGFloat, hintText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            TextEditor(text: text)
                .frame(minHeight: minHeight)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(hintText).foregroundStyle(.tertiary).padding(.horizontal, 14).padding(.vertical, 16).allowsHitTesting(false)
                    }
                }
        }
    }

    private func clearSource() {
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
            set: { newValue in viewModel.updateAssignment { assignment in assignment[keyPath: keyPath] = newValue } }
        )
    }

    private var promptBinding: Binding<String> {
        Binding(
            get: { viewModel.assignment.prompt ?? "" },
            set: { newValue in viewModel.updateAssignment { assignment in assignment.prompt = newValue.isEmpty ? nil : newValue } }
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

private struct OCRPagePreview: View {
    var image: UIImage?
    var page: OCRPage
    var selectedLineID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Selected page preview · Page \(page.pageIndex + 1)")
                .font(.caption.bold())
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(Text("No rendered page image available").font(.caption).foregroundStyle(.secondary))
                }
                GeometryReader { proxy in
                    ForEach(page.lines) { line in
                        let rect = CGRect(
                            x: line.boundingBox.x * proxy.size.width,
                            y: line.boundingBox.y * proxy.size.height,
                            width: max(line.boundingBox.width * proxy.size.width, 1),
                            height: max(line.boundingBox.height * proxy.size.height, 1)
                        )
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(line.id == selectedLineID ? Color.accentColor : (line.needsReview ? Color.orange : Color.secondary), lineWidth: line.id == selectedLineID ? 3 : 1)
                            .background((line.id == selectedLineID ? Color.accentColor : Color.clear).opacity(0.12))
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    }
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: 420, minHeight: 220, maxHeight: 440)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(.separator), lineWidth: 1))
        }
    }
}

private struct CardSection<Content: View>: View {
    var title: String
    var systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).foregroundStyle(.secondary)
                Text(title).font(.title2.bold())
            }
            content
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(.separator), lineWidth: 1))
    }
}

private struct EmptyStateView: View {
    var title: String
    var message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
