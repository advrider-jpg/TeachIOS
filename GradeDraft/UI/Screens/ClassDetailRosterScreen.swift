import SwiftUI

struct ClassDetailRosterScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var classSummary: ClassSummary
    @State private var newStudentName = ""
    @State private var newStudentLocalID = ""
    @State private var rosterCSV = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GradeDraftLayout.deepSectionSpacing) {
                DeepWorkflowHeader(
                    title: classSummary.name,
                    subtitle: "Roster, import preview, and assignments in this class.",
                    status: classSummary.studentCount == 0 ? .notStarted : .onTrack
                )

                MetricStrip(metrics: [
                    .init("Students", value: "\(students.count)"),
                    .init("Assignments", value: "\(assignments.count)"),
                    .init("Approved", value: "\(approvedCount)", status: .approved),
                    .init("Missing grades", value: "\(missingGradeCount)", status: missingGradeCount == 0 ? .onTrack : .needsAttention)
                ])
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                GroupedListCard(title: "Roster", subtitle: "Add student records or import a local CSV.") {
                    HStack(spacing: 8) {
                        TextField("Student name", text: $newStudentName)
                            .textFieldStyle(.roundedBorder)
                        TextField("Local ID", text: $newStudentLocalID)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 110)
                        SecondaryActionButton(title: "Add student", systemImage: "plus", action: saveStudent, disabled: newStudentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .frame(maxWidth: 142)
                    }
                    .padding(GradeDraftLayout.rowHorizontalPadding)

                    if students.isEmpty {
                        EmptyState(title: "Roster not started", message: "Add student names or paste a roster CSV below.", systemImage: "person.crop.circle.badge.plus")
                    } else {
                        ForEach(students) { student in
                            StudentRow(student: student, status: student.isActive ? .onTrack : .needsAttention, scoreText: scoreText(for: student))
                            if student.id != students.last?.id { Divider().padding(.leading, 56) }
                        }
                    }
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                GroupedListCard(title: "Preview import", subtitle: "Review new students, duplicates, and rejected rows before creating assignment records.") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextEditor(text: $rosterCSV)
                            .frame(minHeight: 90)
                            .padding(8)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        HStack(spacing: 8) {
                            SecondaryActionButton(title: "Preview import", systemImage: "list.bullet.rectangle", action: { _ = viewModel.previewRosterCSV(rosterCSV, className: classSummary.name) }, disabled: rosterCSV.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            PrimaryActionButton(title: "Create Assignments", systemImage: "doc.badge.plus", action: { viewModel.createAssignmentsFromRosterCSV(rosterCSV, className: classSummary.name) }, disabled: rosterCSV.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(GradeDraftLayout.rowHorizontalPadding)

                    if let preview = viewModel.latestRosterPreview {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                StatusChip(preview.rejectedRowDetails.isEmpty ? .onTrack : .needsAttention)
                                Text("\(preview.students.count) new students")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            if !preview.duplicateNames.isEmpty {
                                BlockingIssueRow(title: "Duplicates", detail: preview.duplicateNames.joined(separator: ", "), status: .needsAttention)
                            }
                            ForEach(preview.rejectedRowDetails) { rejected in
                                BlockingIssueRow(title: "Rejected rows", detail: "Row \(rejected.rowNumber): \(rejected.reason)", status: .fixBeforeContinuing)
                            }
                            ForEach(preview.warnings, id: \.self) { warning in
                                BlockingIssueRow(title: "Needs attention", detail: warning, status: .needsAttention)
                            }
                        }
                        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
                        .padding(.bottom, 10)
                    }
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                GroupedListCard(title: "Assignments in class", subtitle: "Open an assignment to add work, review text, or approve the final grade.") {
                    if assignments.isEmpty {
                        EmptyState(title: "No saved assignments", message: "Create assignments from roster or add an assignment from the Assignments tab.", systemImage: "doc.text")
                    } else {
                        ForEach(assignments) { assignment in
                            NavigationLink {
                                AssignmentOverviewScreen(viewModel: viewModel, assignmentID: assignment.id)
                            } label: {
                                AssignmentRow(assignment: assignment, status: viewModel.v6Status(for: assignment), actionLabel: viewModel.v6ActionLabel(for: assignment))
                            }
                            .buttonStyle(.plain)
                            if assignment.id != assignments.last?.id { Divider().padding(.leading, 56) }
                        }
                    }
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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
        viewModel.saveStudent(StudentRecord(displayName: newStudentName, className: classSummary.name, localIdentifier: newStudentLocalID))
        newStudentName = ""
        newStudentLocalID = ""
    }
}
