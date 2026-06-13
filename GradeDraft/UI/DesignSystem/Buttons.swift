import SwiftUI

struct StationeryButtonStyle: ButtonStyle {
    enum Prominence {
        case primary
        case secondary
    }

    var prominence: Prominence
    var theme: StationeryTheme
    @Environment(\.isEnabled) private var isEnabled

    init(prominence: Prominence = .primary, theme: StationeryTheme = .gradeDraft) {
        self.prominence = prominence
        self.theme = theme
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foregroundColor)
            .frame(minHeight: GradeDraftLayout.minimumTapTarget)
            .padding(.horizontal, 14)
            .background(backgroundColor(configuration: configuration), in: RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.55)
    }

    private var foregroundColor: Color {
        switch prominence {
        case .primary:
            return isEnabled ? .white : theme.mutedInk
        case .secondary:
            return isEnabled ? theme.accent : theme.mutedInk
        }
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        switch prominence {
        case .primary:
            guard isEnabled else { return theme.paperTint }
            return theme.accent.opacity(configuration.isPressed ? 0.82 : 1)
        case .secondary:
            return theme.paper.opacity(configuration.isPressed ? 0.72 : 1)
        }
    }

    private var borderColor: Color {
        switch prominence {
        case .primary:
            return isEnabled ? theme.accent.opacity(0.45) : Color(.separator)
        case .secondary:
            return isEnabled ? theme.accent.opacity(0.32) : Color(.separator)
        }
    }
}

struct PrimaryActionButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void
    var disabled: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(title: String, systemImage: String? = nil, action: @escaping () -> Void, disabled: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
        self.disabled = disabled
    }

    var body: some View {
        Button(action: action) {
            ActionButtonLabel(
                title: title,
                systemImage: systemImage ?? "arrow.right.circle",
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
        }
        .buttonStyle(StationeryButtonStyle(prominence: .primary))
        .disabled(disabled)
    }
}


struct SecondaryActionButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void
    var disabled: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(title: String, systemImage: String? = nil, action: @escaping () -> Void, disabled: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
        self.disabled = disabled
    }

    var body: some View {
        Button(action: action) {
            ActionButtonLabel(
                title: title,
                systemImage: systemImage ?? "arrow.right",
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
        }
        .buttonStyle(StationeryButtonStyle(prominence: .secondary))
        .disabled(disabled)
    }
}

private struct ActionButtonLabel: View {
    var title: String
    var systemImage: String
    var isAccessibilitySize: Bool

    var body: some View {
        Label {
            Text(title)
                .lineLimit(isAccessibilitySize ? nil : 3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
        }
        .labelStyle(.titleAndIcon)
        .frame(maxWidth: .infinity)
        .frame(minHeight: GradeDraftLayout.minimumTapTarget)
        .accessibilityLabel(title)
    }
}
