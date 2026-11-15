import Foundation

enum ExportFilenameBuilder {
    static func filename(kind: ExportKind, assignmentID: UUID?, extension ext: String, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: date)
        let idToken = assignmentID.map { String($0.uuidString.prefix(8)) } ?? String(UUID().uuidString.prefix(8))
        return "MarkForMe-\(kind.safeFilenameToken)-\(stamp)-\(idToken).\(ext)"
    }
}

extension ExportKind {
    var safeFilenameToken: String {
        switch self {
        case .studentMarkdown: return "StudentReport"
        case .teacherAuditMarkdown: return "TeacherAudit"
        case .studentPDF: return "StudentPDF"
        case .teacherAuditPDF: return "TeacherAuditPDF"
        case .csvGradebook: return "GradebookCSV"
        case .zipArchive: return "TeacherArchive"
        case .fullBackupArchive: return "FullBackup"
        }
    }
}

/// Every export file is protected with `FileProtectionType.complete`: it can only be read while
/// the device is unlocked. `ExportFileStore` applies that when it writes the file; the archive
/// writers use this helper, which sets the same protection through `LocalDataProtection`.
enum ExportFileHardening {
    static func applyBestEffortProtection(to url: URL) {
        LocalDataProtection.protectSensitiveFile(url)
    }
}

/// The one place export files live: `tmp/Exports/`. A prepared file is removed when the share
/// sheet finishes or a new export is prepared, and the folder is emptied at launch.
enum ExportFileStore {
    static func exportsDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        return directory
    }

    static func write(_ data: Data, fileName: String) throws -> URL {
        let url = try exportsDirectory().appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    /// Deleting a finished export is cleanup: a leftover file is emptied by `purgeAll()` at the next launch.
    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func purgeAll() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
    }
}
