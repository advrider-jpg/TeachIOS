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
        _ = try preflightBundle(
            sourceFiles: sourceFiles,
            destination: destination
        )
        throw BundleExportError.notImplemented(
            "Bundle export staging with ZIPFoundation is not fully implemented in this pass."
        )
    }

    private static func preflightBundle(sourceFiles: [URL], destination: URL) throws -> URL {
        guard !sourceFiles.isEmpty else {
            throw BundleExportError.preflightFailed("No source files were provided for the bundle.")
        }

        _ = try Archive(url: destination, accessMode: .create)
        return destination
    }
}
