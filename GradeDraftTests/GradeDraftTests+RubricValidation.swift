import XCTest
import ZIPFoundation
@testable import GradeDraft

extension GradeDraftTests {
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

    func testGRDBRoundTripPreservesRubricImportAndOCRMetadataWithoutPayloadRows() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftRubricOCRRoundTrip-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = try GRDBAssignmentStore(applicationSupportURL: root)
        let parsedRubric = ParsedRubric(
            criteria: [
                RubricCriterion(
                    id: "claim",
                    title: "Claim",
                    maxPoints: 4,
                    descriptor: "Clear claim",
                    sortOrder: 0,
                    levels: [RubricLevel(id: "strong", label: "Strong", points: 4, descriptor: "Clear claim", sortOrder: 0)]
                )
            ],
            issues: [],
            groups: []
        )
        let sourceID = UUID()
        var document = OCRDocument(
            id: UUID(),
            engine: "PDFKit digital text + Apple Vision",
            engineVersion: "system-26",
            pages: [
                OCRPage(id: UUID(), sourceInputID: sourceID, pageIndex: 0, imageWidth: 640, imageHeight: 480, lines: []),
                OCRPage(
                    id: UUID(),
                    sourceInputID: sourceID,
                    pageIndex: 1,
                    imageWidth: 640,
                    imageHeight: 480,
                    lines: [OCRLine(text: "Reviewed line", confidence: 0.99, boundingBox: .zero, teacherConfirmed: true)]
                )
            ],
            reviewStatus: .reviewed
        )
        document.reviewedAt = Date(timeIntervalSince1970: 1_800_000_000)
        var assignment = AssignmentRecord(title: "Normalized persistence", rubricText: "Rubric", ocrReviewStatus: .reviewed)
        assignment.rubricImportMode = .structuredConfirmed
        assignment.confirmedParsedRubric = parsedRubric
        assignment.sourceInputs = [SourceInputRef(id: sourceID, sourceType: .pdf, pageIndex: 0, localRelativePath: "Sources/\(assignment.id.uuidString)/page-1.png")]
        assignment.ocrDocument = document

        try store.saveAssignments([assignment])
        let database = try GradeDraftDatabase(applicationSupportURL: root)
        try database.bootstrapIfNeeded()
        try database.removeCompatibilityPayloadsForValidation()

        let loaded = try store.loadAssignments().first
        XCTAssertEqual(loaded?.rubricImportMode, .structuredConfirmed)
        XCTAssertEqual(loaded?.confirmedParsedRubric, parsedRubric)
        XCTAssertEqual(loaded?.ocrDocument?.engine, "PDFKit digital text + Apple Vision")
        XCTAssertEqual(loaded?.ocrDocument?.engineVersion, "system-26")
        XCTAssertEqual(loaded?.ocrDocument?.reviewStatus, .reviewed)
        XCTAssertEqual(loaded?.ocrDocument?.reviewedAt, document.reviewedAt)
        XCTAssertEqual(loaded?.ocrDocument?.pages.count, 2)
        XCTAssertTrue(loaded?.ocrDocument?.pages.first?.lines.isEmpty == true, "Empty OCR pages must survive normalized GRDB round trip")
        XCTAssertEqual(loaded?.ocrDocument?.pages.last?.imageWidth, 640)
        XCTAssertEqual(loaded?.ocrDocument?.pages.last?.imageHeight, 480)
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

    func testRubricImportModeCodableRoundTrip() throws {
        var assignment = AssignmentRecord(title: "Round trip")
        assignment.rubricImportMode = .structuredConfirmed
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(assignment)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AssignmentRecord.self, from: data)
        XCTAssertEqual(decoded.rubricImportMode, .structuredConfirmed)
    }

    // MARK: - Change 7: Delete assignment removes roster entries

}
