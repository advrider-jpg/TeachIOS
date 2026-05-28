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
                        Text("\u{201C}\(evidence)\u{201D}")
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
    var onAddCriterion: (() -> Void)?
    var onDeleteCriterion: ((UUID) -> Void)?

    @State private var workingReview: FinalGradeReview
    @State private var showingApproveConfirm = false

    init(
        review: FinalGradeReview,
        isStale: Bool = false,
        onChange: @escaping (FinalGradeReview) -> Void,
        onApprove: @escaping () -> Void,
        onAddCriterion: (() -> Void)? = nil,
        onDeleteCriterion: ((UUID) -> Void)? = nil
    ) {
        self.review = review
        self.isStale = isStale
        self.onChange = onChange
        self.onApprove = onApprove
        self.onAddCriterion = onAddCriterion
        self.onDeleteCriterion = onDeleteCriterion
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
                Label("This final review is stale because grading inputs changed after it was created or edited. Review before exporting.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.subheadline.bold())
            }

            if !canApproveCurrentReview {
                Label("Approve each criterion and ensure all scores are valid to enable final grade approval.", systemImage: "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            Text("Criteria")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            ForEach($workingReview.criteria) { $criterion in
                FinalCriterionEditor(
                    criterion: $criterion,
                    onDelete: onDeleteCriterion.map { del in { del(criterion.id) } }
                )
                .onChange(of: criterion) { _, _ in
                    var updated = workingReview
                    updated.teacherEdited = true
                    updated = GradeTotals.applyingDeterministicTotals(to: updated)
                    workingReview = updated
                }
            }

            Button {
                onAddCriterion?()
            } label: {
                Label("Add Criterion", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
            .disabled(onAddCriterion == nil)

            VStack(alignment: .leading, spacing: 8) {
                Text("Student-facing feedback")
                    .font(.headline)
                Text("This text is included in the student report. Keep it constructive and evidence-linked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    showingApproveConfirm = true
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
        .confirmationDialog(
            "Approve Final Grade",
            isPresented: $showingApproveConfirm,
            titleVisibility: .visible
        ) {
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
            Button("Keep Reviewing", role: .cancel) {}
        } message: {
            Text("Approve this as the teacher-final grade? You can still keep the AI proposal for audit, but the final score and feedback will reflect your reviewed edits.")
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
        !workingReview.criteria.isEmpty &&
        workingReview.allCriteriaApproved &&
        workingReview.criteria.allSatisfy { $0.finalPoints >= 0 && $0.finalPoints <= $0.maxPoints }
    }
}

private struct FinalCriterionEditor: View {
    @Binding var criterion: FinalCriterionScore
    var onDelete: (() -> Void)?

    @State private var newEvidenceText = ""
    @State private var showingEvidenceEntry = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                TextField("Criterion name", text: $criterion.criterion)
                    .font(.headline)
                    .textFieldStyle(.roundedBorder)
                Spacer()
                if criterion.proposedPoints > 0 || criterion.maxPoints > 0 {
                    Text("Proposed \(GradeTotals.formatted(criterion.proposedPoints)) / \(GradeTotals.formatted(criterion.maxPoints))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Final points")
                TextField("Points", value: $criterion.finalPoints, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 100)
                    .onChange(of: criterion.finalPoints) { _, newValue in
                        if criterion.maxPoints > 0 {
                            criterion.finalPoints = max(0, min(newValue, criterion.maxPoints))
                        } else {
                            criterion.finalPoints = max(0, newValue)
                        }
                    }
                Text("/")
                    .foregroundStyle(.secondary)
                TextField("Max", value: $criterion.maxPoints, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 80)
                    .onChange(of: criterion.maxPoints) { _, newValue in
                        criterion.maxPoints = max(0, newValue)
                    }
                Spacer()
                Toggle("Approved", isOn: $criterion.teacherApproved)
                    .toggleStyle(.switch)
                    .labelsHidden()
                Text("Approved")
                    .font(.caption)
            }

            TextField("Rating (optional, e.g. Proficient)", text: $criterion.rating, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Explanation")
                    .font(.caption.bold())
                TextEditor(text: $criterion.explanation)
                    .frame(minHeight: 60)
                    .padding(6)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Evidence")
                        .font(.caption.bold())
                    Spacer()
                    Button {
                        showingEvidenceEntry.toggle()
                    } label: {
                        Label("Add evidence", systemImage: "plus.circle")
                            .font(.caption)
                    }
                    if !criterion.evidence.isEmpty {
                        Button("Clear evidence") {
                            criterion.evidence = []
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
                if showingEvidenceEntry {
                    HStack {
                        TextField("Paste an evidence quote from the student text", text: $newEvidenceText)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        Button("Add") {
                            let trimmed = newEvidenceText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                criterion.evidence += [trimmed]
                                newEvidenceText = ""
                                showingEvidenceEntry = false
                            }
                        }
                        .disabled(newEvidenceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                ForEach(Array(criterion.evidence.enumerated()), id: \.offset) { index, evidence in
                    HStack(alignment: .top) {
                        Text("\u{201C}\(evidence)\u{201D}")
                            .font(.caption)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            var updated = criterion.evidence
                            updated.remove(at: index)
                            criterion.evidence = updated
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if criterion.evidence.isEmpty && !showingEvidenceEntry {
                    Text("No evidence cited. Add a quote from the reviewed student text.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Teacher rationale or private note for this criterion", text: $criterion.teacherRationale, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Criterion", systemImage: "trash")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
