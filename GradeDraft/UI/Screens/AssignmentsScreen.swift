import SwiftUI

struct AssignmentsScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    @State private var searchText = ""

    var body: some View {
        List {
            AssignmentStationeryHeader(
                eyebrow: "Assignments",
                title: "Assignments",
                subtitle: "Each card shows the saved status and next teacher action."
            )
            StationerySearchBar(text: $searchText, prompt: "Search assignments", theme: AssignmentWorkflowStationery.theme)
            PaperStack(theme: AssignmentWorkflowStationery.theme) {
                HStack(alignment: .top) {
                    TapeLabel("Assignment stack", theme: AssignmentWorkflowStationery.theme)
                    Spacer(minLength: 8)
                    PaperclipDecoration(theme: AssignmentWorkflowStationery.theme)
                }
                if filteredAssignments.isEmpty {
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView(
                            "No saved assignments",
                            systemImage: "doc.badge.plus",
                            description: Text("Create an assignment to begin.")
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredAssignments) { assignment in
                            NavigationLink {
                                AssignmentOverviewScreen(viewModel: viewModel, assignmentID: assignment.id)
                            } label: {
                                StationeryRow(
                                    title: assignment.title,
                                    detail: assignmentRowMetadata(for: assignment),
                                    systemImage: "doc.text",
                                    status: viewModel.v6Status(for: assignment),
                                    actionLabel: viewModel.v6ActionLabel(for: assignment),
                                    theme: AssignmentWorkflowStationery.theme
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                HandwrittenAnnotation("Statuses come from the saved local assignment state.", theme: AssignmentWorkflowStationery.theme)
                    .padding(.top, 2)
            }
        }
        .gradeDraftNativeGroupedList()
        .navigationTitle("Assignments")
        .searchable(text: $searchText, prompt: "Search assignments")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.newAssignment()
                } label: {
                    Label("New Assignment", systemImage: "plus")
                }
            }
        }
    }

    private func assignmentRowMetadata(for assignment: AssignmentRecord) -> String {
        [assignment.studentDisplayName.nilIfBlank ?? "No student selected", assignment.className.nilIfBlank, assignment.assignmentType.displayName]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var filteredAssignments: [AssignmentRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.assignments }
        return viewModel.assignments.filter { assignment in
            [
                assignment.title,
                assignment.studentDisplayName,
                assignment.className,
                assignment.subject,
                assignment.assignmentType.displayName,
                viewModel.v6Status(for: assignment).rawValue
            ].contains { value in
                value.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }
}

enum AssignmentWorkflowStationery {
    static let theme = StationeryTheme(
        deskBackground: Color(red: 0.976, green: 0.941, blue: 0.855),
        paper: Color(red: 1.0, green: 0.986, blue: 0.932),
        paperTint: Color(red: 0.965, green: 0.914, blue: 0.804),
        ruledLine: Color(red: 0.47, green: 0.58, blue: 0.72).opacity(0.22),
        ink: Color(red: 0.18, green: 0.14, blue: 0.11),
        mutedInk: Color(red: 0.43, green: 0.34, blue: 0.25),
        accent: Color(red: 0.52, green: 0.32, blue: 0.16),
        tape: Color(red: 0.95, green: 0.77, blue: 0.42).opacity(0.74),
        clip: Color(red: 0.42, green: 0.36, blue: 0.30),
        shadow: Color(red: 0.24, green: 0.16, blue: 0.08).opacity(0.16)
    )
}

struct AssignmentStationeryHeader: View {
    var eyebrow: String
    var title: String
    var subtitle: String?
    var status: GradeDraftUIStatus?
    var theme: StationeryTheme

    init(
        eyebrow: String,
        title: String,
        subtitle: String? = nil,
        status: GradeDraftUIStatus? = nil,
        theme: StationeryTheme = AssignmentWorkflowStationery.theme
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.theme = theme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                TapeLabel(eyebrow, theme: theme)
                Spacer(minLength: 0)
                if let status {
                    StatusChip(status, compact: true)
                }
            }
            Text(title)
                .font(.system(.largeTitle, design: .serif).weight(.bold))
                .foregroundStyle(theme.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(GradeDraftTypography.rowMetadata)
                    .foregroundStyle(theme.mutedInk)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
