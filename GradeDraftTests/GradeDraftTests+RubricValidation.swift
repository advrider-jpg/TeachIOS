import XCTest
@testable import GradeDraft

extension GradeDraftTests {
    func testDraftTotalIsSumOfCriterionPoints() {
        let draft = GradeDraftResult(
            packetFingerprint: "packet-1",
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: "claim",
                    rating: "Proficient",
                    proposedPoints: 3,
                    evidenceQuotes: ["Clear claim"],
                    explanation: "The response includes a claim.",
                    teacherReviewRequired: false
                ),
                CriterionScore(
                    criterionID: "evidence",
                    rating: "Developing",
                    proposedPoints: 2,
                    evidenceQuotes: ["One example"],
                    explanation: "The response has limited evidence.",
                    teacherReviewRequired: true
                )
            ],
            studentFeedback: "Feedback",
            teacherNotes: "Notes",
            uncertaintyFlags: []
        )

        XCTAssertEqual(draft.totalScore, 5)
    }

    func testFinalReviewTotalUsesTeacherFinalPoints() {
        let review = FinalGradeReview(
            packetFingerprint: "packet-1",
            criteria: [
                FinalCriterionScore(
                    criterionID: "claim",
                    rating: "Proficient",
                    proposedPoints: 3,
                    finalPoints: 4,
                    explanation: "Teacher found the claim complete.",
                    teacherApproved: true
                )
            ],
            studentFeedback: "Feedback",
            privateTeacherNotes: "Private",
            teacherEdited: true
        )

        XCTAssertEqual(review.totalScore, 4)
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

    func testStoreRoundTripPreservesRubricImportAndOCRMetadata() async throws {
        let database = try AppDatabase.inMemory()
        let classGroup = ClassGroup(name: "6A")
        try await database.save(classGroup)
        try await database.save(Student(displayName: "Kai"), enrolledIn: classGroup.id)
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
        var assignment = Assignment(classGroupID: classGroup.id, title: "Normalized persistence", rubricText: "Rubric")
        assignment.rubricImportMode = .structuredConfirmed
        assignment.confirmedRubric = parsedRubric
        try await database.createAssignment(assignment)
        let summaries = try await database.submissionSummaries(assignmentID: assignment.id)
        let submissionID = try XCTUnwrap(summaries.first).id

        let source = SourceInputRef(
            submissionID: submissionID,
            sourceType: .pdf,
            pageIndex: 0,
            localRelativePath: "Sources/\(submissionID.uuidString)/page-1.png"
        )
        var document = OCRDocument(
            engine: "PDFKit digital text + Apple Vision",
            engineVersion: "system-26",
            pages: [
                OCRPage(sourceInputID: source.id, pageIndex: 0, pixelWidth: 640, pixelHeight: 480, lines: []),
                OCRPage(
                    sourceInputID: source.id,
                    pageIndex: 1,
                    pixelWidth: 640,
                    pixelHeight: 480,
                    lines: [OCRLine(text: "Reviewed line", confidence: 0.99, boundingBox: .zero, origin: .visionOCR, teacherConfirmed: true)]
                )
            ],
            reviewStatus: .reviewed
        )
        document.reviewedAt = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try await database.replaceInput(submissionID: submissionID, kind: .scanned, pastedText: nil, sources: [source], ocr: document)

        let loadedSetup = try await database.assignmentSetup(id: assignment.id)
        XCTAssertEqual(loadedSetup?.assignment.rubricImportMode, .structuredConfirmed)
        XCTAssertEqual(loadedSetup?.assignment.confirmedRubric, parsedRubric)
        let loaded = try await database.submission(id: submissionID)
        XCTAssertEqual(loaded?.ocr?.engine, "PDFKit digital text + Apple Vision")
        XCTAssertEqual(loaded?.ocr?.engineVersion, "system-26")
        XCTAssertEqual(loaded?.ocr?.reviewStatus, .reviewed)
        XCTAssertEqual(loaded?.ocr?.reviewedAt, document.reviewedAt)
        XCTAssertEqual(loaded?.ocr?.pages.count, 2)
        XCTAssertTrue(loaded?.ocr?.pages.first?.lines.isEmpty == true, "Empty scanned-text pages must survive a store round trip")
        XCTAssertEqual(loaded?.ocr?.pages.last?.pixelWidth, 640)
        XCTAssertEqual(loaded?.ocr?.pages.last?.pixelHeight, 480)
    }

    func testGradeDraftValidatorClampsOutOfRangeScoresAndRequiresEvidence() throws {
        let input = sampleInput(rubric: "Evidence: 0-4 points")
        let criterionID = input.parsedRubric.criteria[0].id
        let proposal = ProposalFixtures.proposal([
            ProposalFixtures.criterion(id: criterionID, points: 12, evidence: [], confidence: "medium")
        ])

        let normalized = try GradeDraftValidator.validate(proposal, input: input, audit: nil)
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
        let proposal = ProposalFixtures.proposal([
            ProposalFixtures.criterion(id: criterionID, points: 1, evidence: ["Student response"])
        ])

        XCTAssertThrowsError(try GradeDraftValidator.validate(proposal, input: input, audit: nil))
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
        let prompt = PromptBuilder.gradingInstructionsText() + "\n" + PromptBuilder.fullPacketPromptText(input: input, mode: .full)

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

        let result = PromptBuilder.gradingInstructionsText() + "\n" + PromptBuilder.fullPacketPromptText(input: input, mode: .full)
        XCTAssertTrue(result.contains("What is the role of evidence"),
                      "PromptBuilder should use the prompt field when supplied")
        // Title appears under "Title:", prompt under "Prompt:"
        XCTAssertTrue(result.contains("- Title: My Assignment Title"))
        XCTAssertTrue(result.contains("- Prompt: What is the role of evidence"))
    }

    func testPromptBuilderShowsNotSuppliedWhenPromptEmpty() {
        var input = sampleInput()
        input.prompt = ""
        let result = PromptBuilder.gradingInstructionsText() + "\n" + PromptBuilder.fullPacketPromptText(input: input, mode: .full)
        XCTAssertTrue(result.contains("Not supplied."),
                      "PromptBuilder should show 'Not supplied.' when prompt is empty")
    }

    func testChangingPromptChangesSetupFingerprint() throws {
        var assignment = Assignment(classGroupID: UUID(), title: "Test", rubricText: "Claim: 0-4 points")
        let fingerprintWithoutPrompt = try AssignmentSetup(assignment: assignment).setupFingerprint

        assignment.prompt = "What causes photosynthesis?"
        let fingerprintWithPrompt = try AssignmentSetup(assignment: assignment).setupFingerprint

        XCTAssertNotEqual(fingerprintWithoutPrompt, fingerprintWithPrompt,
                          "Adding a prompt should change the grading packet fingerprint")
    }

    func testManualFinalReviewWithParsedRubricCreatesCriteria() async throws {
        let app = try TestApp.make(grading: UnavailableLocalGradingService())
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points\nEvidence: 0-4 points", studentWork: "Student essay text.")
        let session = try await openSession(app, seeded.submissionID)

        await session.startManualFinalReview()

        let review = try XCTUnwrap(session.review)
        let setup = try XCTUnwrap(session.setup)
        XCTAssertEqual(review.criteria.count, 2, "Two criteria expected from parsed rubric")
        XCTAssertEqual(setup.parsedRubric.criterion(id: review.criteria[0].criterionID)?.title, "Claim")
        XCTAssertEqual(AssignmentReadiness.maximumPoints(for: review.criteria[0], setup: setup), 2)
        XCTAssertEqual(setup.parsedRubric.criterion(id: review.criteria[1].criterionID)?.title, "Evidence")
        XCTAssertEqual(AssignmentReadiness.maximumPoints(for: review.criteria[1], setup: setup), 4)
        XCTAssertTrue(review.criteria.allSatisfy { !$0.teacherApproved }, "No criterion should be pre-approved")
        XCTAssertTrue(review.criteria.allSatisfy { $0.finalPoints == 0 }, "All final points should start at 0")
    }

    func testTotalsRecalculateAfterCriterionDeletion() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points\nEvidence: 0-4 points", studentWork: "Student text.")
        let savedSetup = try await app.requireDatabase().assignmentSetup(id: seeded.assignmentID)
        let setup = try XCTUnwrap(savedSetup)
        let fingerprint = try await TestApp.fingerprint(app, seeded)
        let claim = FinalCriterionScore(
            criterionID: setup.parsedRubric.criteria[0].id, rating: "", proposedPoints: 0, finalPoints: 2,
            explanation: "", teacherApproved: true
        )
        let evidence = FinalCriterionScore(
            criterionID: setup.parsedRubric.criteria[1].id, rating: "", proposedPoints: 0, finalPoints: 3,
            explanation: "", teacherApproved: true
        )
        try await app.requireDatabase().saveFinalReview(
            FinalGradeReview(
                packetFingerprint: fingerprint,
                criteria: [claim, evidence],
                studentFeedback: "",
                privateTeacherNotes: "",
                teacherEdited: true
            ),
            submissionID: seeded.submissionID
        )
        let session = try await openSession(app, seeded.submissionID)
        XCTAssertEqual(session.review?.totalScore, 5)

        session.deleteCriterion(evidence.id)

        let review = try XCTUnwrap(session.review)
        XCTAssertEqual(review.totalScore, 2, "Total should be 2 after removing evidence criterion")
        XCTAssertEqual(review.criteria.compactMap { AssignmentReadiness.maximumPoints(for: $0, setup: setup) }.reduce(0, +), 2,
                       "Maximum should be 2 after removing evidence criterion")
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

    func testRubricImportModeCodableRoundTrip() throws {
        var assignment = Assignment(classGroupID: UUID(), title: "Round trip")
        assignment.rubricImportMode = .structuredConfirmed
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(assignment)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Assignment.self, from: data)
        XCTAssertEqual(decoded.rubricImportMode, .structuredConfirmed)
    }
}
