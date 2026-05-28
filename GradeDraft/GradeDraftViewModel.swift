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

    private let ocrService: OCRServicing
    private let gradingService: GradingServicing & CapabilityChecking
    private let store: AssignmentStoring

    init(
        assignments: [AssignmentRecord] = [],
        ocrService: OCRServicing = VisionOCRService(),
        gradingService: GradingServicing & CapabilityChecking = FoundationModelGradingService(),
        store: AssignmentStoring = LocalJSONStore()
    ) {
        self.ocrService = ocrService
        self.gradingService = gradingService
        self.store = store

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

    var canDraftGrade: Bool {
        assignment.assignmentInputReady && !isWorking
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
        refreshCapabilityStatus()
    }

    func newAssignment(from template: RubricTemplate? = nil) {
        var newRecord = AssignmentRecord()
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
        transform(&updated)
        updated.updatedAt = Date()
        upsertAssignment(updated)
    }

    func applyTemplate(_ template: RubricTemplate) {
        updateAssignment { assignment in
            assignment.assignmentType = template.assignmentType
            assignment.rubricText = template.rubricText
            assignment.customInstructions = template.customInstructions
            assignment.latestDraft = nil
            assignment.finalReview = nil
        }
        persistOrSurfaceError()
        statusMessage = "Template applied locally. Review before grading."
    }

    func applyPastedStudentText(_ text: String) {
        updateAssignment { assignment in
            assignment.reviewedStudentText = text
            assignment.ocrDocument = nil
            assignment.latestDraft = nil
            assignment.finalReview = nil
        }
        persistOrSurfaceError()
    }

    func applyScannedImages(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        isWorking = true
        errorMessage = nil
        exportURL = nil
        defer { isWorking = false }

        do {
            let document = try await ocrService.recognizeText(in: images)
            updateAssignment { assignment in
                assignment.ocrDocument = document
                assignment.reviewedStudentText = document.combinedText
                assignment.latestDraft = nil
                assignment.finalReview = nil
            }
            statusMessage = document.hasLowConfidenceText
                ? "OCR complete. Review uncertain text before drafting a grade."
                : "OCR complete. Review the extracted text before drafting a grade."
            try saveCurrentAssignment()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func draftGrade() async {
        isWorking = true
        errorMessage = nil
        exportURL = nil
        defer { isWorking = false }

        do {
            let result = try await gradingService.draftGrade(input: assignment.gradingInput)
            updateAssignment { assignment in
                assignment.latestDraft = result
                assignment.finalReview = nil
            }
            statusMessage = "Draft grade generated locally. Review and finalize before using."
            try saveCurrentAssignment()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func finalizeLatestDraft() {
        guard let draft = assignment.latestDraft else { return }
        let final = FinalGradeReview(
            criteria: draft.criteria,
            totalScore: draft.totalScore,
            maxScore: draft.maxScore,
            studentFeedback: draft.studentFeedback,
            privateTeacherNotes: draft.teacherNotes,
            teacherEdited: false
        )
        updateAssignment { assignment in
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: final)
        }
        persistOrSurfaceError()
        statusMessage = "Final grade saved locally."
    }

    func updateFinalReview(_ review: FinalGradeReview) {
        updateAssignment { assignment in
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
        }
        persistOrSurfaceError()
    }

    func saveCurrentAssignment() throws {
        upsertAssignment(assignment)
        do {
            try store.saveAssignments(assignments)
        } catch {
            throw GradeDraftError.persistenceFailed(error.localizedDescription)
        }
    }

    func exportCurrentAssignmentReport() {
        do {
            exportURL = try MarkdownReportBuilder.writeTemporaryReport(for: assignment)
            statusMessage = "Local Markdown report is ready to share."
        } catch {
            errorMessage = error.localizedDescription
        }
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
}
