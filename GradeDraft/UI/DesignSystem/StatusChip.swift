import SwiftUI

struct StatusChip: View {
    var status: GradeDraftUIStatus
    var compact: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(_ status: GradeDraftUIStatus, compact: Bool = false) {
        self.status = status
        self.compact = compact
    }

    var body: some View {
        Group {
            if compact && dynamicTypeSize.isAccessibilitySize {
                iconOnlyChip
            } else {
                ViewThatFits(in: .horizontal) {
                    fullChip
                    iconOnlyChip
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status")
        .accessibilityValue(status.fullAccessibilityLabel)
    }

    private var fullChip: some View {
        Label {
            Text(status.chipLabel)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        } icon: {
            Image(systemName: status.systemImage)
                .imageScale(.small)
        }
        .font(GradeDraftTypography.chip)
        .padding(.horizontal, compact ? 8 : 10)
        .frame(minHeight: compact ? 24 : 28)
        .foregroundStyle(status.color)
        .background(status.color.opacity(0.13), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    private var iconOnlyChip: some View {
        Image(systemName: status.systemImage)
            .imageScale(.small)
            .font(GradeDraftTypography.chip)
            .frame(width: compact ? 24 : 28, height: compact ? 24 : 28)
            .foregroundStyle(status.color)
            .background(status.color.opacity(0.13), in: Capsule())
    }
}
