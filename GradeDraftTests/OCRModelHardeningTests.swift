import XCTest
@testable import GradeDraft

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
        XCTAssertEqual(line.reviewStatusLabel, "On track")
    }

    func testOCRLineReviewStatusLabelCorrected() {
        let line = OCRLine(text: "raw", confidence: 0.95, boundingBox: .zero, correctedText: "corrected", teacherConfirmed: true)
        XCTAssertEqual(line.reviewStatusLabel, "On track")
    }

    func testOCRLineReviewStatusLabelUnreviewed() {
        let line = OCRLine(text: "text", confidence: 0.95, boundingBox: .zero, teacherConfirmed: false)
        XCTAssertEqual(line.reviewStatusLabel, "Needs attention")
    }

    func testOCRLineReviewStatusLabelBlockedFromGrading() {
        let line = OCRLine(text: "text", confidence: 0.95, boundingBox: .zero, correctedText: "   ", teacherConfirmed: false)
        XCTAssertEqual(line.reviewStatusLabel, "Fix before continuing")
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

    func testMarkingAllLinesConfirmedOnlyConfirmsLinesAboveLowConfidenceThreshold() {
        let doc = OCRDocument(
            pages: [
                OCRPage(pageIndex: 0, lines: [
                    OCRLine(text: "line1", confidence: 0.9, boundingBox: .zero, teacherConfirmed: false),
                    OCRLine(text: "line2", confidence: 0.5, boundingBox: .zero, teacherConfirmed: false)
                ])
            ]
        )
        let confirmed = doc.markingAllLinesConfirmed()
        XCTAssertEqual(confirmed.reviewStatus, .needsReview)
        XCTAssertTrue(confirmed.pages[0].lines[0].teacherConfirmed)
        XCTAssertFalse(confirmed.pages[0].lines[1].teacherConfirmed)
        XCTAssertNil(confirmed.reviewedAt)
    }

    func testMarkingAllLinesConfirmedReviewsDocumentWhenNoLowConfidenceLinesRemain() {
        let doc = OCRDocument(
            pages: [
                OCRPage(pageIndex: 0, lines: [
                    OCRLine(text: "line1", confidence: 0.9, boundingBox: .zero, teacherConfirmed: false),
                    OCRLine(text: "line2", confidence: 0.95, boundingBox: .zero, teacherConfirmed: false)
                ])
            ]
        )
        let confirmed = doc.markingAllLinesConfirmed()
        XCTAssertEqual(confirmed.reviewStatus, .reviewed)
        XCTAssertTrue(confirmed.pages[0].lines.allSatisfy(\.teacherConfirmed))
        XCTAssertNotNil(confirmed.reviewedAt)
    }
}
