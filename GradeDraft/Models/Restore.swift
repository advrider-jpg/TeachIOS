import Foundation

// MARK: - Backup contents

/// Everything in the app database, as decoded from or written to `snapshot.json`.
/// A Teacher Record archive carries the same type holding a single submission.
struct BackupSnapshot: Codable, Equatable, Sendable {
    var classGroups: [ClassGroup]
    var students: [Student]
    var enrollments: [Enrollment]
    var assignments: [AssignmentSetup]
    var submissions: [SubmissionGraph]
    /// Audit events that belong to an assignment but no single submission.
    var assignmentAuditEvents: [AuditEvent]
    /// Exports that belong to no single submission (class-level exports and full backups).
    var unattachedExports: [ExportRecord]

    init(
        classGroups: [ClassGroup] = [],
        students: [Student] = [],
        enrollments: [Enrollment] = [],
        assignments: [AssignmentSetup] = [],
        submissions: [SubmissionGraph] = [],
        assignmentAuditEvents: [AuditEvent] = [],
        unattachedExports: [ExportRecord] = []
    ) {
        self.classGroups = classGroups
        self.students = students
        self.enrollments = enrollments
        self.assignments = assignments
        self.submissions = submissions
        self.assignmentAuditEvents = assignmentAuditEvents
        self.unattachedExports = unattachedExports
    }

    /// True when any record ID appears twice (a crafted or damaged backup).
    var containsDuplicateIDs: Bool {
        var seen = Set<String>()
        func isNew(_ table: String, _ id: String) -> Bool { seen.insert(table + "/" + id).inserted }

        for item in classGroups where !isNew("classGroup", item.id.uuidString) { return true }
        for item in students where !isNew("student", item.id.uuidString) { return true }
        for item in enrollments where !isNew("enrollment", "\(item.classGroupID.uuidString)/\(item.studentID.uuidString)") { return true }
        for setup in assignments {
            if !isNew("assignment", setup.assignment.id.uuidString) { return true }
            for item in setup.appliedTemplates where !isNew("appliedTemplate", item.id.uuidString) { return true }
            for item in setup.curriculumMappings where !isNew("curriculumMapping", item.id.uuidString) { return true }
        }
        for item in assignmentAuditEvents where !isNew("auditEvent", item.id.uuidString) { return true }
        for item in unattachedExports where !isNew("exportRecord", item.id.uuidString) { return true }
        for graph in submissions {
            if !isNew("submission", graph.submission.id.uuidString) { return true }
            if !isNew("submissionStudent", "\(graph.submission.assignmentID.uuidString)/\(graph.submission.studentID.uuidString)") { return true }
            for item in graph.sources where !isNew("sourceInput", item.id.uuidString) { return true }
            if let ocr = graph.ocr {
                if !isNew("ocrDocument", ocr.id.uuidString) { return true }
                for page in ocr.pages {
                    if !isNew("ocrPage", page.id.uuidString) { return true }
                    for line in page.lines where !isNew("ocrLine", line.id.uuidString) { return true }
                }
            }
            if let draft = graph.draft {
                if !isNew("draft", draft.id.uuidString) { return true }
                for item in draft.criteria where !isNew("draftCriterion", item.id.uuidString) { return true }
            }
            if let review = graph.finalReview {
                if !isNew("finalReview", review.id.uuidString) { return true }
                for item in review.criteria {
                    if !isNew("finalReviewCriterion", item.id.uuidString) { return true }
                    var evidenceSeen = Set<UUID>()
                    for evidenceID in item.evidenceIDs where !evidenceSeen.insert(evidenceID).inserted { return true }
                }
            }
            for item in graph.evidence where !isNew("evidence", item.id.uuidString) { return true }
            for item in graph.exports where !isNew("exportRecord", item.id.uuidString) { return true }
            for item in graph.audit where !isNew("auditEvent", item.id.uuidString) { return true }
        }
        return false
    }
}

/// `manifest.json` in a full backup.
struct BackupManifest: Codable, Equatable, Sendable {
    static let currentFormatVersion = 1

    var formatVersion: Int
    var createdAt: Date
    var appVersion: String
    /// SHA-256 of every source file, keyed by its path inside the archive (`sources/<submissionID>/<file>`).
    var sourceSHA256: [String: String]
}

// MARK: - Restore

/// The teacher's choice for an assignment that exists both locally and in the backup.
/// An assignment and all of its submissions move together.
enum RestoreResolution: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case keepLocal
    case replaceLocal
    case restoreAsCopy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .keepLocal: return "Keep Current Records"
        case .replaceLocal: return "Replace Current Records"
        case .restoreAsCopy: return "Import as New Copy"
        }
    }
}

/// A decoded, verified backup waiting for the teacher's confirmation. Confirm uses this same
/// value: the snapshot is not decoded again, and the staged files stay where they are.
struct RestorePreview: Equatable, Sendable {
    var manifest: BackupManifest
    var snapshot: BackupSnapshot
    /// `Application Support/RestoreStaging-<uuid>/`, holding the backup's source files under `Sources/`.
    var stagingDirectory: URL
    /// Assignments in the backup that already exist locally; each needs a `RestoreResolution`.
    var conflictingAssignmentIDs: [UUID]

    var assignmentCount: Int { snapshot.assignments.count }
    var classCount: Int { snapshot.classGroups.count }
    var studentCount: Int { snapshot.students.count }
    var sourceFileCount: Int { manifest.sourceSHA256.count }
}

/// One source file to move from the staging folder into local storage after the database commit.
struct SourceFileMove: Equatable, Sendable {
    /// Path in the backup (and in the staging folder), `Sources/<backup submissionID>/<file>`.
    var stagedRelativePath: String
    /// Path the restored record points to; differs from `stagedRelativePath` for a restored copy.
    var destinationRelativePath: String
}

struct RestoreOutcome: Equatable, Sendable {
    static let completeMessage = "Restore complete."

    var addedAssignmentIDs: [UUID] = []
    var keptLocalAssignmentIDs: [UUID] = []
    var replacedAssignmentIDs: [UUID] = []
    /// Backup assignment ID → ID of the new copy.
    var copiedAssignmentIDs: [UUID: UUID] = [:]
    var sourceFileMoves: [SourceFileMove] = []
    /// Local files of replaced assignments that no restored record uses any more.
    var obsoleteLocalFilePaths: [String] = []
}
