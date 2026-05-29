import Foundation
import TPPDF
import UIKit

enum PDFExportError: LocalizedError {
    case renderFailed(String)

    var errorDescription: String? {
        switch self {
        case .renderFailed(let detail):
            detail
        }
    }
}

/// Plain, local PDF export for student-facing and teacher-audit reports.
/// The output is intentionally conservative: system font, page numbers, and text derived
/// from the existing Markdown report builders. It does not upload, fetch, or render remote content.
struct PDFExportService {
    static func studentReportPDF(for assignment: AssignmentRecord, destination: URL) throws -> URL {
        try writePDF(
            title: "GradeDraft Student Feedback",
            body: MarkdownReportBuilder.studentMarkdown(for: assignment),
            destination: destination
        )
    }

    static func teacherAuditPDF(for assignment: AssignmentRecord, destination: URL) throws -> URL {
        try writePDF(
            title: "GradeDraft Teacher Audit Report",
            body: MarkdownReportBuilder.teacherAuditMarkdown(for: assignment),
            destination: destination
        )
    }

    private static func writePDF(title: String, body: String, destination: URL) throws -> URL {
        let directory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter points.
        let margin: CGFloat = 48
        let contentWidth = pageBounds.width - (margin * 2)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .title2),
            .foregroundColor: UIColor.label
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label
        ]
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: UIColor.secondaryLabel
        ]

        let normalizedLines = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        do {
            try renderer.writePDF(to: destination) { context in
                var pageNumber = 0
                func beginPage() -> CGFloat {
                    pageNumber += 1
                    context.beginPage()
                    title.draw(in: CGRect(x: margin, y: margin, width: contentWidth, height: 34), withAttributes: titleAttributes)
                    let footer = "GradeDraft local export · Page \(pageNumber)"
                    footer.draw(
                        in: CGRect(x: margin, y: pageBounds.height - margin + 12, width: contentWidth, height: 18),
                        withAttributes: footerAttributes
                    )
                    return margin + 48
                }

                var y = beginPage()
                let lineHeight: CGFloat = 18
                let bottomLimit = pageBounds.height - margin

                for rawLine in normalizedLines {
                    let line = markdownStripped(rawLine)
                    let text = line.isEmpty ? " " : line
                    let bounding = (text as NSString).boundingRect(
                        with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: bodyAttributes,
                        context: nil
                    )
                    let height = max(lineHeight, ceil(bounding.height) + 4)
                    if y + height > bottomLimit {
                        y = beginPage()
                    }
                    (text as NSString).draw(
                        with: CGRect(x: margin, y: y, width: contentWidth, height: height),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: bodyAttributes,
                        context: nil
                    )
                    y += height
                }
            }
            return destination
        } catch {
            throw PDFExportError.renderFailed("Could not create PDF export: \(error.localizedDescription)")
        }
    }

    private static func markdownStripped(_ line: String) -> String {
        var value = line
        while value.hasPrefix("#") { value.removeFirst() }
        value = value.replacingOccurrences(of: "**", with: "")
        value = value.replacingOccurrences(of: "__", with: "")
        value = value.replacingOccurrences(of: "> ", with: "")
        return value.trimmingCharacters(in: .whitespaces)
    }
}
