import SwiftUI
import UniformTypeIdentifiers

struct ClassDetailRosterScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var classSummary: ClassSummary
    @State private var newStudentName = ""
    @State private var newStudentLocalID = ""
    @State private var rosterCSV = ""
    @State private var showingRosterImporter = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Name", value: classSummary.name.isEmpty ? "Class" : classSummary.name)
                LabeledContent("Subject", value: classSummary.subject.nilIfBlank ?? "Not set")
                LabeledContent("Students", value: "\(students.count)")
                LabeledContent("Assignments", value: "\(assignments.count)")
                GradeDraftStatusLabeledContent(title: "Approved", value: "\(approvedCount)", status: .approved)
                GradeDraftStatusLabeledContent(title: "Missing Grades", value: "\(missingGradeCount)", status: missingGradeCount == 0 ? .onTrack : .needsAttention)
            }

            Section("Roster") {
                TextField("Student name", text: $newStudentName)
                    .submitLabel(.next)
                TextField("Local ID", text: $newStudentLocalID)
                    .submitLabel(.done)
                    .onSubmit(saveStudent)
                Button(action: saveStudent) {
                    Label("Add Student", systemImage: "person.badge.plus")
                }
                .disabled(newStudentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if students.isEmpty {
                    ContentUnavailableView(
                        "Roster not started",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Add student names or paste a roster CSV below.")
                    )
                } else {
                    ForEach(students) { student in
                        StudentRow(student: student, status: student.isActive ? .onTrack : .needsAttention, scoreText: scoreText(for: student))
                    }
                }
            }

            Section {
                Button {
                    showingRosterImporter = true
                } label: {
                    Label("Choose CSV", systemImage: "doc.badge.plus")
                }
                TextEditor(text: $rosterCSV)
                    .frame(minHeight: 110)
                    .accessibilityLabel("Pasted roster CSV")
                Button {
                    _ = viewModel.previewRosterCSV(rosterCSV, className: classSummary.name)
                } label: {
                    Label("Preview Import", systemImage: "list.bullet.rectangle")
                }
                .disabled(rosterCSV.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button {
                    viewModel.createAssignmentsFromRosterCSV(rosterCSV, className: classSummary.name)
                } label: {
                    Label("Create Assignments", systemImage: "doc.badge.plus")
                }
                .disabled(rosterCSV.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: {
                Text("Import Roster CSV")
            } footer: {
                Text("Review new students, duplicates, and rejected rows before creating assignment records.")
            }

            if let preview = viewModel.latestRosterPreview {
                Section("Preview Import") {
                    GradeDraftStatusLabeledContent(title: "New Students", value: "\(preview.students.count)", status: preview.rejectedRowDetails.isEmpty ? .onTrack : .needsAttention)
                    LabeledContent("Header Row", value: preview.hasHeaderRow ? "Detected" : "Not detected")
                    if !preview.duplicateNames.isEmpty {
                        BlockingIssueRow(title: "Duplicates", detail: preview.duplicateNames.joined(separator: ", "), status: .needsAttention)
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
                            }
                        }
                    }
                }
            }

            Section("Assignments in Class") {
                if assignments.isEmpty {
                    ContentUnavailableView(
                        "No saved assignments",
                        systemImage: "doc.text",
                        description: Text("Create assignments from roster or add an assignment from the Assignments tab.")
                    )
                } else {
                    ForEach(assignments) { assignment in
                        NavigationLink {
                            AssignmentOverviewScreen(viewModel: viewModel, assignmentID: assignment.id)
                        } label: {
                            AssignmentRow(assignment: assignment, status: viewModel.v6Status(for: assignment), actionLabel: viewModel.v6ActionLabel(for: assignment))
                        }
                    }
                }
            }
        }
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

    private func scoreText(for student: StudentRecord) -> String? {
        guard let record = assignments.first(where: { $0.studentDisplayName.caseInsensitiveCompare(student.displayName) == .orderedSame }),
              let review = record.finalReview,
              review.status == .approved else { return nil }
        return "\(GradeTotals.formatted(review.totalScore)) / \(GradeTotals.formatted(review.maxScore))"
    }

    private func saveStudent() {
        let trimmedName = newStudentName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        viewModel.saveStudent(StudentRecord(displayName: trimmedName, className: classSummary.name, localIdentifier: newStudentLocalID.trimmingCharacters(in: .whitespacesAndNewlines)))
        newStudentName = ""
        newStudentLocalID = ""
    }

    private func importRosterCSV(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        do {
            rosterCSV = try String(contentsOf: url, encoding: .utf8)
            _ = viewModel.previewRosterCSV(rosterCSV, className: classSummary.name)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}
