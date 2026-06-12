import SwiftUI

enum GradeDraftTab: String, CaseIterable, Hashable, Identifiable {
    case home
    case classes
    case assignments
    case review
    case exports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .classes:
            return "Classes"
        case .assignments:
            return "Assignments"
        case .review:
            return "Review"
        case .exports:
            return "Exports"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house"
        case .classes:
            return "person.2"
        case .assignments:
            return "doc.text"
        case .review:
            return "checklist"
        case .exports:
            return "square.and.arrow.up"
        }
    }
}

struct AppTabShell: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var viewModel: GradeDraftViewModel
    @State private var selectedTab: GradeDraftTab = .home
    @State private var launchRoute: AppLaunchRoute?

    var body: some View {
        rootShell
        .task { viewModel.refreshCapabilityStatus() }
        .task { consumePendingLaunchRequest() }
        .alert("MarkForMe", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }

    @ViewBuilder
    private var rootShell: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                List {
                    ForEach(GradeDraftTab.allCases) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Label(tab.title, systemImage: tab.systemImage)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
                        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                    }
                }
                .navigationTitle("MarkForMe")
            } detail: {
                NavigationStack {
                    selectedRootScreen
                }
                .navigationDestination(item: $launchRoute) { route in
                    launchRouteDestination(route)
                }
            }
        } else {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeScreen(viewModel: viewModel)
                }
                .navigationDestination(item: $launchRoute) { route in
                    launchRouteDestination(route)
                }
                .tabItem { Label(GradeDraftTab.home.title, systemImage: GradeDraftTab.home.systemImage) }
                .tag(GradeDraftTab.home)

                NavigationStack {
                    ClassesScreen(viewModel: viewModel)
                }
                .navigationDestination(item: $launchRoute) { route in
                    launchRouteDestination(route)
                }
                .tabItem { Label(GradeDraftTab.classes.title, systemImage: GradeDraftTab.classes.systemImage) }
                .tag(GradeDraftTab.classes)

                NavigationStack {
                    AssignmentsScreen(viewModel: viewModel)
                }
                .navigationDestination(item: $launchRoute) { route in
                    launchRouteDestination(route)
                }
                .tabItem { Label(GradeDraftTab.assignments.title, systemImage: GradeDraftTab.assignments.systemImage) }
                .tag(GradeDraftTab.assignments)

                NavigationStack {
                    ReviewScreen(viewModel: viewModel)
                }
                .navigationDestination(item: $launchRoute) { route in
                    launchRouteDestination(route)
                }
                .tabItem { Label(GradeDraftTab.review.title, systemImage: GradeDraftTab.review.systemImage) }
                .tag(GradeDraftTab.review)

                NavigationStack {
                    ExportsRestoreScreen(viewModel: viewModel)
                }
                .navigationDestination(item: $launchRoute) { route in
                    launchRouteDestination(route)
                }
                .tabItem { Label(GradeDraftTab.exports.title, systemImage: GradeDraftTab.exports.systemImage) }
                .tag(GradeDraftTab.exports)
            }
        }
    }

    @ViewBuilder
    private var selectedRootScreen: some View {
        switch selectedTab {
        case .home:
            HomeScreen(viewModel: viewModel)
        case .classes:
            ClassesScreen(viewModel: viewModel)
        case .assignments:
            AssignmentsScreen(viewModel: viewModel)
        case .review:
            ReviewScreen(viewModel: viewModel)
        case .exports:
            ExportsRestoreScreen(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func launchRouteDestination(_ route: AppLaunchRoute) -> some View {
        switch route {
        case .assignmentOverview(let id):
            AssignmentOverviewScreen(viewModel: viewModel, assignmentID: id)
        case .aiReadiness(let id):
            AIReadinessScreen(viewModel: viewModel, assignmentID: id)
        case .finalReview(let id):
            FinalReviewScreen(viewModel: viewModel, assignmentID: id)
        case .packetPreview(let id):
            AIPacketPreviewScreen(viewModel: viewModel, assignmentID: id)
        case .ocrReview(let id):
            ReviewScannedTextScreen(viewModel: viewModel, assignmentID: id)
        case .curriculum(let id):
            CurriculumBrowserScreen(viewModel: viewModel, assignmentID: id)
        case .studentWork(let id):
            StudentWorkScreen(viewModel: viewModel, assignmentID: id)
        case .exports(let id):
            ExportsRestoreScreen(viewModel: viewModel, assignmentID: id)
        }
    }

    private func consumePendingLaunchRequest() {
        guard let request = AppLaunchRequestStore.consume() else { return }
        viewModel.handleLaunchRequest(request)
        selectedTab = tab(for: request.destination)
        launchRoute = launchRoute(for: request)
    }

    private func tab(for destination: AppLaunchDestination) -> GradeDraftTab {
        switch destination {
        case .home:
            return .home
        case .assignments, .finalReview:
            return .assignments
        case .aiReadiness, .latestDraft, .review, .packetPreview, .ocrReview, .studentWork:
            return .review
        case .exports:
            return .exports
        case .curriculum:
            return .assignments
        }
    }

    private func launchRoute(for request: AppLaunchRequest) -> AppLaunchRoute? {
        if let assignmentID = request.assignmentID,
           viewModel.assignment(for: assignmentID) == nil {
            return nil
        }
        switch request.destination {
        case .home, .review:
            return nil
        case .assignments:
            return currentAssignmentRoute(AppLaunchRoute.assignmentOverview)
        case .aiReadiness:
            return currentAssignmentRoute(AppLaunchRoute.aiReadiness)
        case .finalReview, .latestDraft:
            return currentAssignmentRoute(AppLaunchRoute.finalReview)
        case .packetPreview:
            return currentAssignmentRoute(AppLaunchRoute.packetPreview)
        case .ocrReview:
            return currentAssignmentRoute(AppLaunchRoute.ocrReview)
        case .curriculum:
            return currentAssignmentRoute(AppLaunchRoute.curriculum)
        case .studentWork:
            return currentAssignmentRoute(AppLaunchRoute.studentWork)
        case .exports:
            return .exports(viewModel.selectedAssignmentID)
        }
    }

    private func currentAssignmentRoute(_ makeRoute: (UUID) -> AppLaunchRoute) -> AppLaunchRoute? {
        guard let selectedAssignmentID = viewModel.selectedAssignmentID else { return nil }
        return makeRoute(selectedAssignmentID)
    }
}
