import Foundation

#if os(iOS)
import UIKit
#endif

enum LocalDataProtection {
    static func prepareSensitiveDirectory(_ url: URL, fileManager: FileManager = .default) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        try setExcludedFromBackup(true, for: url)
        applyBestEffortFileProtection(to: url, fileManager: fileManager)
    }

    static func protectSensitiveFile(_ url: URL, fileManager: FileManager = .default) {
        try? setExcludedFromBackup(true, for: url)
        applyBestEffortFileProtection(to: url, fileManager: fileManager)
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

    private static func applyBestEffortFileProtection(to url: URL, fileManager: FileManager) {
        #if os(iOS)
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #endif
    }
}
