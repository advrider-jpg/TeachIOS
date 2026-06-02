import SwiftUI

struct StatusChip: View {
    var status: GradeDraftUIStatus
    var compact: Bool
    var theme: StationeryTheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(_ status: GradeDraftUIStatus, compact: Bool = false, theme: StationeryTheme = .gradeDraft) {
        self.status = status
        self.compact = compact
        self.theme = theme
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
        .background(theme.statusFill(for: status), in: Capsule())
        .overlay(Capsule().stroke(theme.statusStroke(for: status), lineWidth: 0.5))
        .fixedSize(horizontal: true, vertical: false)
    }

    private var iconOnlyChip: some View {
        Image(systemName: status.systemImage)
            .imageScale(.small)
            .font(GradeDraftTypography.chip)
            .frame(width: compact ? 24 : 28, height: compact ? 24 : 28)
            .foregroundStyle(status.color)
            .background(theme.statusFill(for: status), in: Capsule())
            .overlay(Capsule().stroke(theme.statusStroke(for: status), lineWidth: 0.5))
    }
}
