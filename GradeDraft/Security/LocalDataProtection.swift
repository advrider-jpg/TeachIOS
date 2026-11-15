import Foundation

/// File protection for local student data.
/// - Source images, original PDFs and exports: `FileProtectionType.complete` (readable only while the
///   device is unlocked) via `protectSensitiveFile`.
/// - The database, its WAL and SHM files, and the folders that hold local data:
///   `completeUntilFirstUserAuthentication`, so saved work stays usable while the app runs in the background.
/// Everything here is also excluded from iPhone/iCloud device backup; the full backup is the teacher's copy.
enum LocalDataProtection {
    static func prepareSensitiveDirectory(_ url: URL, fileManager: FileManager = .default) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        try setExcludedFromBackup(true, for: url)
        try setProtection(.completeUntilFirstUserAuthentication, for: url, fileManager: fileManager)
    }

    /// For source images, original PDFs and export files.
    static func protectSensitiveFile(_ url: URL, fileManager: FileManager = .default) {
        try? setExcludedFromBackup(true, for: url)
        try? setProtection(.complete, for: url, fileManager: fileManager)
    }

    /// For the database file and its WAL and SHM files.
    static func protectDatabaseFile(_ url: URL, fileManager: FileManager = .default) throws {
        try setExcludedFromBackup(true, for: url)
        try setProtection(.completeUntilFirstUserAuthentication, for: url, fileManager: fileManager)
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
