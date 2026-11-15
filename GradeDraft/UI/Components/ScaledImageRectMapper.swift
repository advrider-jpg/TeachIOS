import CoreGraphics

struct ScaledImageRectMapper {
    // Vision OCR boxes are normalized to the source image with a lower-left origin; SwiftUI draws from the upper-left.
    static func displayedImageRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let displayedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (containerSize.width - displayedSize.width) / 2,
            y: (containerSize.height - displayedSize.height) / 2
        )
        return CGRect(origin: origin, size: displayedSize)
    }

    static func mappedRect(_ normalizedRect: NormalizedRect, imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        let imageRect = displayedImageRect(imageSize: imageSize, in: containerSize)
        guard !imageRect.isEmpty else { return .zero }
        let topLeftY = 1 - normalizedRect.y - normalizedRect.height
        return CGRect(
            x: imageRect.minX + normalizedRect.x * imageRect.width,
            y: imageRect.minY + topLeftY * imageRect.height,
            width: normalizedRect.width * imageRect.width,
            height: normalizedRect.height * imageRect.height
        )
    }
}
