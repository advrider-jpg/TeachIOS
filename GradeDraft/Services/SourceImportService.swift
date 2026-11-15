import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import Vision

struct ImportedInput: Sendable {
    var sources: [SourceInputRef]
    var ocr: OCRDocument
}

enum ImportError: LocalizedError, Equatable {
    case pdfLocked
    case pdfUnreadable
    case noPages
    case imageUnreadable
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .pdfLocked:
            return "This PDF is password-protected. Remove the password and import it again."
        case .pdfUnreadable:
            return "This PDF could not be opened."
        case .noPages:
            return "This file has no pages to import."
        case .imageUnreadable:
            return "One of the images could not be read."
        case .writeFailed(let detail):
            return detail
        }
    }
}

/// Imports scanned pages, photos and PDFs for one submission, off the main thread, one page at a time
/// (render, write HEIC, recognise, release). The caller saves the result with `AppDatabase.replaceInput`
/// and deletes the replaced files that call returns.
actor SourceImportService {
    /// Typed-page test (plan 3.7): enough text and enough of the page covered by that text.
    private static let typedPageMinimumCharacters = 200
    /// Separates a page with real body text from one with only a printed header or name line. Typed
    /// body text on a normal page covers roughly 25-45% of the page area; text-layer lines still need the
    /// teacher's line-by-line confirmation, so a copier's text layer cannot skip review.
    private static let typedPageMinimumCoverage: CGFloat = 0.2
    private static let pdfRenderScale: CGFloat = 2
    private static let heicQuality: CGFloat = 0.8

    private let fileManager: FileManager
    /// The folder that holds one sub-folder per submission. Stored paths are `Sources/<submissionID>/...`.
    private let sourcesRoot: URL

    init(fileManager: FileManager = .default, sourcesRoot: URL) {
        self.fileManager = fileManager
        self.sourcesRoot = sourcesRoot
    }

    func importScannedImages(_ images: [CGImage], submissionID: UUID) async throws -> ImportedInput {
        try await importImages(count: images.count, sourceType: .scan, submissionID: submissionID) { index in
            images[index]
        }
    }

    func importPhotos(_ imageData: [Data], submissionID: UUID) async throws -> ImportedInput {
        try await importImages(count: imageData.count, sourceType: .photo, submissionID: submissionID) { index in
            try Self.decodeImage(imageData[index])
        }
    }

    func importPDF(at url: URL, submissionID: UUID) async throws -> ImportedInput {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url) else { throw ImportError.pdfUnreadable }
        if document.isLocked { throw ImportError.pdfLocked }
        guard document.pageCount > 0 else { throw ImportError.noPages }

        let directory = submissionDirectory(submissionID)
        var writtenFiles: [URL] = []
        do {
            try LocalDataProtection.prepareSensitiveDirectory(directory, fileManager: fileManager)
            let originalDirectory = directory.appendingPathComponent("original", isDirectory: true)
            try LocalDataProtection.prepareSensitiveDirectory(originalDirectory, fileManager: fileManager)

            let originalID = UUID()
            let originalURL = originalDirectory.appendingPathComponent("\(originalID.uuidString).pdf")
            writtenFiles.append(originalURL)
            try copyFile(from: url, to: originalURL)
            var sources = [
                SourceInputRef(
                    id: originalID,
                    submissionID: submissionID,
                    sourceType: .pdf,
                    pageIndex: nil,
                    localRelativePath: relativePath(submissionID, "original/\(originalID.uuidString).pdf"),
                    fileName: url.lastPathComponent,
                    mimeType: "application/pdf",
                    sha256: try ContentDigest.sha256Hex(fileAt: originalURL),
                    pixelWidth: nil,
                    pixelHeight: nil,
                    pdfPageCount: document.pageCount,
                    includedInTeacherArchive: true,
                    createdAt: Date()
                )
            ]

            var pages: [OCRPage] = []
            var usedTextLayer = false
            var usedVision = false
            for pageIndex in 0..<document.pageCount {
                try Task.checkCancellation()
                guard let pdfPage = document.page(at: pageIndex) else { throw ImportError.pdfUnreadable }
                let image = try Self.render(pdfPage)
                let file = try writePage(image, index: pageIndex, submissionID: submissionID)
                writtenFiles.append(file.url)
                let source = try makeSource(
                    file: file,
                    image: image,
                    sourceType: .pdf,
                    pageIndex: pageIndex,
                    fileName: "PDF page \(pageIndex + 1) render",
                    pdfPageCount: document.pageCount,
                    submissionID: submissionID
                )
                sources.append(source)

                let lines: [OCRLine]
                if let typed = Self.typedLines(for: pdfPage) {
                    lines = typed
                    usedTextLayer = true
                } else {
                    lines = try await Self.recognise(image)
                    usedVision = true
                }
                pages.append(Self.page(source: source, pageIndex: pageIndex, lines: lines))
            }

            let engine = switch (usedTextLayer, usedVision) {
            case (true, true): "PDFKit digital text + Apple Vision"
            case (true, false): "PDFKit digital text"
            default: "Apple Vision"
            }
            return ImportedInput(sources: sources, ocr: OCRDocument(engine: engine, engineVersion: "system", pages: pages))
        } catch {
            removeFiles(writtenFiles)
            throw error
        }
    }

    // MARK: - Images

    private func importImages(
        count: Int,
        sourceType: SourceType,
        submissionID: UUID,
        image imageAt: (Int) throws -> CGImage
    ) async throws -> ImportedInput {
        guard count > 0 else { throw ImportError.noPages }
        var writtenFiles: [URL] = []
        do {
            try LocalDataProtection.prepareSensitiveDirectory(
                submissionDirectory(submissionID), fileManager: fileManager
            )
            var sources: [SourceInputRef] = []
            var pages: [OCRPage] = []
            for index in 0..<count {
                try Task.checkCancellation()
                let image = try imageAt(index)
                let file = try writePage(image, index: index, submissionID: submissionID)
                writtenFiles.append(file.url)
                let source = try makeSource(
                    file: file,
                    image: image,
                    sourceType: sourceType,
                    pageIndex: index,
                    fileName: nil,
                    pdfPageCount: nil,
                    submissionID: submissionID
                )
                sources.append(source)
                let lines = try await Self.recognise(image)
                pages.append(Self.page(source: source, pageIndex: index, lines: lines))
            }
            return ImportedInput(sources: sources, ocr: OCRDocument(engine: "Apple Vision", engineVersion: "system", pages: pages))
        } catch {
            removeFiles(writtenFiles)
            throw error
        }
    }

    private static func decodeImage(_ data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw ImportError.imageUnreadable
        }
        // Full resolution, with the photo's orientation applied so lines and boxes are upright.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height)
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImportError.imageUnreadable
        }
        return image
    }

    // MARK: - Files

    private struct WrittenPage {
        var url: URL
        var fileName: String
        var sourceID: UUID
    }

    private func submissionDirectory(_ submissionID: UUID) -> URL {
        sourcesRoot.appendingPathComponent(submissionID.uuidString, isDirectory: true)
    }

    private func relativePath(_ submissionID: UUID, _ name: String) -> String {
        "Sources/\(submissionID.uuidString)/\(name)"
    }

    /// The source id is part of the file name so a re-import never overwrites the files that
    /// `AppDatabase.replaceInput` is about to hand back for deletion.
    private func writePage(_ image: CGImage, index: Int, submissionID: UUID) throws -> WrittenPage {
        let sourceID = UUID()
        let fileName = "page-\(index + 1)-\(sourceID.uuidString).heic"
        let url = submissionDirectory(submissionID).appendingPathComponent(fileName)
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.heic.identifier as CFString, 1, nil
        ) else {
            throw ImportError.writeFailed("Page \(index + 1) could not be saved.")
        }
        let properties = [kCGImageDestinationLossyCompressionQuality: Self.heicQuality] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            try? fileManager.removeItem(at: url)
            throw ImportError.writeFailed("Page \(index + 1) could not be saved.")
        }
        LocalDataProtection.protectSensitiveFile(url, fileManager: fileManager)
        return WrittenPage(url: url, fileName: fileName, sourceID: sourceID)
    }

    private func makeSource(
        file: WrittenPage,
        image: CGImage,
        sourceType: SourceType,
        pageIndex: Int,
        fileName: String?,
        pdfPageCount: Int?,
        submissionID: UUID
    ) throws -> SourceInputRef {
        SourceInputRef(
            id: file.sourceID,
            submissionID: submissionID,
            sourceType: sourceType,
            pageIndex: pageIndex,
            localRelativePath: relativePath(submissionID, file.fileName),
            fileName: fileName,
            mimeType: "image/heic",
            sha256: try ContentDigest.sha256Hex(fileAt: file.url),
            pixelWidth: image.width,
            pixelHeight: image.height,
            pdfPageCount: pdfPageCount,
            includedInTeacherArchive: false,
            createdAt: Date()
        )
    }

    private func copyFile(from source: URL, to destination: URL) throws {
        do {
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            throw ImportError.writeFailed("The PDF could not be copied into the app: \(error.localizedDescription)")
        }
        LocalDataProtection.protectSensitiveFile(destination, fileManager: fileManager)
    }

    private func removeFiles(_ urls: [URL]) {
        for url in urls { try? fileManager.removeItem(at: url) }
    }

    private static func page(source: SourceInputRef, pageIndex: Int, lines: [OCRLine]) -> OCRPage {
        OCRPage(
            sourceInputID: source.id,
            pageIndex: pageIndex,
            pixelWidth: source.pixelWidth,
            pixelHeight: source.pixelHeight,
            lines: lines
        )
    }

    // MARK: - Recognition

    private static func recognise(_ image: CGImage) async throws -> [OCRLine] {
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.automaticallyDetectLanguage = true
        request.textRecognitionOptions.useLanguageCorrection = true
        let observations = try await request.perform(on: image)
        guard let document = observations.first?.document else { return [] }

        var lines: [OCRLine] = []
        for (paragraphIndex, paragraph) in document.paragraphs.enumerated() {
            for line in paragraph.lines {
                guard let candidate = line.topCandidates(1).first,
                      !candidate.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                let box = line.boundingRegion.boundingBox
                lines.append(
                    OCRLine(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: NormalizedRect(
                            x: box.origin.x,
                            y: box.origin.y,
                            width: box.width,
                            height: box.height
                        ),
                        origin: .visionOCR,
                        paragraphIndex: paragraphIndex
                    )
                )
            }
        }
        return lines
    }

    // MARK: - PDF pages

    private static func render(_ page: PDFPage) throws -> CGImage {
        let media = page.bounds(for: .mediaBox)
        let width = Int((media.width * pdfRenderScale).rounded(.up))
        let height = Int((media.height * pdfRenderScale).rounded(.up))
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else {
            throw ImportError.pdfUnreadable
        }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: CGFloat(width) / media.width, y: CGFloat(height) / media.height)
        page.draw(with: .mediaBox, to: context)
        guard let image = context.makeImage() else { throw ImportError.pdfUnreadable }
        return image
    }

    /// Lines from the PDF's own text layer, or nil when the page does not count as typed
    /// (too little text, or text covering too little of the page) and must be recognised instead.
    private static func typedLines(for page: PDFPage) -> [OCRLine]? {
        let media = page.bounds(for: .mediaBox)
        guard media.width > 0, media.height > 0 else { return nil }
        let characterCount = (page.string ?? "").filter { !$0.isWhitespace }.count
        guard characterCount >= typedPageMinimumCharacters,
              let selection = page.selection(for: media) else { return nil }

        let lineSelections = selection.selectionsByLine()
        let bounds = lineSelections.map { $0.bounds(for: page) }
        let covered = unionArea(of: bounds.map { $0.intersection(media) }.filter { !$0.isNull })
        guard covered / (media.width * media.height) >= typedPageMinimumCoverage else { return nil }

        var lines: [OCRLine] = []
        for (selection, box) in zip(lineSelections, bounds) {
            guard let text = selection.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            lines.append(
                OCRLine(
                    text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                    confidence: nil,
                    boundingBox: NormalizedRect(
                        x: (box.minX - media.minX) / media.width,
                        y: (box.minY - media.minY) / media.height,
                        width: box.width / media.width,
                        height: box.height / media.height
                    ),
                    origin: .pdfTextLayer,
                    paragraphIndex: nil
                )
            )
        }
        return lines
    }

    /// Exact area of the union of rectangles (overlaps counted once).
    private static func unionArea(of rects: [CGRect]) -> CGFloat {
        let xs = Set(rects.flatMap { [$0.minX, $0.maxX] }).sorted()
        var area: CGFloat = 0
        for (left, right) in zip(xs, xs.dropFirst()) {
            let intervals = rects
                .filter { $0.minX <= left && $0.maxX >= right }
                .map { ($0.minY, $0.maxY) }
                .sorted { $0.0 < $1.0 }
            var covered: CGFloat = 0
            var currentEnd = -CGFloat.infinity
            for (low, high) in intervals {
                let start = max(low, currentEnd)
                if high > start { covered += high - start }
                currentEnd = max(currentEnd, high)
            }
            area += covered * (right - left)
        }
        return area
    }
}
