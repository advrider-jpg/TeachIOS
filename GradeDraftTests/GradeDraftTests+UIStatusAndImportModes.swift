import XCTest
import ZIPFoundation
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

    @MainActor
    func testManualEditResetsToAutomatic() {
        var assignment = AssignmentRecord(title: "Test")
        assignment.rubricImportMode = .structuredConfirmed
        assignment.confirmedParsedRubric = ParsedRubric(criteria: [], issues: [], groups: [])
        assignment.latestDraft = GradeDraftResult(
            packetFingerprint: "old-packet",
            studentResponseSummary: "Summary",
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "Draft",
            teacherNotes: "Note",
            uncertaintyFlags: []
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: "old-packet",
            status: .approved,
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "Final",
            privateTeacherNotes: "Note",
            teacherEdited: true
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)
        vm.updateRubricText("New rubric text")
        XCTAssertEqual(vm.assignment.rubricImportMode, .automatic)
        XCTAssertNil(vm.assignment.confirmedParsedRubric)
        XCTAssertNotNil(vm.assignment.latestDraft)
        XCTAssertNotNil(vm.assignment.finalReview)
        XCTAssertTrue(vm.assignment.latestDraftIsStale)
        XCTAssertTrue(vm.assignment.finalReviewIsStale)
    }
}
