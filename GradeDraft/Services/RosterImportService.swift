import Foundation

/// Turns a teacher's roster file (CSV, text or Excel) into `RosterImportRow`s plus a report of
/// everything that was not imported as-is: blank columns, columns that were not recognised
/// or repeated, rows that were skipped, and whether a header row was found.
enum RosterImportService {
    private enum Field: CaseIterable {
        case displayName, firstName, surname, localIdentifier, className, notes

        /// Header names, lower-cased with spaces removed.
        var synonyms: [String] {
            switch self {
            case .displayName: return ["displayname", "name", "studentname", "fullname"]
            case .firstName: return ["firstname", "givenname", "preferredname"]
            case .surname: return ["surname", "lastname", "familyname"]
            case .localIdentifier: return ["localidentifier", "studentcode", "studentid", "id", "code"]
            case .className: return ["classname", "class", "group"]
            case .notes: return ["notes"]
            }
        }
    }

    static func parse(fileAt url: URL) throws -> (rows: [RosterImportRow], result: RosterImportResult) {
        if url.pathExtension.lowercased() == "xlsx" {
            return parse(rows: try SpreadsheetReader.rows(fromXLSX: url))
        }
        return parse(text: try TextFileReader.read(url))
    }

    static func parse(text: String) -> (rows: [RosterImportRow], result: RosterImportResult) {
        let withoutBOM = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        do {
            return parse(rows: try CSVParser.parseRows(withoutBOM))
        } catch {
            return ([], RosterImportResult(ignoredBlankColumns: 0, unrecognisedColumns: [],
                                           skippedRows: ["The roster could not be read: \(error.localizedDescription)"],
                                           hasHeaderRow: false))
        }
    }

    private static func parse(rows parsedRows: [[String]]) -> (rows: [RosterImportRow], result: RosterImportResult) {
        let numbered = parsedRows.enumerated().filter { _, columns in
            columns.contains { !clean($0).isEmpty }
        }
        guard let first = numbered.first else {
            return ([], RosterImportResult(ignoredBlankColumns: 0, unrecognisedColumns: [],
                                           skippedRows: ["The roster is empty."], hasHeaderRow: false))
        }

        let headers = first.element.map(clean)
        let named = headers.enumerated().filter { !$0.element.isEmpty }
        let normalised = named.map { (index: $0.offset, name: normalisedHeader($0.element)) }
        let knownNames = Set(Field.allCases.flatMap(\.synonyms))
        let hasHeader = normalised.contains { knownNames.contains($0.name) }

        var columnFor: [Field: Int] = [:]
        var ignoredBlankColumns = 0
        var unrecognised: [String] = []

        if hasHeader {
            // The first of any repeated header wins.
            let indexByName = Dictionary(normalised.map { ($0.name, $0.index) }, uniquingKeysWith: { first, _ in first })
            for field in Field.allCases {
                if let index = field.synonyms.compactMap({ indexByName[$0] }).min() {
                    columnFor[field] = index
                }
            }
            ignoredBlankColumns = headers.count - named.count
            let used = Set(columnFor.values)
            for entry in normalised where !used.contains(entry.index) {
                let repeated = indexByName[entry.name] != entry.index
                unrecognised.append(repeated ? "\(headers[entry.index]) (repeated)" : headers[entry.index])
            }
        } else {
            columnFor = [.displayName: 0, .localIdentifier: 1, .className: 2, .notes: 3]
        }

        var importRows: [RosterImportRow] = []
        var skipped: [String] = []
        var seenIdentifiers: Set<String> = []
        var seenNames: [String: Int] = [:]

        for (rawIndex, columns) in hasHeader ? Array(numbered.dropFirst()) : numbered {
            let rowNumber = rawIndex + 1
            func value(_ field: Field) -> String {
                guard let index = columnFor[field], columns.indices.contains(index) else { return "" }
                return clean(columns[index])
            }

            let displayName: String
            if columnFor[.displayName] != nil || !hasHeader {
                displayName = value(.displayName)
            } else {
                displayName = [value(.firstName), value(.surname)].filter { !$0.isEmpty }.joined(separator: " ")
            }
            guard !displayName.isEmpty else {
                skipped.append("Row \(rowNumber): no student name.")
                continue
            }

            seenNames[displayName.lowercased(), default: 0] += 1
            let identifier = value(.localIdentifier)
            if !identifier.isEmpty, !seenIdentifiers.insert(identifier.lowercased()).inserted {
                skipped.append("Row \(rowNumber): \(displayName) repeats the identifier \(identifier).")
                continue
            }

            importRows.append(RosterImportRow(displayName: displayName, localIdentifier: identifier,
                                              className: value(.className), notes: value(.notes)))
        }

        var warnings: [String] = []
        if seenNames.values.contains(where: { $0 > 1 }) {
            warnings.append("Duplicate display names detected; use localIdentifier values to distinguish students.")
        }

        return (importRows, RosterImportResult(ignoredBlankColumns: ignoredBlankColumns,
                                               unrecognisedColumns: unrecognised,
                                               skippedRows: skipped,
                                               hasHeaderRow: hasHeader,
                                               warnings: warnings))
    }

    private static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Case- and space-insensitive header comparison.
    private static func normalisedHeader(_ value: String) -> String {
        String(value.lowercased().unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) })
    }
}
