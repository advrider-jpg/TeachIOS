import SwiftUI

enum LocalCapabilityBannerCopy {
    static func title(for status: LocalAIStatus) -> String {
        switch status {
        case .available:
            return "Local AI ready"
        case .unavailable(let message):
            if message.localizedCaseInsensitiveContains("Apple Intelligence is not enabled") {
                return "Apple Intelligence disabled"
            }
            if message.localizedCaseInsensitiveContains("not ready") || message.localizedCaseInsensitiveContains("preparing") {
                return "Model not ready"
            }
            if message.localizedCaseInsensitiveContains("does not support")
                || message.localizedCaseInsensitiveContains("not eligible")
                || message.localizedCaseInsensitiveContains("unsupported device") {
                return "Device not eligible"
            }
            if message.localizedCaseInsensitiveContains("Foundation Models framework")
                || message.localizedCaseInsensitiveContains("newer operating system") {
                return "Foundation Models unavailable"
            }
            return "Local AI unavailable"
        }
    }

    static func details(for status: LocalAIStatus, message: String) -> [String] {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        switch status {
        case .available:
            return [
                "Foundation Models is available on this device for local draft assistance.",
                "Airplane Mode can be used during device QA to confirm there is no cloud fallback.",
                "Manual final review, teacher approval, and export gates still apply."
            ]
        case .unavailable(let statusMessage):
            var details = [trimmedMessage.isEmpty ? statusMessage : trimmedMessage]
            if statusMessage.localizedCaseInsensitiveContains("Apple Intelligence is not enabled") {
                details.append("Enable Apple Intelligence in Settings before using local AI drafting.")
            } else if statusMessage.localizedCaseInsensitiveContains("not ready") || statusMessage.localizedCaseInsensitiveContains("preparing") {
                details.append("Wait for the on-device model to finish preparing, then refresh readiness.")
            } else if statusMessage.localizedCaseInsensitiveContains("does not support")
                || statusMessage.localizedCaseInsensitiveContains("not eligible")
                || statusMessage.localizedCaseInsensitiveContains("unsupported device") {
                details.append("Use manual review on this device, or test local AI on an Apple Intelligence-capable device.")
            } else if statusMessage.localizedCaseInsensitiveContains("newer operating system") {
                details.append("Install the required iOS/iPadOS version before using Foundation Models.")
            } else if statusMessage.localizedCaseInsensitiveContains("Foundation Models framework") {
                details.append("Compile with an SDK that includes Foundation Models before making local AI release claims.")
            }
            details.append("Manual final review remains available. Student work is not sent to cloud AI as a fallback.")
            return details
        }
    }
}

struct LocalCapabilityBanner: View {
    var status: LocalAIStatus
    var message: String
    @State private var showingDetails = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NotebookCard(status: bannerStatus, showsPerforation: true) {
            HStack(alignment: .top, spacing: 12) {
                StatusIconBubble(bannerStatus)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        TapeLabel("Local only")
                    }
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                    DisclosureGroup(isExpanded: $showingDetails) {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(detailLines, id: \.self) { detail in
                                HandwrittenAnnotation(detail, status: .teacherOnly)
                            }
                        }
                        .padding(.top, 4)
                    } label: {
                        Text(showingDetails ? "Hide details" : "Local privacy details")
                            .font(.caption.weight(.semibold))
                    }
                }
                .layoutPriority(1)
                if !dynamicTypeSize.isAccessibilitySize {
                    PaperclipDecoration()
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        LocalCapabilityBannerCopy.title(for: status)
    }

    private var detailLines: [String] {
        LocalCapabilityBannerCopy.details(for: status, message: message)
    }

    private var bannerStatus: GradeDraftUIStatus {
        switch status {
        case .available:
            return .onTrack
        case .unavailable:
            return .needsAttention
        }
    }
}
