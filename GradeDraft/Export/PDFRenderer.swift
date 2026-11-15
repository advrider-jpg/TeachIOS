import Foundation
import UIKit

struct PDFRenderError: LocalizedError, Equatable {
    var detail: String
    var errorDescription: String? { "The PDF could not be created: \(detail)" }
}

/// Draws a `ReportDocument` as an A4 PDF using only Apple frameworks. There is no second renderer:
/// if layout or writing fails, the error goes to the screen.
enum PDFRenderer {
    static let paperRect = CGRect(x: 0, y: 0, width: 595, height: 842)
    static let margin: CGFloat = 48

    static func render(_ document: ReportDocument) throws -> Data {
        var result: Result<Data, PDFRenderError> = .failure(PDFRenderError(detail: "rendering did not run"))
        // Fixed black text on white paper, whatever the device appearance.
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            result = renderPages(document)
        }
        return try result.get()
    }

    private static func renderPages(_ document: ReportDocument) -> Result<Data, PDFRenderError> {
        let formatter = UISimpleTextPrintFormatter(attributedText: attributedText(for: document))
        let pageRenderer = ReportPageRenderer(title: document.title)
        pageRenderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        let pageCount = pageRenderer.numberOfPages
        guard pageCount > 0 else {
            return .failure(PDFRenderError(detail: "the report produced no pages"))
        }

        let data = UIGraphicsPDFRenderer(bounds: paperRect).pdfData { context in
            pageRenderer.prepare(forDrawingPages: NSRange(location: 0, length: pageCount))
            for index in 0..<pageCount {
                context.beginPage()
                pageRenderer.drawPage(at: index, in: context.pdfContextBounds)
            }
        }
        guard !data.isEmpty else {
            return .failure(PDFRenderError(detail: "the PDF file was empty"))
        }
        return .success(data)
    }

    // MARK: - Text

    private static let titleFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
    private static let headingFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
    private static let bodyFont = UIFont.systemFont(ofSize: 11)
    private static let studentFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)

    private static func attributedText(for document: ReportDocument) -> NSAttributedString {
        let output = NSMutableAttributedString()

        func append(_ text: String, font: UIFont, style: NSParagraphStyle) {
            output.append(NSAttributedString(
                string: text + "\n",
                attributes: [.font: font, .foregroundColor: UIColor.black, .paragraphStyle: style]
            ))
        }

        func style(before: CGFloat = 0, after: CGFloat = 6, headIndent: CGFloat = 0, firstLineIndent: CGFloat = 0) -> NSParagraphStyle {
            let paragraph = NSMutableParagraphStyle()
            paragraph.paragraphSpacingBefore = before
            paragraph.paragraphSpacing = after
            paragraph.headIndent = headIndent
            paragraph.firstLineHeadIndent = firstLineIndent
            if headIndent > 0 {
                paragraph.tabStops = [NSTextTab(textAlignment: .left, location: headIndent)]
            }
            return paragraph
        }

        append(document.title, font: titleFont, style: style(after: 10))
        for block in document.blocks {
            switch block {
            case .heading(_, let text):
                append(text, font: headingFont, style: style(before: 10, after: 4))
            case .keyValue(let label, let value):
                append("\(label): \(value)", font: bodyFont, style: style(after: 2))
            case .paragraph(let text):
                append(text, font: bodyFont, style: style())
            case .bulletList(let items):
                for item in items {
                    append("\u{2022}\t\(item)", font: bodyFont, style: style(after: 2, headIndent: 14))
                }
            case .studentText(let text):
                append(text, font: studentFont, style: style())
            }
        }
        return output
    }
}

/// Lays the report out on A4 with the title in the header and "Page n of m" in the footer.
private final class ReportPageRenderer: UIPrintPageRenderer {
    private let title: String

    init(title: String) {
        self.title = title
        super.init()
        headerHeight = 24
        footerHeight = 24
    }

    override var paperRect: CGRect { PDFRenderer.paperRect }

    override var printableRect: CGRect {
        PDFRenderer.paperRect.insetBy(dx: PDFRenderer.margin, dy: PDFRenderer.margin)
    }

    override func drawHeaderForPage(at pageIndex: Int, in headerRect: CGRect) {
        draw(title, in: headerRect, alignment: .left)
    }

    override func drawFooterForPage(at pageIndex: Int, in footerRect: CGRect) {
        draw("Page \(pageIndex + 1) of \(numberOfPages)", in: footerRect, alignment: .right)
    }

    private func draw(_ text: String, in rect: CGRect, alignment: NSTextAlignment) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: rect, withAttributes: [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ])
    }
}
