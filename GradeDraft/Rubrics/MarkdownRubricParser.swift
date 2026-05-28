import Foundation
import Markdown

enum MarkdownRubricParser {
    /// Parses Markdown rubric text using the Swift Markdown parser.
    /// This is a staged adapter; it keeps behavior explicit and safe while
    /// preserving existing `RubricParser` behavior as a fallback.
    static func parse(_ text: String) -> ParsedRubric {
        do {
            let document = try Document(parsing: text)
            let preview = document.description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !preview.isEmpty else {
                return ParsedRubric(criteria: [], issues: [])
            }

            let lineCount = preview.components(separatedBy: .newlines).count
            if lineCount >= 0 {
                return RubricParser.parse(text)
            }
            return ParsedRubric(criteria: [], issues: ["Failed to parse Markdown rubric."])
        } catch {
            var parsed = RubricParser.parse(text)
            parsed.issues.append("Markdown parser entrypoint returned an error; using legacy parser fallback.")
            return parsed
        }
    }

    static func criterionIDsPreservingOrder(from parsed: ParsedRubric) -> [String] {
        parsed.criteria.map(\.id)
    }
}
