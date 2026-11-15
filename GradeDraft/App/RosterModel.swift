import Foundation
import GRDB
import Observation

/// A roster file read and checked, waiting for the teacher's confirmation.
struct RosterImportPreview: Equatable, Sendable {
    var fileName: String
    var rows: [RosterImportRow]
    /// The file-reading half: ignored and unrecognised columns, skipped rows, header detection.
    var fileResult: RosterImportResult
}

/// One class: its details, students and assignments, for the class detail screen. When the class no
/// longer exists, `isMissing` becomes true and every action does nothing.
@Observable @MainActor
final class RosterModel {
    let classGroupID: UUID

    private(set) var students: [Student] = []
    private(set) var isMissing = false
    private(set) var hasLoaded = false
    var alert: AlertMessage?

    private(set) var rosterPreview: RosterImportPreview?
    /// The last confirmed import: the file-reading result merged with the store's (`imported`, `warnings`).
    private(set) var lastImportResult: RosterImportResult?

    @ObservationIgnored let app: AppModel

    init(classGroupID: UUID, app: AppModel) {
        self.classGroupID = classGroupID
        self.app = app
    }

    var classGroup: ClassGroup? {
        app.classGroups.first { $0.id == classGroupID }
    }

    var assignments: [AssignmentSummary] {
        app.assignmentSummaries.filter { $0.assignment.classGroupID == classGroupID }
    }

    // MARK: - Observation

    /// Keeps `students` current and detects a deleted class for as long as the calling task runs.
    func observe() async {
        let database: AppDatabase
        do {
            database = try app.requireDatabase()
        } catch {
            alert = AlertMessage(title: "Class could not be opened", error: error)
            return
        }
        let classGroupID = classGroupID
        let observation = ValueObservation
            .tracking(region: Table("classGroup"), Table("student"), Table("enrollment"), fetch: { db in
                try ClassGroup.exists(db, id: classGroupID)
            })
            .values(in: database.writer)
        do {
            for try await exists in observation {
                guard exists else {
                    isMissing = true
                    rosterPreview = nil
                    continue
                }
                students = try await database.students(inClass: classGroupID)
                hasLoaded = true
            }
        } catch is CancellationError {
        } catch {
            alert = AlertMessage(title: "Class could not be read", error: error)
        }
    }

    private func requireDatabase(_ action: String) -> AppDatabase? {
        guard !isMissing else { return nil }
        do {
            return try app.requireDatabase()
        } catch {
            alert = AlertMessage(title: action, error: error)
            return nil
        }
    }

    // MARK: - Class details

    /// Edits and saves the class's details (name, year, term, subject, notes, archived).
    func updateClass(_ change: (inout ClassGroup) -> Void) async {
        guard let database = requireDatabase("Class not saved"), var classGroup else { return }
        change(&classGroup)
        classGroup.updatedAt = Date()
        do {
            try await database.save(classGroup)
        } catch {
            alert = AlertMessage(title: "Class not saved", error: error)
        }
    }

    // MARK: - Students

    /// Adds a student to this class; the store creates their submissions for the class's assignments.
    func enrol(displayName: String, localIdentifier: String = "", notes: String = "") async {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let database = requireDatabase("Student not added") else { return }
        guard !name.isEmpty else {
            alert = AlertMessage(title: "Student not added", message: "Enter the student's name.")
            return
        }
        do {
            try await database.save(
                Student(
                    displayName: name,
                    localIdentifier: localIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                ),
                enrolledIn: classGroupID
            )
        } catch {
            alert = AlertMessage(title: "Student not added", error: error)
        }
    }

    /// Removes the student from this class: deletes their submissions for this class's assignments and
    /// those submissions' source files. The student record and their other classes stay.
    func removeStudent(_ studentID: UUID) async {
        guard let database = requireDatabase("Student not removed") else { return }
        do {
            let paths = try await database.removeEnrollment(studentID: studentID, classGroupID: classGroupID)
            let failed = SourceFileCleanup.delete(paths, storageRoot: try app.requireStorageRoot())
            if !failed.isEmpty {
                alert = AlertMessage(title: "Files not deleted", message: SourceFileCleanup.failureMessage(failed))
            }
        } catch {
            alert = AlertMessage(title: "Student not removed", error: error)
        }
    }

    // MARK: - Roster import

    /// Reads a CSV, text or Excel roster and shows what would be imported.
    func previewRosterFile(at url: URL) {
        guard !isMissing else { return }
        do {
            let parsed = try RosterImportService.parse(fileAt: url)
            rosterPreview = RosterImportPreview(fileName: url.lastPathComponent, rows: parsed.rows, fileResult: parsed.result)
        } catch {
            alert = AlertMessage(title: "Roster not read", error: error)
        }
    }

    /// Imports the previewed rows into this class.
    func confirmRosterImport() async {
        guard let preview = rosterPreview, let database = requireDatabase("Roster not imported") else { return }
        do {
            let saved = try await database.importRoster(preview.rows, into: classGroupID)
            var merged = preview.fileResult
            merged.imported = saved.imported
            merged.warnings = preview.fileResult.warnings + saved.warnings
            lastImportResult = merged
            rosterPreview = nil
        } catch {
            alert = AlertMessage(title: "Roster not imported", error: error)
        }
    }

    func discardRosterPreview() {
        rosterPreview = nil
    }
}
