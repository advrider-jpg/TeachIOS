import AppleArchive
import Foundation
import System
import ZIPFoundation

enum BackupArchiveError: LocalizedError {
    case passwordRequired
    case wrongPassword
    case notABackup
    case unreadable(String)
    case duplicateRecords
    case archiveFailed(String)
    /// Any failure before the restore's database transaction committed: nothing local changed.
    case restoreFailedUnchanged(underlying: any Error)
    /// The records were restored, but these source files could not be moved into place or removed.
    case filesIncomplete([String])

    var errorDescription: String? {
        switch self {
        case .passwordRequired:
            return "Choose a password for this backup."
        case .wrongPassword:
            return "That password doesn't open this backup."
        case .notABackup:
            return "This file isn't a MarkForMe backup."
        case .unreadable(let detail):
            return "This backup can't be read: \(detail)"
        case .duplicateRecords:
            return "This backup contains duplicate records and can't be restored."
        case .archiveFailed(let detail):
            return "The archive could not be created: \(detail)"
        case .restoreFailedUnchanged:
            return "Restore failed. Your existing data and files are unchanged."
        case .filesIncomplete(let paths):
            return "Your records were restored, but \(paths.count) original file(s) could not be put in place: \(paths.joined(separator: ", "))"
        }
    }
}

/// Full backups (password-encrypted Apple Archive), restore, and the Teacher Record ZIP.
enum BackupArchiveService {
    static let backupFileExtension = "markformebackup"

    private static let maxRestoreJSONEntryBytes: UInt64 = 50 * 1024 * 1024
    private static let maxRestoreSourceEntryBytes: UInt64 = 100 * 1024 * 1024
    private static let manifestPath = "manifest.json"
    private static let snapshotPath = "snapshot.json"
    private static let archiveSourcesPrefix = "sources/"
    private static let localSourcesPrefix = "Sources/"

    private static var fieldType: ArchiveHeader.FieldKey { ArchiveHeader.FieldKey("TYP") }
    private static var fieldPath: ArchiveHeader.FieldKey { ArchiveHeader.FieldKey("PAT") }
    private static var fieldData: ArchiveHeader.FieldKey { ArchiveHeader.FieldKey("DAT") }

    // MARK: - Full backup

    /// Writes `manifest.json`, `snapshot.json` and every source file (`sources/<submissionID>/<file>`)
    /// into one encrypted archive. A source file that is missing or unsafe fails the backup.
    static func writeFullBackup(
        snapshot: BackupSnapshot,
        storageRoot: URL,
        password: String,
        appVersion: String,
        to destination: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard !password.isEmpty else { throw BackupArchiveError.passwordRequired }

        var files: [(archivePath: String, url: URL)] = []
        var seenPaths: Set<String> = []
        for source in snapshot.submissions.flatMap(\.sources) {
            guard let relative = source.localRelativePath, seenPaths.insert(relative).inserted else { continue }
            guard let url = SourcePathSafety.resolvedLocalSourceURL(relative, applicationSupportDirectory: storageRoot) else {
                throw BackupArchiveError.archiveFailed("A source file has an unsafe location: \(relative).")
            }
            guard fileManager.fileExists(atPath: url.path), !isSymbolicLink(url) else {
                throw BackupArchiveError.archiveFailed("A source file is missing: \(relative).")
            }
            files.append((archivePath(forLocalPath: relative), url))
        }

        var digests: [String: String] = [:]
        for file in files {
            digests[file.archivePath] = try ContentDigest.sha256Hex(fileAt: file.url)
        }
        let manifest = BackupManifest(
            formatVersion: BackupManifest.currentFormatVersion,
            createdAt: Date(),
            appVersion: appVersion,
            sourceSHA256: digests
        )

        try prepareDestination(destination, fileManager: fileManager)
        do {
            let context = ArchiveEncryptionContext(
                profile: .hkdf_sha256_aesctr_hmac__scrypt__none,
                compressionAlgorithm: .lzfse,
                compressionBlockSize: 1_048_576
            )
            try step("setting the password") { try context.setPassword(password) }
            guard let fileStream = ArchiveByteStream.fileStream(
                path: FilePath(destination.path),
                mode: .writeOnly,
                options: [.create, .truncate],
                permissions: FilePermissions(rawValue: 0o600)
            ) else {
                throw BackupArchiveError.archiveFailed("The backup file could not be created.")
            }
            guard let encryptionStream = ArchiveByteStream.encryptionStream(writingTo: fileStream, encryptionContext: context) else {
                try? fileStream.close()
                throw BackupArchiveError.archiveFailed("The backup could not be encrypted.")
            }
            guard let encoder = ArchiveStream.encodeStream(writingTo: encryptionStream) else {
                try? encryptionStream.close()
                try? fileStream.close()
                throw BackupArchiveError.archiveFailed("The backup could not be written.")
            }
            do {
                let manifestData = try jsonEncoder().encode(manifest)
                try step("writing \(manifestPath)") { try writeEntry(manifestPath, data: manifestData, to: encoder) }
                let snapshotData = try jsonEncoder().encode(snapshot)
                try step("writing \(snapshotPath)") { try writeEntry(snapshotPath, data: snapshotData, to: encoder) }
                for file in files {
                    let data = try Data(contentsOf: file.url, options: .mappedIfSafe)
                    try step("writing \(file.archivePath)") { try writeEntry(file.archivePath, data: data, to: encoder) }
                }
            } catch {
                try? encoder.close()
                try? encryptionStream.close()
                try? fileStream.close()
                throw error
            }
            // Closing flushes the last compressed and encrypted blocks; a failure here is a failed backup.
            try step("finishing the archive") { try encoder.close() }
            try step("finishing the encryption") { try encryptionStream.close() }
            try step("closing the backup file") { try fileStream.close() }
        } catch {
            try? fileManager.removeItem(at: destination)
            if let error = error as? BackupArchiveError { throw error }
            throw BackupArchiveError.archiveFailed(error.localizedDescription)
        }
        LocalDataProtection.protectSensitiveFile(destination, fileManager: fileManager)
        return destination
    }

    // MARK: - Restore: read and stage

    /// Opens the backup, reads its entries one at a time (only regular files and directories, only safe
    /// paths, size caps enforced), stages source files in `Application Support/RestoreStaging-<uuid>/`,
    /// verifies every file against the manifest, decodes the snapshot once and rejects duplicate records.
    /// On failure the staging folder is removed.
    static func prepareRestore(
        from archiveURL: URL,
        password: String,
        storageRoot: URL,
        database: AppDatabase,
        fileManager: FileManager = .default
    ) async throws -> RestorePreview {
        let staging = storageRoot.deletingLastPathComponent()
            .appendingPathComponent("RestoreStaging-\(UUID().uuidString)", isDirectory: true)
        do {
            let (manifest, snapshot) = try readAndStage(archiveURL, password: password, staging: staging, fileManager: fileManager)
            let localAssignmentIDs = Set(try await database.assignmentSummaries(inClass: nil).map(\.id))
            return RestorePreview(
                manifest: manifest,
                snapshot: snapshot,
                stagingDirectory: staging,
                conflictingAssignmentIDs: snapshot.assignments.map(\.id).filter { localAssignmentIDs.contains($0) }
            )
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    /// Removes a preview's staging folder (cancel, or after a restore finished).
    static func discard(_ preview: RestorePreview, fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: preview.stagingDirectory)
    }

    private static func readAndStage(
        _ archiveURL: URL,
        password: String,
        staging: URL,
        fileManager: FileManager
    ) throws -> (BackupManifest, BackupSnapshot) {
        guard let fileStream = ArchiveByteStream.fileStream(
            path: FilePath(archiveURL.path),
            mode: .readOnly,
            options: [],
            permissions: FilePermissions(rawValue: 0o600)
        ) else {
            throw BackupArchiveError.unreadable("the file could not be opened.")
        }
        defer { try? fileStream.close() }
        guard let context = ArchiveEncryptionContext(from: fileStream) else { throw BackupArchiveError.notABackup }
        try context.setPassword(password)
        guard let decryptionStream = ArchiveByteStream.decryptionStream(readingFrom: fileStream, encryptionContext: context) else {
            throw BackupArchiveError.wrongPassword
        }
        defer { try? decryptionStream.close() }
        guard let decoder = ArchiveStream.decodeStream(readingFrom: decryptionStream) else {
            throw BackupArchiveError.unreadable("the archive could not be decoded.")
        }
        defer { try? decoder.close() }

        try LocalDataProtection.prepareSensitiveDirectory(staging, fileManager: fileManager)
        var entries = RestoreEntries()
        while let header = try decoder.readHeader() {
            try readEntry(header, from: decoder, into: &entries, staging: staging, fileManager: fileManager)
        }

        let (manifest, snapshot) = try decodeRestoredContents(entries)
        try verifySourceReferences(of: snapshot, stagedDigests: entries.stagedDigests)
        return (manifest, snapshot)
    }

    /// What `readAndStage` has collected so far from the archive's entries.
    private struct RestoreEntries {
        var manifestData: Data?
        var snapshotData: Data?
        var stagedDigests: [String: String] = [:]
    }

    private static func readEntry(
        _ header: ArchiveHeader,
        from decoder: ArchiveStream,
        into entries: inout RestoreEntries,
        staging: URL,
        fileManager: FileManager
    ) throws {
        guard case .string(_, let path)? = header.field(forKey: fieldPath) else {
            throw BackupArchiveError.unreadable("an entry has no name.")
        }
        guard case .uint(_, let typeValue)? = header.field(forKey: fieldType) else {
            throw BackupArchiveError.unreadable("\(path) has no entry type.")
        }
        let entryType = UInt32(truncatingIfNeeded: typeValue)

        if entryType == ArchiveHeader.EntryType.directory.rawValue {
            try validateDirectoryEntry(path)
            return
        }
        guard entryType == ArchiveHeader.EntryType.regularFile.rawValue else {
            throw BackupArchiveError.unreadable("\(path) is not a regular file.")
        }

        switch path {
        case manifestPath, snapshotPath:
            try readJSONEntry(header, path: path, from: decoder, into: &entries)
        default:
            try stageSourceEntry(header, path: path, from: decoder, into: &entries, staging: staging, fileManager: fileManager)
        }
    }

    private static func validateDirectoryEntry(_ path: String) throws {
        guard path == "sources" || path.hasPrefix(archiveSourcesPrefix) else {
            throw BackupArchiveError.unreadable("unexpected folder \(path).")
        }
        if path != "sources" {
            _ = try localPath(forArchivePath: path)
        }
    }

    private static func readJSONEntry(
        _ header: ArchiveHeader,
        path: String,
        from decoder: ArchiveStream,
        into entries: inout RestoreEntries
    ) throws {
        guard (path == manifestPath ? entries.manifestData : entries.snapshotData) == nil else {
            throw BackupArchiveError.unreadable("\(path) appears twice.")
        }
        let data = try readData(of: header, path: path, limit: maxRestoreJSONEntryBytes, from: decoder)
        if path == manifestPath { entries.manifestData = data } else { entries.snapshotData = data }
    }

    private static func stageSourceEntry(
        _ header: ArchiveHeader,
        path: String,
        from decoder: ArchiveStream,
        into entries: inout RestoreEntries,
        staging: URL,
        fileManager: FileManager
    ) throws {
        let local = try localPath(forArchivePath: path)
        guard entries.stagedDigests[path] == nil else {
            throw BackupArchiveError.unreadable("\(path) appears twice.")
        }
        let data = try readData(of: header, path: path, limit: maxRestoreSourceEntryBytes, from: decoder)
        let stagedURL = staging.appendingPathComponent(local, isDirectory: false)
        try LocalDataProtection.prepareSensitiveDirectory(stagedURL.deletingLastPathComponent(), fileManager: fileManager)
        try data.write(to: stagedURL, options: [.withoutOverwriting, .completeFileProtection])
        LocalDataProtection.protectSensitiveFile(stagedURL, fileManager: fileManager)
        entries.stagedDigests[path] = ContentDigest.sha256Hex(data)
    }

    private static func decodeRestoredContents(_ entries: RestoreEntries) throws -> (BackupManifest, BackupSnapshot) {
        guard let manifestData = entries.manifestData, let snapshotData = entries.snapshotData else {
            throw BackupArchiveError.unreadable("the backup is incomplete.")
        }
        let manifest: BackupManifest
        let snapshot: BackupSnapshot
        do {
            manifest = try jsonDecoder().decode(BackupManifest.self, from: manifestData)
            snapshot = try jsonDecoder().decode(BackupSnapshot.self, from: snapshotData)
        } catch {
            throw BackupArchiveError.unreadable(error.localizedDescription)
        }
        guard manifest.formatVersion == BackupManifest.currentFormatVersion else {
            throw BackupArchiveError.unreadable("backup format \(manifest.formatVersion) is not supported.")
        }
        guard manifest.sourceSHA256 == entries.stagedDigests else {
            throw BackupArchiveError.unreadable("its original files don't match the backup's contents list.")
        }
        guard !snapshot.containsDuplicateIDs else { throw BackupArchiveError.duplicateRecords }
        return (manifest, snapshot)
    }

    private static func verifySourceReferences(of snapshot: BackupSnapshot, stagedDigests: [String: String]) throws {
        for graph in snapshot.submissions {
            let folder = localSourcesPrefix + graph.submission.id.uuidString + "/"
            for source in graph.sources {
                guard let path = source.localRelativePath else { continue }
                guard path.hasPrefix(folder), SourcePathSafety.sanitizedLocalSourcePath(path) != nil else {
                    throw BackupArchiveError.unreadable("a file reference is outside its student's folder.")
                }
                guard stagedDigests[archivePath(forLocalPath: path)] != nil else {
                    throw BackupArchiveError.unreadable("the original file \(path) is missing.")
                }
            }
        }
    }

    private static func readData(of header: ArchiveHeader, path: String, limit: UInt64, from decoder: ArchiveStream) throws -> Data {
        guard case .blob(_, let size, _)? = header.field(forKey: fieldData) else { return Data() }
        guard size <= limit else { throw BackupArchiveError.unreadable("\(path) is too large to restore safely.") }
        guard size > 0 else { return Data() }
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(size), alignment: 1)
        defer { buffer.deallocate() }
        try decoder.readBlob(key: fieldData, into: buffer)
        return Data(buffer)
    }

    // MARK: - Restore: commit

    /// Commits the restore's database transaction; only after it commits are the staged files moved into
    /// place with `FileManager.replaceItemAt`. A failure before the commit removes only the staging folder
    /// and throws `restoreFailedUnchanged`. `failBeforeCommit` is a test hook passed to `AppDatabase.restore`.
    static func commitRestore(
        _ preview: RestorePreview,
        resolutions: [UUID: RestoreResolution],
        database: AppDatabase,
        storageRoot: URL,
        fileManager: FileManager = .default,
        failBeforeCommit: Bool = false
    ) async throws -> RestoreOutcome {
        let outcome: RestoreOutcome
        do {
            outcome = try await database.restore(preview.snapshot, resolutions: resolutions, failBeforeCommit: failBeforeCommit)
        } catch {
            discard(preview, fileManager: fileManager)
            throw BackupArchiveError.restoreFailedUnchanged(underlying: error)
        }

        var incomplete: [String] = []
        for move in outcome.sourceFileMoves {
            let staged = preview.stagingDirectory.appendingPathComponent(move.stagedRelativePath, isDirectory: false)
            guard let destination = SourcePathSafety.resolvedLocalSourceURL(
                move.destinationRelativePath, applicationSupportDirectory: storageRoot
            ) else {
                incomplete.append(move.destinationRelativePath)
                continue
            }
            do {
                try LocalDataProtection.prepareSensitiveDirectory(destination.deletingLastPathComponent(), fileManager: fileManager)
                if fileManager.fileExists(atPath: destination.path) {
                    _ = try fileManager.replaceItemAt(destination, withItemAt: staged, backupItemName: nil, options: [])
                } else {
                    try fileManager.moveItem(at: staged, to: destination)
                }
                LocalDataProtection.protectSensitiveFile(destination, fileManager: fileManager)
            } catch {
                incomplete.append(move.destinationRelativePath)
            }
        }
        for path in outcome.obsoleteLocalFilePaths {
            guard let url = SourcePathSafety.resolvedLocalSourceURL(path, applicationSupportDirectory: storageRoot),
                  fileManager.fileExists(atPath: url.path) else { continue }
            do {
                try fileManager.removeItem(at: url)
            } catch {
                incomplete.append(path)
            }
        }
        discard(preview, fileManager: fileManager)
        guard incomplete.isEmpty else { throw BackupArchiveError.filesIncomplete(incomplete) }
        return outcome
    }

    // MARK: - Teacher Record archive

    /// A plain ZIP (opens on school PCs): `snapshot.json`, the already-rendered report files, and `sources/`.
    static func writeTeacherRecordArchive(
        snapshot: BackupSnapshot,
        reportFiles: [(name: String, data: Data)],
        sourceFiles: [URL],
        to destination: URL
    ) throws -> URL {
        let fileManager = FileManager.default
        for url in sourceFiles {
            guard fileManager.fileExists(atPath: url.path), !isSymbolicLink(url) else {
                throw BackupArchiveError.archiveFailed("A source file is missing: \(url.lastPathComponent).")
            }
        }
        try prepareDestination(destination, fileManager: fileManager)
        do {
            let archive = try Archive(url: destination, accessMode: .create)
            var usedNames: Set<String> = []
            try addEntry(uniqueArchivePath(snapshotPath, usedNames: &usedNames), data: try jsonEncoder().encode(snapshot), to: archive)
            for report in reportFiles {
                try addEntry(uniqueArchivePath(report.name, usedNames: &usedNames), data: report.data, to: archive)
            }
            for url in sourceFiles {
                try archive.addEntry(
                    with: sourceArchivePath(for: url, usedNames: &usedNames),
                    fileURL: url,
                    compressionMethod: .deflate
                )
            }
        } catch {
            try? fileManager.removeItem(at: destination)
            throw BackupArchiveError.archiveFailed(error.localizedDescription)
        }
        LocalDataProtection.protectSensitiveFile(destination, fileManager: fileManager)
        return destination
    }

    private static func addEntry(_ path: String, data: Data, to archive: Archive) throws {
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            compressionMethod: .deflate,
            provider: { position, size in
                let start = Int(position)
                return data.subdata(in: start..<(start + size))
            }
        )
    }

    // MARK: - Helpers

    /// Runs one archive step; an Apple Archive error names the step that failed.
    private static func step(_ name: String, _ body: () throws -> Void) throws {
        do {
            try body()
        } catch let error as BackupArchiveError {
            throw error
        } catch {
            throw BackupArchiveError.archiveFailed("Failed while \(name): \(error.localizedDescription)")
        }
    }

    private static func writeEntry(_ path: String, data: Data, to encoder: ArchiveStream) throws {
        let header = ArchiveHeader()
        header.append(.string(key: fieldPath, value: path))
        header.append(.uint(key: fieldType, value: UInt64(ArchiveHeader.EntryType.regularFile.rawValue)))
        header.append(.blob(key: fieldData, size: UInt64(data.count)))
        try encoder.writeHeader(header)
        try data.withUnsafeBytes { buffer in
            try encoder.writeBlob(key: fieldData, from: buffer)
        }
    }

    /// `Sources/<submissionID>/<file>` → `sources/<submissionID>/<file>`.
    private static func archivePath(forLocalPath localPath: String) -> String {
        archiveSourcesPrefix + localPath.dropFirst(localSourcesPrefix.count)
    }

    /// `sources/<submissionID>/<file>` → `Sources/<submissionID>/<file>`, rejected unless it passes `SourcePathSafety`.
    private static func localPath(forArchivePath archivePath: String) throws -> String {
        guard archivePath.hasPrefix(archiveSourcesPrefix) else {
            throw BackupArchiveError.unreadable("unexpected entry \(archivePath).")
        }
        let local = localSourcesPrefix + archivePath.dropFirst(archiveSourcesPrefix.count)
        guard let safe = SourcePathSafety.sanitizedLocalSourcePath(local) else {
            throw BackupArchiveError.unreadable("unsafe entry path \(archivePath).")
        }
        return safe
    }

    private static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func prepareDestination(_ destination: URL, fileManager: FileManager) throws {
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
    }

    private static func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
    }

    private static func safeArchivePath(_ name: String) -> String {
        let components = name.replacingOccurrences(of: "\\", with: "_")
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
        if sanitized.isEmpty || sanitized == "." { return "_" }
        return sanitized
    }

    private static func sourceArchivePath(for sourceURL: URL, usedNames: inout Set<String>) -> String {
        let path = sourceURL.standardizedFileURL.path
        let base: String
        if let range = path.range(of: "/Sources/") {
            base = archiveSourcesPrefix + path[range.upperBound...]
        } else {
            let digest = ContentDigest.sha256Hex(path).prefix(12)
            base = archiveSourcesPrefix + "imported/\(digest)-\(sourceURL.lastPathComponent)"
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
        let ext = (fileName as NSString).pathExtension
        let stem = ext.isEmpty ? fileName : (fileName as NSString).deletingPathExtension
        var counter = 2
        while true {
            let name = ext.isEmpty ? "\(stem)-\(counter)" : "\(stem)-\(counter).\(ext)"
            let candidate = directory.isEmpty ? name : "\(directory)/\(name)"
            if usedNames.insert(candidate).inserted { return candidate }
            counter += 1
        }
    }
}

enum SourcePathSafety {
    static func sanitizedLocalSourcePath(_ path: String?) -> String? {
        guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard !path.hasPrefix("/") else { return nil }
        guard !path.contains("\\") else { return nil }
        guard path.hasPrefix("Sources/") else { return nil }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { return nil }
        return path
    }

    static func resolvedLocalSourceURL(_ path: String?, applicationSupportDirectory: URL) -> URL? {
        guard let relativePath = sanitizedLocalSourcePath(path) else { return nil }
        let root = applicationSupportDirectory.standardizedFileURL.resolvingSymlinksInPath()
        let url = root.appendingPathComponent(relativePath, isDirectory: false).standardizedFileURL
        let resolved = url.resolvingSymlinksInPath()
        guard resolved.path == root.path || resolved.path.hasPrefix(root.path + "/") else { return nil }
        return resolved
    }
}
