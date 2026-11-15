import XCTest
@testable import GradeDraft

// MARK: - SourceInputRef edge cases

final class SourceInputRefHardeningTests: XCTestCase {
    func testDefaultValuesAreCorrect() {
        let source = SourceInputRef(submissionID: UUID(), sourceType: .pastedText)
        XCTAssertFalse(source.includedInTeacherArchive)
        XCTAssertNil(source.localRelativePath)
        XCTAssertNil(source.sha256)
        XCTAssertNil(source.pdfPageCount)
    }

    func testPDFSourceWithMetadata() {
        let source = SourceInputRef(
            submissionID: UUID(),
            sourceType: .pdf,
            fileName: "work.pdf",
            mimeType: "application/pdf",
            pdfPageCount: 5
        )
        XCTAssertEqual(source.sourceType, .pdf)
        XCTAssertEqual(source.pdfPageCount, 5)
    }
}
