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
        return "GradeDraft-\(kind.safeFilenameToken)-\(stamp)-\(idToken).\(ext)"
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
        case .backupJSON: return "BackupJSON"
        }
    }
}

enum ExportFileHardening {
    static func applyBestEffortProtection(to url: URL) {
        try? (url as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
        #if os(iOS)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #endif
    }
}
