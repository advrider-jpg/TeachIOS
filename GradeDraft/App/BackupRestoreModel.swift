import Foundation
import Observation

/// Full backup (password-encrypted) and restore, used by the Exports tab. Restore runs
/// prepare → preview → a keep/replace/copy choice for each assignment that also exists locally →
/// commit, or discard. A failure before the commit leaves local data and files unchanged.
@Observable @MainActor
final class BackupRestoreModel {
    var alert: AlertMessage?
    private(set) var isWorking = false
    private(set) var preparedExport: PreparedExport?

    /// A decoded, verified backup waiting for confirmation.
    private(set) var preview: RestorePreview?
    /// The teacher's choice for each conflicting assignment.
    var resolutions: [UUID: RestoreResolution] = [:]

    @ObservationIgnored weak var app: AppModel?

    init() {}

    /// Assignments in the backup that already exist on this device.
    var conflicts: [AssignmentSetup] {
        guard let preview else { return [] }
        let conflicting = Set(preview.conflictingAssignmentIDs)
        return preview.snapshot.assignments.filter { conflicting.contains($0.id) }
    }

    var canCommitRestore: Bool {
        guard let preview, !isWorking else { return false }
        return preview.conflictingAssignmentIDs.allSatisfy { resolutions[$0] != nil }
    }

    private struct Context {
        let app: AppModel
        let database: AppDatabase
        let root: URL
    }

    private func requireApp(_ action: String) -> Context? {
        do {
            guard let app else { throw AppDatabaseError.openFailed(underlying: CocoaError(.featureUnsupported)) }
            return Context(app: app, database: try app.requireDatabase(), root: try app.requireStorageRoot())
        } catch {
            alert = AlertMessage(title: action, error: error)
            return nil
        }
    }

    // MARK: - Full backup

    /// Writes every class, student, assignment, submission and source file into one encrypted
    /// `.markformebackup` file in `tmp/Exports/`, records it, and sets `preparedExport`.
    func createFullBackup(password: String) async {
        guard let context = requireApp("Backup not created"), !isWorking else { return }
        guard !password.isEmpty else {
            alert = AlertMessage(title: "Backup not created", message: BackupArchiveError.passwordRequired.localizedDescription)
            return
        }
        if let message = await context.app.services.authenticateIfRequired(for: .fullBackupArchive) {
            alert = AlertMessage(title: "Backup not created", message: message)
            return
        }
        finishSharing()
        isWorking = true
        defer { isWorking = false }
        var writtenURL: URL?
        do {
            let snapshot = try await context.database.backupSnapshot()
            let createdAt = Date()
            let destination = try ExportFileStore.exportsDirectory().appendingPathComponent(
                ExportFilenameBuilder.filename(kind: .fullBackupArchive, assignmentID: nil,
                                               extension: BackupArchiveService.backupFileExtension, date: createdAt)
            )
            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            let url = try BackupArchiveService.writeFullBackup(
                snapshot: snapshot, storageRoot: context.root, password: password, appVersion: appVersion, to: destination
            )
            writtenURL = url
            try await context.database.recordExport(ExportRecord(
                assignmentID: nil, submissionID: nil, kind: .fullBackupArchive, createdAt: createdAt,
                contentSHA256: try ContentDigest.sha256Hex(fileAt: url),
                includesPrivateTeacherNotes: true,
                includesOriginalSources: snapshot.submissions.contains { !$0.sources.isEmpty }
            ))
            preparedExport = PreparedExport(kind: .fullBackupArchive, url: url, title: "Full Backup")
        } catch {
            if let writtenURL { ExportFileStore.remove(writtenURL) }
            alert = AlertMessage(title: "Backup not created", error: error)
        }
    }

    func finishSharing() {
        if let preparedExport { ExportFileStore.remove(preparedExport.url) }
        preparedExport = nil
    }

    // MARK: - Restore

    /// Opens and verifies the backup and shows what it contains. Nothing local changes.
    func prepareRestore(from url: URL, password: String) async {
        guard let context = requireApp("Restore failed"), !isWorking else { return }
        discardRestore()
        isWorking = true
        defer { isWorking = false }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            preview = try await BackupArchiveService.prepareRestore(
                from: url, password: password, storageRoot: context.root, database: context.database
            )
        } catch {
            alert = AlertMessage(title: "Backup not opened", error: error)
        }
    }

    func setResolution(_ resolution: RestoreResolution, for assignmentID: UUID) {
        resolutions[assignmentID] = resolution
    }

    /// Commits the restore in one transaction, then moves the backup's files into place.
    func commitRestore() async {
        guard let preview, canCommitRestore, let context = requireApp("Restore failed") else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await BackupArchiveService.commitRestore(
                preview, resolutions: resolutions, database: context.database, storageRoot: context.root
            )
            alert = AlertMessage(title: "Restore", message: RestoreOutcome.completeMessage)
        } catch {
            alert = AlertMessage(title: "Restore", error: error)
        }
        self.preview = nil
        resolutions = [:]
    }

    /// Cancels the restore and removes the staged files.
    func discardRestore() {
        if let preview { BackupArchiveService.discard(preview) }
        preview = nil
        resolutions = [:]
    }
}
