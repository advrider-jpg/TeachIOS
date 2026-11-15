import XCTest
import ZIPFoundation
@testable import GradeDraft

// MARK: - Backup and Teacher Record archive hardening

final class BundleExportHardeningTests: XCTestCase {
    func testTeacherRecordArchiveContainsAllExpectedFiles() throws {
        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment(title: "Full archive test")
        let report = ReportBuilder.teacherRecord(setup: fixture.setup, submission: fixture.submission, generatedAt: Date(timeIntervalSince1970: 0))
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("archive-hardening-\(UUID()).zip")
        defer { try? FileManager.default.removeItem(at: destination) }

        let written = try BackupArchiveService.writeTeacherRecordArchive(
            snapshot: fixture.snapshot,
            reportFiles: [
                (name: "TeacherRecord.md", data: Data(MarkdownRenderer.render(report).utf8)),
                (name: "TeacherRecord.pdf", data: try PDFRenderer.render(report))
            ],
            sourceFiles: [],
            to: destination
        )

        let archive = try Archive(url: written, accessMode: .read)
        XCTAssertNotNil(archive["snapshot.json"])
        XCTAssertNotNil(archive["TeacherRecord.md"])
        XCTAssertNotNil(archive["TeacherRecord.pdf"])
    }

    func testFullBackupContainsManifestAndData() async throws {
        let first = try ExportFixtureFactory.baseAssignment(title: "A", student: "Student A")
        let second = try ExportFixtureFactory.baseAssignment(title: "B", student: "Student B")
        let source = try AppDatabase.inMemory()
        _ = try await source.restore(first.snapshot, resolutions: [:])
        _ = try await source.restore(second.snapshot, resolutions: [:])

        let base = ExportFixtureFactory.temporaryDirectory("FullBackupHardening")
        let storageRoot = base.appendingPathComponent("GradeDraft", isDirectory: true)
        let written = try BackupArchiveService.writeFullBackup(
            snapshot: try await source.backupSnapshot(),
            storageRoot: storageRoot,
            password: "test-password",
            appVersion: "test",
            to: base.appendingPathComponent("backup.markformebackup")
        )

        let preview = try await BackupArchiveService.prepareRestore(
            from: written, password: "test-password", storageRoot: storageRoot, database: try AppDatabase.inMemory()
        )
        defer { BackupArchiveService.discard(preview) }

        XCTAssertEqual(preview.manifest.formatVersion, BackupManifest.currentFormatVersion)
        XCTAssertEqual(preview.assignmentCount, 2)
        XCTAssertEqual(Set(preview.snapshot.assignments.map(\.assignment.title)), ["A", "B"])
    }
}
