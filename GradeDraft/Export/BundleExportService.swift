import Foundation
import ZIPFoundation

// swiftlint:disable type_body_length

enum BundleExportError: LocalizedError {
    case preflightFailed(String)
    case archiveFailed(String)
    case restoreFailed(String)

    var errorDescription: String? {
        switch self {
        case .preflightFailed(let detail): return "Bundle export preflight failed: \(detail)"
        case .archiveFailed(let detail): return "Bundle export failed: \(detail)"
        case .restoreFailed(let detail): return "Backup restore failed: \(detail)"
        }
    }
}

enum GradeDraftArchiveKind: String, Codable {
    case teacherAuditArchive
    case assignmentGradebookArchive
    case fullLocalBackup
}

struct BackupDatabaseExport: Codable {
    var assignments: [AssignmentRecord]
    var classGroups: [ClassGroupRecord]
    var students: [StudentRecord]
    var rosterEntries: [AssignmentRosterEntry]

    init(
        assignments: [AssignmentRecord],
        classGroups: [ClassGroupRecord] = [],
        students: [StudentRecord] = [],
        rosterEntries: [AssignmentRosterEntry] = []
    ) {
        self.assignments = assignments
        self.classGroups = classGroups
        self.students = students
        self.rosterEntries = rosterEntries
    }

    private enum CodingKeys: String, CodingKey { case assignments, classGroups, students, rosterEntries }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assignments = try container.decode([AssignmentRecord].self, forKey: .assignments)
        classGroups = (try? container.decode([ClassGroupRecord].self, forKey: .classGroups)) ?? []
        students = (try? container.decode([StudentRecord].self, forKey: .students)) ?? []
        rosterEntries = (try? container.decode([AssignmentRosterEntry].self, forKey: .rosterEntries)) ?? []
    }
}

/// Local ZIP/archive export. Archives are teacher-facing and may contain sensitive records.
struct BundleExportService {
    static func preflightDestination(for assignmentID: UUID) throws -> URL {
        let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let root = documents.appendingPathComponent("GradeDraftExports", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let filename = ExportFilenameBuilder.filename(kind: .zipArchive, assignmentID: assignmentID, extension: "zip")
        return root.appendingPathComponent(filename, isDirectory: false)
    }

    static func writeBundle(assignment: AssignmentRecord, sourceFiles: [URL], to destination: URL) throws -> URL {
        try writeTeacherAuditArchive(assignment: assignment, sourceFiles: sourceFiles, to: destination)
    }

    static func writeTeacherAuditArchive(assignment: AssignmentRecord, sourceFiles: [URL], to destination: URL) throws -> URL {
        try prepareDestination(destination)
        let existingSourceFiles = sourceFiles.filter { FileManager.default.fileExists(atPath: $0.path) }
        do {
            guard let archive = Archive(url: destination, accessMode: .create) else {
                throw BundleExportError.archiveFailed("Could not create ZIP archive at \(destination.lastPathComponent).")
            }
            var inventory: [ExportArchiveInventoryItem] = []
            let manifest = BackupArchiveManifest(
                archiveKind: GradeDraftArchiveKind.teacherAuditArchive.rawValue,
                includesPrivateTeacherNotes: true,
                includesOriginalSources: !existingSourceFiles.isEmpty,
                sourceFileCount: existingSourceFiles.count,
                recordCounts: recordCounts(for: [assignment], classGroups: [], students: []),
                contentHashes: contentHashes(for: [assignment], extraFiles: existingSourceFiles)
            )
            try addCodable(manifest, named: "manifest.json", category: "manifest", sensitivity: .internalMetadata, description: "Archive manifest and restore compatibility metadata.", inventory: &inventory, to: archive)
            try addData(MarkdownReportBuilder.studentMarkdown(for: assignment).data(using: .utf8) ?? Data(), named: "student_report.md", category: "studentReport", sensitivity: .studentReport, description: "Final-only student-facing report content.", inventory: &inventory, to: archive)
            try addData(MarkdownReportBuilder.teacherAuditMarkdown(for: assignment).data(using: .utf8) ?? Data(), named: "teacher_audit_report.md", category: "teacherAuditReport", sensitivity: .teacherAudit, description: "Teacher-only audit report with private notes and provenance.", inventory: &inventory, to: archive)
            let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftArchivePDFs", isDirectory: true)
            try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
            let studentPDF = try PDFExportService.studentReportPDF(for: assignment, destination: tempRoot.appendingPathComponent(ExportFilenameBuilder.filename(kind: .studentPDF, assignmentID: assignment.id, extension: "pdf")))
            let auditPDF = try PDFExportService.teacherAuditPDF(for: assignment, destination: tempRoot.appendingPathComponent(ExportFilenameBuilder.filename(kind: .teacherAuditPDF, assignmentID: assignment.id, extension: "pdf")))
            try addFile(studentPDF, named: "student_report.pdf", category: "studentReport", sensitivity: .studentReport, description: "PDF generated from final-only student-facing report content.", inventory: &inventory, to: archive)
            try addFile(auditPDF, named: "teacher_audit_report.pdf", category: "teacherAuditReport", sensitivity: .teacherAudit, description: "PDF generated from teacher-only audit report content.", inventory: &inventory, to: archive)
            try addData(CSVExportService.exportedCSV(from: [assignment]).data(using: .utf8) ?? Data(), named: "grade_summary.csv", category: "gradebook", sensitivity: .gradebook, description: "Quoted and formula-neutralized grade summary CSV.", inventory: &inventory, to: archive)
            try addCodable(assignment, named: "assignment.json", category: "assignmentRecord", sensitivity: .teacherAudit, description: "Complete assignment record.", inventory: &inventory, to: archive)
            try addCodable(assignment.parsedRubric.criteria, named: "rubric.json", category: "rubric", sensitivity: .studentDataInternal, description: "Parsed rubric criteria.", inventory: &inventory, to: archive)
            try addCodable(assignment.sourceInputs, named: "source_metadata.json", category: "sourceMetadata", sensitivity: .sourceMetadata, description: "Original source metadata and local source references.", inventory: &inventory, to: archive)
            try addCodable(assignment.ocrDocument, named: "ocr_document.json", category: "ocrDocument", sensitivity: .teacherAudit, description: "OCR document and review state.", inventory: &inventory, to: archive)
            try addCodable(assignment.evidenceReferences, named: "evidence_refs.json", category: "evidence", sensitivity: .teacherAudit, description: "Evidence references and bounding boxes.", inventory: &inventory, to: archive)
            try addCodable(assignment.latestDraft, named: "grade_proposal.json", category: "gradeProposal", sensitivity: .teacherAudit, description: "Draft grading proposal for teacher review.", inventory: &inventory, to: archive)
            try addCodable(assignment.finalReview, named: "final_review.json", category: "finalReview", sensitivity: .teacherAudit, description: "Teacher final review record.", inventory: &inventory, to: archive)
            try addCodable(assignment.auditEvents, named: "audit_events.json", category: "auditEvents", sensitivity: .teacherAudit, description: "Audit events recorded for the assignment.", inventory: &inventory, to: archive)
            try addCodable(assignment.exportRecords, named: "export_records.json", category: "exportRecords", sensitivity: .internalMetadata, description: "Prior export records and fingerprints.", inventory: &inventory, to: archive)
            try addCodable(assignment.curriculumMappings, named: "curriculum_mappings.json", category: "curriculumMappings", sensitivity: .internalMetadata, description: "Local curriculum mapping records.", inventory: &inventory, to: archive)
            try addSources(existingSourceFiles, to: archive, inventory: &inventory)
            try writeInventory(&inventory, to: archive)
            ExportFileHardening.applyBestEffortProtection(to: destination)
            return destination
        } catch {
            throw BundleExportError.archiveFailed(error.localizedDescription)
        }
    }

    static func writeAssignmentArchive(assignments: [AssignmentRecord], sourceFiles: [URL], to destination: URL) throws -> URL {
        try prepareDestination(destination)
        let existingSourceFiles = sourceFiles.filter { FileManager.default.fileExists(atPath: $0.path) }
        do {
            guard let archive = Archive(url: destination, accessMode: .create) else {
                throw BundleExportError.archiveFailed("Could not create ZIP archive at \(destination.lastPathComponent).")
            }
            var inventory: [ExportArchiveInventoryItem] = []
            let manifest = BackupArchiveManifest(
                archiveKind: GradeDraftArchiveKind.assignmentGradebookArchive.rawValue,
                includesPrivateTeacherNotes: true,
                includesOriginalSources: !existingSourceFiles.isEmpty,
                sourceFileCount: existingSourceFiles.count,
                recordCounts: recordCounts(for: assignments, classGroups: [], students: []),
                contentHashes: contentHashes(for: assignments, extraFiles: existingSourceFiles)
            )
            try addCodable(manifest, named: "manifest.json", category: "manifest", sensitivity: .internalMetadata, description: "Archive manifest and restore compatibility metadata.", inventory: &inventory, to: archive)
            try addData(CSVExportService.exportedCSV(from: assignments).data(using: .utf8) ?? Data(), named: "gradebook.csv", category: "gradebook", sensitivity: .gradebook, description: "Quoted and formula-neutralized gradebook CSV.", inventory: &inventory, to: archive)
            try addCodable(assignments, named: "assignments.json", category: "assignmentRecord", sensitivity: .teacherAudit, description: "Complete assignment records.", inventory: &inventory, to: archive)
            for assignment in assignments {
                let root = "student_work/\(assignment.id.uuidString)"
                try addData(MarkdownReportBuilder.studentMarkdown(for: assignment).data(using: .utf8) ?? Data(), named: "\(root)/student_report.md", category: "studentReport", sensitivity: .studentReport, description: "Final-only student-facing report content.", inventory: &inventory, to: archive)
                try addData(MarkdownReportBuilder.teacherAuditMarkdown(for: assignment).data(using: .utf8) ?? Data(), named: "\(root)/teacher_audit_report.md", category: "teacherAuditReport", sensitivity: .teacherAudit, description: "Teacher-only audit report with private notes and provenance.", inventory: &inventory, to: archive)
                try addCodable(assignment.finalReview, named: "\(root)/final_review.json", category: "finalReview", sensitivity: .teacherAudit, description: "Teacher final review record.", inventory: &inventory, to: archive)
                try addCodable(assignment.evidenceReferences, named: "\(root)/evidence_refs.json", category: "evidence", sensitivity: .teacherAudit, description: "Evidence references and bounding boxes.", inventory: &inventory, to: archive)
                try addCodable(assignment.ocrDocument, named: "\(root)/ocr_document.json", category: "ocrDocument", sensitivity: .teacherAudit, description: "OCR document and review state.", inventory: &inventory, to: archive)
            }
            try addSources(existingSourceFiles, to: archive, inventory: &inventory)
            try writeInventory(&inventory, to: archive)
            ExportFileHardening.applyBestEffortProtection(to: destination)
            return destination
        } catch {
            throw BundleExportError.archiveFailed(error.localizedDescription)
        }
    }

    static func writeFullBackup(
        assignments: [AssignmentRecord],
        sourceFiles: [URL],
        to destination: URL,
        classGroups: [ClassGroupRecord] = [],
        students: [StudentRecord] = [],
        rosterEntries: [AssignmentRosterEntry] = []
    ) throws -> URL {
        try prepareDestination(destination)
        let existingSourceFiles = sourceFiles.filter { FileManager.default.fileExists(atPath: $0.path) }
        do {
            guard let archive = Archive(url: destination, accessMode: .create) else {
                throw BundleExportError.archiveFailed("Could not create ZIP archive at \(destination.lastPathComponent).")
            }
            var inventory: [ExportArchiveInventoryItem] = []
            let manifest = BackupArchiveManifest(
                archiveKind: GradeDraftArchiveKind.fullLocalBackup.rawValue,
                includesPrivateTeacherNotes: true,
                includesOriginalSources: !existingSourceFiles.isEmpty,
                sourceFileCount: existingSourceFiles.count,
                recordCounts: recordCounts(for: assignments, classGroups: classGroups, students: students, rosterEntries: rosterEntries),
                contentHashes: contentHashes(for: assignments, extraFiles: existingSourceFiles)
            )
            let databaseExport = BackupDatabaseExport(assignments: assignments, classGroups: classGroups, students: students, rosterEntries: rosterEntries)
            try addCodable(manifest, named: "manifest.json", category: "manifest", sensitivity: .internalMetadata, description: "Backup manifest and restore compatibility metadata.", inventory: &inventory, to: archive)
            try addCodable(["schemaVersion": manifest.schemaVersion], named: "schema_version.json", category: "schema", sensitivity: .internalMetadata, description: "Backup schema marker.", inventory: &inventory, to: archive)
            try addCodable(databaseExport, named: "database_export.json", category: "databaseExport", sensitivity: .teacherAudit, description: "Complete local database export.", inventory: &inventory, to: archive)
            try addCodable(assignments, named: "assignments.json", category: "assignmentRecord", sensitivity: .teacherAudit, description: "Complete assignment records.", inventory: &inventory, to: archive)
            try addCodable(classGroups, named: "class_groups.json", category: "classGroups", sensitivity: .studentDataInternal, description: "Class group records.", inventory: &inventory, to: archive)
            try addCodable(students, named: "students.json", category: "students", sensitivity: .studentDataInternal, description: "Student records.", inventory: &inventory, to: archive)
            try addCodable(rosterEntries, named: "assignment_roster_entries.json", category: "rosterEntries", sensitivity: .studentDataInternal, description: "Assignment roster entries.", inventory: &inventory, to: archive)
            try addCodable(assignments.flatMap(\.sourceInputs), named: "source_inputs.json", category: "sourceMetadata", sensitivity: .sourceMetadata, description: "Source input metadata.", inventory: &inventory, to: archive)
            try addCodable(assignments.flatMap(\.evidenceReferences), named: "evidence_refs.json", category: "evidence", sensitivity: .teacherAudit, description: "Evidence references and bounding boxes.", inventory: &inventory, to: archive)
            try addCodable(assignments.flatMap(\.auditEvents), named: "audit_events.json", category: "auditEvents", sensitivity: .teacherAudit, description: "Assignment audit events.", inventory: &inventory, to: archive)
            try addCodable(assignments.flatMap(\.exportRecords), named: "export_records.json", category: "exportRecords", sensitivity: .internalMetadata, description: "Export records and fingerprints.", inventory: &inventory, to: archive)
            try addCodable(assignments.flatMap(\.curriculumMappings), named: "curriculum_mappings.json", category: "curriculumMappings", sensitivity: .internalMetadata, description: "Local curriculum mappings.", inventory: &inventory, to: archive)
            try addCodable(assignments.compactMap(\.ocrDocument), named: "ocr_documents.json", category: "ocrDocument", sensitivity: .teacherAudit, description: "OCR documents and review state.", inventory: &inventory, to: archive)
            try addSources(existingSourceFiles, to: archive, inventory: &inventory)
            try writeInventory(&inventory, to: archive)
            ExportFileHardening.applyBestEffortProtection(to: destination)
            return destination
        } catch {
            throw BundleExportError.archiveFailed(error.localizedDescription)
        }
    }

    static func readBackupDatabaseExport(from url: URL) throws -> BackupDatabaseExport {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw BundleExportError.restoreFailed("Could not open backup archive for reading.")
        }
        guard archive["manifest.json"] != nil else {
            throw BundleExportError.restoreFailed("Backup archive is missing manifest.json.")
        }
        if let dataEntry = archive["database_export.json"] {
            return try readCodable(BackupDatabaseExport.self, entry: dataEntry, archive: archive)
        }
        guard let assignmentEntry = archive["assignments.json"] else {
            throw BundleExportError.restoreFailed("Backup archive is missing assignment data.")
        }
        let assignments = try readCodable([AssignmentRecord].self, entry: assignmentEntry, archive: archive)
        let classGroups: [ClassGroupRecord] = try archive["class_groups.json"].map { try readCodable([ClassGroupRecord].self, entry: $0, archive: archive) } ?? []
        let students: [StudentRecord] = try archive["students.json"].map { try readCodable([StudentRecord].self, entry: $0, archive: archive) } ?? []
        let rosterEntries: [AssignmentRosterEntry] = try archive["assignment_roster_entries.json"].map { try readCodable([AssignmentRosterEntry].self, entry: $0, archive: archive) } ?? []
        return BackupDatabaseExport(assignments: assignments, classGroups: classGroups, students: students, rosterEntries: rosterEntries)
    }

    static func readBackupAssignments(from url: URL) throws -> [AssignmentRecord] {
        try readBackupDatabaseExport(from: url).assignments
    }

    static func previewRestore(from url: URL, existingAssignments: [AssignmentRecord]) throws -> BackupRestorePreview {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw BundleExportError.restoreFailed("Could not open backup archive for preview.")
        }
        let manifest: BackupArchiveManifest
        if let manifestEntry = archive["manifest.json"] {
            manifest = try readCodable(BackupArchiveManifest.self, entry: manifestEntry, archive: archive)
        } else {
            throw BundleExportError.restoreFailed("Backup archive is missing manifest.json.")
        }
        guard manifest.archiveKind == GradeDraftArchiveKind.fullLocalBackup.rawValue else {
            throw BundleExportError.restoreFailed("Only full local backup archives can be restored. Found \(manifest.archiveKind).")
        }
        guard manifest.schemaVersion.hasPrefix("gradedraft-backup-v") else {
            throw BundleExportError.restoreFailed("Backup schema version is not compatible: \(manifest.schemaVersion).")
        }
        let restored = try readBackupAssignments(from: url)
        let localIDs = Set(existingAssignments.map(\.id))
        let conflicts = restored.map(\.id).filter { localIDs.contains($0) }
        return BackupRestorePreview(
            archiveKind: manifest.archiveKind,
            schemaVersion: manifest.schemaVersion,
            assignmentCount: manifest.recordCounts["assignments"] ?? restored.count,
            classCount: manifest.recordCounts["classGroups"] ?? 0,
            studentCount: manifest.recordCounts["students"] ?? 0,
            sourceFileCount: manifest.sourceFileCount,
            conflictAssignmentIDs: conflicts,
            warnings: manifest.includesPrivateTeacherNotes ? ["Backup contains private teacher notes and teacher-only review records."] : []
        )
    }

    static func restoreBackupArchive(
        from url: URL,
        existingAssignments: [AssignmentRecord],
        applicationSupportDirectory: URL,
        conflictResolution: BackupConflictResolution
    ) throws -> [AssignmentRecord] {
        _ = try previewRestore(from: url, existingAssignments: existingAssignments)
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw BundleExportError.restoreFailed("Could not open backup archive for restore.")
        }
        var restored = try readBackupAssignments(from: url)
        let existingIDs = Set(existingAssignments.map(\.id))
        let copyIDMap: [String: String]
        if conflictResolution == .restoreAsCopy {
            copyIDMap = Dictionary(uniqueKeysWithValues: restored.compactMap { record in
                existingIDs.contains(record.id) ? (record.id.uuidString, UUID().uuidString) : nil
            })
            restored = restored.map { record in
                guard existingIDs.contains(record.id) else { return record }
                var copy = record
                if let copyID = copyIDMap[record.id.uuidString].flatMap(UUID.init(uuidString:)) {
                    copy.id = copyID
                }
                copy.title = "Restored copy of \(record.title)"
                copy.sourceInputs = remappedSourceInputs(copy.sourceInputs, from: record.id.uuidString, to: copy.id.uuidString)
                copy.appendAuditEvent(.inputChanged, detail: "Backup restore copied this assignment because a local assignment already used the original ID.")
                return copy
            }
        } else {
            copyIDMap = [:]
        }
        let conflictingAssignmentIDs = Set(existingAssignments.map { $0.id.uuidString })
        try restoreSourceFiles(
            from: archive,
            to: applicationSupportDirectory,
            conflictResolution: conflictResolution,
            conflictingAssignmentIDs: conflictingAssignmentIDs,
            copyAssignmentIDs: copyIDMap
        )
        return restored
    }

    static func safeRestoreDestination(for archiveEntryPath: String, applicationSupportDirectory: URL) throws -> URL? {
        guard let relative = try safeRelativeSourcePath(fromArchiveEntryPath: archiveEntryPath) else { return nil }
        return try safeDestination(forRelativeSourcePath: relative, applicationSupportDirectory: applicationSupportDirectory)
    }

    private static func prepareDestination(_ destination: URL) throws {
        let directory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
    }

    private static func recordCounts(for assignments: [AssignmentRecord], classGroups: [ClassGroupRecord], students: [StudentRecord], rosterEntries: [AssignmentRosterEntry] = []) -> [String: Int] {
        [
            "assignments": assignments.count,
            "classGroups": classGroups.count,
            "students": students.count,
            "rosterEntries": rosterEntries.count,
            "sources": assignments.flatMap(\.sourceInputs).count,
            "ocrDocuments": assignments.compactMap(\.ocrDocument).count,
            "evidenceReferences": assignments.flatMap(\.evidenceReferences).count,
            "auditEvents": assignments.flatMap(\.auditEvents).count,
            "exports": assignments.flatMap(\.exportRecords).count,
            "curriculumMappings": assignments.flatMap(\.curriculumMappings).count
        ]
    }

    private static func contentHashes(for assignments: [AssignmentRecord], extraFiles: [URL]) -> [String: String] {
        var hashes = Dictionary(uniqueKeysWithValues: assignments.map { ($0.id.uuidString, $0.gradingPacketFingerprint) })
        for file in extraFiles where FileManager.default.fileExists(atPath: file.path) {
            if let data = try? Data(contentsOf: file) {
                hashes["source:\(StableFingerprint.fingerprint([file.path]))"] = StableFingerprint.fingerprint(data)
            }
        }
        return hashes
    }

    private static func addSources(_ sourceFiles: [URL], to archive: Archive, inventory: inout [ExportArchiveInventoryItem]) throws {
        var usedNames: Set<String> = []
        for sourceURL in sourceFiles where FileManager.default.fileExists(atPath: sourceURL.path) {
            let entryName = sourceArchivePath(for: sourceURL, usedNames: &usedNames)
            try addFile(sourceURL, named: entryName, category: "sourceFile", sensitivity: .sourceFile, description: "Original source file included by the teacher.", inventory: &inventory, to: archive)
        }
    }

    private static func restoreSourceFiles(
        from archive: Archive,
        to applicationSupportDirectory: URL,
        conflictResolution: BackupConflictResolution,
        conflictingAssignmentIDs: Set<String>,
        copyAssignmentIDs: [String: String] = [:]
    ) throws {
        let fileManager = FileManager.default
        for entry in archive {
            if entry.path.hasPrefix("/") || entry.path.contains("\\") {
                if entry.path.contains("sources") {
                    throw BundleExportError.restoreFailed("Archive source entry contains an unsafe path: \(entry.path).")
                }
                continue
            }
            guard var relative = try safeRelativeSourcePath(fromArchiveEntryPath: entry.path) else { continue }
            if conflictResolution == .restoreAsCopy,
               let remapped = remappedSourcePath(relative, using: copyAssignmentIDs) {
                relative = remapped
            } else if conflictResolution != .replaceLocal,
                      conflictingAssignmentIDs.contains(where: { sourcePath(relative, belongsTo: $0) }) {
                continue
            }
            let destination = try safeDestination(forRelativeSourcePath: relative, applicationSupportDirectory: applicationSupportDirectory)
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
            _ = try archive.extract(entry, to: destination)
            ExportFileHardening.applyBestEffortProtection(to: destination)
        }
    }

    private static func remappedSourceInputs(_ sourceInputs: [SourceInputRef], from originalAssignmentID: String, to copiedAssignmentID: String) -> [SourceInputRef] {
        sourceInputs.map { source in
            var remapped = source
            if let localRelativePath = source.localRelativePath {
                remapped.localRelativePath = remappedSourcePath(localRelativePath, using: [originalAssignmentID: copiedAssignmentID]) ?? localRelativePath
            }
            return remapped
        }
    }

    private static func remappedSourcePath(_ path: String, using copyAssignmentIDs: [String: String]) -> String? {
        for (originalID, copiedID) in copyAssignmentIDs where sourcePath(path, belongsTo: originalID) {
            return path.replacingOccurrences(of: "Sources/\(originalID)/", with: "Sources/\(copiedID)/")
        }
        return nil
    }

    private static func sourcePath(_ path: String, belongsTo assignmentID: String) -> Bool {
        path.hasPrefix("Sources/\(assignmentID)/") || path.contains("/Sources/\(assignmentID)/")
    }

    private static func addCodable<T: Encodable>(
        _ value: T,
        named name: String,
        category: String,
        sensitivity: ExportInventorySensitivity,
        description: String,
        inventory: inout [ExportArchiveInventoryItem],
        to archive: Archive
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try addData(try encoder.encode(value), named: name, category: category, sensitivity: sensitivity, description: description, inventory: &inventory, to: archive)
    }

    private static func readCodable<T: Decodable>(_ type: T.Type, entry: Entry, archive: Archive) throws -> T {
        var data = Data()
        _ = try archive.extract(entry) { chunk in data.append(chunk) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    private static func addData(
        _ data: Data,
        named name: String,
        category: String,
        sensitivity: ExportInventorySensitivity,
        description: String,
        inventory: inout [ExportArchiveInventoryItem],
        to archive: Archive
    ) throws {
        let safeName = safeArchivePath(name)
        try addDataWithoutInventory(data, named: safeName, to: archive)
        inventory.append(sensitivity.inventoryItem(path: safeName, category: category, description: description))
    }

    private static func addFile(
        _ fileURL: URL,
        named name: String,
        category: String,
        sensitivity: ExportInventorySensitivity,
        description: String,
        inventory: inout [ExportArchiveInventoryItem],
        to archive: Archive
    ) throws {
        let safeName = safeArchivePath(name)
        try archive.addEntry(with: safeName, fileURL: fileURL)
        inventory.append(sensitivity.inventoryItem(path: safeName, category: category, description: description))
    }

    private static func writeInventory(_ inventory: inout [ExportArchiveInventoryItem], to archive: Archive) throws {
        let inventoryPath = "archive_inventory.json"
        inventory.append(
            ExportInventorySensitivity.inventory.inventoryItem(
                path: inventoryPath,
                category: "inventory",
                description: "Machine-readable inventory for this export archive."
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try addDataWithoutInventory(try encoder.encode(inventory), named: inventoryPath, to: archive)
    }

    private static func addDataWithoutInventory(_ data: Data, named name: String, to archive: Archive) throws {
        let safeName = safeArchivePath(name)
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftArchiveData-\(UUID().uuidString).data")
        try data.write(to: scratch, options: [.atomic])
        defer { try? FileManager.default.removeItem(at: scratch) }
        try archive.addEntry(with: safeName, fileURL: scratch)
    }

    private static func safeArchivePath(_ name: String) -> String {
        let normalized = name.replacingOccurrences(of: "\\", with: "_")
        let components = normalized
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { sanitizedPathComponent(String($0)) }
            .filter { !$0.isEmpty }
        return components.isEmpty ? "file" : components.joined(separator: "/")
    }

    private static func sanitizedPathComponent(_ component: String) -> String {
        var sanitized = component.replacingOccurrences(of: "[^A-Za-z0-9._-]+", with: "_", options: .regularExpression)
        while sanitized.contains("..") {
            sanitized = sanitized.replacingOccurrences(of: "..", with: "_")
        }
        if sanitized.isEmpty || sanitized == "." || sanitized == ".." { return "_" }
        return sanitized
    }

    private static func sourceArchivePath(for sourceURL: URL, usedNames: inout Set<String>) -> String {
        let standardizedPath = sourceURL.standardizedFileURL.path
        let base: String
        if let relativeRange = standardizedPath.range(of: "/Sources/") {
            let relative = String(standardizedPath[relativeRange.upperBound...])
            let components = relative.split(separator: "/", omittingEmptySubsequences: false).map { sanitizedPathComponent(String($0)) }.filter { !$0.isEmpty }
            base = "sources/Sources/\(components.isEmpty ? sanitizedPathComponent(sourceURL.lastPathComponent) : components.joined(separator: "/"))"
        } else {
            let digest = StableFingerprint.fingerprint([standardizedPath]).replacingOccurrences(of: "fnv1a64-", with: "")
            base = "sources/imported/\(String(digest.prefix(12)))-\(sanitizedPathComponent(sourceURL.lastPathComponent))"
        }
        return uniqueArchivePath(base, usedNames: &usedNames)
    }

    private static func uniqueArchivePath(_ proposed: String, usedNames: inout Set<String>) -> String {
        let safe = safeArchivePath(proposed)
        guard usedNames.contains(safe) else {
            usedNames.insert(safe)
            return safe
        }

        let slashIndex = safe.lastIndex(of: "/")
        let directory = slashIndex.map { String(safe[..<$0]) } ?? ""
        let fileName = slashIndex.map { String(safe[safe.index(after: $0)...]) } ?? safe
        let nsFileName = fileName as NSString
        let ext = nsFileName.pathExtension
        let stem = ext.isEmpty ? fileName : nsFileName.deletingPathExtension
        var counter = 2
        while true {
            let candidateStem = "\(stem)-\(counter)"
            let candidateName = ext.isEmpty ? candidateStem : "\(candidateStem).\(ext)"
            let candidate = directory.isEmpty ? candidateName : "\(directory)/\(candidateName)"
            if !usedNames.contains(candidate) {
                usedNames.insert(candidate)
                return candidate
            }
            counter += 1
        }
    }

    private static func safeRelativeSourcePath(fromArchiveEntryPath archiveEntryPath: String) throws -> String? {
        guard archiveEntryPath.hasPrefix("sources/") else { return nil }
        let relative = String(archiveEntryPath.dropFirst("sources/".count))
        guard !relative.isEmpty else { throw BundleExportError.restoreFailed("Archive source entry contains an empty source path: \(archiveEntryPath).") }
        guard !relative.hasPrefix("/") else { throw BundleExportError.restoreFailed("Archive source entry contains an absolute path: \(archiveEntryPath).") }
        guard !relative.contains("\\") else { throw BundleExportError.restoreFailed("Archive source entry contains an unsafe path separator: \(archiveEntryPath).") }
        let components = relative.split(separator: "/", omittingEmptySubsequences: false)
        guard components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw BundleExportError.restoreFailed("Archive source entry contains an unsafe path: \(archiveEntryPath).")
        }
        return relative
    }

    private static func safeDestination(forRelativeSourcePath relative: String, applicationSupportDirectory: URL) throws -> URL {
        guard !relative.isEmpty, !relative.hasPrefix("/"), !relative.contains("\\") else {
            throw BundleExportError.restoreFailed("Archive source entry contains an unsafe path: \(relative).")
        }
        let components = relative.split(separator: "/", omittingEmptySubsequences: false)
        guard components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw BundleExportError.restoreFailed("Archive source entry contains an unsafe path: \(relative).")
        }
        let root = applicationSupportDirectory.standardizedFileURL
        let destination = root.appendingPathComponent(relative).standardizedFileURL
        guard destination.path == root.path || destination.path.hasPrefix(root.path + "/") else {
            throw BundleExportError.restoreFailed("Archive source entry escapes local storage: \(relative).")
        }
        return destination
    }
}

private struct ExportInventorySensitivity {
    var includesStudentData: Bool
    var includesPrivateTeacherNotes: Bool
    var includesOriginalSources: Bool
    var includesInternalMetadata: Bool

    static let studentReport = ExportInventorySensitivity(includesStudentData: true, includesPrivateTeacherNotes: false, includesOriginalSources: false, includesInternalMetadata: false)
    static let gradebook = ExportInventorySensitivity(includesStudentData: true, includesPrivateTeacherNotes: false, includesOriginalSources: false, includesInternalMetadata: true)
    static let studentDataInternal = ExportInventorySensitivity(includesStudentData: true, includesPrivateTeacherNotes: false, includesOriginalSources: false, includesInternalMetadata: true)
    static let sourceMetadata = ExportInventorySensitivity(includesStudentData: true, includesPrivateTeacherNotes: false, includesOriginalSources: false, includesInternalMetadata: true)
    static let sourceFile = ExportInventorySensitivity(includesStudentData: true, includesPrivateTeacherNotes: false, includesOriginalSources: true, includesInternalMetadata: false)
    static let teacherAudit = ExportInventorySensitivity(includesStudentData: true, includesPrivateTeacherNotes: true, includesOriginalSources: false, includesInternalMetadata: true)
    static let internalMetadata = ExportInventorySensitivity(includesStudentData: true, includesPrivateTeacherNotes: false, includesOriginalSources: false, includesInternalMetadata: true)
    static let inventory = ExportInventorySensitivity(includesStudentData: false, includesPrivateTeacherNotes: false, includesOriginalSources: false, includesInternalMetadata: true)

    func inventoryItem(path: String, category: String, description: String) -> ExportArchiveInventoryItem {
        ExportArchiveInventoryItem(
            path: path,
            category: category,
            includesStudentData: includesStudentData,
            includesPrivateTeacherNotes: includesPrivateTeacherNotes,
            includesOriginalSources: includesOriginalSources,
            includesInternalMetadata: includesInternalMetadata,
            description: description
        )
    }
}
// swiftlint:enable type_body_length
