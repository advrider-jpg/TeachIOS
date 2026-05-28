import Foundation
import GRDB

enum GradeDraftDatabaseError: Error, LocalizedError {
    case missingStoreRoot
    case migrationFailed(String)
    case preflightFailed(String)
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
            let value = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM grade_draft_assignments") ?? 0
            return value
        }
        return DatabaseBackupDescriptor(
            assignmentCount: assignmentRowCount,
            exportCreatedAt: Date()
        )
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

        migrator.registerMigration("002_audit_replay_guardrails") { db in
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
