import XCTest
@testable import GradeDraft

// MARK: - CSVExportService edge cases

final class CSVExportServiceHardeningTests: XCTestCase {
    func testEmptySubmissionListProducesHeaderOnly() throws {
        let fixture = try ExportFixtureFactory.baseAssignment()
        let rows = try parsedRows(setup: fixture.setup, submissions: [])
        XCTAssertEqual(rows.count, 1, "Should only have header row")
        XCTAssertTrue(rows[0].contains("student"))
    }

    func testMultipleStudentsProduceMultipleRows() throws {
        let first = try ExportFixtureFactory.baseAssignment(student: "A")
        var second = first
        second.submission.student = Student(displayName: "B")
        second.submission.submission.studentID = second.submission.student.id
        let rows = try parsedRows(setup: first.setup, submissions: [first.submission, second.submission])
        XCTAssertEqual(rows.count, 3, "Header + 2 data rows")
    }

    func testCSVOutputHasCorrectHeaderColumns() throws {
        let fixture = try ExportFixtureFactory.baseAssignment()
        let csv = CSVExportService.gradebookCSV(setup: fixture.setup, submissions: [])
        let rows = try CSVParser.parseRows(String(csv.dropFirst()))
        XCTAssertEqual(rows.first?.first, "student")
        XCTAssertTrue(rows.first?.contains("status") == true)
        XCTAssertTrue(rows.first?.contains("total_score") == true)
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}\"student\""))
    }

    func testCSVNoPrivateNotesExposed() throws {
        var fixture = try ExportFixtureFactory.draftOnlyAssignment()
        fixture.submission.draft?.teacherNotes = "SECRET PRIVATE NOTE"
        let csv = CSVExportService.gradebookCSV(setup: fixture.setup, submissions: [fixture.submission])
        XCTAssertFalse(csv.contains("SECRET PRIVATE NOTE"))
    }

    func testNoDraftAndNoFinalReviewIsPendingWithBlankSuggestion() throws {
        let fixture = try ExportFixtureFactory.baseAssignment()
        let rows = try parsedRows(setup: fixture.setup, submissions: [fixture.submission])
        XCTAssertEqual(rows[1][2], "pending_final_review")
        XCTAssertEqual(rows[1][5], "")
    }

    func testInProgressFinalStatus() throws {
        let fixture = try ExportFixtureFactory.inProgressFinalReviewAssignment()
        let rows = try parsedRows(setup: fixture.setup, submissions: [fixture.submission])
        XCTAssertEqual(rows[1][2], "in_progress")
    }

    /// The file starts with a byte-order mark, which the parser does not read.
    private func parsedRows(setup: AssignmentSetup, submissions: [SubmissionGraph]) throws -> [[String]] {
        try CSVParser.parseRows(String(CSVExportService.gradebookCSV(setup: setup, submissions: submissions).dropFirst()))
    }
}
