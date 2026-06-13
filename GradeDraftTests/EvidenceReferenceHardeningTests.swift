import XCTest
@testable import GradeDraft

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
        XCTAssertTrue(ref.displaySource.contains("text line"))
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
