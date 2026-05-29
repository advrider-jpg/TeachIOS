import Foundation

enum RosterImportService {
    static func preview(csvText: String, defaultClassName: String = "") -> RosterImportPreview {
        let rawRows = csvText.components(separatedBy: .newlines)
        let nonEmptyRows = rawRows.enumerated().filter { !$0.element.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let first = nonEmptyRows.first else {
            return RosterImportPreview(
                className: defaultClassName,
                students: [],
                duplicateNames: [],
                rejectedRows: ["Roster import is empty."],
                rejectedRowDetails: [RosterRejectedRow(rowNumber: 1, rawText: "", reason: "Roster import is empty.")],
                warnings: [],
                hasHeaderRow: false
            )
        }

        let firstColumns = csvColumns(first.element)
        let lowerHeaders = firstColumns.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let hasHeader = lowerHeaders.contains("displayname") || lowerHeaders.contains("display name") || lowerHeaders.contains("localidentifier") || lowerHeaders.contains("local identifier") || lowerHeaders.contains("classname") || lowerHeaders.contains("class name")
        let headerIndex: [String: Int] = Dictionary(uniqueKeysWithValues: lowerHeaders.enumerated().map { index, value in (value.replacingOccurrences(of: " ", with: ""), index) })
        let dataRows = hasHeader ? Array(nonEmptyRows.dropFirst()) : nonEmptyRows
        var warnings: [String] = []
        if !hasHeader {
            warnings.append("No roster CSV header row was detected; the first column is treated as displayName.")
        }

        var students: [StudentRecord] = []
        var rejectedRows: [String] = []
        var rejectedDetails: [RosterRejectedRow] = []
        var seenNames: [String: Int] = [:]
        var seenIDs: [String: Int] = [:]

        for (rawIndex, rawLine) in dataRows {
            let columns = csvColumns(rawLine)
            let displayName = value(columns, at: hasHeader ? headerIndex["displayname"] : 0)
            let localIdentifier = value(columns, at: hasHeader ? headerIndex["localidentifier"] : 1)
            let rowClassName = value(columns, at: hasHeader ? headerIndex["classname"] : 2)
            let notes = value(columns, at: hasHeader ? headerIndex["notes"] : 3)
            let resolvedClassName = rowClassName.isEmpty ? defaultClassName : rowClassName

            guard !displayName.isEmpty else {
                let reason = "Missing displayName."
                rejectedRows.append("Row \(rawIndex + 1): \(reason)")
                rejectedDetails.append(RosterRejectedRow(rowNumber: rawIndex + 1, rawText: rawLine, reason: reason))
                continue
            }

            let nameKey = displayName.lowercased()
            seenNames[nameKey, default: 0] += 1
            if !localIdentifier.isEmpty {
                let idKey = localIdentifier.lowercased()
                seenIDs[idKey, default: 0] += 1
                if seenIDs[idKey, default: 0] > 1 {
                    let reason = "Duplicate localIdentifier \(localIdentifier)."
                    rejectedRows.append("Row \(rawIndex + 1): \(reason)")
                    rejectedDetails.append(RosterRejectedRow(rowNumber: rawIndex + 1, rawText: rawLine, reason: reason))
                    continue
                }
            }

            students.append(StudentRecord(displayName: displayName, className: resolvedClassName, localIdentifier: localIdentifier, notes: notes))
        }

        let duplicateNames = seenNames.filter { $0.value > 1 }.map(\.key).sorted()
        if !duplicateNames.isEmpty {
            warnings.append("Duplicate display names detected; use localIdentifier values to distinguish students.")
        }

        return RosterImportPreview(
            className: defaultClassName,
            students: students,
            duplicateNames: duplicateNames,
            rejectedRows: rejectedRows,
            rejectedRowDetails: rejectedDetails,
            warnings: warnings,
            hasHeaderRow: hasHeader
        )
    }

    private static func value(_ columns: [String], at index: Int?) -> String {
        guard let index, columns.indices.contains(index) else { return "" }
        return columns[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func csvColumns(_ row: String) -> [String] {
        var columns: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = row.makeIterator()
        while let char = iterator.next() {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                columns.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        columns.append(current)
        return columns
    }
}
