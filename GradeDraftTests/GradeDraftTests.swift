import XCTest
@testable import GradeDraft

final class InMemoryAssignmentStore: AssignmentStoring {
    private(set) var assignments: [AssignmentRecord]

    init(assignments: [AssignmentRecord] = []) {
        self.assignments = assignments
    }

    func loadAssignments() throws -> [AssignmentRecord] {
        assignments
    }

    func saveAssignments(_ assignments: [AssignmentRecord]) throws {
        self.assignments = assignments
    }

    func deleteAssignment(id: UUID) throws {
        assignments.removeAll { $0.id == id }
    }

    func applicationSupportDirectory() throws -> URL {
        FileManager.default.temporaryDirectory
    }
}

final class GradeDraftTests: XCTestCase {
    func testDeterministicTotalsIgnoreModelTotals() throws {
        let draft = GradeDraftResult(
            packetFingerprint: "packet-1",
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: "claim",
                    criterion: "Claim",
                    rating: "Proficient",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["Clear claim"],
                    explanation: "The response includes a claim.",
                    teacherReviewRequired: false
                ),
                CriterionScore(
                    criterionID: "evidence",
                    criterion: "Evidence",
                    rating: "Developing",
                    proposedPoints: 2,
                    maxPoints: 4,
                    evidence: ["One example"],
                    explanation: "The response has limited evidence.",
                    teacherReviewRequired: true
                )
            ],
            totalScore: 999,
            maxScore: 999,
            studentFeedback: "Feedback",
            teacherNotes: "Notes",
            uncertaintyFlags: []
        )

        let normalized = GradeTotals.applyingDeterministicTotals(to: draft)
        XCTAssertEqual(normalized.totalScore, 5)
        XCTAssertEqual(normalized.maxScore, 8)
    }

    func testFinalReviewTotalsUseTeacherFinalPoints() throws {
        let review = FinalGradeReview(
            packetFingerprint: "packet-1",
            criteria: [
                FinalCriterionScore(
                    criterionID: "claim",
                    criterion: "Claim",
                    rating: "Proficient",
                    proposedPoints: 3,
                    finalPoints: 4,
                    maxPoints: 4,
                    evidence: ["Clear claim"],
                    explanation: "Teacher found the claim complete.",
                    teacherApproved: true
                )
            ],
            totalScore: 999,
            maxScore: 999,
            studentFeedback: "Feedback",
            privateTeacherNotes: "Private",
            teacherEdited: true
        )

        let normalized = GradeTotals.applyingDeterministicTotals(to: review)
        XCTAssertEqual(normalized.totalScore, 4)
        XCTAssertEqual(normalized.maxScore, 4)
    }

    func testValidationBlocksEmptyRubric() throws {
        var input = sampleInput()
        input.rubricText = " "
        input.answerKeyText = " "
        input.exemplarText = " "
        input.hasGradingStandard = false
        XCTAssertThrowsError(try LocalOnlyGradingValidator.validate(input)) { error in
            XCTAssertEqual(error as? GradeDraftError, .missingRubric)
        }
    }

    func testValidationAcceptsAnswerKeyAsGradingStandard() throws {
        var input = sampleInput()
        input.rubricText = " "
        input.answerKeyText = "Students should include two examples."
        input.hasGradingStandard = true
        XCTAssertNoThrow(try LocalOnlyGradingValidator.validate(input))
    }

    func testValidationAcceptsExemplarAsGradingStandard() throws {
        var input = sampleInput()
        input.rubricText = " "
        input.answerKeyText = " "
        input.exemplarText = "Exemplar response content for comparison."
        input.hasGradingStandard = true
        XCTAssertNoThrow(try LocalOnlyGradingValidator.validate(input))
    }

    func testValidationBlocksEmptyStudentText() throws {
        var input = sampleInput()
        input.reviewedStudentText = "  "
        XCTAssertThrowsError(try LocalOnlyGradingValidator.validate(input)) { error in
            XCTAssertEqual(error as? GradeDraftError, .missingStudentText)
        }
    }

    func testValidationBlocksUnreviewedOCR() throws {
        var input = sampleInput()
        input.ocrReviewStatus = .needsReview
        XCTAssertThrowsError(try LocalOnlyGradingValidator.validate(input)) { error in
            XCTAssertEqual(error as? GradeDraftError, .ocrReviewRequired)
        }
    }

    func testJSONExtractorFindsFirstObjectAndIgnoresBracesInStrings() {
        let raw = "Here is the draft:\n```json\n{\"studentResponseSummary\":\"uses { braces } in text\",\"criteria\":[]}\n``` trailing"
        XCTAssertEqual(
            JSONExtractor.extractFirstJSONObject(from: raw),
            "{\"studentResponseSummary\":\"uses { braces } in text\",\"criteria\":[]}"
        )
    }

    func testOCRQualitySummaryFlagsLowConfidenceAndUnconfirmedText() {
        let lines = [
            OCRLine(text: "Strong line", confidence: 0.95, boundingBox: .zero, teacherConfirmed: true),
            OCRLine(text: "Weak line", confidence: 0.42, boundingBox: .zero, teacherConfirmed: false)
        ]
        let summary = OCRQualitySummary(lines: lines)
        XCTAssertEqual(summary.lineCount, 2)
        XCTAssertEqual(summary.lowConfidenceLineCount, 1)
        XCTAssertEqual(summary.unconfirmedLineCount, 1)
        XCTAssertTrue(summary.requiresTeacherOCRReview)
    }

    func testCSVSanitizationEscapesFormulaLikePrefixes() throws {
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("=1+1"), "'=1+1")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("+1-2"), "'+1-2")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("-SUM(A1:A2)"), "'-SUM(A1:A2)")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("@hidden"), "'@hidden")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell(" =1+1"), "' =1+1")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("   @bad"), "'   @bad")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("-"), "'-")
    }

    func testCSVSanitizationPreservesRealNumericValues() throws {
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("42"), "42")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("42.5"), "42.5")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("-12"), "-12")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("-12.5"), "-12.5")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("  -3"), "  -3")
    }

    func testCSVExportBuildRowsUsesFormulaSafeguardsAndOmitsPrivateNotes() throws {
        let draft = GradeDraftResult(
            studentResponseSummary: "Draft summary",
            criteria: [
                CriterionScore(
                    criterionID: "claim",
                    criterion: "Claim",
                    rating: "Proficient",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["Student text"],
                    explanation: "Evidence supports claim.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "Good effort.",
            teacherNotes: "Private grading note.",
            uncertaintyFlags: []
        )

        var assignment = AssignmentRecord(
            title: "=Exploit prompt",
            subject: "+English",
            gradeLevel: "9",
            studentDisplayName: "-Jane",
            assignmentType: .essay
        )
        assignment.latestDraft = draft
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterionID: "claim",
                criterion: "Claim",
                rating: "Proficient",
                proposedPoints: 3,
                finalPoints: 4,
                maxPoints: 4,
                evidence: ["Student text"],
                explanation: "Strong claim.",
                teacherApproved: true
            )],
            totalScore: 4,
            maxScore: 4,
            studentFeedback: "Good.",
            privateTeacherNotes: "Private instructor comment.",
            teacherEdited: true
        )

        let rows = CSVExportService.buildStudentRows(from: [assignment])
        XCTAssertEqual(rows.count, 2)
        let dataRow = rows[1]
        XCTAssertEqual(dataRow[1], "'=Exploit prompt")
        XCTAssertEqual(dataRow[2], "'+English")
        XCTAssertEqual(dataRow[5], "'-Jane")
        XCTAssertEqual(dataRow.count, 16)
        XCTAssertEqual(dataRow[10], "approved")
        XCTAssertEqual(dataRow[11], "notNeeded")
        XCTAssertEqual(dataRow[12], "teacherReviewRequired")
        XCTAssertEqual(dataRow[13], "false")
        XCTAssertEqual(dataRow[14], "false")

        let csv = CSVExportService.exportedCSV(from: [assignment])
        XCTAssertTrue(csv.hasPrefix("assignment_id,title,subject,grade_level,class_name,student,assignment_type,assessment_purpose,total_score,max_score,final_status,ocr_status,draft_status,final_review_stale,draft_stale,updated_at"))
        XCTAssertFalse(csv.contains("Private grading note."))
        XCTAssertFalse(csv.contains("Private instructor comment."))
    }

    @MainActor
    func testCannotApproveFinalReviewWithUnapprovedCriteria() {
        let criterion = FinalCriterionScore(
            criterionID: "claim",
            criterion: "Claim",
            rating: "Developing",
            proposedPoints: 3,
            finalPoints: 3,
            maxPoints: 4,
            evidence: ["Evidence"],
            explanation: "Partially met.",
            teacherApproved: false
        )
        let assignment = AssignmentRecord(
            title: "Essay",
            subject: "ELA",
            gradeLevel: "7",
            studentDisplayName: "Kai",
            assignmentType: .essay,
            reviewedStudentText: "Student response",
            latestDraft: nil,
            finalReview: FinalGradeReview(
                packetFingerprint: "packet-1",
                status: .inProgress,
                criteria: [criterion],
                totalScore: 0,
                maxScore: 0,
                studentFeedback: "Good.",
                privateTeacherNotes: "Hidden",
                teacherEdited: true
            )
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canApproveFinalReview)
        viewModel.approveFinalReview()
        XCTAssertEqual(viewModel.errorMessage, "Approve all final-review criteria before finalizing.")
        XCTAssertEqual(viewModel.assignment.finalReview?.status, .inProgress)
    }

    @MainActor
    func testCanApproveAndPersistFinalReviewWhenAllCriteriaApproved() {
        let criterion = FinalCriterionScore(
            criterionID: "claim",
            criterion: "Claim",
            rating: "Proficient",
            proposedPoints: 3,
            finalPoints: 3,
            maxPoints: 4,
            evidence: ["Evidence"],
            explanation: "Strong claim.",
            teacherApproved: true
        )
        let assignment = AssignmentRecord(
            title: "Essay",
            subject: "ELA",
            gradeLevel: "7",
            studentDisplayName: "Kai",
            assignmentType: .essay,
            reviewedStudentText: "Student response",
            latestDraft: nil,
            finalReview: FinalGradeReview(
                packetFingerprint: "packet-1",
                status: .inProgress,
                criteria: [criterion],
                totalScore: 0,
                maxScore: 0,
                studentFeedback: "Good.",
                privateTeacherNotes: "Hidden",
                teacherEdited: true
            )
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertTrue(viewModel.canApproveFinalReview)
        viewModel.approveFinalReview()
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.assignment.finalReview?.status, .approved)
        XCTAssertNotNil(viewModel.assignment.finalReview?.finalizedAt)
    }

    @MainActor
    func testCannotApproveStaleFinalReview() {
        let staleCriterion = FinalCriterionScore(
            criterionID: "claim",
            criterion: "Claim",
            rating: "Proficient",
            proposedPoints: 3,
            finalPoints: 4,
            maxPoints: 4,
            evidence: ["Evidence"],
            explanation: "Met.",
            teacherApproved: true
        )
        let assignment = AssignmentRecord(
            title: "Essay",
            subject: "ELA",
            gradeLevel: "7",
            studentDisplayName: "Kai",
            assignmentType: .essay,
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "Student response",
            finalReview: FinalGradeReview(
                packetFingerprint: "legacy-packet",
                status: .inProgress,
                criteria: [staleCriterion],
                totalScore: 4,
                maxScore: 4,
                studentFeedback: "Good.",
                privateTeacherNotes: "",
                teacherEdited: true
            )
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canApproveFinalReview)
        viewModel.approveFinalReview()
        XCTAssertEqual(viewModel.errorMessage, "Refresh final review because grading inputs changed since this review was created.")
        XCTAssertEqual(viewModel.assignment.finalReview?.status, .inProgress)
    }

    func testRubricParserFindsPointBearingCriteria() {
        let rubric = """
        Claim: 0-2 points
        - 2: clear claim
        Evidence: 0-4 points
        """
        let parsed = RubricParser.parse(rubric)
        XCTAssertEqual(parsed.criteria.count, 2)
        XCTAssertEqual(parsed.criteria[0].title, "Claim")
        XCTAssertEqual(parsed.criteria[1].maxPoints, 4)
    }

    func testGRDBStoreRoundTripsAssignmentsAndDeletes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let store = try GRDBAssignmentStore(applicationSupportURL: root)

        let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
        let assignmentA = AssignmentRecord(
            id: UUID(),
            title: "Essay 1",
            subject: "History",
            gradeLevel: "9",
            studentDisplayName: "Alex",
            assignmentType: .essay,
            reviewedStudentText: "Reviewed text",
            ocrReviewStatus: .reviewed,
            latestDraft: GradeDraftResult(
                studentResponseSummary: "Summary",
                criteria: [
                    CriterionScore(
                        criterionID: "claim",
                        criterion: "Claim",
                        rating: "Proficient",
                        proposedPoints: 2,
                        maxPoints: 2,
                        evidence: ["Evidence"],
                        explanation: "Good",
                        teacherReviewRequired: false
                    )
                ],
                totalScore: 2,
                maxScore: 2,
                studentFeedback: "Nice",
                teacherNotes: "",
                uncertaintyFlags: []
            ),
            createdAt: oldDate,
            updatedAt: oldDate
        )

        let assignmentB = AssignmentRecord(
            id: UUID(),
            title: "Response",
            subject: "Math",
            gradeLevel: "8",
            studentDisplayName: "Bri",
            assignmentType: .shortAnswer,
            reviewedStudentText: "Short answer",
            ocrReviewStatus: .reviewed,
            createdAt: oldDate.addingTimeInterval(1),
            updatedAt: oldDate.addingTimeInterval(1)
        )

        try store.saveAssignments([assignmentA, assignmentB])
        let loaded = try store.loadAssignments()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertTrue(loaded.contains(assignmentB))
        XCTAssertTrue(loaded.contains(assignmentA))

        try store.deleteAssignment(id: assignmentA.id)
        let afterDelete = try store.loadAssignments()
        XCTAssertEqual(afterDelete.count, 1)
        XCTAssertEqual(afterDelete[0].id, assignmentB.id)
    }

    func testGradeDraftValidatorClampsOutOfRangeScoresAndRequiresEvidence() throws {
        let input = sampleInput(rubric: "Evidence: 0-4 points")
        let criterionID = input.parsedRubric.criteria[0].id
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: criterionID,
                    criterion: "Evidence",
                    rating: "Developing",
                    proposedPoints: 12,
                    maxPoints: 4,
                    evidence: [],
                    explanation: "No cited evidence.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "Feedback",
            teacherNotes: "",
            uncertaintyFlags: []
        )

        let normalized = try GradeDraftValidator.normalizeAndValidate(draft, input: input)
        XCTAssertEqual(normalized.criteria[0].proposedPoints, 4)
        XCTAssertEqual(normalized.criteria[0].criterionID, criterionID)
        XCTAssertTrue(normalized.criteria[0].teacherReviewRequired)
        XCTAssertEqual(normalized.totalScore, 4)
        XCTAssertFalse(normalized.complianceFlags.isEmpty)
        XCTAssertEqual(normalized.packetFingerprint, input.packetFingerprint)
    }

    func testGradeDraftValidatorRequiresEveryStructuredCriterion() throws {
        let input = sampleInput(rubric: "Claim: 0-2 points\nEvidence: 0-4 points")
        let criterionID = input.parsedRubric.criteria[0].id
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: criterionID,
                    criterion: "Claim",
                    rating: "Developing",
                    proposedPoints: 1,
                    maxPoints: 2,
                    evidence: ["Student claim"],
                    explanation: "Partial claim.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "Feedback",
            teacherNotes: "",
            uncertaintyFlags: []
        )

        XCTAssertThrowsError(try GradeDraftValidator.normalizeAndValidate(draft, input: input))
    }

    func testStudentReportExcludesPrivateTeacherNotes() {
        var assignment = AssignmentRecord(title: "Response 1", subject: "ELA", gradeLevel: "5")
        assignment.reviewedStudentText = "Student text"
        assignment.rubricText = "Claim: 0-4 points"
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterionID: "claim",
                criterion: "Claim",
                rating: "Proficient",
                proposedPoints: 3,
                finalPoints: 4,
                maxPoints: 4,
                evidence: ["Student text"],
                explanation: "Clear claim.",
                teacherApproved: true
            )],
            totalScore: 4,
            maxScore: 4,
            studentFeedback: "Good claim.",
            privateTeacherNotes: "Sensitive private note.",
            teacherEdited: true
        )

        let student = MarkdownReportBuilder.studentMarkdown(for: assignment)
        XCTAssertTrue(student.contains("Final teacher-approved grade"))
        XCTAssertTrue(student.contains("Good claim."))
        XCTAssertFalse(student.contains("Sensitive private note"))

        let audit = MarkdownReportBuilder.teacherAuditMarkdown(for: assignment)
        XCTAssertTrue(audit.contains("Sensitive private note"))
    }

    private func sampleInput(rubric: String = "Claim: 0-4 points") -> GradingInput {
        let parsed = RubricParser.parse(rubric)
        return GradingInput(
            assignmentID: UUID(),
            assignmentTitle: "Essay",
            subject: "ELA",
            gradeLevel: "6",
            className: "6A",
            studentDisplayName: "Student A",
            assignmentType: .essay,
            rubricText: rubric,
            parsedRubric: parsed,
            customInstructions: "",
            answerKeyText: "",
            exemplarText: "",
            reviewedStudentText: "Student response",
            ocrQualitySummary: OCRQualitySummary(),
            ocrReviewStatus: .notNeeded,
            sourceInputCount: 1,
            hasGradingStandard: !rubric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            packetFingerprint: "packet-1"
        )
    }
}
