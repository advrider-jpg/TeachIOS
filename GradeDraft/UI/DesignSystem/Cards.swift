import SwiftUI

struct GroupedListCard<Content: View>: View {
    var title: String?
    var subtitle: String?
    @ViewBuilder var content: Content

    init(title: String? = nil, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 3) {
                    if let title {
                        Text(title)
                            .font(.title2.bold())
                            .lineLimit(1)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
                .padding(.top, 14)
            }
            VStack(spacing: 0) {
                content
            }
        }
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: GradeDraftLayout.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GradeDraftLayout.cardCornerRadius, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}


struct EmptyState: View {
    var title: String
    var message: String
    var systemImage: String

    init(title: String, message: String, systemImage: String = "tray") {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .lineLimit(2)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


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
