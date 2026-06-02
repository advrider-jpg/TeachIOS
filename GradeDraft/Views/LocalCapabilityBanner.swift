import SwiftUI

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
                            HandwrittenAnnotation("Manual final review remains available when local AI is unavailable.", status: .teacherOnly)
                            HandwrittenAnnotation("Student work is not uploaded for text recognition, draft feedback, or usage tracking.", status: .teacherOnly)
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
        switch status {
        case .available:
            return "Local AI ready"
        case .unavailable:
            return "Local AI unavailable"
        }
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
