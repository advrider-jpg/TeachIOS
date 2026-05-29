import SwiftUI

struct StatusChip: View {
    var status: GradeDraftUIStatus
    var compact: Bool

    init(_ status: GradeDraftUIStatus, compact: Bool = false) {
        self.status = status
        self.compact = compact
    }

    var body: some View {
        Label {
            Text(status.chipLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        } icon: {
            Image(systemName: status.systemImage)
                .imageScale(.small)
        }
        .font(GradeDraftTypography.chip)
        .padding(.horizontal, compact ? 8 : 10)
        .frame(height: 24)
        .foregroundStyle(status.color)
        .background(status.color.opacity(0.13), in: Capsule())
        .accessibilityLabel("Status: \(status.fullAccessibilityLabel)")
    }
}
