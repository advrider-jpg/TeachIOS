import XCTest
@testable import GradeDraft

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
