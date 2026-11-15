import XCTest
@testable import GradeDraft

extension GradeDraftTests {
    func testNoProhibitedLabelsInVisibleCopy() {
        let prohibitedTerms = [
            "auto-grade",
            "Auto-grade",
            "AutoGrade",
            "Accept AI grade",
            "Accept AI Grade",
            "AI final grade",
            "AI Final Grade",
            "one-click grade",
            "One-click Grade",
            "Guaranteed Score",
            "guaranteed score"
        ]

        // Check all built-in template names and instructions
        for template in RubricTemplates.builtIn {
            for term in prohibitedTerms {
                XCTAssertFalse(template.name.contains(term),
                               "Template name '\(template.name)' must not contain '\(term)'")
                XCTAssertFalse(template.customInstructions.contains(term),
                               "Template \(template.id) instructions must not contain '\(term)'")
            }
        }

        // Check error messages
        let errorMessages = [
            GradeDraftError.missingRubric.localizedDescription,
            GradeDraftError.missingStudentText.localizedDescription,
            GradeDraftError.ocrReviewRequired.localizedDescription
        ]
        for msg in errorMessages {
            for term in prohibitedTerms {
                XCTAssertFalse(msg.contains(term),
                               "Error message '\(msg)' must not contain '\(term)'")
            }
        }
    }

    /// Editing the rubric text returns the rubric to automatic reading and drops the confirmed structure. The
    /// draft and final review stay on record and are marked as needing recheck (they are no longer deleted).
    func testManualEditResetsToAutomatic() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Student text") { assignment in
            assignment.rubricImportMode = .structuredConfirmed
            assignment.confirmedRubric = ParsedRubric(criteria: [], issues: [], groups: [])
        }
        let database = try app.requireDatabase()
        let before = try await database.assignmentSetup(id: seeded.assignmentID)
        XCTAssertEqual(before?.assignment.rubricImportMode, .structuredConfirmed)
        let fingerprint = try await TestApp.fingerprint(app, seeded)
        try await database.replaceDraft(
            GradeDraftResult(
                packetFingerprint: fingerprint, studentResponseSummary: "Summary", criteria: [],
                studentFeedback: "Draft", teacherNotes: "Note", uncertaintyFlags: []
            ),
            submissionID: seeded.submissionID
        )
        try await database.saveFinalReview(
            FinalGradeReview(
                packetFingerprint: fingerprint, status: .approved, criteria: [],
                studentFeedback: "Final", privateTeacherNotes: "Note", teacherEdited: true
            ),
            submissionID: seeded.submissionID
        )
        let model = try await openSetupModel(app, seeded.assignmentID)

        model.edit { $0.assignment.rubricText = "New rubric text" }
        await model.flushPendingEdits()

        let setupSaved = try await database.assignmentSetup(id: seeded.assignmentID)
        let setup = try XCTUnwrap(setupSaved)
        let graphSaved = try await database.submission(id: seeded.submissionID)
        let graph = try XCTUnwrap(graphSaved)
        XCTAssertEqual(setup.assignment.rubricImportMode, .automatic)
        XCTAssertNil(setup.assignment.confirmedRubric)
        XCTAssertNotNil(graph.draft)
        XCTAssertNotNil(graph.finalReview)
        XCTAssertTrue(try graph.draftIsStale(setup: setup))
        XCTAssertTrue(try graph.finalReviewIsStale(setup: setup))
    }
}
