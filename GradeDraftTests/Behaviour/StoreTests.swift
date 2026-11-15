import Foundation
import GRDB
import Testing
@testable import GradeDraft

struct StoreTests {
    // T6
    @Test func replaceLocalRestoreFailureLeavesFilesAndDataUnchanged() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoreTests-\(UUID().uuidString)", isDirectory: true)
        let storageRoot = root.appendingPathComponent("GradeDraft", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)

        let database = try AppDatabase.inMemory()
        let (assignmentID, submissionID) = try await Fixture.oneSubmission(in: database)

        // The submission has a scanned page on disk.
        let relativePath = "Sources/\(submissionID.uuidString)/page-1.heic"
        let fileURL = storageRoot.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("page as backed up".utf8).write(to: fileURL)
        let source = SourceInputRef(
            submissionID: submissionID,
            sourceType: .scan,
            pageIndex: 0,
            localRelativePath: relativePath,
            fileName: "page-1.heic",
            mimeType: "image/heic",
            sha256: try ContentDigest.sha256Hex(fileAt: fileURL)
        )
        let ocr = OCRDocument(pages: [
            OCRPage(sourceInputID: source.id, pageIndex: 0, lines: [
                OCRLine(text: "Fractions are parts of a whole.", confidence: 0.95, boundingBox: .zero, origin: .visionOCR)
            ])
        ])
        _ = try await database.replaceInput(submissionID: submissionID, kind: .scanned, pastedText: nil, sources: [source], ocr: ocr)

        let backupURL = root.appendingPathComponent("backup.\(BackupArchiveService.backupFileExtension)")
        _ = try BackupArchiveService.writeFullBackup(
            snapshot: try await database.backupSnapshot(),
            storageRoot: storageRoot,
            password: "correct horse battery staple",
            appVersion: "test",
            to: backupURL
        )

        // After the backup the teacher keeps working: the file and the records change.
        let localBytes = Data("page edited after the backup".utf8)
        try localBytes.write(to: fileURL)
        var localSource = source
        localSource.sha256 = ContentDigest.sha256Hex(localBytes)
        _ = try await database.replaceInput(
            submissionID: submissionID, kind: .pasted, pastedText: "Typed after the backup.", sources: [localSource], ocr: nil
        )
        let rowsBefore = try await database.backupSnapshot()

        let preview = try await BackupArchiveService.prepareRestore(
            from: backupURL,
            password: "correct horse battery staple",
            storageRoot: storageRoot,
            database: database
        )
        #expect(preview.conflictingAssignmentIDs == [assignmentID])

        let error = await #expect(throws: BackupArchiveError.self) {
            try await BackupArchiveService.commitRestore(
                preview,
                resolutions: [assignmentID: .replaceLocal],
                database: database,
                storageRoot: storageRoot,
                failBeforeCommit: true
            )
        }
        #expect(error?.localizedDescription == "Restore failed. Your existing data and files are unchanged.")
        #expect(try Data(contentsOf: fileURL) == localBytes)
        #expect(try await database.backupSnapshot() == rowsBefore)
        #expect(!FileManager.default.fileExists(atPath: preview.stagingDirectory.path))
    }

    // T14
    @Test func unreadableStoredValueThrowsDataCorrupted() async throws {
        let database = try AppDatabase.inMemory()
        let (_, submissionID) = try await Fixture.oneSubmission(in: database)
        try await database.writer.write { db in
            try db.execute(
                sql: """
                INSERT INTO ocrDocument (id, submissionID, engine, engineVersion, reviewStatus, createdAt)
                VALUES (?, ?, 'Apple Vision', 'system', 'notARealStatus', ?)
                """,
                arguments: [UUID(), submissionID, Date()]
            )
        }

        let error = await #expect(throws: AppDatabaseError.self) {
            try await database.submission(id: submissionID)
        }
        guard case .dataCorrupted(let table, _, _)? = error else {
            Issue.record("Expected dataCorrupted, got \(String(describing: error))")
            return
        }
        #expect(table == "ocrDocument")
    }
}

private enum Fixture {
    /// A class with one enrolled student and one assignment, which creates that student's submission.
    static func oneSubmission(in database: AppDatabase) async throws -> (assignmentID: UUID, submissionID: UUID) {
        let classGroup = ClassGroup(name: "7B")
        try await database.save(classGroup)
        try await database.save(Student(displayName: "Ada Lovelace", localIdentifier: "A1"), enrolledIn: classGroup.id)
        let assignment = Assignment(classGroupID: classGroup.id, title: "Fraction essay", rubricText: "Ideas: 10 points")
        try await database.createAssignment(assignment)
        let submission = try #require(try await database.submissionSummaries(assignmentID: assignment.id).first)
        return (assignment.id, submission.id)
    }
}
