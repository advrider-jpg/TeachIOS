import Foundation
import Markdown

/// Markdown-aware rubric parser that extracts structured criteria, groups, levels,
/// point ranges, and warnings while keeping the raw rubric available for teacher confirmation.
enum MarkdownRubricParser {
    static func preview(_ text: String) -> RubricImportPreview {
        RubricImportPreview(rawMarkdown: text, parsedRubric: parse(text))
    }

    static func parse(_ text: String) -> ParsedRubric {
        _ = Document(parsing: text)
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
                let headingText = row.text
                let headingTitle = RubricParser.criterionTitle(from: headingText)
                    ?? RubricParser.criterionTitle(from: row.title)
                    ?? row.title.nilIfEmpty
                guard let maxPoints = row.maxPoints ?? RubricParser.maxPoints(in: headingText) ?? RubricParser.maxPoints(in: row.title),
                      let title = headingTitle else {
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

    private static func candidateRows(from text: String) -> [CandidateRow] {
        var rows: [CandidateRow] = []
        var tableHeaders: [String] = []
        for raw in text.components(separatedBy: .newlines) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("#") {
                let title = markdownPlain(trimmed.replacingOccurrences(of: #"^#{1,6}\s*"#, with: "", options: .regularExpression))
                rows.append(CandidateRow(kind: .heading, text: title, title: title, descriptor: "", groupTitle: nil, explicitID: nil, maxPoints: nil, levelColumns: []))
                continue
            }
            if trimmed.contains("|") {
                let cells = trimmed.split(separator: "|", omittingEmptySubsequences: false).map { markdownPlain(String($0)) }.filter { !$0.isEmpty }
                guard !cells.isEmpty else { continue }
                if cells.allSatisfy({ $0.replacingOccurrences(of: "-", with: "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }
                if tableHeaders.isEmpty || cells.contains(where: { $0.localizedCaseInsensitiveContains("criterion") }) {
                    tableHeaders = cells
                    rows.append(CandidateRow(kind: .tableHeader, text: cells.joined(separator: ": "), title: cells.first ?? "", descriptor: "", groupTitle: nil, explicitID: nil, maxPoints: nil, levelColumns: []))
                    continue
                }
                rows.append(tableRow(cells: cells, headers: tableHeaders))
                continue
            }
            let plain = markdownPlain(trimmed)
            let kind: RowKind = trimmed.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) == nil ? (trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("•") ? .bullet : .paragraph) : .numbered
            let stripped = plain
                .replacingOccurrences(of: #"^[-*•]\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"^\d+[.)]\s*"#, with: "", options: .regularExpression)
            rows.append(
                CandidateRow(
                    kind: kind,
                    text: stripped,
                    title: RubricParser.criterionTitle(from: stripped) ?? stripped,
                    descriptor: stripped,
                    groupTitle: nil,
                    explicitID: RubricParser.explicitCriterionID(in: stripped),
                    maxPoints: RubricParser.maxPoints(in: stripped),
                    levelColumns: []
                )
            )
        }
        return rows
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

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
