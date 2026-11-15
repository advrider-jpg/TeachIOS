import Foundation

/// One structured report. Built once by `ReportBuilder`; `MarkdownRenderer` and `PDFRenderer`
/// both draw from it, so the two formats cannot disagree about content.
struct ReportDocument: Equatable {
    var title: String
    var blocks: [ReportBlock]
}

enum ReportBlock: Equatable {
    case heading(level: Int, text: String)
    case keyValue(label: String, value: String)
    case paragraph(String)
    case bulletList([String])
    /// The student's own words. Rendered verbatim (fenced in Markdown, monospaced in PDF).
    case studentText(String)
}

enum ReportError: LocalizedError, Equatable {
    case notApproved

    var errorDescription: String? {
        switch self {
        case .notApproved:
            return "A student report needs an approved, current final review."
        }
    }
}
