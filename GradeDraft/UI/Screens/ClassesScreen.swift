import SwiftUI

struct ClassesScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    @State private var newClassName = ""

    var body: some View {
        List {
            StationeryPageHeader(
                eyebrow: "Classes",
                title: "Classes",
                subtitle: "Local class folders for rosters, assignments, and teacher-approved progress."
            )

            ClassesStationeryCard(title: "Add Class", tapeLabel: "New folder", showsPaperclip: true) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Class name", text: $newClassName)
                        .submitLabel(.done)
                        .onSubmit(addClass)
                    Button(action: addClass) {
                        Label("Add Class", systemImage: "plus")
                            .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedClassName.isEmpty)
                    HandwrittenAnnotation("Class records stay on this device.", status: .teacherOnly)
                }
            }

            ClassesStationeryCard(title: "Classes", tapeLabel: "Roster stack") {
                let summaries = viewModel.classSummaries
                if summaries.isEmpty {
                    ContentUnavailableView(
                        "No classes yet",
                        systemImage: "person.2",
                        description: Text("Add a class to group students and assignments.")
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(summaries) { summary in
                            NavigationLink {
                                ClassDetailRosterScreen(viewModel: viewModel, classSummary: summary)
                            } label: {
                                ClassRow(
                                    name: summary.name,
                                    subject: summary.subject,
                                    studentCount: summary.studentCount,
                                    assignmentCount: summary.assignmentCount,
                                    status: summary.studentCount == 0 ? .notStarted : .onTrack
                                )
                                .background(Color.white.opacity(0.34), in: RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .gradeDraftNativeGroupedList()
        .navigationTitle("Classes")
    }

    private var trimmedClassName: String {
        newClassName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addClass() {
        guard !trimmedClassName.isEmpty else { return }
        if viewModel.classSummaries.contains(where: { $0.name.caseInsensitiveCompare(trimmedClassName) == .orderedSame }) {
            viewModel.errorMessage = "A class with this name already exists locally."
            return
        }
        viewModel.saveClassGroup(ClassGroupRecord(name: trimmedClassName))
        newClassName = ""
    }
}

private struct ClassesStationeryCard<Content: View>: View {
    var title: String?
    var tapeLabel: String?
    var showsPaperclip: Bool
    private let content: Content

    init(title: String? = nil, tapeLabel: String? = nil, showsPaperclip: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.tapeLabel = tapeLabel
        self.showsPaperclip = showsPaperclip
        self.content = content()
    }

    var body: some View {
        NotebookCard(showsPerforation: true) {
            if title != nil || tapeLabel != nil || showsPaperclip {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        if let tapeLabel {
                            TapeLabel(tapeLabel)
                        }
                        Spacer(minLength: 8)
                        if showsPaperclip {
                            PaperclipDecoration()
                                .frame(width: 32, height: 44)
                        }
                    }
                    if let title {
                        Text(title)
                            .font(.system(.title3, design: .serif).weight(.semibold))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            content
        }
    }
}
