import SwiftUI

/// Outlines the scanned-text lines that need the teacher's action on top of the page image, and the
/// selected line. Lines without a position are skipped.
struct TextLineHighlightOverlay: View {
    var page: OCRPage
    var imageSize: CGSize
    var selectedLineID: UUID?

    var body: some View {
        GeometryReader { proxy in
            ForEach(page.lines.filter { $0.boundingBox != nil }) { line in
                let mappedRect = ScaledImageRectMapper.mappedRect(line.boundingBox ?? .zero, imageSize: imageSize, in: proxy.size)
                let visibleRect = CGRect(
                    x: mappedRect.minX,
                    y: mappedRect.minY,
                    width: max(mappedRect.width, 1),
                    height: max(mappedRect.height, 1)
                )
                RoundedRectangle(cornerRadius: 3)
                    .fill(fill(for: line))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(stroke(for: line), lineWidth: line.id == selectedLineID ? 2.5 : 1.5)
                    )
                    .frame(width: visibleRect.width, height: visibleRect.height)
                    .position(x: visibleRect.midX, y: visibleRect.midY)
                    .accessibilityLabel("Page \(page.pageIndex + 1), scanned text line")
                    .accessibilityValue(line.reviewAccessibilityValue)
            }
        }
        .allowsHitTesting(false)
    }

    private func stroke(for line: OCRLine) -> Color {
        if line.id == selectedLineID { return .accentColor }
        if line.isRejected { return .red }
        if line.needsReview { return .orange }
        return .clear
    }

    private func fill(for line: OCRLine) -> Color {
        if line.id == selectedLineID { return Color.accentColor.opacity(0.12) }
        if line.isRejected { return Color.gray.opacity(0.16) }
        return Color.clear
    }
}

extension OCRLine {
    /// The line's review state, as `StatusLabel` shows it.
    var reviewUIStatus: GradeDraftUIStatus {
        if isRejected { return .textNeedsAttention }
        if teacherConfirmed { return .onTrack }
        return needsReview ? .needsAttention : .onTrack
    }

    /// What VoiceOver reads for a line: its state, where its text came from, and the text.
    var reviewAccessibilityValue: String {
        let source: String
        switch origin {
        case .pdfTextLayer:
            source = "From PDF text layer."
        case .visionOCR:
            source = confidence.map { "Confidence \(Int((min(max($0, 0), 1) * 100).rounded())) percent." } ?? "No confidence score."
        }
        let text = reviewedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let textSummary = text.isEmpty ? "No recognized text." : "Text: \(text)."
        return "\(reviewUIStatus.rawValue). \(source) \(textSummary)"
    }
}
