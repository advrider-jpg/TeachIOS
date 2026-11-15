import XCTest
@testable import GradeDraft

// MARK: - OCR model edge cases

final class OCRModelHardeningTests: XCTestCase {
    private func makeLine(
        _ text: String = "text",
        confidence: Float? = 0.95,
        origin: OCRLineOrigin = .visionOCR,
        corrected: String? = nil,
        confirmed: Bool = false
    ) -> OCRLine {
        OCRLine(text: text, confidence: confidence, boundingBox: .zero, origin: origin, correctedText: corrected, teacherConfirmed: confirmed)
    }

    func testOCRLineReviewedTextUsesCorrectedWhenPresent() {
        let line = makeLine("raw text", confidence: 0.9, corrected: "corrected text")
        XCTAssertEqual(line.reviewedText, "corrected text")
        XCTAssertEqual(line.rawText, "raw text")
    }

    func testOCRLineReviewedTextFallsBackToRaw() {
        let line = makeLine("raw text", confidence: 0.9)
        XCTAssertEqual(line.reviewedText, "raw text")
    }

    func testOCRLineReviewedTextFallsBackWhenCorrectedIsEmpty() {
        let line = makeLine("raw text", confidence: 0.9, corrected: "  ")
        XCTAssertEqual(line.reviewedText, "raw text", "Empty corrected text should fall back to raw")
    }

    func testOCRLineReviewedTextFallsBackWhenCorrectedIsWhitespace() {
        let line = makeLine("raw text", confidence: 0.9, corrected: "\n\t")
        XCTAssertEqual(line.reviewedText, "raw text")
    }

    func testOCRLineNeedsReviewWhenLowConfidence() {
        let line = makeLine(confidence: 0.5, confirmed: false)
        XCTAssertTrue(line.needsReview, "An unconfirmed low-confidence line should require review")
    }

    /// Changed expectation: a low-confidence line stays in review until the teacher acts, then it is resolved
    /// (the old rule kept confirmed low-confidence lines in review forever, so review could never be finished).
    func testOCRLineLowConfidenceIsResolvedOnceConfirmed() {
        let line = makeLine(confidence: 0.5, confirmed: true)
        XCTAssertFalse(line.needsReview)
    }

    /// Changed expectation: only low-confidence Vision lines (and every PDF text-layer line) need review;
    /// an unconfirmed high-confidence Vision line does not.
    func testOCRLineHighConfidenceVisionLineDoesNotNeedReviewUnconfirmed() {
        let line = makeLine(confidence: 0.95, confirmed: false)
        XCTAssertFalse(line.needsReview)
    }

    func testOCRLineDoesNotNeedReviewWhenHighConfidenceAndConfirmed() {
        let line = makeLine(confidence: 0.95, confirmed: true)
        XCTAssertFalse(line.needsReview)
    }

    func testOCRLineReviewStatusLabelConfirmed() {
        let line = makeLine(confidence: 0.95, confirmed: true)
        XCTAssertEqual(line.reviewStatusLabel, "On track")
    }

    func testOCRLineReviewStatusLabelCorrected() {
        let line = makeLine("raw", confidence: 0.95, corrected: "corrected", confirmed: true)
        XCTAssertEqual(line.reviewStatusLabel, "On track")
    }

    /// Uses a low-confidence line: an unconfirmed high-confidence Vision line no longer needs attention.
    func testOCRLineReviewStatusLabelUnreviewed() {
        let line = makeLine(confidence: 0.5, confirmed: false)
        XCTAssertEqual(line.reviewStatusLabel, "Needs attention")
    }

    func testOCRLineReviewStatusLabelBlockedFromGrading() {
        let line = makeLine(confidence: 0.95, corrected: "   ", confirmed: false)
        XCTAssertEqual(line.reviewStatusLabel, "Fix before continuing")
    }

    func testOCRDocumentCombinedTextUsesReviewedText() {
        let doc = OCRDocument(
            pages: [
                OCRPage(pageIndex: 0, lines: [
                    makeLine("raw1", confidence: 0.9, corrected: "corrected1"),
                    makeLine("raw2", confidence: 0.9)
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
                    makeLine("raw1", confidence: 0.9, corrected: "corrected1")
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
                    makeLine("line1", confidence: 0.9),
                    makeLine("line2", confidence: 0.5)
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
                    makeLine("line1", confidence: 0.9),
                    makeLine("line2", confidence: 0.95)
                ])
            ]
        )
        let confirmed = doc.markingAllLinesConfirmed()
        XCTAssertEqual(confirmed.reviewStatus, .reviewed)
        XCTAssertTrue(confirmed.pages[0].lines.allSatisfy(\.teacherConfirmed))
        XCTAssertNotNil(confirmed.reviewedAt)
    }
}
