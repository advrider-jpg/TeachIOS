import Foundation
import Testing
@testable import GradeDraft

struct ImportTests {
    private func fixture(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("PDF")
            .appendingPathComponent(name)
    }

    @Test func pdfTextLayerLinesUseRealPositionsAndNoConfidence() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImportTests-\(UUID().uuidString)", isDirectory: true)
        let sourcesRoot = root.appendingPathComponent("Sources", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SourceImportService(sourcesRoot: sourcesRoot)

        let imported = try await service.importPDF(at: fixture("two-lines.pdf"), submissionID: UUID())
        let page = try #require(imported.ocr.pages.first)
        #expect(page.lines.count == 2)
        let first = try #require(page.lines.first)
        let second = try #require(page.lines.last)
        #expect(first.rawText.hasPrefix("First line of the essay"))
        #expect(second.rawText.hasPrefix("Second line of the essay"))

        // Bottom-left origin: the line that is higher on the page has the larger y.
        let firstBox = try #require(first.boundingBox)
        let secondBox = try #require(second.boundingBox)
        #expect(firstBox.y > secondBox.y)
        for box in [firstBox, secondBox] {
            #expect(box.x >= 0 && box.y >= 0)
            #expect(box.x + box.width <= 1 && box.y + box.height <= 1)
        }
        for line in page.lines {
            #expect(line.confidence == nil)
            #expect(line.origin == .pdfTextLayer)
            #expect(line.needsReview)
        }

        let locked = await #expect(throws: ImportError.pdfLocked) {
            try await service.importPDF(at: fixture("locked.pdf"), submissionID: UUID())
        }
        #expect(locked?.errorDescription == "This PDF is password-protected. Remove the password and import it again.")
    }
}
