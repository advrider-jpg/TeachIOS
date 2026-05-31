import SwiftUI

struct HomeScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel

    var body: some View {
        List {
            Section {
                LocalCapabilityBanner(status: viewModel.localAIStatus, message: viewModel.statusMessage)
            } footer: {
                Text("GradeDraft stores student work and grading records locally on this device.")
            }

            Section {
                LabeledContent("Assignments", value: "\(viewModel.assignments.count)")
                GradeDraftStatusLabeledContent(title: GradeDraftWorkflowLanguage.reviewTextActionLabel, value: "\(viewModel.scannedTextReviewAssignments.count)", status: .reviewScannedText)
                GradeDraftStatusLabeledContent(title: "Final Review", value: "\(viewModel.finalReviewAssignments.count)", status: .reviewFinalGrade)
                GradeDraftStatusLabeledContent(title: "Ready to Export", value: "\(viewModel.readyToExportAssignments.count)", status: .readyToExport)
            }

            Section("Needs Attention") {
                let items = viewModel.homeAttentionItems
                if items.isEmpty {
                    ContentUnavailableView(
                        "Nothing needs attention",
                        systemImage: "checkmark.circle",
                        description: Text("Assignments that block review or export will appear here.")
                    )
                } else {
                    ForEach(items) { item in
                        NavigationLink {
                            item.destinationView(viewModel: viewModel)
                        } label: {
                            ReviewQueueRow(title: item.title, detail: item.detail, countText: item.countText, status: item.status, actionLabel: item.actionLabel)
                        }
                    }
                }
            }

            Section("Assignments Needing Action") {
                let rows = Array(viewModel.assignmentsNeedingAction.prefix(5))
                if rows.isEmpty {
                    ContentUnavailableView(
                        "No assignment action needed",
                        systemImage: "tray",
                        description: Text("Create an assignment or open Exports for approved work.")
                    )
                } else {
                    ForEach(rows) { assignment in
                        NavigationLink {
                            AssignmentOverviewScreen(viewModel: viewModel, assignmentID: assignment.id)
                        } label: {
                            AssignmentRow(assignment: assignment, status: viewModel.v6Status(for: assignment), actionLabel: viewModel.v6ActionLabel(for: assignment))
                        }
                    }
                }
            }

            Section {
                let records = viewModel.recentExportRows
                if records.isEmpty {
                    ContentUnavailableView(
                        "No exports yet",
                        systemImage: "square.and.arrow.up",
                        description: Text("Approved student reports and teacher-only records will appear here.")
                    )
                } else {
                    ForEach(records) { record in
                        HStack(spacing: 12) {
                            Image(systemName: record.kind.v6AudienceStatus.systemImage)
                                .foregroundStyle(record.kind.v6AudienceStatus.color)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.kind.v6DisplayName)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(record.assignmentTitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            StatusChip(record.kind.v6AudienceStatus, compact: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } header: {
                Text("Recent Exports & Backups")
            } footer: {
                Text("Files are created locally and shared only when you choose.")
            }
        }
        .gradeDraftNativeGroupedList()
        .navigationTitle("GradeDraft")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsAboutLocalPrivacyScreen(viewModel: viewModel)
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings, About, and Local Privacy")
            }
        }
    }
}
