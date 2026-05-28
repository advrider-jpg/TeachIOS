import Foundation
import TPPDF

enum PDFExportError: LocalizedError {
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .notImplemented(let detail):
            detail
        }
    }
}

/// PDF export is deferred and not exposed in the UI.
/// Calling any method will throw a not-implemented error without side effects.
struct PDFExportService {
    static func studentReportPDF(for assignment: AssignmentRecord, destination: URL) throws -> URL {
        throw PDFExportError.notImplemented(
            "PDF export is not yet available. Use the Markdown or CSV export options."
        )
    }

    static func teacherAuditPDF(for assignment: AssignmentRecord, destination: URL) throws -> URL {
        throw PDFExportError.notImplemented(
            "PDF export is not yet available. Use the Markdown or CSV export options."
        )
    }
}
