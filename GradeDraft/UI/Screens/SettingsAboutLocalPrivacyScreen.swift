import SwiftUI

struct SettingsAboutLocalPrivacyScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GradeDraftLayout.deepSectionSpacing) {
                DeepWorkflowHeader(
                    title: "Settings / About / Local Privacy",
                    subtitle: "Local storage, backups, teacher-only records, and device processing.",
                    status: .teacherOnly
                )

                GroupedListCard(title: "Local Privacy", subtitle: "GradeDraft is local-first and offline-first.") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("GradeDraft stores and processes student work, grading records, rubrics, teacher notes, and feedback locally on your device. The developer does not receive, upload, or access this information in the core app workflow.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Label("No cloud text recognition in the core workflow.", systemImage: "checkmark.circle")
                        Label("No cloud AI grading in the core workflow.", systemImage: "checkmark.circle")
                        Label("No usage tracking in this repo.", systemImage: "checkmark.circle")
                        Label("No account or login required.", systemImage: "checkmark.circle")
                        Label("Teacher finalizes all grades.", systemImage: "person.badge.checkmark")
                    }
                    .font(.subheadline)
                    .padding(GradeDraftLayout.rowHorizontalPadding)
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                GroupedListCard(title: "Local storage", subtitle: "Persistence details for teacher awareness.") {
                    BlockingIssueRow(title: "Local only", detail: viewModel.persistenceSummary, status: .teacherOnly)
                    BlockingIssueRow(title: "Exports", detail: "Exports may contain sensitive student information. Review the confirmation sheet before creating a file.", status: .needsAttention)
                    BlockingIssueRow(title: "Backups", detail: "Full backups include all GradeDraft data stored on this device. Store securely.", status: .teacherOnly)
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
