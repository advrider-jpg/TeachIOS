import XCTest
@testable import GradeDraft

// MARK: - Export report content hardening

final class ExportReportHardeningTests: XCTestCase {
    func testStudentReportDoesNotContainRawModelResponse() {
        var assignment = AssignmentRecord(title: "Export test", reviewedStudentText: "Student text")
        assignment.rubricText = "Claim: 0-4 points"
        assignment.latestDraft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "Feedback",
            teacherNotes: "Private model note",
            uncertaintyFlags: [],
            rawModelResponse: "Raw JSON blob"
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim", rating: "", proposedPoints: 0, finalPoints: 3,
                maxPoints: 4, evidence: [], explanation: "", teacherApproved: true
            )],
            totalScore: 3, maxScore: 4, studentFeedback: "Final feedback",
            privateTeacherNotes: "Secret teacher note", teacherEdited: true
        )
        let report = MarkdownReportBuilder.studentMarkdown(for: assignment)
        XCTAssertFalse(report.contains("Raw JSON blob"))
        XCTAssertFalse(report.contains("Secret teacher note"))
        XCTAssertFalse(report.contains("Private model note"))
        XCTAssertTrue(report.contains("Final feedback"))
    }

    func testTeacherAuditContainsAuditEvents() {
        var assignment = AssignmentRecord(title: "Review history test")
        assignment.appendAuditEvent(.assignmentCreated, detail: "Created for testing.")
        assignment.appendAuditEvent(.inputChanged, detail: "Rubric changed.")
        let audit = MarkdownReportBuilder.teacherAuditMarkdown(for: assignment)
        XCTAssertTrue(audit.contains("Created for testing."))
        XCTAssertTrue(audit.contains("Rubric changed."))
    }

    func testTeacherAuditContainsSourceInputs() {
        var assignment = AssignmentRecord(title: "Source test")
        assignment.sourceInputs = [
            SourceInputRef(sourceType: .scan, localRelativePath: "Sources/scan1.png", contentDigest: "test-digest", digestAlgorithm: "fnv1a64")
        ]
        let audit = MarkdownReportBuilder.teacherAuditMarkdown(for: assignment)
        XCTAssertTrue(audit.contains("scan1.png") || audit.contains("Document scan"))
    }

    func testStudentReportForAssignmentWithNoGrade() {
        let assignment = AssignmentRecord(title: "No grade", reviewedStudentText: "text")
        let report = MarkdownReportBuilder.studentMarkdown(for: assignment)
        XCTAssertTrue(report.contains("No final teacher-approved grade is available"))
    }

    func testStudentReportForDraftOnlyAssignmentExcludesDraftContentByDefault() {
        var assignment = AssignmentRecord(title: "Draft only", reviewedStudentText: "text")
        assignment.latestDraft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [CriterionScore(
                criterion: "Claim", rating: "Good", proposedPoints: 3, maxPoints: 4,
                evidence: ["quote"], explanation: "Met.", teacherReviewRequired: false
            )],
            totalScore: 3, maxScore: 4,
            studentFeedback: "Good work", teacherNotes: "Private", uncertaintyFlags: []
        )
        let report = MarkdownReportBuilder.studentMarkdown(for: assignment)
        XCTAssertTrue(report.contains("No final teacher-approved grade is available"))
        XCTAssertFalse(report.contains("Draft grade for teacher review"))
        XCTAssertFalse(report.contains("Good work"))
        XCTAssertFalse(report.contains("Private"))
        XCTAssertTrue(MarkdownReportBuilder.teacherAuditMarkdown(for: assignment).contains("Good work"))
    }
}
