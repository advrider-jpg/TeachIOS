import XCTest
@testable import GradeDraft

final class GradeDraftTests: XCTestCase {
    func testDeterministicTotalsIgnoreModelTotals() throws {
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterion: "Claim",
                    rating: "Proficient",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["Clear claim"],
                    explanation: "The response includes a claim.",
                    teacherReviewRequired: false
                ),
                CriterionScore(
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

    func testValidationBlocksEmptyRubric() throws {
        let input = GradingInput(
            assignmentTitle: "Essay",
            subject: "ELA",
            gradeLevel: "6",
            assignmentType: .essay,
            rubricText: " ",
            customInstructions: "",
            reviewedStudentText: "Student response",
            ocrQualitySummary: OCRQualitySummary()
        )
        XCTAssertThrowsError(try LocalOnlyGradingValidator.validate(input)) { error in
            XCTAssertEqual(error as? GradeDraftError, .missingRubric)
        }
    }

    func testValidationBlocksEmptyStudentText() throws {
        let input = GradingInput(
            assignmentTitle: "Essay",
            subject: "ELA",
            gradeLevel: "6",
            assignmentType: .essay,
            rubricText: "Rubric",
            customInstructions: "",
            reviewedStudentText: "  ",
            ocrQualitySummary: OCRQualitySummary()
        )
        XCTAssertThrowsError(try LocalOnlyGradingValidator.validate(input)) { error in
            XCTAssertEqual(error as? GradeDraftError, .missingStudentText)
        }
    }

    func testJSONExtractorFindsFirstObjectAndIgnoresBracesInStrings() {
        let raw = "Here is the draft:\n```json\n{\"studentResponseSummary\":\"uses { braces } in text\",\"criteria\":[]}\n``` trailing"
        XCTAssertEqual(
            JSONExtractor.extractFirstJSONObject(from: raw),
            "{\"studentResponseSummary\":\"uses { braces } in text\",\"criteria\":[]}"
        )
    }

    func testOCRQualitySummaryFlagsLowConfidence() {
        let lines = [
            OCRLine(text: "Strong line", confidence: 0.95, boundingBox: .zero),
            OCRLine(text: "Weak line", confidence: 0.42, boundingBox: .zero)
        ]
        let summary = OCRQualitySummary(lines: lines)
        XCTAssertEqual(summary.lineCount, 2)
        XCTAssertEqual(summary.lowConfidenceLineCount, 1)
        XCTAssertTrue(summary.requiresTeacherOCRReview)
    }

    func testGradeDraftValidatorClampsOutOfRangeScoresAndRequiresEvidence() throws {
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
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

        let normalized = try GradeDraftValidator.normalizeAndValidate(draft)
        XCTAssertEqual(normalized.criteria[0].proposedPoints, 4)
        XCTAssertTrue(normalized.criteria[0].teacherReviewRequired)
        XCTAssertEqual(normalized.totalScore, 4)
        XCTAssertFalse(normalized.complianceFlags.isEmpty)
    }

    func testMarkdownReportUsesFinalReviewWhenPresent() {
        var assignment = AssignmentRecord(title: "Response 1", subject: "ELA", gradeLevel: "5")
        assignment.reviewedStudentText = "Student text"
        assignment.rubricText = "Rubric"
        assignment.finalReview = FinalGradeReview(
            criteria: [CriterionScore(
                criterion: "Claim",
                rating: "Proficient",
                proposedPoints: 3,
                maxPoints: 4,
                evidence: ["Student text"],
                explanation: "Clear claim.",
                teacherReviewRequired: false
            )],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "Good claim.",
            privateTeacherNotes: "Reviewed.",
            teacherEdited: true
        )

        let markdown = MarkdownReportBuilder.markdown(for: assignment)
        XCTAssertTrue(markdown.contains("Final teacher-approved grade"))
        XCTAssertTrue(markdown.contains("Good claim."))
        XCTAssertTrue(markdown.contains("Student text"))
    }
}
