import XCTest
@testable import GradeDraft

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
