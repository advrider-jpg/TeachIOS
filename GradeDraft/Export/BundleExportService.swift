import Foundation
import ZIPFoundation

// swiftlint:disable type_body_length

enum BundleExportError: LocalizedError {
    case preflightFailed(String)
    case archiveFailed(String)
    case restoreFailed(String)

    var errorDescription: String? {
        switch self {
        case .preflightFailed(let detail):
            "Bundle export preflight failed: \(detail)"
        case .archiveFailed(let detail):
            "Bundle export failed: \(detail)"
        case .restoreFailed(let detail):
            "Backup restore failed: \(detail)"
        }
    }
}

enum GradeDraftArchiveKind: String, Codable {
    case teacherAuditArchive
    case assignmentGradebookArchive
    case fullLocalBackup
}

/// Local ZIP/archive export. Archives are teacher-facing and may contain sensitive records.
struct BundleExportService {
    static func preflightDestination(for assignmentID: UUID) throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = documents.appendingPathComponent("GradeDraftExports", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("GradeDraft-Archive-\(assignmentID.uuidString).zip", isDirectory: false)
    }

    static func writeBundle(
        assignment: AssignmentRecord,
        sourceFiles: [URL],
        to destination: URL
    ) throws -> URL {
        try writeTeacherAuditArchive(assignment: assignment, sourceFiles: sourceFiles, to: destination)
    }

    static func writeTeacherAuditArchive(assignment: AssignmentRecord, sourceFiles: [URL], to destination: URL) throws -> URL {
        try prepareDestination(destination)
        do {
            let archive = try Archive(url: destination, accessMode: .create)
            let manifest = BackupArchiveManifest(
                archiveKind: GradeDraftArchiveKind.teacherAuditArchive.rawValue,
                includesPrivateTeacherNotes: true,
                includesOriginalSources: !sourceFiles.isEmpty,
                sourceFileCount: sourceFiles.count,
                recordCounts: recordCounts(for: [assignment]),
                contentHashes: ["assignment": assignment.gradingPacketFingerprint]
            )
            try addCodable(manifest, named: "manifest.json", to: archive)
            try addData(MarkdownReportBuilder.studentMarkdown(for: assignment).data(using: .utf8) ?? Data(), named: "student_report.md", to: archive)
            try addData(MarkdownReportBuilder.teacherAuditMarkdown(for: assignment).data(using: .utf8) ?? Data(), named: "teacher_audit_report.md", to: archive)
            let temp = FileManager.default.temporaryDirectory
            let studentPDF = try PDFExportService.studentReportPDF(for: assignment, destination: temp.appendingPathComponent("student_report.pdf"))
            let auditPDF = try PDFExportService.teacherAuditPDF(for: assignment, destination: temp.appendingPathComponent("teacher_audit_report.pdf"))
            try archive.addEntry(with: "student_report.pdf", fileURL: studentPDF)
            try archive.addEntry(with: "teacher_audit_report.pdf", fileURL: auditPDF)
            try addData(CSVExportService.exportedCSV(from: [assignment]).data(using: .utf8) ?? Data(), named: "grade_summary.csv", to: archive)
            try addCodable(assignment, named: "assignment.json", to: archive)
            try addCodable(assignment.sourceInputs, named: "source_metadata.json", to: archive)
            try addCodable(assignment.evidenceReferences, named: "evidence_refs.json", to: archive)
            try addCodable(assignment.ocrDocument, named: "ocr_document.json", to: archive)
            try addCodable(assignment.latestDraft, named: "grade_proposal.json", to: archive)
            try addCodable(assignment.finalReview, named: "final_review.json", to: archive)
            try addCodable(assignment.auditEvents, named: "audit_events.json", to: archive)
            try addCodable(assignment.exportRecords, named: "export_records.json", to: archive)
            try addSources(sourceFiles, to: archive)
            return destination
        } catch {
            throw BundleExportError.archiveFailed(error.localizedDescription)
        }
    }

    static func writeAssignmentArchive(assignments: [AssignmentRecord], sourceFiles: [URL], to destination: URL) throws -> URL {
        try prepareDestination(destination)
        do {
            let archive = try Archive(url: destination, accessMode: .create)
            let manifest = BackupArchiveManifest(
                archiveKind: GradeDraftArchiveKind.assignmentGradebookArchive.rawValue,
                includesPrivateTeacherNotes: true,
                includesOriginalSources: !sourceFiles.isEmpty,
                sourceFileCount: sourceFiles.count,
                recordCounts: recordCounts(for: assignments),
                contentHashes: Dictionary(uniqueKeysWithValues: assignments.map { ($0.id.uuidString, $0.gradingPacketFingerprint) })
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

    static func writeFullBackup(assignments: [AssignmentRecord], sourceFiles: [URL], to destination: URL) throws -> URL {
        try prepareDestination(destination)
        do {
            let archive = try Archive(url: destination, accessMode: .create)
            let manifest = BackupArchiveManifest(
                archiveKind: GradeDraftArchiveKind.fullLocalBackup.rawValue,
                includesPrivateTeacherNotes: true,
                includesOriginalSources: !sourceFiles.isEmpty,
                sourceFileCount: sourceFiles.count,
                recordCounts: recordCounts(for: assignments),
                contentHashes: Dictionary(uniqueKeysWithValues: assignments.map { ($0.id.uuidString, $0.gradingPacketFingerprint) })
            )
            try addCodable(manifest, named: "manifest.json", to: archive)
            try addCodable(["schemaVersion": "gradedraft-backup-v1"], named: "schema_version.json", to: archive)
            try addCodable(assignments, named: "database_export.json", to: archive)
            try addCodable(assignments, named: "assignments.json", to: archive)
            try addCodable(assignments.flatMap(\.sourceInputs), named: "source_inputs.json", to: archive)
            try addCodable(assignments.flatMap(\.auditEvents), named: "audit_events.json", to: archive)
            try addCodable(assignments.flatMap(\.exportRecords), named: "export_records.json", to: archive)
            try addSources(sourceFiles, to: archive)
            return destination
        } catch {
            throw BundleExportError.archiveFailed(error.localizedDescription)
        }
    }

    static func readBackupAssignments(from url: URL) throws -> [AssignmentRecord] {
        let archive = try Archive(url: url, accessMode: .read)
        guard archive["manifest.json"] != nil else {
            throw BundleExportError.restoreFailed("Backup archive is missing manifest.json.")
        }
        guard let dataEntry = archive["database_export.json"] ?? archive["assignments.json"] else {
            throw BundleExportError.restoreFailed("Backup archive is missing assignment data.")
        }
        var data = Data()
        _ = try archive.extract(dataEntry) { chunk in data.append(chunk) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([AssignmentRecord].self, from: data)
    }

    private static func prepareDestination(_ destination: URL) throws {
        let directory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
    }

    private static func recordCounts(for assignments: [AssignmentRecord]) -> [String: Int] {
        [
            "assignments": assignments.count,
            "sources": assignments.flatMap(\.sourceInputs).count,
            "evidenceReferences": assignments.flatMap(\.evidenceReferences).count,
            "auditEvents": assignments.flatMap(\.auditEvents).count,
            "exports": assignments.flatMap(\.exportRecords).count
        ]
    }

    private static func addSources(_ sourceFiles: [URL], to archive: Archive) throws {
        for sourceURL in sourceFiles where FileManager.default.fileExists(atPath: sourceURL.path) {
            let entryName = "sources/\(sourceURL.lastPathComponent)"
            try archive.addEntry(with: entryName, fileURL: sourceURL)
        }
    }

    private static func addCodable<T: Encodable>(_ value: T, named name: String, to archive: Archive) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try addData(try encoder.encode(value), named: name, to: archive)
    }

    private static func addData(_ data: Data, named name: String, to archive: Archive) throws {
        let safeName = name.replacingOccurrences(of: "..", with: "_")
        try archive.addEntry(with: safeName, type: .file, uncompressedSize: Int64(data.count)) { position, size in
            let start = Int(position)
            return data.subdata(in: start..<(start + size))
        }
    }
}
// swiftlint:enable type_body_length
