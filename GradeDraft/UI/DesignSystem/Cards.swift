import SwiftUI

struct WarningBanner: View {
    var title: String
    var message: String
    var status: GradeDraftUIStatus

    init(title: String, message: String, status: GradeDraftUIStatus = .needsAttention) {
        self.title = title
        self.message = message
        self.status = status
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: status.systemImage)
                .foregroundStyle(status.color)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(status.color.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}


struct ReviewGateBanner: View {
    var title: String
    var message: String
    var status: GradeDraftUIStatus

    var body: some View {
        WarningBanner(title: title, message: message, status: status)
    }
}
