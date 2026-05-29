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
        return root.appendingPathComponent("GradeDraft-Archive-\(assignmentID.uuidString).zip", isDirectory: false)
    }

    static func writeBundle(assignment: AssignmentRecord, sourceFiles: [URL], to destination: URL) throws -> URL {
        try writeTeacherAuditArchive(assignment: assignment, sourceFiles: sourceFiles, to: destination)
    }

    static func writeTeacherAuditArchive(assignment: AssignmentRecord, sourceFiles: [URL], to destination: URL) throws -> URL {
        try prepareDestination(destination)
        do {
            guard let archive = Archive(url: destination, accessMode: .create) else {
                throw BundleExportError.archiveFailed("Could not create ZIP archive at \(destination.lastPathComponent).")
            }
            let manifest = BackupArchiveManifest(
                archiveKind: GradeDraftArchiveKind.teacherAuditArchive.rawValue,
                includesPrivateTeacherNotes: true,
                includesOriginalSources: !sourceFiles.isEmpty,
                sourceFileCount: sourceFiles.count,
                recordCounts: recordCounts(for: [assignment], classGroups: [], students: []),
                contentHashes: contentHashes(for: [assignment], extraFiles: sourceFiles)
            )
            try addCodable(manifest, named: "manifest.json", to: archive)
            try addData(MarkdownReportBuilder.studentMarkdown(for: assignment).data(using: .utf8) ?? Data(), named: "student_report.md", to: archive)
            try addData(MarkdownReportBuilder.teacherAuditMarkdown(for: assignment).data(using: .utf8) ?? Data(), named: "teacher_audit_report.md", to: archive)
            let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftArchivePDFs", isDirectory: true)
            try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
            let studentPDF = try PDFExportService.studentReportPDF(for: assignment, destination: tempRoot.appendingPathComponent("student_report-\(assignment.id.uuidString).pdf"))
            let auditPDF = try PDFExportService.teacherAuditPDF(for: assignment, destination: tempRoot.appendingPathComponent("teacher_audit_report-\(assignment.id.uuidString).pdf"))
            try archive.addEntry(with: "student_report.pdf", fileURL: studentPDF)
            try archive.addEntry(with: "teacher_audit_report.pdf", fileURL: auditPDF)
            try addData(CSVExportService.exportedCSV(from: [assignment]).data(using: .utf8) ?? Data(), named: "grade_summary.csv", to: archive)
            try addCodable(assignment, named: "assignment.json", to: archive)
            try addCodable(assignment.parsedRubric.criteria, named: "rubric.json", to: archive)
            try addCodable(assignment.sourceInputs, named: "source_metadata.json", to: archive)
            try addCodable(assignment.ocrDocument, named: "ocr_document.json", to: archive)
            try addCodable(assignment.evidenceReferences, named: "evidence_refs.json", to: archive)
            try addCodable(assignment.latestDraft, named: "grade_proposal.json", to: archive)
            try addCodable(assignment.finalReview, named: "final_review.json", to: archive)
            try addCodable(assignment.auditEvents, named: "audit_events.json", to: archive)
            try addCodable(assignment.exportRecords, named: "export_records.json", to: archive)
            try addCodable(assignment.curriculumMappings, named: "curriculum_mappings.json", to: archive)
            try addSources(sourceFiles, to: archive)
            return destination
        } catch {
            throw BundleExportError.archiveFailed(error.localizedDescription)
        }
    }

    static func writeAssignmentArchive(assignments: [AssignmentRecord], sourceFiles: [URL], to destination: URL) throws -> URL {
        try prepareDestination(destination)
        do {
            guard let archive = Archive(url: destination, accessMode: .create) else {
                throw BundleExportError.archiveFailed("Could not create ZIP archive at \(destination.lastPathComponent).")
            }
            let manifest = BackupArchiveManifest(
                archiveKind: GradeDraftArchiveKind.assignmentGradebookArchive.rawValue,
                includesPrivateTeacherNotes: true,
                includesOriginalSources: !sourceFiles.isEmpty,
                sourceFileCount: sourceFiles.count,
                recordCounts: recordCounts(for: assignments, classGroups: [], students: []),
                contentHashes: contentHashes(for: assignments, extraFiles: sourceFiles)
            )
            try addCodable(manifest, named: "manifest.json", to: archive)
            try addData(CSVExportService.exportedCSV(from: assignments).data(using: .utf8) ?? Data(), named: "gradebook.csv", to: archive)
            try addCodable(assignments, named: "assignments.json", to: archive)
            for assignment in assignments {
                let root = "student_work/\(assignment.id.uuidString)"
                try addData(MarkdownReportBuilder.studentMarkdown(for: assignment).data(using: .utf8) ?? Data(), named: "\(root)/student_report.md", to: archive)
                try addData(MarkdownReportBuilder.teacherAuditMarkdown(for: assignment).data(using: .utf8) ?? Data(), named: "\(root)/teacher_audit_report.md", to: archive)
                try addCodable(assignment.finalReview, named: "\(root)/final_review.json", to: archive)
                try addCodable(assignment.evidenceReferences, named: "\(root)/evidence_refs.json", to: archive)
                try addCodable(assignment.ocrDocument, named: "\(root)/ocr_document.json", to: archive)
            }
            try addSources(sourceFiles, to: archive)
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
        do {
            guard let archive = Archive(url: destination, accessMode: .create) else {
                throw BundleExportError.archiveFailed("Could not create ZIP archive at \(destination.lastPathComponent).")
            }
            let manifest = BackupArchiveManifest(
                archiveKind: GradeDraftArchiveKind.fullLocalBackup.rawValue,
                includesPrivateTeacherNotes: true,
                includesOriginalSources: !sourceFiles.isEmpty,
                sourceFileCount: sourceFiles.count,
                recordCounts: recordCounts(for: assignments, classGroups: classGroups, students: students, rosterEntries: rosterEntries),
                contentHashes: contentHashes(for: assignments, extraFiles: sourceFiles)
            )
            let databaseExport = BackupDatabaseExport(assignments: assignments, classGroups: classGroups, students: students, rosterEntries: rosterEntries)
            try addCodable(manifest, named: "manifest.json", to: archive)
            try addCodable(["schemaVersion": manifest.schemaVersion], named: "schema_version.json", to: archive)
            try addCodable(databaseExport, named: "database_export.json", to: archive)
            try addCodable(assignments, named: "assignments.json", to: archive)
            try addCodable(classGroups, named: "class_groups.json", to: archive)
            try addCodable(students, named: "students.json", to: archive)
            try addCodable(rosterEntries, named: "assignment_roster_entries.json", to: archive)
            try addCodable(assignments.flatMap(\.sourceInputs), named: "source_inputs.json", to: archive)
            try addCodable(assignments.flatMap(\.evidenceReferences), named: "evidence_refs.json", to: archive)
            try addCodable(assignments.flatMap(\.auditEvents), named: "audit_events.json", to: archive)
            try addCodable(assignments.flatMap(\.exportRecords), named: "export_records.json", to: archive)
            try addCodable(assignments.flatMap(\.curriculumMappings), named: "curriculum_mappings.json", to: archive)
            try addCodable(assignments.compactMap(\.ocrDocument), named: "ocr_documents.json", to: archive)
            try addSources(sourceFiles, to: archive)
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
                hashes["source:\(file.lastPathComponent)"] = StableFingerprint.fingerprint(data)
            }
        }
        return hashes
    }

    private static func addSources(_ sourceFiles: [URL], to archive: Archive) throws {
        for sourceURL in sourceFiles where FileManager.default.fileExists(atPath: sourceURL.path) {
            let safeLastPath = sourceURL.lastPathComponent.replacingOccurrences(of: "..", with: "_")
            let entryName: String
            if let relativeRange = sourceURL.path.range(of: "/Sources/") {
                let relative = String(sourceURL.path[relativeRange.upperBound...])
                entryName = safeArchivePath("sources/Sources/\(relative)")
            } else {
                entryName = safeArchivePath("sources/\(safeLastPath)")
            }
            try archive.addEntry(with: entryName, fileURL: sourceURL)
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
        for entry in archive where entry.path.hasPrefix("sources/") {
            guard !entry.path.contains("..") else { throw BundleExportError.restoreFailed("Archive source entry contains an unsafe path: \(entry.path).") }
            var relative = String(entry.path.dropFirst("sources/".count))
            guard !relative.isEmpty else { continue }
            if conflictResolution == .restoreAsCopy,
               let remapped = remappedSourcePath(relative, using: copyAssignmentIDs) {
                relative = remapped
            } else if conflictResolution != .replaceLocal,
                      conflictingAssignmentIDs.contains(where: { sourcePath(relative, belongsTo: $0) }) {
                continue
            }
            let destination = applicationSupportDirectory.appendingPathComponent(relative)
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
            _ = try archive.extract(entry, to: destination)
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

    private static func addCodable<T: Encodable>(_ value: T, named name: String, to archive: Archive) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try addData(try encoder.encode(value), named: name, to: archive)
    }

    private static func readCodable<T: Decodable>(_ type: T.Type, entry: Entry, archive: Archive) throws -> T {
        var data = Data()
        _ = try archive.extract(entry) { chunk in data.append(chunk) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    private static func addData(_ data: Data, named name: String, to archive: Archive) throws {
        let safeName = safeArchivePath(name)
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftArchiveData-\(UUID().uuidString).data")
        try data.write(to: scratch, options: [.atomic])
        defer { try? FileManager.default.removeItem(at: scratch) }
        try archive.addEntry(with: safeName, fileURL: scratch)
    }

    private static func safeArchivePath(_ name: String) -> String {
        name.split(separator: "/").map { part in
            part == ".." ? "_" : part.replacingOccurrences(of: "\\", with: "_")
        }.joined(separator: "/")
    }
}
// swiftlint:enable type_body_length
