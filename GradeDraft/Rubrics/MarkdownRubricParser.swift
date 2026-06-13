import Foundation
import Markdown

/// Markdown-aware rubric parser that extracts structured criteria, groups, levels,
/// point ranges, and warnings while keeping the raw rubric available for teacher confirmation.
///
/// Structure detection is driven by the swift-markdown AST (`Document`): headings,
/// tables (header + body rows, with the delimiter row handled natively), lists, block
/// quotes, and paragraphs are walked directly. Paragraphs are split on soft/hard line
/// breaks so teachers can list one criterion per line without blank-line separation.
/// Point, title, ID, and level extraction reuse the shared `RubricParser` helpers.
enum MarkdownRubricParser {
    static func preview(_ text: String) -> RubricImportPreview {
        RubricImportPreview(rawMarkdown: text, parsedRubric: parse(text))
    }

    static func parse(_ text: String) -> ParsedRubric {
        let rows = candidateRows(from: text)
        var criteria: [RubricCriterion] = []
        var issues: [String] = []
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

    private static func candidateRows(from text: String) -> [CandidateRow] {
        var rows: [CandidateRow] = []
        collectRows(from: Document(parsing: text), into: &rows)
        rows.append(contentsOf: pipeTableRows(fromRawMarkdown: text))
        rows.append(contentsOf: explicitListRows(fromRawMarkdown: text))
        return deduplicatedRows(rows)
    }

    /// Recursively walks block markup, emitting one candidate row per heading, per
    /// soft/hard-break-delimited paragraph line, per list item line, and per table row.
    private static func collectRows(from markup: Markup, into rows: inout [CandidateRow]) {
        for child in markup.children {
            switch child {
            case let heading as Heading:
                let title = markdownPlain(heading.plainText)
                guard !title.isEmpty else { continue }
                rows.append(
                    CandidateRow(kind: .heading, text: title, title: title, descriptor: "",
                                 groupTitle: nil, explicitID: nil, maxPoints: nil, levelColumns: [])
                )
            case let table as Markdown.Table:
                collectTableRows(table, into: &rows)
            case let paragraph as Paragraph:
                for line in paragraphLines(paragraph) {
                    appendTextRow(line, kind: .paragraph, into: &rows)
                }
            case is UnorderedList, is OrderedList, is ListItem, is BlockQuote:
                // Block containers: recurse so their inner paragraphs become rows. The
                // AST has already stripped list markers and quote prefixes.
                collectRows(from: child, into: &rows)
            default:
                continue
            }
        }
    }

    /// Splits a paragraph into one string per soft/hard line break so that consecutive
    /// criterion lines (no blank line between them) are treated as separate criteria.
    private static func paragraphLines(_ paragraph: Paragraph) -> [String] {
        var lines: [String] = []
        var current = ""

        // Walk inline markup by concrete type. `plainText` is not exposed on the
        // `any Markup` existential in this swift-markdown version, so recurse into
        // container inlines (emphasis, strong, links) and read leaf text directly.
        func accumulate(_ markup: Markup) {
            switch markup {
            case is SoftBreak, is LineBreak:
                lines.append(current)
                current = ""
            case let text as Text:
                current += text.string
            case let code as InlineCode:
                current += code.code
            default:
                for child in markup.children { accumulate(child) }
            }
        }

        for inline in paragraph.children { accumulate(inline) }
        lines.append(current)
        return lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func appendTextRow(_ rawText: String, kind: RowKind, into rows: inout [CandidateRow]) {
        let plain = markdownPlain(rawText)
        guard !plain.isEmpty else { return }
        rows.append(
            CandidateRow(
                kind: kind,
                text: plain,
                title: RubricParser.criterionTitle(from: plain) ?? plain,
                descriptor: plain,
                groupTitle: nil,
                explicitID: RubricParser.explicitCriterionID(in: plain),
                maxPoints: RubricParser.maxPoints(in: plain),
                levelColumns: []
            )
        )
    }

    private static func collectTableRows(_ table: Markdown.Table, into rows: inout [CandidateRow]) {
        let headerCells = cells(in: table.head)
        if !headerCells.isEmpty {
            rows.append(
                CandidateRow(kind: .tableHeader, text: headerCells.joined(separator: ": "),
                             title: headerCells.first ?? "", descriptor: "", groupTitle: nil,
                             explicitID: nil, maxPoints: nil, levelColumns: [])
            )
        }
        for case let bodyRow as Markdown.Table.Row in table.body.children {
            let rowCells = cells(in: bodyRow)
            guard !rowCells.isEmpty else { continue }
            rows.append(tableRow(cells: rowCells, headers: headerCells))
        }
    }

    private static func pipeTableRows(fromRawMarkdown text: String) -> [CandidateRow] {
        let lines = text.components(separatedBy: .newlines)
        var rows: [CandidateRow] = []
        var currentGroup: String?
        var index = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if let heading = rawHeadingTitle(from: line) {
                currentGroup = heading
                index += 1
                continue
            }
            guard isPipeTableLine(line),
                  index + 1 < lines.count,
                  isPipeDelimiterRow(splitPipeRow(lines[index + 1])) else {
                index += 1
                continue
            }

            let headers = splitPipeRow(line)
            index += 2
            while index < lines.count {
                let bodyLine = lines[index].trimmingCharacters(in: .whitespaces)
                guard isPipeTableLine(bodyLine) else { break }
                var row = tableRow(cells: splitPipeRow(bodyLine), headers: headers)
                row.groupTitle = currentGroup
                rows.append(row)
                index += 1
            }
        }

        return rows
    }

    private static func explicitListRows(fromRawMarkdown text: String) -> [CandidateRow] {
        var rows: [CandidateRow] = []
        var currentGroup: String?
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let heading = rawHeadingTitle(from: line) {
                currentGroup = heading
                continue
            }
            guard let item = rawListItem(from: line) else { continue }
            let plain = markdownPlain(item.text)
            guard !plain.isEmpty else { continue }
            rows.append(
                CandidateRow(
                    kind: item.kind,
                    text: plain,
                    title: RubricParser.criterionTitle(from: plain) ?? plain,
                    descriptor: plain,
                    groupTitle: currentGroup,
                    explicitID: RubricParser.explicitCriterionID(in: item.text),
                    maxPoints: RubricParser.maxPoints(in: plain),
                    levelColumns: []
                )
            )
        }
        return rows
    }

    private static func rawHeadingTitle(from line: String) -> String? {
        guard line.hasPrefix("#") else { return nil }
        let withoutMarkers = String(line.drop(while: { $0 == "#" }))
        let trimmed = withoutMarkers.trimmingCharacters(in: .whitespaces)
        return markdownPlain(String(trimmed)).nilIfEmpty
    }

    private static func rawListItem(from line: String) -> (kind: RowKind, text: String)? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return (.bullet, String(line.dropFirst(2)))
        }
        guard let markerRange = line.range(of: #"^\d+[\.)]\s+"#, options: .regularExpression) else {
            return nil
        }
        return (.numbered, String(line[markerRange.upperBound...]))
    }

    private static func isPipeTableLine(_ line: String) -> Bool {
        line.hasPrefix("|") && line.contains("|")
    }

    private static func splitPipeRow(_ line: String) -> [String] {
        var value = line.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("|") { value.removeFirst() }
        if value.hasSuffix("|") { value.removeLast() }
        return value
            .components(separatedBy: "|")
            .map { markdownPlain($0) }
    }

    private static func isPipeDelimiterRow(_ cells: [String]) -> Bool {
        !cells.isEmpty && cells.allSatisfy { cell in
            let marker = cell.trimmingCharacters(in: .whitespaces)
            let stripped = marker.replacingOccurrences(of: ":", with: "")
            return stripped.count >= 3 && stripped.allSatisfy { $0 == "-" }
        }
    }

    private static func deduplicatedRows(_ rows: [CandidateRow]) -> [CandidateRow] {
        var seen: Set<String> = []
        var output: [CandidateRow] = []
        for row in rows {
            let key = [
                row.explicitID ?? "",
                RubricParser.normalized(row.title),
                row.maxPoints.map { GradeTotals.formatted($0) } ?? "",
                RubricParser.normalized(row.text)
            ].joined(separator: "|")
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            output.append(row)
        }
        return output
    }

    private static func cells(in container: Markup) -> [String] {
        container.children
            .compactMap { ($0 as? Markdown.Table.Cell)?.plainText }
            .map(markdownPlain)
            .filter { !$0.isEmpty }
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

    private static func markdownPlain(_ value: String) -> String {
        value
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
