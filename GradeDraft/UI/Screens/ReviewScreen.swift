import SwiftUI

struct ReviewScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    @State private var segment: ReviewSegment = .all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GradeDraftLayout.sectionSpacing) {
                TopLevelHeader(title: "Review", subtitle: "Teacher work queue for text checks, final grades, and rechecks.")

                Picker("Review queue", selection: $segment) {
                    ForEach(ReviewSegment.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                GroupedListCard(title: reviewTitle, subtitle: "Open a row to continue the required teacher review.") {
                    let items = viewModel.reviewItems(for: segment)
                    if items.isEmpty {
                        EmptyState(title: "No review items", message: "Assignments needing teacher review will appear here.", systemImage: "checklist")
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
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var reviewTitle: String {
        switch segment {
        case .all:
            return "All"
        case .scannedText:
            return "Scanned Text"
        case .finalReview:
            return "Final Review"
        case .needsRecheck:
            return "Needs Recheck"
        }
    }
}
