import SwiftUI

struct EvidenceChip: View {
    var evidence: EvidenceReference
    var status: GradeDraftUIStatus

    init(evidence: EvidenceReference, status: GradeDraftUIStatus = .teacherOnly) {
        self.evidence = evidence
        self.status = status
    }

    var body: some View {
        Label(evidence.displaySource, systemImage: "quote.bubble")
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .foregroundStyle(status.color)
            .background(status.color.opacity(0.13), in: Capsule())
            .accessibilityLabel("Evidence from \(evidence.displaySource). \(status.rawValue).")
    }
}


struct EvidenceSourceRow: View {
    var evidence: EvidenceReference

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "quote.opening")
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text(evidence.quote)
                    .font(.subheadline)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    EvidenceChip(evidence: evidence)
                    StatusChip(evidence.teacherConfirmed ? .onTrack : .needsAttention, compact: true)
                }
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
        .padding(.vertical, 10)
    }
}


struct EvidenceSourcePreview: View {
    var evidence: [EvidenceReference]

    var body: some View {
        GroupedListCard(title: "Evidence", subtitle: "Evidence remains linked to reviewed student work or teacher notes.") {
            if evidence.isEmpty {
                EmptyState(title: "No evidence added", message: "Add evidence from reviewed text during final review.", systemImage: "quote.bubble")
            } else {
                ForEach(evidence) { item in
                    EvidenceSourceRow(evidence: item)
                    if item.id != evidence.last?.id { Divider().padding(.leading, 50) }
                }
            }
        }
    }
}
