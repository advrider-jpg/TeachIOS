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

struct PDFExportService {
    static func studentReportPDF(for assignment: AssignmentRecord, destination: URL) throws -> URL {
        throw PDFExportError.notImplemented(
            "Student PDF export is not yet implemented with TPPDF in this pass; use stub failure handling."
        )
    }

    static func teacherAuditPDF(for assignment: AssignmentRecord, destination: URL) throws -> URL {
        throw PDFExportError.notImplemented(
            "Teacher audit PDF export is not yet implemented with TPPDF in this pass; use stub failure handling."
        )
    }
}
