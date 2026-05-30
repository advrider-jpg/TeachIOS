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
        let assignment = ExportFixtureFactory.sensitiveApprovedAssignment(title: "Essay, \"Final\"\nLine", student: "Alice, A")
        let csv = CSVExportService.exportedCSV(from: [assignment])
        let rows = try CSVParser.parseRows(csv)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1][1], "Essay, \"Final\"\nLine")
        XCTAssertEqual(rows[1][5], "Alice, A")
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
    func testExportedCSVQuotesAllCells() throws {
        let csv = CSVExportService.exportedCSV(from: [ExportFixtureFactory.sensitiveApprovedAssignment()])
        for line in csv.components(separatedBy: "\n") where !line.isEmpty {
            XCTAssertTrue(line.hasPrefix("\""))
            XCTAssertTrue(line.hasSuffix("\""))
        }
    }

    func testExportedCSVParsesToExpectedColumnCountForEveryRow() throws {
        let rows = try CSVParser.parseRows(CSVExportService.exportedCSV(from: [ExportFixtureFactory.sensitiveApprovedAssignment()]))
        let count = try XCTUnwrap(rows.first?.count)
        XCTAssertEqual(count, 16)
        XCTAssertTrue(rows.allSatisfy { $0.count == count })
    }

    func testExportedCSVEscapesCommaQuoteAndNewlineInAssignmentTitle() throws {
        let title = "Essay, \"Unit 1\"\nFinal"
        let rows = try CSVParser.parseRows(CSVExportService.exportedCSV(from: [ExportFixtureFactory.sensitiveApprovedAssignment(title: title)]))
        XCTAssertEqual(rows[1][1], title)
    }

    func testExportedCSVNeutralizesFormulaInTitleSubjectClassAndStudentFields() throws {
        var assignment = ExportFixtureFactory.sensitiveApprovedAssignment(title: "=Title")
        assignment.subject = "+Subject"
        assignment.className = " @Class"
        assignment.studentDisplayName = "-Student Name"
        let rows = try CSVParser.parseRows(CSVExportService.exportedCSV(from: [assignment]))
        XCTAssertEqual(rows[1][1], "'=Title")
        XCTAssertEqual(rows[1][2], "'+Subject")
        XCTAssertEqual(rows[1][4], "' @Class")
        XCTAssertEqual(rows[1][5], "'-Student Name")
    }

    func testExportedCSVDoesNotContainPrivateTeacherNotes() {
        XCTAssertFalse(csv().contains(ExportFixtureFactory.privateTeacherNote))
    }

    func testExportedCSVDoesNotContainReviewedStudentText() {
        XCTAssertFalse(csv().contains("REVIEWED_STUDENT_TEXT_SENTINEL"))
    }

    func testExportedCSVDoesNotContainRawOCRText() {
        XCTAssertFalse(csv().contains("RAW_OCR_TEXT_SENTINEL"))
    }

    func testExportedCSVDoesNotContainRawModelResponse() {
        XCTAssertFalse(csv().contains(ExportFixtureFactory.rawModelResponse))
    }

    func testExportedCSVDoesNotContainSourceRelativePath() {
        XCTAssertFalse(csv().contains(ExportFixtureFactory.sourcePath))
    }

    func testExportedCSVDoesNotContainTeacherRationale() {
        XCTAssertFalse(csv().contains(ExportFixtureFactory.teacherRationale))
    }

    func testExportedCSVDoesNotContainAuditEvents() {
        XCTAssertFalse(csv().contains(ExportFixtureFactory.auditEvent))
    }

    func testExportedCSVContainsOnlyExpectedHeaderNames() throws {
        let rows = try CSVParser.parseRows(csv())
        XCTAssertEqual(rows.first, [
            "assignment_id", "title", "subject", "grade_level", "class_name", "student", "assignment_type", "assessment_purpose", "total_score", "max_score", "final_status", "ocr_status", "draft_status", "final_review_stale", "draft_stale", "updated_at"
        ])
    }

    private func csv() -> String {
        CSVExportService.exportedCSV(from: [ExportFixtureFactory.sensitiveApprovedAssignment()])
    }
}

final class RosterCSVHardeningTests: XCTestCase {
    func testRosterImportAcceptsQuotedCommaInDisplayName() {
        let preview = RosterImportService.preview(csvText: "displayName,localIdentifier\n\"Smith, Alice\",A1")
        XCTAssertEqual(preview.students.first?.displayName, "Smith, Alice")
    }

    func testRosterImportAcceptsEscapedQuotesInDisplayName() {
        let preview = RosterImportService.preview(csvText: "displayName,localIdentifier\n\"Alice \"\"AJ\"\" Smith\",A1")
        XCTAssertEqual(preview.students.first?.displayName, "Alice \"AJ\" Smith")
    }

    func testRosterImportPreservesCommaInNotes() {
        let preview = RosterImportService.preview(csvText: "displayName,localIdentifier,className,notes\nAlice,A1,6A,\"Needs seating, extra time\"")
        XCTAssertEqual(preview.students.first?.notes, "Needs seating, extra time")
    }

    func testRosterImportRejectsUnterminatedQuotedField() {
        let preview = RosterImportService.preview(csvText: "displayName\n\"Alice")
        XCTAssertTrue(preview.students.isEmpty)
        XCTAssertFalse(preview.rejectedRows.isEmpty)
    }

    func testRosterImportHeaderlessCSVStillWorks() {
        let preview = RosterImportService.preview(csvText: "Alice\nBob", defaultClassName: "6A")
        XCTAssertEqual(preview.students.map(\.displayName), ["Alice", "Bob"])
        XCTAssertFalse(preview.hasHeaderRow)
    }

    func testRosterImportTrimsDisplayNameAndIdentifier() {
        let preview = RosterImportService.preview(csvText: "displayName,localIdentifier\n Alice , A1 ")
        XCTAssertEqual(preview.students.first?.displayName, "Alice")
        XCTAssertEqual(preview.students.first?.localIdentifier, "A1")
    }

    func testRosterImportDuplicateIdentifierStillRejectsSecondRow() {
        let preview = RosterImportService.preview(csvText: "displayName,localIdentifier\nAlice,A1\nBob,A1")
        XCTAssertEqual(preview.students.count, 1)
        XCTAssertTrue(preview.rejectedRows.first?.contains("Duplicate localIdentifier") == true)
    }

    func testRosterImportDuplicateNameWarningStillUsesLowercaseKey() {
        let preview = RosterImportService.preview(csvText: "displayName,localIdentifier\nAlice,A1\nalice,A2")
        XCTAssertEqual(preview.duplicateNames, ["alice"])
        XCTAssertFalse(preview.warnings.isEmpty)
    }
}
