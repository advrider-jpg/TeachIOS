import Foundation
import PDFKit
import UIKit
import ZIPFoundation

@MainActor
final class GradeDraftViewModel: ObservableObject {
    @Published var assignments: [AssignmentRecord] = []
    @Published var selectedAssignmentID: UUID?
    @Published var isWorking = false
    @Published var statusMessage = "Local-only mode. No student work is uploaded."
    @Published var errorMessage: String?
    @Published var exportURL: URL?
    @Published var exportKind: ExportKind?

    private let ocrService: OCRServicing
    private let gradingService: GradingServicing & CapabilityChecking
    private let store: AssignmentStoring
    private let fileManager: FileManager
    @Published private(set) var persistenceMode: String

    init(
        assignments: [AssignmentRecord] = [],
        ocrService: OCRServicing = VisionOCRService(),
        gradingService: GradingServicing & CapabilityChecking = FoundationModelGradingService(),
        store: AssignmentStoring? = nil,
        fileManager: FileManager = .default
    ) {
        self.ocrService = ocrService
        self.gradingService = gradingService
        let resolvedStore: AssignmentStoring
        let resolvedMode: String
        if let store {
            resolvedStore = store
            resolvedMode = "Injected store"
        } else if let dbStore = try? GRDBAssignmentStore(fileManager: fileManager) {
            resolvedStore = dbStore
            resolvedMode = "GRDB-backed local storage"
        } else {
            resolvedStore = LocalJSONStore(fileManager: fileManager)
            resolvedMode = "JSON file-backed storage (GRDB unavailable)"
        }

        self.store = resolvedStore
        self.persistenceMode = resolvedMode
        self.fileManager = fileManager

        if assignments.isEmpty {
            do {
                let loaded = try resolvedStore.loadAssignments()
                self.assignments = loaded.isEmpty ? [AssignmentRecord()] : loaded
            } catch {
                self.assignments = [AssignmentRecord()]
                self.errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
            }
        } else {
            self.assignments = assignments
        }

        selectedAssignmentID = self.assignments.first?.id
        refreshCapabilityStatus()
    }

    var assignment: AssignmentRecord {
        get {
            guard let selectedAssignmentID,
                  let assignment = assignments.first(where: { $0.id == selectedAssignmentID }) else {
                return assignments.first ?? AssignmentRecord()
            }
            return assignment
        }
        set {
            upsertAssignment(newValue)
        }
    }

    var localAIStatus: LocalAIStatus {
        gradingService.localAIStatus
    }

    var hasLowConfidenceOCR: Bool {
        assignment.ocrDocument?.hasLowConfidenceText == true
    }

    var qualitySummary: OCRQualitySummary {
        assignment.ocrDocument?.qualitySummary ?? OCRQualitySummary()
    }

    var readinessIssues: [String] {
        var issues: [String] = []
        if case .unavailable(let message) = localAIStatus {
            issues.append(message)
        }
        if !assignment.hasGradingStandard {
            issues.append("Add a rubric, answer key, exemplar, or grading criteria.")
        }
        if assignment.reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Add pasted text or review OCR text.")
        }
        if assignment.ocrReviewStatus.blocksGrading {
            issues.append("Mark OCR as reviewed before grading.")
        }
        if assignment.latestDraftIsStale {
            issues.append("The saved draft is stale because the text, rubric, or instructions changed.")
        }
        if assignment.finalReviewIsStale {
            issues.append("The final review is stale because the text, rubric, or instructions changed.")
        }
        if assignment.finalReview?.status != .approved, let blockMessage = finalReviewApprovalBlockMessage {
            issues.append(blockMessage)
        }

        if !canExportStudentReport {
            issues.append("Student-facing export is blocked until the teacher approves the final grade.")
        }
        return issues
    }

    var canExportStudentReport: Bool {
        guard let finalReview = assignment.finalReview else {
            return false
        }
        if finalReview.status != .approved {
            return false
        }
        return !assignment.finalReviewIsStale
    }

    var canApproveFinalReview: Bool {
        guard let finalReview = assignment.finalReview else {
            return false
        }
        guard finalReview.criteria.isEmpty == false else {
            return false
        }
        if assignment.finalReviewIsStale {
            return false
        }
        if !finalReview.allCriteriaApproved {
            return false
        }
        if finalReview.criteria.contains(where: { criterion in
            criterion.finalPoints < 0 || criterion.finalPoints > criterion.maxPoints
        }) {
            return false
        }
        return true
    }

    private var finalReviewApprovalBlockMessage: String? {
        guard let finalReview = assignment.finalReview else {
            return "Create a final review before final approval."
        }
        if finalReview.criteria.isEmpty {
            return "Add at least one criterion before approval."
        }
        if assignment.finalReviewIsStale {
            return "Refresh final review because grading inputs changed since this review was created."
        }
        if !finalReview.allCriteriaApproved {
            return "Approve all final-review criteria before finalizing."
        }
        if finalReview.criteria.contains(where: { criterion in
            criterion.finalPoints < 0 || criterion.finalPoints > criterion.maxPoints
        }) {
            return "Correct out-of-range criterion scores before finalizing."
        }
        return nil
    }

    var persistenceSummary: String {
        "Persistence: \(persistenceMode)"
    }

    var canDraftGrade: Bool {
        guard assignment.assignmentInputReady, !isWorking else { return false }
        if case .available = localAIStatus { return true }
        return false
    }

    var canStartManualFinalReview: Bool {
        !assignment.reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        assignment.hasGradingStandard &&
        !assignment.requiresOCRReviewBeforeGrading
    }

    /// Readiness issues that block manual grading (no AI required).
    var manualGradingReadinessIssues: [String] {
        var issues: [String] = []
        if !assignment.hasGradingStandard {
            issues.append("Add a rubric, answer key, exemplar, or grading criteria before drafting feedback.")
        }
        if assignment.reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Add or review the student text before drafting feedback.")
        }
        if assignment.ocrReviewStatus.blocksGrading {
            issues.append("Review and confirm OCR text before drafting feedback.")
        }
        return issues
    }

    func refreshCapabilityStatus() {
        switch gradingService.localAIStatus {
        case .available:
            statusMessage = "Local AI is available on this device. Student work stays on device."
        case .unavailable(let message):
            statusMessage = message
        }
    }

    func selectAssignment(_ id: UUID) {
        selectedAssignmentID = id
        exportURL = nil
        exportKind = nil
        refreshCapabilityStatus()
    }

    func newAssignment(from template: RubricTemplate? = nil) {
        var newRecord = AssignmentRecord()
        newRecord.appendAuditEvent(.assignmentCreated, detail: "Assignment created locally.")
        if let template {
            newRecord.title = template.name
            newRecord.assignmentType = template.assignmentType
            newRecord.assessmentPurpose = template.assessmentPurpose
            newRecord.rubricText = template.rubricText
            newRecord.customInstructions = template.customInstructions
        }
        upsertAssignment(newRecord)
        selectedAssignmentID = newRecord.id
        persistOrSurfaceError()
    }

    func duplicateCurrentAssignment() {
        var copy = assignment
        copy.id = UUID()
        copy.title = "Copy of \(copy.title)"
        copy.latestDraft = nil
        copy.finalReview = nil
        copy.exportRecords = []
        copy.auditEvents = [AuditEvent(eventType: .assignmentCreated, detail: "Assignment duplicated locally from another record.")]
        copy.createdAt = Date()
        copy.updatedAt = Date()
        upsertAssignment(copy)
        selectedAssignmentID = copy.id
        persistOrSurfaceError()
    }

    func deleteCurrentAssignment() {
        guard let selectedAssignmentID else { return }
        let assignmentToDelete = assignments.first { $0.id == selectedAssignmentID }
        assignments.removeAll { $0.id == selectedAssignmentID }
        if assignments.isEmpty {
            assignments = [AssignmentRecord()]
        }
        self.selectedAssignmentID = assignments.first?.id
        do {
            try store.deleteAssignment(id: selectedAssignmentID)
            try store.saveAssignments(assignments)
            // Delete source image files for this assignment if present.
            if let appDir = try? store.applicationSupportDirectory(),
               let toDelete = assignmentToDelete,
               !toDelete.sourceInputs.isEmpty {
                let sourceDir = appDir
                    .appendingPathComponent("Sources", isDirectory: true)
                    .appendingPathComponent(selectedAssignmentID.uuidString, isDirectory: true)
                if fileManager.fileExists(atPath: sourceDir.path) {
                    try? fileManager.removeItem(at: sourceDir)
                }
            }
            statusMessage = "Assignment deleted locally."
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func updateAssignment(_ transform: (inout AssignmentRecord) -> Void) {
        var updated = assignment
        let previousFingerprint = updated.gradingPacketFingerprint
        transform(&updated)
        updated.updatedAt = Date()
        if updated.gradingPacketFingerprint != previousFingerprint {
            if updated.latestDraft != nil {
                updated.latestDraft?.status = .stale
                updated.appendAuditEvent(.draftMarkedStale, detail: "Grading inputs changed after a draft was generated.")
            }
            if updated.finalReview != nil {
                updated.finalReview?.status = .stale
            }
        }
        upsertAssignment(updated)
    }

    func applyTemplate(_ template: RubricTemplate) {
        updateAssignment { assignment in
            assignment.assignmentType = template.assignmentType
            assignment.assessmentPurpose = template.assessmentPurpose
            assignment.rubricText = template.rubricText
            assignment.customInstructions = template.customInstructions
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Rubric template applied: \(template.name).")
        }
        persistOrSurfaceError()
        statusMessage = "Template applied locally. Review before grading."
    }

    func applyPastedStudentText(_ text: String) {
        updateAssignment { assignment in
            assignment.reviewedStudentText = text
            assignment.ocrDocument = nil
            assignment.ocrReviewStatus = .notNeeded
            assignment.ocrReviewedAt = nil
            assignment.sourceInputs = [SourceInputRef(sourceType: .pastedText, contentDigest: StableFingerprint.fingerprint([text]), digestAlgorithm: "fnv1a64")]
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Pasted student text applied as teacher-reviewed input.")
        }
        persistOrSurfaceError()
    }

    func applyScannedImages(_ images: [UIImage]) async {
        await applyImages(images, sourceType: .scan)
    }

    func applyPhotoImages(_ images: [UIImage]) async {
        await applyImages(images, sourceType: .photo)
    }

    func applyImages(_ images: [UIImage], sourceType: SourceType) async {
        guard !images.isEmpty else { return }
        isWorking = true
        errorMessage = nil
        exportURL = nil
        exportKind = nil
        defer { isWorking = false }

        do {
            let sourceRefs = try persistSourceImages(images, sourceType: sourceType, assignmentID: assignment.id)
            var document = try await ocrService.recognizeText(in: images)
            for index in document.pages.indices where index < sourceRefs.count {
                document.pages[index].sourceInputID = sourceRefs[index].id
            }
            document.reviewStatus = .needsReview

            updateAssignment { assignment in
                assignment.sourceInputs = sourceRefs
                assignment.ocrDocument = document
                assignment.ocrReviewStatus = .needsReview
                assignment.ocrReviewedAt = nil
                assignment.reviewedStudentText = document.combinedText
                assignment.latestDraft = nil
                assignment.finalReview = nil
                assignment.appendAuditEvent(.sourceCaptured, detail: "Captured \(images.count) \(sourceType.displayName.lowercased()) page(s) locally.")
                assignment.appendAuditEvent(.ocrCompleted, detail: document.qualitySummary.displaySummary)
            }
            statusMessage = "OCR complete. Review and confirm the extracted text before drafting a feedback suggestion."
            try saveCurrentAssignment()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markOCRReviewed() {
        guard assignment.ocrDocument != nil else { return }
        updateAssignment { assignment in
            assignment.ocrDocument = assignment.ocrDocument?.markingAllLinesConfirmed()
            assignment.ocrReviewStatus = .reviewed
            assignment.ocrReviewedAt = Date()
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.ocrReviewed, detail: "Teacher marked OCR text reviewed. Reviewed text is now eligible for grading.")
        }
        persistOrSurfaceError()
        statusMessage = "OCR reviewed. Draft feedback is now available if Local AI and rubric are ready."
    }

    func draftGrade() async {
        guard canDraftGrade else {
            errorMessage = readinessIssues.first ?? "Draft feedback is not ready."
            return
        }
        isWorking = true
        errorMessage = nil
        exportURL = nil
        exportKind = nil
        defer { isWorking = false }

        do {
            let input = assignment.gradingInput
            let result = try await gradingService.draftGrade(input: input)
            updateAssignment { assignment in
                assignment.latestDraft = result
                assignment.finalReview = nil
                assignment.appendAuditEvent(.draftGenerated, detail: "Local grading draft generated from packet \(input.packetFingerprint).")
            }
            statusMessage = "Draft feedback suggestion generated locally. Start teacher final review before using it."
            try saveCurrentAssignment()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startFinalReviewFromLatestDraft() {
        guard let draft = assignment.latestDraft else { return }
        let final = FinalGradeReview(
            packetFingerprint: draft.packetFingerprint,
            status: .inProgress,
            criteria: draft.criteria.map(FinalCriterionScore.init(from:)),
            totalScore: draft.totalScore,
            maxScore: draft.maxScore,
            studentFeedback: draft.studentFeedback,
            privateTeacherNotes: draft.teacherNotes,
            teacherEdited: false
        )
        updateAssignment { assignment in
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: final)
            assignment.appendAuditEvent(.finalReviewStarted, detail: "Teacher review started from the latest local draft.")
        }
        persistOrSurfaceError()
        statusMessage = "Final review started. Approve each criterion before exporting as final."
    }

    func startManualFinalReview() {
        guard canStartManualFinalReview else {
            errorMessage = manualGradingReadinessIssues.first ?? "Cannot start manual final review yet."
            return
        }

        let parsedCriteria = assignment.parsedRubric.criteria
        let finalCriteria: [FinalCriterionScore]

        if !parsedCriteria.isEmpty {
            finalCriteria = parsedCriteria.map { criterion in
                FinalCriterionScore(
                    criterionID: criterion.id,
                    criterion: criterion.title,
                    rating: "",
                    proposedPoints: 0,
                    finalPoints: 0,
                    maxPoints: criterion.maxPoints,
                    evidence: [],
                    explanation: "",
                    teacherApproved: false,
                    teacherRationale: "Manual teacher-created final review."
                )
            }
        } else {
            finalCriteria = [FinalCriterionScore(
                criterionID: nil,
                criterion: "Teacher-entered grading standard",
                rating: "",
                proposedPoints: 0,
                finalPoints: 0,
                maxPoints: 0,
                evidence: [],
                explanation: "",
                teacherApproved: false,
                teacherRationale: "Manual teacher-created final review. Edit this criterion to match the grading standard, then approve it."
            )]
        }

        let review = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: finalCriteria,
            totalScore: 0,
            maxScore: finalCriteria.map(\.maxPoints).reduce(0, +),
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: false
        )
        updateAssignment { assignment in
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
            assignment.appendAuditEvent(.finalReviewStarted, detail: "Teacher started manual final review without AI draft.")
        }
        persistOrSurfaceError()
        statusMessage = "Manual final review started. Edit criteria, approve each one, then approve the final grade."
    }

    func addCriterionToFinalReview() {
        guard var review = assignment.finalReview else { return }
        let newCriterion = FinalCriterionScore(
            criterionID: nil,
            criterion: "New criterion",
            rating: "",
            proposedPoints: 0,
            finalPoints: 0,
            maxPoints: 0,
            evidence: [],
            explanation: "",
            teacherApproved: false,
            teacherRationale: ""
        )
        review.criteria.append(newCriterion)
        review.teacherEdited = true
        review = GradeTotals.applyingDeterministicTotals(to: review)
        updateAssignment { assignment in
            assignment.finalReview = review
        }
        persistOrSurfaceError()
    }

    func deleteCriterionFromFinalReview(id: UUID) {
        guard var review = assignment.finalReview else { return }
        review.criteria.removeAll { $0.id == id }
        review.teacherEdited = true
        review = GradeTotals.applyingDeterministicTotals(to: review)
        updateAssignment { assignment in
            assignment.finalReview = review
        }
        persistOrSurfaceError()
    }

    func updateFinalReview(_ review: FinalGradeReview) {
        var review = review
        review.teacherEdited = true
        updateAssignment { assignment in
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
        }
        persistOrSurfaceError()
    }

    func approveFinalReview() {
        guard var review = assignment.finalReview else { return }
        guard canApproveFinalReview else {
            errorMessage = finalReviewApprovalBlockMessage ?? "This final review is not ready for final approval."
            return
        }
        review.criteria = review.criteria.map { criterion in
            var criterion = criterion
            criterion.teacherApproved = true
            return criterion
        }
        review.status = .approved
        review.finalizedAt = Date()
        review = GradeTotals.applyingDeterministicTotals(to: review)
        updateAssignment { assignment in
            assignment.finalReview = review
            assignment.appendAuditEvent(.finalApproved, detail: "Teacher approved final grade \(GradeTotals.formatted(review.totalScore)) / \(GradeTotals.formatted(review.maxScore)).")
        }
        persistOrSurfaceError()
        statusMessage = "Final grade approved and saved locally."
    }

    func saveCurrentAssignment() throws {
        upsertAssignment(assignment)
        do {
            try store.saveAssignments(assignments)
        } catch {
            throw GradeDraftError.persistenceFailed(error.localizedDescription)
        }
    }

    func exportStudentReport() {
        guard canExportStudentReport else {
            errorMessage = "Student-facing export is blocked until the teacher approves the final grade."
            return
        }

        do {
            let markdown = MarkdownReportBuilder.studentMarkdown(for: assignment)
            exportURL = try MarkdownReportBuilder.writeTemporaryStudentReport(for: assignment)
            exportKind = .studentMarkdown
            recordExport(kind: .studentMarkdown, markdown: markdown, includesPrivateNotes: false)
            statusMessage = "Student Markdown report is ready to share."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportTeacherAuditReport() {
        do {
            let markdown = MarkdownReportBuilder.teacherAuditMarkdown(for: assignment)
            exportURL = try MarkdownReportBuilder.writeTemporaryTeacherAuditReport(for: assignment)
            exportKind = .teacherAuditMarkdown
            recordExport(kind: .teacherAuditMarkdown, markdown: markdown, includesPrivateNotes: true)
            statusMessage = "Teacher audit Markdown report is ready to share. Treat it as sensitive."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportCSVGradebook() {
        do {
            let csv = CSVExportService.exportedCSV(from: [assignment])
            let safeTitle = assignment.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression)
            let fileName = "GradeDraft-CSV-\(safeTitle.isEmpty ? assignment.id.uuidString : safeTitle).csv"
            let destination = fileManager.temporaryDirectory.appendingPathComponent(fileName)
            try csv.write(to: destination, atomically: true, encoding: .utf8)
            exportURL = destination
            exportKind = .csvGradebook
            recordExport(kind: .csvGradebook, markdown: csv, includesPrivateNotes: false)
            statusMessage = "CSV grade summary is ready to share."
        } catch {
            errorMessage = error.localizedDescription
        }
    }


    func applyPDFFile(_ url: URL) async {
        isWorking = true
        errorMessage = nil
        exportURL = nil
        exportKind = nil
        defer { isWorking = false }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            guard let document = PDFDocument(url: url) else {
                throw GradeDraftError.ocrFailed("The selected PDF could not be opened.")
            }
            guard document.pageCount > 0 else {
                throw GradeDraftError.ocrFailed("The selected PDF did not contain any pages.")
            }

            let appDirectory = try store.applicationSupportDirectory()
            let sourceRoot = appDirectory
                .appendingPathComponent("Sources", isDirectory: true)
                .appendingPathComponent(assignment.id.uuidString, isDirectory: true)
            let originalFolder = sourceRoot.appendingPathComponent("original", isDirectory: true)
            try fileManager.createDirectory(at: originalFolder, withIntermediateDirectories: true)
            let pdfID = UUID()
            let originalPDFURL = originalFolder.appendingPathComponent("\(pdfID.uuidString).pdf")
            if fileManager.fileExists(atPath: originalPDFURL.path) { try fileManager.removeItem(at: originalPDFURL) }
            try fileManager.copyItem(at: url, to: originalPDFURL)
            let pdfData = try Data(contentsOf: originalPDFURL)
            let originalPDFSource = SourceInputRef(
                id: pdfID,
                sourceType: .pdf,
                pageIndex: nil,
                localRelativePath: "Sources/\(assignment.id.uuidString)/original/\(pdfID.uuidString).pdf",
                fileName: url.lastPathComponent,
                mimeType: "application/pdf",
                contentDigest: StableFingerprint.fingerprint(pdfData),
                digestAlgorithm: "fnv1a64",
                pdfPageCount: document.pageCount,
                teacherIncludedInExport: true
            )

            let digitalTextByPage = extractDigitalPDFText(document)
            let images = try renderPDFPages(document)
            guard !images.isEmpty else {
                throw GradeDraftError.ocrFailed("The selected PDF did not contain renderable pages.")
            }
            var pageSourceRefs = try persistSourceImages(images, sourceType: .pdf, assignmentID: assignment.id)
            for index in pageSourceRefs.indices {
                pageSourceRefs[index].fileName = "PDF page \(index + 1) render"
                pageSourceRefs[index].mimeType = "image/png"
                pageSourceRefs[index].pdfPageCount = document.pageCount
            }

            let ocrDocument: OCRDocument
            if digitalTextByPage.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                ocrDocument = ocrDocumentFromDigitalPDFText(digitalTextByPage, sourceRefs: pageSourceRefs)
            } else {
                var recognized = try await ocrService.recognizeText(in: images)
                for index in recognized.pages.indices where index < pageSourceRefs.count {
                    recognized.pages[index].sourceInputID = pageSourceRefs[index].id
                }
                ocrDocument = recognized
            }

            var documentForReview = ocrDocument
            documentForReview.reviewStatus = .needsReview
            updateAssignment { assignment in
                assignment.sourceInputs = [originalPDFSource] + pageSourceRefs
                assignment.ocrDocument = documentForReview
                assignment.ocrReviewStatus = .needsReview
                assignment.ocrReviewedAt = nil
                assignment.reviewedStudentText = documentForReview.combinedText
                assignment.latestDraft = nil
                assignment.finalReview = nil
                assignment.appendAuditEvent(.sourceCaptured, detail: "Imported local PDF with \(document.pageCount) page(s); original PDF and rendered pages stored locally.")
                assignment.appendAuditEvent(.ocrCompleted, detail: documentForReview.qualitySummary.displaySummary)
            }
            statusMessage = "PDF imported. Review and confirm extracted text before drafting feedback."
            try saveCurrentAssignment()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importMarkdownRubric(from url: URL) {
        do {
            let text = try readTextFile(url)
            let parsed = MarkdownRubricParser.parse(text)
            updateAssignment { assignment in
                assignment.rubricText = text
                if !parsed.criteria.isEmpty {
                    assignment.appendAuditEvent(.inputChanged, detail: "Imported Markdown rubric with \(parsed.criteria.count) criterion/criteria.")
                } else {
                    assignment.appendAuditEvent(.inputChanged, detail: "Imported Markdown rubric text; structured criteria were not detected.")
                }
                assignment.latestDraft = nil
                assignment.finalReview = nil
            }
            persistOrSurfaceError()
            statusMessage = parsed.criteria.isEmpty ? "Rubric imported; review criteria manually." : "Markdown rubric imported with structured criteria."
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func importCurriculumReference(from url: URL) {
        do {
            let text = try CurriculumImportService.importableText(from: url)
            let summary = CurriculumImportService.summary(from: text, sourceName: url.lastPathComponent)
            updateAssignment { assignment in
                assignment.curriculumReference = summary
                assignment.latestDraft = nil
                assignment.finalReview = nil
                assignment.appendAuditEvent(.inputChanged, detail: "Imported local curriculum/reference material from \(url.lastPathComponent).")
            }
            persistOrSurfaceError()
            statusMessage = "Curriculum/reference material imported locally. Confirm it matches your jurisdiction before grading."
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func createAssignmentsFromRosterCSV(_ text: String) {
        let names = text.components(separatedBy: .newlines)
            .map { line in line.split(separator: ",").first.map(String.init) ?? line }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !names.isEmpty else {
            errorMessage = "Paste at least one student name or local identifier."
            return
        }
        let template = assignment
        var created: [AssignmentRecord] = []
        for name in names {
            var copy = template
            copy.id = UUID()
            copy.studentDisplayName = name
            copy.latestDraft = nil
            copy.finalReview = nil
            copy.exportRecords = []
            copy.auditEvents = [AuditEvent(eventType: .assignmentCreated, detail: "Roster-created assignment for \(name).")]
            copy.createdAt = Date()
            copy.updatedAt = Date()
            created.append(copy)
        }
        assignments.append(contentsOf: created)
        assignments.sort { $0.updatedAt > $1.updatedAt }
        selectedAssignmentID = created.first?.id ?? selectedAssignmentID
        persistOrSurfaceError()
        statusMessage = "Created \(created.count) roster assignment(s) locally."
    }

    func updateOCRLine(pageID: UUID, lineID: UUID, correctedText: String) {
        updateAssignment { assignment in
            guard var document = assignment.ocrDocument else { return }
            for pageIndex in document.pages.indices where document.pages[pageIndex].id == pageID {
                for lineIndex in document.pages[pageIndex].lines.indices where document.pages[pageIndex].lines[lineIndex].id == lineID {
                    document.pages[pageIndex].lines[lineIndex].correctedText = correctedText
                    document.pages[pageIndex].lines[lineIndex].teacherConfirmed = false
                }
            }
            assignment.ocrDocument = document
            assignment.reviewedStudentText = document.combinedText
            assignment.ocrReviewStatus = .needsReview
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Edited OCR line text during teacher review.")
        }
        persistOrSurfaceError()
    }

    func confirmOCRLine(pageID: UUID, lineID: UUID) {
        updateAssignment { assignment in
            guard var document = assignment.ocrDocument else { return }
            for pageIndex in document.pages.indices where document.pages[pageIndex].id == pageID {
                for lineIndex in document.pages[pageIndex].lines.indices where document.pages[pageIndex].lines[lineIndex].id == lineID {
                    document.pages[pageIndex].lines[lineIndex].teacherConfirmed = true
                }
            }
            assignment.ocrDocument = document
            assignment.reviewedStudentText = document.combinedText
            assignment.ocrReviewStatus = document.hasUnconfirmedLines ? .needsReview : .reviewed
            if !document.hasUnconfirmedLines { assignment.ocrReviewedAt = Date() }
            assignment.latestDraft = nil
            assignment.finalReview = nil
        }
        persistOrSurfaceError()
    }

    func rejectOCRLine(pageID: UUID, lineID: UUID) {
        updateAssignment { assignment in
            guard var document = assignment.ocrDocument else { return }
            for pageIndex in document.pages.indices where document.pages[pageIndex].id == pageID {
                document.pages[pageIndex].lines.removeAll { $0.id == lineID }
            }
            assignment.ocrDocument = document
            assignment.reviewedStudentText = document.combinedText
            assignment.ocrReviewStatus = document.hasUnconfirmedLines ? .needsReview : .reviewed
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Rejected OCR line during teacher review.")
        }
        persistOrSurfaceError()
    }

    func addOCRLineEvidenceToFinalReview(pageID: UUID, lineID: UUID, criterionID: UUID?) {
        guard var review = assignment.finalReview,
              let document = assignment.ocrDocument,
              let page = document.pages.first(where: { $0.id == pageID }),
              let line = page.lines.first(where: { $0.id == lineID }) else { return }
        let quote = line.reviewedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !quote.isEmpty else { return }
        let evidenceRef = EvidenceReference(
            sourceInputID: page.sourceInputID,
            ocrLineID: line.id,
            pageIndex: page.pageIndex,
            quote: quote,
            startOffset: nil,
            endOffset: nil,
            boundingBox: line.boundingBox,
            sourceKind: "ocrLine",
            teacherConfirmed: line.teacherConfirmed
        )
        let sourceRef = evidenceSourceReference(page: page, line: line, evidenceID: evidenceRef.id)
        let targetIndex: Int
        if let criterionID, let found = review.criteria.firstIndex(where: { $0.id == criterionID }) {
            targetIndex = found
        } else {
            targetIndex = review.criteria.startIndex
        }
        guard review.criteria.indices.contains(targetIndex) else { return }
        review.criteria[targetIndex].evidence.append(quote)
        var refs = review.criteria[targetIndex].evidenceSourceRefs ?? []
        refs.append(sourceRef)
        review.criteria[targetIndex].evidenceSourceRefs = refs
        review.criteria[targetIndex].teacherApproved = false
        review.teacherEdited = true
        updateAssignment { assignment in
            assignment.evidenceReferences.append(evidenceRef)
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
            assignment.appendAuditEvent(.inputChanged, detail: "Linked OCR line evidence to final-review criterion.")
        }
        persistOrSurfaceError()
    }

    func sourceImage(for source: SourceInputRef) -> UIImage? {
        guard let localRelativePath = source.localRelativePath,
              let appDir = try? store.applicationSupportDirectory() else { return nil }
        let url = appDir.appendingPathComponent(localRelativePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func sourceFiles(for assignment: AssignmentRecord) -> [URL] {
        guard let appDir = try? store.applicationSupportDirectory() else { return [] }
        return assignment.sourceInputs.compactMap { source in
            guard let localRelativePath = source.localRelativePath else { return nil }
            let url = appDir.appendingPathComponent(localRelativePath)
            return fileManager.fileExists(atPath: url.path) ? url : nil
        }
    }

    private func mergeRestoredAssignments(_ restored: [AssignmentRecord]) -> [AssignmentRecord] {
        var byID = Dictionary(uniqueKeysWithValues: assignments.map { ($0.id, $0) })
        for record in restored {
            if let existing = byID[record.id], existing.updatedAt > record.updatedAt {
                var copy = record
                copy.id = UUID()
                copy.title = "Restored copy of \(record.title)"
                copy.appendAuditEvent(.inputChanged, detail: "Restored as copy because a newer local record existed with the same ID.")
                byID[copy.id] = copy
            } else {
                byID[record.id] = record
            }
        }
        return Array(byID.values)
    }

    func sourceFilesForCurrentAssignment() -> [URL] {
        sourceFiles(for: assignment)
    }

    func exportStudentPDF() {
        guard canExportStudentReport else {
            errorMessage = "Student-facing export is blocked until the teacher approves the final grade."
            return
        }
        do {
            let destination = temporaryExportURL(prefix: "GradeDraft-Student", extension: "pdf")
            exportURL = try PDFExportService.studentReportPDF(for: assignment, destination: destination)
            exportKind = .studentPDF
            recordExport(kind: .studentPDF, markdown: MarkdownReportBuilder.studentMarkdown(for: assignment), includesPrivateNotes: false)
            statusMessage = "Student PDF report is ready to share."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportTeacherAuditPDF() {
        do {
            let destination = temporaryExportURL(prefix: "GradeDraft-TeacherAudit", extension: "pdf")
            exportURL = try PDFExportService.teacherAuditPDF(for: assignment, destination: destination)
            exportKind = .teacherAuditPDF
            recordExport(kind: .teacherAuditPDF, markdown: MarkdownReportBuilder.teacherAuditMarkdown(for: assignment), includesPrivateNotes: true)
            statusMessage = "Teacher audit PDF is ready to share. Treat it as sensitive."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportArchiveBundle() {
        do {
            let destination = try BundleExportService.preflightDestination(for: assignment.id)
            exportURL = try BundleExportService.writeTeacherAuditArchive(assignment: assignment, sourceFiles: sourceFilesForCurrentAssignment(), to: destination)
            exportKind = .zipArchive
            recordExport(kind: .zipArchive, markdown: StableFingerprint.fingerprint([assignment.gradingPacketFingerprint]), includesPrivateNotes: true)
            statusMessage = "Teacher archive ZIP is ready to share. Treat it as sensitive."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportBackupJSON() {
        do {
            let destination = temporaryExportURL(prefix: "GradeDraft-FullBackup", extension: "zip")
            let sourceFiles = assignments.flatMap { assignment in
                sourceFiles(for: assignment)
            }
            exportURL = try BundleExportService.writeFullBackup(assignments: assignments, sourceFiles: sourceFiles, to: destination)
            exportKind = .fullBackupArchive
            statusMessage = "Full local backup archive is ready to share. Treat it as sensitive student data."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restoreBackup(from url: URL) {
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let restored: [AssignmentRecord]
            if url.pathExtension.lowercased() == "zip" {
                restored = try BundleExportService.readBackupAssignments(from: url)
            } else {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                restored = try decoder.decode([AssignmentRecord].self, from: data)
            }
            guard !restored.isEmpty else {
                errorMessage = "Backup contained no assignments."
                return
            }
            let merged = mergeRestoredAssignments(restored)
            assignments = merged.sorted { $0.updatedAt > $1.updatedAt }
            selectedAssignmentID = assignments.first?.id
            try store.saveAssignments(assignments)
            statusMessage = "Restored \(restored.count) assignment(s) from local backup preview/import."
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    private func recordExport(kind: ExportKind, markdown: String, includesPrivateNotes: Bool) {
        updateAssignment { assignment in
            assignment.exportRecords.append(
                ExportRecord(
                    exportKind: kind,
                    contentFingerprint: StableFingerprint.fingerprint([markdown]),
                    includesPrivateTeacherNotes: includesPrivateNotes,
                    includesOriginalSources: false
                )
            )
            assignment.appendAuditEvent(.exportPrepared, detail: "Prepared \(kind.displayName).")
        }
        persistOrSurfaceError()
    }

    private func upsertAssignment(_ updated: AssignmentRecord) {
        var updated = updated
        updated.updatedAt = Date()
        if let index = assignments.firstIndex(where: { $0.id == updated.id }) {
            assignments[index] = updated
        } else {
            assignments.insert(updated, at: 0)
        }
        assignments.sort { $0.updatedAt > $1.updatedAt }
    }

    private func persistOrSurfaceError() {
        do {
            try saveCurrentAssignment()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistSourceImages(_ images: [UIImage], sourceType: SourceType, assignmentID: UUID) throws -> [SourceInputRef] {
        let appDirectory = try store.applicationSupportDirectory()
        let sourceDirectory = appDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(assignmentID.uuidString, isDirectory: true)
        if !fileManager.fileExists(atPath: sourceDirectory.path) {
            try fileManager.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        }

        return try images.enumerated().map { index, image in
            guard let data = image.pngData() else {
                throw GradeDraftError.persistenceFailed("Could not serialize captured page \(index + 1).")
            }
            let filename = "page-\(index + 1)-\(UUID().uuidString).png"
            let url = sourceDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: [.atomic])
            let relativePath = "Sources/\(assignmentID.uuidString)/\(filename)"
            return SourceInputRef(
                sourceType: sourceType,
                pageIndex: index,
                localRelativePath: relativePath,
                contentDigest: StableFingerprint.fingerprint(data),
                digestAlgorithm: "fnv1a64",
                imageWidth: Double(image.size.width),
                imageHeight: Double(image.size.height),
                teacherIncludedInExport: false
            )
        }
    }

    private func renderPDFPages(_ document: PDFDocument) throws -> [UIImage] {
        var images: [UIImage] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0
            let size = CGSize(width: max(bounds.width, 1) * scale, height: max(bounds.height, 1) * scale)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                context.cgContext.saveGState()
                context.cgContext.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: context.cgContext)
                context.cgContext.restoreGState()
            }
            images.append(image)
        }
        return images
    }

    private func extractDigitalPDFText(_ document: PDFDocument) -> [String] {
        (0..<document.pageCount).map { index in
            document.page(at: index)?.string ?? ""
        }
    }

    private func ocrDocumentFromDigitalPDFText(_ pageTexts: [String], sourceRefs: [SourceInputRef]) -> OCRDocument {
        let pages: [OCRPage] = pageTexts.enumerated().map { pageIndex, text in
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .enumerated()
                .map { lineIndex, lineText in
                    OCRLine(
                        text: lineText,
                        confidence: 1.0,
                        boundingBox: NormalizedRect(x: 0.02, y: CGFloat(lineIndex) * 0.035, width: 0.96, height: 0.03),
                        teacherConfirmed: false
                    )
                }
            return OCRPage(
                sourceInputID: pageIndex < sourceRefs.count ? sourceRefs[pageIndex].id : nil,
                pageIndex: pageIndex,
                imageWidth: sourceRefs[safe: pageIndex]?.imageWidth,
                imageHeight: sourceRefs[safe: pageIndex]?.imageHeight,
                lines: lines
            )
        }
        return OCRDocument(engine: "PDFKit digital text", engineVersion: "system", pages: pages)
    }

    private func readTextFile(_ url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .utf16) {
            return text
        }
        throw GradeDraftError.persistenceFailed("Could not read imported file as text.")
    }

    private func evidenceSourceReference(page: OCRPage, line: OCRLine, evidenceID: UUID? = nil) -> String {
        let sourceID = page.sourceInputID?.uuidString ?? "unknown-source"
        let box = line.boundingBox
        let evidencePart = evidenceID.map { "evidence:\($0.uuidString):" } ?? ""
        return "\(evidencePart)source:\(sourceID):page:\(page.pageIndex):ocrLine:\(line.id.uuidString):bbox:\(box.x),\(box.y),\(box.width),\(box.height)"
    }

    private func temporaryExportURL(prefix: String, extension ext: String) -> URL {
        let safeTitle = assignment.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression)
        let filename = "\(prefix)-\(safeTitle.isEmpty ? assignment.id.uuidString : safeTitle).\(ext)"
        return fileManager.temporaryDirectory.appendingPathComponent(filename)
    }
}

private enum CurriculumImportService {
    static func importableText(from url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .utf16) { return text }
        if url.pathExtension.lowercased() == "xlsx" {
            return try xlsxSharedText(from: url)
        }
        throw GradeDraftError.persistenceFailed("Could not read imported curriculum/reference file as text.")
    }

    private static func xlsxSharedText(from url: URL) throws -> String {
        let archive = try Archive(url: url, accessMode: .read)
        var collected: [String] = []
        for entry in archive where entry.path.hasSuffix(".xml") {
            var data = Data()
            _ = try archive.extract(entry) { chunk in data.append(chunk) }
            guard let xml = String(data: data, encoding: .utf8) else { continue }
            let cleaned = xml
                .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
            collected.append(cleaned)
        }
        return collected.joined(separator: "\n")
    }

    static func summary(from text: String, sourceName: String) -> String {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let codePattern = #"\b[A-Z]{2,}[A-Z0-9]{3,}\b"#
        let codes = lines.flatMap { line -> [String] in
            guard let regex = try? NSRegularExpression(pattern: codePattern) else { return [] }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            return regex.matches(in: line, range: range).compactMap { match in
                Range(match.range, in: line).map { String(line[$0]) }
            }
        }
        let excerpts = lines.prefix(20).joined(separator: "\n")
        return """
        Source: \(sourceName)
        Import status: Teacher-provided local curriculum/reference material. Confirm against the official jurisdiction source before reporting.
        Detected codes: \(Array(Set(codes)).sorted().joined(separator: ", "))

        Excerpts:
        \(excerpts)
        """
    }
}


private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
