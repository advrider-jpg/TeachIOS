import SwiftUI

struct LocalCapabilityBanner: View {
    var status: LocalAIStatus
    var message: String

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
                Text("No backend, no cloud OCR, no cloud grading, and no telemetry SDK in this repo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
