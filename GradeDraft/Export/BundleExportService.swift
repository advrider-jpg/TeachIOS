import Foundation
import ZIPFoundation

enum BundleExportError: LocalizedError {
    case preflightFailed(String)
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .preflightFailed(let detail):
            "Bundle export preflight failed: \(detail)"
        case .notImplemented(let detail):
            detail
        }
    }
}

/// ZIP/archive bundle export is deferred and not exposed in the UI.
/// Calling any method will throw a not-implemented error without leaving artifacts.
struct BundleExportService {
    static func preflightDestination(for assignmentID: UUID) throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = documents.appendingPathComponent(".gradedraft", isDirectory: true)
        let destination = root.appendingPathComponent("\(assignmentID.uuidString).gradedraft", isDirectory: false)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return destination
    }

    static func writeBundle(
        assignment: AssignmentRecord,
        sourceFiles: [URL],
        to destination: URL
    ) throws -> URL {
        throw BundleExportError.notImplemented(
            "ZIP archive export is not yet available. Use the Markdown or CSV export options."
        )
    }
}
