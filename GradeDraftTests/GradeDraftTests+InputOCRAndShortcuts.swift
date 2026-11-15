import XCTest
@testable import GradeDraft

extension GradeDraftTests {
    /// A submission with scanned text made of the given lines (not yet marked reviewed).
    fileprivate func seedScanned(
        _ app: AppModel,
        lines: [OCRLine],
        rubric: String = "Claim: 0-2 points"
    ) async throws -> SeededSubmission {
        let seeded = try await TestApp.seed(app, rubric: rubric, studentWork: nil)
        _ = try await app.requireDatabase().replaceInput(
            submissionID: seeded.submissionID, kind: .scanned, pastedText: nil, sources: [],
            ocr: OCRDocument(pages: [OCRPage(pageIndex: 0, lines: lines)])
        )
        return seeded
    }

    func testOCRQualitySummaryFlagsLowConfidenceAndUnconfirmedText() {
        let lines = [
            OCRLine(text: "Strong line", confidence: 0.95, boundingBox: .zero, origin: .visionOCR, teacherConfirmed: true),
            OCRLine(text: "Weak line", confidence: 0.42, boundingBox: .zero, origin: .visionOCR, teacherConfirmed: false)
        ]
        let summary = OCRQualitySummary(lines: lines)
        XCTAssertEqual(summary.lineCount, 2)
        XCTAssertEqual(summary.lowConfidenceLineCount, 1)
        XCTAssertEqual(summary.unresolvedLineCount, 1)
        XCTAssertTrue(summary.requiresTeacherOCRReview)
    }

    func testScannedInputRequiresScannedTextReviewBeforeGrading() async throws {
        let app = try TestApp.make()
        let line = OCRLine(text: "Scanned text", confidence: 0.5, boundingBox: .zero, origin: .visionOCR)
        let seeded = try await seedScanned(app, lines: [line])
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.graph?.ocr?.reviewStatus, .needsReview)
        XCTAssertTrue(session.graph?.ocr?.reviewStatus.blocksGrading == true, "Scanned text that needs review blocks grading")
        XCTAssertFalse(session.readiness?.scannedTextIssues.isEmpty ?? true)
        let summary = try await app.requireDatabase().submissionSummaries(assignmentID: seeded.assignmentID).first
        XCTAssertEqual(summary?.rosterStatus, .ocrReviewNeeded)
    }

    func testMarkingScannedTextReviewedSetsStatusReviewed() async throws {
        let app = try TestApp.make()
        let line = OCRLine(text: "Extracted text", confidence: 0.95, boundingBox: .zero, origin: .visionOCR, teacherConfirmed: true)
        let seeded = try await seedScanned(app, lines: [line])
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canStartFinalReview, false, "Cannot start manual review before scanned text is reviewed")
        await session.markScannedTextReviewed()
        try await waitForSession(session, app)

        XCTAssertEqual(session.graph?.ocr?.reviewStatus, .reviewed, "After marking reviewed, status should be reviewed")
        XCTAssertEqual(session.readiness?.canStartFinalReview, true, "Manual review should be available after scanned text is reviewed")
    }

    func testDraftBlockedBeforeScannedTextReview() async throws {
        let app = try TestApp.make()
        let line = OCRLine(text: "Text", confidence: 0.95, boundingBox: .zero, origin: .visionOCR, teacherConfirmed: true)
        let seeded = try await seedScanned(app, lines: [line])
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canDraft, false, "Draft should be blocked before scanned text review")
    }

    // MARK: - Rubric import modes

    func testConfirmStructuredImportSetsMode() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Old rubric", studentWork: "Student text")
        let database = try app.requireDatabase()
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

        model.previewRubric(text: "| Criterion | Max | Level | Points |\n|---|---|---|---|\n| Claim | 4 | Good | 4 |")
        await model.confirmRubricPreview(structured: true)

        let setupSaved = try await database.assignmentSetup(id: seeded.assignmentID)
        let setup = try XCTUnwrap(setupSaved)
        let graphSaved = try await database.submission(id: seeded.submissionID)
        let graph = try XCTUnwrap(graphSaved)
        XCTAssertEqual(setup.assignment.rubricImportMode, .structuredConfirmed)
        XCTAssertNotNil(setup.assignment.confirmedRubric)
        XCTAssertNotNil(graph.draft)
        XCTAssertNotNil(graph.finalReview)
        XCTAssertTrue(try graph.draftIsStale(setup: setup))
        XCTAssertTrue(try graph.finalReviewIsStale(setup: setup))
    }

    func testConfirmRawTextImportSetsRawMode() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "", studentWork: "Student text")
        let model = try await openSetupModel(app, seeded.assignmentID)

        model.previewRubric(text: "Some rubric text without table")
        await model.confirmRubricPreview(structured: false)

        XCTAssertEqual(model.setup?.assignment.rubricImportMode, .rawTextOnly)
        XCTAssertNil(model.setup?.assignment.confirmedRubric)
    }

    func testRawTextImportDoesNotUseParsedCriteria() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "", studentWork: "Student text")
        let model = try await openSetupModel(app, seeded.assignmentID)

        model.previewRubric(text: "| Criterion | Max | Level | Points |\n|---|---|---|---|\n| Claim | 4 | Good | 4 |")
        await model.confirmRubricPreview(structured: false)

        XCTAssertEqual(model.setup?.parsedRubric.criteria.isEmpty, true, "Raw-text mode must produce empty parsed criteria")
    }

    // MARK: - Scanned text review

    /// Changed expectation: rejecting the last unresolved line no longer marks the scanned text reviewed by
    /// itself; once no line needs action, the teacher's explicit "mark reviewed" succeeds and sets the date.
    func testRejectingTheLastUnresolvedLineAllowsMarkingReviewed() async throws {
        let app = try TestApp.make()
        let low = OCRLine(text: "hello", confidence: 0.3, boundingBox: .zero, origin: .visionOCR)
        let seeded = try await seedScanned(app, lines: [low])
        let session = try await openSession(app, seeded.submissionID)

        await session.rejectLine(low.id)
        try await waitForSession(session, app)
        await session.markScannedTextReviewed()

        let graph = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertEqual(graph?.ocr?.reviewStatus, .reviewed)
        XCTAssertNotNil(graph?.ocr?.reviewedAt, "Document reviewedAt must be set")
        XCTAssertNil(session.alert)
    }

    func testEditOCRLineAfterReviewResetsToNeedsReview() async throws {
        let app = try TestApp.make()
        let line = OCRLine(text: "hello", confidence: 0.9, boundingBox: .zero, origin: .visionOCR, teacherConfirmed: true)
        let seeded = try await seedScanned(app, lines: [line])
        let session = try await openSession(app, seeded.submissionID)
        await session.markScannedTextReviewed()
        let reviewed = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertEqual(reviewed?.ocr?.reviewStatus, .reviewed)
        XCTAssertNotNil(reviewed?.ocr?.reviewedAt)

        await session.correctLine(line.id, text: "world")

        let graph = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertEqual(graph?.ocr?.reviewStatus, .needsReview, "Editing line must reset document to needsReview")
        XCTAssertNil(graph?.ocr?.reviewedAt, "Document reviewedAt must be cleared after edit")
    }

    func testMarkReviewedIsRefusedWhileLowConfidenceLinesAreUnresolved() async throws {
        let app = try TestApp.make()
        let line = OCRLine(
            text: "maybe", confidence: OCRQualitySummary.lowConfidenceThreshold - 0.01, boundingBox: .zero, origin: .visionOCR
        )
        let seeded = try await seedScanned(app, lines: [line], rubric: "")
        let session = try await openSession(app, seeded.submissionID)

        await session.markScannedTextReviewed()

        let graph = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertEqual(graph?.ocr?.reviewStatus, .needsReview)
        XCTAssertEqual(graph?.ocr?.allLines.first?.teacherConfirmed, false)
        XCTAssertTrue(session.alert?.message.contains("Confirm, correct or reject") == true)
    }

    /// Changed expectation: "Confirm all" confirms the confident Vision lines and leaves low-confidence lines
    /// for the teacher (the old page-level "mark page reviewed" confirmed nothing at all while any line was low).
    func testConfirmAllDoesNotBulkConfirmLowConfidenceLines() async throws {
        let app = try TestApp.make()
        let lowConfidence = OCRLine(
            text: "maybe", confidence: OCRQualitySummary.lowConfidenceThreshold - 0.01, boundingBox: .zero, origin: .visionOCR
        )
        let highConfidence = OCRLine(text: "clear", confidence: 0.99, boundingBox: .zero, origin: .visionOCR)
        let seeded = try await seedScanned(app, lines: [lowConfidence, highConfidence])
        let session = try await openSession(app, seeded.submissionID)

        await session.confirmAllConfidentLines()

        let graph = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertEqual(graph?.ocr?.reviewStatus, .needsReview)
        let lines = graph?.ocr?.allLines ?? []
        XCTAssertEqual(lines.first { $0.id == lowConfidence.id }?.teacherConfirmed, false)
        XCTAssertEqual(lines.first { $0.id == highConfidence.id }?.teacherConfirmed, true)
    }

    // MARK: - Source path safety

    func testSanitizedLocalSourcePathAcceptsValidPath() {
        XCTAssertEqual(SourcePathSafety.sanitizedLocalSourcePath("Sources/abc123/page.png"), "Sources/abc123/page.png")
    }

    func testUnsafeRelativeSourcePathDoesNotResolveToAFile() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SourcePathSafety-\(UUID().uuidString)")
        XCTAssertNil(SourcePathSafety.resolvedLocalSourceURL("Sources/assignment/../secret.png", applicationSupportDirectory: root))
        XCTAssertNotNil(SourcePathSafety.resolvedLocalSourceURL("Sources/assignment/page.png", applicationSupportDirectory: root))
    }

    func testSanitizedLocalSourcePathRejectsAbsolutePath() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("/absolute/path.png"))
    }

    func testSanitizedLocalSourcePathRejectsDotDot() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("Sources/../escape.png"))
    }

    func testSanitizedLocalSourcePathRejectsDotDotAfterPrefix() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("Sources/abc/../escape.png"))
    }

    func testSanitizedLocalSourcePathRejectsBackslash() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("Sources\\bad.png"))
    }

    func testSanitizedLocalSourcePathRejectsNil() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath(nil))
    }

    func testSanitizedLocalSourcePathRejectsNonSourcesPrefix() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("Documents/file.png"))
    }
}
