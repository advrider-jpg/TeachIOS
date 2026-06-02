import SwiftUI

struct ReviewScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                ReviewQueuePaperHeader(
                    title: "Review Queue",
                    note: reviewQueueNote,
                    metrics: reviewMetrics
                )
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if textNeedsReview.isEmpty && finalReview.isEmpty && needsRecheck.isEmpty && readyToExport.isEmpty {
                Section {
                    ReviewPaperUnavailableCard(
                        title: emptyStateTitle,
                        systemImage: "checklist.checked",
                        description: emptyStateDescription
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            if !textNeedsReview.isEmpty {
                reviewSection("Text Needs Review", items: textNeedsReview)
            }
            if !finalReview.isEmpty {
                reviewSection("Final Review", items: finalReview)
            }
            if !needsRecheck.isEmpty {
                reviewSection("Needs Recheck", items: needsRecheck)
            }
            if !readyToExport.isEmpty {
                Section("Ready to Export") {
                    ForEach(readyToExport) { assignment in
                        NavigationLink {
                            ExportsRestoreScreen(viewModel: viewModel, assignmentID: assignment.id)
                                .toolbar(.hidden, for: .tabBar)
                        } label: {
                            ReviewNotebookAssignmentRow(
                                assignment: assignment,
                                status: viewModel.v6Status(for: assignment),
                                actionLabel: viewModel.v6ActionLabel(for: assignment)
                            )
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .gradeDraftNativeGroupedList()
        .scrollContentBackground(.hidden)
        .background(ReviewPaperStyle.background.ignoresSafeArea())
        .navigationTitle("Review")
        .searchable(text: $searchText, prompt: "Search review queue")
    }

    @ViewBuilder
    private func reviewSection(_ title: String, items: [ReviewNavigationItem]) -> some View {
        Section {
            ForEach(items) { item in
                NavigationLink {
                    item.destinationView(viewModel: viewModel)
                } label: {
                    ReviewNotebookQueueRow(item: item)
                }
            }
            .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } header: {
            ReviewTapeSectionHeader(title: title)
        }
    }

    private var textNeedsReview: [ReviewNavigationItem] {
        filtered(viewModel.reviewItems(for: .scannedText))
    }

    private var finalReview: [ReviewNavigationItem] {
        filtered(viewModel.reviewItems(for: .finalReview))
    }

    private var needsRecheck: [ReviewNavigationItem] {
        filtered(viewModel.reviewItems(for: .needsRecheck))
    }

    private var readyToExport: [AssignmentRecord] {
        let rows = viewModel.readyToExportAssignments
        let query = normalizedSearchText
        guard !query.isEmpty else { return rows }
        return rows.filter { assignment in
            [assignment.title, assignment.studentDisplayName, assignment.className, assignment.subject, viewModel.v6Status(for: assignment).rawValue]
                .contains { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    private func filtered(_ items: [ReviewNavigationItem]) -> [ReviewNavigationItem] {
        let query = normalizedSearchText
        guard !query.isEmpty else { return items }
        return items.filter { item in
            [item.title, item.detail, item.countText ?? "", item.status.rawValue, item.actionLabel]
                .contains { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emptyStateTitle: String {
        normalizedSearchText.isEmpty ? "No reviews pending" : "No matching reviews"
    }

    private var emptyStateDescription: String {
        normalizedSearchText.isEmpty
            ? "Assignments needing teacher review will appear here."
            : "No review rows match this search."
    }

    private var reviewQueueNote: String {
        if normalizedSearchText.isEmpty {
            return "Teacher checks stay separate: text review, final review, recheck, then export readiness."
        }
        return "Showing review rows that match your search."
    }

    private var reviewMetrics: [ReviewQueuePaperHeader.Metric] {
        [
            ReviewQueuePaperHeader.Metric(label: "Text", value: "\(textNeedsReview.count)", status: .reviewScannedText),
            ReviewQueuePaperHeader.Metric(label: "Final", value: "\(finalReview.count)", status: .reviewFinalGrade),
            ReviewQueuePaperHeader.Metric(label: "Recheck", value: "\(needsRecheck.count)", status: .needsRecheck),
            ReviewQueuePaperHeader.Metric(label: "Export", value: "\(readyToExport.count)", status: .readyToExport)
        ]
    }
}

private enum ReviewPaperStyle {
    static let background = Color(red: 0.98, green: 0.95, blue: 0.88)
    static let paper = Color(red: 1.0, green: 0.985, blue: 0.94)
    static let ink = Color(red: 0.24, green: 0.18, blue: 0.13)
    static let rule = Color(red: 0.74, green: 0.52, blue: 0.30)
    static let tape = Color(red: 0.96, green: 0.84, blue: 0.55)
    static let shadow = Color.black.opacity(0.09)
}

private struct ReviewQueuePaperHeader: View {
    struct Metric: Identifiable {
        var id: String { label }
        var label: String
        var value: String
        var status: GradeDraftUIStatus
    }

    var title: String
    var note: String
    var metrics: [Metric]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(.largeTitle, design: .serif).weight(.semibold))
                        .foregroundStyle(ReviewPaperStyle.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(note)
                        .font(.system(.subheadline, design: .serif).italic())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "paperclip")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ReviewPaperStyle.rule)
                    .rotationEffect(.degrees(12))
                    .accessibilityHidden(true)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(metrics) { metric in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(metric.value)
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .foregroundStyle(metric.status.color)
                        Text(metric.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(metric.status.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(metric.status.color.opacity(0.20), lineWidth: 1)
                    )
                }
            }
        }
        .padding(18)
        .background(ReviewPaperStyle.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topLeading) {
            ReviewTapeLabel(text: "review notes")
                .offset(x: 18, y: -11)
        }
        .overlay(alignment: .leading) {
            ReviewPerforation()
                .offset(x: 7)
        }
        .shadow(color: ReviewPaperStyle.shadow, radius: 12, x: 0, y: 6)
    }
}

private struct ReviewNotebookQueueRow: View {
    var item: ReviewNavigationItem

    var body: some View {
        ReviewNotebookCard(status: item.status) {
            ReviewQueueRow(
                title: item.title,
                detail: item.detail,
                countText: item.countText,
                status: item.status,
                actionLabel: item.actionLabel
            )
        }
    }
}

private struct ReviewNotebookAssignmentRow: View {
    var assignment: AssignmentRecord
    var status: GradeDraftUIStatus
    var actionLabel: String

    var body: some View {
        ReviewNotebookCard(status: status) {
            AssignmentRow(assignment: assignment, status: status, actionLabel: actionLabel)
        }
    }
}

private struct ReviewNotebookCard<Content: View>: View {
    var status: GradeDraftUIStatus
    let content: Content

    init(status: GradeDraftUIStatus, @ViewBuilder content: () -> Content) {
        self.status = status
        self.content = content()
    }

    var body: some View {
        content
            .background(ReviewPaperStyle.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(status.color.opacity(0.28), lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                ReviewPerforation()
                    .offset(x: 6)
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "paperclip")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ReviewPaperStyle.rule)
                    .rotationEffect(.degrees(-10))
                    .padding(.top, 8)
                    .padding(.trailing, 12)
                    .accessibilityHidden(true)
            }
            .shadow(color: ReviewPaperStyle.shadow, radius: 6, x: 0, y: 3)
    }
}

private struct ReviewTapeSectionHeader: View {
    var title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(ReviewPaperStyle.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(ReviewPaperStyle.tape.opacity(0.90), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(ReviewPaperStyle.rule.opacity(0.22), lineWidth: 1)
            )
            .padding(.top, 6)
            .textCase(nil)
    }
}

private struct ReviewTapeLabel: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(ReviewPaperStyle.ink.opacity(0.78))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(ReviewPaperStyle.tape.opacity(0.92), in: Capsule())
            .rotationEffect(.degrees(-2))
            .accessibilityHidden(true)
    }
}

private struct ReviewPerforation: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { _ in
                Circle()
                    .fill(ReviewPaperStyle.background)
                    .frame(width: 5, height: 5)
                    .overlay(Circle().stroke(ReviewPaperStyle.rule.opacity(0.18), lineWidth: 0.5))
            }
        }
        .padding(.vertical, 8)
        .accessibilityHidden(true)
    }
}

private struct ReviewPaperUnavailableCard: View {
    var title: String
    var systemImage: String
    var description: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(ReviewPaperStyle.rule)
            Text(title)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(ReviewPaperStyle.ink)
            Text(description)
                .font(.system(.subheadline, design: .serif).italic())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(ReviewPaperStyle.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ReviewPaperStyle.rule.opacity(0.20), lineWidth: 1)
        )
    }
}
