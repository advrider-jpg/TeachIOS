import Foundation

enum RosterImportService {
    static func preview(csvText: String, defaultClassName: String = "") -> RosterImportPreview {
        let parsedRows: [[String]]
        do {
            parsedRows = try CSVParser.parseRows(csvText)
        } catch {
            let message = error.localizedDescription
            return RosterImportPreview(
                className: defaultClassName,
                students: [],
                duplicateNames: [],
                rejectedRows: ["Row 1: \(message)"],
                rejectedRowDetails: [RosterRejectedRow(rowNumber: 1, rawText: csvText, reason: message)],
                warnings: [],
                hasHeaderRow: false
            )
        }

        let nonEmptyRows = parsedRows.enumerated().filter { _, columns in
            columns.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
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

        let firstColumns = first.element
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

        for (rawIndex, columns) in dataRows {
            let rowNumber = rawIndex + 1
            let displayName = value(columns, at: hasHeader ? headerIndex["displayname"] : 0)
            let localIdentifier = value(columns, at: hasHeader ? headerIndex["localidentifier"] : 1)
            let rowClassName = value(columns, at: hasHeader ? headerIndex["classname"] : 2)
            let notes = value(columns, at: hasHeader ? headerIndex["notes"] : 3)
            let resolvedClassName = rowClassName.isEmpty ? defaultClassName : rowClassName
            let rawText = CSVWriter.string(rows: [columns])

            guard !displayName.isEmpty else {
                let reason = "Missing displayName."
                rejectedRows.append("Row \(rowNumber): \(reason)")
                rejectedDetails.append(RosterRejectedRow(rowNumber: rowNumber, rawText: rawText, reason: reason))
                continue
            }

            let nameKey = displayName.lowercased()
            seenNames[nameKey, default: 0] += 1
            if !localIdentifier.isEmpty {
                let idKey = localIdentifier.lowercased()
                seenIDs[idKey, default: 0] += 1
                if seenIDs[idKey, default: 0] > 1 {
                    let reason = "Duplicate localIdentifier \(localIdentifier)."
                    rejectedRows.append("Row \(rowNumber): \(reason)")
                    rejectedDetails.append(RosterRejectedRow(rowNumber: rowNumber, rawText: rawText, reason: reason))
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
}
