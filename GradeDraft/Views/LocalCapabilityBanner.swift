import SwiftUI

struct LocalCapabilityBanner: View {
    var status: LocalAIStatus
    var message: String
    @State private var showingDetails = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                DisclosureGroup(isExpanded: $showingDetails) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manual final review remains available when local AI is unavailable.")
                        Text("Student work is not uploaded for text recognition, draft feedback, or usage tracking.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } label: {
                    Text(showingDetails ? "Hide details" : "Local privacy details")
                        .font(.caption.weight(.semibold))
                }
            }
            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var title: String {
        switch status {
        case .available:
            return "Local AI ready"
        case .unavailable:
            return "Local AI unavailable"
        }
    }

    private var iconName: String {
        switch status {
        case .available:
            return "checkmark.shield"
        case .unavailable:
            return "exclamationmark.triangle"
        }
    }

    private var iconColor: Color {
        switch status {
        case .available:
            return .green
        case .unavailable:
            return .orange
        }
    }
}
