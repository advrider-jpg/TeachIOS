import XCTest
@testable import GradeDraft

// MARK: - Assignment, submission and grading-packet edge cases

final class AssignmentHardeningTests: XCTestCase {
    private func assignment(rubric: String = "", answerKey: String = "", exemplar: String = "") -> Assignment {
        Assignment(classGroupID: UUID(), title: "Test", rubricText: rubric, answerKeyText: answerKey, exemplarText: exemplar)
    }

    /// An assignment with one student's pasted work.
    private func pastedWork(rubric: String = "Claim: 0-4 points", text: String = "text") -> (setup: AssignmentSetup, graph: SubmissionGraph) {
        let setup = AssignmentSetup(assignment: assignment(rubric: rubric))
        let student = Student(displayName: "Student")
        let graph = SubmissionGraph(
            submission: Submission(assignmentID: setup.id, studentID: student.id, inputKind: .pasted, pastedText: text),
            student: student
        )
        return (setup, graph)
    }

    private func emptyDraft(fingerprint: String) -> GradeDraftResult {
        GradeDraftResult(
            packetFingerprint: fingerprint,
            studentResponseSummary: "", criteria: [],
            studentFeedback: "", teacherNotes: "", uncertaintyFlags: []
        )
    }

    private func emptyFinalReview(fingerprint: String) -> FinalGradeReview {
        FinalGradeReview(
            packetFingerprint: fingerprint,
            criteria: [],
            studentFeedback: "", privateTeacherNotes: "", teacherEdited: false
        )
    }

    func testHasGradingStandardWithRubricOnly() {
        XCTAssertTrue(assignment(rubric: "Claim: 0-4 points").hasGradingStandard)
    }

    func testHasGradingStandardWithAnswerKeyOnly() {
        XCTAssertTrue(assignment(answerKey: "Two examples needed.").hasGradingStandard)
    }

    func testHasGradingStandardWithExemplarOnly() {
        XCTAssertTrue(assignment(exemplar: "Model response here.").hasGradingStandard)
    }

    func testHasNoGradingStandard() {
        XCTAssertFalse(assignment().hasGradingStandard)
    }

    func testHasNoGradingStandardWhitespaceOnly() {
        XCTAssertFalse(assignment(rubric: "  ", answerKey: " ", exemplar: "\n").hasGradingStandard)
    }

    func testGradingPacketFingerprintChangesWithRubric() throws {
        var work = pastedWork()
        let fingerprintBefore = try work.graph.packetFingerprint(setup: work.setup)
        work.setup.assignment.rubricText = "Evidence: 0-2 points"
        let fingerprintAfter = try work.graph.packetFingerprint(setup: work.setup)
        XCTAssertNotEqual(fingerprintBefore, fingerprintAfter)
    }

    func testGradingPacketFingerprintChangesWithStudentText() throws {
        var work = pastedWork(text: "text A")
        let fingerprintBefore = try work.graph.packetFingerprint(setup: work.setup)
        work.graph.submission.pastedText = "text B"
        let fingerprintAfter = try work.graph.packetFingerprint(setup: work.setup)
        XCTAssertNotEqual(fingerprintBefore, fingerprintAfter)
    }

    func testDraftIsStaleWhenFingerprintDiffers() throws {
        var work = pastedWork()
        work.graph.draft = emptyDraft(fingerprint: "old-fingerprint")
        XCTAssertTrue(try work.graph.draftIsStale(setup: work.setup))
    }

    func testDraftIsNotStaleWhenFingerprintMatches() throws {
        var work = pastedWork()
        work.graph.draft = emptyDraft(fingerprint: try work.graph.packetFingerprint(setup: work.setup))
        XCTAssertFalse(try work.graph.draftIsStale(setup: work.setup))
    }

    func testFinalReviewIsStaleWhenFingerprintDiffers() throws {
        var work = pastedWork()
        work.graph.finalReview = emptyFinalReview(fingerprint: "old-fingerprint")
        XCTAssertTrue(try work.graph.finalReviewIsStale(setup: work.setup))
    }

    func testSourceReferencedReviewedTextWithoutOCR() throws {
        let work = pastedWork(text: "plain text")
        let input = try GradingPacketBuilder.gradingInput(setup: work.setup, graph: work.graph, className: "6A", mappedItems: [])
        XCTAssertEqual(input.reviewedTextWithSourceRefs, "plain text")
    }

    func testSourceReferencedReviewedTextWithOCR() throws {
        var work = pastedWork(text: "")
        work.graph.submission.inputKind = .scanned
        work.graph.submission.pastedText = nil
        work.graph.ocr = OCRDocument(
            pages: [OCRPage(pageIndex: 0, lines: [
                OCRLine(text: "line one", confidence: 0.9, boundingBox: .zero, origin: .visionOCR)
            ])]
        )
        let input = try GradingPacketBuilder.gradingInput(setup: work.setup, graph: work.graph, className: "6A", mappedItems: [])
        XCTAssertTrue(input.reviewedTextWithSourceRefs.contains("[p1-l1-"))
        XCTAssertTrue(input.reviewedTextWithSourceRefs.contains("line one"))
    }

    func testAuditEventAppend() async throws {
        let fixture = try ExportFixtureFactory.baseAssignment()
        let database = try AppDatabase.inMemory()
        _ = try await database.restore(fixture.snapshot, resolutions: [:])
        let beforeGraph = try await database.submission(id: fixture.submission.id)
        XCTAssertTrue(try XCTUnwrap(beforeGraph).audit.isEmpty)

        try await database.appendAudit(AuditEvent(
            assignmentID: fixture.setup.id,
            submissionID: fixture.submission.id,
            eventType: .assignmentCreated,
            detail: "Test event"
        ))

        let afterGraph = try await database.submission(id: fixture.submission.id)
        let after = try XCTUnwrap(afterGraph).audit
        XCTAssertEqual(after.count, 1)
        XCTAssertEqual(after.first?.eventType, .assignmentCreated)
    }

    func testGradingInputIsReadyForGrading() {
        XCTAssertTrue(gradingInput(rubric: "Claim: 0-4 points", hasGradingStandard: true, ocrReviewStatus: .reviewed).isReadyForGrading)
    }

    func testGradingInputNotReadyWithoutStandard() {
        XCTAssertFalse(gradingInput(rubric: "", hasGradingStandard: false, ocrReviewStatus: .reviewed).isReadyForGrading)
    }

    func testGradingInputNotReadyWithBlockingOCR() {
        XCTAssertFalse(gradingInput(rubric: "Claim: 0-4 points", hasGradingStandard: true, ocrReviewStatus: .needsReview).isReadyForGrading)
    }

    private func gradingInput(rubric: String, hasGradingStandard: Bool, ocrReviewStatus: OCRReviewStatus) -> GradingInput {
        GradingInput(
            assignmentID: UUID(),
            assignmentTitle: "Test",
            prompt: "",
            subject: "",
            gradeLevel: "",
            className: "",
            studentDisplayName: "",
            assignmentType: .essay,
            rubricText: rubric,
            parsedRubric: rubric.isEmpty ? ParsedRubric(criteria: [], issues: []) : RubricParser.parse(rubric),
            customInstructions: "",
            answerKeyText: "",
            exemplarText: "",
            assessmentPurpose: .summative,
            curriculumReference: "",
            reviewedStudentText: "Student text",
            reviewedTextWithSourceRefs: "Student text",
            ocrQualitySummary: OCRQualitySummary(),
            ocrReviewStatus: ocrReviewStatus,
            sourceInputCount: 0,
            packetFingerprint: "fp",
            hasGradingStandard: hasGradingStandard
        )
    }
}
