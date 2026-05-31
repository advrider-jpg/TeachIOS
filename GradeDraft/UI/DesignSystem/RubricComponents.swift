import SwiftUI

struct RubricCriterionRow: View {
    var criterion: RubricCriterion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checklist")
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(criterion.title)
                    .font(.headline)
                    .lineLimit(2)
                Text("\(GradeTotals.formatted(criterion.maxPoints)) points")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            StatusChip(.onTrack, compact: true)
        }
        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
        .padding(.vertical, 10)
    }
}


struct CriterionSummaryRow: View {
    var criterion: FinalCriterionScore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: criterion.teacherApproved ? "checkmark.circle" : "circle")
                .foregroundStyle(criterion.teacherApproved ? .green : .orange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(criterion.criterion)
                    .font(.headline)
                    .lineLimit(2)
                Text(criterion.rating.nilIfBlank ?? "No rating selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text("\(GradeTotals.formatted(criterion.finalPoints)) / \(GradeTotals.formatted(criterion.maxPoints))")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
        .padding(.vertical, 10)
    }
}