import SwiftUI

struct AssignmentOverviewScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var assignmentID: UUID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GradeDraftLayout.deepSectionSpacing) {
                if let assignment = viewModel.assignment(for: assignmentID) {
                    DeepWorkflowHeader(
                        title: assignment.title,
                        subtitle: "Workflow summary and next action.",
                        status: viewModel.v6Status(for: assignment)
                    ) {
                        Button("Save") { save() }
                            .buttonStyle(.bordered)
                    }

                    GroupedListCard(title: "Next up", subtitle: nextUpDetail(for: assignment)) {
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
                    }
                    .padding(.horizontal, GradeDraftLayout.screenPadding)

                    GroupedListCard(title: "Workflow", subtitle: "Visible steps match the teacher workflow.") {
                        WorkflowProgressRail(steps: workflowSteps(for: assignment))
                    }
                    .padding(.horizontal, GradeDraftLayout.screenPadding)

                    if !blockingIssues(for: assignment).isEmpty {
                        GroupedListCard(title: "Fix before continuing", subtitle: "These items prevent grading or export.") {
                            ForEach(blockingIssues(for: assignment), id: \.title) { issue in
                                BlockingIssueRow(title: issue.title, detail: issue.detail, status: issue.status)
                            }
                        }
                        .padding(.horizontal, GradeDraftLayout.screenPadding)
                    }

                    GroupedListCard(title: "Assignment details", subtitle: "Setup fields for this record.") {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Assignment title", text: binding(\.title))
                                .textFieldStyle(.roundedBorder)
                            TextField("Assignment question or prompt", text: promptBinding)
                                .textFieldStyle(.roundedBorder)
                            TextField("Student name or local identifier", text: binding(\.studentDisplayName))
                                .textFieldStyle(.roundedBorder)
                            TextField("Class or section", text: binding(\.className))
                                .textFieldStyle(.roundedBorder)
                            TextField("Subject", text: binding(\.subject))
                                .textFieldStyle(.roundedBorder)
                            TextField("Grade level", text: binding(\.gradeLevel))
                                .textFieldStyle(.roundedBorder)
                            Picker("Assignment type", selection: binding(\.assignmentType)) {
                                ForEach(AssignmentType.allCases) { type in Text(type.displayName).tag(type) }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(GradeDraftLayout.rowHorizontalPadding)
                    }
                    .padding(.horizontal, GradeDraftLayout.screenPadding)
                } else {
                    EmptyState(title: "Assignment not found", message: "Return to Assignments and choose a saved assignment.", systemImage: "doc.text.magnifyingglass")
                        .padding(GradeDraftLayout.screenPadding)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { viewModel.selectAssignment(assignmentID) }
    }

    private func workflowSteps(for assignment: AssignmentRecord) -> [WorkflowStepRow] {
        [
            WorkflowStepRow(index: 1, title: "Setup", detail: assignment.hasGradingStandard ? "Rubric or grading standard saved." : "Add a rubric, answer key, exemplar, or grading criteria.", status: assignment.hasGradingStandard ? .onTrack : .notStarted),
            WorkflowStepRow(index: 2, title: "Student Work", detail: assignment.reviewedStudentText.isEmpty ? "Add student work for teacher-reviewed grading." : "Student work has been added.", status: assignment.reviewedStudentText.isEmpty ? .addStudentWork : .onTrack),
            WorkflowStepRow(index: 3, title: GradeDraftWorkflowLanguage.ocrReviewStepLabel, detail: assignment.ocrReviewStatus.blocksGrading ? GradeDraftWorkflowLanguage.reviewScannedTextExplanation : "Text review gate is satisfied.", status: assignment.ocrReviewStatus.v6Status),
            WorkflowStepRow(index: 4, title: "Rubric", detail: assignment.hasGradingStandard ? "Rubric or instructions ready for teacher review." : "Rubric needs fixes before grading.", status: assignment.hasGradingStandard ? .onTrack : .needsAttention),
            WorkflowStepRow(index: 5, title: "Final Review", detail: assignment.finalReview == nil ? "Review final grade before export." : "Teacher final review is saved.", status: assignment.finalReview?.status.v6Status ?? .reviewFinalGrade),
            WorkflowStepRow(index: 6, title: "Export", detail: viewModel.canExportStudentReport ? "Ready to export." : "Final approval required before student-facing export.", status: viewModel.canExportStudentReport ? .readyToExport : .notStarted)
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
            ExportsRestoreScreen(viewModel: viewModel)
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
            get: { viewModel.assignment[keyPath: keyPath] },
            set: { newValue in viewModel.updateAssignment { $0[keyPath: keyPath] = newValue } }
        )
    }

    private var promptBinding: Binding<String> {
        Binding(
            get: { viewModel.assignment.prompt ?? "" },
            set: { value in viewModel.updateAssignment { $0.prompt = value.nilIfBlank } }
        )
    }

    private func save() {
        do {
            try viewModel.saveCurrentAssignment()
            viewModel.statusMessage = "Assignment saved locally."
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}
