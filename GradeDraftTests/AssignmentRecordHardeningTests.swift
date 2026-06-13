import XCTest
@testable import GradeDraft

// MARK: - AssignmentRecord edge cases

final class AssignmentRecordHardeningTests: XCTestCase {
    func testHasGradingStandardWithRubricOnly() {
        let record = AssignmentRecord(rubricText: "Claim: 0-4 points")
        XCTAssertTrue(record.hasGradingStandard)
    }

    func testHasGradingStandardWithAnswerKeyOnly() {
        let record = AssignmentRecord(answerKeyText: "Two examples needed.")
        XCTAssertTrue(record.hasGradingStandard)
    }

    func testHasGradingStandardWithExemplarOnly() {
        let record = AssignmentRecord(exemplarText: "Model response here.")
        XCTAssertTrue(record.hasGradingStandard)
    }

    func testHasNoGradingStandard() {
        let record = AssignmentRecord(rubricText: "", answerKeyText: "", exemplarText: "")
        XCTAssertFalse(record.hasGradingStandard)
    }

    func testHasNoGradingStandardWhitespaceOnly() {
        let record = AssignmentRecord(rubricText: "  ", answerKeyText: " ", exemplarText: "\n")
        XCTAssertFalse(record.hasGradingStandard)
    }

    func testRequiresOCRReviewBeforeGrading() {
        XCTAssertTrue(AssignmentRecord(ocrReviewStatus: .needsReview).requiresOCRReviewBeforeGrading)
        XCTAssertTrue(AssignmentRecord(ocrReviewStatus: .blocked).requiresOCRReviewBeforeGrading)
        XCTAssertFalse(AssignmentRecord(ocrReviewStatus: .notNeeded).requiresOCRReviewBeforeGrading)
        XCTAssertFalse(AssignmentRecord(ocrReviewStatus: .reviewed).requiresOCRReviewBeforeGrading)
    }

    func testGradingPacketFingerprintChangesWithRubric() {
        var record = AssignmentRecord(title: "Test", rubricText: "Claim: 0-4 points", reviewedStudentText: "text")
        let fingerprintBefore = record.gradingPacketFingerprint
        record.rubricText = "Evidence: 0-2 points"
        let fingerprintAfter = record.gradingPacketFingerprint
        XCTAssertNotEqual(fingerprintBefore, fingerprintAfter)
    }

    func testGradingPacketFingerprintChangesWithStudentText() {
        var record = AssignmentRecord(title: "Test", rubricText: "Claim: 0-4 points", reviewedStudentText: "text A")
        let fingerprintBefore = record.gradingPacketFingerprint
        record.reviewedStudentText = "text B"
        let fingerprintAfter = record.gradingPacketFingerprint
        XCTAssertNotEqual(fingerprintBefore, fingerprintAfter)
    }

    func testGradingPacketFingerprintChangesWithOCRStatus() {
        var record = AssignmentRecord(title: "Test", rubricText: "Claim: 0-4 points", reviewedStudentText: "text")
        record.ocrReviewStatus = .notNeeded
        let fingerprintBefore = record.gradingPacketFingerprint
        record.ocrReviewStatus = .reviewed
        let fingerprintAfter = record.gradingPacketFingerprint
        XCTAssertNotEqual(fingerprintBefore, fingerprintAfter)
    }

    func testLatestDraftIsStaleWhenFingerprintDiffers() {
        var record = AssignmentRecord(title: "Test", rubricText: "Claim: 0-4 points", reviewedStudentText: "text")
        record.latestDraft = GradeDraftResult(
            packetFingerprint: "old-fingerprint",
            studentResponseSummary: "", criteria: [], totalScore: 0, maxScore: 0,
            studentFeedback: "", teacherNotes: "", uncertaintyFlags: []
        )
        XCTAssertTrue(record.latestDraftIsStale)
    }

    func testLatestDraftIsNotStaleWhenFingerprintMatches() {
        var record = AssignmentRecord(title: "Test", rubricText: "Claim: 0-4 points", reviewedStudentText: "text")
        record.latestDraft = GradeDraftResult(
            packetFingerprint: record.gradingPacketFingerprint,
            studentResponseSummary: "", criteria: [], totalScore: 0, maxScore: 0,
            studentFeedback: "", teacherNotes: "", uncertaintyFlags: []
        )
        XCTAssertFalse(record.latestDraftIsStale)
    }

    func testFinalReviewIsStaleWhenFingerprintDiffers() {
        var record = AssignmentRecord(title: "Test", rubricText: "Claim: 0-4 points", reviewedStudentText: "text")
        record.finalReview = FinalGradeReview(
            packetFingerprint: "old-fingerprint",
            criteria: [], totalScore: 0, maxScore: 0,
            studentFeedback: "", privateTeacherNotes: "", teacherEdited: false
        )
        XCTAssertTrue(record.finalReviewIsStale)
    }

    func testSourceReferencedReviewedTextWithoutOCR() {
        let record = AssignmentRecord(reviewedStudentText: "plain text")
        XCTAssertEqual(record.sourceReferencedReviewedText, "plain text")
    }

    func testSourceReferencedReviewedTextWithOCR() {
        var record = AssignmentRecord(reviewedStudentText: "")
        record.ocrDocument = OCRDocument(
            pages: [OCRPage(pageIndex: 0, lines: [
                OCRLine(text: "line one", confidence: 0.9, boundingBox: .zero)
            ])]
        )
        let result = record.sourceReferencedReviewedText
        XCTAssertTrue(result.contains("[p1-l1-"))
        XCTAssertTrue(result.contains("line one"))
    }

    func testAuditEventAppend() {
        var record = AssignmentRecord()
        XCTAssertTrue(record.auditEvents.isEmpty)
        record.appendAuditEvent(.assignmentCreated, detail: "Test event")
        XCTAssertEqual(record.auditEvents.count, 1)
        XCTAssertEqual(record.auditEvents[0].eventType, .assignmentCreated)
    }

    func testGradingInputIsReadyForGrading() {
        let input = GradingInput(
            assignmentID: UUID(),
            assignmentTitle: "Test",
            prompt: "",
            subject: "",
            gradeLevel: "",
            className: "",
            studentDisplayName: "",
            assignmentType: .essay,
            rubricText: "Claim: 0-4 points",
            parsedRubric: RubricParser.parse("Claim: 0-4 points"),
            customInstructions: "",
            answerKeyText: "",
            exemplarText: "",
            assessmentPurpose: .summative,
            curriculumReference: "",
            reviewedStudentText: "Student text",
            reviewedTextWithSourceRefs: "Student text",
            ocrQualitySummary: OCRQualitySummary(),
            ocrReviewStatus: .notNeeded,
            sourceInputCount: 0,
            packetFingerprint: "fp",
            hasGradingStandard: true
        )
        XCTAssertTrue(input.isReadyForGrading)
    }

    func testGradingInputNotReadyWithoutStandard() {
        let input = GradingInput(
            assignmentID: UUID(),
            assignmentTitle: "Test",
            prompt: "",
            subject: "",
            gradeLevel: "",
            className: "",
            studentDisplayName: "",
            assignmentType: .essay,
            rubricText: "",
            parsedRubric: ParsedRubric(criteria: [], issues: []),
            customInstructions: "",
            answerKeyText: "",
            exemplarText: "",
            assessmentPurpose: .summative,
            curriculumReference: "",
            reviewedStudentText: "Student text",
            reviewedTextWithSourceRefs: "Student text",
            ocrQualitySummary: OCRQualitySummary(),
            ocrReviewStatus: .notNeeded,
            sourceInputCount: 0,
            packetFingerprint: "fp",
            hasGradingStandard: false
        )
        XCTAssertFalse(input.isReadyForGrading)
    }

    func testGradingInputNotReadyWithBlockingOCR() {
        let input = GradingInput(
            assignmentID: UUID(),
            assignmentTitle: "Test",
            prompt: "",
            subject: "",
            gradeLevel: "",
            className: "",
            studentDisplayName: "",
            assignmentType: .essay,
            rubricText: "Claim: 0-4 points",
            parsedRubric: RubricParser.parse("Claim: 0-4 points"),
            customInstructions: "",
            answerKeyText: "",
            exemplarText: "",
            assessmentPurpose: .summative,
            curriculumReference: "",
            reviewedStudentText: "Student text",
            reviewedTextWithSourceRefs: "Student text",
            ocrQualitySummary: OCRQualitySummary(),
            ocrReviewStatus: .needsReview,
            sourceInputCount: 0,
            packetFingerprint: "fp",
            hasGradingStandard: true
        )
        XCTAssertFalse(input.isReadyForGrading)
    }
}
