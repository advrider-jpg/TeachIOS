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
