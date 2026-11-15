import CoreXLSX
import Foundation

/// Reads the first worksheet of an Excel (.xlsx) file as rows of text, for roster and
/// curriculum/reference imports. Shared strings are resolved; inline-string and number cells
/// come back as their stored text. Rows keep their column positions (blank cells are "").
enum SpreadsheetReader {
    enum ReadError: LocalizedError {
        case unreadable
        case noWorksheet

        var errorDescription: String? {
            switch self {
            case .unreadable: return "This Excel file could not be opened. Check that it is a .xlsx workbook."
            case .noWorksheet: return "This Excel workbook has no worksheet to import."
            }
        }
    }

    static func rows(fromXLSX url: URL) throws -> [[String]] {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let file = XLSXFile(filepath: url.path) else { throw ReadError.unreadable }
        guard let workbook = try file.parseWorkbooks().first,
              let path = try file.parseWorksheetPathsAndNames(workbook: workbook).first?.path else {
            throw ReadError.noWorksheet
        }
        let sharedStrings = try file.parseSharedStrings()
        let worksheet = try file.parseWorksheet(at: path)

        var result: [[String]] = []
        for row in worksheet.data?.rows ?? [] {
            var columns: [String] = []
            for cell in row.cells {
                let index = columnIndex(cell.reference.column.value)
                if columns.count <= index {
                    columns.append(contentsOf: Array(repeating: "", count: index - columns.count + 1))
                }
                columns[index] = text(of: cell, sharedStrings: sharedStrings)
            }
            result.append(columns)
        }
        return result
    }

    private static func text(of cell: Cell, sharedStrings: SharedStrings?) -> String {
        if cell.type == .sharedString {
            guard let sharedStrings, let raw = cell.value, let index = Int(raw),
                  sharedStrings.items.indices.contains(index) else { return "" }
            let item = sharedStrings.items[index]
            return item.text ?? item.richText.compactMap(\.text).joined()
        }
        if let inline = cell.inlineString?.text { return inline }
        return cell.value ?? ""
    }

    /// "A" -> 0, "Z" -> 25, "AA" -> 26.
    private static func columnIndex(_ letters: String) -> Int {
        let number = letters.uppercased().unicodeScalars.reduce(0) { total, scalar in
            total * 26 + Int(scalar.value) - 64
        }
        return max(number - 1, 0)
    }
}
