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
            "guaranteed score",
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
            GradeDraftError.ocrReviewRequired.localizedDescription,
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
            ocrQualitySummary: OCRQualitySummary(),
            ocrReviewStatus: .notNeeded,
            sourceInputCount: 1,
            packetFingerprint: "packet-1",
            hasGradingStandard: !rubric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }
}
