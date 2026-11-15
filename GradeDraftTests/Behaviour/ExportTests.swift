import Foundation
import Testing
@testable import GradeDraft

struct ExportTests {
    // T5
    @Test func gradebookTotalBlankUntilApprovedCurrentReview() throws {
        let setup = Fixture.setup()
        let draftOnly = Fixture.submission(name: "Ada Lovelace", localID: "A1", setup: setup, state: .draftOnly)
        let approved = Fixture.submission(name: "Grace Hopper", localID: "G2", setup: setup, state: .approvedCurrent)
        let staleApproved = Fixture.submission(name: "Alan Turing", localID: "T3", setup: setup, state: .approvedStale)

        let csv = CSVExportService.gradebookCSV(setup: setup, submissions: [draftOnly, approved, staleApproved])

        #expect(csv.hasPrefix("\u{FEFF}"))
        #expect(csv.hasSuffix("\r\n"))
        // Every row ends CRLF and no bare LF is used as a row separator.
        #expect(csv.replacingOccurrences(of: "\r\n", with: "").contains("\n") == false)

        let rows = try CSVParser.parseRows(String(csv.dropFirst()))
        #expect(rows[0] == ["student", "local_id", "status", "total_score", "max_score", "ai_draft_suggestion"])
        // Draft only: no total, the model's 17 shown only as a suggestion.
        #expect(rows[1] == ["Ada Lovelace", "A1", "pending_final_review", "", "20", "17"])
        // Approved and current: the teacher's total.
        #expect(rows[2] == ["Grace Hopper", "G2", "approved", "17", "20", "17"])
        // Approved but stale: no total.
        #expect(rows[3] == ["Alan Turing", "T3", "stale_review", "", "20", "17"])

        // A name or id that starts with a tab or carriage return (or a formula character) is neutralised.
        let hostile = Fixture.submission(name: "\t=cmd", localID: "\rid", setup: setup, state: .draftOnly)
        let hostileCSV = CSVExportService.gradebookCSV(setup: setup, submissions: [hostile])
        #expect(hostileCSV.contains("\"'\t=cmd\""))
        #expect(hostileCSV.contains("\"'\rid\""))
    }

    // T13
    @Test func reportEscapesMarkdownInStudentText() {
        let setup = Fixture.setup()
        let studentText = "# of apples = 12\n- 3 = 5"
        let submission = Fixture.submission(name: "Ada Lovelace", localID: "A1", setup: setup, state: .draftOnly, pastedText: studentText)

        let markdown = MarkdownRenderer.render(
            ReportBuilder.teacherRecord(setup: setup, submission: submission, generatedAt: Date(timeIntervalSince1970: 0))
        )

        #expect(markdown.contains("```text\n\(studentText)\n```"))

        // Outside the fenced block, no line is a heading or bullet made from the student's words.
        var insideFence = false
        for line in markdown.components(separatedBy: "\n") {
            if line.hasPrefix("```") { insideFence.toggle(); continue }
            if insideFence { continue }
            #expect(line != "# of apples = 12")
            #expect(line != "- 3 = 5")
        }
    }
}

// MARK: - Inputs

private enum Fixture {
    enum State { case draftOnly, approvedCurrent, approvedStale }

    static let date = Date(timeIntervalSince1970: 1_700_000_000)
    static let classID = UUID()
    static let assignmentID = UUID()

    static func setup() -> AssignmentSetup {
        let rubric = ParsedRubric(criteria: [
            RubricCriterion(id: "ideas", title: "Ideas", maxPoints: 10, descriptor: "Ideas: 10 points", sortOrder: 0),
            RubricCriterion(id: "clarity", title: "Clarity", maxPoints: 10, descriptor: "Clarity: 10 points", sortOrder: 1)
        ])
        let assignment = Assignment(
            id: assignmentID,
            classGroupID: classID,
            title: "Fraction essay",
            prompt: "",
            subject: "Maths",
            gradeLevel: "Year 7",
            assessmentPurpose: .summative,
            curriculumReference: "",
            assignmentType: .essay,
            rubricText: "Ideas: 10 points\nClarity: 10 points",
            rubricImportMode: .teacherConfirmed,
            confirmedRubric: rubric,
            customInstructions: "",
            constraintTemplateIDs: [],
            answerKeyText: "",
            exemplarText: "",
            formativeFocusText: "",
            createdAt: date,
            updatedAt: date
        )
        return AssignmentSetup(assignment: assignment, appliedTemplates: [], curriculumMappings: [])
    }

    static func submission(
        name: String,
        localID: String,
        setup: AssignmentSetup,
        state: State,
        pastedText: String = "Fractions are parts of a whole."
    ) -> SubmissionGraph {
        let studentID = UUID()
        let submissionID = UUID()
        var graph = SubmissionGraph(
            submission: Submission(
                id: submissionID,
                assignmentID: assignmentID,
                studentID: studentID,
                inputKind: .pasted,
                pastedText: pastedText,
                createdAt: date,
                updatedAt: date
            ),
            student: Student(
                id: studentID,
                displayName: name,
                localIdentifier: localID,
                notes: "",
                isActive: true,
                createdAt: date,
                updatedAt: date
            ),
            sources: [],
            ocr: nil,
            draft: nil,
            finalReview: nil,
            evidence: [],
            exports: [],
            audit: []
        )

        // Draft: 10 + 7 = 17 of 20, written by the model.
        graph.draft = GradeDraftResult(
            id: UUID(),
            generatedAt: date,
            packetFingerprint: graph.packetFingerprint(setup: setup),
            status: .generated,
            studentResponseSummary: "",
            criteria: [
                CriterionScore(id: UUID(), criterionID: "ideas", rating: "Strong", proposedPoints: 10, evidenceQuotes: [], explanation: "Clear.", teacherReviewRequired: false, nextStep: "", confidence: "high", uncertaintyFlags: []),
                CriterionScore(id: UUID(), criterionID: "clarity", rating: "Good", proposedPoints: 7, evidenceQuotes: [], explanation: "Mostly clear.", teacherReviewRequired: false, nextStep: "", confidence: "medium", uncertaintyFlags: [])
            ],
            studentFeedback: "Draft feedback.",
            teacherNotes: "",
            uncertaintyFlags: [],
            complianceFlags: [],
            modelAudit: nil
        )

        guard state != .draftOnly else { return graph }

        // Final review: the teacher also gives 10 + 7.
        let fingerprint = state == .approvedCurrent ? graph.packetFingerprint(setup: setup) : "fingerprint-from-before-an-edit"
        graph.finalReview = FinalGradeReview(
            id: UUID(),
            createdAt: date,
            finalizedAt: date,
            packetFingerprint: fingerprint,
            status: .approved,
            criteria: [
                FinalCriterionScore(id: UUID(), criterionID: "ideas", rating: "Strong", proposedPoints: 10, finalPoints: 10, explanation: "Clear.", teacherApproved: true, teacherRationale: "", evidenceIDs: []),
                FinalCriterionScore(id: UUID(), criterionID: "clarity", rating: "Good", proposedPoints: 7, finalPoints: 7, explanation: "Mostly clear.", teacherApproved: true, teacherRationale: "", evidenceIDs: [])
            ],
            studentFeedback: "Well done.",
            privateTeacherNotes: "",
            teacherEdited: false
        )
        return graph
    }
}
