import XCTest
@testable import GradeDraft

// MARK: - CSVExportService edge cases

final class CSVExportServiceHardeningTests: XCTestCase {
    func testEmptyAssignmentListProducesHeaderOnly() {
        let rows = CSVExportService.buildStudentRows(from: [])
        XCTAssertEqual(rows.count, 1, "Should only have header row")
        XCTAssertTrue(rows[0].contains("assignment_id"))
    }

    func testMultipleAssignmentsProduceMultipleRows() {
        let assignmentA = AssignmentRecord(title: "A", rubricText: "Claim: 0-4 points", reviewedStudentText: "text")
        let assignmentB = AssignmentRecord(title: "B", rubricText: "Evidence: 0-2 points", reviewedStudentText: "text")
        let rows = CSVExportService.buildStudentRows(from: [assignmentA, assignmentB])
        XCTAssertEqual(rows.count, 3, "Header + 2 data rows")
    }

    func testCSVOutputHasCorrectHeaderColumns() throws {
        let csv = CSVExportService.exportedCSV(from: [])
        let rows = try CSVParser.parseRows(csv)
        XCTAssertEqual(rows.first?.first, "assignment_id")
        XCTAssertTrue(rows.first?.contains("final_status") == true)
        XCTAssertTrue(rows.first?.contains("ocr_status") == true)
        XCTAssertTrue(csv.hasPrefix("\"assignment_id\""))
    }

    func testCSVNoPrivateNotesExposed() {
        var assignment = AssignmentRecord(title: "Test")
        assignment.reviewedStudentText = "text"
        assignment.rubricText = "Claim: 0-4 points"
        assignment.latestDraft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "",
            teacherNotes: "SECRET PRIVATE NOTE",
            uncertaintyFlags: []
        )
        let csv = CSVExportService.exportedCSV(from: [assignment])
        XCTAssertFalse(csv.contains("SECRET PRIVATE NOTE"))
    }

    func testDraftStatusNotGenerated() {
        let assignment = AssignmentRecord(title: "No draft")
        let rows = CSVExportService.buildStudentRows(from: [assignment])
        XCTAssertEqual(rows[1][12], "not_generated")
    }

    func testInProgressFinalStatus() {
        var assignment = AssignmentRecord(title: "In progress")
        assignment.rubricText = "Claim: 0-4 points"
        assignment.reviewedStudentText = "text"
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [FinalCriterionScore(
                criterion: "Claim", rating: "", proposedPoints: 0, finalPoints: 2,
                maxPoints: 4, evidence: [], explanation: "", teacherApproved: false
            )],
            totalScore: 2, maxScore: 4, studentFeedback: "", privateTeacherNotes: "", teacherEdited: false
        )
        let rows = CSVExportService.buildStudentRows(from: [assignment])
        XCTAssertEqual(rows[1][10], "in_progress")
    }
}
