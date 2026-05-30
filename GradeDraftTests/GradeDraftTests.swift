import XCTest
import ZIPFoundation
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
        let parsedRows = try CSVParser.parseRows(csv)
        XCTAssertEqual(parsedRows.first, ["assignment_id", "title", "subject", "grade_level", "class_name", "student", "assignment_type", "assessment_purpose", "total_score", "max_score", "final_status", "ocr_status", "draft_status", "final_review_stale", "draft_stale", "updated_at"])
        XCTAssertTrue(csv.hasPrefix("\"assignment_id\""))
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
        XCTAssertEqual(viewModel.errorMessage, "Recheck final review because student work, rubric, or evidence changed.")
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

    func testGRDBInjectedRootIsRespectedAndNotDefaultDirectory() throws {
        let injectedRoot = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftInjected-\(UUID())")
        defer { try? FileManager.default.removeItem(at: injectedRoot) }
        try FileManager.default.createDirectory(at: injectedRoot, withIntermediateDirectories: true)

        let store = try GRDBAssignmentStore(applicationSupportURL: injectedRoot)
        let supportDir = try store.applicationSupportDirectory()

        // The support directory must be inside the injected root, not the default App Support path
        XCTAssertTrue(supportDir.path.hasPrefix(injectedRoot.path),
                      "Expected support dir \(supportDir.path) to be under injected root \(injectedRoot.path)")

        let defaultAppSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let defaultPath = defaultAppSupport?.appendingPathComponent("GradeDraft").path {
            XCTAssertNotEqual(supportDir.path, defaultPath,
                              "Injected root should produce a different path than the default App Support path")
        }
    }

    func testGRDBBootstrapIsIdempotent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftBootstrap-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let store1 = try GRDBAssignmentStore(applicationSupportURL: root)
        let store2 = try GRDBAssignmentStore(applicationSupportURL: root)

        // Both bootstraps should succeed; loading on an already-migrated DB should not throw
        let assignments = [AssignmentRecord(title: "Idempotent test")]
        try store1.saveAssignments(assignments)
        let loaded = try store2.loadAssignments()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "Idempotent test")
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

    // MARK: - Content-source consistency tests

    func testBuiltInRubricTemplateIDsInSourceOrder() {
        let expectedIDs = [
            "short-answer-4pt",
            "paragraph-response-8pt",
            "essay-20pt",
            "lab-writeup-16pt",
            "reading-comprehension-10pt",
            "science-explanation-12pt",
            "hass-source-response-12pt",
            "formative-exit-ticket-8pt",
            "reflection-response-12pt"
        ]
        let actualIDs = RubricTemplates.builtIn.map(\.id)
        XCTAssertEqual(actualIDs, expectedIDs,
                       "Built-in template IDs must match source-of-truth Section 6 in order")
    }

    func testBuiltInRubricTemplateMaxPointTotals() {
        let expectedTotals: [String: Double] = [
            "short-answer-4pt": 4,
            "paragraph-response-8pt": 8,
            "essay-20pt": 20,
            "lab-writeup-16pt": 16,
            "reading-comprehension-10pt": 10,
            "science-explanation-12pt": 12,
            "hass-source-response-12pt": 12,
            "formative-exit-ticket-8pt": 8,
            "reflection-response-12pt": 12
        ]

        for template in RubricTemplates.builtIn {
            guard let expected = expectedTotals[template.id] else {
                XCTFail("Unexpected template ID: \(template.id)")
                continue
            }
            let parsed = RubricParser.parse(template.rubricText)
            let total = parsed.criteria.map(\.maxPoints).reduce(0, +)
            XCTAssertEqual(total, expected,
                           "Template \(template.id) should total \(expected) pts but got \(total)")
        }
    }

    func testBuiltInTemplateInstructionsIncludeEvidenceSafeguards() {
        let evidenceKeywords = ["evidence", "cite", "teacher review", "teacher review required"]
        for template in RubricTemplates.builtIn {
            let instructions = template.customInstructions.lowercased()
            let hasEvidenceGuard = evidenceKeywords.contains { instructions.contains($0) }
            XCTAssertTrue(hasEvidenceGuard,
                          "Template \(template.id) instructions must reference evidence or teacher review. Got: \(template.customInstructions)")
        }
    }

    func testPromptBuilderContainsSafetyRules() {
        let input = sampleInput()
        let prompt = PromptBuilder.gradingPrompt(input: input)

        XCTAssertTrue(prompt.contains("teacher"), "Prompt must reference teacher review role")
        XCTAssertTrue(prompt.contains("No supporting evidence found."), "Prompt must specify evidence marker")
        XCTAssertTrue(prompt.contains("infer"), "Prompt must prohibit inference of student traits")
        XCTAssertTrue(prompt.contains("totalScore") || prompt.contains("totals"),
                      "Prompt must instruct app to calculate totals, not trust model")
        XCTAssertTrue(prompt.contains("cloud") || prompt.contains("cloud model"),
                      "Prompt must state no cloud fallback")
        XCTAssertFalse(prompt.contains("auto-grade") || prompt.contains("Auto-grade"),
                       "Prompt must not use prohibited 'auto-grade' language")
    }

    func testPromptBuilderUsesPromptFieldNotTitle() {
        var input = sampleInput()
        input.assignmentTitle = "My Assignment Title"
        input.prompt = "What is the role of evidence in a historical argument?"

        let result = PromptBuilder.gradingPrompt(input: input)
        XCTAssertTrue(result.contains("What is the role of evidence"),
                      "PromptBuilder should use the prompt field when supplied")
        // Title appears under "Title:", prompt under "Prompt:"
        XCTAssertTrue(result.contains("- Title: My Assignment Title"))
        XCTAssertTrue(result.contains("- Prompt: What is the role of evidence"))
    }

    func testPromptBuilderShowsNotSuppliedWhenPromptEmpty() {
        var input = sampleInput()
        input.prompt = ""
        let result = PromptBuilder.gradingPrompt(input: input)
        XCTAssertTrue(result.contains("Not supplied."),
                      "PromptBuilder should show 'Not supplied.' when prompt is empty")
    }

    func testChangingPromptChangesPacketFingerprint() {
        var record = AssignmentRecord(
            title: "Test",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "Student work"
        )
        let fingerprintWithoutPrompt = record.gradingPacketFingerprint

        record.prompt = "What causes photosynthesis?"
        let fingerprintWithPrompt = record.gradingPacketFingerprint

        XCTAssertNotEqual(fingerprintWithoutPrompt, fingerprintWithPrompt,
                          "Adding a prompt should change the grading packet fingerprint")
    }

    func testPromptPersistsInGRDBRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftPrompt-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let store = try GRDBAssignmentStore(applicationSupportURL: root)
        var record = AssignmentRecord(title: "Prompt persistence test")
        record.prompt = "Describe the water cycle."

        try store.saveAssignments([record])
        let loaded = try store.loadAssignments()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].prompt, "Describe the water cycle.")
    }

    func testOldRecordWithoutPromptDecodesSuccessfully() throws {
        // Encode a record, strip the prompt key, then decode — simulating data
        // saved before the prompt field was added.
        let original = AssignmentRecord(title: "Legacy Assignment")
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(original)
        var jsonObject = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        )
        jsonObject.removeValue(forKey: "prompt")
        let legacyData = try JSONSerialization.data(withJSONObject: jsonObject)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AssignmentRecord.self, from: legacyData)
        XCTAssertNil(decoded.prompt, "prompt should be nil when absent in stored JSON")
        XCTAssertEqual(decoded.title, "Legacy Assignment")
    }

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

    func testLocalAIUnavailableMessageContainsNoCloudFallback() {
        let service = UnavailableLocalGradingService()
        if case .unavailable(let message) = service.localAIStatus {
            XCTAssertTrue(message.lowercased().contains("cloud") || message.lowercased().contains("not"),
                          "Unavailable message should clarify no cloud fallback: \(message)")
            let prohibitedPhrases = ["will upload", "try again later with cloud", "cloud backup grading"]
            for phrase in prohibitedPhrases {
                XCTAssertFalse(message.lowercased().contains(phrase),
                               "Unavailable message must not imply cloud fallback: '\(phrase)' found in: \(message)")
            }
        } else {
            XCTFail("UnavailableLocalGradingService must report unavailable status")
        }
    }

    // MARK: - Manual final review tests

    @MainActor
    func testManualFinalReviewCanStartWithoutAIDraft() {
        let assignment = AssignmentRecord(
            title: "Short answer",
            rubricText: "Claim: 0-2 points\nEvidence: 0-2 points",
            reviewedStudentText: "Student wrote something."
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            gradingService: UnavailableLocalGradingService(),
            store: store
        )

        XCTAssertNil(viewModel.assignment.latestDraft, "No AI draft should exist")
        XCTAssertTrue(viewModel.canStartManualFinalReview, "Manual review should be available")
        viewModel.startManualFinalReview()
        XCTAssertNotNil(viewModel.assignment.finalReview, "Final review should be created")
        XCTAssertEqual(viewModel.assignment.finalReview?.status, .inProgress)
    }

    @MainActor
    func testManualFinalReviewBlockedWithoutReviewedText() {
        let assignment = AssignmentRecord(
            title: "Short answer",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: ""
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canStartManualFinalReview, "Manual review blocked without reviewed text")
    }

    @MainActor
    func testManualFinalReviewBlockedByOCRNeedsReview() {
        let assignment = AssignmentRecord(
            title: "Scanned work",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text from OCR",
            ocrReviewStatus: .needsReview
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canStartManualFinalReview, "Manual review blocked when OCR needs review")
    }

    @MainActor
    func testManualFinalReviewBlockedByOCRBlocked() {
        let assignment = AssignmentRecord(
            title: "Blocked OCR",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Text",
            ocrReviewStatus: .blocked
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canStartManualFinalReview, "Manual review blocked when OCR is blocked")
    }

    @MainActor
    func testManualFinalReviewBlockedWithoutGradingStandard() {
        let assignment = AssignmentRecord(
            title: "No rubric",
            rubricText: "",
            answerKeyText: "",
            exemplarText: "",
            reviewedStudentText: "Student text"
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canStartManualFinalReview, "Manual review blocked without any grading standard")
    }

    @MainActor
    func testManualFinalReviewWithParsedRubricCreatesCriteria() {
        let rubric = "Claim: 0-2 points\nEvidence: 0-4 points"
        let assignment = AssignmentRecord(
            title: "Essay",
            rubricText: rubric,
            reviewedStudentText: "Student essay text."
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            gradingService: UnavailableLocalGradingService(),
            store: store
        )

        viewModel.startManualFinalReview()

        let review = viewModel.assignment.finalReview
        XCTAssertNotNil(review)
        XCTAssertEqual(review?.criteria.count, 2, "Two criteria expected from parsed rubric")
        XCTAssertEqual(review?.criteria[0].criterion, "Claim")
        XCTAssertEqual(review?.criteria[0].maxPoints, 2)
        XCTAssertEqual(review?.criteria[1].criterion, "Evidence")
        XCTAssertEqual(review?.criteria[1].maxPoints, 4)
        XCTAssertTrue(review?.criteria.allSatisfy { !$0.teacherApproved } ?? false, "No criterion should be pre-approved")
        XCTAssertTrue(review?.criteria.allSatisfy { $0.finalPoints == 0 } ?? false, "All final points should start at 0")
    }

    @MainActor
    func testManualFinalReviewWithAnswerKeyOnlyCreatesTeacherReviewCriterion() {
        let assignment = AssignmentRecord(
            title: "Short answer",
            rubricText: "",
            answerKeyText: "Expected: two specific examples.",
            reviewedStudentText: "Student answer here."
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            gradingService: UnavailableLocalGradingService(),
            store: store
        )

        viewModel.startManualFinalReview()

        let review = viewModel.assignment.finalReview
        XCTAssertNotNil(review)
        XCTAssertEqual(review?.criteria.count, 1, "One teacher-review criterion expected when no parsed rubric")
        XCTAssertEqual(review?.criteria[0].criterion, "Teacher-entered grading standard")
        XCTAssertFalse(review?.criteria[0].teacherApproved ?? true)
    }

    @MainActor
    func testManualFinalReviewCannotBeApprovedUntilAllCriteriaApproved() {
        var assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text."
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 0,
                finalPoints: 2,
                maxPoints: 2,
                evidence: [],
                explanation: "",
                teacherApproved: false
            )],
            totalScore: 2,
            maxScore: 2,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: true
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canApproveFinalReview, "Cannot approve while criterion is unapproved")
    }

    @MainActor
    func testApprovedManualFinalReviewEnablesStudentExport() {
        var assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text."
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 0,
                finalPoints: 2,
                maxPoints: 2,
                evidence: [],
                explanation: "",
                teacherApproved: true
            )],
            totalScore: 2,
            maxScore: 2,
            studentFeedback: "Good work.",
            privateTeacherNotes: "",
            teacherEdited: true
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertTrue(viewModel.canExportStudentReport, "Approved manual final review should enable student export")
    }

    func testManualFinalReviewSurvivesGRDBRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftManual-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let store = try GRDBAssignmentStore(applicationSupportURL: root)

        var assignment = AssignmentRecord(title: "Manual review round trip")
        assignment.rubricText = "Claim: 0-2 points"
        assignment.reviewedStudentText = "Student wrote this."
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [FinalCriterionScore(
                criterionID: "criterion-1",
                criterion: "Claim",
                rating: "",
                proposedPoints: 0,
                finalPoints: 1,
                maxPoints: 2,
                evidence: ["Student wrote this."],
                explanation: "Partial claim.",
                teacherApproved: false,
                teacherRationale: "Manual teacher-created final review."
            )],
            totalScore: 1,
            maxScore: 2,
            studentFeedback: "",
            privateTeacherNotes: "My private note",
            teacherEdited: false
        )

        try store.saveAssignments([assignment])
        let loaded = try store.loadAssignments()

        XCTAssertEqual(loaded.count, 1)
        let loadedReview = loaded[0].finalReview
        XCTAssertNotNil(loadedReview)
        XCTAssertEqual(loadedReview?.criteria.count, 1)
        XCTAssertEqual(loadedReview?.criteria[0].criterion, "Claim")
        XCTAssertEqual(loadedReview?.criteria[0].finalPoints, 1)
        XCTAssertEqual(loadedReview?.privateTeacherNotes, "My private note")
    }

    // MARK: - Criterion management tests

    @MainActor
    func testAddCriterionToFinalReview() {
        var assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text."
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: false
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.addCriterionToFinalReview()
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria.count, 1, "One criterion should be added")
        XCTAssertFalse(viewModel.assignment.finalReview?.criteria[0].teacherApproved ?? true, "New criterion should not be pre-approved")
    }

    @MainActor
    func testDeleteCriterionFromFinalReview() {
        let criterion = FinalCriterionScore(
            criterion: "Claim",
            rating: "",
            proposedPoints: 0,
            finalPoints: 2,
            maxPoints: 2,
            evidence: [],
            explanation: "",
            teacherApproved: true
        )
        var assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text."
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [criterion],
            totalScore: 2,
            maxScore: 2,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: false
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.deleteCriterionFromFinalReview(id: criterion.id)
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria.count, 0, "Criterion should be deleted")
        XCTAssertEqual(viewModel.assignment.finalReview?.totalScore, 0, "Total should recalculate to 0")
    }

    @MainActor
    func testApprovalBlockedAfterAddingUnapprovedCriterion() {
        let approvedCriterion = FinalCriterionScore(
            criterion: "Claim",
            rating: "",
            proposedPoints: 0,
            finalPoints: 2,
            maxPoints: 2,
            evidence: [],
            explanation: "",
            teacherApproved: true
        )
        var assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text."
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [approvedCriterion],
            totalScore: 2,
            maxScore: 2,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: true
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertTrue(viewModel.canApproveFinalReview, "Should be approvable before adding unapproved criterion")
        viewModel.addCriterionToFinalReview()
        XCTAssertFalse(viewModel.canApproveFinalReview, "Should be blocked after adding unapproved criterion")
    }

    @MainActor
    func testTotalsRecalculateAfterCriterionDeletion() {
        let criterionA = FinalCriterionScore(
            criterion: "Claim",
            rating: "",
            proposedPoints: 0,
            finalPoints: 2,
            maxPoints: 2,
            evidence: [],
            explanation: "",
            teacherApproved: true
        )
        let criterionB = FinalCriterionScore(
            criterion: "Evidence",
            rating: "",
            proposedPoints: 0,
            finalPoints: 3,
            maxPoints: 4,
            evidence: [],
            explanation: "",
            teacherApproved: true
        )
        var assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-2 points\nEvidence: 0-4 points",
            reviewedStudentText: "Student text."
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [criterionA, criterionB],
            totalScore: 5,
            maxScore: 6,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: true
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.deleteCriterionFromFinalReview(id: criterionB.id)

        XCTAssertEqual(viewModel.assignment.finalReview?.totalScore, 2, "Total should be 2 after removing evidence criterion")
        XCTAssertEqual(viewModel.assignment.finalReview?.maxScore, 2, "Max should be 2 after removing evidence criterion")
    }

    // MARK: - Export flow tests

    @MainActor
    func testStudentReportBlockedWithoutApprovedFinalReview() {
        let assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "Student text."
        )
        // No finalReview at all
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)
        XCTAssertFalse(viewModel.canExportStudentReport, "Student export blocked without final review")
    }

    @MainActor
    func testStudentReportBlockedWhenFinalReviewIsStale() {
        var assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "Student text."
        )
        // finalReview with a different packet fingerprint (stale)
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: "stale-fingerprint",
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 3,
                finalPoints: 3,
                maxPoints: 4,
                evidence: ["student text"],
                explanation: "Good.",
                teacherApproved: true
            )],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "Good.",
            privateTeacherNotes: "",
            teacherEdited: true
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertTrue(viewModel.assignment.finalReviewIsStale, "Final review should be stale")
        XCTAssertFalse(viewModel.canExportStudentReport, "Student export blocked when stale")
    }

    func testStudentReportExcludesRawModelResponse() {
        var assignment = AssignmentRecord(title: "Essay", subject: "ELA", gradeLevel: "6")
        assignment.reviewedStudentText = "Student text"
        assignment.rubricText = "Claim: 0-4 points"
        assignment.latestDraft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "Draft feedback",
            teacherNotes: "Private model note.",
            uncertaintyFlags: [],
            rawModelResponse: "Raw JSON blob should not appear"
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 0,
                finalPoints: 3,
                maxPoints: 4,
                evidence: [],
                explanation: "",
                teacherApproved: true
            )],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "Teacher final feedback.",
            privateTeacherNotes: "",
            teacherEdited: true
        )

        let report = MarkdownReportBuilder.studentMarkdown(for: assignment)
        XCTAssertFalse(report.contains("Raw JSON blob"), "Student report must not include raw model response")
        XCTAssertFalse(report.contains("Private model note"), "Student report must not include raw model teacher notes")
        XCTAssertTrue(report.contains("Teacher final feedback"), "Student report should include teacher final feedback")
    }

    func testTeacherAuditIncludesPrivateNotesAndOCRStatusAndFingerprint() {
        var assignment = AssignmentRecord(title: "Audit test", subject: "Science")
        assignment.reviewedStudentText = "Student text"
        assignment.rubricText = "Claim: 0-4 points"
        assignment.ocrReviewStatus = .reviewed
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 0,
                finalPoints: 4,
                maxPoints: 4,
                evidence: [],
                explanation: "",
                teacherApproved: true
            )],
            totalScore: 4,
            maxScore: 4,
            studentFeedback: "Great.",
            privateTeacherNotes: "Private audit note here.",
            teacherEdited: true
        )

        let audit = MarkdownReportBuilder.teacherAuditMarkdown(for: assignment)
        XCTAssertTrue(audit.contains("Private audit note here."), "Teacher review should include private notes")
        XCTAssertTrue(audit.contains("Scanned-text review status: Ready for teacher review"), "Teacher review should include scanned-text status")
        XCTAssertTrue(audit.contains(assignment.gradingPacketFingerprint), "Teacher review should include packet fingerprint")
    }

    func testCSVStatusForNoFinalReview() {
        let assignment = AssignmentRecord(title: "No review", rubricText: "Claim: 0-4 points", reviewedStudentText: "text")
        let rows = CSVExportService.buildStudentRows(from: [assignment])
        let dataRow = rows[1]
        XCTAssertEqual(dataRow[10], "pending_final_review", "Status should be pending_final_review when no final review")
    }

    func testCSVStatusForApprovedFinalReview() {
        var assignment = AssignmentRecord(title: "Approved")
        assignment.rubricText = "Claim: 0-4 points"
        assignment.reviewedStudentText = "text"
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim", rating: "", proposedPoints: 0, finalPoints: 3,
                maxPoints: 4, evidence: [], explanation: "", teacherApproved: true
            )],
            totalScore: 3, maxScore: 4, studentFeedback: "", privateTeacherNotes: "", teacherEdited: true
        )
        let rows = CSVExportService.buildStudentRows(from: [assignment])
        XCTAssertEqual(rows[1][10], "approved", "Status should be approved")
    }

    func testCSVStatusForStaleReview() {
        var assignment = AssignmentRecord(title: "Stale")
        assignment.rubricText = "Claim: 0-4 points"
        assignment.reviewedStudentText = "text"
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: "old-fingerprint",
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim", rating: "", proposedPoints: 0, finalPoints: 3,
                maxPoints: 4, evidence: [], explanation: "", teacherApproved: true
            )],
            totalScore: 3, maxScore: 4, studentFeedback: "", privateTeacherNotes: "", teacherEdited: true
        )
        let rows = CSVExportService.buildStudentRows(from: [assignment])
        XCTAssertEqual(rows[1][10], "stale_review", "Status should be stale_review when fingerprint mismatch")
    }

    // MARK: - Source file cleanup test

    @MainActor
    func testDeleteAssignmentRemovesRecord() {
        let assignment = AssignmentRecord(title: "To delete", rubricText: "Claim: 0-4 points")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertEqual(viewModel.assignments.count, 1)
        viewModel.deleteCurrentAssignment()
        // After deletion one blank starter assignment is created if empty
        XCTAssertFalse(viewModel.assignments.contains { $0.id == assignment.id }, "Deleted assignment should not remain")
    }

    // MARK: - Local AI unavailability tests

    @MainActor
    func testLocalAIUnavailableDisablesDraftButton() {
        let assignment = AssignmentRecord(
            title: "Short answer",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text."
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            gradingService: UnavailableLocalGradingService(),
            store: store
        )
        XCTAssertFalse(viewModel.canDraftGrade, "AI draft button should be disabled when local AI unavailable")
    }

    @MainActor
    func testLocalAIUnavailableDoesNotDisableManualFinalReview() {
        let assignment = AssignmentRecord(
            title: "Manual review",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text."
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            gradingService: UnavailableLocalGradingService(),
            store: store
        )
        XCTAssertTrue(viewModel.canStartManualFinalReview, "Manual review should be available when local AI is unavailable")
    }

    // MARK: - OCR review tests

    @MainActor
    func testScannedInputSetsOCRStatusNeedsReview() {
        // Creating an assignment with needsReview status simulates a scan
        let assignment = AssignmentRecord(
            title: "Scan test",
            reviewedStudentText: "Scanned text",
            ocrReviewStatus: .needsReview
        )
        XCTAssertTrue(assignment.requiresOCRReviewBeforeGrading, "Scan should require OCR review")
        XCTAssertTrue(assignment.ocrReviewStatus.blocksGrading, "OCR needsReview blocks grading")
    }

    @MainActor
    func testMarkingOCRReviewedSetsStatusReviewed() {
        var assignment = AssignmentRecord(
            title: "OCR review test",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Extracted text",
            ocrReviewStatus: .needsReview
        )
        // Simulate an OCR document being present
        assignment.ocrDocument = OCRDocument(
            pages: [OCRPage(
                pageIndex: 0,
                lines: [OCRLine(text: "Extracted text", confidence: 0.95, boundingBox: .zero)]
            )]
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canStartManualFinalReview, "Cannot start manual review before scanned text is reviewed")
        viewModel.markOCRReviewed()
        XCTAssertEqual(viewModel.assignment.ocrReviewStatus, .reviewed, "After marking reviewed, status should be reviewed")
        XCTAssertTrue(viewModel.canStartManualFinalReview, "Manual review should be available after scanned text is reviewed")
    }

    @MainActor
    func testDraftBlockedBeforeOCRReview() {
        let assignment = AssignmentRecord(
            title: "OCR blocked",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Text",
            ocrReviewStatus: .needsReview
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canDraftGrade, "Draft should be blocked before OCR review")
    }

    // MARK: - Advanced feature completion regression tests

    func testEvidenceReferenceModelStoresBoundingBoxTraceability() {
        let sourceID = UUID()
        let lineID = UUID()
        let reference = EvidenceReference(
            sourceInputID: sourceID,
            ocrLineID: lineID,
            pageIndex: 0,
            quote: "Student evidence",
            startOffset: 0,
            endOffset: 16,
            boundingBox: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            sourceKind: "ocrLine",
            teacherConfirmed: true
        )
        XCTAssertEqual(reference.sourceInputID, sourceID)
        XCTAssertEqual(reference.ocrLineID, lineID)
        XCTAssertEqual(reference.boundingBox?.width, 0.3)
        XCTAssertTrue(reference.displaySource.contains("page 1"))
    }

    func testStudentReportDoesNotExposeEvidenceSourceRefs() {
        var assignment = AssignmentRecord(title: "Privacy", reviewedStudentText: "Evidence")
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 0,
                finalPoints: 1,
                maxPoints: 1,
                evidence: ["Evidence"],
                evidenceSourceRefs: ["source:secret:page:0:ocrLine:secret"],
                explanation: "Evidence supports claim.",
                teacherApproved: true
            )],
            totalScore: 1,
            maxScore: 1,
            studentFeedback: "Good.",
            privateTeacherNotes: "Private",
            teacherEdited: true
        )
        let report = MarkdownReportBuilder.studentMarkdown(for: assignment)
        XCTAssertFalse(report.contains("source:secret"))
        XCTAssertFalse(report.contains("Private"))
    }

    func testTeacherAuditReportIncludesEvidenceTraceability() {
        let lineID = UUID()
        var assignment = AssignmentRecord(title: "Audit", reviewedStudentText: "Evidence")
        assignment.evidenceReferences = [EvidenceReference(
            sourceInputID: UUID(),
            ocrLineID: lineID,
            pageIndex: 0,
            quote: "Evidence",
            startOffset: nil,
            endOffset: nil,
            boundingBox: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            sourceKind: "ocrLine",
            teacherConfirmed: true
        )]
        let audit = MarkdownReportBuilder.teacherAuditMarkdown(for: assignment)
        XCTAssertTrue(audit.contains("Evidence"))
        XCTAssertTrue(audit.contains("bbox"))
    }

    func testPDFExportServicesWriteNonEmptyFiles() throws {
        var assignment = AssignmentRecord(title: "PDF", reviewedStudentText: "Evidence")
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 0,
                finalPoints: 1,
                maxPoints: 1,
                evidence: ["Evidence"],
                explanation: "Met.",
                teacherApproved: true
            )],
            totalScore: 1,
            maxScore: 1,
            studentFeedback: "Good.",
            privateTeacherNotes: "Private",
            teacherEdited: true
        )
        let studentURL = FileManager.default.temporaryDirectory.appendingPathComponent("student-\(UUID()).pdf")
        let auditURL = FileManager.default.temporaryDirectory.appendingPathComponent("audit-\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: studentURL); try? FileManager.default.removeItem(at: auditURL) }
        let writtenStudent = try PDFExportService.studentReportPDF(for: assignment, destination: studentURL)
        let writtenAudit = try PDFExportService.teacherAuditPDF(for: assignment, destination: auditURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: writtenStudent.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: writtenAudit.path))
        XCTAssertGreaterThan((try Data(contentsOf: writtenStudent)).count, 100)
        XCTAssertGreaterThan((try Data(contentsOf: writtenAudit)).count, 100)
    }

    func testArchiveContainsManifestAndCoreFiles() throws {
        let assignment = AssignmentRecord(title: "Archive", reviewedStudentText: "Text")
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("archive-\(UUID()).zip")
        defer { try? FileManager.default.removeItem(at: destination) }
        let written = try BundleExportService.writeTeacherAuditArchive(assignment: assignment, sourceFiles: [], to: destination)
        guard let archive = Archive(url: written, accessMode: .read) else {
            return XCTFail("Archive should open")
        }
        XCTAssertNotNil(archive["manifest.json"])
        XCTAssertNotNil(archive["student_report.md"])
        XCTAssertNotNil(archive["teacher_audit_report.md"])
        XCTAssertNotNil(archive["assignment.json"])
    }

    func testFullBackupArchiveCanBeReadBack() throws {
        let assignment = AssignmentRecord(title: "Backup", reviewedStudentText: "Text")
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("backup-\(UUID()).zip")
        defer { try? FileManager.default.removeItem(at: destination) }
        let written = try BundleExportService.writeFullBackup(assignments: [assignment], sourceFiles: [], to: destination)
        let restored = try BundleExportService.readBackupAssignments(from: written)
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored[0].title, "Backup")
    }

    func testMarkdownRubricParserExtractsTableCriteria() {
        let markdown = """
        | Criterion ID | Criterion | Max Points | Evidence Required | Level | Level Points | Descriptor |
        |---|---|---:|---|---|---:|---|
        | claim | Claim | 4 | yes | Strong | 4 | Clear claim |
        | evidence | Evidence | 3 | yes | Strong | 3 | Strong evidence |
        """
        let parsed = MarkdownRubricParser.parse(markdown)
        XCTAssertGreaterThanOrEqual(parsed.criteria.count, 2)
        XCTAssertTrue(parsed.criteria.contains { $0.title.localizedCaseInsensitiveContains("Claim") })
    }

    func testSourceInputStoresPDFMetadata() {
        let source = SourceInputRef(sourceType: .pdf, fileName: "work.pdf", mimeType: "application/pdf", pdfPageCount: 2)
        XCTAssertEqual(source.fileName, "work.pdf")
        XCTAssertEqual(source.mimeType, "application/pdf")
        XCTAssertEqual(source.pdfPageCount, 2)
    }

    // MARK: - Private helpers

    private func sampleInput(rubric: String = "Claim: 0-4 points") -> GradingInput {
        let parsed = RubricParser.parse(rubric)
        return GradingInput(
            assignmentID: UUID(),
            assignmentTitle: "Essay",
            prompt: "",
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
            assessmentPurpose: .summative,
            curriculumReference: "",
            reviewedStudentText: "Student response",
            reviewedTextWithSourceRefs: "Student response",
            ocrQualitySummary: OCRQualitySummary(),
            ocrReviewStatus: .notNeeded,
            sourceInputCount: 1,
            packetFingerprint: "packet-1",
            hasGradingStandard: !rubric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }
}
