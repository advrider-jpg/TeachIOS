import XCTest
@testable import GradeDraft

// MARK: - OCRQualitySummary edge cases

final class OCRQualitySummaryHardeningTests: XCTestCase {
    private func line(_ text: String, confidence: Float, confirmed: Bool) -> OCRLine {
        OCRLine(text: text, confidence: confidence, boundingBox: .zero, origin: .visionOCR, teacherConfirmed: confirmed)
    }

    /// Changed expectation: with no scored lines the average is nil (it used to be reported as 0, which read
    /// as "every line scored zero").
    func testEmptyLinesProducesZeroCounts() {
        let summary = OCRQualitySummary(lines: [])
        XCTAssertEqual(summary.lineCount, 0)
        XCTAssertEqual(summary.lowConfidenceLineCount, 0)
        XCTAssertEqual(summary.unresolvedLineCount, 0)
        XCTAssertNil(summary.averageConfidence)
        XCTAssertNil(summary.minimumConfidence)
        XCTAssertFalse(summary.requiresTeacherOCRReview)
    }

    func testAllHighConfidenceConfirmed() {
        let lines = [
            line("A", confidence: 0.99, confirmed: true),
            line("B", confidence: 0.95, confirmed: true)
        ]
        let summary = OCRQualitySummary(lines: lines)
        XCTAssertEqual(summary.lineCount, 2)
        XCTAssertEqual(summary.lowConfidenceLineCount, 0)
        XCTAssertEqual(summary.unresolvedLineCount, 0)
        XCTAssertFalse(summary.requiresTeacherOCRReview)
    }

    func testAllLowConfidence() {
        let lines = [
            line("A", confidence: 0.3, confirmed: false),
            line("B", confidence: 0.5, confirmed: false)
        ]
        let summary = OCRQualitySummary(lines: lines)
        XCTAssertEqual(summary.lowConfidenceLineCount, 2)
        XCTAssertEqual(summary.unresolvedLineCount, 2)
        XCTAssertTrue(summary.requiresTeacherOCRReview)
    }

    func testMinimumConfidenceTracked() {
        let lines = [
            line("A", confidence: 0.99, confirmed: true),
            line("B", confidence: 0.42, confirmed: false)
        ]
        let summary = OCRQualitySummary(lines: lines)
        XCTAssertEqual(summary.minimumConfidence, 0.42)
    }

    func testDisplaySummaryNoLines() {
        let summary = OCRQualitySummary()
        XCTAssertTrue(summary.displaySummary.contains("No scanned text"))
    }

    /// Changed wording: the summary says "reviewed" (not "confirmed") when no line needs the teacher.
    func testDisplaySummaryAllConfirmed() {
        let lines = [
            line("A", confidence: 0.95, confirmed: true)
        ]
        let summary = OCRQualitySummary(lines: lines)
        XCTAssertTrue(summary.displaySummary.contains("reviewed"))
    }
}
