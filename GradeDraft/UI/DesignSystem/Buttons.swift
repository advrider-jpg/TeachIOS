import SwiftUI

struct PrimaryActionButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void
    var disabled: Bool

    init(title: String, systemImage: String? = nil, action: @escaping () -> Void, disabled: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
        self.disabled = disabled
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage ?? "arrow.right.circle")
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(minHeight: GradeDraftLayout.minimumTapTarget)
        }
        .buttonStyle(.borderedProminent)
        .disabled(disabled)
    }
}


struct SecondaryActionButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void
    var disabled: Bool

    init(title: String, systemImage: String? = nil, action: @escaping () -> Void, disabled: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
        self.disabled = disabled
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage ?? "arrow.right")
                .lineLimit(1)
                .frame(minHeight: GradeDraftLayout.minimumTapTarget)
        }
        .buttonStyle(.bordered)
        .disabled(disabled)
    }
}


struct DestructiveActionButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void
    var disabled: Bool

    init(title: String, systemImage: String? = nil, action: @escaping () -> Void, disabled: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
        self.disabled = disabled
    }

    var body: some View {
        Button(role: .destructive, action: action) {
            Label(title, systemImage: systemImage ?? "trash")
                .lineLimit(1)
                .frame(minHeight: GradeDraftLayout.minimumTapTarget)
        }
        .buttonStyle(.bordered)
        .disabled(disabled)
    }
}
