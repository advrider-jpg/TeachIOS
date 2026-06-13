import Foundation
import PDFKit
import UIKit
import ZIPFoundation

@MainActor
extension GradeDraftViewModel {
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
        var nextAssignments = assignments.filter { $0.id != selectedAssignmentID }
        if nextAssignments.isEmpty {
            nextAssignments = [AssignmentRecord()]
        }
        let nextRosterEntries = assignmentRosterEntries.filter { $0.assignmentID != selectedAssignmentID }
        let nextSelectedAssignmentID = nextAssignments.first?.id
        do {
            try store.replaceLocalDataSnapshot(
                AssignmentStoreSnapshot(
                    assignments: nextAssignments,
                    classGroups: classGroups,
                    students: students,
                    rosterEntries: nextRosterEntries
                )
            )
            assignments = nextAssignments
            assignmentRosterEntries = nextRosterEntries
            self.selectedAssignmentID = nextSelectedAssignmentID

            var sourceCleanupWarning: String?
            if let appDir = try? store.applicationSupportDirectory(),
               let toDelete = assignmentToDelete,
               !toDelete.sourceInputs.isEmpty {
                let sourceDir = appDir
                    .appendingPathComponent("Sources", isDirectory: true)
                    .appendingPathComponent(selectedAssignmentID.uuidString, isDirectory: true)
                if fileManager.fileExists(atPath: sourceDir.path) {
                    do {
                        try fileManager.removeItem(at: sourceDir)
                    } catch {
                        sourceCleanupWarning = error.localizedDescription
                    }
                }
            }
            if let sourceCleanupWarning {
                errorMessage = "Assignment record was deleted, but its local source-file folder could not be removed: \(sourceCleanupWarning)"
            } else {
                statusMessage = "Assignment deleted locally."
            }
        } catch {
            reloadFromStoreAfterPersistenceFailure()
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func updateAssignment(_ transform: (inout AssignmentRecord) -> Void) {
        guard let selectedAssignmentID,
              let current = assignments.first(where: { $0.id == selectedAssignmentID }) else {
            errorMessage = "Assignment could not be updated because it is not saved on this device."
            return
        }
        var updated = current
        let previousFingerprint = updated.gradingPacketFingerprint
        let previousSourceFingerprint = updated.gradingSourceFingerprint
        transform(&updated)
        updated.updatedAt = Date()
        if updated.gradingPacketFingerprint != previousFingerprint {
            if updated.latestDraft != nil {
                updated.latestDraft?.status = .stale
                updated.appendAuditEvent(.draftMarkedStale, detail: "Grading inputs changed after a draft was generated.")
            }
            if updated.finalReview != nil && updated.gradingSourceFingerprint != previousSourceFingerprint {
                updated.finalReview?.status = .stale
                updated.appendAuditEvent(.finalReviewMarkedStale, detail: "Source grading inputs changed after final review.")
            }
        }
        upsertAssignment(updated)
    }

    func saveCurrentAssignment() throws {
        guard let selectedAssignmentID,
              assignments.contains(where: { $0.id == selectedAssignmentID }) else {
            throw GradeDraftError.persistenceFailed("Assignment could not be saved because it is not saved on this device.")
        }
        upsertAssignment(assignment)
        do {
            try store.saveAssignments(assignments)
        } catch {
            reloadFromStoreAfterPersistenceFailure()
            throw GradeDraftError.persistenceFailed(error.localizedDescription)
        }
    }

    func upsertAssignment(_ updated: AssignmentRecord) {
        var updated = updated
        updated.updatedAt = Date()
        if let index = assignments.firstIndex(where: { $0.id == updated.id }) {
            assignments[index] = updated
        } else {
            assignments.insert(updated, at: 0)
        }
        assignments.sort { $0.updatedAt > $1.updatedAt }
    }

    func persistOrSurfaceError() -> Bool {
        do {
            try saveCurrentAssignment()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func currentStoreSnapshot(
        assignments: [AssignmentRecord]? = nil,
        classGroups: [ClassGroupRecord]? = nil,
        students: [StudentRecord]? = nil,
        rosterEntries: [AssignmentRosterEntry]? = nil
    ) -> AssignmentStoreSnapshot {
        let nextAssignments = assignments ?? self.assignments
        let nextClassGroups = classGroups ?? self.classGroups
        let nextStudents = students ?? self.students
        let nextRosterEntries = reconciledRosterEntries(
            rosterEntries ?? self.assignmentRosterEntries,
            assignments: nextAssignments,
            students: nextStudents
        )
        return AssignmentStoreSnapshot(
            assignments: nextAssignments,
            classGroups: nextClassGroups,
            students: nextStudents,
            rosterEntries: nextRosterEntries
        )
    }

    func reloadFromStoreAfterPersistenceFailure() {
        let previousSelection = selectedAssignmentID
        do {
            let loadedAssignments = try store.loadAssignments()
            assignments = loadedAssignments.isEmpty ? [AssignmentRecord()] : loadedAssignments
            classGroups = try store.loadClassGroups()
            students = try store.loadStudents()
            assignmentRosterEntries = try store.loadAssignmentRosterSnapshot()
            if classGroups.isEmpty { classGroups = Self.classGroupsFromAssignments(assignments) }
            if students.isEmpty { students = Self.studentsFromAssignments(assignments) }
            reconcileRosterEntriesWithCurrentAssignments()
            selectedAssignmentID = previousSelection.flatMap { selected in assignments.contains(where: { $0.id == selected }) ? selected : nil } ?? assignments.first?.id
            refreshAIReadiness()
        } catch {
            errorMessage = GradeDraftError.persistenceFailed("Could not reload local records after a failed save: \(error.localizedDescription)").localizedDescription
        }
    }
}
