import SwiftUI

struct HomeScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GradeDraftLayout.sectionSpacing) {
                TopLevelHeader(title: "Home", subtitle: "Daily teacher actions for local grading.") {
                    NavigationLink {
                        SettingsAboutLocalPrivacyScreen(viewModel: viewModel)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Settings, About, and Local Privacy")
                }

                MetricStrip(metrics: [
                    .init("Assignments", value: "\(viewModel.assignments.count)"),
                    .init(GradeDraftWorkflowLanguage.reviewTextActionLabel, value: "\(viewModel.scannedTextReviewAssignments.count)", status: .reviewScannedText),
                    .init("Final Review", value: "\(viewModel.finalReviewAssignments.count)", status: .reviewFinalGrade),
                    .init("Ready Export", value: "\(viewModel.readyToExportAssignments.count)", status: .readyToExport)
                ])
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                GroupedListCard(title: "Needs attention", subtitle: "Start with items that block or delay teacher review.") {
                    let items = viewModel.homeAttentionItems
                    if items.isEmpty {
                        EmptyState(title: "Nothing needs attention", message: "Assignments with reviewed work and approved final grades will appear as ready to export.", systemImage: "checkmark.circle")
                    } else {
                        ForEach(items) { item in
                            NavigationLink {
                                item.destinationView(viewModel: viewModel)
                            } label: {
                                ReviewQueueRow(title: item.title, detail: item.detail, countText: item.countText, status: item.status, actionLabel: item.actionLabel)
                            }
                            .buttonStyle(.plain)
                            if item.id != items.last?.id { Divider().padding(.leading, 56) }
                        }
                    }
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                GroupedListCard(title: "Assignments needing action", subtitle: "Status and next action stay paired.") {
                    let rows = viewModel.assignmentsNeedingAction.prefix(5).map { $0 }
                    if rows.isEmpty {
                        EmptyState(title: "No assignment action needed", message: "Create an assignment or open Exports for approved work.", systemImage: "tray")
                    } else {
                        ForEach(rows) { assignment in
                            NavigationLink {
                                AssignmentOverviewScreen(viewModel: viewModel, assignmentID: assignment.id)
                            } label: {
                                AssignmentRow(assignment: assignment, status: viewModel.v6Status(for: assignment), actionLabel: viewModel.v6ActionLabel(for: assignment))
                            }
                            .buttonStyle(.plain)
                            if assignment.id != rows.last?.id { Divider().padding(.leading, 56) }
                        }
                    }
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                GroupedListCard(title: "Recent exports & backups", subtitle: "Files are created locally and shared only when you choose.") {
                    let records = viewModel.recentExportRows
                    if records.isEmpty {
                        EmptyState(title: "No exports yet", message: "Approved student reports and teacher-only records will appear here.", systemImage: "square.and.arrow.up")
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
                            .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
                            .padding(.vertical, 10)
                            .frame(minHeight: 60)
                            if record.id != records.last?.id { Divider().padding(.leading, 56) }
                        }
                    }
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}
