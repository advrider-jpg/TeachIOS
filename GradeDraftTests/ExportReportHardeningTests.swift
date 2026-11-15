import XCTest
@testable import GradeDraft

// MARK: - Export report content hardening

final class ExportReportHardeningTests: XCTestCase {
    func testStudentReportDoesNotContainPrivateNotesOrModelNotes() throws {
        var fixture = try ExportFixtureFactory.baseAssignment(title: "Export test")
        let fingerprint = try fixture.currentFingerprint()
        fixture.submission.draft = GradeDraftResult(
            packetFingerprint: fingerprint,
            studentResponseSummary: "Summary",
            criteria: [],
            studentFeedback: "Feedback",
            teacherNotes: "Private model note",
            uncertaintyFlags: []
        )
        fixture.submission.finalReview = FinalGradeReview(
            finalizedAt: Date(timeIntervalSince1970: 1_700_000_000),
            packetFingerprint: fingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterionID: fixture.criterionID, rating: "", proposedPoints: 0, finalPoints: 3,
                explanation: "", teacherApproved: true
            )],
            studentFeedback: "Final feedback",
            privateTeacherNotes: "Secret teacher note",
            teacherEdited: true
        )

        let report = try fixture.studentReportMarkdown()

        XCTAssertFalse(report.contains("Secret teacher note"))
        XCTAssertFalse(report.contains("Private model note"))
        XCTAssertTrue(report.contains("Final feedback"))
    }

    func testTeacherRecordContainsAuditEvents() throws {
        var fixture = try ExportFixtureFactory.baseAssignment(title: "Review history test")
        fixture.submission.audit = [
            AuditEvent(assignmentID: fixture.setup.id, submissionID: fixture.submission.submission.id, eventType: .assignmentCreated, detail: "Created for testing."),
            AuditEvent(assignmentID: fixture.setup.id, submissionID: fixture.submission.submission.id, eventType: .inputChanged, detail: "Rubric changed.")
        ]

        let record = fixture.teacherRecordMarkdown()

        XCTAssertTrue(record.contains("Created for testing."))
        XCTAssertTrue(record.contains("Rubric changed."))
    }

    func testTeacherRecordContainsSourceInputs() throws {
        var fixture = try ExportFixtureFactory.baseAssignment(title: "Source test")
        fixture.submission.sources = [
            SourceInputRef(
                submissionID: fixture.submission.submission.id,
                sourceType: .scan,
                localRelativePath: "Sources/\(fixture.submission.submission.id.uuidString)/scan1.png",
                sha256: "test-digest"
            )
        ]

        let record = fixture.teacherRecordMarkdown()

        XCTAssertTrue(record.contains("scan1.png") || record.contains("Document scan"))
    }

    func testStudentReportForSubmissionWithNoGradeIsRefused() throws {
        let fixture = try ExportFixtureFactory.baseAssignment(title: "No grade")
        XCTAssertThrowsError(
            try ReportBuilder.studentReport(setup: fixture.setup, submission: fixture.submission, generatedAt: Date(timeIntervalSince1970: 0))
        ) { error in
            XCTAssertEqual(error as? ReportError, .notApproved)
        }
    }

    func testStudentReportForDraftOnlySubmissionExcludesDraftContentByDefault() throws {
        var fixture = try ExportFixtureFactory.baseAssignment(title: "Draft only")
        fixture.submission.draft = GradeDraftResult(
            packetFingerprint: try fixture.currentFingerprint(),
            studentResponseSummary: "Summary",
            criteria: [CriterionScore(
                criterionID: fixture.criterionID, rating: "Good", proposedPoints: 3,
                evidenceQuotes: ["quote"], explanation: "Met.", teacherReviewRequired: false
            )],
            studentFeedback: "Good work",
            teacherNotes: "Private",
            uncertaintyFlags: []
        )

        XCTAssertThrowsError(
            try ReportBuilder.studentReport(setup: fixture.setup, submission: fixture.submission, generatedAt: Date(timeIntervalSince1970: 0))
        ) { error in
            XCTAssertEqual(error as? ReportError, .notApproved)
        }
        XCTAssertTrue(fixture.teacherRecordMarkdown().contains("Good work"))
    }
}
