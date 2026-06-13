import XCTest
@testable import GradeDraft

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
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("\t=SUM(A1)"), "'\t=SUM(A1)")
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
