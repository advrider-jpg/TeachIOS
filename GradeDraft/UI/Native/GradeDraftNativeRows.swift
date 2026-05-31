import SwiftUI

struct GradeDraftStatusLabeledContent: View {
    let title: String
    let value: String
    let status: GradeDraftUIStatus

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Text(value)
                StatusChip(status, compact: true)
            }
        } label: {
            Text(title)
        }
    }
}