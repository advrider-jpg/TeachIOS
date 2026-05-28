import SwiftUI

struct GradeResultView: View {
    var result: GradeDraftResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Draft grade")
                    .font(.title2.bold())
                Spacer()
                Text(scoreText)
                    .font(.title3.monospacedDigit().bold())
            }

            labeledBlock("Student response summary", result.studentResponseSummary)
            labeledBlock("Student feedback", result.studentFeedback)

            if !result.teacherNotes.isEmpty {
                labeledBlock("Teacher notes", result.teacherNotes)
            }

            if !result.uncertaintyFlags.isEmpty {
                flagBlock(title: "Uncertainty flags", flags: result.uncertaintyFlags, icon: "exclamationmark.triangle", color: .orange)
            }

            if !result.complianceFlags.isEmpty {
                flagBlock(title: "Guardrail notes", flags: result.complianceFlags, icon: "checkmark.shield", color: .secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Rubric criteria")
                    .font(.headline)
                ForEach(result.criteria) { criterion in
                    criterionCard(criterion)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var scoreText: String {
        "\(GradeTotals.formatted(result.totalScore)) / \(GradeTotals.formatted(result.maxScore))"
    }

    private func labeledBlock(_ title: String, _ bodyText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(bodyText.isEmpty ? "None provided." : bodyText)
                .font(.body)
                .textSelection(.enabled)
        }
    }

    private func flagBlock(title: String, flags: [String], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(flags, id: \.self) { flag in
                Label(flag, systemImage: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
            }
        }
    }

    private func criterionCard(_ criterion: CriterionScore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(criterion.criterion)
                    .font(.headline)
                Spacer()
                Text("\(GradeTotals.formatted(criterion.proposedPoints)) / \(GradeTotals.formatted(criterion.maxPoints))")
                    .font(.subheadline.monospacedDigit().bold())
            }
            Text(criterion.rating.isEmpty ? "No rating label" : criterion.rating)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Text(criterion.explanation.isEmpty ? "No explanation provided." : criterion.explanation)
                .font(.body)
            if !criterion.evidence.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Evidence")
                        .font(.subheadline.bold())
                    ForEach(criterion.evidence, id: \.self) { evidence in
                        Text("• \(evidence)")
                            .font(.subheadline)
                            .textSelection(.enabled)
                    }
                }
            }
            if criterion.teacherReviewRequired {
                Label("Teacher review required", systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct FinalGradeReviewView: View {
    @State private var editableReview: FinalGradeReview
    var onSave: (FinalGradeReview) -> Void

    init(review: FinalGradeReview, onSave: @escaping (FinalGradeReview) -> Void) {
        _editableReview = State(initialValue: review)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Final teacher-approved grade")
                    .font(.title2.bold())
                Spacer()
                Text("\(GradeTotals.formatted(editableReview.totalScore)) / \(GradeTotals.formatted(editableReview.maxScore))")
                    .font(.title3.monospacedDigit().bold())
            }

            Text("Edit the final feedback or notes here. Criterion-level point editing is preserved as a model boundary for the next implementation pass.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Student feedback")
                    .font(.headline)
                TextEditor(text: Binding(
                    get: { editableReview.studentFeedback },
                    set: { newValue in
                        editableReview.studentFeedback = newValue
                        editableReview.teacherEdited = true
                    }
                ))
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Private teacher notes")
                    .font(.headline)
                TextEditor(text: Binding(
                    get: { editableReview.privateTeacherNotes },
                    set: { newValue in
                        editableReview.privateTeacherNotes = newValue
                        editableReview.teacherEdited = true
                    }
                ))
                .frame(minHeight: 90)
                .padding(8)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button("Save Final Review") {
                editableReview = GradeTotals.applyingDeterministicTotals(to: editableReview)
                onSave(editableReview)
            }
            .buttonStyle(.borderedProminent)

            VStack(alignment: .leading, spacing: 12) {
                Text("Final criteria")
                    .font(.headline)
                ForEach(editableReview.criteria) { criterion in
                    finalCriterionCard(criterion)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func finalCriterionCard(_ criterion: CriterionScore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(criterion.criterion)
                    .font(.headline)
                Spacer()
                Text("\(GradeTotals.formatted(criterion.proposedPoints)) / \(GradeTotals.formatted(criterion.maxPoints))")
                    .font(.subheadline.monospacedDigit().bold())
            }
            Text(criterion.explanation.isEmpty ? "No explanation provided." : criterion.explanation)
                .font(.body)
            if !criterion.evidence.isEmpty {
                Text("Evidence: \(criterion.evidence.joined(separator: "; "))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
