import Foundation
import UIKit

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

    init(
        assignments: [AssignmentRecord] = [],
        ocrService: OCRServicing = VisionOCRService(),
        gradingService: GradingServicing & CapabilityChecking = FoundationModelGradingService(),
        store: AssignmentStoring = LocalJSONStore(),
        fileManager: FileManager = .default
    ) {
        self.ocrService = ocrService
        self.gradingService = gradingService
        self.store = store
        self.fileManager = fileManager

        if assignments.isEmpty {
            do {
                let loaded = try store.loadAssignments()
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
        if assignment.rubricText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Add a rubric, answer key, or grading standard.")
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
        return issues
    }

    var canDraftGrade: Bool {
        guard assignment.assignmentInputReady, !isWorking else { return false }
        if case .available = localAIStatus { return true }
        return false
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
        assignments.removeAll { $0.id == selectedAssignmentID }
        if assignments.isEmpty {
            assignments = [AssignmentRecord()]
        }
        self.selectedAssignmentID = assignments.first?.id
        do {
            try store.deleteAssignment(id: selectedAssignmentID)
            try store.saveAssignments(assignments)
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
            statusMessage = "OCR complete. Review and confirm the extracted text before drafting a grade."
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
        statusMessage = "OCR reviewed. Draft grading is now available if local AI and rubric are ready."
    }

    func draftGrade() async {
        guard canDraftGrade else {
            errorMessage = readinessIssues.first ?? "Draft grading is not ready."
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
            statusMessage = "Draft grade generated locally. Start final review before using it."
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
}
