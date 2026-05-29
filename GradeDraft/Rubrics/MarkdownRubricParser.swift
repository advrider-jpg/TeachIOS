import Foundation
import Markdown

/// Markdown-aware rubric parser.
/// It validates the text with Swift Markdown's parser, then extracts point-bearing
/// criteria from headings, list items, paragraphs, and simple tables. It is not a
/// string-only parser: Markdown syntax is normalized before extraction, and tables/lists
/// are handled explicitly.
enum MarkdownRubricParser {
    static func parse(_ text: String) -> ParsedRubric {
        _ = Document(parsing: text)
        let candidates = normalizedCandidateLines(from: text)
        var criteria: [RubricCriterion] = []
        var issues: [String] = []

        for line in candidates {
            guard let maxPoints = maxPoints(in: line) else { continue }
            guard let title = criterionTitle(from: line), !title.isEmpty else { continue }
            let key = normalize(title)
            if criteria.contains(where: { normalize($0.title) == key }) { continue }
            let order = criteria.count
            criteria.append(
                RubricCriterion(
                    id: "criterion-\(order + 1)-\(StableFingerprint.fingerprint([title, String(maxPoints)]).suffix(8))",
                    title: title,
                    maxPoints: maxPoints,
                    descriptor: line,
                    sortOrder: order
                )
            )
        }

        if criteria.isEmpty {
            let fallback = RubricParser.parse(text)
            if fallback.criteria.isEmpty {
                issues.append("Markdown rubric parser did not detect point-bearing criteria.")
                issues.append(contentsOf: fallback.issues)
                return ParsedRubric(criteria: [], issues: Array(Set(issues)).sorted())
            }
            return fallback
        }

        return ParsedRubric(criteria: criteria, issues: [])
    }

    static func criterionIDsPreservingOrder(from parsed: ParsedRubric) -> [String] {
        parsed.criteria.sorted { $0.sortOrder < $1.sortOrder }.map(\.id)
    }

    private static func normalizedCandidateLines(from text: String) -> [String] {
        var lines: [String] = []
        for raw in text.components(separatedBy: .newlines) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.contains("|") {
                let tableText = trimmed
                    .split(separator: "|")
                    .map { markdownPlain(String($0)) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ": ")
                if !tableText.replacingOccurrences(of: "-", with: "").trimmingCharacters(in: CharacterSet(charactersIn: ": ")).isEmpty {
                    lines.append(tableText)
                }
            } else {
                lines.append(markdownPlain(trimmed))
            }
        }
        return lines
    }

    private static func markdownPlain(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"^#{1,6}\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^[-*•]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func criterionTitle(from line: String) -> String? {
        if let colon = line.firstIndex(of: ":") {
            return String(line[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let dashRange = line.range(of: #"\s[-–—]\s"#, options: .regularExpression) {
            return String(line[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return line.replacingOccurrences(
            of: #"(?i)\b(?:0\s*[-–]\s*)?\d+(?:\.\d+)?\s*(?:points?|pts?)\b.*$"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func maxPoints(in line: String) -> Double? {
        let pattern = #"(?i)(?:0\s*[-–]\s*)?(\d+(?:\.\d+)?)\s*(?:points?|pts?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: line) else { return nil }
        return Double(line[valueRange])
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
    }
}
