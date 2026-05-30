import Foundation

enum CSVWriter {
    static func string(rows: [[String]], rowSeparator: String = "\n") -> String {
        guard !rows.isEmpty else { return "" }
        return rows
            .map { row in row.map(quotedCell).joined(separator: ",") }
            .joined(separator: rowSeparator)
    }

    static func quotedCell(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

enum CSVParser {
    struct ParseError: LocalizedError, Equatable {
        var message: String
        var errorDescription: String? { message }
    }

    static func parseRows(_ csvText: String) throws -> [[String]] {
        let normalizedCSVText = csvText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        guard !normalizedCSVText.isEmpty else { return [] }

        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var fieldStartedWithQuote = false
        var index = normalizedCSVText.startIndex

        func appendField() {
            row.append(field)
            field = ""
            fieldStartedWithQuote = false
        }

        func appendRow() {
            appendField()
            rows.append(row)
            row = []
        }

        while index < normalizedCSVText.endIndex {
            let character = normalizedCSVText[index]
            let nextIndex = normalizedCSVText.index(after: index)

            if inQuotes {
                if character == "\"" {
                    if nextIndex < normalizedCSVText.endIndex, normalizedCSVText[nextIndex] == "\"" {
                        field.append("\"")
                        index = normalizedCSVText.index(after: nextIndex)
                    } else {
                        inQuotes = false
                        index = nextIndex
                    }
                } else {
                    field.append(character)
                    index = nextIndex
                }
                continue
            }

            switch character {
            case "\"":
                if field.isEmpty && !fieldStartedWithQuote {
                    inQuotes = true
                    fieldStartedWithQuote = true
                } else {
                    field.append(character)
                }
                index = nextIndex
            case ",":
                appendField()
                index = nextIndex
            case "\n":
                appendRow()
                index = nextIndex
            case "\r":
                appendRow()
                if nextIndex < normalizedCSVText.endIndex, normalizedCSVText[nextIndex] == "\n" {
                    index = normalizedCSVText.index(after: nextIndex)
                } else {
                    index = nextIndex
                }
            default:
                field.append(character)
                index = nextIndex
            }
        }

        if inQuotes {
            throw ParseError(message: "CSV contains an unterminated quoted field.")
        }

        if !field.isEmpty || !row.isEmpty || fieldStartedWithQuote || normalizedCSVText.hasSuffix(",") {
            appendField()
            rows.append(row)
        }

        return rows
    }
}
