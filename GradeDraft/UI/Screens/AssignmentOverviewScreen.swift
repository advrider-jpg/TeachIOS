import SwiftUI

// MARK: - Steps

/// The ordered steps of grading an assignment for its class, mirroring the teacher workflow.
enum GradeWizardStep: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case setup
    case studentWork
    case scannedText
    case aiDraft
    case finalReview
    case export

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .setup: return "Setup"
        case .studentWork: return "Student Work"
        case .scannedText: return "Scanned Text"
        case .aiDraft: return "AI Draft"
        case .finalReview: return "Final Review"
        case .export: return "Export"
        }
    }

    var systemImage: String {
        switch self {
        case .setup: return "doc.text"
        case .studentWork: return "tray.and.arrow.down"
        case .scannedText: return "text.viewfinder"
        case .aiDraft: return "sparkles"
        case .finalReview: return "checklist"
        case .export: return "square.and.arrow.up"
        }
    }

    /// The last part of the step's accessibility identifier.
    var identifier: String {
        switch self {
        case .setup: return "setup"
        case .studentWork: return "studentWork"
        case .scannedText: return "scannedText"
        case .aiDraft: return "aiDraft"
        case .finalReview: return "finalReview"
        case .export: return "export"
        }
    }
}

/// Where an assignment stands, step by step, worked out from the assignment's grading standard and
/// each student's status. A step is complete only when every student has passed it. The messages for a
/// step that is not complete come from `ReadinessIssue`.
struct GradeWizardProgress: Equatable {
    let hasGradingStandard: Bool
    let submissions: [SubmissionSummary]

    init(assignment: Assignment, submissions: [SubmissionSummary]) {
        self.hasGradingStandard = assignment.hasGradingStandard
        self.submissions = submissions
    }

    func count(_ status: RosterStatus) -> Int {
        submissions.filter { $0.rosterStatus == status }.count
    }

    /// Students who have not yet passed the step.
    private func notYetPast(_ step: GradeWizardStep) -> Set<RosterStatus> {
        switch step {
        case .setup:
            return []
        case .studentWork:
            return [.notStarted]
        case .scannedText:
            return [.notStarted, .ocrReviewNeeded]
        case .aiDraft:
            return [.notStarted, .ocrReviewNeeded, .readyForGrading, .needsRecheck]
        case .finalReview:
            return Set(RosterStatus.allCases).subtracting([.approved, .exported])
        case .export:
            return Set(RosterStatus.allCases).subtracting([.exported])
        }
    }

    /// The statuses a student is in when this step is the one for them to do next.
    private func nextUp(for step: GradeWizardStep) -> Set<RosterStatus> {
        switch step {
        case .setup: return []
        case .studentWork: return [.notStarted]
        case .scannedText: return [.ocrReviewNeeded]
        case .aiDraft: return [.readyForGrading, .needsRecheck]
        case .finalReview: return [.draftGenerated, .finalReviewInProgress, .needsRecheck]
        case .export: return [.approved]
        }
    }

    func isComplete(_ step: GradeWizardStep) -> Bool {
        if step == .setup { return hasGradingStandard }
        return !submissions.isEmpty && submissions.allSatisfy { !notYetPast(step).contains($0.rosterStatus) }
    }

    var completedCount: Int {
        GradeWizardStep.allCases.filter(isComplete).count
    }

    /// The first step that is not complete; nil when every step is.
    var currentStep: GradeWizardStep? {
        GradeWizardStep.allCases.first { !isComplete($0) }
    }

    /// The first student, in roster order, whose next task is this step.
    func nextSubmission(for step: GradeWizardStep) -> SubmissionSummary? {
        let statuses = nextUp(for: step)
        return submissions.first { statuses.contains($0.rosterStatus) }
    }

    /// Why the step is not complete, in the words `ReadinessIssue` defines; nil when complete or when the
    /// step is only waiting for an earlier one.
    func issue(for step: GradeWizardStep) -> ReadinessIssue? {
        guard !isComplete(step) else { return nil }
        switch step {
        case .setup:
            return .missingGradingStandard
        case .studentWork:
            return .missingStudentWork
        case .scannedText:
            return count(.ocrReviewNeeded) > 0 ? .scannedTextNotMarkedReviewed : nil
        case .aiDraft:
            if count(.needsRecheck) > 0 { return .draftStale }
            return count(.readyForGrading) > 0 ? .aiReadinessNotChecked : nil
        case .finalReview:
            if count(.needsRecheck) > 0 { return .finalReviewStale }
            if count(.finalReviewInProgress) > 0 { return .criteriaNotApproved }
            return count(.draftGenerated) > 0 ? .noFinalReview : nil
        case .export:
            let waiting = submissions.contains { ![.approved, .exported].contains($0.rosterStatus) }
            return waiting ? .finalReviewNotApproved : nil
        }
    }

    func status(_ step: GradeWizardStep) -> GradeDraftUIStatus {
        if isComplete(step) {
            switch step {
            case .finalReview: return .approved
            case .export: return .exported
            default: return .onTrack
            }
        }
        guard step == currentStep else { return .notStarted }
        switch step {
        case .setup: return .needsAttention
        case .studentWork: return .addStudentWork
        case .scannedText: return .reviewScannedText
        case .aiDraft: return count(.needsRecheck) > 0 ? .needsRecheck : .readyForTeacherReview
        case .finalReview: return count(.needsRecheck) > 0 ? .needsRecheck : .reviewFinalGrade
        case .export: return .readyToExport
        }
    }

    /// One status for the whole assignment: the current step's, or "Exported" when every step is complete.
    var overallStatus: GradeDraftUIStatus {
        currentStep.map(status) ?? .exported
    }
}

// MARK: - Screen

/// One assignment: its details, the six grading steps with the current one open, and every student's
/// submission with its status.
struct AssignmentOverviewScreen: View {
    let model: AssignmentSetupModel
    @State private var expandedSteps: Set<GradeWizardStep>

    init(model: AssignmentSetupModel) {
        self.model = model
        var current = GradeWizardStep.export
        if let setup = model.setup,
           let step = GradeWizardProgress(assignment: setup.assignment, submissions: model.submissions).currentStep {
            current = step
        }
        _expandedSteps = State(initialValue: [current])
    }

    var body: some View {
        @Bindable var model = model
        Group {
            if let setup = model.setup {
                content(setup)
            } else {
                ProgressView()
            }
        }
        .alertMessage($model.alert)
    }

    private func content(_ setup: AssignmentSetup) -> some View {
        let progress = GradeWizardProgress(assignment: setup.assignment, submissions: model.submissions)
        let stepCount = GradeWizardStep.allCases.count
        return List {
            Section {
                LabeledContent("Class", value: model.className)
                LabeledContent("Rubric", value: rubricSummary(setup))
                ProgressView("Progress", value: Double(progress.completedCount), total: Double(stepCount))
                    .accessibilityValue("\(progress.completedCount) of \(stepCount) steps complete")
                    .accessibilityIdentifier("assignmentOverview.progress")
            }

            Section("Assignment Details") {
                TextField("Assignment title", text: model.text(\.title))
                    .accessibilityIdentifier("assignmentOverview.title")
                TextField("Assignment question or prompt", text: model.text(\.prompt), axis: .vertical)
                    .accessibilityIdentifier("assignmentOverview.prompt")
                TextField("Subject", text: model.text(\.subject))
                    .accessibilityIdentifier("assignmentOverview.subject")
                TextField("Grade level", text: model.text(\.gradeLevel))
                    .accessibilityIdentifier("assignmentOverview.gradeLevel")
                Picker("Assignment type", selection: assignmentType(setup)) {
                    ForEach(AssignmentType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .accessibilityIdentifier("assignmentOverview.type")
            }

            ForEach(GradeWizardStep.allCases) { step in
                Section(isExpanded: expansion(of: step)) {
                    stepRows(step, progress: progress, setup: setup)
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(step.title, systemImage: step.systemImage)
                            .font(.headline)
                        StatusLabel(progress.status(step), subject: "\(step.title) status")
                            .font(.subheadline)
                    }
                    .textCase(nil)
                    .accessibilityIdentifier("assignmentOverview.step.\(step.identifier)")
                }
            }

            Section("Students") {
                if model.submissions.isEmpty {
                    ContentUnavailableView(
                        "No students yet",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Add students to the class to start grading this assignment.")
                    )
                } else {
                    ForEach(model.submissions) { submission in
                        NavigationLink(value: Route.submission(submission.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(submission.studentName)
                                    .font(.headline)
                                StatusLabel(submission.rosterStatus.uiStatus, subject: "Grading status")
                                    .font(.subheadline)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        .accessibilityIdentifier("assignmentOverview.submission.\(submission.id.uuidString)")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(setup.assignment.title.isEmpty ? "Assignment" : setup.assignment.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Steps

    @ViewBuilder
    private func stepRows(_ step: GradeWizardStep, progress: GradeWizardProgress, setup: AssignmentSetup) -> some View {
        if let issue = progress.issue(for: step) {
            Label(issue.message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
        switch step {
        case .setup:
            NavigationLink(value: Route.rubric(model.assignmentID)) {
                Label("Rubric & Instructions", systemImage: "list.bullet.rectangle")
            }
            .accessibilityIdentifier("assignmentOverview.rubric")
            NavigationLink(value: Route.curriculum(assignmentID: model.assignmentID)) {
                LabeledContent {
                    Text("\(setup.curriculumMappings.count)")
                } label: {
                    Label("Curriculum References", systemImage: "books.vertical")
                }
            }
            .accessibilityIdentifier("assignmentOverview.curriculum")
        case .studentWork:
            LabeledContent("Students without work", value: "\(progress.count(.notStarted))")
        case .scannedText:
            LabeledContent("Scanned text to review", value: "\(progress.count(.ocrReviewNeeded))")
        case .aiDraft:
            if case .unavailable(let detail) = model.localAIStatus {
                Label(ReadinessIssue.localAIUnavailable(detail).message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else {
                LabeledContent("On-device AI", value: "Ready")
            }
            LabeledContent("Ready to draft", value: "\(progress.count(.readyForGrading))")
            LabeledContent("Drafts to review", value: "\(progress.count(.draftGenerated))")
        case .finalReview:
            LabeledContent("Final reviews in progress", value: "\(progress.count(.finalReviewInProgress))")
            LabeledContent("Needing recheck", value: "\(progress.count(.needsRecheck))")
            LabeledContent("Approved", value: "\(progress.count(.approved) + progress.count(.exported)) of \(progress.submissions.count)")
        case .export:
            LabeledContent("Exported", value: "\(progress.count(.exported)) of \(progress.submissions.count)")
        }
        if let next = progress.nextSubmission(for: step) {
            NavigationLink(value: Route.submission(next.id)) {
                Label("Continue with \(next.studentName)", systemImage: "arrow.right.circle")
            }
            .accessibilityIdentifier("assignmentOverview.continue.\(step.identifier)")
        }
    }

    private func expansion(of step: GradeWizardStep) -> Binding<Bool> {
        Binding(
            get: { expandedSteps.contains(step) },
            set: { isExpanded in
                if isExpanded {
                    expandedSteps.insert(step)
                } else {
                    expandedSteps.remove(step)
                }
            }
        )
    }

    private func assignmentType(_ setup: AssignmentSetup) -> Binding<AssignmentType> {
        Binding(
            get: { model.setup?.assignment.assignmentType ?? setup.assignment.assignmentType },
            set: { newValue in model.edit { $0.assignment.assignmentType = newValue } }
        )
    }

    private func rubricSummary(_ setup: AssignmentSetup) -> String {
        guard setup.assignment.hasGradingStandard else { return "Not added" }
        let count = setup.parsedRubric.criteria.count
        if count == 0 { return "Added, no criteria read" }
        return count == 1 ? "1 criterion" : "\(count) criteria"
    }
}

#if DEBUG
private struct AssignmentOverviewPreview: View {
    @State private var model = PreviewFixtures.makeAppModel()

    var body: some View {
        NavigationStack {
            RouteDestination(route: .assignment(PreviewFixtures.assignmentID), app: model)
                .navigationDestination(for: Route.self) { RouteDestination(route: $0, app: model) }
        }
        .environment(model)
        .task { await model.observeLists() }
    }
}

#Preview("Light") {
    AssignmentOverviewPreview()
}

#Preview("Dark") {
    AssignmentOverviewPreview()
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    AssignmentOverviewPreview()
        .dynamicTypeSize(.accessibility3)
}
#endif
