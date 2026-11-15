import Foundation
import GRDB

enum AppDatabaseError: LocalizedError {
    case openFailed(underlying: any Error)
    case dataCorrupted(table: String, rowID: String, underlying: any Error)
    case notFound(UUID)
    case writeFailed(underlying: any Error)

    var errorDescription: String? {
        switch self {
        case .openFailed(let underlying):
            return "The saved-work database could not be opened: \(underlying.localizedDescription)"
        case .dataCorrupted(let table, let rowID, let underlying):
            return "Saved data can't be read (\(table) record \(rowID)): \(underlying.localizedDescription)"
        case .notFound:
            return "This item no longer exists. It may have been deleted."
        case .writeFailed(let underlying):
            return "The change could not be saved: \(underlying.localizedDescription)"
        }
    }
}

/// Marking scanned text reviewed while lines still need the teacher's action.
struct OCRReviewIncompleteError: LocalizedError, Equatable {
    var unresolvedLineCount: Int

    var errorDescription: String? {
        "Confirm, correct or reject the \(unresolvedLineCount) highlighted line(s) before marking the scanned text reviewed."
    }
}

/// A restore was asked to proceed while an assignment that exists locally has no keep/replace/copy choice.
struct RestoreConflictUnresolvedError: LocalizedError, Equatable {
    var assignmentIDs: [UUID]

    var errorDescription: String? {
        "Choose keep, replace or copy for every assignment that already exists on this device."
    }
}

/// A row points to a related row that is missing.
struct MissingRelatedRowError: LocalizedError {
    var detail: String

    var errorDescription: String? { detail }
}

/// Test hook: the failure `restore(_:resolutions:failBeforeCommit:)` raises just before its transaction commits.
struct InjectedRestoreFailure: LocalizedError {
    var errorDescription: String? { "Injected restore failure." }
}

/// The app's one store: GRDB, one database file, one schema (`v1`).
final class AppDatabase: Sendable {
    static let databaseFileName = "gradedraft.sqlite"

    /// `DatabasePool` on disk, `DatabaseQueue` in memory.
    let writer: any DatabaseWriter

    private init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.makeMigrator().migrate(writer)
    }

    /// `Application Support/GradeDraft/`: the database file and `Sources/<submissionID>/` live here.
    static func storageDirectory(fileManager: FileManager = .default) throws -> URL {
        try fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("GradeDraft", isDirectory: true)
    }

    static func openOnDisk(fileManager: FileManager = .default) throws -> AppDatabase {
        do {
            let folder = try storageDirectory(fileManager: fileManager)
            let isFirstOpen = !fileManager.fileExists(atPath: folder.path)
            try LocalDataProtection.prepareSensitiveDirectory(folder, fileManager: fileManager)
            let databaseURL = folder.appendingPathComponent(databaseFileName)
            let database = try AppDatabase(writer: DatabasePool(path: databaseURL.path))
            for suffix in ["", "-wal", "-shm"] {
                let fileURL = folder.appendingPathComponent(databaseFileName + suffix)
                if fileManager.fileExists(atPath: fileURL.path) {
                    try LocalDataProtection.protectDatabaseFile(fileURL, fileManager: fileManager)
                }
            }
            // The device-backup setting starts as Keep Local Only. Later opens leave the teacher's choice alone.
            if isFirstOpen {
                try LocalDataProtection.setDeviceBackupIncluded(false, storageRoot: folder, fileManager: fileManager)
            }
            return database
        } catch {
            throw AppDatabaseError.openFailed(underlying: error)
        }
    }

    /// For tests and previews.
    static func inMemory() throws -> AppDatabase {
        try AppDatabase(writer: DatabaseQueue())
    }

    // MARK: - Lists

    func classGroups() async throws -> [ClassGroup] {
        try await read { db in
            try Self.fetch(ClassGroup.self, db, sql: "SELECT * FROM classGroup ORDER BY updatedAt DESC")
        }
    }

    /// nil = every student.
    func students(inClass classGroupID: UUID?) async throws -> [Student] {
        try await read { db in
            guard let classGroupID else {
                return try Self.fetch(Student.self, db, sql: "SELECT * FROM student ORDER BY displayName")
            }
            return try Self.fetch(
                Student.self, db,
                sql: """
                SELECT student.* FROM student
                JOIN enrollment ON enrollment.studentID = student.id
                WHERE enrollment.classGroupID = ?
                ORDER BY enrollment.sortOrder, student.displayName
                """,
                arguments: [classGroupID]
            )
        }
    }

    /// nil = assignments in every class.
    func assignmentSummaries(inClass classGroupID: UUID?) async throws -> [AssignmentSummary] {
        try await read { db in
            let scope: AssignmentScope = classGroupID.map { .classGroup($0) } ?? .all
            let assignments = try Self.fetch(
                Assignment.self, db,
                sql: "SELECT * FROM assignment WHERE \(scope.whereClause) ORDER BY assignment.updatedAt DESC",
                arguments: scope.arguments
            )
            let classNames = Dictionary(
                try Self.fetch(ClassGroup.self, db, sql: "SELECT * FROM classGroup").map { ($0.id, $0.name) },
                uniquingKeysWith: { first, _ in first }
            )
            let counts = Dictionary(
                try Self.fetch(
                    SubmissionCountRow.self, db, table: Submission.databaseTableName,
                    sql: """
                    SELECT submission.assignmentID AS assignmentID, COUNT(*) AS submissionCount
                    FROM submission JOIN assignment ON assignment.id = submission.assignmentID
                    WHERE \(scope.whereClause)
                    GROUP BY submission.assignmentID
                    """,
                    arguments: scope.arguments
                ).map { ($0.assignmentID, $0.submissionCount) },
                uniquingKeysWith: { first, _ in first }
            )
            return assignments.map { assignment in
                AssignmentSummary(
                    assignment: assignment,
                    className: classNames[assignment.classGroupID] ?? "",
                    submissionCount: counts[assignment.id] ?? 0
                )
            }
        }
    }

    /// nil = every submission (Home and Review).
    func submissionSummaries(assignmentID: UUID?) async throws -> [SubmissionSummary] {
        try await read { db in
            let graphs = try Self.fetchGraphs(db, scope: assignmentID.map { .assignment($0) } ?? .all)
            let setups = try Self.fetchSetups(db, scope: assignmentID.map { .assignment($0) } ?? .all)
            let classNames = Dictionary(
                try Self.fetch(ClassGroup.self, db, sql: "SELECT * FROM classGroup").map { ($0.id, $0.name) },
                uniquingKeysWith: { first, _ in first }
            )
            let rosterOrder = Dictionary(
                try Self.fetch(Enrollment.self, db, sql: "SELECT * FROM enrollment").map { ($0.id, $0.sortOrder) },
                uniquingKeysWith: { first, _ in first }
            )
            var setupByID: [UUID: (setup: AssignmentSetup, encoding: Data)] = [:]
            for setup in setups {
                setupByID[setup.id] = (setup, try setup.canonicalEncoding())
            }

            var summaries: [SubmissionSummary] = []
            for graph in graphs {
                guard let entry = setupByID[graph.submission.assignmentID] else {
                    throw AppDatabaseError.dataCorrupted(
                        table: Submission.databaseTableName,
                        rowID: graph.submission.id.uuidString,
                        underlying: MissingRelatedRowError(detail: "The submission's assignment is missing.")
                    )
                }
                let fingerprint = SubmissionGraph.packetFingerprint(setupEncoding: entry.encoding, reviewedText: graph.reviewedText)
                let classGroupID = entry.setup.assignment.classGroupID
                summaries.append(
                    SubmissionSummary(
                        id: graph.submission.id,
                        assignmentID: entry.setup.id,
                        assignmentTitle: entry.setup.assignment.title,
                        classGroupID: classGroupID,
                        className: classNames[classGroupID] ?? "",
                        studentID: graph.student.id,
                        studentName: graph.student.displayName,
                        localIdentifier: graph.student.localIdentifier,
                        rosterOrder: rosterOrder[EnrollmentID(classGroupID: classGroupID, studentID: graph.student.id)],
                        rosterStatus: graph.rosterStatus(currentFingerprint: fingerprint),
                        lastExportedAt: graph.exports.map(\.createdAt).max(),
                        updatedAt: graph.submission.updatedAt
                    )
                )
            }
            return summaries.sorted { lhs, rhs in
                if lhs.assignmentTitle != rhs.assignmentTitle { return lhs.assignmentTitle < rhs.assignmentTitle }
                if lhs.assignmentID != rhs.assignmentID { return lhs.assignmentID.uuidString < rhs.assignmentID.uuidString }
                let lhsOrder = lhs.rosterOrder ?? Int.max
                let rhsOrder = rhs.rosterOrder ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return lhs.studentName.localizedStandardCompare(rhs.studentName) == .orderedAscending
            }
        }
    }

    /// nil = enrolments in every class.
    func enrollments(inClass classGroupID: UUID?) async throws -> [Enrollment] {
        try await read { db in
            guard let classGroupID else {
                return try Self.fetch(Enrollment.self, db, sql: "SELECT * FROM enrollment ORDER BY classGroupID, sortOrder")
            }
            return try Self.fetch(
                Enrollment.self, db,
                sql: "SELECT * FROM enrollment WHERE classGroupID = ? ORDER BY sortOrder",
                arguments: [classGroupID]
            )
        }
    }

    /// The most recent exports, newest first: the export record with its assignment title and the student's
    /// display name. A full backup has neither; a class-level export has no student. One query.
    func recentExports(limit: Int) async throws -> [ExportRecordSummary] {
        try await read { db in
            try Self.fetch(
                ExportRecordSummary.self, db, table: ExportRecord.databaseTableName,
                sql: """
                SELECT exportRecord.id AS id, exportRecord.kind AS kind, exportRecord.createdAt AS createdAt,
                       assignment.title AS assignmentTitle, student.displayName AS studentName
                FROM exportRecord
                LEFT JOIN assignment ON assignment.id = exportRecord.assignmentID
                LEFT JOIN submission ON submission.id = exportRecord.submissionID
                LEFT JOIN student ON student.id = submission.studentID
                ORDER BY exportRecord.createdAt DESC
                LIMIT ?
                """,
                arguments: [limit]
            )
        }
    }

    /// Whether any submission of the assignment has scanned text (input kind scanned).
    func assignmentHasScannedText(assignmentID: UUID) async throws -> Bool {
        try await read { db in
            try Bool.fetchOne(
                db,
                sql: "SELECT EXISTS(SELECT 1 FROM submission WHERE assignmentID = ? AND inputKind = ?)",
                arguments: [assignmentID, SubmissionInputKind.scanned.rawValue]
            ) ?? false
        }
    }

    /// Every submission of the assignment, fully loaded, in creation order.
    func submissionGraphs(assignmentID: UUID) async throws -> [SubmissionGraph] {
        try await read { db in try Self.fetchGraphs(db, scope: .assignment(assignmentID)) }
    }

    /// One query, no graphs: what Shortcuts needs to list submissions. Most recently changed first.
    func submissionTitles() async throws -> [SubmissionTitle] {
        try await read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT submission.id AS id, assignment.id AS assignmentID, assignment.title AS assignmentTitle,
                       student.displayName AS studentName, classGroup.name AS className
                FROM submission
                JOIN assignment ON assignment.id = submission.assignmentID
                JOIN student ON student.id = submission.studentID
                JOIN classGroup ON classGroup.id = assignment.classGroupID
                ORDER BY submission.updatedAt DESC
                """
            ).map { row in
                SubmissionTitle(
                    id: row["id"], assignmentTitle: row["assignmentTitle"], assignmentID: row["assignmentID"],
                    studentName: row["studentName"], className: row["className"]
                )
            }
        }
    }

    // MARK: - Observation

    func observeSubmission(id: UUID) -> AsyncValueObservation<SubmissionGraph?> {
        ValueObservation
            .tracking { db in try Self.fetchGraphs(db, scope: .submission(id)).first }
            .values(in: writer)
    }

    func observeAssignment(id: UUID) -> AsyncValueObservation<AssignmentSetup?> {
        ValueObservation
            .tracking { db in try Self.fetchSetups(db, scope: .assignment(id)).first }
            .values(in: writer)
    }

    // MARK: - Reads

    func assignmentSetup(id: UUID) async throws -> AssignmentSetup? {
        try await read { db in try Self.fetchSetups(db, scope: .assignment(id)).first }
    }

    func submission(id: UUID) async throws -> SubmissionGraph? {
        try await read { db in try Self.fetchGraphs(db, scope: .submission(id)).first }
    }

    // MARK: - Writes (each is one transaction)

    func save(_ classGroup: ClassGroup) async throws {
        try await write { db in try classGroup.save(db) }
    }

    /// Deletes the class with its assignments and their submissions. Returns the source paths of the
    /// deleted submissions, for the caller to delete.
    func deleteClassGroup(id: UUID) async throws -> [String] {
        try await write { db in
            let paths = try Self.sourcePaths(db, whereSubmission: """
                submission.assignmentID IN (SELECT id FROM assignment WHERE classGroupID = ?)
                """, arguments: [id])
            guard try ClassGroup.deleteOne(db, id: id) else { throw AppDatabaseError.notFound(id) }
            return paths
        }
    }

    /// Saves the student and, when `classGroupID` is given, enrols them there (creating their
    /// submissions for the class's existing assignments).
    func save(_ student: Student, enrolledIn classGroupID: UUID?) async throws {
        try await write { db in
            if let classGroupID, try !ClassGroup.exists(db, id: classGroupID) {
                throw AppDatabaseError.notFound(classGroupID)
            }
            try student.save(db)
            guard let classGroupID else { return }
            let enrolled = try Bool.fetchOne(
                db,
                sql: "SELECT EXISTS(SELECT 1 FROM enrollment WHERE classGroupID = ? AND studentID = ?)",
                arguments: [classGroupID, student.id]
            ) ?? false
            if !enrolled {
                try Enrollment(classGroupID: classGroupID, studentID: student.id, sortOrder: Self.nextSortOrder(db, classGroupID: classGroupID)).insert(db)
                try Self.createMissingSubmissions(db, classGroupID: classGroupID)
            }
        }
    }

    /// Deletes the student with their submissions. Returns the source paths of the deleted submissions,
    /// for the caller to delete.
    func deleteStudent(id: UUID) async throws -> [String] {
        try await write { db in
            let paths = try Self.sourcePaths(db, whereSubmission: "submission.studentID = ?", arguments: [id])
            guard try Student.deleteOne(db, id: id) else { throw AppDatabaseError.notFound(id) }
            return paths
        }
    }

    /// Removes the student from the class and deletes their submissions for that class's assignments
    /// only. The student record and their other classes stay. Returns the source paths of the deleted
    /// submissions, for the caller to delete.
    func removeEnrollment(studentID: UUID, classGroupID: UUID) async throws -> [String] {
        try await write { db in
            try db.execute(
                sql: "DELETE FROM enrollment WHERE studentID = ? AND classGroupID = ?",
                arguments: [studentID, classGroupID]
            )
            guard db.changesCount > 0 else { throw AppDatabaseError.notFound(studentID) }
            let inClass = """
                submission.studentID = ?
                AND submission.assignmentID IN (SELECT id FROM assignment WHERE classGroupID = ?)
                """
            let paths = try Self.sourcePaths(db, whereSubmission: inClass, arguments: [studentID, classGroupID])
            try db.execute(
                sql: """
                DELETE FROM submission
                WHERE studentID = ? AND assignmentID IN (SELECT id FROM assignment WHERE classGroupID = ?)
                """,
                arguments: [studentID, classGroupID]
            )
            return paths
        }
    }

    /// Adds the rows as students of the class. A row whose local identifier (or, without one, whose
    /// name) is already in the class is skipped with a warning. Fills `imported` and `warnings`.
    func importRoster(_ rows: [RosterImportRow], into classGroupID: UUID) async throws -> RosterImportResult {
        try await write { db in
            guard try ClassGroup.exists(db, id: classGroupID) else { throw AppDatabaseError.notFound(classGroupID) }
            let enrolled = try Self.fetch(
                Student.self, db,
                sql: "SELECT student.* FROM student JOIN enrollment ON enrollment.studentID = student.id WHERE enrollment.classGroupID = ?",
                arguments: [classGroupID]
            )
            var knownIdentifiers = Set(enrolled.map { $0.localIdentifier.lowercased() }.filter { !$0.isEmpty })
            var knownNames = Set(enrolled.filter { $0.localIdentifier.isEmpty }.map { $0.displayName.lowercased() })
            var sortOrder = try Self.nextSortOrder(db, classGroupID: classGroupID)
            var result = RosterImportResult()
            let now = Date()

            for row in rows {
                let name = row.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                let identifier = row.localIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    result.warnings.append("A row without a student name was skipped.")
                    continue
                }
                if !identifier.isEmpty, knownIdentifiers.contains(identifier.lowercased()) {
                    result.warnings.append("\(name) (\(identifier)) is already in this class and was skipped.")
                    continue
                }
                if identifier.isEmpty, knownNames.contains(name.lowercased()) {
                    result.warnings.append("\(name) is already in this class and was skipped.")
                    continue
                }
                let student = Student(
                    displayName: name,
                    localIdentifier: identifier,
                    notes: row.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    createdAt: now,
                    updatedAt: now
                )
                try student.insert(db)
                try Enrollment(classGroupID: classGroupID, studentID: student.id, sortOrder: sortOrder).insert(db)
                sortOrder += 1
                result.imported += 1
                if identifier.isEmpty { knownNames.insert(name.lowercased()) } else { knownIdentifiers.insert(identifier.lowercased()) }
            }
            try Self.createMissingSubmissions(db, classGroupID: classGroupID)
            return result
        }
    }

    /// Also creates one submission per enrolled student.
    func createAssignment(_ assignment: Assignment) async throws {
        try await write { db in
            guard try ClassGroup.exists(db, id: assignment.classGroupID) else {
                throw AppDatabaseError.notFound(assignment.classGroupID)
            }
            try assignment.insert(db)
            try Self.createMissingSubmissions(db, classGroupID: assignment.classGroupID)
        }
    }

    /// Appends one `draftMarkedStale` / `finalReviewMarkedStale` audit event per submission, only when
    /// this save turns a current draft or final review stale.
    func saveSetup(_ setup: AssignmentSetup) async throws {
        try await write { db in
            let assignmentID = setup.assignment.id
            guard let previous = try Self.fetchSetups(db, scope: .assignment(assignmentID)).first else {
                throw AppDatabaseError.notFound(assignmentID)
            }
            let previousEncoding = try previous.canonicalEncoding()
            let newEncoding = try setup.canonicalEncoding()
            // Only graded submissions can turn stale, and only when the grading inputs changed.
            let graphs = previousEncoding == newEncoding
                ? []
                : try Self.fetchGraphs(db, scope: .gradedInAssignment(assignmentID))
            let now = Date()
            var events: [AuditEvent] = []
            for graph in graphs {
                let before = SubmissionGraph.packetFingerprint(setupEncoding: previousEncoding, reviewedText: graph.reviewedText)
                let after = SubmissionGraph.packetFingerprint(setupEncoding: newEncoding, reviewedText: graph.reviewedText)
                if let draft = graph.draft, draft.packetFingerprint == before, draft.packetFingerprint != after {
                    events.append(AuditEvent(
                        assignmentID: assignmentID, submissionID: graph.id, timestamp: now, eventType: .draftMarkedStale,
                        detail: "The assignment setup changed, so the AI draft no longer matches the grading inputs."
                    ))
                }
                if let review = graph.finalReview, review.packetFingerprint == before, review.packetFingerprint != after {
                    events.append(AuditEvent(
                        assignmentID: assignmentID, submissionID: graph.id, timestamp: now, eventType: .finalReviewMarkedStale,
                        detail: "The assignment setup changed, so the final review no longer matches the grading inputs."
                    ))
                }
            }

            try setup.assignment.update(db)
            try db.execute(sql: "DELETE FROM appliedTemplate WHERE assignmentID = ?", arguments: [assignmentID])
            for template in setup.appliedTemplates {
                var template = template
                template.assignmentID = assignmentID
                try template.insert(db)
            }
            try db.execute(sql: "DELETE FROM curriculumMapping WHERE assignmentID = ?", arguments: [assignmentID])
            for mapping in setup.curriculumMappings {
                var mapping = mapping
                mapping.assignmentID = assignmentID
                try mapping.insert(db)
            }
            for event in events { try event.insert(db) }
        }
    }

    /// Deletes the assignment with its submissions. Returns the source paths of the deleted submissions,
    /// for the caller to delete.
    func deleteAssignment(id: UUID) async throws -> [String] {
        try await write { db in
            let paths = try Self.sourcePaths(db, whereSubmission: "submission.assignmentID = ?", arguments: [id])
            guard try Assignment.deleteOne(db, id: id) else { throw AppDatabaseError.notFound(id) }
            return paths
        }
    }

    /// Replaces the submission's student work. Old sources, scanned text and evidence are removed in the
    /// same transaction. Returns the replaced source paths no new source uses, for the caller to delete.
    func replaceInput(
        submissionID: UUID,
        kind: SubmissionInputKind,
        pastedText: String?,
        sources: [SourceInputRef],
        ocr: OCRDocument?
    ) async throws -> [String] {
        try await write { db in
            guard var submission = try Self.fetch(
                Submission.self, db, sql: "SELECT * FROM submission WHERE id = ?", arguments: [submissionID]
            ).first else {
                throw AppDatabaseError.notFound(submissionID)
            }
            let oldPaths = try String.fetchAll(
                db,
                sql: "SELECT localRelativePath FROM sourceInput WHERE submissionID = ? AND localRelativePath IS NOT NULL",
                arguments: [submissionID]
            )
            try db.execute(sql: "DELETE FROM evidence WHERE submissionID = ?", arguments: [submissionID])
            try db.execute(sql: "DELETE FROM ocrDocument WHERE submissionID = ?", arguments: [submissionID])
            try db.execute(sql: "DELETE FROM sourceInput WHERE submissionID = ?", arguments: [submissionID])

            submission.inputKind = kind
            submission.pastedText = kind == .pasted ? pastedText : nil
            submission.updatedAt = Date()
            try submission.update(db)
            try Self.insertSources(sources, submissionID: submissionID, db)
            if let ocr { try Self.insertOCR(ocr, submissionID: submissionID, db) }

            let keptPaths = Set(sources.compactMap(\.localRelativePath))
            return oldPaths.filter { !keptPaths.contains($0) }
        }
    }

    func updateOCRLine(_ line: OCRLine, submissionID: UUID) async throws {
        try await write { db in
            try Self.touchSubmission(db, id: submissionID)
            guard let existing = try Self.fetch(
                OCRLineRow.self, db,
                sql: """
                SELECT ocrLine.* FROM ocrLine
                JOIN ocrPage ON ocrPage.id = ocrLine.pageID
                JOIN ocrDocument ON ocrDocument.id = ocrPage.documentID
                WHERE ocrLine.id = ? AND ocrDocument.submissionID = ?
                """,
                arguments: [line.id, submissionID]
            ).first else {
                throw AppDatabaseError.notFound(line.id)
            }
            try OCRLineRow(line, pageID: existing.pageID, lineOrder: existing.lineOrder).update(db)
            // Changing a line's text, confirmation or rejection after the scanned text was marked reviewed puts
            // the document back to "needs review"; the teacher marks it reviewed again.
            if existing.correctedText != line.correctedText
                || existing.teacherConfirmed != line.teacherConfirmed
                || existing.isRejected != line.isRejected {
                try db.execute(
                    sql: """
                    UPDATE ocrDocument SET reviewStatus = ?, reviewedAt = NULL
                    WHERE reviewStatus = ? AND id = (SELECT documentID FROM ocrPage WHERE id = ?)
                    """,
                    arguments: [OCRReviewStatus.needsReview.rawValue, OCRReviewStatus.reviewed.rawValue, existing.pageID]
                )
            }
        }
    }

    /// `.reviewed` is refused while any line still needs the teacher's action.
    func setOCRReviewStatus(_ status: OCRReviewStatus, submissionID: UUID) async throws {
        try await write { db in
            try Self.touchSubmission(db, id: submissionID)
            guard let ocr = try Self.fetchGraphs(db, scope: .submission(submissionID)).first?.ocr else {
                throw AppDatabaseError.notFound(submissionID)
            }
            if status == .reviewed, ocr.unresolvedLineCount > 0 {
                throw AppDatabaseError.writeFailed(underlying: OCRReviewIncompleteError(unresolvedLineCount: ocr.unresolvedLineCount))
            }
            let reviewedAt: Date? = status == .reviewed ? Date() : nil
            try db.execute(
                sql: "UPDATE ocrDocument SET reviewStatus = ?, reviewedAt = ? WHERE id = ?",
                arguments: [status.rawValue, reviewedAt, ocr.id]
            )
        }
    }

    /// Stores a new AI draft and deletes the submission's final review.
    func replaceDraft(_ draft: GradeDraftResult, submissionID: UUID) async throws {
        try await write { db in
            try Self.touchSubmission(db, id: submissionID)
            try db.execute(sql: "DELETE FROM finalReview WHERE submissionID = ?", arguments: [submissionID])
            try db.execute(sql: "DELETE FROM draft WHERE submissionID = ?", arguments: [submissionID])
            try Self.insertDraft(draft, submissionID: submissionID, db)
        }
    }

    func saveFinalReview(_ review: FinalGradeReview, submissionID: UUID) async throws {
        try await write { db in
            try Self.touchSubmission(db, id: submissionID)
            try db.execute(sql: "DELETE FROM finalReview WHERE submissionID = ?", arguments: [submissionID])
            try Self.insertFinalReview(review, submissionID: submissionID, db)
        }
    }

    func addEvidence(_ evidence: EvidenceReference, submissionID: UUID) async throws {
        try await write { db in
            try Self.touchSubmission(db, id: submissionID)
            var evidence = evidence
            evidence.submissionID = submissionID
            try evidence.insert(db)
        }
    }

    func removeEvidence(id: UUID, submissionID: UUID) async throws {
        try await write { db in
            try Self.touchSubmission(db, id: submissionID)
            try db.execute(sql: "DELETE FROM evidence WHERE id = ? AND submissionID = ?", arguments: [id, submissionID])
            guard db.changesCount > 0 else { throw AppDatabaseError.notFound(id) }
        }
    }

    func recordExport(_ record: ExportRecord) async throws {
        try await write { db in
            if let assignmentID = record.assignmentID, try !Assignment.exists(db, id: assignmentID) {
                throw AppDatabaseError.notFound(assignmentID)
            }
            if let submissionID = record.submissionID, try !Submission.exists(db, id: submissionID) {
                throw AppDatabaseError.notFound(submissionID)
            }
            try record.insert(db)
        }
    }

    func appendAudit(_ event: AuditEvent) async throws {
        try await write { db in
            guard try Assignment.exists(db, id: event.assignmentID) else { throw AppDatabaseError.notFound(event.assignmentID) }
            if let submissionID = event.submissionID, try !Submission.exists(db, id: submissionID) {
                throw AppDatabaseError.notFound(submissionID)
            }
            try event.insert(db)
        }
    }

    // MARK: - Backup and restore

    func backupSnapshot() async throws -> BackupSnapshot {
        try await read { db in
            BackupSnapshot(
                classGroups: try Self.fetch(ClassGroup.self, db, sql: "SELECT * FROM classGroup ORDER BY createdAt"),
                students: try Self.fetch(Student.self, db, sql: "SELECT * FROM student ORDER BY createdAt"),
                enrollments: try Self.fetch(Enrollment.self, db, sql: "SELECT * FROM enrollment ORDER BY classGroupID, sortOrder"),
                assignments: try Self.fetchSetups(db, scope: .all),
                submissions: try Self.fetchGraphs(db, scope: .all),
                assignmentAuditEvents: try Self.fetch(
                    AuditEvent.self, db, sql: "SELECT * FROM auditEvent WHERE submissionID IS NULL ORDER BY timestamp"
                ),
                unattachedExports: try Self.fetch(
                    ExportRecord.self, db, sql: "SELECT * FROM exportRecord WHERE submissionID IS NULL ORDER BY createdAt"
                )
            )
        }
    }

    /// Restores a backup in one transaction. Classes and students are matched by
    /// ID (an existing local row is kept). Each assignment that also exists locally follows its resolution;
    /// a missing resolution fails the restore. `failBeforeCommit` is a test hook that rolls everything back.
    func restore(
        _ snapshot: BackupSnapshot,
        resolutions: [UUID: RestoreResolution],
        failBeforeCommit: Bool = false
    ) async throws -> RestoreOutcome {
        try await write { db in
            let localAssignmentIDs = Set(try UUID.fetchAll(db, sql: "SELECT id FROM assignment"))
            let conflicts = snapshot.assignments.map(\.id).filter { localAssignmentIDs.contains($0) }
            let unresolved = conflicts.filter { resolutions[$0] == nil }
            guard unresolved.isEmpty else {
                throw AppDatabaseError.writeFailed(underlying: RestoreConflictUnresolvedError(assignmentIDs: unresolved))
            }

            let localClassIDs = Set(try UUID.fetchAll(db, sql: "SELECT id FROM classGroup"))
            for classGroup in snapshot.classGroups where !localClassIDs.contains(classGroup.id) {
                try classGroup.insert(db)
            }
            let localStudentIDs = Set(try UUID.fetchAll(db, sql: "SELECT id FROM student"))
            for student in snapshot.students where !localStudentIDs.contains(student.id) {
                try student.insert(db)
            }
            let localEnrollments = Set(try Self.fetch(Enrollment.self, db, sql: "SELECT * FROM enrollment").map(\.id))
            for enrollment in snapshot.enrollments where !localEnrollments.contains(enrollment.id) {
                try enrollment.insert(db)
            }

            let graphsByAssignment = Dictionary(grouping: snapshot.submissions, by: \.submission.assignmentID)
            let auditByAssignment = Dictionary(grouping: snapshot.assignmentAuditEvents, by: \.assignmentID)
            var exportsByAssignment: [UUID: [ExportRecord]] = [:]
            var backupLevelExports: [ExportRecord] = []
            for export in snapshot.unattachedExports {
                if let assignmentID = export.assignmentID {
                    exportsByAssignment[assignmentID, default: []].append(export)
                } else {
                    backupLevelExports.append(export)
                }
            }

            var outcome = RestoreOutcome()
            for setup in snapshot.assignments {
                var tree = RestoreTree(
                    setup: setup,
                    graphs: graphsByAssignment[setup.id] ?? [],
                    audit: auditByAssignment[setup.id] ?? [],
                    exports: exportsByAssignment[setup.id] ?? []
                )
                let originalPaths = tree.sourcePaths
                let resolution: RestoreResolution? = conflicts.contains(setup.id) ? resolutions[setup.id] : nil
                switch resolution {
                case .none:
                    outcome.addedAssignmentIDs.append(setup.id)
                case .some(.keepLocal):
                    outcome.keptLocalAssignmentIDs.append(setup.id)
                    continue
                case .some(.replaceLocal):
                    let localPaths = try String.fetchAll(
                        db,
                        sql: """
                        SELECT sourceInput.localRelativePath FROM sourceInput
                        JOIN submission ON submission.id = sourceInput.submissionID
                        WHERE submission.assignmentID = ? AND sourceInput.localRelativePath IS NOT NULL
                        """,
                        arguments: [setup.id]
                    )
                    try Assignment.deleteOne(db, id: setup.id)
                    let restoredPaths = Set(originalPaths)
                    outcome.obsoleteLocalFilePaths += localPaths.filter { !restoredPaths.contains($0) }
                    outcome.replacedAssignmentIDs.append(setup.id)
                case .some(.restoreAsCopy):
                    tree = tree.copyWithNewIDs()
                    outcome.copiedAssignmentIDs[setup.id] = tree.setup.id
                }
                try Self.insert(tree, db)
                for (original, restored) in zip(originalPaths, tree.sourcePaths) {
                    outcome.sourceFileMoves.append(SourceFileMove(stagedRelativePath: original, destinationRelativePath: restored))
                }
            }

            let localExportIDs = Set(try UUID.fetchAll(db, sql: "SELECT id FROM exportRecord"))
            for export in backupLevelExports where !localExportIDs.contains(export.id) {
                try export.insert(db)
            }

            if failBeforeCommit { throw InjectedRestoreFailure() }
            return outcome
        }
    }
}

// MARK: - Transactions

extension AppDatabase {
    private func read<T: Sendable>(_ value: @escaping @Sendable (Database) throws -> T) async throws -> T {
        try await writer.read(value)
    }

    private func write<T: Sendable>(_ updates: @escaping @Sendable (Database) throws -> T) async throws -> T {
        do {
            return try await writer.write(updates)
        } catch let error as AppDatabaseError {
            throw error
        } catch {
            throw AppDatabaseError.writeFailed(underlying: error)
        }
    }

    /// Confirms the submission still exists (else `notFound`) and records the change time.
    private static func touchSubmission(_ db: Database, id: UUID) throws {
        try db.execute(sql: "UPDATE submission SET updatedAt = ? WHERE id = ?", arguments: [Date(), id])
        guard db.changesCount > 0 else { throw AppDatabaseError.notFound(id) }
    }

    /// Source paths of the submissions matching a condition on the `submission` table.
    private static func sourcePaths(_ db: Database, whereSubmission condition: String, arguments: StatementArguments) throws -> [String] {
        try String.fetchAll(
            db,
            sql: """
            SELECT sourceInput.localRelativePath FROM sourceInput
            JOIN submission ON submission.id = sourceInput.submissionID
            WHERE \(condition) AND sourceInput.localRelativePath IS NOT NULL
            """,
            arguments: arguments
        )
    }

    private static func nextSortOrder(_ db: Database, classGroupID: UUID) throws -> Int {
        (try Int.fetchOne(db, sql: "SELECT MAX(sortOrder) FROM enrollment WHERE classGroupID = ?", arguments: [classGroupID]) ?? -1) + 1
    }

    /// One submission for every (assignment, enrolled student) pair in the class that has none yet.
    private static func createMissingSubmissions(_ db: Database, classGroupID: UUID) throws {
        let assignmentIDs = try UUID.fetchAll(db, sql: "SELECT id FROM assignment WHERE classGroupID = ?", arguments: [classGroupID])
        let studentIDs = try UUID.fetchAll(
            db, sql: "SELECT studentID FROM enrollment WHERE classGroupID = ? ORDER BY sortOrder", arguments: [classGroupID]
        )
        let existing = Set(
            try fetch(
                SubmissionKeyRow.self, db, table: Submission.databaseTableName,
                sql: """
                SELECT submission.assignmentID AS assignmentID, submission.studentID AS studentID FROM submission
                JOIN assignment ON assignment.id = submission.assignmentID
                WHERE assignment.classGroupID = ?
                """,
                arguments: [classGroupID]
            ).map { "\($0.assignmentID.uuidString)/\($0.studentID.uuidString)" }
        )
        let now = Date()
        for assignmentID in assignmentIDs {
            for studentID in studentIDs where !existing.contains("\(assignmentID.uuidString)/\(studentID.uuidString)") {
                try Submission(assignmentID: assignmentID, studentID: studentID, createdAt: now, updatedAt: now).insert(db)
            }
        }
    }
}

/// A submission's assignment title, with the names Shortcuts must keep out of the title.
struct SubmissionTitle: Sendable {
    let id: UUID
    let assignmentTitle: String
    let assignmentID: UUID
    let studentName: String
    let className: String
}

/// One row of the Exports tab's recent exports.
struct ExportRecordSummary: Identifiable, Equatable, Sendable, Decodable, FetchableRecord {
    var id: UUID
    var kind: ExportKind
    var createdAt: Date
    var assignmentTitle: String?
    var studentName: String?
}

private struct SubmissionCountRow: Decodable, FetchableRecord {
    var assignmentID: UUID
    var submissionCount: Int
}

private struct SubmissionKeyRow: Decodable, FetchableRecord {
    var assignmentID: UUID
    var studentID: UUID
}
