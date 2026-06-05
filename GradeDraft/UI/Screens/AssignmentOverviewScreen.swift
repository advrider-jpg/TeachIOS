import SwiftUI

struct AssignmentOverviewScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var assignmentID: UUID
    @State private var showWizard = false

    var body: some View {
        Group {
            if let assignment = viewModel.assignment(for: assignmentID) {
                Form {
                    AssignmentStationeryHeader(
                        eyebrow: "Workflow",
                        title: assignment.title.isEmpty ? "Assignment" : assignment.title,
                        subtitle: nextUpDetail(for: assignment),
                        status: viewModel.v6Status(for: assignment)
                    )
                    PaperStack(theme: AssignmentWorkflowStationery.theme) {
                        HStack(alignment: .top) {
                            TapeLabel("Next up", theme: AssignmentWorkflowStationery.theme)
                            Spacer(minLength: 8)
                            PaperclipDecoration(theme: AssignmentWorkflowStationery.theme)
                        }
                        NavigationLink {
                            nextDestination(for: assignment)
                        } label: {
                            ReviewQueueRow(
                                title: viewModel.v6Status(for: assignment).rawValue,
                                detail: nextUpDetail(for: assignment),
                                countText: nil,
                                status: viewModel.v6Status(for: assignment),
                                actionLabel: viewModel.v6ActionLabel(for: assignment)
                            )
                        }
                        .buttonStyle(.plain)
                        HandwrittenAnnotation(nextUpDetail(for: assignment), status: viewModel.v6Status(for: assignment), theme: AssignmentWorkflowStationery.theme)
                        Button {
                            viewModel.selectAssignment(assignmentID)
                            showWizard = true
                        } label: {
                            Label("Start Guided Grading", systemImage: "wand.and.stars")
                                .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityHint("Walk through every grading step for this student")
                    }

                    NotebookCard(theme: AssignmentWorkflowStationery.theme, showsPerforation: true) {
                        TapeLabel("Timeline", theme: AssignmentWorkflowStationery.theme)
                        workflowProgressSummary(for: assignment)
                        WorkflowProgressRail(steps: workflowSteps(for: assignment))
                        HandwrittenAnnotation("Visible steps match the teacher workflow.", theme: AssignmentWorkflowStationery.theme)
                    }

                    if !blockingIssues(for: assignment).isEmpty {
                        NotebookCard(theme: AssignmentWorkflowStationery.theme, status: .fixBeforeContinuing, showsPerforation: true) {
                            TapeLabel("Fix first", theme: AssignmentWorkflowStationery.theme)
                            ForEach(blockingIssues(for: assignment), id: \.title) { issue in
                                BlockingIssueRow(title: issue.title, detail: issue.detail, status: issue.status)
                            }
                            HandwrittenAnnotation("These items prevent grading or export.", status: .fixBeforeContinuing, theme: AssignmentWorkflowStationery.theme)
                        }
                    }

                    NotebookCard(theme: AssignmentWorkflowStationery.theme, showsPerforation: true) {
                        TapeLabel("Assignment details", theme: AssignmentWorkflowStationery.theme)
                        VStack(spacing: 12) {
                            assignmentField("Assignment title") {
                                TextField("Assignment title", text: binding(\.title))
                            }
                            assignmentField("Assignment question or prompt") {
                                TextField("Assignment question or prompt", text: promptBinding, axis: .vertical)
                                    .lineLimit(2...6)
                            }
                            assignmentField("Student name or local identifier") {
                                TextField("Student name or local identifier", text: binding(\.studentDisplayName))
                            }
                            assignmentField("Class or section") {
                                TextField("Class or section", text: binding(\.className))
                            }
                            assignmentField("Subject") {
                                TextField("Subject", text: binding(\.subject))
                            }
                            assignmentField("Grade level") {
                                TextField("Grade level", text: binding(\.gradeLevel))
                            }
                            assignmentField("Assignment type") {
                                Picker("Assignment type", selection: binding(\.assignmentType)) {
                                    ForEach(AssignmentType.allCases) { type in
                                        Text(type.displayName).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        HandwrittenAnnotation("Setup fields stay local and are used to build the teacher-reviewed grading packet.", theme: AssignmentWorkflowStationery.theme)
                    }
                }
                .stationeryScreen(theme: AssignmentWorkflowStationery.theme)
                .navigationTitle(assignment.title.isEmpty ? "Assignment" : assignment.title)
            } else {
                ContentUnavailableView(
                    "Assignment not found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Return to Assignments and choose a saved assignment.")
                )
                .navigationTitle("Assignment")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .disabled(viewModel.assignment(for: assignmentID) == nil)
            }
        }
        .onAppear { viewModel.selectAssignment(assignmentID) }
        .fullScreenCover(isPresented: $showWizard) {
            GradeWizardView(viewModel: viewModel, assignmentID: assignmentID)
        }
    }

    @ViewBuilder
    private func assignmentField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(GradeDraftTypography.helper.weight(.semibold))
                .foregroundStyle(AssignmentWorkflowStationery.theme.mutedInk)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AssignmentWorkflowStationery.theme.paperTint.opacity(0.72), in: RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous))
    }

    private func workflowProgressSummary(for assignment: AssignmentRecord) -> some View {
        let steps = workflowSteps(for: assignment)
        let total = steps.count
        let done = steps.filter { isStepComplete($0.status) }.count
        let currentStep = min(done + 1, total)
        let percent = total == 0 ? 0 : Int((Double(done) / Double(total) * 100).rounded())
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(done >= total ? "All steps complete" : "Step \(currentStep) of \(total)")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(AssignmentWorkflowStationery.theme.ink)
                Spacer(minLength: 8)
                Text("\(percent)%")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AssignmentWorkflowStationery.theme.mutedInk)
            }
            ProgressView(value: Double(done), total: Double(max(total, 1)))
                .tint(AssignmentWorkflowStationery.theme.accent)
                .accessibilityLabel("Workflow progress")
                .accessibilityValue("\(done) of \(total) steps complete")
        }
    }

    private func isStepComplete(_ status: GradeDraftUIStatus) -> Bool {
        switch status {
        case .onTrack, .approved, .readyToExport, .exported:
            return true
        default:
            return false
        }
    }

    private func workflowSteps(for assignment: AssignmentRecord) -> [WorkflowStepRow] {
        [
            WorkflowStepRow(index: 1, title: "Setup", detail: assignment.hasGradingStandard ? "Rubric or grading standard saved." : "Add a rubric, answer key, exemplar, or grading criteria.", status: assignment.hasGradingStandard ? .onTrack : .notStarted),
            WorkflowStepRow(index: 2, title: "Student Work", detail: assignment.reviewedStudentText.isEmpty ? "Add student work for teacher-reviewed grading." : "Student work has been added.", status: assignment.reviewedStudentText.isEmpty ? .addStudentWork : .onTrack),
            WorkflowStepRow(index: 3, title: GradeDraftWorkflowLanguage.ocrReviewStepLabel, detail: assignment.ocrReviewStatus.blocksGrading ? GradeDraftWorkflowLanguage.reviewScannedTextExplanation : "Text review gate is satisfied.", status: assignment.ocrReviewStatus.v6Status),
            WorkflowStepRow(index: 4, title: "Rubric", detail: assignment.hasGradingStandard ? "Rubric or instructions ready for teacher review." : "Rubric needs fixes before grading.", status: assignment.hasGradingStandard ? .onTrack : .needsAttention),
            WorkflowStepRow(index: 5, title: "Final Review", detail: finalReviewStepDetail(for: assignment), status: finalReviewStepStatus(for: assignment)),
            WorkflowStepRow(index: 6, title: "Export", detail: assignment.isStudentFacingExportReady ? "Ready to export." : "Final approval required before student-facing export.", status: assignment.isStudentFacingExportReady ? .readyToExport : .notStarted)
        ]
    }

    @ViewBuilder
    private func nextDestination(for assignment: AssignmentRecord) -> some View {
        switch viewModel.v6Status(for: assignment) {
        case .addStudentWork:
            StudentWorkScreen(viewModel: viewModel, assignmentID: assignment.id)
        case .reviewScannedText, .textNeedsAttention:
            ReviewScannedTextScreen(viewModel: viewModel, assignmentID: assignment.id)
        case .reviewFinalGrade, .needsRecheck, .readyForTeacherReview, .inProgress:
            FinalReviewScreen(viewModel: viewModel, assignmentID: assignment.id)
        case .readyToExport, .approved, .exported:
            ExportsRestoreScreen(viewModel: viewModel, assignmentID: assignment.id)
                .toolbar(.hidden, for: .tabBar)
        case .notStarted, .needsAttention, .fixBeforeContinuing, .onTrack, .studentFacing, .teacherOnly:
            RubricInstructionsScreen(viewModel: viewModel, assignmentID: assignment.id)
        }
    }

    private func nextUpDetail(for assignment: AssignmentRecord) -> String {
        switch viewModel.v6Status(for: assignment) {
        case .reviewScannedText, .textNeedsAttention:
            return "Next up: \(GradeDraftWorkflowLanguage.reviewScannedTextExplanation)"
        case .addStudentWork:
            return "Next up: Add student work for teacher-reviewed grading."
        case .needsRecheck:
            return "Next up: Recheck review because student work, rubric, or evidence changed."
        case .reviewFinalGrade:
            return "Next up: Review final grade and approve each criterion."
        case .readyToExport, .approved:
            return "Next up: Export student-facing or teacher-only records."
        default:
            return "Next up: Complete setup and review requirements."
        }
    }

    private func blockingIssues(for assignment: AssignmentRecord) -> [(title: String, detail: String, status: GradeDraftUIStatus)] {
        var issues: [(String, String, GradeDraftUIStatus)] = []
        if assignment.ocrReviewStatus == .blocked {
            issues.append(("Text lines need checking", "Low confidence text needs review before grading.", .textNeedsAttention))
        } else if assignment.ocrReviewStatus.blocksGrading {
            issues.append(("Text lines need checking", GradeDraftWorkflowLanguage.reviewScannedTextExplanation, .fixBeforeContinuing))
        }
        if !assignment.hasGradingStandard {
            issues.append(("Rubric needs fixes", "Add rubric, answer key, exemplar, or grading criteria.", .fixBeforeContinuing))
        }
        if assignment.finalReviewIsStale {
            issues.append(("This review needs rechecking", "Student work, rubric, or evidence changed after this review was last saved.", .needsRecheck))
        }
        return issues
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AssignmentRecord, Value>) -> Binding<Value> {
        Binding(
            get: {
                if let assignment = viewModel.assignment(for: assignmentID) {
                    return assignment[keyPath: keyPath]
                }
                return viewModel.assignment[keyPath: keyPath]
            },
            set: { newValue in
                viewModel.selectAssignment(assignmentID)
                viewModel.updateAssignment { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private var promptBinding: Binding<String> {
        Binding(
            get: { viewModel.assignment(for: assignmentID)?.prompt ?? "" },
            set: { value in
                viewModel.selectAssignment(assignmentID)
                viewModel.updateAssignment { $0.prompt = value.nilIfBlank }
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

    private func finalReviewStepDetail(for assignment: AssignmentRecord) -> String {
        if assignment.finalReviewIsStale {
            return "Recheck final review because student work, rubric, or evidence changed."
        }
        guard let finalReview = assignment.finalReview else {
            return "Review final grade before export."
        }
        return finalReview.status == .approved ? "Teacher-approved final review is saved." : "Teacher final review is in progress."
    }

    private func finalReviewStepStatus(for assignment: AssignmentRecord) -> GradeDraftUIStatus {
        if assignment.finalReviewIsStale { return .needsRecheck }
        return assignment.finalReview?.status.v6Status ?? .reviewFinalGrade
    }
}
