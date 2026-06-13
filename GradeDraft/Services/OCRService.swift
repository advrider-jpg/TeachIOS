import Foundation
import ImageIO
import UIKit
import Vision

protocol OCRServicing: Sendable {
    func recognizeText(in images: [UIImage]) async throws -> OCRDocument
}

final class VisionOCRService: OCRServicing, Sendable {
    func recognizeText(in images: [UIImage]) async throws -> OCRDocument {
        var pages: [OCRPage] = []

        for (index, image) in images.enumerated() {
            let lines = try await recognizeText(in: image)
            pages.append(
                OCRPage(
                    pageIndex: index,
                    imageWidth: Double(image.size.width),
                    imageHeight: Double(image.size.height),
                    lines: lines
                )
            )
        }

        return OCRDocument(pages: pages)
    }

    private func recognizeText(in image: UIImage) async throws -> [OCRLine] {
        guard let cgImage = image.cgImage else {
            throw GradeDraftError.ocrFailed("The selected image could not be converted for text recognition.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: GradeDraftError.ocrFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let lines = Self.sortedReadingOrder(
                    observations.compactMap { observation -> OCRLine? in
                        guard let candidate = observation.topCandidates(1).first else {
                            return nil
                        }

                        let box = observation.boundingBox
                        return OCRLine(
                            text: candidate.string,
                            confidence: candidate.confidence,
                            boundingBox: NormalizedRect(
                                x: box.origin.x,
                                y: box.origin.y,
                                width: box.width,
                                height: box.height
                            )
                        )
                    }
                )

                continuation.resume(returning: lines)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: GradeDraftError.ocrFailed(error.localizedDescription))
            }
        }
    }

    static func sortedReadingOrder(_ lines: [OCRLine]) -> [OCRLine] {
        lines.sorted { lhs, rhs in
            let rowTolerance = max(max(lhs.boundingBox.height, rhs.boundingBox.height), CGFloat(0.015))
            if abs(lhs.boundingBox.y - rhs.boundingBox.y) > rowTolerance {
                return lhs.boundingBox.y > rhs.boundingBox.y
            }
            return lhs.boundingBox.x < rhs.boundingBox.x
        }
    }
}

enum PDFImportPlanner {
    static func pageIndexesNeedingOCR(digitalTextByPage: [String]) -> [Int] {
        digitalTextByPage.enumerated()
            .filter { $0.element.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(\.offset)
    }

    static func digitalDocument(pageTexts: [String], sourceRefs: [SourceInputRef]) -> OCRDocument {
        let pages: [OCRPage] = pageTexts.enumerated().map { pageIndex, text in
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .enumerated()
                .map { lineIndex, lineText in
                    OCRLine(
                        text: lineText,
                        confidence: 1.0,
                        boundingBox: NormalizedRect(x: 0.02, y: CGFloat(lineIndex) * 0.035, width: 0.96, height: 0.03),
                        teacherConfirmed: false
                    )
                }
            return OCRPage(
                sourceInputID: sourceRefs[safe: pageIndex]?.id,
                pageIndex: pageIndex,
                imageWidth: sourceRefs[safe: pageIndex]?.imageWidth,
                imageHeight: sourceRefs[safe: pageIndex]?.imageHeight,
                lines: lines
            )
        }
        return OCRDocument(engine: "PDFKit digital text", engineVersion: "system", pages: pages)
    }

    static func mergedDocument(
        digitalTextByPage: [String],
        sourceRefs: [SourceInputRef],
        recognizedOCRPagesByPageIndex: [Int: OCRPage],
        pageCount: Int
    ) -> OCRDocument {
        let digital = digitalDocument(pageTexts: digitalTextByPage, sourceRefs: sourceRefs)
        let pages = (0..<pageCount).map { index in
            let digitalText = digitalTextByPage[safe: index] ?? ""
            if !digitalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let page = digital.pages[safe: index] {
                return page
            }
            return recognizedOCRPagesByPageIndex[index] ?? OCRPage(
                sourceInputID: sourceRefs[safe: index]?.id,
                pageIndex: index,
                imageWidth: sourceRefs[safe: index]?.imageWidth,
                imageHeight: sourceRefs[safe: index]?.imageHeight,
                lines: []
            )
        }
        return OCRDocument(
            engine: engineName(pageIndexesNeedingOCR: pageIndexesNeedingOCR(digitalTextByPage: digitalTextByPage)),
            engineVersion: "system",
            pages: pages
        )
    }

    static func engineName(pageIndexesNeedingOCR: [Int]) -> String {
        pageIndexesNeedingOCR.isEmpty ? "PDFKit digital text" : "PDFKit digital text + Apple Vision"
    }
}

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
