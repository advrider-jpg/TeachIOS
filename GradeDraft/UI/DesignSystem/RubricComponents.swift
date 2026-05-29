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


struct RubricImportPreviewCard: View {
    var preview: RubricImportPreview
    var onConfirmStructured: () -> Void
    var onUseText: () -> Void

    var body: some View {
        GroupedListCard(
            title: preview.issues.isEmpty ? "Preview import" : "Imported with warnings",
            subtitle: "Review the criteria before using them for teacher-reviewed grading."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    StatusChip(preview.issues.isEmpty ? .onTrack : .needsAttention)
                    Text("\(preview.detectedCriteria.count) criteria · \(preview.detectedLevels.count) scoring bands")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ForEach(preview.detectedCriteria) { criterion in
                    RubricCriterionRow(criterion: criterion)
                    if criterion.id != preview.detectedCriteria.last?.id { Divider().padding(.leading, 50) }
                }
                if !preview.issues.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Import warnings")
                            .font(.headline)
                        ForEach(preview.issues, id: \.id) { issue in
                            Label(issue.message, systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
                }
                HStack(spacing: 8) {
                    PrimaryActionButton(title: "Confirm Structured Import", systemImage: "checkmark.circle", action: onConfirmStructured, disabled: preview.detectedCriteria.isEmpty)
                    SecondaryActionButton(title: "Use Rubric Text", systemImage: "text.alignleft", action: onUseText)
                }
                .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
                .padding(.bottom, 12)
            }
            .padding(.top, 4)
        }
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


struct CriterionDetailPanel: View {
    var criterion: FinalCriterionScore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CriterionSummaryRow(criterion: criterion)
            if !criterion.explanation.isEmpty {
                Text(criterion.explanation)
                    .font(.subheadline)
                    .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
            }
            if !criterion.evidence.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Evidence")
                        .font(.caption.weight(.semibold))
                    ForEach(criterion.evidence, id: \.self) { quote in
                        Text("“\(quote)”")
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
                .padding(.bottom, 10)
            }
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
