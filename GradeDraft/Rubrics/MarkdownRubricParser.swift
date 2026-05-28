import Foundation

/// Delegates to RubricParser for all rubric text.
/// Markdown-aware structured rubric parsing is not implemented in this version.
/// The swift-markdown dependency is available but not currently used for rubric parsing.
/// Full Markdown rubric parsing is a deferred feature.
enum MarkdownRubricParser {
    static func parse(_ text: String) -> ParsedRubric {
        RubricParser.parse(text)
    }

    static func criterionIDsPreservingOrder(from parsed: ParsedRubric) -> [String] {
        parsed.criteria.map(\.id)
    }
}
