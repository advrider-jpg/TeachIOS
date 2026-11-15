import Foundation

/// File protection for local student data.
/// - Source images, original PDFs and exports: `FileProtectionType.complete` (readable only while the
///   device is unlocked) via `protectSensitiveFile`.
/// - The database, its WAL and SHM files, and the folders that hold local data:
///   `completeUntilFirstUserAuthentication`, so saved work stays usable while the app runs in the background.
/// Saved work is excluded from iPhone/iCloud device backup by default; the full backup is the teacher's copy.
/// The teacher can include it (`setDeviceBackupIncluded`). The setting lives in the files' own
/// `isExcludedFromBackup` flags (the storage folder, the database, its WAL and SHM files and `Sources/`),
/// so the files are the only record of it: everything written later under `Sources/` inherits the
/// folder's flag, and nothing here resets a flag the teacher changed.
enum LocalDataProtection {
    /// The folder under the storage folder that holds `Sources/<submissionID>/` files.
    static let sourcesFolderName = "Sources"

    /// Creates the folder if needed and sets its file protection. A folder this call creates starts excluded
    /// from device backup, except inside `Sources/`, which inherits the `Sources/` flag.
    static func prepareSensitiveDirectory(_ url: URL, fileManager: FileManager = .default) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            if !isInsideSources(url) {
                try setExcludedFromBackup(true, for: url)
            }
        }
        try setProtection(.completeUntilFirstUserAuthentication, for: url, fileManager: fileManager)
    }

    /// For source images, original PDFs and export files. A file inside `Sources/` follows the `Sources/` flag.
    static func protectSensitiveFile(_ url: URL, fileManager: FileManager = .default) {
        if !isInsideSources(url) {
            try? setExcludedFromBackup(true, for: url)
        }
        try? setProtection(.complete, for: url, fileManager: fileManager)
    }

    /// For the database file and its WAL and SHM files. Backup exclusion is the device-backup setting's.
    static func protectDatabaseFile(_ url: URL, fileManager: FileManager = .default) throws {
        try setProtection(.completeUntilFirstUserAuthentication, for: url, fileManager: fileManager)
    }

    // MARK: - Device backup setting

    /// The files whose flags make up the device-backup setting: the storage folder (a folder's flag
    /// covers everything in it, so it must agree), the database, its WAL and SHM files, and `Sources/`.
    private static func deviceBackupURLs(storageRoot: URL, databaseFileName: String, fileManager: FileManager) -> [URL] {
        var urls = [storageRoot]
        let candidates = [sourcesFolderName, databaseFileName, databaseFileName + "-wal", databaseFileName + "-shm"]
        for name in candidates {
            let url = storageRoot.appendingPathComponent(name)
            if fileManager.fileExists(atPath: url.path) { urls.append(url) }
        }
        return urls
    }

    /// Includes the saved work in device backup (`true`) or excludes it (`false`) by setting the flag on every
    /// file in `deviceBackupURLs`. Creates `Sources/` first if it does not exist yet, so later imports inherit it.
    static func setDeviceBackupIncluded(
        _ included: Bool,
        storageRoot: URL,
        databaseFileName: String = AppDatabase.databaseFileName,
        fileManager: FileManager = .default
    ) throws {
        let sources = storageRoot.appendingPathComponent(sourcesFolderName, isDirectory: true)
        if !fileManager.fileExists(atPath: sources.path) {
            try fileManager.createDirectory(at: sources, withIntermediateDirectories: true)
            try setProtection(.completeUntilFirstUserAuthentication, for: sources, fileManager: fileManager)
        }
        for url in deviceBackupURLs(storageRoot: storageRoot, databaseFileName: databaseFileName, fileManager: fileManager) {
            try setExcludedFromBackup(!included, for: url)
        }
    }

    /// What the files say: `true` when none is excluded, `false` when all are, nil when the platform reports no
    /// value, a file cannot be read, or the flags disagree (for example, a change that stopped part-way).
    static func deviceBackupIncluded(
        storageRoot: URL,
        databaseFileName: String = AppDatabase.databaseFileName,
        fileManager: FileManager = .default
    ) -> Bool? {
        var excludedCount = 0
        let urls = deviceBackupURLs(storageRoot: storageRoot, databaseFileName: databaseFileName, fileManager: fileManager)
        for url in urls {
            guard let excluded = try? isExcludedFromBackup(url) else { return nil }
            if excluded { excludedCount += 1 }
        }
        if excludedCount == 0 { return true }
        return excludedCount == urls.count ? false : nil
    }

    private static func isInsideSources(_ url: URL) -> Bool {
        url.pathComponents.contains(sourcesFolderName)
    }

    static func setExcludedFromBackup(_ excluded: Bool, for url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = excluded
        try mutableURL.setResourceValues(values)
    }

    static func isExcludedFromBackup(_ url: URL) throws -> Bool? {
        try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup
    }

    private static func setProtection(_ protection: FileProtectionType, for url: URL, fileManager: FileManager) throws {
        #if os(iOS)
        try fileManager.setAttributes([.protectionKey: protection], ofItemAtPath: url.path)
        #endif
    }
}
