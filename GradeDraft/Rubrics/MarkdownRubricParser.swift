import Foundation
import Markdown

/// Markdown-aware rubric parser that extracts structured criteria, groups, levels,
/// point ranges, and warnings while keeping the raw rubric available for teacher confirmation.
///
/// Structure comes only from the swift-markdown AST (`Document`): headings (tracked while
/// walking, so each table or list row knows its group), list items, tables (`head` and `body`
/// rows), block quotes and paragraphs. Paragraphs are split on soft/hard line breaks so
/// teachers can list one criterion per line without blank-line separation. Tables and lists
/// inside code blocks are not rubric content; they are ignored with a warning. Point, title,
/// ID, and level extraction reuse the shared `RubricParser` helpers.
enum MarkdownRubricParser {
    static func preview(_ text: String) -> RubricImportPreview {
        RubricImportPreview(rawMarkdown: text, parsedRubric: parse(text))
    }

    static func parse(_ text: String) -> ParsedRubric {
        let (rows, walkWarnings) = candidateRows(from: text)
        var criteria: [RubricCriterion] = []
        var issues: [String] = walkWarnings
        var groups: [String] = []
        var currentGroup: String?
        var seen: Set<String> = []

        for row in rows {
            if row.kind == .heading {
                currentGroup = row.title
                if let currentGroup, !groups.contains(currentGroup) { groups.append(currentGroup) }
                guard let maxPoints = row.maxPoints ?? RubricParser.maxPoints(in: row.text),
                      let title = RubricParser.criterionTitle(from: row.text) ?? row.title.nilIfEmpty else {
                    continue
                }

                let normalizedTitle = RubricParser.normalized(title)
                if seen.contains(normalizedTitle) {
                    issues.append("Duplicate criterion ignored: \(title)")
                    continue
                }
                seen.insert(normalizedTitle)
                let order = criteria.count
                let id = row.explicitID ?? RubricParser.stableCriterionID(order: order, title: title, maxPoints: maxPoints)
                var levels = row.levels(criterionID: id)
                if levels.isEmpty { levels = RubricParser.levels(in: row.text, criterionID: id) }
                criteria.append(
                    RubricCriterion(
                        id: id,
                        title: title,
                        maxPoints: maxPoints,
                        descriptor: row.descriptor.isEmpty ? row.text : row.descriptor,
                        sortOrder: order,
                        groupTitle: currentGroup,
                        levels: levels,
                        explicitID: row.explicitID
                    )
                )
                continue
            }

            if row.kind == .tableHeader { continue }
            guard let maxPoints = row.maxPoints ?? RubricParser.maxPoints(in: row.text) else { continue }
            guard let title = row.title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? RubricParser.criterionTitle(from: row.text) else { continue }
            let normalizedTitle = RubricParser.normalized(title)
            if seen.contains(normalizedTitle) {
                issues.append("Duplicate criterion ignored: \(title)")
                continue
            }
            seen.insert(normalizedTitle)
            let order = criteria.count
            let id = row.explicitID ?? RubricParser.stableCriterionID(order: order, title: title, maxPoints: maxPoints)
            var levels = row.levels(criterionID: id)
            if levels.isEmpty { levels = RubricParser.levels(in: row.text, criterionID: id) }
            criteria.append(
                RubricCriterion(
                    id: id,
                    title: title,
                    maxPoints: maxPoints,
                    descriptor: row.descriptor.isEmpty ? row.text : row.descriptor,
                    sortOrder: order,
                    groupTitle: row.groupTitle ?? currentGroup,
                    levels: levels,
                    explicitID: row.explicitID
                )
            )
        }

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Rubric text is empty.")
        } else if criteria.isEmpty {
            issues.append("Markdown parser did not detect point-bearing criteria; raw rubric text remains available for teacher confirmation.")
        }
        for criterion in criteria where criterion.levels.isEmpty {
            issues.append("Criterion '\(criterion.title)' has no explicit scoring bands; teacher can still confirm the raw descriptor.")
        }
        return ParsedRubric(criteria: criteria, issues: stableIssues(issues), groups: groups)
    }

    static func criterionIDsPreservingOrder(from parsed: ParsedRubric) -> [String] {
        parsed.criteria.sorted { $0.sortOrder < $1.sortOrder }.map(\.id)
    }

    private enum RowKind { case heading, bullet, numbered, table, tableHeader, paragraph }

    private struct LevelColumn {
        var label: String
        var descriptor: String
        var points: Double?
        var min: Double?
        var max: Double?
    }

    private struct CandidateRow {
        var kind: RowKind
        var text: String
        var title: String
        var descriptor: String
        var groupTitle: String?
        var explicitID: String?
        var maxPoints: Double?
        var levelColumns: [LevelColumn]

        func levels(criterionID: String) -> [RubricLevel] {
            levelColumns.enumerated().map { index, level in
                RubricLevel(
                    id: "\(criterionID)-level-\(index + 1)-\(RubricParser.normalized(level.label))",
                    label: level.label,
                    points: level.points ?? level.max ?? 0,
                    minPoints: level.min,
                    maxPoints: level.max,
                    descriptor: level.descriptor,
                    sortOrder: index
                )
            }
        }
    }

    // MARK: - AST walk

    private static let codeBlockWarning = "A table or list inside a code block was ignored."

    private static func candidateRows(from text: String) -> (rows: [CandidateRow], warnings: [String]) {
        var walker = Walker()
        walker.walk(Document(parsing: text))
        return (walker.rows, walker.warnings)
    }

    /// Walks block markup in document order, emitting one candidate row per heading, per
    /// soft/hard-break-delimited paragraph line, per list item, and per table body row. The
    /// current heading is tracked so rows carry their group.
    private struct Walker {
        var rows: [CandidateRow] = []
        var warnings: [String] = []
        var currentGroup: String?

        mutating func walk(_ markup: Markup) {
            for child in markup.children { visit(child) }
        }

        mutating func visit(_ block: Markup) {
            switch block {
            case let heading as Heading:
                let title = MarkdownRubricParser.plain(heading)
                guard !title.isEmpty else { return }
                currentGroup = title
                rows.append(
                    CandidateRow(kind: .heading, text: title, title: title, descriptor: "",
                                 groupTitle: nil, explicitID: nil, maxPoints: nil, levelColumns: [])
                )
            case let table as Markdown.Table:
                appendTableRows(table)
            case let paragraph as Paragraph:
                for line in MarkdownRubricParser.paragraphLines(paragraph) {
                    appendTextRow(line, kind: .paragraph)
                }
            case let item as ListItem:
                let text = item.children
                    .compactMap { $0 as? Paragraph }
                    .map { MarkdownRubricParser.plain($0) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                appendTextRow(text, kind: item.parent is OrderedList ? .numbered : .bullet)
                // Nested lists, tables and code blocks inside the item; its own paragraphs are the row above.
                for child in item.children where !(child is Paragraph) { visit(child) }
            case is UnorderedList, is OrderedList, is BlockQuote:
                walk(block)
            case let code as CodeBlock:
                if MarkdownRubricParser.containsTableOrList(Document(parsing: code.code)),
                   !warnings.contains(MarkdownRubricParser.codeBlockWarning) {
                    warnings.append(MarkdownRubricParser.codeBlockWarning)
                }
            default:
                return
            }
        }

        private mutating func appendTextRow(_ text: String, kind: RowKind) {
            guard !text.isEmpty else { return }
            rows.append(
                CandidateRow(
                    kind: kind,
                    text: text,
                    title: RubricParser.criterionTitle(from: text) ?? text,
                    descriptor: text,
                    groupTitle: currentGroup,
                    explicitID: RubricParser.explicitCriterionID(in: text),
                    maxPoints: RubricParser.maxPoints(in: text),
                    levelColumns: []
                )
            )
        }

        private mutating func appendTableRows(_ table: Markdown.Table) {
            let headerCells = MarkdownRubricParser.cells(in: table.head)
            if headerCells.contains(where: { !$0.isEmpty }) {
                rows.append(
                    CandidateRow(kind: .tableHeader, text: headerCells.filter { !$0.isEmpty }.joined(separator: ": "),
                                 title: headerCells.first ?? "", descriptor: "", groupTitle: currentGroup,
                                 explicitID: nil, maxPoints: nil, levelColumns: [])
                )
            }
            for case let bodyRow as Markdown.Table.Row in table.body.children {
                let rowCells = MarkdownRubricParser.cells(in: bodyRow)
                guard rowCells.contains(where: { !$0.isEmpty }) else { continue }
                var row = MarkdownRubricParser.tableRow(cells: rowCells, headers: headerCells)
                row.groupTitle = currentGroup
                rows.append(row)
            }
        }
    }

    /// Plain text of a block or inline via `PlainTextConvertibleMarkup`; soft breaks read as a space.
    private static func plain(_ markup: Markup) -> String {
        let text: String
        switch markup {
        case is SoftBreak: text = " "
        case is LineBreak: text = "\n"
        case let convertible as PlainTextConvertibleMarkup: text = convertible.plainText
        default: text = markup.children.map { plain($0) }.joined()
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Splits a paragraph into one string per soft/hard line break so that consecutive
    /// criterion lines (no blank line between them) are treated as separate criteria.
    private static func paragraphLines(_ paragraph: Paragraph) -> [String] {
        var lines: [String] = []
        var current = ""
        for inline in paragraph.children {
            if inline is SoftBreak || inline is LineBreak {
                lines.append(current)
                current = ""
            } else if let convertible = inline as? PlainTextConvertibleMarkup {
                current += convertible.plainText
            } else {
                current += plain(inline)
            }
        }
        lines.append(current)
        return lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func containsTableOrList(_ markup: Markup) -> Bool {
        if markup is Markdown.Table || markup is UnorderedList || markup is OrderedList { return true }
        return markup.children.contains { containsTableOrList($0) }
    }

    /// Cell text in column order. Blank cells are kept so body cells stay aligned with their header.
    private static func cells(in container: Markup) -> [String] {
        container.children.compactMap { ($0 as? Markdown.Table.Cell).map { plain($0) } }
    }

    private static func tableRow(cells: [String], headers: [String]) -> CandidateRow {
        let normalizedHeaders = headers.map { RubricParser.normalized($0) }
        let idIndex = normalizedHeaders.firstIndex { $0 == "criterionid" || $0 == "id" || $0 == "code" }
        let titleIndex = normalizedHeaders.firstIndex { $0 == "criterion" || $0 == "title" || $0 == "name" }
            ?? headers.firstIndex { ($0.localizedCaseInsensitiveContains("criterion") && !$0.localizedCaseInsensitiveContains("id")) || $0.localizedCaseInsensitiveContains("name") || $0.localizedCaseInsensitiveContains("title") }
            ?? 0
        let pointsIndex = headers.firstIndex { $0.localizedCaseInsensitiveContains("point") || $0.localizedCaseInsensitiveContains("pts") }
        let descriptorIndex = headers.firstIndex { $0.localizedCaseInsensitiveContains("descriptor") || $0.localizedCaseInsensitiveContains("description") }
        let title = cells[safe: titleIndex] ?? cells.first ?? ""
        let explicitID = idIndex.flatMap { cells[safe: $0] }.flatMap { RubricParser.normalized($0).nilIfEmpty } ?? RubricParser.explicitCriterionID(in: title)
        let pointsText = pointsIndex.flatMap { cells[safe: $0] } ?? cells.joined(separator: " ")
        let tableMaxPoints = pointsIndex.flatMap { cells[safe: $0] }.flatMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) ?? RubricParser.maxPoints(in: $0) }
        let descriptor = descriptorIndex.flatMap { cells[safe: $0] } ?? cells.dropFirst().joined(separator: " ")
        let levelColumns: [LevelColumn] = headers.enumerated().compactMap { index, header in
            let headerIsLevel = ["excellent", "proficient", "developing", "beginning", "level", "band"].contains { header.lowercased().contains($0) }
            guard headerIsLevel, let value = cells[safe: index], !value.isEmpty else { return nil }
            let range = RubricParser.pointRange(in: value)
            return LevelColumn(label: header, descriptor: value, points: RubricParser.maxPoints(in: value), min: range.0, max: range.1)
        }
        return CandidateRow(
            kind: .table,
            text: cells.joined(separator: " | "),
            title: title,
            descriptor: descriptor,
            groupTitle: nil,
            explicitID: explicitID,
            maxPoints: tableMaxPoints ?? RubricParser.maxPoints(in: pointsText) ?? RubricParser.maxPoints(in: cells.joined(separator: " ")),
            levelColumns: levelColumns
        )
    }

    private static func stableIssues(_ issues: [String]) -> [String] {
        var seen: Set<String> = []
        var output: [String] = []
        for issue in issues where !seen.contains(issue) {
            output.append(issue)
            seen.insert(issue)
        }
        return output
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
