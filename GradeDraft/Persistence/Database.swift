import Foundation
import GRDB

enum GradeDraftDatabaseError: Error, LocalizedError {
    case missingStoreRoot
    case migrationFailed(String)
    case preflightFailed(String)
    case dataCorrupted(String)
}

struct DatabaseBackupDescriptor: Codable {
    let assignmentCount: Int
    let exportCreatedAt: Date
}

/// Thin GRDB entry point for the next persistence pass.
/// This is intentionally minimal and intentionally defensive: it validates
/// migration progress and preflight paths before write operations begin.
final class GradeDraftDatabase {
    private let databaseQueue: DatabaseQueue
    private let migrations = DatabaseMigrator()
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    init(applicationSupportURL: URL? = nil) throws {
        let baseURL = applicationSupportURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first

        guard let baseURL else {
            throw GradeDraftDatabaseError.missingStoreRoot
        }

        let databaseFolder = baseURL.appendingPathComponent("GradeDraft", isDirectory: true)
        let databaseURL = databaseFolder.appendingPathComponent("gradedraft.sqlite")
        try FileManager.default.createDirectory(at: databaseFolder, withIntermediateDirectories: true)

        databaseQueue = try DatabaseQueue(path: databaseURL.path)
    }

    func loadAssignments() throws -> [AssignmentRecord] {
        try databaseQueue.read { db in
            let payloads = try String.fetchAll(db, sql: "SELECT payload FROM grade_draft_assignment_records ORDER BY updated_at DESC")
            return payloads.map { payload in
                guard let data = payload.data(using: .utf8) else {
                    throw GradeDraftDatabaseError.dataCorrupted("Unable to decode assignment payload bytes.")
                }
                do {
                    return try jsonDecoder.decode(AssignmentRecord.self, from: data)
                } catch {
                    throw GradeDraftDatabaseError.dataCorrupted("Could not decode assignment payload: \(error.localizedDescription)")
                }
            }
        }
    }

    func saveAssignments(_ assignments: [AssignmentRecord]) throws {
        try databaseQueue.write { db in
            for assignment in assignments {
                let payload = try jsonEncoder.encode(assignment)
                let payloadText = String(data: payload, encoding: .utf8) ?? "[]"
                let updatedAt = iso8601.string(from: assignment.updatedAt)
                let id = assignment.id.uuidString
                try db.execute(
                    sql: """
                    INSERT INTO grade_draft_assignment_records (id, payload, updated_at)
                    VALUES (?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at
                    """,
                    arguments: [id, payloadText, updatedAt]
                )
            }
        }
    }

    func deleteAssignment(id: UUID) throws {
        try databaseQueue.write { db in
            try db.execute(sql: "DELETE FROM grade_draft_assignment_records WHERE id = ?", arguments: [id.uuidString])
        }
    }

    func applicationSupportDirectory() throws -> URL {
        try databaseDirectory()
    }

    func bootstrapIfNeeded() throws {
        var migrator = migrations
        registerMigrations(&migrator)
        do {
            try migrator.migrate(databaseQueue)
        } catch {
            throw GradeDraftDatabaseError.migrationFailed(error.localizedDescription)
        }
    }

    func preflightAuditBundle() throws -> URL {
        let folder = try databaseDirectory()
        let backupFolder = folder.appendingPathComponent("Backup", isDirectory: true)
        try FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)

        var valuesAreWritable = false
        try backupFolder.withUnsafeFileSystemRepresentation { representation in
            guard let path = representation else {
                throw GradeDraftDatabaseError.preflightFailed("Could not resolve backup folder path.")
            }
            valuesAreWritable = FileManager.default.isWritableFile(atPath: String(cString: path))
        }

        if !valuesAreWritable {
            throw GradeDraftDatabaseError.preflightFailed("Backup folder is not writable.")
        }
        return backupFolder
    }

    func readBackupDescriptor() throws -> DatabaseBackupDescriptor {
        let databaseURL = try databaseURL()
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return DatabaseBackupDescriptor(assignmentCount: 0, exportCreatedAt: Date())
        }

        let assignmentRowCount = try databaseQueue.read { db in
            let value = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM grade_draft_assignment_records") ?? 0
            return value
        }
        return DatabaseBackupDescriptor(
            assignmentCount: assignmentRowCount,
            exportCreatedAt: Date()
        )
    }

    private static var iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private var iso8601: ISO8601DateFormatter {
        Self.iso8601
    }

    private func databaseDirectory() throws -> URL {
        guard let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw GradeDraftDatabaseError.missingStoreRoot
        }
        return folder.appendingPathComponent("GradeDraft", isDirectory: true)
    }

    private func databaseURL() throws -> URL {
        try databaseDirectory().appendingPathComponent("gradedraft.sqlite")
    }

    private func registerMigrations(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("001_core_schema") { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_assignments (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                subject TEXT NOT NULL,
                grade_level TEXT NOT NULL,
                assignment_type TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """)
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_audit_ledger (
                id TEXT PRIMARY KEY,
                assignment_id TEXT NOT NULL,
                event_type TEXT NOT NULL,
                event_detail TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            """)
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_exports (
                id TEXT PRIMARY KEY,
                assignment_id TEXT NOT NULL,
                export_kind TEXT NOT NULL,
                payload_path TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_audit_assignment_id ON grade_draft_audit_ledger(assignment_id);")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_exports_assignment_id ON grade_draft_exports(assignment_id);")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_exports_created_at ON grade_draft_exports(created_at);")
        }

        migrator.registerMigration("002_assignment_records_json") { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_assignment_records (
                id TEXT PRIMARY KEY,
                payload TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_assignment_records_updated_at ON grade_draft_assignment_records(updated_at);")
        }

        migrator.registerMigration("003_audit_replay_guardrails") { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_bundle_backup_preflight (
                id TEXT PRIMARY KEY,
                assignment_id TEXT NOT NULL,
                packet_digest TEXT NOT NULL,
                expected_items INTEGER NOT NULL,
                checked_at TEXT NOT NULL
            );
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_backup_preflight_assignment_id ON grade_draft_bundle_backup_preflight(assignment_id);")
        }
    }
}
