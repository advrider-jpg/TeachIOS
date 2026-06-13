import XCTest
@testable import GradeDraft

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
