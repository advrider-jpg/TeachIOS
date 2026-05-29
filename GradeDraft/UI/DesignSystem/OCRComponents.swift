import SwiftUI
import UIKit

struct WorkPreviewCard: View {
    var text: Binding<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Work preview")
                .font(.headline)
            TextEditor(text: text)
                .frame(minHeight: 160)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Paste or import student work.")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(14)
    }
}

// MARK: - Scanned text review components

struct ScannedTextPageSelector: View {
    var pages: [OCRPage]
    @Binding var selectedPageID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pages) { page in
                    Button {
                        selectedPageID = page.id
                    } label: {
                        VStack(spacing: 5) {
                            Text("Page \(page.pageIndex + 1)")
                                .font(.caption.weight(.semibold))
                            Text("\(page.unresolvedLineCount) lines")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(height: 50)
                        .background(selectedPageID == page.id ? Color.blue.opacity(0.14) : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selectedPageID == page.id ? Color.blue : Color(.separator), lineWidth: selectedPageID == page.id ? 1.5 : 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, GradeDraftLayout.screenPadding)
        }
    }
}

struct ScannedTextDocumentPreview: View {
    var image: UIImage?
    var page: OCRPage
    var selectedLineID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Work preview")
                    .font(.headline)
                Spacer()
                Text("Page \(page.pageIndex + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                    TextLineHighlightOverlay(page: page, imageSize: image.size, selectedLineID: selectedLineID)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            VStack(spacing: 6) {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("No page image available")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 420)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
        .padding(14)
    }
}

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

struct TextLineHighlightOverlay: View {
    var page: OCRPage
    var imageSize: CGSize
    var selectedLineID: UUID?

    var body: some View {
        GeometryReader { proxy in
            ForEach(page.lines) { line in
                let mappedRect = ScaledImageRectMapper.mappedRect(line.boundingBox, imageSize: imageSize, in: proxy.size)
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
                    .accessibilityLabel("Page \(page.pageIndex + 1), text line. Status: \(line.v6ReviewLabel).")
            }
        }
        .allowsHitTesting(false)
    }

    private func stroke(for line: OCRLine) -> Color {
        if line.id == selectedLineID { return .blue }
        if line.isRejected { return .red }
        if line.needsReview { return .orange }
        return .clear
    }

    private func fill(for line: OCRLine) -> Color {
        if line.id == selectedLineID { return Color.blue.opacity(0.12) }
        if line.isRejected { return Color.gray.opacity(0.16) }
        return Color.clear
    }
}

struct TextLineEditorCard: View {
    var pageID: UUID
    var line: OCRLine
    var isSelected: Bool
    var onSelect: () -> Void
    var onTextChange: (String) -> Void
    var onConfirm: () -> Void
    var onReject: () -> Void
    var onAddEvidence: () -> Void
    var evidenceEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                StatusChip(line.v6ReviewStatus, compact: true)
                Text("Confidence \(Int(line.confidence * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(line.needsReview ? .orange : .secondary)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Text as read")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(line.rawText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Corrected text")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Corrected text", text: Binding(get: { line.reviewedText }, set: onTextChange), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 8) {
                SecondaryActionButton(title: "Confirm Line", systemImage: "checkmark.circle", action: onConfirm)
                SecondaryActionButton(title: "Reject Line", systemImage: "xmark.circle", action: onReject)
                SecondaryActionButton(title: "Add as Evidence", systemImage: "quote.bubble", action: onAddEvidence, disabled: !evidenceEnabled)
            }
            .font(.caption)
        }
        .padding(12)
        .background(isSelected ? Color.blue.opacity(0.09) : Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.blue : Color(.separator), lineWidth: isSelected ? 1.5 : 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

extension OCRLine {
    var v6ReviewStatus: GradeDraftUIStatus {
        if isRejected { return .textNeedsAttention }
        if teacherConfirmed { return .onTrack }
        if correctedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { return .fixBeforeContinuing }
        return needsReview ? .needsAttention : .reviewScannedText
    }

    var v6ReviewLabel: String {
        v6ReviewStatus.rawValue
    }
}
