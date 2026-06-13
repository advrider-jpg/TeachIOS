import XCTest
@testable import GradeDraft

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
