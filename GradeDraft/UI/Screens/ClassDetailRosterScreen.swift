import SwiftUI
import UniformTypeIdentifiers

struct ClassDetailRosterScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var classSummary: ClassSummary
    @State private var newStudentName = ""
    @State private var newStudentLocalID = ""
    @State private var rosterCSV = ""
    @State private var showingRosterImporter = false
    @State private var reviewedRosterCSV: String?

    var body: some View {
        Form {
            StationeryPageHeader(
                eyebrow: "Roster",
                title: classSummary.name.isEmpty ? "Class" : classSummary.name,
                subtitle: "Roster records, import review, and local assignment progress."
            )

            RosterStationeryCard(title: "Class Summary", tapeLabel: "Roster cover", showsPaperclip: true) {
                VStack(spacing: 10) {
                    RosterMetricRow(title: "Name", value: classSummary.name.isEmpty ? "Class" : classSummary.name, status: nil)
                    RosterMetricRow(title: "Subject", value: classSummary.subject.nilIfBlank ?? "Not set", status: nil)
                    RosterMetricRow(title: "Students", value: "\(students.count)", status: nil)
                    RosterMetricRow(title: "Assignments", value: "\(assignments.count)", status: nil)
                    RosterMetricRow(title: "Approved", value: "\(approvedCount)", status: .approved)
                    RosterMetricRow(title: "Missing Grades", value: "\(missingGradeCount)", status: missingGradeCount == 0 ? .onTrack : .needsAttention)
                }
            }

            RosterStationeryCard(title: "Roster", tapeLabel: "Student list") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Student name", text: $newStudentName)
                        .submitLabel(.next)
                    TextField("Local ID", text: $newStudentLocalID)
                        .submitLabel(.done)
                        .onSubmit(saveStudent)
                    Button(action: saveStudent) {
                        Label("Add Student", systemImage: "person.badge.plus")
                            .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newStudentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if students.isEmpty {
                        ContentUnavailableView(
                            "Roster not started",
                            systemImage: "person.crop.circle.badge.plus",
                            description: Text("Add student names or paste a roster CSV below.")
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(students) { student in
                                StudentRow(student: student, status: student.isActive ? .onTrack : .needsAttention, scoreText: scoreText(for: student))
                                    .background(Color.white.opacity(0.34), in: RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous))
                            }
                        }
                    }
                }
            }

            RosterStationeryCard(title: "Import Roster CSV", tapeLabel: "Review before create", showsPaperclip: true) {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        showingRosterImporter = true
                    } label: {
                        Label("Choose CSV", systemImage: "doc.badge.plus")
                            .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)

                    TextEditor(text: $rosterCSV)
                        .frame(minHeight: 110)
                        .accessibilityLabel("Pasted roster CSV")
                        .onChange(of: rosterCSV) { _, _ in reviewedRosterCSV = nil }

                    HStack(spacing: 12) {
                        Button {
                            previewRosterCSV()
                        } label: {
                            Label("Preview Import", systemImage: "list.bullet.rectangle")
                                .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(rosterCSV.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button {
                            createAssignmentsFromReviewedRoster()
                        } label: {
                            Label("Create Assignments", systemImage: "doc.badge.plus")
                                .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!rosterPreviewReadyForCreate)
                    }

                    if !rosterPreviewReadyForCreate && !rosterCSV.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HandwrittenAnnotation("Preview the current roster CSV before creating local assignment records.", status: .needsAttention)
                    }

                    HandwrittenAnnotation("Review new students, duplicates, and rejected rows before creating assignment records.", status: .teacherOnly)
                }
            }

            if let preview = viewModel.latestRosterPreview {
                RosterStationeryCard(title: "Preview Import", tapeLabel: "Checked rows") {
                    VStack(alignment: .leading, spacing: 12) {
                        RosterMetricRow(title: "New Students", value: "\(preview.students.count)", status: preview.rejectedRowDetails.isEmpty ? .onTrack : .needsAttention)
                        RosterMetricRow(title: "Header Row", value: preview.hasHeaderRow ? "Detected" : "Not detected", status: nil)
                        if !preview.duplicateNames.isEmpty {
                            BlockingIssueRow(title: "Duplicates", detail: preview.duplicateNames.joined(separator: ", "), status: .needsAttention)
                                .background(Color.white.opacity(0.34), in: RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous))
                        }
                        if !preview.warnings.isEmpty {
                            DisclosureGroup("Warnings") {
                                ForEach(preview.warnings, id: \.self) { warning in
                                    Text(warning)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if !preview.rejectedRowDetails.isEmpty {
                            DisclosureGroup("Rejected Rows") {
                                ForEach(preview.rejectedRowDetails) { rejected in
                                    BlockingIssueRow(title: "Row \(rejected.rowNumber)", detail: rejected.reason, status: .fixBeforeContinuing)
                                        .background(Color.white.opacity(0.34), in: RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous))
                                }
                            }
                        }
                    }
                }
            }

            RosterStationeryCard(title: "Assignments in Class", tapeLabel: "Grade sheets") {
                if assignments.isEmpty {
                    ContentUnavailableView(
                        "No saved assignments",
                        systemImage: "doc.text",
                        description: Text("Create assignments from roster or add an assignment from the Assignments tab.")
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(assignments) { assignment in
                            NavigationLink {
                                AssignmentOverviewScreen(viewModel: viewModel, assignmentID: assignment.id)
                            } label: {
                                AssignmentRow(assignment: assignment, status: viewModel.v6Status(for: assignment), actionLabel: viewModel.v6ActionLabel(for: assignment))
                                    .background(Color.white.opacity(0.34), in: RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .stationeryScreen()
        .navigationTitle(classSummary.name.isEmpty ? "Class" : classSummary.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fileImporter(isPresented: $showingRosterImporter, allowedContentTypes: [.commaSeparatedText, .plainText, .item]) { result in
            switch result {
            case .success(let url):
                importRosterCSV(from: url)
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private var students: [StudentRecord] {
        viewModel.students.filter { student in
            student.className.caseInsensitiveCompare(classSummary.name) == .orderedSame || student.className.isEmpty && classSummary.name.isEmpty
        }.sorted { $0.displayName < $1.displayName }
    }

    private var assignments: [AssignmentRecord] {
        viewModel.assignments.filter { $0.className.caseInsensitiveCompare(classSummary.name) == .orderedSame }
    }

    private var approvedCount: Int {
        assignments.filter { $0.finalReview?.status == .approved && !$0.finalReviewIsStale }.count
    }

    private var missingGradeCount: Int {
        max(assignments.count - approvedCount, 0)
    }

    private var rosterPreviewReadyForCreate: Bool {
        reviewedRosterCSV == rosterCSV && viewModel.latestRosterPreview?.students.isEmpty == false
    }

    private func scoreText(for student: StudentRecord) -> String? {
        guard let record = assignments.first(where: { $0.studentDisplayName.caseInsensitiveCompare(student.displayName) == .orderedSame }),
              let review = record.finalReview,
              review.status == .approved else { return nil }
        return "\(GradeTotals.formatted(review.totalScore)) / \(GradeTotals.formatted(review.maxScore))"
    }

    private func saveStudent() {
        let trimmedName = newStudentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocalID = newStudentLocalID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        if students.contains(where: { student in
            student.displayName.caseInsensitiveCompare(trimmedName) == .orderedSame ||
            (!trimmedLocalID.isEmpty && student.localIdentifier.caseInsensitiveCompare(trimmedLocalID) == .orderedSame)
        }) {
            viewModel.errorMessage = "A matching student already exists in this class. Edit the existing roster record instead of creating a duplicate."
            return
        }
        viewModel.saveStudent(StudentRecord(displayName: trimmedName, className: classSummary.name, localIdentifier: trimmedLocalID))
        newStudentName = ""
        newStudentLocalID = ""
    }

    private func previewRosterCSV() {
        _ = viewModel.previewRosterCSV(rosterCSV, className: classSummary.name)
        reviewedRosterCSV = rosterCSV
    }

    private func createAssignmentsFromReviewedRoster() {
        guard rosterPreviewReadyForCreate else {
            viewModel.errorMessage = "Preview the current roster CSV before creating assignment records."
            return
        }
        viewModel.createAssignmentsFromRosterCSV(rosterCSV, className: classSummary.name)
        reviewedRosterCSV = nil
    }

    private func importRosterCSV(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        do {
            rosterCSV = try String(contentsOf: url, encoding: .utf8)
            previewRosterCSV()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

private struct RosterMetricRow: View {
    var title: String
    var value: String
    var status: GradeDraftUIStatus?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            Text(value)
                .font(.headline)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if let status {
                StatusChip(status, compact: true)
            }
        }
        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
        .padding(.vertical, 8)
        .frame(minHeight: GradeDraftLayout.minimumTapTarget)
        .background(Color.white.opacity(0.34), in: RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct RosterStationeryCard<Content: View>: View {
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
