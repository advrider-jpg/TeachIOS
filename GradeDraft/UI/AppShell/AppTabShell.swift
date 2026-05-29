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
    @ObservedObject var viewModel: GradeDraftViewModel
    @State private var selectedTab: GradeDraftTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeScreen(viewModel: viewModel)
            }
            .tabItem { Label(GradeDraftTab.home.title, systemImage: GradeDraftTab.home.systemImage) }
            .tag(GradeDraftTab.home)

            NavigationStack {
                ClassesScreen(viewModel: viewModel)
            }
            .tabItem { Label(GradeDraftTab.classes.title, systemImage: GradeDraftTab.classes.systemImage) }
            .tag(GradeDraftTab.classes)

            NavigationStack {
                AssignmentsScreen(viewModel: viewModel)
            }
            .tabItem { Label(GradeDraftTab.assignments.title, systemImage: GradeDraftTab.assignments.systemImage) }
            .tag(GradeDraftTab.assignments)

            NavigationStack {
                ReviewScreen(viewModel: viewModel)
            }
            .tabItem { Label(GradeDraftTab.review.title, systemImage: GradeDraftTab.review.systemImage) }
            .tag(GradeDraftTab.review)

            NavigationStack {
                ExportsRestoreScreen(viewModel: viewModel)
            }
            .tabItem { Label(GradeDraftTab.exports.title, systemImage: GradeDraftTab.exports.systemImage) }
            .tag(GradeDraftTab.exports)
        }
        .task { viewModel.refreshCapabilityStatus() }
        .alert("GradeDraft", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}
