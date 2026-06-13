import SwiftUI

/// The ordered stages of grading one student's assignment, mirroring the teacher workflow.
enum GradeWizardStep: Int, CaseIterable, Identifiable, Hashable {
    case setup
    case studentWork
    case textReview
    case rubric
    case finalReview
    case export

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .setup: return "Setup"
        case .studentWork: return "Student Work"
        case .textReview: return "Text Review"
        case .rubric: return "Rubric"
        case .finalReview: return "Final Review"
        case .export: return "Export"
        }
    }

    var systemImage: String {
        switch self {
        case .setup: return "doc.text"
        case .studentWork: return "tray.and.arrow.down"
        case .textReview: return "text.viewfinder"
        case .rubric: return "list.bullet.rectangle"
        case .finalReview: return "checklist"
        case .export: return "square.and.arrow.up"
        }
    }

    var summary: String {
        switch self {
        case .setup: return "Confirm the assignment title, student, and type for this grading packet."
        case .studentWork: return "Scan, import, or paste the student's work so it can be reviewed locally."
        case .textReview: return "Review and confirm any scanned text before it is used for grading."
        case .rubric: return "Add the rubric, answer key, exemplar, or criteria the grade will be measured against."
        case .finalReview: return "Draft or start the review, then edit and approve each criterion."
        case .export: return "Create the student-facing report once the final grade is approved."
        }
    }
}

/// Pure, testable gating logic for the guided grading wizard.
enum GradeWizardProgress {
    static func isComplete(_ step: GradeWizardStep, for assignment: AssignmentRecord) -> Bool {
        switch step {
        case .setup:
            return !isBlank(assignment.title) && !isBlank(assignment.studentDisplayName)
        case .studentWork:
            return !isBlank(assignment.reviewedStudentText)
        case .textReview:
            return !assignment.ocrReviewStatus.blocksGrading
        case .rubric:
            return assignment.hasGradingStandard
        case .finalReview:
            return assignment.finalReview?.status == .approved && !assignment.finalReviewIsStale
        case .export:
            return assignment.exportRecords.contains { $0.exportKind == .studentMarkdown || $0.exportKind == .studentPDF }
        }
    }

    static func firstIncompleteStep(for assignment: AssignmentRecord) -> GradeWizardStep {
        GradeWizardStep.allCases.first { !isComplete($0, for: assignment) } ?? .export
    }

    static func completedCount(for assignment: AssignmentRecord) -> Int {
        GradeWizardStep.allCases.filter { isComplete($0, for: assignment) }.count
    }

    static func blockingReasons(_ step: GradeWizardStep, for assignment: AssignmentRecord) -> [String] {
        switch step {
        case .setup:
            var reasons: [String] = []
            if isBlank(assignment.title) { reasons.append("Add an assignment title.") }
            if isBlank(assignment.studentDisplayName) { reasons.append("Add a student name or local identifier.") }
            return reasons
        case .studentWork:
            return isComplete(.studentWork, for: assignment) ? [] : ["Add scanned, imported, or pasted student work."]
        case .textReview:
            return assignment.ocrReviewStatus.blocksGrading ? ["Review and confirm scanned text before grading."] : []
        case .rubric:
            return assignment.hasGradingStandard ? [] : ["Add a rubric, answer key, exemplar, or grading criteria."]
        case .finalReview:
            if assignment.finalReviewIsStale { return ["Recheck the review because student work, rubric, or evidence changed."] }
            if assignment.finalReview?.status == .approved { return [] }
            return ["Draft or start the review, then approve each criterion."]
        case .export:
            return assignment.isStudentFacingExportReady ? [] : ["Approve the final review before exporting the student-facing report."]
        }
    }

    private static func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Full-screen, step-by-step guided grading flow for one student's assignment.
/// Lightweight steps (Setup, Export) are handled inline; heavier steps deep-link
/// into the existing focused screens. Advancement is gated on each step's completion.
struct GradeWizardView: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    let assignmentID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var step: GradeWizardStep = .setup
    @State private var deepLink: GradeWizardStep?
    @State private var didPosition = false
    @State private var confirmationKind: ExportConfirmationKind?

    private var assignment: AssignmentRecord? { viewModel.assignment(for: assignmentID) }

    var body: some View {
        NavigationStack {
            Group {
                if let assignment {
                    VStack(spacing: 0) {
                        stepper(for: assignment)
                        Divider()
                        ScrollView {
                            stepContent(for: assignment)
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider()
                        footer(for: assignment)
                    }
                } else {
                    ContentUnavailableView(
                        "Assignment not found",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Close and choose a saved assignment.")
                    )
                }
            }
            .navigationTitle("Guided Grading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(assignment == nil)
                }
            }
            .navigationDestination(item: $deepLink) { target in
                destination(for: target)
            }
            .onAppear {
                viewModel.selectAssignment(assignmentID)
                if !didPosition, let assignment {
                    step = GradeWizardProgress.firstIncompleteStep(for: assignment)
                    didPosition = true
                }
            }
            .sheet(item: $confirmationKind) { kind in
                if let assignment {
                    ExportConfirmationSheet(
                        kind: kind,
                        assignment: assignment,
                        allAssignments: viewModel.assignments,
                        onCancel: { confirmationKind = nil },
                        onConfirm: { confirmExport(kind) }
                    )
                } else {
                    ContentUnavailableView(
                        "Assignment not found",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Close and choose a saved assignment before exporting.")
                    )
                    .presentationDetents([.medium])
                }
            }
        }
    }

    // MARK: - Stepper

    private func stepper(for assignment: AssignmentRecord) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(GradeWizardStep.allCases) { candidate in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { step = candidate }
                    } label: {
                        stepPill(candidate, assignment: assignment)
                    }
                    .buttonStyle(.plain)
                    if candidate != GradeWizardStep.allCases.last {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.25))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                    }
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Step \(step.rawValue + 1) of \(GradeWizardStep.allCases.count) · \(step.title)")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text("\(GradeWizardProgress.completedCount(for: assignment))/\(GradeWizardStep.allCases.count) done")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func stepPill(_ candidate: GradeWizardStep, assignment: AssignmentRecord) -> some View {
        let done = GradeWizardProgress.isComplete(candidate, for: assignment)
        let current = candidate == step
        return ZStack {
            Circle()
                .fill(current ? Color.accentColor : (done ? Color.green.opacity(0.18) : Color.secondary.opacity(0.12)))
                .frame(width: 30, height: 30)
            if done && !current {
                Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.green)
            } else {
                Image(systemName: candidate.systemImage)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(current ? Color.white : Color.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(candidate.title), step \(candidate.rawValue + 1) of \(GradeWizardStep.allCases.count)")
        .accessibilityValue(done ? "Complete" : (current ? "Current step" : "Not complete"))
        .accessibilityAddTraits(current ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Step content

    @ViewBuilder
    private func stepContent(for assignment: AssignmentRecord) -> some View {
        switch step {
        case .setup:
            setupStep(assignment)
        case .studentWork:
            toolStep(assignment, step: .studentWork,
                     openLabel: "Add or Review Student Work", openIcon: "tray.and.arrow.down",
                     doneText: "Student work has been added.")
        case .textReview:
            toolStep(assignment, step: .textReview,
                     openLabel: "Review Scanned Text", openIcon: "text.viewfinder",
                     doneText: "The text review gate is satisfied.")
        case .rubric:
            toolStep(assignment, step: .rubric,
                     openLabel: "Open Rubric & Instructions", openIcon: "list.bullet.rectangle",
                     doneText: "A grading standard is saved.")
        case .finalReview:
            toolStep(assignment, step: .finalReview,
                     openLabel: "Open Final Review", openIcon: "checklist",
                     doneText: "A teacher-approved final review is saved.")
        case .export:
            exportStep(assignment)
        }
    }

    private func stepHeader(_ step: GradeWizardStep) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(step.title, systemImage: step.systemImage)
                .font(.title2.weight(.bold))
            Text(step.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusRow(done: Bool, _ text: String) -> some View {
        Label(text, systemImage: done ? "checkmark.circle.fill" : "circle")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(done ? .green : .secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func blockingReasons(_ step: GradeWizardStep, _ assignment: AssignmentRecord) -> some View {
        ForEach(GradeWizardProgress.blockingReasons(step, for: assignment), id: \.self) { reason in
            Label(reason, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func toolStep(_ assignment: AssignmentRecord, step: GradeWizardStep, openLabel: String, openIcon: String, doneText: String) -> some View {
        let done = GradeWizardProgress.isComplete(step, for: assignment)
        return VStack(alignment: .leading, spacing: 14) {
            stepHeader(step)
            statusRow(done: done, done ? doneText : "Not done yet.")
            blockingReasons(step, assignment)
            openToolButton(step, label: openLabel, systemImage: openIcon)
        }
    }

    private func setupStep(_ assignment: AssignmentRecord) -> some View {
        let done = GradeWizardProgress.isComplete(.setup, for: assignment)
        return VStack(alignment: .leading, spacing: 14) {
            stepHeader(.setup)
            statusRow(done: done, done ? "Assignment identity is set." : "Add a title and student name to continue.")
            VStack(alignment: .leading, spacing: 10) {
                wizardField("Assignment title") {
                    TextField("Assignment title", text: stringBinding(\.title))
                        .textFieldStyle(.roundedBorder)
                }
                wizardField("Student name or local identifier") {
                    TextField("Student name", text: stringBinding(\.studentDisplayName))
                        .textFieldStyle(.roundedBorder)
                }
                wizardField("Class or section") {
                    TextField("Class or section", text: stringBinding(\.className))
                        .textFieldStyle(.roundedBorder)
                }
                wizardField("Subject") {
                    TextField("Subject", text: stringBinding(\.subject))
                        .textFieldStyle(.roundedBorder)
                }
                wizardField("Assignment type") {
                    Picker("Assignment type", selection: typeBinding) {
                        ForEach(AssignmentType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private func exportStep(_ assignment: AssignmentRecord) -> some View {
        let exported = GradeWizardProgress.isComplete(.export, for: assignment)
        return VStack(alignment: .leading, spacing: 14) {
            stepHeader(.export)
            if assignment.isStudentFacingExportReady {
                statusRow(done: exported, exported ? "A student-facing report has been exported." : "Ready to export the student-facing report.")
                Button {
                    confirmationKind = .studentReportPDF
                } label: {
                    Label("Create Student Report PDF", systemImage: "doc.richtext")
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    confirmationKind = .studentReportMarkdown
                } label: {
                    Label("Create Student Report (Markdown)", systemImage: "doc.plaintext")
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                if let artifact = viewModel.preparedExportArtifact,
                   artifact.assignmentID == assignmentID,
                   artifact.kind == .studentPDF || artifact.kind == .studentMarkdown {
                    ShareLink(item: artifact.url) {
                        Label("Share \(artifact.displayName)", systemImage: "square.and.arrow.up")
                            .frame(minHeight: 44)
                    }
                }
            } else {
                statusRow(done: false, "Approve the final review before exporting the student-facing report.")
                blockingReasons(.export, assignment)
            }
            openToolButton(.export, label: "Open All Export Options", systemImage: "tray.full")
        }
    }

    private func openToolButton(_ target: GradeWizardStep, label: String, systemImage: String) -> some View {
        Button {
            viewModel.selectAssignment(assignmentID)
            deepLink = target
        } label: {
            Label(label, systemImage: systemImage)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func wizardField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - Deep-link destinations

    @ViewBuilder
    private func destination(for target: GradeWizardStep) -> some View {
        switch target {
        case .setup:
            AssignmentOverviewScreen(viewModel: viewModel, assignmentID: assignmentID)
        case .studentWork:
            StudentWorkScreen(viewModel: viewModel, assignmentID: assignmentID)
        case .textReview:
            ReviewScannedTextScreen(viewModel: viewModel, assignmentID: assignmentID)
        case .rubric:
            RubricInstructionsScreen(viewModel: viewModel, assignmentID: assignmentID)
        case .finalReview:
            FinalReviewScreen(viewModel: viewModel, assignmentID: assignmentID)
        case .export:
            ExportsRestoreScreen(viewModel: viewModel, assignmentID: assignmentID)
        }
    }

    // MARK: - Footer

    private func footer(for assignment: AssignmentRecord) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { goBack() }
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(step == GradeWizardStep.allCases.first)

            Spacer(minLength: 8)

            if step == GradeWizardStep.allCases.last {
                Button { dismiss() } label: {
                    Label("Finish", systemImage: "checkmark")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { goNext() }
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!GradeWizardProgress.isComplete(step, for: assignment))
            }
        }
        .padding(20)
    }

    // MARK: - Actions

    private func goNext() {
        if let next = GradeWizardStep(rawValue: step.rawValue + 1) { step = next }
    }

    private func goBack() {
        if let previous = GradeWizardStep(rawValue: step.rawValue - 1) { step = previous }
    }

    private func stringBinding(_ keyPath: WritableKeyPath<AssignmentRecord, String>) -> Binding<String> {
        Binding(
            get: { assignment?[keyPath: keyPath] ?? "" },
            set: { value in
                viewModel.selectAssignment(assignmentID)
                viewModel.updateAssignment { $0[keyPath: keyPath] = value }
            }
        )
    }

    private var typeBinding: Binding<AssignmentType> {
        Binding(
            get: { assignment?.assignmentType ?? .essay },
            set: { value in
                viewModel.selectAssignment(assignmentID)
                viewModel.updateAssignment { $0.assignmentType = value }
            }
        )
    }

    private func save() {
        do {
            viewModel.selectAssignment(assignmentID)
            try viewModel.saveCurrentAssignment()
            viewModel.statusMessage = "Assignment saved locally."
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func confirmExport(_ kind: ExportConfirmationKind) {
        confirmationKind = nil
        viewModel.selectAssignment(assignmentID)
        Task { await viewModel.performConfirmedExport(kind) }
    }
}
