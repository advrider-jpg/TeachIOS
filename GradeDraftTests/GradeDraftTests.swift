import XCTest
@testable import GradeDraft

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
        XCTAssertThrowsError(try LocalOnlyGradingValidator.validate(input)) { error in
            XCTAssertEqual(error as? GradeDraftError, .missingRubric)
        }
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
            packetFingerprint: "packet-1"
        )
    }
}
