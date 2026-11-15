import Foundation
import Testing
@testable import GradeDraft

struct RosterTests {
    @Test(arguments: [String.Encoding.utf8, .windowsCP1252])
    func rosterImportHandlesBlankDuplicateHeadersBOMAndWindowsEncoding(encoding: String.Encoding) throws {
        // A byte-order mark exists only in UTF-8; Windows-1252 cannot represent it.
        let bom = encoding == .utf8 ? "\u{FEFF}" : ""
        let text = bom + "First Name,Surname,,Notes,notes\r\nZoë,Nguyen,,a,b"
        let data = try #require(text.data(using: encoding))

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RosterTests-\(UUID().uuidString).csv")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let (rows, result) = try RosterImportService.parse(fileAt: url)

        #expect(rows.count == 1)
        let student = try #require(rows.first)
        #expect(student.displayName == "Zoë Nguyen")
        #expect(student.notes == "a")
        #expect(result.ignoredBlankColumns == 1)
        #expect(result.unrecognisedColumns == ["notes (repeated)"])
        #expect(result.skippedRows.isEmpty)
    }
}
