import SwiftUI

struct HomeScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel

    var body: some View {
        List {
            StationeryPageHeader(
                eyebrow: "Home",
                title: "Mark My Work",
                subtitle: "Local records, teacher-reviewed work, and export readiness at a glance."
            )

            HomeStationeryCard(tapeLabel: "Local first", showsPaperclip: true) {
                VStack(alignment: .leading, spacing: 12) {
                    LocalCapabilityBanner(status: viewModel.localAIStatus, message: viewModel.statusMessage)
                    HandwrittenAnnotation("Mark My Work stores student work and grading records locally on this device.", status: .teacherOnly)
                }
            }

            HomeStationeryCard(title: "Summary", tapeLabel: "Desk check") {
                MetricStrip(metrics: [
                    MetricStrip.Metric("Assignments", value: "\(viewModel.assignments.count)"),
                    MetricStrip.Metric(GradeDraftWorkflowLanguage.reviewTextActionLabel, value: "\(viewModel.scannedTextReviewAssignments.count)", status: .reviewScannedText),
                    MetricStrip.Metric("Final Review", value: "\(viewModel.finalReviewAssignments.count)", status: .reviewFinalGrade),
                    MetricStrip.Metric("Ready to Export", value: "\(viewModel.readyToExportAssignments.count)", status: .readyToExport)
                ])
            }

            HomeStationeryCard(title: "Needs Attention", tapeLabel: "Review queue", showsPaperclip: true) {
                let items = viewModel.homeAttentionItems
                if items.isEmpty {
                    ContentUnavailableView(
                        "Nothing needs attention",
                        systemImage: "checkmark.circle",
                        description: Text("Assignments that block review or export will appear here.")
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(items) { item in
                            NavigationLink {
                                item.destinationView(viewModel: viewModel)
                            } label: {
                                ReviewQueueRow(title: item.title, detail: item.detail, countText: item.countText, status: item.status, actionLabel: item.actionLabel)
                                    .background(Color.white.opacity(0.34), in: RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HomeStationeryCard(title: "Assignments Needing Action", tapeLabel: "Next five") {
                let rows = Array(viewModel.assignmentsNeedingAction.prefix(5))
                if rows.isEmpty {
                    ContentUnavailableView(
                        "No assignment action needed",
                        systemImage: "tray",
                        description: Text("Create an assignment or open Exports for approved work.")
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(rows) { assignment in
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

            HomeStationeryCard(title: "Recent Exports & Backups", tapeLabel: "Local files", showsPaperclip: true) {
                let records = viewModel.recentExportRows
                if records.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ContentUnavailableView(
                            "No exports yet",
                            systemImage: "square.and.arrow.up",
                            description: Text("Approved student reports and teacher-only records will appear here.")
                        )
                        HandwrittenAnnotation("Files are created locally and shared only when you choose.", status: .teacherOnly)
                    }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(records) { record in
                            HStack(spacing: 12) {
                                StatusIconBubble(record.kind.v6AudienceStatus)
                                    .frame(width: 32, height: 32)
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
                            .padding(.vertical, GradeDraftLayout.rowVerticalPadding)
                            .background(Color.white.opacity(0.34), in: RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous))
                            .accessibilityElement(children: .combine)
                        }
                        HandwrittenAnnotation("Files are created locally and shared only when you choose.", status: .teacherOnly)
                    }
                }
            }
        }
        .gradeDraftNativeGroupedList()
        .navigationTitle("Mark My Work")
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

private struct HomeStationeryCard<Content: View>: View {
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
