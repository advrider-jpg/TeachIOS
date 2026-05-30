import XCTest
import ZIPFoundation
@testable import GradeDraft

private final class ArchiveTestAssignmentStore: AssignmentStoring {
    private(set) var assignments: [AssignmentRecord]
    private(set) var rosterEntries: [AssignmentRosterEntry] = []
    private let root: URL

    init(assignments: [AssignmentRecord] = [], root: URL) {
        self.assignments = assignments
        self.root = root
    }

    func loadAssignments() throws -> [AssignmentRecord] { assignments }
    func saveAssignments(_ assignments: [AssignmentRecord]) throws { self.assignments = assignments }
    func deleteAssignment(id: UUID) throws { assignments.removeAll { $0.id == id } }
    func applicationSupportDirectory() throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    func loadClassGroups() throws -> [ClassGroupRecord] { [] }
    func saveClassGroup(_ classGroup: ClassGroupRecord) throws {}
    func deleteClassGroup(id: UUID) throws {}
    func loadStudents() throws -> [StudentRecord] { [] }
    func saveStudent(_ student: StudentRecord) throws {}
    func deleteStudent(id: UUID) throws {}
    func loadAssignmentRoster(assignmentID: UUID) throws -> [AssignmentRosterEntry] { rosterEntries.filter { $0.assignmentID == assignmentID } }
    func saveAssignmentRoster(_ entries: [AssignmentRosterEntry]) throws { self.rosterEntries = entries }
    func saveSourceInputs(_ sourceInputs: [SourceInputRef], assignmentID: UUID) throws {}
    func saveOCRDocument(_ document: OCRDocument, assignmentID: UUID) throws {}
    func saveFinalReview(_ review: FinalGradeReview, assignmentID: UUID) throws {}
    func saveEvidenceReferences(_ references: [EvidenceReference], assignmentID: UUID) throws {}
    func loadFullAssignmentGraph(id: UUID) throws -> AssignmentRecord? { assignments.first { $0.id == id } }
}

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

    // MARK: - Change 4: Roster entry remap tests

    @MainActor
    func testRestoreAsCopyRemapsRosterEntryToNewAssignmentID() throws {
        let localAssignment = ExportFixtureFactory.sensitiveApprovedAssignment()
        let localRosterEntry = AssignmentRosterEntry(assignmentID: localAssignment.id, studentID: UUID(), studentDisplayName: "Alice")

        // Build a full backup that has the same assignment ID
        let backupRoot = ExportFixtureFactory.temporaryDirectory("RosterRemapBackup")
        let archive = backupRoot.appendingPathComponent("backup.zip")
        let written = try BundleExportService.writeFullBackup(
            assignments: [localAssignment],
            sourceFiles: [],
            to: archive,
            classGroups: [],
            students: [],
            rosterEntries: [localRosterEntry]
        )

        let root = ExportFixtureFactory.temporaryDirectory("RosterRemapRestore")
        let store = ArchiveTestAssignmentStore(assignments: [localAssignment], root: root)
        let vm = GradeDraftViewModel(assignments: [localAssignment], store: store)
        vm.assignmentRosterEntries = [localRosterEntry]
        vm.backupConflictResolution = .restoreAsCopy

        vm.previewBackupRestore(from: written)
        XCTAssertNotNil(vm.pendingRestorePreview, "Preview must be set before confirm")
        vm.confirmPendingRestore()

        // After restore there should be 2 assignments
        XCTAssertEqual(vm.assignments.count, 2, "Restore-as-copy must produce two assignments")
        let copiedAssignment = vm.assignments.first(where: { $0.id != localAssignment.id })
        XCTAssertNotNil(copiedAssignment, "A copied assignment with a new ID must exist")

        // The local roster entry must still reference the original
        XCTAssertTrue(vm.assignmentRosterEntries.contains { $0.assignmentID == localAssignment.id }, "Local roster entry must remain for original")

        // There must be a roster entry pointing to the copied assignment
        if let copiedID = copiedAssignment?.id {
            XCTAssertTrue(vm.assignmentRosterEntries.contains { $0.assignmentID == copiedID }, "A roster entry must reference the copied assignment ID")
        }
    }

    @MainActor
    func testRestoreKeepLocalDoesNotImportConflictingRosterEntries() throws {
        let localAssignment = ExportFixtureFactory.sensitiveApprovedAssignment()
        let localRosterEntry = AssignmentRosterEntry(assignmentID: localAssignment.id, studentID: UUID(), studentDisplayName: "Bob")

        let backupRoot = ExportFixtureFactory.temporaryDirectory("RosterKeepLocalBackup")
        let archive = backupRoot.appendingPathComponent("backup.zip")
        let written = try BundleExportService.writeFullBackup(
            assignments: [localAssignment],
            sourceFiles: [],
            to: archive,
            classGroups: [],
            students: [],
            rosterEntries: [localRosterEntry]
        )

        let root = ExportFixtureFactory.temporaryDirectory("RosterKeepLocalRestore")
        let store = ArchiveTestAssignmentStore(assignments: [localAssignment], root: root)
        let vm = GradeDraftViewModel(assignments: [localAssignment], store: store)
        vm.assignmentRosterEntries = [localRosterEntry]
        vm.backupConflictResolution = .keepLocal

        vm.previewBackupRestore(from: written)
        vm.confirmPendingRestore()

        let entries = vm.assignmentRosterEntries.filter { $0.assignmentID == localAssignment.id }
        XCTAssertEqual(entries.count, 1, "Keep-local must not import duplicate roster entries for conflicting assignments")
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
