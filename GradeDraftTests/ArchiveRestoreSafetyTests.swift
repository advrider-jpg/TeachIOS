import XCTest
import ZIPFoundation
@testable import GradeDraft

final class ArchiveInventoryHardeningTests: XCTestCase {
    func testTeacherAuditArchiveContainsInventoryJSON() throws {
        let archive = try teacherArchive()
        XCTAssertNotNil(archive["archive_inventory.json"])
    }

    func testGradebookArchiveContainsInventoryJSON() throws {
        let assignment = ExportFixtureFactory.sensitiveApprovedAssignment()
        let destination = ExportFixtureFactory.temporaryDirectory("GradebookArchive").appendingPathComponent("gradebook.zip")
        let written = try BundleExportService.writeAssignmentArchive(assignments: [assignment], sourceFiles: [], to: destination)
        XCTAssertNotNil(try openArchive(written)["archive_inventory.json"])
    }

    func testFullBackupArchiveContainsInventoryJSON() throws {
        let assignment = ExportFixtureFactory.sensitiveApprovedAssignment()
        let destination = ExportFixtureFactory.temporaryDirectory("FullBackupArchive").appendingPathComponent("backup.zip")
        let written = try BundleExportService.writeFullBackup(assignments: [assignment], sourceFiles: [], to: destination)
        XCTAssertNotNil(try openArchive(written)["archive_inventory.json"])
    }

    func testArchiveInventoryContainsOnlyEntriesActuallyPresent() throws {
        let archive = try teacherArchive()
        let paths = Set(archive.map(\.path))
        for item in try inventory(in: archive) {
            XCTAssertTrue(paths.contains(item.path), "Missing archived entry listed in inventory: \(item.path)")
        }
    }

    func testTeacherArchiveInventoryMarksTeacherAuditAsPrivateNotesIncluded() throws {
        let archive = try teacherArchive()
        let item = try XCTUnwrap(inventory(in: archive).first { $0.path == "teacher_audit_report.md" })
        XCTAssertTrue(item.includesPrivateTeacherNotes)
        XCTAssertTrue(item.includesInternalMetadata)
    }

    func testTeacherArchiveInventoryMarksStudentReportAsNoPrivateNotes() throws {
        let archive = try teacherArchive()
        let item = try XCTUnwrap(inventory(in: archive).first { $0.path == "student_report.md" })
        XCTAssertFalse(item.includesPrivateTeacherNotes)
        XCTAssertFalse(item.includesOriginalSources)
    }

    func testFullBackupInventoryMarksDatabaseExportAsInternalMetadata() throws {
        let assignment = ExportFixtureFactory.sensitiveApprovedAssignment()
        let destination = ExportFixtureFactory.temporaryDirectory("FullBackupInventory").appendingPathComponent("backup.zip")
        let written = try BundleExportService.writeFullBackup(assignments: [assignment], sourceFiles: [], to: destination)
        let archive = try openArchive(written)
        let item = try XCTUnwrap(inventory(in: archive).first { $0.path == "database_export.json" })
        XCTAssertTrue(item.includesPrivateTeacherNotes)
        XCTAssertTrue(item.includesInternalMetadata)
    }

    func testSourceFilesWithSameLastPathDoNotCollideInArchive() throws {
        let root = ExportFixtureFactory.temporaryDirectory("SourceCollision")
        let first = try writeFile(root.appendingPathComponent("a/page.png"), contents: "first")
        let second = try writeFile(root.appendingPathComponent("b/page.png"), contents: "second")
        let destination = root.appendingPathComponent("archive.zip")
        let written = try BundleExportService.writeTeacherAuditArchive(
            assignment: ExportFixtureFactory.sensitiveApprovedAssignment(),
            sourceFiles: [first, second],
            to: destination
        )
        let paths = try inventory(in: openArchive(written)).filter { $0.category == "sourceFile" }.map(\.path)
        XCTAssertEqual(paths.count, 2)
        XCTAssertEqual(Set(paths).count, 2)
    }

    func testSourceFileArchivePathsDoNotContainDotDot() throws {
        let root = ExportFixtureFactory.temporaryDirectory("SourcePathDotDot")
        let source = try writeFile(root.appendingPathComponent("..unsafe.png"), contents: "source")
        let written = try BundleExportService.writeTeacherAuditArchive(
            assignment: ExportFixtureFactory.sensitiveApprovedAssignment(),
            sourceFiles: [source],
            to: root.appendingPathComponent("archive.zip")
        )
        let paths = try inventory(in: openArchive(written)).filter { $0.category == "sourceFile" }.map(\.path)
        XCTAssertFalse(paths.contains { $0.contains("..") })
    }

    func testSourceFileArchivePathsDoNotContainBackslash() throws {
        let root = ExportFixtureFactory.temporaryDirectory("SourcePathBackslash")
        let source = try writeFile(root.appendingPathComponent("folder\\name.png"), contents: "source")
        let written = try BundleExportService.writeTeacherAuditArchive(
            assignment: ExportFixtureFactory.sensitiveApprovedAssignment(),
            sourceFiles: [source],
            to: root.appendingPathComponent("archive.zip")
        )
        let paths = try inventory(in: openArchive(written)).filter { $0.category == "sourceFile" }.map(\.path)
        XCTAssertFalse(paths.contains { $0.contains("\\") })
    }

    func testArchiveManifestSourceFileCountMatchesInventorySourceFiles() throws {
        let root = ExportFixtureFactory.temporaryDirectory("ManifestSourceCount")
        let source = try writeFile(root.appendingPathComponent("source.txt"), contents: "source")
        let written = try BundleExportService.writeTeacherAuditArchive(
            assignment: ExportFixtureFactory.sensitiveApprovedAssignment(),
            sourceFiles: [source],
            to: root.appendingPathComponent("archive.zip")
        )
        let archive = try openArchive(written)
        let manifest = try decode(BackupArchiveManifest.self, path: "manifest.json", in: archive)
        let sourceInventoryCount = try inventory(in: archive).filter { $0.category == "sourceFile" }.count
        XCTAssertEqual(manifest.sourceFileCount, sourceInventoryCount)
    }

    func testArchiveContentHashesIncludeSourceFilesWhenPresent() throws {
        let root = ExportFixtureFactory.temporaryDirectory("ManifestSourceHash")
        let source = try writeFile(root.appendingPathComponent("source.txt"), contents: "source")
        let written = try BundleExportService.writeFullBackup(
            assignments: [ExportFixtureFactory.sensitiveApprovedAssignment()],
            sourceFiles: [source],
            to: root.appendingPathComponent("backup.zip")
        )
        let manifest = try decode(BackupArchiveManifest.self, path: "manifest.json", in: openArchive(written))
        XCTAssertTrue(manifest.contentHashes.keys.contains { $0.hasPrefix("source:") })
    }

    private func teacherArchive() throws -> Archive {
        let assignment = ExportFixtureFactory.sensitiveApprovedAssignment()
        let destination = ExportFixtureFactory.temporaryDirectory("TeacherArchive").appendingPathComponent("archive.zip")
        return try openArchive(BundleExportService.writeTeacherAuditArchive(assignment: assignment, sourceFiles: [], to: destination))
    }
}

final class RestorePathSafetyTests: XCTestCase {
    func testSafeRestoreDestinationIgnoresNonSourceEntry() throws {
        let root = ExportFixtureFactory.temporaryDirectory("RestoreIgnore")
        XCTAssertNil(try BundleExportService.safeRestoreDestination(for: "manifest.json", applicationSupportDirectory: root))
    }

    func testRestoreRejectsDotDotSourceEntry() {
        XCTAssertThrowsError(try BundleExportService.safeRestoreDestination(for: "sources/Sources/../evil.txt", applicationSupportDirectory: ExportFixtureFactory.temporaryDirectory("RestoreDotDot")))
    }

    func testRestoreRejectsAbsoluteSourceEntry() {
        XCTAssertThrowsError(try BundleExportService.safeRestoreDestination(for: "sources//tmp/evil.txt", applicationSupportDirectory: ExportFixtureFactory.temporaryDirectory("RestoreAbsolute")))
    }

    func testRestoreRejectsBackslashSourceEntry() {
        XCTAssertThrowsError(try BundleExportService.safeRestoreDestination(for: "sources/Sources\\evil.txt", applicationSupportDirectory: ExportFixtureFactory.temporaryDirectory("RestoreBackslash")))
    }

    func testRestoreRejectsDotComponent() {
        XCTAssertThrowsError(try BundleExportService.safeRestoreDestination(for: "sources/Sources/./file.txt", applicationSupportDirectory: ExportFixtureFactory.temporaryDirectory("RestoreDot")))
    }

    func testRestoreRejectsEmptySourcePath() {
        XCTAssertThrowsError(try BundleExportService.safeRestoreDestination(for: "sources/", applicationSupportDirectory: ExportFixtureFactory.temporaryDirectory("RestoreEmpty")))
    }

    func testRestoreDoesNotWriteOutsideApplicationSupport() {
        let root = ExportFixtureFactory.temporaryDirectory("RestoreContainment")
        XCTAssertThrowsError(try BundleExportService.safeRestoreDestination(for: "sources/Sources/../../outside.txt", applicationSupportDirectory: root))
    }

    func testRestoreAsCopyStillRemapsSafeSourcePaths() throws {
        let fixture = try backupWithAppManagedSource()
        let restored = try BundleExportService.restoreBackupArchive(
            from: fixture.archiveURL,
            existingAssignments: [fixture.assignment],
            applicationSupportDirectory: fixture.restoreRoot,
            conflictResolution: .restoreAsCopy
        )
        let copied = try XCTUnwrap(restored.first)
        XCTAssertNotEqual(copied.id, fixture.assignment.id)
        let expected = fixture.restoreRoot.appendingPathComponent("Sources/\(copied.id.uuidString)/page-1.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expected.path))
    }

    func testRestoreKeepLocalSkipsConflictingSourcePaths() throws {
        let fixture = try backupWithAppManagedSource()
        let local = fixture.restoreRoot.appendingPathComponent("Sources/\(fixture.assignment.id.uuidString)/page-1.txt")
        try writeFile(local, contents: "local")
        _ = try BundleExportService.restoreBackupArchive(
            from: fixture.archiveURL,
            existingAssignments: [fixture.assignment],
            applicationSupportDirectory: fixture.restoreRoot,
            conflictResolution: .keepLocal
        )
        XCTAssertEqual(String(data: try Data(contentsOf: local), encoding: .utf8), "local")
    }

    func testRestoreReplaceLocalOverwritesOnlyInsideApplicationSupport() throws {
        let fixture = try backupWithAppManagedSource()
        let local = fixture.restoreRoot.appendingPathComponent("Sources/\(fixture.assignment.id.uuidString)/page-1.txt")
        try writeFile(local, contents: "local")
        _ = try BundleExportService.restoreBackupArchive(
            from: fixture.archiveURL,
            existingAssignments: [fixture.assignment],
            applicationSupportDirectory: fixture.restoreRoot,
            conflictResolution: .replaceLocal
        )
        XCTAssertEqual(String(data: try Data(contentsOf: local), encoding: .utf8), "source bytes")
    }

    private func backupWithAppManagedSource() throws -> (assignment: AssignmentRecord, archiveURL: URL, restoreRoot: URL) {
        let root = ExportFixtureFactory.temporaryDirectory("RestoreBackup")
        var assignment = ExportFixtureFactory.sensitiveApprovedAssignment()
        let relative = "Sources/\(assignment.id.uuidString)/page-1.txt"
        let source = try writeFile(root.appendingPathComponent(relative), contents: "source bytes")
        assignment.sourceInputs = [SourceInputRef(sourceType: .scan, localRelativePath: relative, fileName: "page-1.txt", teacherIncludedInExport: true)]
        let archive = root.appendingPathComponent("backup.zip")
        let written = try BundleExportService.writeFullBackup(assignments: [assignment], sourceFiles: [source], to: archive)
        let restoreRoot = ExportFixtureFactory.temporaryDirectory("RestoreDestination")
        return (assignment, written, restoreRoot)
    }
}

private func openArchive(_ url: URL) throws -> Archive {
    guard let archive = Archive(url: url, accessMode: .read) else {
        throw NSError(domain: "ArchiveRestoreSafetyTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not open archive: \(url.lastPathComponent)"])
    }
    return archive
}

private func archiveData(_ path: String, in archive: Archive) throws -> Data {
    guard let entry = archive[path] else {
        throw NSError(domain: "ArchiveRestoreSafetyTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing archive entry: \(path)"])
    }
    var data = Data()
    _ = try archive.extract(entry) { chunk in data.append(chunk) }
    return data
}

private func decode<T: Decodable>(_ type: T.Type, path: String, in archive: Archive) throws -> T {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(type, from: archiveData(path, in: archive))
}

private func inventory(in archive: Archive) throws -> [ExportArchiveInventoryItem] {
    try decode([ExportArchiveInventoryItem].self, path: "archive_inventory.json", in: archive)
}

@discardableResult
private func writeFile(_ url: URL, contents: String) throws -> URL {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(contents.utf8).write(to: url)
    return url
}
