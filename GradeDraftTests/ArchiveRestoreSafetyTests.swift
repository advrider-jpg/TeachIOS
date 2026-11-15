import XCTest
import ZIPFoundation
@testable import GradeDraft

/// The Teacher Record ZIP: one snapshot, the rendered reports and the original files.
final class TeacherRecordArchiveSafetyTests: XCTestCase {
    func testSourceFilesWithSameLastPathDoNotCollideInArchive() throws {
        let root = ExportFixtureFactory.temporaryDirectory("SourceCollision")
        let first = try writeFile(root.appendingPathComponent("a/page.png"), contents: "first")
        let second = try writeFile(root.appendingPathComponent("b/page.png"), contents: "second")
        let paths = try sourceEntryPaths(sourceFiles: [first, second], root: root)
        XCTAssertEqual(paths.count, 2)
        XCTAssertEqual(Set(paths).count, 2)
    }

    func testSourceFileArchivePathsDoNotContainDotDot() throws {
        let root = ExportFixtureFactory.temporaryDirectory("SourcePathDotDot")
        let source = try writeFile(root.appendingPathComponent("..unsafe.png"), contents: "source")
        let paths = try sourceEntryPaths(sourceFiles: [source], root: root)
        XCTAssertEqual(paths.count, 1)
        XCTAssertFalse(paths.contains { $0.contains("..") })
    }

    func testSourceFileArchivePathsDoNotContainBackslash() throws {
        let root = ExportFixtureFactory.temporaryDirectory("SourcePathBackslash")
        let source = try writeFile(root.appendingPathComponent("folder\\name.png"), contents: "source")
        let paths = try sourceEntryPaths(sourceFiles: [source], root: root)
        XCTAssertEqual(paths.count, 1)
        XCTAssertFalse(paths.contains { $0.contains("\\") })
    }

    func testArchiveRejectsSymlinkSourceFile() throws {
        let root = ExportFixtureFactory.temporaryDirectory("ArchiveSymlinkReject")
        let target = try writeFile(root.appendingPathComponent("target.txt"), contents: "target")
        let link = root.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        XCTAssertThrowsError(try writeTeacherRecordArchive(sourceFiles: [link], root: root))
    }

    func testTeacherArchiveFailsWhenRequestedSourceFileIsMissing() throws {
        let root = ExportFixtureFactory.temporaryDirectory("ArchiveMissingSource")
        let missingSource = root.appendingPathComponent("Sources/missing.png")

        XCTAssertThrowsError(try writeTeacherRecordArchive(sourceFiles: [missingSource], root: root)) { error in
            XCTAssertTrue(error.localizedDescription.contains("missing"))
        }
    }

    private func writeTeacherRecordArchive(sourceFiles: [URL], root: URL) throws -> URL {
        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment()
        let report = ReportBuilder.teacherRecord(setup: fixture.setup, submission: fixture.submission, generatedAt: Date(timeIntervalSince1970: 0))
        return try BackupArchiveService.writeTeacherRecordArchive(
            snapshot: fixture.snapshot,
            reportFiles: [(name: "TeacherRecord.md", data: Data(MarkdownRenderer.render(report).utf8))],
            sourceFiles: sourceFiles,
            to: root.appendingPathComponent("archive.zip")
        )
    }

    private func sourceEntryPaths(sourceFiles: [URL], root: URL) throws -> [String] {
        let archive = try Archive(url: try writeTeacherRecordArchive(sourceFiles: sourceFiles, root: root), accessMode: .read)
        return archive.map(\.path).filter { $0.hasPrefix("sources/") }
    }
}

/// Source file paths from a backup are checked before anything is written.
final class SourcePathSafetyTests: XCTestCase {
    func testPathOutsideSourcesFolderIsNotASourcePath() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("manifest.json"))
    }

    func testRestoreRejectsDotDotSourceEntry() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("Sources/../evil.txt"))
    }

    func testRestoreRejectsAbsoluteSourceEntry() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("/tmp/evil.txt"))
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("Sources//tmp/evil.txt"))
    }

    func testRestoreRejectsBackslashSourceEntry() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("Sources\\evil.txt"))
    }

    func testRestoreRejectsDotComponent() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("Sources/./file.txt"))
    }

    func testRestoreRejectsEmptySourcePath() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("Sources/"))
    }

    func testRestoreDoesNotWriteOutsideApplicationSupport() {
        let root = ExportFixtureFactory.temporaryDirectory("RestoreContainment")
        XCTAssertNil(SourcePathSafety.resolvedLocalSourceURL("Sources/../../outside.txt", applicationSupportDirectory: root))
    }

    func testSourcePathResolutionRejectsSymlinkEscape() throws {
        let root = ExportFixtureFactory.temporaryDirectory("SourceSymlinkEscape")
        let outside = ExportFixtureFactory.temporaryDirectory("SourceSymlinkOutside")
        let target = try writeFile(outside.appendingPathComponent("outside.txt"), contents: "outside")
        let sources = root.appendingPathComponent("Sources")
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        let link = sources.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        XCTAssertNil(SourcePathSafety.resolvedLocalSourceURL("Sources/link.txt", applicationSupportDirectory: root))
    }
}

/// A full backup of one assignment with one original file, restored over the store that made it.
final class BackupRestoreFilesTests: XCTestCase {
    private let password = "test-password"

    func testRestoreAsCopyStillRemapsSafeSourcePaths() async throws {
        let world = try await RestoreWorld.make()
        let preview = try await world.prepare()
        XCTAssertEqual(preview.conflictingAssignmentIDs, [world.assignmentID])

        let outcome = try await world.commit(preview, resolution: .restoreAsCopy)

        let copiedID = try XCTUnwrap(outcome.copiedAssignmentIDs[world.assignmentID])
        XCTAssertNotEqual(copiedID, world.assignmentID)
        let snapshot = try await world.database.backupSnapshot()
        let copiedSubmission = try XCTUnwrap(snapshot.submissions.first { $0.submission.assignmentID == copiedID })
        let copiedPath = try XCTUnwrap(copiedSubmission.sources.first?.localRelativePath)
        XCTAssertNotEqual(copiedPath, world.sourceRelativePath)
        XCTAssertEqual(try String(contentsOf: world.storageRoot.appendingPathComponent(copiedPath), encoding: .utf8), "source bytes")
        XCTAssertEqual(try String(contentsOf: world.localSourceURL, encoding: .utf8), "source bytes")
    }

    func testRestoreKeepLocalSkipsConflictingSourcePaths() async throws {
        let world = try await RestoreWorld.make()
        try writeFile(world.localSourceURL, contents: "local")
        let preview = try await world.prepare()

        _ = try await world.commit(preview, resolution: .keepLocal)

        XCTAssertEqual(try String(contentsOf: world.localSourceURL, encoding: .utf8), "local")
    }

    func testRestoreReplaceLocalOverwritesOnlyInsideApplicationSupport() async throws {
        let world = try await RestoreWorld.make()
        try writeFile(world.localSourceURL, contents: "local")
        let preview = try await world.prepare()

        _ = try await world.commit(preview, resolution: .replaceLocal)

        XCTAssertEqual(try String(contentsOf: world.localSourceURL, encoding: .utf8), "source bytes")
    }

    func testRestoreAsCopyAddsASecondAssignmentWithASubmissionForTheSameStudent() async throws {
        let world = try await RestoreWorld.make()
        let preview = try await world.prepare()

        let outcome = try await world.commit(preview, resolution: .restoreAsCopy)

        let copiedID = try XCTUnwrap(outcome.copiedAssignmentIDs[world.assignmentID])
        let assignments = try await world.database.assignmentSummaries(inClass: nil)
        XCTAssertEqual(assignments.count, 2)
        // The local submission stays with the original assignment; the copy has its own for the same student.
        let original = try await world.database.submissionSummaries(assignmentID: world.assignmentID)
        let copied = try await world.database.submissionSummaries(assignmentID: copiedID)
        XCTAssertEqual(original.map(\.studentID), [world.studentID])
        XCTAssertEqual(copied.map(\.studentID), [world.studentID])
    }

    func testRestoreKeepLocalDoesNotImportConflictingSubmissions() async throws {
        let world = try await RestoreWorld.make()
        let preview = try await world.prepare()

        _ = try await world.commit(preview, resolution: .keepLocal)

        let assignments = try await world.database.assignmentSummaries(inClass: nil)
        XCTAssertEqual(assignments.count, 1)
        let submissions = try await world.database.submissionSummaries(assignmentID: world.assignmentID)
        XCTAssertEqual(submissions.count, 1, "Keep-local must not import duplicate submissions for conflicting assignments")
    }

    func testBackupManifestListsEveryOriginalFileWithItsDigest() async throws {
        let world = try await RestoreWorld.make()
        let emptyStore = try AppDatabase.inMemory()
        let preview = try await BackupArchiveService.prepareRestore(
            from: world.archiveURL, password: password, storageRoot: world.storageRoot, database: emptyStore
        )
        defer { BackupArchiveService.discard(preview) }

        let archivePath = "sources/" + world.sourceRelativePath.dropFirst("Sources/".count)
        XCTAssertEqual(preview.manifest.sourceSHA256[archivePath], ContentDigest.sha256Hex(Data("source bytes".utf8)))
        XCTAssertEqual(preview.sourceFileCount, 1)
        XCTAssertTrue(preview.conflictingAssignmentIDs.isEmpty)
    }

    func testBackupRestoreSelectionCreatesPreviewBeforeMutation() async throws {
        let world = try await RestoreWorld.make()
        let otherStore = try AppDatabase.inMemory()
        try await otherStore.save(ClassGroup(name: "Local class"))

        let preview = try await BackupArchiveService.prepareRestore(
            from: world.archiveURL, password: password, storageRoot: world.storageRoot, database: otherStore
        )
        defer { BackupArchiveService.discard(preview) }

        XCTAssertEqual(preview.snapshot.assignments.map(\.id), [world.assignmentID])
        let localAssignments = try await otherStore.assignmentSummaries(inClass: nil)
        XCTAssertTrue(localAssignments.isEmpty, "Choosing a backup must not change local records")
        let localClasses = try await otherStore.classGroups()
        XCTAssertEqual(localClasses.map(\.name), ["Local class"])
    }

    /// A store holding one fixture assignment with its original file, and a full backup of it.
    private struct RestoreWorld {
        let storageRoot: URL
        let database: AppDatabase
        let archiveURL: URL
        let assignmentID: UUID
        let studentID: UUID
        let sourceRelativePath: String
        private let password = "test-password"

        var localSourceURL: URL { storageRoot.appendingPathComponent(sourceRelativePath) }

        static func make() async throws -> RestoreWorld {
            let base = ExportFixtureFactory.temporaryDirectory("RestoreWorld")
            let storageRoot = base.appendingPathComponent("GradeDraft", isDirectory: true)
            let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment()
            let relative = try XCTUnwrap(fixture.sourceRelativePath)
            try writeFile(storageRoot.appendingPathComponent(relative), contents: "source bytes")

            let database = try AppDatabase.inMemory()
            _ = try await database.restore(fixture.snapshot, resolutions: [:])
            let archiveURL = try BackupArchiveService.writeFullBackup(
                snapshot: try await database.backupSnapshot(),
                storageRoot: storageRoot,
                password: "test-password",
                appVersion: "test",
                to: base.appendingPathComponent("backup.markformebackup")
            )
            return RestoreWorld(
                storageRoot: storageRoot,
                database: database,
                archiveURL: archiveURL,
                assignmentID: fixture.setup.id,
                studentID: fixture.submission.student.id,
                sourceRelativePath: relative
            )
        }

        func prepare() async throws -> RestorePreview {
            try await BackupArchiveService.prepareRestore(
                from: archiveURL, password: password, storageRoot: storageRoot, database: database
            )
        }

        func commit(_ preview: RestorePreview, resolution: RestoreResolution) async throws -> RestoreOutcome {
            try await BackupArchiveService.commitRestore(
                preview,
                resolutions: [assignmentID: resolution],
                database: database,
                storageRoot: storageRoot
            )
        }
    }
}

@discardableResult
private func writeFile(_ url: URL, contents: String) throws -> URL {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(contents.utf8).write(to: url)
    return url
}
