import Foundation

/// Writes a `ReportDocument` as Markdown. All report text is escaped so that student or teacher
/// words can never turn into headings, lists, quotes or emphasis; the student's own text is
/// written inside a fenced block instead.
enum MarkdownRenderer {
    static func render(_ document: ReportDocument) -> String {
        var parts: [String] = ["# " + escaped(document.title)]
        for block in document.blocks {
            switch block {
            case .heading(let level, let text):
                parts.append(String(repeating: "#", count: min(max(level, 1), 6)) + " " + escaped(text))
            case .keyValue(let label, let value):
                parts.append("**\(escaped(label)):** \(escaped(value))")
            case .paragraph(let text):
                parts.append(escaped(text))
            case .bulletList(let items):
                parts.append(items.map(bullet).joined(separator: "\n"))
            case .studentText(let text):
                parts.append(fenced(text))
            }
        }
        return parts.joined(separator: "\n\n") + "\n"
    }

    private static func bullet(_ item: String) -> String {
        let lines = normalizedLines(item).map(escapedLine)
        return "- " + lines.joined(separator: "\n  ")
    }

    private static func fenced(_ text: String) -> String {
        let safe = normalizedLines(text).joined(separator: "\n").replacingOccurrences(of: "```", with: "``\u{200B}`")
        return "```text\n\(safe)\n```"
    }

    /// Escapes a block of text line by line.
    static func escaped(_ text: String) -> String {
        normalizedLines(text).map(escapedLine).joined(separator: "\n")
    }

    private static func normalizedLines(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
    }

    private static func escapedLine(_ line: String) -> String {
        var inline = ""
        for character in line {
            if character == "*" || character == "_" || character == "`" { inline.append("\\") }
            inline.append(character)
        }
        guard let start = inline.firstIndex(where: { !$0.isWhitespace }) else { return inline }
        let rest = inline[start...]
        if let first = rest.first, "#>-+".contains(first) {
            inline.insert("\\", at: start)
        } else if let first = rest.first, first.isASCII, first.isNumber {
            // "<digits>." at the start of a line would start a numbered list.
            let digits = rest.prefix(while: { $0.isASCII && $0.isNumber })
            let afterDigits = rest[digits.endIndex...]
            if afterDigits.first == "." {
                inline.insert("\\", at: afterDigits.startIndex)
            }
        }
        return inline
    }
}
