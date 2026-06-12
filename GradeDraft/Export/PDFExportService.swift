import Foundation
import TPPDF
import UIKit

enum PDFExportError: LocalizedError {
    case renderFailed(String)

    var errorDescription: String? {
        switch self {
        case .renderFailed(let detail):
            return detail
        }
    }
}

/// Local PDF export for student-facing and teacher-review reports.
///
/// Reports are rendered with TPPDF for real typographic hierarchy (headings, inline
/// emphasis, block quotes, indented lists), repeating page header/footer, page numbers,
/// and automatic pagination. The rich renderer is wrapped by a conservative
/// `UIGraphicsPDFRenderer` fallback so a report is always produced even if the rich
/// layout pass fails for an unusual input. The output is fully local: it never uploads,
/// fetches, or renders remote content.
struct PDFExportService {
    static func studentReportPDF(for assignment: AssignmentRecord, destination: URL) throws -> URL {
        try writePDF(
            title: "MarkForMe Student Report",
            markdown: MarkdownReportBuilder.studentMarkdown(for: assignment),
            destination: destination
        )
    }

    static func teacherAuditPDF(for assignment: AssignmentRecord, destination: URL) throws -> URL {
        try writePDF(
            title: "MarkForMe Teacher Record",
            markdown: MarkdownReportBuilder.teacherAuditMarkdown(for: assignment),
            destination: destination
        )
    }

    private static func writePDF(title: String, markdown: String, destination: URL) throws -> URL {
        let directory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        do {
            let data = try renderStyledPDFData(title: title, markdown: markdown)
            guard !data.isEmpty else {
                throw PDFExportError.renderFailed("The styled PDF renderer produced no data.")
            }
            try data.write(to: destination, options: [.atomic])
        } catch {
            // Robustness: never fail a teacher export because the rich layout pass
            // could not lay out an unusual report. Fall back to the plain renderer.
            try renderPlainPDF(title: title, markdown: markdown, destination: destination)
        }

        ExportFileHardening.applyBestEffortProtection(to: destination)
        return destination
    }

    // MARK: - Rich renderer (TPPDF)

    private static func renderStyledPDFData(title: String, markdown: String) throws -> Data {
        let document = PDFDocument(format: .usLetter)
        document.add(.headerLeft, attributedText: chromeText(title))
        document.add(.footerLeft, attributedText: chromeText("MarkForMe · local export"))
        document.pagination = PDFPagination(container: .footerRight)

        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        var renderedAnyContent = false
        for rawLine in lines {
            guard let block = styledBlock(for: rawLine) else {
                document.add(space: 4) // Preserve blank-line breathing room.
                continue
            }
            document.add(attributedText: block.text)
            document.add(space: block.spacingAfter)
            renderedAnyContent = true
        }

        guard renderedAnyContent else {
            throw PDFExportError.renderFailed("The report contained no renderable content.")
        }

        let generator = PDFGenerator(document: document)
        do {
            return try generator.generateData()
        } catch {
            throw PDFExportError.renderFailed("Could not render styled PDF: \(error.localizedDescription)")
        }
    }

    private struct StyledBlock {
        var text: NSAttributedString
        var spacingAfter: CGFloat
    }

    private static func styledBlock(for rawLine: String) -> StyledBlock? {
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Heading levels.
        if let heading = headingLevel(of: trimmed) {
            let content = String(trimmed.drop(while: { $0 == "#" })).trimmingCharacters(in: .whitespaces)
            let font: UIFont
            let spacingBefore: CGFloat
            switch heading {
            case 1: font = .systemFont(ofSize: 24, weight: .bold); spacingBefore = 2
            case 2: font = .systemFont(ofSize: 18, weight: .bold); spacingBefore = 10
            case 3: font = .systemFont(ofSize: 15, weight: .semibold); spacingBefore = 8
            default: font = .systemFont(ofSize: 13, weight: .semibold); spacingBefore = 6
            }
            let paragraph = NSMutableParagraphStyle()
            paragraph.paragraphSpacingBefore = spacingBefore
            paragraph.paragraphSpacing = 2
            let attributed = NSMutableAttributedString()
            appendInlineRuns(content, baseFont: font, color: .label, paragraph: paragraph, into: attributed)
            return StyledBlock(text: attributed, spacingAfter: 4)
        }

        // Block quote / callout.
        if trimmed.hasPrefix(">") {
            let content = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            let paragraph = NSMutableParagraphStyle()
            paragraph.firstLineHeadIndent = 12
            paragraph.headIndent = 12
            paragraph.paragraphSpacing = 2
            let attributed = NSMutableAttributedString()
            appendInlineRuns(
                content,
                baseFont: .italicSystemFont(ofSize: 10.5),
                color: .secondaryLabel,
                paragraph: paragraph,
                into: attributed
            )
            return StyledBlock(text: attributed, spacingAfter: 5)
        }

        // List items (one level of nesting via a leading "  - ").
        if let bullet = bulletContent(of: rawLine) {
            let paragraph = NSMutableParagraphStyle()
            let indent: CGFloat = bullet.nested ? 30 : 16
            paragraph.firstLineHeadIndent = indent
            paragraph.headIndent = indent + 10
            paragraph.paragraphSpacing = 1
            let attributed = NSMutableAttributedString()
            let marker = bullet.nested ? "◦  " : "•  "
            attributed.append(NSAttributedString(
                string: marker,
                attributes: [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.secondaryLabel, .paragraphStyle: paragraph]
            ))
            appendInlineRuns(bullet.content, baseFont: .systemFont(ofSize: 11), color: .label, paragraph: paragraph, into: attributed)
            return StyledBlock(text: attributed, spacingAfter: 2)
        }

        // Body paragraph.
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 2
        paragraph.lineSpacing = 1
        let attributed = NSMutableAttributedString()
        appendInlineRuns(trimmed, baseFont: .systemFont(ofSize: 11), color: .label, paragraph: paragraph, into: attributed)
        return StyledBlock(text: attributed, spacingAfter: 3)
    }

    private static func headingLevel(of line: String) -> Int? {
        guard line.hasPrefix("#") else { return nil }
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard hashes >= 1, hashes <= 6 else { return nil }
        // A heading marker must be followed by a space, e.g. "## Title".
        let remainder = line.dropFirst(hashes)
        guard remainder.first == " " else { return nil }
        return min(hashes, 4)
    }

    private static func bulletContent(of rawLine: String) -> (content: String, nested: Bool)? {
        let nested = rawLine.hasPrefix("  - ") || rawLine.hasPrefix("    - ")
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("- ") else { return nil }
        return (String(trimmed.dropFirst(2)), nested)
    }

    /// Splits `**bold**` runs out of a line and appends styled runs to `target`.
    private static func appendInlineRuns(
        _ text: String,
        baseFont: UIFont,
        color: UIColor,
        paragraph: NSParagraphStyle,
        into target: NSMutableAttributedString
    ) {
        let segments = text.components(separatedBy: "**")
        for (index, segment) in segments.enumerated() where !segment.isEmpty {
            let isBold = index % 2 == 1 // Odd segments sit between ** markers.
            let font = isBold ? boldVariant(of: baseFont) : baseFont
            target.append(NSAttributedString(
                string: segment,
                attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
            ))
        }
        // Guard against a line that was only "**" markers.
        if target.length == 0 {
            target.append(NSAttributedString(
                string: text,
                attributes: [.font: baseFont, .foregroundColor: color, .paragraphStyle: paragraph]
            ))
        }
    }

    private static func boldVariant(of font: UIFont) -> UIFont {
        let traits = font.fontDescriptor.symbolicTraits.union(.traitBold)
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else {
            return UIFont.boldSystemFont(ofSize: font.pointSize)
        }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    private static func chromeText(_ value: String) -> NSAttributedString {
        NSAttributedString(
            string: value,
            attributes: [
                .font: UIFont.systemFont(ofSize: 8, weight: .regular),
                .foregroundColor: UIColor.tertiaryLabel
            ]
        )
    }

    // MARK: - Plain fallback renderer (UIKit)

    /// Conservative single-font renderer retained as a robustness fallback.
    private static func renderPlainPDF(title: String, markdown: String, destination: URL) throws {
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

        let normalizedLines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        do {
            try renderer.writePDF(to: destination) { context in
                var pageNumber = 0
                func beginPage() -> CGFloat {
                    pageNumber += 1
                    context.beginPage()
                    title.draw(in: CGRect(x: margin, y: margin, width: contentWidth, height: 34), withAttributes: titleAttributes)
                    let footer = "MarkForMe local export · Page \(pageNumber)"
                    footer.draw(
                        in: CGRect(x: margin, y: pageBounds.height - margin + 12, width: contentWidth, height: 18),
                        withAttributes: footerAttributes
                    )
                    return margin + 48
                }

                var cursorY = beginPage()
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
                    if cursorY + height > bottomLimit {
                        cursorY = beginPage()
                    }
                    (text as NSString).draw(
                        with: CGRect(x: margin, y: cursorY, width: contentWidth, height: height),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: bodyAttributes,
                        context: nil
                    )
                    cursorY += height
                }
            }
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
