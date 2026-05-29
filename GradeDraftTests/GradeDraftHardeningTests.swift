import XCTest
import ZIPFoundation
@testable import GradeDraft

// MARK: - StableFingerprint tests

final class StableFingerprintTests: XCTestCase {
    func testFingerprintIsDeterministic() {
        let first = StableFingerprint.fingerprint(["hello", "world"])
        let second = StableFingerprint.fingerprint(["hello", "world"])
        XCTAssertEqual(first, second, "Same inputs must produce the same fingerprint")
    }

    func testFingerprintChangesWithInput() {
        let first = StableFingerprint.fingerprint(["hello"])
        let second = StableFingerprint.fingerprint(["world"])
        XCTAssertNotEqual(first, second, "Different inputs must produce different fingerprints")
    }

    func testFingerprintOrderMatters() {
        let forward = StableFingerprint.fingerprint(["a", "b"])
        let reversed = StableFingerprint.fingerprint(["b", "a"])
        XCTAssertNotEqual(forward, reversed, "Different order must produce different fingerprints")
    }

    func testFingerprintEmptyArray() {
        let result = StableFingerprint.fingerprint([])
        XCTAssertTrue(result.hasPrefix("fnv1a64-"))
    }

    func testFingerprintEmptyString() {
        let result = StableFingerprint.fingerprint([""])
        XCTAssertTrue(result.hasPrefix("fnv1a64-"))
    }

    func testFingerprintEmptyData() {
        let result = StableFingerprint.fingerprint(Data())
        XCTAssertTrue(result.hasPrefix("fnv1a64-"))
    }

    func testFingerprintDataDeterminism() {
        let data = Data("GradeDraft".utf8)
        let first = StableFingerprint.fingerprint(data)
        let second = StableFingerprint.fingerprint(data)
        XCTAssertEqual(first, second)
    }

    func testFingerprintDistinguishesEmptyComponents() {
        let leadingEmpty = StableFingerprint.fingerprint(["", "hello"])
        let trailingEmpty = StableFingerprint.fingerprint(["hello", ""])
        XCTAssertNotEqual(leadingEmpty, trailingEmpty)
    }
}

// MARK: - RubricParser edge cases

final class RubricParserHardeningTests: XCTestCase {
    func testEmptyStringProducesNoStructuredCriteria() {
        let parsed = RubricParser.parse("")
        XCTAssertTrue(parsed.criteria.isEmpty)
        XCTAssertFalse(parsed.issues.isEmpty, "Empty rubric should produce issues")
    }

    func testWhitespaceOnlyProducesNoStructuredCriteria() {
        let parsed = RubricParser.parse("   \n\n  \t  ")
        XCTAssertTrue(parsed.criteria.isEmpty)
        XCTAssertFalse(parsed.issues.isEmpty)
    }

    func testDecimalPointValues() {
        let rubric = "Accuracy: 0-2.5 points"
        let parsed = RubricParser.parse(rubric)
        XCTAssertEqual(parsed.criteria.count, 1)
        XCTAssertEqual(parsed.criteria[0].maxPoints, 2.5)
    }

    func testMultipleColonsInLine() {
        let rubric = "Note: Claim: 0-4 points"
        let parsed = RubricParser.parse(rubric)
        XCTAssertEqual(parsed.criteria.count, 1)
        XCTAssertEqual(parsed.criteria[0].title, "Note")
    }

    func testBulletLinesSkipped() {
        let rubric = """
        Claim: 0-4 points
        - 4: excellent
        - 0: missing
        * also a bullet
        Evidence: 0-2 points
        """
        let parsed = RubricParser.parse(rubric)
        XCTAssertEqual(parsed.criteria.count, 2)
        XCTAssertEqual(parsed.criteria[0].title, "Claim")
        XCTAssertEqual(parsed.criteria[1].title, "Evidence")
    }

    func testNoPointBearingLinesProducesIssue() {
        let rubric = "This is a rubric without any point descriptors."
        let parsed = RubricParser.parse(rubric)
        XCTAssertTrue(parsed.criteria.isEmpty)
        XCTAssertFalse(parsed.issues.isEmpty)
    }

    func testPtsAbbreviation() {
        let rubric = "Claim: 0-3 pts"
        let parsed = RubricParser.parse(rubric)
        XCTAssertEqual(parsed.criteria.count, 1)
        XCTAssertEqual(parsed.criteria[0].maxPoints, 3)
    }

    func testSingleWordPoint() {
        let rubric = "Claim: 0-5 point"
        let parsed = RubricParser.parse(rubric)
        XCTAssertEqual(parsed.criteria.count, 1)
        XCTAssertEqual(parsed.criteria[0].maxPoints, 5)
    }

    func testCriterionIDsAreStable() {
        let rubric = "Claim: 0-4 points\nEvidence: 0-2 points"
        let parsed1 = RubricParser.parse(rubric)
        let parsed2 = RubricParser.parse(rubric)
        XCTAssertEqual(parsed1.criteria.map(\.id), parsed2.criteria.map(\.id))
    }

    func testSortOrderIsPreserved() {
        let rubric = "A: 0-1 points\nB: 0-2 points\nC: 0-3 points"
        let parsed = RubricParser.parse(rubric)
        XCTAssertEqual(parsed.criteria.map(\.sortOrder), [0, 1, 2])
    }
}

// MARK: - MarkdownRubricParser edge cases

final class MarkdownRubricParserHardeningTests: XCTestCase {
    func testHeadingCriteriaExtracted() {
        let markdown = """
        ## Claim: 0-4 points
        Detailed descriptor for claim.
        ## Evidence: 0-3 points
        Detailed descriptor for evidence.
        """
        let parsed = MarkdownRubricParser.parse(markdown)
        XCTAssertGreaterThanOrEqual(parsed.criteria.count, 2)
    }

    func testTableWithSeparatorRowSkipped() {
        let markdown = """
        | Criterion | Max Points |
        |---|---:|
        | Claim | 4 points |
        | Evidence | 3 points |
        """
        let parsed = MarkdownRubricParser.parse(markdown)
        XCTAssertGreaterThanOrEqual(parsed.criteria.count, 2)
    }

    func testEmptyMarkdownProducesIssue() {
        let parsed = MarkdownRubricParser.parse("")
        XCTAssertTrue(parsed.criteria.isEmpty)
        XCTAssertFalse(parsed.issues.isEmpty)
    }

    func testDuplicateCriteriaNamesDeduped() {
        let markdown = """
        Claim: 0-4 points
        Claim: 0-4 points
        """
        let parsed = MarkdownRubricParser.parse(markdown)
        XCTAssertEqual(parsed.criteria.count, 1, "Duplicate criteria should be deduped")
    }

    func testCriterionIDsPreservingOrderIsOrdered() {
        let rubric = "A: 0-1 points\nB: 0-2 points\nC: 0-3 points"
        let parsed = MarkdownRubricParser.parse(rubric)
        let ids = MarkdownRubricParser.criterionIDsPreservingOrder(from: parsed)
        XCTAssertEqual(ids.count, 3)
        XCTAssertEqual(ids, parsed.criteria.sorted { $0.sortOrder < $1.sortOrder }.map(\.id))
    }

    func testFallbackToSimpleParserWhenMarkdownFails() {
        let rubric = "Claim: 0-2 points\nEvidence: 0-3 points"
        let parsed = MarkdownRubricParser.parse(rubric)
        XCTAssertGreaterThanOrEqual(parsed.criteria.count, 2)
    }
}

// MARK: - GradeTotals edge cases

final class GradeTotalsHardeningTests: XCTestCase {
    func testEmptyCriteriaProducesZeroTotals() {
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [],
            totalScore: 999,
            maxScore: 999,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        let normalized = GradeTotals.applyingDeterministicTotals(to: draft)
        XCTAssertEqual(normalized.totalScore, 0)
        XCTAssertEqual(normalized.maxScore, 0)
    }

    func testNegativeProposedPointsClampedToZero() {
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterion: "Claim",
                    rating: "Poor",
                    proposedPoints: -5,
                    maxPoints: 4,
                    evidence: [],
                    explanation: "",
                    teacherReviewRequired: true
                )
            ],
            totalScore: 999,
            maxScore: 999,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        let normalized = GradeTotals.applyingDeterministicTotals(to: draft)
        XCTAssertEqual(normalized.totalScore, 0, "Negative proposed points should clamp to 0")
        XCTAssertEqual(normalized.maxScore, 4)
    }

    func testNegativeMaxPointsClampedToZeroInDraft() {
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterion: "Claim",
                    rating: "OK",
                    proposedPoints: 2,
                    maxPoints: -1,
                    evidence: [],
                    explanation: "",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 999,
            maxScore: 999,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        let normalized = GradeTotals.applyingDeterministicTotals(to: draft)
        XCTAssertEqual(normalized.maxScore, 0, "Negative maxPoints should clamp to 0")
    }

    func testFinalReviewNegativeFinalPointsClampedToZero() {
        let review = FinalGradeReview(
            packetFingerprint: "p-1",
            criteria: [
                FinalCriterionScore(
                    criterion: "Claim",
                    rating: "",
                    proposedPoints: 0,
                    finalPoints: -3,
                    maxPoints: 4,
                    evidence: [],
                    explanation: "",
                    teacherApproved: true
                )
            ],
            totalScore: 999,
            maxScore: 999,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: true
        )
        let normalized = GradeTotals.applyingDeterministicTotals(to: review)
        XCTAssertEqual(normalized.totalScore, 0, "Negative finalPoints should clamp to 0")
    }

    func testFormattedWholeNumber() {
        XCTAssertEqual(GradeTotals.formatted(4.0), "4")
        XCTAssertEqual(GradeTotals.formatted(0.0), "0")
    }

    func testFormattedDecimalNumber() {
        XCTAssertEqual(GradeTotals.formatted(2.5), "2.5")
        XCTAssertEqual(GradeTotals.formatted(3.33), "3.3")
    }

    func testMultipleCriteriaAggregation() {
        let review = FinalGradeReview(
            packetFingerprint: "p-1",
            criteria: [
                FinalCriterionScore(criterion: "A", rating: "", proposedPoints: 0, finalPoints: 3, maxPoints: 4, evidence: [], explanation: "", teacherApproved: true),
                FinalCriterionScore(criterion: "B", rating: "", proposedPoints: 0, finalPoints: 2, maxPoints: 4, evidence: [], explanation: "", teacherApproved: true),
                FinalCriterionScore(criterion: "C", rating: "", proposedPoints: 0, finalPoints: 4, maxPoints: 4, evidence: [], explanation: "", teacherApproved: true)
            ],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: true
        )
        let normalized = GradeTotals.applyingDeterministicTotals(to: review)
        XCTAssertEqual(normalized.totalScore, 9)
        XCTAssertEqual(normalized.maxScore, 12)
    }
}

// MARK: - OCR model edge cases

final class OCRModelHardeningTests: XCTestCase {
    func testOCRLineReviewedTextUsesCorrectedWhenPresent() {
        let line = OCRLine(text: "raw text", confidence: 0.9, boundingBox: .zero, correctedText: "corrected text")
        XCTAssertEqual(line.reviewedText, "corrected text")
        XCTAssertEqual(line.text, "corrected text")
    }

    func testOCRLineReviewedTextFallsBackToRaw() {
        let line = OCRLine(text: "raw text", confidence: 0.9, boundingBox: .zero)
        XCTAssertEqual(line.reviewedText, "raw text")
    }

    func testOCRLineReviewedTextFallsBackWhenCorrectedIsEmpty() {
        let line = OCRLine(text: "raw text", confidence: 0.9, boundingBox: .zero, correctedText: "  ")
        XCTAssertEqual(line.reviewedText, "raw text", "Empty corrected text should fall back to raw")
    }

    func testOCRLineReviewedTextFallsBackWhenCorrectedIsWhitespace() {
        let line = OCRLine(text: "raw text", confidence: 0.9, boundingBox: .zero, correctedText: "\n\t")
        XCTAssertEqual(line.reviewedText, "raw text")
    }

    func testOCRLineNeedsReviewWhenLowConfidence() {
        let line = OCRLine(text: "text", confidence: 0.5, boundingBox: .zero, teacherConfirmed: true)
        XCTAssertTrue(line.needsReview, "Low confidence should require review even if confirmed")
    }

    func testOCRLineNeedsReviewWhenUnconfirmed() {
        let line = OCRLine(text: "text", confidence: 0.95, boundingBox: .zero, teacherConfirmed: false)
        XCTAssertTrue(line.needsReview, "Unconfirmed line should need review")
    }

    func testOCRLineDoesNotNeedReviewWhenHighConfidenceAndConfirmed() {
        let line = OCRLine(text: "text", confidence: 0.95, boundingBox: .zero, teacherConfirmed: true)
        XCTAssertFalse(line.needsReview)
    }

    func testOCRLineReviewStatusLabelConfirmed() {
        let line = OCRLine(text: "text", confidence: 0.95, boundingBox: .zero, teacherConfirmed: true)
        XCTAssertEqual(line.reviewStatusLabel, "confirmed")
    }

    func testOCRLineReviewStatusLabelCorrected() {
        let line = OCRLine(text: "raw", confidence: 0.95, boundingBox: .zero, correctedText: "corrected", teacherConfirmed: true)
        XCTAssertEqual(line.reviewStatusLabel, "corrected")
    }

    func testOCRLineReviewStatusLabelUnreviewed() {
        let line = OCRLine(text: "text", confidence: 0.95, boundingBox: .zero, teacherConfirmed: false)
        XCTAssertEqual(line.reviewStatusLabel, "unreviewed")
    }

    func testOCRLineReviewStatusLabelBlockedFromGrading() {
        let line = OCRLine(text: "text", confidence: 0.95, boundingBox: .zero, correctedText: "   ", teacherConfirmed: false)
        XCTAssertEqual(line.reviewStatusLabel, "blockedFromGrading")
    }

    func testOCRDocumentCombinedTextUsesReviewedText() {
        let doc = OCRDocument(
            pages: [
                OCRPage(pageIndex: 0, lines: [
                    OCRLine(text: "raw1", confidence: 0.9, boundingBox: .zero, correctedText: "corrected1"),
                    OCRLine(text: "raw2", confidence: 0.9, boundingBox: .zero)
                ])
            ]
        )
        XCTAssertTrue(doc.combinedText.contains("corrected1"))
        XCTAssertTrue(doc.combinedText.contains("raw2"))
        XCTAssertFalse(doc.combinedText.contains("raw1"))
    }

    func testOCRDocumentRawCombinedTextUsesRawText() {
        let doc = OCRDocument(
            pages: [
                OCRPage(pageIndex: 0, lines: [
                    OCRLine(text: "raw1", confidence: 0.9, boundingBox: .zero, correctedText: "corrected1")
                ])
            ]
        )
        XCTAssertTrue(doc.rawCombinedText.contains("raw1"))
        XCTAssertFalse(doc.rawCombinedText.contains("corrected1"))
    }

    func testMarkingAllLinesConfirmed() {
        let doc = OCRDocument(
            pages: [
                OCRPage(pageIndex: 0, lines: [
                    OCRLine(text: "line1", confidence: 0.9, boundingBox: .zero, teacherConfirmed: false),
                    OCRLine(text: "line2", confidence: 0.5, boundingBox: .zero, teacherConfirmed: false)
                ])
            ]
        )
        let confirmed = doc.markingAllLinesConfirmed()
        XCTAssertEqual(confirmed.reviewStatus, .reviewed)
        XCTAssertTrue(confirmed.pages[0].lines.allSatisfy(\.teacherConfirmed))
        XCTAssertNotNil(confirmed.reviewedAt)
    }
}

// MARK: - OCRQualitySummary edge cases

final class OCRQualitySummaryHardeningTests: XCTestCase {
    func testEmptyLinesProducesZeroCounts() {
        let summary = OCRQualitySummary(lines: [])
        XCTAssertEqual(summary.lineCount, 0)
        XCTAssertEqual(summary.lowConfidenceLineCount, 0)
        XCTAssertEqual(summary.unconfirmedLineCount, 0)
        XCTAssertEqual(summary.averageConfidence, 0)
        XCTAssertNil(summary.minimumConfidence)
        XCTAssertFalse(summary.requiresTeacherOCRReview)
    }

    func testAllHighConfidenceConfirmed() {
        let lines = [
            OCRLine(text: "A", confidence: 0.99, boundingBox: .zero, teacherConfirmed: true),
            OCRLine(text: "B", confidence: 0.95, boundingBox: .zero, teacherConfirmed: true)
        ]
        let summary = OCRQualitySummary(lines: lines)
        XCTAssertEqual(summary.lineCount, 2)
        XCTAssertEqual(summary.lowConfidenceLineCount, 0)
        XCTAssertEqual(summary.unconfirmedLineCount, 0)
        XCTAssertFalse(summary.requiresTeacherOCRReview)
    }

    func testAllLowConfidence() {
        let lines = [
            OCRLine(text: "A", confidence: 0.3, boundingBox: .zero, teacherConfirmed: false),
            OCRLine(text: "B", confidence: 0.5, boundingBox: .zero, teacherConfirmed: false)
        ]
        let summary = OCRQualitySummary(lines: lines)
        XCTAssertEqual(summary.lowConfidenceLineCount, 2)
        XCTAssertEqual(summary.unconfirmedLineCount, 2)
        XCTAssertTrue(summary.requiresTeacherOCRReview)
    }

    func testMinimumConfidenceTracked() {
        let lines = [
            OCRLine(text: "A", confidence: 0.99, boundingBox: .zero, teacherConfirmed: true),
            OCRLine(text: "B", confidence: 0.42, boundingBox: .zero, teacherConfirmed: false)
        ]
        let summary = OCRQualitySummary(lines: lines)
        XCTAssertEqual(summary.minimumConfidence, 0.42)
    }

    func testDisplaySummaryNoLines() {
        let summary = OCRQualitySummary()
        XCTAssertTrue(summary.displaySummary.contains("No OCR text"))
    }

    func testDisplaySummaryAllConfirmed() {
        let lines = [
            OCRLine(text: "A", confidence: 0.95, boundingBox: .zero, teacherConfirmed: true)
        ]
        let summary = OCRQualitySummary(lines: lines)
        XCTAssertTrue(summary.displaySummary.contains("confirmed"))
    }
}

// MARK: - SpreadsheetSafety edge cases

final class SpreadsheetSafetyHardeningTests: XCTestCase {
    func testEmptyStringUnchanged() {
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell(""), "")
    }

    func testTabPrefixNotEscaped() {
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("\tHello"), "\tHello")
    }

    func testNormalTextUnchanged() {
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("Hello World"), "Hello World")
    }

    func testEscapesTabThenFormula() {
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("\t=SUM(A1)"), "\t=SUM(A1)")
    }

    func testNegativeDecimalPreserved() {
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("-3.14"), "-3.14")
    }

    func testNegativeNonNumericEscaped() {
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("-abc"), "'-abc")
    }

    func testLeadingWhitespaceFormula() {
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("  =SUM"), "'  =SUM")
    }

    func testIsNumericalTextEdgeCases() {
        XCTAssertTrue(SpreadsheetSafety.isNumericalText("0"))
        XCTAssertTrue(SpreadsheetSafety.isNumericalText("  42  "))
        XCTAssertFalse(SpreadsheetSafety.isNumericalText(""))
        XCTAssertFalse(SpreadsheetSafety.isNumericalText("   "))
        XCTAssertFalse(SpreadsheetSafety.isNumericalText("12abc"))
    }
}

// MARK: - CSVExportService edge cases

final class CSVExportServiceHardeningTests: XCTestCase {
    func testEmptyAssignmentListProducesHeaderOnly() {
        let rows = CSVExportService.buildStudentRows(from: [])
        XCTAssertEqual(rows.count, 1, "Should only have header row")
        XCTAssertTrue(rows[0].contains("assignment_id"))
    }

    func testMultipleAssignmentsProduceMultipleRows() {
        let assignmentA = AssignmentRecord(title: "A", rubricText: "Claim: 0-4 points", reviewedStudentText: "text")
        let assignmentB = AssignmentRecord(title: "B", rubricText: "Evidence: 0-2 points", reviewedStudentText: "text")
        let rows = CSVExportService.buildStudentRows(from: [assignmentA, assignmentB])
        XCTAssertEqual(rows.count, 3, "Header + 2 data rows")
    }

    func testCSVOutputHasCorrectHeaderColumns() {
        let csv = CSVExportService.exportedCSV(from: [])
        XCTAssertTrue(csv.hasPrefix("\"assignment_id\""))
        XCTAssertTrue(csv.contains("\"final_status\""))
        XCTAssertTrue(csv.contains("\"ocr_status\""))
    }

    func testCSVNoPrivateNotesExposed() {
        var assignment = AssignmentRecord(title: "Test")
        assignment.reviewedStudentText = "text"
        assignment.rubricText = "Claim: 0-4 points"
        assignment.latestDraft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "",
            teacherNotes: "SECRET PRIVATE NOTE",
            uncertaintyFlags: []
        )
        let csv = CSVExportService.exportedCSV(from: [assignment])
        XCTAssertFalse(csv.contains("SECRET PRIVATE NOTE"))
    }

    func testDraftStatusNotGenerated() {
        let assignment = AssignmentRecord(title: "No draft")
        let rows = CSVExportService.buildStudentRows(from: [assignment])
        XCTAssertEqual(rows[1][12], "not_generated")
    }

    func testInProgressFinalStatus() {
        var assignment = AssignmentRecord(title: "In progress")
        assignment.rubricText = "Claim: 0-4 points"
        assignment.reviewedStudentText = "text"
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [FinalCriterionScore(
                criterion: "Claim", rating: "", proposedPoints: 0, finalPoints: 2,
                maxPoints: 4, evidence: [], explanation: "", teacherApproved: false
            )],
            totalScore: 2, maxScore: 4, studentFeedback: "", privateTeacherNotes: "", teacherEdited: false
        )
        let rows = CSVExportService.buildStudentRows(from: [assignment])
        XCTAssertEqual(rows[1][10], "in_progress")
    }
}

// MARK: - GradeDraftValidator hardening

final class GradeDraftValidatorHardeningTests: XCTestCase {
    func testProhibitedInferenceInSummaryThrows() {
        let input = sampleInput()
        let draft = GradeDraftResult(
            studentResponseSummary: "This student shows great effort and ability",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria[0].id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["Direct quote"],
                    explanation: "Met claim.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "Good job",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        XCTAssertThrowsError(try GradeDraftValidator.normalizeAndValidate(draft, input: input)) { error in
            XCTAssertEqual(error as? GradeDraftError, .invalidModelGrade("The model output included prohibited inference language."))
        }
    }

    func testProhibitedInferenceInFeedbackThrows() {
        let input = sampleInput()
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary of work",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria[0].id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["Quote"],
                    explanation: "Met claim.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "The student shows strong motivation and intelligence",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        XCTAssertThrowsError(try GradeDraftValidator.normalizeAndValidate(draft, input: input))
    }

    func testEmptyCriteriaThrows() {
        let input = sampleInput()
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        XCTAssertThrowsError(try GradeDraftValidator.normalizeAndValidate(draft, input: input)) { error in
            XCTAssertEqual(error as? GradeDraftError, .invalidModelGrade("At least one rubric criterion is required."))
        }
    }

    func testEmptyReviewedTextInInputThrows() {
        var input = sampleInput()
        input.reviewedStudentText = "  "
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria[0].id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["Quote"],
                    explanation: "Met.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        XCTAssertThrowsError(try GradeDraftValidator.normalizeAndValidate(draft, input: input))
    }

    func testDuplicateCriterionIDThrows() {
        let input = sampleInput(rubric: "Claim: 0-2 points\nEvidence: 0-4 points")
        let id = input.parsedRubric.criteria[0].id
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 2,
                    maxPoints: 2,
                    evidence: ["Quote"],
                    explanation: "Met.",
                    teacherReviewRequired: false
                ),
                CriterionScore(
                    criterionID: id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 2,
                    maxPoints: 2,
                    evidence: ["Quote"],
                    explanation: "Met.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 4,
            maxScore: 4,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        XCTAssertThrowsError(try GradeDraftValidator.normalizeAndValidate(draft, input: input))
    }

    func testEmptyCriterionNameThrows() {
        let input = sampleInput()
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria[0].id,
                    criterion: "   ",
                    rating: "Good",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["Quote"],
                    explanation: "Met.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        XCTAssertThrowsError(try GradeDraftValidator.normalizeAndValidate(draft, input: input))
    }

    func testEvidenceOutsideReviewedTextFlaggedForReview() throws {
        let input = sampleInput()
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria[0].id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["This text is NOT in the student response"],
                    explanation: "Met.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        let normalized = try GradeDraftValidator.normalizeAndValidate(draft, input: input)
        XCTAssertTrue(normalized.criteria[0].teacherReviewRequired, "Evidence not in reviewed text should flag for review")
    }

    func testMissingEvidenceMarkerIsRecognized() throws {
        let input = sampleInput()
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria[0].id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["No supporting evidence found."],
                    explanation: "Met.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        let normalized = try GradeDraftValidator.normalizeAndValidate(draft, input: input)
        XCTAssertTrue(normalized.criteria[0].teacherReviewRequired, "Missing evidence marker should flag for review")
    }

    func testConfidenceNormalization() throws {
        let input = sampleInput()
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria[0].id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["Student response"],
                    explanation: "Met.",
                    teacherReviewRequired: false,
                    confidence: "HIGH"
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        let normalized = try GradeDraftValidator.normalizeAndValidate(draft, input: input)
        XCTAssertEqual(normalized.criteria[0].confidence, "high")
    }

    func testUnknownConfidenceDefaultsToMedium() throws {
        let input = sampleInput()
        let draft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria[0].id,
                    criterion: "Claim",
                    rating: "Good",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["Student response"],
                    explanation: "Met.",
                    teacherReviewRequired: false,
                    confidence: "very confident"
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        let normalized = try GradeDraftValidator.normalizeAndValidate(draft, input: input)
        XCTAssertEqual(normalized.criteria[0].confidence, "medium")
    }

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

// MARK: - OCRReviewStatus edge cases

final class OCRReviewStatusHardeningTests: XCTestCase {
    func testBlocksGradingForNeedsReview() {
        XCTAssertTrue(OCRReviewStatus.needsReview.blocksGrading)
    }

    func testBlocksGradingForBlocked() {
        XCTAssertTrue(OCRReviewStatus.blocked.blocksGrading)
    }

    func testDoesNotBlockForReviewed() {
        XCTAssertFalse(OCRReviewStatus.reviewed.blocksGrading)
    }

    func testDoesNotBlockForNotNeeded() {
        XCTAssertFalse(OCRReviewStatus.notNeeded.blocksGrading)
    }

    func testDisplayNames() {
        XCTAssertFalse(OCRReviewStatus.notNeeded.displayName.isEmpty)
        XCTAssertFalse(OCRReviewStatus.needsReview.displayName.isEmpty)
        XCTAssertFalse(OCRReviewStatus.reviewed.displayName.isEmpty)
        XCTAssertFalse(OCRReviewStatus.blocked.displayName.isEmpty)
    }
}

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

// MARK: - FinalGradeReview / FinalCriterionScore edge cases

final class FinalGradeReviewHardeningTests: XCTestCase {
    func testAllCriteriaApprovedWhenEmpty() {
        let review = FinalGradeReview(
            criteria: [],
            totalScore: 0, maxScore: 0,
            studentFeedback: "", privateTeacherNotes: "", teacherEdited: false
        )
        XCTAssertFalse(review.allCriteriaApproved, "Empty criteria should not be 'all approved'")
    }

    func testAllCriteriaApprovedWhenAllApproved() {
        let review = FinalGradeReview(
            criteria: [
                FinalCriterionScore(criterion: "A", rating: "", proposedPoints: 0, finalPoints: 1, maxPoints: 1, evidence: [], explanation: "", teacherApproved: true),
                FinalCriterionScore(criterion: "B", rating: "", proposedPoints: 0, finalPoints: 1, maxPoints: 1, evidence: [], explanation: "", teacherApproved: true)
            ],
            totalScore: 2, maxScore: 2,
            studentFeedback: "", privateTeacherNotes: "", teacherEdited: true
        )
        XCTAssertTrue(review.allCriteriaApproved)
    }

    func testAllCriteriaApprovedFalseWhenOneUnapproved() {
        let review = FinalGradeReview(
            criteria: [
                FinalCriterionScore(criterion: "A", rating: "", proposedPoints: 0, finalPoints: 1, maxPoints: 1, evidence: [], explanation: "", teacherApproved: true),
                FinalCriterionScore(criterion: "B", rating: "", proposedPoints: 0, finalPoints: 1, maxPoints: 1, evidence: [], explanation: "", teacherApproved: false)
            ],
            totalScore: 2, maxScore: 2,
            studentFeedback: "", privateTeacherNotes: "", teacherEdited: true
        )
        XCTAssertFalse(review.allCriteriaApproved)
    }

    func testFinalCriterionScoreInitFromDraft() {
        let draft = CriterionScore(
            criterionID: "c-1",
            criterion: "Claim",
            rating: "Good",
            proposedPoints: 3,
            maxPoints: 4,
            evidence: ["evidence"],
            explanation: "explanation",
            teacherReviewRequired: true
        )
        let final = FinalCriterionScore(from: draft)
        XCTAssertEqual(final.criterionID, "c-1")
        XCTAssertEqual(final.criterion, "Claim")
        XCTAssertEqual(final.proposedPoints, 3)
        XCTAssertEqual(final.finalPoints, 3, "finalPoints should default to proposedPoints")
        XCTAssertEqual(final.maxPoints, 4)
        XCTAssertFalse(final.teacherApproved, "Should not be pre-approved")
        XCTAssertEqual(final.teacherRationale, "Review required by draft.")
    }

    func testFinalCriterionScoreInitFromDraftNoReviewRequired() {
        let draft = CriterionScore(
            criterion: "Claim",
            rating: "Good",
            proposedPoints: 3,
            maxPoints: 4,
            evidence: ["evidence"],
            explanation: "explanation",
            teacherReviewRequired: false
        )
        let final = FinalCriterionScore(from: draft)
        XCTAssertEqual(final.teacherRationale, "")
    }
}

// MARK: - ViewModel hardening tests

final class ViewModelHardeningTests: XCTestCase {
    @MainActor
    func testDuplicateCurrentAssignment() {
        let assignment = AssignmentRecord(
            title: "Original",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "text"
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.duplicateCurrentAssignment()
        XCTAssertEqual(viewModel.assignments.count, 2)
        let duplicate = viewModel.assignments.first { $0.id != assignment.id }
        XCTAssertNotNil(duplicate)
        XCTAssertTrue(duplicate?.title.contains("Copy of") ?? false)
        XCTAssertNil(duplicate?.latestDraft)
        XCTAssertNil(duplicate?.finalReview)
    }

    @MainActor
    func testCreateAssignmentsFromRosterCSV() {
        let assignment = AssignmentRecord(
            title: "Template",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: ""
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.createAssignmentsFromRosterCSV("Alice\nBob\nCharlie")
        XCTAssertEqual(viewModel.assignments.count, 4, "Should have original + 3 roster assignments")
    }

    @MainActor
    func testCreateAssignmentsFromRosterCSVEmpty() {
        let assignment = AssignmentRecord(title: "Template")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.createAssignmentsFromRosterCSV("")
        XCTAssertNotNil(viewModel.errorMessage, "Empty roster should show error")
    }

    @MainActor
    func testUpdateOCRLineChangesReviewStatus() {
        var assignment = AssignmentRecord(
            title: "OCR test",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Extracted text",
            ocrReviewStatus: .reviewed
        )
        let page = OCRPage(pageIndex: 0, lines: [
            OCRLine(text: "Extracted text", confidence: 0.95, boundingBox: .zero, teacherConfirmed: true)
        ])
        assignment.ocrDocument = OCRDocument(pages: [page], reviewStatus: .reviewed)
        let pageID = page.id
        let lineID = page.lines[0].id

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.updateOCRLine(pageID: pageID, lineID: lineID, correctedText: "Corrected text")
        XCTAssertEqual(viewModel.assignment.ocrReviewStatus, .needsReview, "Editing OCR should reset to needsReview")
    }

    @MainActor
    func testConfirmOCRLineSetsConfirmed() {
        var assignment = AssignmentRecord(
            title: "OCR confirm",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "text",
            ocrReviewStatus: .needsReview
        )
        let page = OCRPage(pageIndex: 0, lines: [
            OCRLine(text: "line", confidence: 0.95, boundingBox: .zero, teacherConfirmed: false)
        ])
        assignment.ocrDocument = OCRDocument(pages: [page])
        let pageID = page.id
        let lineID = page.lines[0].id

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.confirmOCRLine(pageID: pageID, lineID: lineID)
        XCTAssertEqual(viewModel.assignment.ocrReviewStatus, .reviewed, "Confirming the only line should set status to reviewed")
    }

    @MainActor
    func testRejectOCRLineRemovesLine() {
        var assignment = AssignmentRecord(
            title: "OCR reject",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "text",
            ocrReviewStatus: .needsReview
        )
        let page = OCRPage(pageIndex: 0, lines: [
            OCRLine(text: "line1", confidence: 0.95, boundingBox: .zero, teacherConfirmed: false),
            OCRLine(text: "line2", confidence: 0.95, boundingBox: .zero, teacherConfirmed: true)
        ])
        assignment.ocrDocument = OCRDocument(pages: [page])
        let pageID = page.id
        let lineID = page.lines[0].id

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.rejectOCRLine(pageID: pageID, lineID: lineID)
        XCTAssertEqual(viewModel.assignment.ocrDocument?.pages[0].lines.count, 2, "Rejected line metadata should be preserved for traceability")
        XCTAssertTrue(viewModel.assignment.ocrDocument?.pages[0].lines[0].isRejected ?? false)
        XCTAssertFalse(viewModel.assignment.reviewedStudentText.contains("line1"), "Rejected line text should be excluded from reviewed text")
    }

    @MainActor
    func testApplyTemplateResetsGradingState() {
        var assignment = AssignmentRecord(
            title: "Template test",
            rubricText: "Old rubric: 0-2 points",
            reviewedStudentText: "text"
        )
        assignment.latestDraft = GradeDraftResult(
            studentResponseSummary: "Summary", criteria: [], totalScore: 0, maxScore: 0,
            studentFeedback: "", teacherNotes: "", uncertaintyFlags: []
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        let template = RubricTemplates.builtIn[0]
        viewModel.applyTemplate(template)
        XCTAssertNil(viewModel.assignment.latestDraft, "Applying template should clear draft")
        XCTAssertNil(viewModel.assignment.finalReview, "Applying template should clear final review")
        XCTAssertEqual(viewModel.assignment.rubricText, template.rubricText)
    }

    @MainActor
    func testApplyPastedStudentTextResetsOCRState() {
        var assignment = AssignmentRecord(
            title: "Paste test",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "OCR text",
            ocrReviewStatus: .reviewed
        )
        assignment.ocrDocument = OCRDocument(pages: [
            OCRPage(pageIndex: 0, lines: [OCRLine(text: "OCR", confidence: 0.9, boundingBox: .zero)])
        ])

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.applyPastedStudentText("New pasted text")
        XCTAssertEqual(viewModel.assignment.reviewedStudentText, "New pasted text")
        XCTAssertNil(viewModel.assignment.ocrDocument, "Pasted text should clear OCR document")
        XCTAssertEqual(viewModel.assignment.ocrReviewStatus, .notNeeded)
    }

    @MainActor
    func testCannotApproveFinalReviewWithOutOfRangeScore() {
        var assignment = AssignmentRecord(
            title: "Out of range",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "text"
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 0,
                finalPoints: 5,
                maxPoints: 4,
                evidence: [],
                explanation: "",
                teacherApproved: true
            )],
            totalScore: 5,
            maxScore: 4,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: true
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canApproveFinalReview, "Out-of-range scores should block approval")
    }

    @MainActor
    func testCannotApproveFinalReviewWithEmptyCriteria() {
        var assignment = AssignmentRecord(
            title: "Empty criteria",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "text"
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

        XCTAssertFalse(viewModel.canApproveFinalReview, "Empty criteria should block approval")
    }

    @MainActor
    func testUpdateAssignmentMarksDraftStaleOnInputChange() {
        var assignment = AssignmentRecord(
            title: "Stale test",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "text"
        )
        assignment.latestDraft = GradeDraftResult(
            packetFingerprint: assignment.gradingPacketFingerprint,
            studentResponseSummary: "", criteria: [], totalScore: 0, maxScore: 0,
            studentFeedback: "", teacherNotes: "", uncertaintyFlags: []
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.updateAssignment { record in
            record.rubricText = "Evidence: 0-2 points"
        }
        XCTAssertEqual(viewModel.assignment.latestDraft?.status, .stale, "Draft should be marked stale on input change")
    }

    @MainActor
    func testReadinessIssuesIncludesLocalAIUnavailable() {
        let assignment = AssignmentRecord(
            title: "Test",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "text"
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            gradingService: UnavailableLocalGradingService(),
            store: store
        )
        XCTAssertTrue(viewModel.readinessIssues.contains { $0.lowercased().contains("unavailable") })
    }

    @MainActor
    func testExportStudentReportBlockedWhenNoFinalReview() {
        let assignment = AssignmentRecord(
            title: "Test",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "text"
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.exportStudentReport()
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.exportURL)
    }

    @MainActor
    func testStartFinalReviewFromLatestDraft() {
        var assignment = AssignmentRecord(
            title: "Draft review",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "text"
        )
        let draft = GradeDraftResult(
            packetFingerprint: assignment.gradingPacketFingerprint,
            studentResponseSummary: "Summary",
            criteria: [CriterionScore(
                criterionID: "c-1",
                criterion: "Claim",
                rating: "Good",
                proposedPoints: 3,
                maxPoints: 4,
                evidence: ["Quote"],
                explanation: "Met.",
                teacherReviewRequired: false
            )],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "Good",
            teacherNotes: "Notes",
            uncertaintyFlags: []
        )
        assignment.latestDraft = draft

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.startFinalReviewFromLatestDraft()
        XCTAssertNotNil(viewModel.assignment.finalReview)
        XCTAssertEqual(viewModel.assignment.finalReview?.status, .inProgress)
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria.count, 1)
        XCTAssertFalse(viewModel.assignment.finalReview?.criteria[0].teacherApproved ?? true)
    }

    @MainActor
    func testNewAssignmentFromTemplate() {
        let store = InMemoryAssignmentStore()
        let viewModel = GradeDraftViewModel(assignments: [AssignmentRecord()], store: store)

        let template = RubricTemplates.builtIn[0]
        viewModel.newAssignment(from: template)
        XCTAssertTrue(viewModel.assignments.contains { $0.rubricText == template.rubricText })
    }

    @MainActor
    func testNewAssignmentWithoutTemplate() {
        let store = InMemoryAssignmentStore()
        let viewModel = GradeDraftViewModel(assignments: [AssignmentRecord()], store: store)

        let countBefore = viewModel.assignments.count
        viewModel.newAssignment()
        XCTAssertEqual(viewModel.assignments.count, countBefore + 1)
    }

    @MainActor
    func testExportCSVGradebook() {
        var assignment = AssignmentRecord(title: "CSV test", rubricText: "Claim: 0-4 points", reviewedStudentText: "text")
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim", rating: "", proposedPoints: 0, finalPoints: 3,
                maxPoints: 4, evidence: [], explanation: "", teacherApproved: true
            )],
            totalScore: 3, maxScore: 4, studentFeedback: "", privateTeacherNotes: "", teacherEdited: true
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.exportCSVGradebook()
        XCTAssertNotNil(viewModel.exportURL)
        XCTAssertEqual(viewModel.exportKind, .csvGradebook)
    }

    @MainActor
    func testSelectAssignment() {
        let assignmentA = AssignmentRecord(title: "A")
        let assignmentB = AssignmentRecord(title: "B")
        let store = InMemoryAssignmentStore(assignments: [assignmentA, assignmentB])
        let viewModel = GradeDraftViewModel(assignments: [assignmentA, assignmentB], store: store)

        viewModel.selectAssignment(assignmentB.id)
        XCTAssertEqual(viewModel.selectedAssignmentID, assignmentB.id)
        XCTAssertEqual(viewModel.assignment.title, "B")
    }
}

// MARK: - EvidenceReference edge cases

final class EvidenceReferenceHardeningTests: XCTestCase {
    func testDisplaySourceWithOCRLineID() {
        let ref = EvidenceReference(
            ocrLineID: UUID(),
            pageIndex: 2,
            quote: "quote",
            sourceKind: "ocrLine",
            teacherConfirmed: true
        )
        XCTAssertTrue(ref.displaySource.contains("page 3"))
        XCTAssertTrue(ref.displaySource.contains("OCR line"))
    }

    func testDisplaySourceWithoutOCRLineID() {
        let ref = EvidenceReference(
            pageIndex: 0,
            quote: "quote",
            sourceKind: "text",
            teacherConfirmed: true
        )
        XCTAssertTrue(ref.displaySource.contains("page 1"))
        XCTAssertFalse(ref.displaySource.contains("OCR line"))
    }

    func testDisplaySourceWithoutPageIndex() {
        let ref = EvidenceReference(
            quote: "quote",
            sourceKind: "text",
            teacherConfirmed: true
        )
        XCTAssertTrue(ref.displaySource.contains("reviewed text"))
    }
}

// MARK: - AssignmentType / AssessmentPurpose

final class EnumDisplayNameTests: XCTestCase {
    func testAssignmentTypeDisplayNames() {
        for type in AssignmentType.allCases {
            XCTAssertFalse(type.displayName.isEmpty, "\(type.rawValue) should have a display name")
        }
    }

    func testAssessmentPurposeDisplayNames() {
        for purpose in AssessmentPurpose.allCases {
            XCTAssertFalse(purpose.displayName.isEmpty, "\(purpose.rawValue) should have a display name")
        }
    }

    func testSourceTypeDisplayNames() {
        for sourceType in SourceType.allCases {
            XCTAssertFalse(sourceType.displayName.isEmpty, "\(sourceType.rawValue) should have a display name")
        }
    }

    func testExportKindDisplayNames() {
        let allKinds: [ExportKind] = [.studentMarkdown, .teacherAuditMarkdown, .studentPDF, .teacherAuditPDF, .csvGradebook, .zipArchive, .fullBackupArchive, .backupJSON]
        for kind in allKinds {
            XCTAssertFalse(kind.displayName.isEmpty, "\(kind.rawValue) should have a display name")
        }
    }
}

// MARK: - PromptBuilder hardening

final class PromptBuilderHardeningTests: XCTestCase {
    func testPromptIncludesAnswerKeyWhenProvided() {
        var input = sampleInput()
        input.answerKeyText = "Expected answer: photosynthesis converts CO2."
        let prompt = PromptBuilder.gradingPrompt(input: input)
        XCTAssertTrue(prompt.contains("photosynthesis converts CO2"))
        XCTAssertTrue(prompt.contains("Answer key"))
    }

    func testPromptIncludesExemplarWhenProvided() {
        var input = sampleInput()
        input.exemplarText = "Exemplar: The student should mention both reactants."
        let prompt = PromptBuilder.gradingPrompt(input: input)
        XCTAssertTrue(prompt.contains("Exemplar"))
        XCTAssertTrue(prompt.contains("both reactants"))
    }

    func testPromptIncludesCustomInstructions() {
        var input = sampleInput()
        input.customInstructions = "Be lenient with spelling errors."
        let prompt = PromptBuilder.gradingPrompt(input: input)
        XCTAssertTrue(prompt.contains("lenient with spelling"))
    }

    func testPromptIncludesStructuredCriteriaWhenParsed() {
        let input = sampleInput(rubric: "Claim: 0-4 points\nEvidence: 0-2 points")
        let prompt = PromptBuilder.gradingPrompt(input: input)
        XCTAssertTrue(prompt.contains("Claim"))
        XCTAssertTrue(prompt.contains("Evidence"))
        XCTAssertTrue(prompt.contains("maxPoints"))
    }

    func testPromptShowsFallbackWhenNoCriteria() {
        let input = sampleInput(rubric: "This rubric has no points.")
        let prompt = PromptBuilder.gradingPrompt(input: input)
        XCTAssertTrue(prompt.contains("No structured point-bearing criteria"))
    }

    func testPromptIncludesCurriculumReference() {
        var input = sampleInput()
        input.curriculumReference = "ACELA1234 — Year 7 English literacy standard"
        let prompt = PromptBuilder.gradingPrompt(input: input)
        XCTAssertTrue(prompt.contains("ACELA1234"))
    }

    func testPromptIncludesOCRWarningWhenQualityUncertain() {
        var input = sampleInput()
        input.ocrQualitySummary = OCRQualitySummary(
            lineCount: 5,
            lowConfidenceLineCount: 2,
            unconfirmedLineCount: 3,
            averageConfidence: 0.6
        )
        let prompt = PromptBuilder.gradingPrompt(input: input)
        XCTAssertTrue(prompt.contains("OCR quality warning"))
    }

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

// MARK: - Export report content hardening

final class ExportReportHardeningTests: XCTestCase {
    func testStudentReportDoesNotContainRawModelResponse() {
        var assignment = AssignmentRecord(title: "Export test", reviewedStudentText: "Student text")
        assignment.rubricText = "Claim: 0-4 points"
        assignment.latestDraft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "Feedback",
            teacherNotes: "Private model note",
            uncertaintyFlags: [],
            rawModelResponse: "Raw JSON blob"
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim", rating: "", proposedPoints: 0, finalPoints: 3,
                maxPoints: 4, evidence: [], explanation: "", teacherApproved: true
            )],
            totalScore: 3, maxScore: 4, studentFeedback: "Final feedback",
            privateTeacherNotes: "Secret teacher note", teacherEdited: true
        )
        let report = MarkdownReportBuilder.studentMarkdown(for: assignment)
        XCTAssertFalse(report.contains("Raw JSON blob"))
        XCTAssertFalse(report.contains("Secret teacher note"))
        XCTAssertFalse(report.contains("Private model note"))
        XCTAssertTrue(report.contains("Final feedback"))
    }

    func testTeacherAuditContainsAuditEvents() {
        var assignment = AssignmentRecord(title: "Audit events test")
        assignment.appendAuditEvent(.assignmentCreated, detail: "Created for testing.")
        assignment.appendAuditEvent(.inputChanged, detail: "Rubric changed.")
        let audit = MarkdownReportBuilder.teacherAuditMarkdown(for: assignment)
        XCTAssertTrue(audit.contains("Created for testing."))
        XCTAssertTrue(audit.contains("Rubric changed."))
    }

    func testTeacherAuditContainsSourceInputs() {
        var assignment = AssignmentRecord(title: "Source test")
        assignment.sourceInputs = [
            SourceInputRef(sourceType: .scan, localRelativePath: "Sources/scan1.png", contentDigest: "test-digest", digestAlgorithm: "fnv1a64")
        ]
        let audit = MarkdownReportBuilder.teacherAuditMarkdown(for: assignment)
        XCTAssertTrue(audit.contains("scan1.png") || audit.contains("Document scan"))
    }

    func testStudentReportForAssignmentWithNoGrade() {
        let assignment = AssignmentRecord(title: "No grade", reviewedStudentText: "text")
        let report = MarkdownReportBuilder.studentMarkdown(for: assignment)
        XCTAssertTrue(report.contains("No grade has been drafted"))
    }

    func testStudentReportForDraftOnlyAssignment() {
        var assignment = AssignmentRecord(title: "Draft only", reviewedStudentText: "text")
        assignment.latestDraft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [CriterionScore(
                criterion: "Claim", rating: "Good", proposedPoints: 3, maxPoints: 4,
                evidence: ["quote"], explanation: "Met.", teacherReviewRequired: false
            )],
            totalScore: 3, maxScore: 4,
            studentFeedback: "Good work", teacherNotes: "Private", uncertaintyFlags: []
        )
        let report = MarkdownReportBuilder.studentMarkdown(for: assignment)
        XCTAssertTrue(report.contains("Draft grade for teacher review"))
        XCTAssertTrue(report.contains("Good work"))
        XCTAssertFalse(report.contains("Private"))
    }
}

// MARK: - BundleExportService hardening

final class BundleExportHardeningTests: XCTestCase {
    func testArchiveContainsAllExpectedFiles() throws {
        var assignment = AssignmentRecord(title: "Full archive test", reviewedStudentText: "Text")
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim", rating: "", proposedPoints: 0, finalPoints: 1,
                maxPoints: 1, evidence: [], explanation: "", teacherApproved: true
            )],
            totalScore: 1, maxScore: 1, studentFeedback: "Good.",
            privateTeacherNotes: "Private", teacherEdited: true
        )
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("archive-hardening-\(UUID()).zip")
        defer { try? FileManager.default.removeItem(at: destination) }
        let written = try BundleExportService.writeTeacherAuditArchive(assignment: assignment, sourceFiles: [], to: destination)
        guard let archive = Archive(url: written, accessMode: .read) else {
            return XCTFail("Archive should open")
        }
        XCTAssertNotNil(archive["manifest.json"])
        XCTAssertNotNil(archive["student_report.md"])
        XCTAssertNotNil(archive["teacher_audit_report.md"])
        XCTAssertNotNil(archive["assignment.json"])
        XCTAssertNotNil(archive["source_metadata.json"])
        XCTAssertNotNil(archive["grade_summary.csv"])
        XCTAssertNotNil(archive["student_report.pdf"])
        XCTAssertNotNil(archive["teacher_audit_report.pdf"])
    }

    func testFullBackupContainsManifestAndData() throws {
        let assignmentA = AssignmentRecord(title: "A", reviewedStudentText: "Text A")
        let assignmentB = AssignmentRecord(title: "B", reviewedStudentText: "Text B")
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("backup-hardening-\(UUID()).zip")
        defer { try? FileManager.default.removeItem(at: destination) }
        let written = try BundleExportService.writeFullBackup(assignments: [assignmentA, assignmentB], sourceFiles: [], to: destination)
        let restored = try BundleExportService.readBackupAssignments(from: written)
        XCTAssertEqual(restored.count, 2)
        XCTAssertTrue(restored.contains { $0.title == "A" })
        XCTAssertTrue(restored.contains { $0.title == "B" })
    }

    func testGradebookArchiveContainsExpectedFiles() throws {
        let gradebookAssignment = AssignmentRecord(title: "Gradebook A", reviewedStudentText: "Text")
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("gradebook-hardening-\(UUID()).zip")
        defer { try? FileManager.default.removeItem(at: destination) }
        let written = try BundleExportService.writeAssignmentArchive(assignments: [gradebookAssignment], sourceFiles: [], to: destination)
        guard let archive = Archive(url: written, accessMode: .read) else {
            return XCTFail("Archive should open")
        }
        XCTAssertNotNil(archive["manifest.json"])
        XCTAssertNotNil(archive["gradebook.csv"])
        XCTAssertNotNil(archive["assignments.json"])
    }
}

// MARK: - JSON Codable round-trip hardening

final class CodableRoundTripHardeningTests: XCTestCase {
    func testAssignmentRecordFullRoundTrip() throws {
        var original = AssignmentRecord(
            title: "Round trip test",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "Student text"
        )
        original.prompt = "What is photosynthesis?"
        original.ocrReviewStatus = .reviewed
        original.sourceInputs = [SourceInputRef(sourceType: .scan, contentDigest: "digest")]
        original.appendAuditEvent(.assignmentCreated, detail: "Created.")
        original.finalReview = FinalGradeReview(
            packetFingerprint: original.gradingPacketFingerprint,
            criteria: [FinalCriterionScore(
                criterion: "Claim", rating: "", proposedPoints: 0, finalPoints: 3,
                maxPoints: 4, evidence: [], explanation: "", teacherApproved: true
            )],
            totalScore: 3, maxScore: 4, studentFeedback: "Good.",
            privateTeacherNotes: "Private", teacherEdited: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AssignmentRecord.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.prompt, "What is photosynthesis?")
        XCTAssertEqual(decoded.ocrReviewStatus, .reviewed)
        XCTAssertEqual(decoded.sourceInputs.count, 1)
        XCTAssertEqual(decoded.auditEvents.count, 1)
        XCTAssertEqual(decoded.finalReview?.criteria.count, 1)
    }

    func testGradeDraftResultRoundTrip() throws {
        let original = GradeDraftResult(
            packetFingerprint: "fp-1",
            studentResponseSummary: "Summary",
            criteria: [CriterionScore(
                criterionID: "c-1",
                criterion: "Claim",
                rating: "Good",
                proposedPoints: 3,
                maxPoints: 4,
                evidence: ["Quote"],
                explanation: "Met.",
                teacherReviewRequired: true,
                confidence: "high"
            )],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "Good",
            teacherNotes: "Notes",
            uncertaintyFlags: ["flag1"],
            complianceFlags: ["compliance1"],
            rawModelResponse: "raw response"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GradeDraftResult.self, from: data)

        XCTAssertEqual(decoded.packetFingerprint, "fp-1")
        XCTAssertEqual(decoded.criteria.count, 1)
        XCTAssertEqual(decoded.criteria[0].confidence, "high")
        XCTAssertEqual(decoded.rawModelResponse, "raw response")
    }
}

// MARK: - SourceInputRef edge cases

final class SourceInputRefHardeningTests: XCTestCase {
    func testDefaultValuesAreCorrect() {
        let source = SourceInputRef(sourceType: .pastedText)
        XCTAssertFalse(source.teacherIncludedInExport)
        XCTAssertNil(source.localRelativePath)
        XCTAssertNil(source.contentDigest)
        XCTAssertNil(source.pdfPageCount)
    }

    func testPDFSourceWithMetadata() {
        let source = SourceInputRef(
            sourceType: .pdf,
            fileName: "work.pdf",
            mimeType: "application/pdf",
            pdfPageCount: 5
        )
        XCTAssertEqual(source.sourceType, .pdf)
        XCTAssertEqual(source.pdfPageCount, 5)
    }
}

// MARK: - GradeDraftError messages

final class GradeDraftErrorHardeningTests: XCTestCase {
    func testAllErrorsHaveDescriptions() {
        let errors: [GradeDraftError] = [
            .missingRubric,
            .missingStudentText,
            .ocrReviewRequired,
            .localModelUnavailable("reason"),
            .malformedModelResponse("detail"),
            .invalidModelGrade("detail"),
            .ocrFailed("detail"),
            .persistenceFailed("detail"),
            .exportFailed("detail")
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testErrorEquality() {
        XCTAssertEqual(GradeDraftError.missingRubric, GradeDraftError.missingRubric)
        XCTAssertNotEqual(GradeDraftError.missingRubric, GradeDraftError.missingStudentText)
        XCTAssertEqual(
            GradeDraftError.localModelUnavailable("a"),
            GradeDraftError.localModelUnavailable("a")
        )
        XCTAssertNotEqual(
            GradeDraftError.localModelUnavailable("a"),
            GradeDraftError.localModelUnavailable("b")
        )
    }

    func testNoProhibitedLabelsInErrorMessages() {
        let prohibited = ["auto-grade", "AutoGrade", "Accept AI grade", "AI final grade", "one-click grade", "Guaranteed Score"]
        let errors: [GradeDraftError] = [.missingRubric, .missingStudentText, .ocrReviewRequired]
        for error in errors {
            for term in prohibited {
                XCTAssertFalse(error.localizedDescription.contains(term))
            }
        }
    }
}

// MARK: - LocalOnlyGradingValidator

final class LocalOnlyGradingValidatorHardeningTests: XCTestCase {
    func testValidInputDoesNotThrow() {
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
        XCTAssertNoThrow(try LocalOnlyGradingValidator.validate(input))
    }

    func testBlockedOCRThrows() {
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
            ocrReviewStatus: .blocked,
            sourceInputCount: 0,
            packetFingerprint: "fp",
            hasGradingStandard: true
        )
        XCTAssertThrowsError(try LocalOnlyGradingValidator.validate(input)) { error in
            XCTAssertEqual(error as? GradeDraftError, .ocrReviewRequired)
        }
    }
}

// MARK: - All-features completion v3 coverage

private enum V3ArchiveTestError: Error {
    case missingEntry(String)
}

private final class V3TempAssignmentStore: AssignmentStoring {
    private(set) var assignments: [AssignmentRecord]
    private let root: URL

    init(assignments: [AssignmentRecord] = [], root: URL) {
        self.assignments = assignments
        self.root = root
    }

    func loadAssignments() throws -> [AssignmentRecord] { assignments }
    func saveAssignments(_ assignments: [AssignmentRecord]) throws { self.assignments = assignments }
    func deleteAssignment(id: UUID) throws { assignments.removeAll { $0.id == id } }
    func applicationSupportDirectory() throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}

final class AllFeaturesCompletionV3Tests: XCTestCase {
    func testMarkdownRubricParserSupportsHeadingsListsTablesLevelsDuplicatesAndPreview() {
        let markdown = """
        # Argument writing
        - [claim] Claim: 0-4 points. Excellent 4 points: precise claim. Beginning 0-1 points: missing claim.
        1. Evidence: 0-3 pts. Proficient 3 points: relevant evidence.
        | Criterion ID | Criterion | Max Points | Excellent | Developing |
        | --- | --- | ---: | --- | --- |
        | reasoning | Reasoning | 4 | 4 points: explains how evidence supports claim | 1-2 points: limited explanation |
        | duplicate | Claim | 4 | 4 points: duplicate claim | 1 point: duplicate |
        """

        let preview = MarkdownRubricParser.preview(markdown)
        XCTAssertEqual(preview.parsedRubric.groups, ["Argument writing"])
        XCTAssertTrue(preview.detectedCriteria.contains { $0.id == "claim" && $0.groupTitle == "Argument writing" })
        XCTAssertTrue(preview.detectedCriteria.contains { $0.title == "Evidence" })
        XCTAssertTrue(preview.detectedCriteria.contains { $0.id == "reasoning" && $0.title == "Reasoning" })
        XCTAssertTrue(preview.detectedLevels.contains { $0.label.localizedCaseInsensitiveContains("Excellent") })
        XCTAssertTrue(preview.issues.contains { $0.message.localizedCaseInsensitiveContains("Duplicate criterion") })
        XCTAssertTrue(preview.fallbackRawTextAvailable)
    }

    func testCurriculumCatalogLoadsFiltersMapsPersistsAndAvoidsEndorsementClaims() throws {
        let catalog = CurriculumCatalogService.localCatalog
        XCTAssertFalse(catalog.items.isEmpty)
        let englishYear7 = catalog.filtered(learningArea: "English", yearLevel: "Year 7")
        XCTAssertFalse(englishYear7.isEmpty)
        XCTAssertFalse(CurriculumCatalogService.sourceWarning.localizedCaseInsensitiveContains("endorsed by"))
        XCTAssertFalse(CurriculumCatalogService.sourceWarning.localizedCaseInsensitiveContains("certified by"))

        var assignment = approvedAssignment(title: "Curriculum map")
        let item = try XCTUnwrap(englishYear7.first)
        assignment.curriculumMappings = [CurriculumMapping(curriculumItemID: item.id, mappingKind: "assignment")]
        assignment.curriculumReference = CurriculumCatalogService.selectedReferenceSummary(items: [item])
        let audit = MarkdownReportBuilder.teacherAuditMarkdown(for: assignment)
        XCTAssertTrue(audit.contains(item.code))
        XCTAssertTrue(audit.localizedCaseInsensitiveContains("provenance"))
        XCTAssertTrue(assignment.gradingPacketFingerprint.contains("fnv1a64-"))
        XCTAssertTrue(PromptBuilder.gradingPrompt(input: assignment.gradingInput).contains(item.code))
    }

    func testRosterCSVPreviewDuplicateDetectionRejectedRowsAndGradebookCSV() {
        let csv = """
        displayName,localIdentifier,className,notes
        Alice,A1,6A,
        Bob,A2,6A,
        Alice,A3,6A,duplicate name allowed with warning
        ,A4,6A,missing name
        Chris,A2,6A,duplicate identifier rejected
        """
        let preview = RosterImportService.preview(csvText: csv, defaultClassName: "6A")
        XCTAssertEqual(preview.students.count, 3)
        XCTAssertTrue(preview.duplicateNames.contains("alice"))
        XCTAssertEqual(preview.rejectedRowDetails.count, 2)
        XCTAssertTrue(preview.hasHeaderRow)

        var alice = approvedAssignment(title: "Essay", student: "Alice", score: 4)
        alice.className = "6A"
        var bob = approvedAssignment(title: "Essay", student: "Bob", score: 3)
        bob.className = "6A"
        let csvOutput = CSVExportService.exportedCSV(from: [alice, bob])
        XCTAssertTrue(csvOutput.contains("\"Alice\""))
        XCTAssertTrue(csvOutput.contains("\"Bob\""))
        XCTAssertTrue(csvOutput.contains("\"approved\""))
    }

    @MainActor
    func testOCRLineEvidenceLinkingBoundingBoxRemovalAndStudentPrivacy() throws {
        let sourceID = UUID()
        var assignment = approvedAssignment(title: "Evidence", student: "Student")
        let line = OCRLine(
            text: "The quote supports my claim.",
            confidence: 0.99,
            boundingBox: NormalizedRect(x: 0.12, y: 0.22, width: 0.45, height: 0.08),
            teacherConfirmed: true
        )
        let page = OCRPage(sourceInputID: sourceID, pageIndex: 1, lines: [line])
        assignment.sourceInputs = [SourceInputRef(id: sourceID, sourceType: .pdf, pageIndex: 1, localRelativePath: "Sources/page-2.png")]
        assignment.ocrDocument = OCRDocument(pages: [page], reviewStatus: .reviewed)
        assignment.ocrReviewStatus = .reviewed
        assignment.reviewedStudentText = page.lines.map(\.reviewedText).joined(separator: "\n")
        var evidenceReview = try XCTUnwrap(assignment.finalReview)
        evidenceReview.criteria[0].evidence = []
        evidenceReview.criteria[0].evidenceSourceRefs = []
        let criterionID = evidenceReview.criteria[0].id
        assignment.finalReview = evidenceReview

        let store = V3TempAssignmentStore(assignments: [assignment], root: FileManager.default.temporaryDirectory.appendingPathComponent("V3Evidence-\(UUID())"))
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)
        viewModel.addOCRLineEvidenceToFinalReview(pageID: page.id, lineID: line.id, criterionID: criterionID)

        XCTAssertEqual(viewModel.assignment.evidenceReferences.count, 1)
        XCTAssertEqual(viewModel.assignment.evidenceReferences.first?.ocrLineID, line.id)
        XCTAssertEqual(viewModel.assignment.evidenceReferences.first?.boundingBox?.stableDisplay, "x:0.1200 y:0.2200 w:0.4500 h:0.0800")
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria[0].evidence.count, 1)
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria[0].evidenceSourceRefs?.count, 1)

        let teacherAudit = MarkdownReportBuilder.teacherAuditMarkdown(for: viewModel.assignment)
        XCTAssertTrue(teacherAudit.contains("bbox"))
        XCTAssertTrue(teacherAudit.contains("OCR line"))
        let studentReport = MarkdownReportBuilder.studentMarkdown(for: viewModel.assignment)
        XCTAssertFalse(studentReport.contains("bbox"))
        XCTAssertFalse(studentReport.contains("source:"))

        viewModel.removeEvidenceFromFinalReview(criterionID: criterionID, evidenceIndex: 0)
        XCTAssertTrue(viewModel.assignment.evidenceReferences.isEmpty)
        XCTAssertTrue(viewModel.assignment.finalReview?.criteria[0].evidence.isEmpty ?? false)
        XCTAssertTrue(viewModel.assignment.finalReview?.criteria[0].evidenceSourceRefs?.isEmpty ?? false)
    }

    @MainActor
    func testManualEvidenceAddAndClearKeepsEvidenceArraysAligned() throws {
        var assignment = approvedAssignment(title: "Manual evidence")
        var manualReview = try XCTUnwrap(assignment.finalReview)
        manualReview.criteria[0].evidence = []
        manualReview.criteria[0].evidenceSourceRefs = []
        let criterionID = manualReview.criteria[0].id
        assignment.finalReview = manualReview
        let store = V3TempAssignmentStore(assignments: [assignment], root: FileManager.default.temporaryDirectory.appendingPathComponent("V3ManualEvidence-\(UUID())"))
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.addManualEvidenceToFinalReview(criterionID: criterionID, quote: "Teacher-entered quote")
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria[0].evidence, ["Teacher-entered quote"])
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria[0].evidenceSourceRefs?.count, 1)
        XCTAssertEqual(viewModel.assignment.evidenceReferences.first?.sourceKind, "manualTeacherEntry")

        viewModel.clearEvidenceFromFinalReview(criterionID: criterionID)
        XCTAssertTrue(viewModel.assignment.finalReview?.criteria[0].evidence.isEmpty ?? false)
        XCTAssertTrue(viewModel.assignment.finalReview?.criteria[0].evidenceSourceRefs?.isEmpty ?? false)
        XCTAssertTrue(viewModel.assignment.evidenceReferences.isEmpty)
    }

    func testFullBackupArchiveIncludesAllRecordTypesManifestSafePathsAndRestoresSources() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("V3BackupSource-\(UUID())")
        let sourceFolder = tempRoot.appendingPathComponent("Sources/assignment-1", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        let sourceFile = sourceFolder.appendingPathComponent("page-1.png")
        try Data("source bytes".utf8).write(to: sourceFile)

        var assignment = approvedAssignment(title: "Backup", student: "Alice")
        assignment.sourceInputs = [SourceInputRef(sourceType: .pdf, pageIndex: 0, localRelativePath: "Sources/assignment-1/page-1.png", fileName: "work.pdf", mimeType: "application/pdf", contentDigest: "digest", digestAlgorithm: "fnv1a64", pdfPageCount: 1, teacherIncludedInExport: true)]
        assignment.evidenceReferences = [EvidenceReference(sourceInputID: assignment.sourceInputs[0].id, ocrLineID: UUID(), pageIndex: 0, quote: "Evidence", boundingBox: NormalizedRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2), sourceKind: "ocrLine", teacherConfirmed: true)]
        assignment.exportRecords = [ExportRecord(exportKind: .teacherAuditPDF, contentFingerprint: "fp", includesPrivateTeacherNotes: true, includesOriginalSources: true)]
        assignment.auditEvents = [AuditEvent(eventType: .exportPrepared, detail: "Prepared export.")]
        assignment.curriculumMappings = [CurriculumMapping(curriculumItemID: CurriculumCatalogService.localCatalog.items[0].id, mappingKind: "assignment")]
        assignment.ocrDocument = OCRDocument(pages: [OCRPage(sourceInputID: assignment.sourceInputs[0].id, pageIndex: 0, lines: [OCRLine(text: "Evidence", confidence: 1, boundingBox: .zero, teacherConfirmed: true)])], reviewStatus: .reviewed)

        let classGroup = ClassGroupRecord(name: "6A", schoolYear: "2026", term: "Term 1", subject: "English", gradeLevel: "Year 6")
        let student = StudentRecord(displayName: "Alice", className: "6A", localIdentifier: "A1")
        let rosterEntry = AssignmentRosterEntry(assignmentID: assignment.id, studentID: student.id, studentDisplayName: student.displayName, localIdentifier: student.localIdentifier, status: .approved, sortOrder: 0)
        let zipURL = tempRoot.appendingPathComponent("backup.zip")
        let written = try BundleExportService.writeFullBackup(assignments: [assignment], sourceFiles: [sourceFile], to: zipURL, classGroups: [classGroup], students: [student], rosterEntries: [rosterEntry])
        let archive = try openArchive(written)
        let expectedEntries = ["manifest.json", "schema_version.json", "database_export.json", "assignments.json", "class_groups.json", "students.json", "assignment_roster_entries.json", "source_inputs.json", "evidence_refs.json", "audit_events.json", "export_records.json", "curriculum_mappings.json", "ocr_documents.json"]
        for path in expectedEntries { XCTAssertNotNil(archive[path], "Missing archive entry: \(path)") }
        XCTAssertTrue(archive.contains { $0.path == "sources/Sources/assignment-1/page-1.png" })
        XCTAssertFalse(archive.contains { $0.path.contains("..") })

        let manifestData = try archiveData("manifest.json", in: archive)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(BackupArchiveManifest.self, from: manifestData)
        XCTAssertEqual(manifest.archiveKind, GradeDraftArchiveKind.fullLocalBackup.rawValue)
        XCTAssertEqual(manifest.recordCounts["assignments"], 1)
        XCTAssertEqual(manifest.recordCounts["students"], 1)
        XCTAssertTrue(manifest.includesOriginalSources)

        let restoreRoot = FileManager.default.temporaryDirectory.appendingPathComponent("V3BackupRestore-\(UUID())")
        let preview = try BundleExportService.previewRestore(from: written, existingAssignments: [assignment])
        XCTAssertEqual(preview.conflictAssignmentIDs, [assignment.id])
        let restoredAsCopy = try BundleExportService.restoreBackupArchive(from: written, existingAssignments: [assignment], applicationSupportDirectory: restoreRoot, conflictResolution: .restoreAsCopy)
        XCTAssertEqual(restoredAsCopy.count, 1)
        XCTAssertNotEqual(restoredAsCopy[0].id, assignment.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoreRoot.appendingPathComponent("Sources/assignment-1/page-1.png").path))
    }

    func testRestoreAsCopyRemapsConflictingAssignmentSourcePaths() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("V3BackupCopySource-\(UUID())")
        let restoreRoot = FileManager.default.temporaryDirectory.appendingPathComponent("V3BackupCopyRestore-\(UUID())")

        var assignment = approvedAssignment(title: "Backup", student: "Alice")
        let originalRelativePath = "Sources/\(assignment.id.uuidString)/page-1.png"
        let sourceFile = tempRoot.appendingPathComponent(originalRelativePath)
        try FileManager.default.createDirectory(at: sourceFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("source bytes".utf8).write(to: sourceFile)
        let localConflictFile = restoreRoot.appendingPathComponent(originalRelativePath)
        try FileManager.default.createDirectory(at: localConflictFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("local-only bytes".utf8).write(to: localConflictFile)
        assignment.sourceInputs = [
            SourceInputRef(
                sourceType: .pdf,
                pageIndex: 0,
                localRelativePath: originalRelativePath,
                fileName: "work.pdf",
                mimeType: "application/pdf",
                contentDigest: "digest",
                digestAlgorithm: "fnv1a64",
                pdfPageCount: 1,
                teacherIncludedInExport: true
            )
        ]

        let zipURL = tempRoot.appendingPathComponent("backup.zip")
        let written = try BundleExportService.writeFullBackup(assignments: [assignment], sourceFiles: [sourceFile], to: zipURL)

        let restoredAsCopy = try BundleExportService.restoreBackupArchive(
            from: written,
            existingAssignments: [assignment],
            applicationSupportDirectory: restoreRoot,
            conflictResolution: .restoreAsCopy
        )

        let copiedAssignment = try XCTUnwrap(restoredAsCopy.first)
        let copiedRelativePath = try XCTUnwrap(copiedAssignment.sourceInputs.first?.localRelativePath)
        XCTAssertNotEqual(copiedAssignment.id, assignment.id)
        XCTAssertEqual(copiedRelativePath, "Sources/\(copiedAssignment.id.uuidString)/page-1.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoreRoot.appendingPathComponent(copiedRelativePath).path))
        let copiedText = try XCTUnwrap(String(data: try Data(contentsOf: restoreRoot.appendingPathComponent(copiedRelativePath)), encoding: .utf8))
        XCTAssertEqual(copiedText, "source bytes")
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoreRoot.appendingPathComponent(originalRelativePath).path))
        let localConflictText = try XCTUnwrap(String(data: try Data(contentsOf: localConflictFile), encoding: .utf8))
        XCTAssertEqual(localConflictText, "local-only bytes")
    }

    @MainActor
    func testBackupRestoreUIPathDetectsConflictAndRestoresAsCopy() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("V3ViewModelRestore-\(UUID())")
        let local = approvedAssignment(title: "Local", student: "Alice")
        var backup = local
        backup.title = "Backup version"
        let zipURL = tempRoot.appendingPathComponent("backup.zip")
        try BundleExportService.writeFullBackup(assignments: [backup], sourceFiles: [], to: zipURL)
        let store = V3TempAssignmentStore(assignments: [local], root: tempRoot.appendingPathComponent("AppSupport"))
        let viewModel = GradeDraftViewModel(assignments: [local], store: store)
        viewModel.backupConflictResolution = .restoreAsCopy

        viewModel.restoreBackup(from: zipURL)

        XCTAssertEqual(viewModel.latestRestorePreview?.conflictAssignmentIDs, [local.id])
        XCTAssertEqual(viewModel.assignments.count, 2)
        XCTAssertTrue(viewModel.assignments.contains { $0.title == "Local" })
        XCTAssertTrue(viewModel.assignments.contains { $0.title.contains("Restored copy") })
    }

    func testNormalizedDatabaseLoadsFromNormalizedTablesAfterCompatibilityPayloadsAreRemoved() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("V3NormalizedDB-\(UUID())")
        let database = try GradeDraftDatabase(applicationSupportURL: root)
        try database.bootstrapIfNeeded()

        let classGroup = ClassGroupRecord(name: "6A", schoolYear: "2026", term: "Term 1", subject: "English", gradeLevel: "Year 6")
        let student = StudentRecord(displayName: "Alice", className: "6A", localIdentifier: "A1")
        var assignment = approvedAssignment(title: "Normalized", student: student.displayName)
        assignment.classGroupID = classGroup.id
        assignment.studentID = student.id
        assignment.sourceInputs = [SourceInputRef(sourceType: .pdf, pageIndex: 0, localRelativePath: "Sources/normalized/page.png", pdfPageCount: 1)]
        assignment.ocrDocument = OCRDocument(pages: [OCRPage(sourceInputID: assignment.sourceInputs[0].id, pageIndex: 0, lines: [OCRLine(text: "Line", confidence: 1, boundingBox: .zero, teacherConfirmed: true)])], reviewStatus: .reviewed)
        assignment.evidenceReferences = [EvidenceReference(sourceInputID: assignment.sourceInputs[0].id, ocrLineID: assignment.ocrDocument?.pages[0].lines[0].id, pageIndex: 0, quote: "Line", boundingBox: .zero, sourceKind: "ocrLine", teacherConfirmed: true)]
        assignment.curriculumMappings = [CurriculumMapping(curriculumItemID: CurriculumCatalogService.localCatalog.items[0].id, mappingKind: "assignment")]
        let rosterEntry = AssignmentRosterEntry(assignmentID: assignment.id, studentID: student.id, studentDisplayName: student.displayName, localIdentifier: student.localIdentifier, status: .approved, sortOrder: 0)

        try database.saveClassGroup(classGroup)
        try database.saveStudent(student)
        try database.saveAssignments([assignment])
        try database.saveAssignmentRoster([rosterEntry])
        try database.removeCompatibilityPayloadsForValidation()

        let loaded = try XCTUnwrap(database.loadFullAssignmentGraph(id: assignment.id))
        XCTAssertEqual(loaded.title, "Normalized")
        XCTAssertEqual(loaded.sourceInputs.count, 1)
        XCTAssertEqual(loaded.ocrDocument?.pages[0].lines[0].rawText, "Line")
        XCTAssertEqual(loaded.evidenceReferences.count, 1)
        XCTAssertEqual(loaded.finalReview?.criteria.count, 1)
        XCTAssertEqual(loaded.curriculumMappings.count, 1)
        XCTAssertEqual(try database.loadAssignmentRoster(assignmentID: assignment.id).first?.status, .approved)
        XCTAssertEqual(try database.loadClassGroups().first?.name, "6A")
        XCTAssertEqual(try database.loadStudents().first?.displayName, "Alice")
    }

    @MainActor
    func testStudentPDFExportBlockedBeforeApprovedFinalReviewAndTeacherExportRecordIsSensitive() throws {
        var assignment = approvedAssignment(title: "Exports")
        var pendingReview = try XCTUnwrap(assignment.finalReview)
        pendingReview.status = .inProgress
        assignment.finalReview = pendingReview
        let store = V3TempAssignmentStore(assignments: [assignment], root: FileManager.default.temporaryDirectory.appendingPathComponent("V3ExportGate-\(UUID())"))
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.exportStudentPDF()
        XCTAssertNil(viewModel.exportURL)
        XCTAssertNotNil(viewModel.errorMessage)

        viewModel.exportTeacherAuditPDF()
        XCTAssertEqual(viewModel.assignment.exportRecords.last?.exportKind, .teacherAuditPDF)
        XCTAssertTrue(viewModel.assignment.exportRecords.last?.includesPrivateTeacherNotes ?? false)
    }

    private func approvedAssignment(title: String, student: String = "Student", score: Double = 1) -> AssignmentRecord {
        var assignment = AssignmentRecord(
            title: title,
            prompt: "Prompt",
            subject: "English",
            gradeLevel: "Year 6",
            curriculumReference: "",
            className: "6A",
            studentDisplayName: student,
            assignmentType: .essay,
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "The quote supports my claim.",
            ocrReviewStatus: .reviewed
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "Proficient",
                proposedPoints: score,
                finalPoints: score,
                maxPoints: 4,
                evidence: ["The quote supports my claim."],
                evidenceSourceRefs: [],
                explanation: "The response supports a claim.",
                teacherApproved: true
            )],
            totalScore: score,
            maxScore: 4,
            studentFeedback: "Teacher-approved feedback.",
            privateTeacherNotes: "Private teacher notes.",
            teacherEdited: true
        )
        return assignment
    }

    private func openArchive(_ url: URL) throws -> Archive {
        guard let archive = Archive(url: url, accessMode: .read) else { throw V3ArchiveTestError.missingEntry(url.lastPathComponent) }
        return archive
    }

    private func archiveData(_ path: String, in archive: Archive) throws -> Data {
        guard let entry = archive[path] else { throw V3ArchiveTestError.missingEntry(path) }
        var data = Data()
        _ = try archive.extract(entry) { chunk in data.append(chunk) }
        return data
    }
}
