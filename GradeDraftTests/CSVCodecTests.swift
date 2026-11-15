import XCTest
@testable import GradeDraft

final class CSVWriterTests: XCTestCase {
    func testQuotesEveryCellIncludingHeaders() throws {
        let csv = CSVWriter.string(rows: [["assignment_id", "title"], ["1", "Essay"]])
        XCTAssertEqual(csv, "\"assignment_id\",\"title\"\n\"1\",\"Essay\"")
    }

    func testEscapesEmbeddedQuotes() throws {
        XCTAssertEqual(CSVWriter.quotedCell("Alice \"AJ\" Smith"), "\"Alice \"\"AJ\"\" Smith\"")
    }

    func testPreservesCommasInsideCells() throws {
        let rows = try CSVParser.parseRows(CSVWriter.string(rows: [["Smith, Alice", "6A"]]))
        XCTAssertEqual(rows, [["Smith, Alice", "6A"]])
    }

    func testPreservesNewlinesInsideCells() throws {
        let rows = try CSVParser.parseRows(CSVWriter.string(rows: [["Line 1\nLine 2", "Feedback"]]))
        XCTAssertEqual(rows[0][0], "Line 1\nLine 2")
    }

    func testRoundTripsRepresentativeGradebookRowsThroughParser() throws {
        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment(student: "Alice, \"AJ\"\nLine")
        let rows = try gradebookRows([fixture])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1][0], "Alice, \"AJ\"\nLine")
    }

    func testEmptyRowsProduceEmptyString() {
        XCTAssertEqual(CSVWriter.string(rows: []), "")
    }

    func testEmptyCellIsQuotedEmptyString() {
        XCTAssertEqual(CSVWriter.string(rows: [[""]]), "\"\"")
    }

    func testWriterUsesStableRowSeparator() {
        XCTAssertEqual(CSVWriter.string(rows: [["a"], ["b"]], rowSeparator: "\r\n"), "\"a\"\r\n\"b\"")
    }

    func testParserHandlesCRLF() throws {
        let rows = try CSVParser.parseRows("\"a\",\"b\"\r\n\"c\",\"d\"")
        XCTAssertEqual(rows, [["a", "b"], ["c", "d"]])
    }

    func testParserThrowsOnUnterminatedQuotedField() {
        XCTAssertThrowsError(try CSVParser.parseRows("\"Alice"))
    }
}

final class SpreadsheetSafetyFormulaInjectionTests: XCTestCase {
    func testEscapesEqualsFormula() { XCTAssertEqual(SpreadsheetSafety.sanitizedCell("=1+1"), "'=1+1") }
    func testEscapesPlusFormula() { XCTAssertEqual(SpreadsheetSafety.sanitizedCell("+CMD"), "'+CMD") }
    func testEscapesMinusFormulaText() { XCTAssertEqual(SpreadsheetSafety.sanitizedCell("-SUM(A1:A2)"), "'-SUM(A1:A2)") }
    func testEscapesAtFormula() { XCTAssertEqual(SpreadsheetSafety.sanitizedCell("@hidden"), "'@hidden") }
    func testEscapesLeadingSpaceFormula() { XCTAssertEqual(SpreadsheetSafety.sanitizedCell("  =SUM(A1)"), "'  =SUM(A1)") }
    func testEscapesLeadingTabFormula() { XCTAssertEqual(SpreadsheetSafety.sanitizedCell("\t=SUM(A1)"), "'\t=SUM(A1)") }
    func testPreservesNegativeInteger() { XCTAssertEqual(SpreadsheetSafety.sanitizedCell("-12"), "-12") }
    func testPreservesNegativeDecimal() { XCTAssertEqual(SpreadsheetSafety.sanitizedCell("-12.5"), "-12.5") }
    func testPreservesPositiveIntegerWithPlusIfDoubleRecognizesIt() { XCTAssertEqual(SpreadsheetSafety.sanitizedCell("+12"), "+12") }
    func testDoesNotDoubleEscapeApostrophePrefixedFormula() { XCTAssertEqual(SpreadsheetSafety.sanitizedCell("'=1+1"), "'=1+1") }
    func testWhitespaceOnlyUnchanged() { XCTAssertEqual(SpreadsheetSafety.sanitizedCell("   \t"), "   \t") }
    func testNormalTextUnchanged() { XCTAssertEqual(SpreadsheetSafety.sanitizedCell("Normal text"), "Normal text") }
}

final class CSVExportServicePrivacyTests: XCTestCase {
    func testGradebookCSVQuotesAllCells() throws {
        let csv = try makeCSV()
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}"))
        for line in csv.dropFirst().components(separatedBy: "\r\n") where !line.isEmpty {
            XCTAssertTrue(line.hasPrefix("\""))
            XCTAssertTrue(line.hasSuffix("\""))
        }
    }

    func testGradebookCSVParsesToExpectedColumnCountForEveryRow() throws {
        let rows = try gradebookRows([ExportFixtureFactory.sensitiveApprovedAssignment()])
        let count = try XCTUnwrap(rows.first?.count)
        XCTAssertEqual(count, 6)
        XCTAssertTrue(rows.allSatisfy { $0.count == count })
    }

    func testGradebookCSVEscapesCommaQuoteAndNewlineInStudentName() throws {
        let name = "Essay, \"Unit 1\"\nFinal"
        let rows = try gradebookRows([ExportFixtureFactory.sensitiveApprovedAssignment(student: name)])
        XCTAssertEqual(rows[1][0], name)
    }

    func testGradebookCSVNeutralizesFormulaInStudentFields() throws {
        var fixture = try ExportFixtureFactory.sensitiveApprovedAssignment()
        fixture.submission.student.displayName = "-Student Name"
        fixture.submission.student.localIdentifier = " @Class"
        let rows = try gradebookRows([fixture])
        XCTAssertEqual(rows[1][0], "'-Student Name")
        XCTAssertEqual(rows[1][1], "' @Class")
    }

    func testGradebookCSVDoesNotContainPrivateTeacherNotes() throws {
        XCTAssertFalse(try makeCSV().contains(ExportFixtureFactory.privateTeacherNote))
    }

    func testGradebookCSVDoesNotContainReviewedStudentText() throws {
        XCTAssertFalse(try makeCSV().contains(ExportFixtureFactory.reviewedTextSentinel))
    }

    func testGradebookCSVDoesNotContainRawOCRText() throws {
        XCTAssertFalse(try makeCSV().contains(ExportFixtureFactory.rawOCRTextSentinel))
    }

    func testGradebookCSVDoesNotContainSourceRelativePath() throws {
        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment()
        let csv = CSVExportService.gradebookCSV(setup: fixture.setup, submissions: [fixture.submission])
        XCTAssertFalse(csv.contains(try XCTUnwrap(fixture.sourceRelativePath)))
        XCTAssertFalse(csv.contains(ExportFixtureFactory.sourceFileName))
    }

    func testGradebookCSVDoesNotContainTeacherRationale() throws {
        XCTAssertFalse(try makeCSV().contains(ExportFixtureFactory.teacherRationale))
    }

    func testGradebookCSVDoesNotContainAuditEvents() throws {
        XCTAssertFalse(try makeCSV().contains(ExportFixtureFactory.auditEvent))
    }

    func testGradebookCSVContainsOnlyExpectedHeaderNames() throws {
        let rows = try gradebookRows([ExportFixtureFactory.sensitiveApprovedAssignment()])
        XCTAssertEqual(rows.first, ["student", "local_id", "status", "total_score", "max_score", "ai_draft_suggestion"])
    }

    private func makeCSV() throws -> String {
        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment()
        return CSVExportService.gradebookCSV(setup: fixture.setup, submissions: [fixture.submission])
    }
}

final class RosterCSVHardeningTests: XCTestCase {
    func testRosterImportAcceptsQuotedCommaInDisplayName() {
        let parsed = RosterImportService.parse(text: "displayName,localIdentifier\n\"Smith, Alice\",A1")
        XCTAssertEqual(parsed.rows.first?.displayName, "Smith, Alice")
    }

    func testRosterImportAcceptsEscapedQuotesInDisplayName() {
        let parsed = RosterImportService.parse(text: "displayName,localIdentifier\n\"Alice \"\"AJ\"\" Smith\",A1")
        XCTAssertEqual(parsed.rows.first?.displayName, "Alice \"AJ\" Smith")
    }

    func testRosterImportPreservesCommaInNotes() {
        let parsed = RosterImportService.parse(text: "displayName,localIdentifier,className,notes\nAlice,A1,6A,\"Needs seating, extra time\"")
        XCTAssertEqual(parsed.rows.first?.notes, "Needs seating, extra time")
    }

    func testRosterImportRejectsUnterminatedQuotedField() {
        let parsed = RosterImportService.parse(text: "displayName\n\"Alice")
        XCTAssertTrue(parsed.rows.isEmpty)
        XCTAssertFalse(parsed.result.skippedRows.isEmpty)
    }

    func testRosterImportHeaderlessCSVStillWorks() {
        let parsed = RosterImportService.parse(text: "Alice\nBob")
        XCTAssertEqual(parsed.rows.map(\.displayName), ["Alice", "Bob"])
        XCTAssertFalse(parsed.result.hasHeaderRow)
    }

    func testRosterImportTrimsDisplayNameAndIdentifier() {
        let parsed = RosterImportService.parse(text: "displayName,localIdentifier\n Alice , A1 ")
        XCTAssertEqual(parsed.rows.first?.displayName, "Alice")
        XCTAssertEqual(parsed.rows.first?.localIdentifier, "A1")
    }

    func testRosterImportDuplicateIdentifierStillRejectsSecondRow() {
        let parsed = RosterImportService.parse(text: "displayName,localIdentifier\nAlice,A1\nBob,A1")
        XCTAssertEqual(parsed.rows.count, 1)
        XCTAssertTrue(parsed.result.skippedRows.first?.contains("repeats the identifier") == true)
    }

    func testRosterImportDuplicateNameWarningStillUsesLowercaseKey() {
        let parsed = RosterImportService.parse(text: "displayName,localIdentifier\nAlice,A1\nalice,A2")
        XCTAssertEqual(parsed.rows.count, 2)
        XCTAssertEqual(parsed.result.warnings, ["Duplicate display names detected; use localIdentifier values to distinguish students."])
    }
}

/// Parses a gradebook CSV. The file starts with a byte-order mark, which the parser does not read.
private func gradebookRows(_ fixtures: [ExportFixture]) throws -> [[String]] {
    let first = try XCTUnwrap(fixtures.first)
    let csv = CSVExportService.gradebookCSV(setup: first.setup, submissions: fixtures.map(\.submission))
    return try CSVParser.parseRows(String(csv.dropFirst()))
}
