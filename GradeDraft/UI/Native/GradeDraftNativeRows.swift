import SwiftUI

struct GradeDraftStatusLabeledContent: View {
    let title: String
    let value: String
    let status: GradeDraftUIStatus

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Text(value)
                    .font(.body.monospacedDigit())
                StatusChip(status, compact: true)
            }
        } label: {
            Text(title)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue("\(value). Status: \(status.fullAccessibilityLabel)")
    }
}
