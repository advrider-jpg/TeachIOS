import XCTest
@testable import GradeDraft

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
        XCTAssertTrue(summary.displaySummary.contains("No scanned text"))
    }

    func testDisplaySummaryAllConfirmed() {
        let lines = [
            OCRLine(text: "A", confidence: 0.95, boundingBox: .zero, teacherConfirmed: true)
        ]
        let summary = OCRQualitySummary(lines: lines)
        XCTAssertTrue(summary.displaySummary.contains("confirmed"))
    }
}
