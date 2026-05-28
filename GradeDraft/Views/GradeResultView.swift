import SwiftUI

struct GradeResultView: View {
    var result: GradeDraftResult
    var isStale: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Draft score")
                    .font(.headline)
                Spacer()
                Text("\(GradeTotals.formatted(result.totalScore)) / \(GradeTotals.formatted(result.maxScore))")
                    .font(.title3.bold())
            }

            if isStale || result.status == .stale {
                Label("This draft is stale because grading inputs changed.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.subheadline.bold())
            }

            Text(result.studentResponseSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !result.uncertaintyFlags.isEmpty {
                DisclosureGroup("Uncertainty flags") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(result.uncertaintyFlags, id: \.self) { flag in
                            Label(flag, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.top, 6)
                }
            }

            ForEach(result.criteria) { criterion in
                CriterionDraftCard(criterion: criterion)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Draft student feedback")
                    .font(.headline)
                Text(result.studentFeedback.isEmpty ? "No feedback returned." : result.studentFeedback)
                    .textSelection(.enabled)
            }

            if !result.complianceFlags.isEmpty {
                DisclosureGroup("Validation and compliance notes") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(result.complianceFlags, id: \.self) { flag in
                            Label(flag, systemImage: "checkmark.shield")
                                .font(.caption)
                        }
                    }
                    .padding(.top, 6)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct CriterionDraftCard: View {
    var criterion: CriterionScore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(criterion.criterion)
                    .font(.headline)
                Spacer()
                Text("\(GradeTotals.formatted(criterion.proposedPoints)) / \(GradeTotals.formatted(criterion.maxPoints))")
                    .font(.headline.monospacedDigit())
            }

            if !criterion.rating.isEmpty {
                Text(criterion.rating)
                    .font(.subheadline.bold())
            }

            Text(criterion.explanation.isEmpty ? "No explanation provided." : criterion.explanation)
                .font(.subheadline)

            if !criterion.evidence.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Evidence")
                        .font(.caption.bold())
                    ForEach(criterion.evidence, id: \.self) { evidence in
                        Text("“\(evidence)”")
                            .font(.caption)
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
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct FinalGradeReviewView: View {
    var review: FinalGradeReview
    var isStale: Bool = false
    var onChange: (FinalGradeReview) -> Void
    var onApprove: () -> Void

    @State private var workingReview: FinalGradeReview

    init(review: FinalGradeReview, isStale: Bool = false, onChange: @escaping (FinalGradeReview) -> Void, onApprove: @escaping () -> Void) {
        self.review = review
        self.isStale = isStale
        self.onChange = onChange
        self.onApprove = onApprove
        _workingReview = State(initialValue: review)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Teacher final review")
                        .font(.headline)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
                Spacer()
                Text("\(GradeTotals.formatted(workingReview.totalScore)) / \(GradeTotals.formatted(workingReview.maxScore))")
                    .font(.title3.bold())
            }

            if isStale || workingReview.status == .stale {
                Label("This final review is stale because grading inputs changed.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.subheadline.bold())
            }

            if !canApproveCurrentReview {
                Label("Approve each criterion to enable final grade approval.", systemImage: "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            ForEach($workingReview.criteria) { $criterion in
                FinalCriterionEditor(criterion: $criterion)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Student feedback")
                    .font(.headline)
                TextEditor(text: $workingReview.studentFeedback)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Private teacher notes")
                    .font(.headline)
                Text("These notes are included only in the teacher audit export, not the student report.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $workingReview.privateTeacherNotes)
                    .frame(minHeight: 90)
                    .padding(8)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 12) {
                Button("Save Teacher Edits") {
                    workingReview.teacherEdited = true
                    workingReview = GradeTotals.applyingDeterministicTotals(to: workingReview)
                    onChange(workingReview)
                }
                .buttonStyle(.bordered)

                Button("Approve Final Grade") {
                    workingReview.criteria = workingReview.criteria.map { criterion in
                        var criterion = criterion
                        criterion.teacherApproved = true
                        return criterion
                    }
                    workingReview.status = .approved
                    workingReview.finalizedAt = Date()
                    workingReview = GradeTotals.applyingDeterministicTotals(to: workingReview)
                    onChange(workingReview)
                    onApprove()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canApproveCurrentReview)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onChange(of: review) { _, newValue in
            workingReview = newValue
        }
    }

    private var statusText: String {
        switch workingReview.status {
        case .inProgress:
            return "In progress. Save edits and approve before treating this as final."
        case .approved:
            return "Approved by teacher."
        case .stale:
            return "Stale. Review inputs changed after this final review was created."
        }
    }

    private var statusColor: Color {
        switch workingReview.status {
        case .approved:
            return .green
        case .stale:
            return .orange
        case .inProgress:
            return .secondary
        }
    }

    private var canApproveCurrentReview: Bool {
        !workingReview.criteria.isEmpty && workingReview.allCriteriaApproved && workingReview.criteria.allSatisfy { $0.finalPoints >= 0 && $0.finalPoints <= $0.maxPoints }
    }
}

private struct FinalCriterionEditor: View {
    @Binding var criterion: FinalCriterionScore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(criterion.criterion)
                    .font(.headline)
                Spacer()
                Text("Proposed \(GradeTotals.formatted(criterion.proposedPoints)) / \(GradeTotals.formatted(criterion.maxPoints))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Final points")
                TextField("Points", value: $criterion.finalPoints, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120)
                    .onChange(of: criterion.finalPoints) { _, newValue in
                        criterion.finalPoints = max(0, min(newValue, criterion.maxPoints))
                    }
                Text("/ \(GradeTotals.formatted(criterion.maxPoints))")
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Approved", isOn: $criterion.teacherApproved)
                    .toggleStyle(.switch)
            }

            if !criterion.rating.isEmpty {
                Text(criterion.rating)
                    .font(.subheadline.bold())
            }

            Text(criterion.explanation.isEmpty ? "No explanation provided." : criterion.explanation)
                .font(.subheadline)

            if !criterion.evidence.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Evidence")
                        .font(.caption.bold())
                    ForEach(criterion.evidence, id: \.self) { evidence in
                        Text("“\(evidence)”")
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            }

            TextField("Teacher rationale for any change", text: $criterion.teacherRationale, axis: .vertical)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
