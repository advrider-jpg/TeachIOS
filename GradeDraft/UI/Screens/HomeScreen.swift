import SwiftUI

extension RosterStatus {
    /// Waiting on the teacher: scanned text to check, work ready to review, a final review to finish or recheck.
    var needsTeacherReview: Bool {
        switch self {
        case .ocrReviewNeeded, .readyForGrading, .finalReviewInProgress, .needsRecheck: return true
        case .notStarted, .draftGenerated, .approved, .exported: return false
        }
    }

    var hasDraftReady: Bool { self == .draftGenerated }
}

/// One submission as a list row: the student, optionally the assignment and class, and the status.
struct SubmissionSummaryRow: View {
    var summary: SubmissionSummary
    var showsAssignment = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.studentName)
                .font(.headline)
            if showsAssignment {
                Text("\(summary.assignmentTitle) · \(summary.className)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            StatusLabel(summary.rosterStatus.uiStatus, subject: "Grading status")
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
    }
}

struct HomeScreen: View {
    @Environment(AppModel.self) private var appModel

    private var needsReview: [SubmissionSummary] {
        appModel.submissionSummaries.filter { $0.rosterStatus.needsTeacherReview }
    }

    private var draftsReady: [SubmissionSummary] {
        appModel.submissionSummaries.filter { $0.rosterStatus.hasDraftReady }
    }

    private var recentlyExported: [SubmissionSummary] {
        let exported = appModel.submissionSummaries
            .filter { $0.rosterStatus == .exported }
            .sorted { ($0.lastExportedAt ?? .distantPast) > ($1.lastExportedAt ?? .distantPast) }
        return Array(exported.prefix(10))
    }

    var body: some View {
        List {
            Section {
                aiStatus
            } header: {
                Text("On-Device AI")
            } footer: {
                Text("MarkForMe stores student work and grading records locally on this device.")
            }

            if appModel.listsLoaded && needsReview.isEmpty && draftsReady.isEmpty && recentlyExported.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Nothing needs your review",
                        systemImage: "checkmark.circle",
                        description: Text("Create an assignment or open Exports for approved work.")
                    )
                    .listRowBackground(Color.clear)
                }
            }

            submissionSection("Needs your review", key: "needsReview", items: needsReview)
            submissionSection("Drafts ready", key: "draftsReady", items: draftsReady)
            submissionSection("Recently exported", key: "recentlyExported", items: recentlyExported)
        }
        .navigationTitle("MarkForMe")
    }

    @ViewBuilder
    private var aiStatus: some View {
        Group {
            switch appModel.services.grading.localAIStatus {
            case .available:
                Label {
                    Text("Foundation Models is available on this device for local draft assistance.")
                } icon: {
                    Image(systemName: "checkmark.circle").foregroundStyle(.green)
                }
            case .unavailable(let detail):
                Label {
                    Text(ReadinessIssue.localAIUnavailable(detail).message)
                } icon: {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                }
                Text("Manual final review remains available. Student work is not sent to cloud AI as a fallback.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("home.aiStatus")
    }

    @ViewBuilder
    private func submissionSection(_ title: String, key: String, items: [SubmissionSummary]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { item in
                    NavigationLink(value: Route.submission(item.id)) {
                        SubmissionSummaryRow(summary: item)
                    }
                    .accessibilityIdentifier("home.\(key).\(item.id.uuidString)")
                }
            }
        }
    }
}

#if DEBUG
private struct HomeScreenPreview: View {
    @State private var model = PreviewFixtures.makeAppModel()

    var body: some View {
        NavigationStack {
            HomeScreen()
                .navigationDestination(for: Route.self) { RouteDestination(route: $0, app: model) }
        }
        .environment(model)
        .task { await model.observeLists() }
    }
}

#Preview("Light") {
    HomeScreenPreview()
}

#Preview("Dark") {
    HomeScreenPreview()
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    HomeScreenPreview()
        .dynamicTypeSize(.accessibility3)
}
#endif
