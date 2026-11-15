import SwiftUI

/// The window's root: the storage error screen when saved work cannot be opened, otherwise the tabs.
/// Open Assignment Shortcuts are routed here.
struct RootView: View {
    @Environment(AppModel.self) private var appModel
    var retryStorage: () -> Void

    var body: some View {
        Group {
            if let startupError = appModel.startupError, appModel.database == nil {
                StorageErrorView(error: startupError, tryAgain: retryStorage)
            } else {
                AppTabShell()
            }
        }
        .onAppIntentExecution(OpenSubmissionIntent.self) { intent in
            appModel.open(intent.target.id, destination: intent.destination)
        }
    }
}

/// Home, Classes, Assignments, Review and Exports, declared once. On iPad the tab bar becomes a sidebar.
/// Each tab has its own navigation stack whose path is a list of `Route`s, saved per window.
struct AppTabShell: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase

    @SceneStorage("navigation.home") private var homePath: Data?
    @SceneStorage("navigation.classes") private var classesPath: Data?
    @SceneStorage("navigation.assignments") private var assignmentsPath: Data?
    @SceneStorage("navigation.review") private var reviewPath: Data?
    @SceneStorage("navigation.exports") private var exportsPath: Data?
    @State private var restoredPaths = false

    var body: some View {
        @Bindable var appModel = appModel
        TabView(selection: $appModel.selectedTab) {
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: AppTab.home) {
                stack(.home) {
                    HomeScreen()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                NavigationLink {
                                    SettingsAboutLocalPrivacyScreen()
                                } label: {
                                    Label("Settings", systemImage: "gearshape")
                                }
                                .accessibilityIdentifier("home.settings")
                            }
                        }
                }
            }
            Tab(AppTab.classes.title, systemImage: AppTab.classes.systemImage, value: AppTab.classes) {
                stack(.classes) { ClassesScreen() }
            }
            Tab(AppTab.assignments.title, systemImage: AppTab.assignments.systemImage, value: AppTab.assignments) {
                stack(.assignments) { AssignmentsScreen() }
            }
            Tab(AppTab.review.title, systemImage: AppTab.review.systemImage, value: AppTab.review) {
                stack(.review) { ReviewScreen() }
            }
            Tab(AppTab.exports.title, systemImage: AppTab.exports.systemImage, value: AppTab.exports) {
                stack(.exports) { ExportsTabScreen() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .task {
            restorePaths()
            await appModel.observeLists()
        }
        .onChange(of: appModel.paths) {
            savePaths()
        }
        .alertMessage($appModel.alert)
    }

    private func stack<Root: View>(_ tab: AppTab, @ViewBuilder root: () -> Root) -> some View {
        NavigationStack(path: Binding(
            get: { appModel.path(for: tab) },
            set: { appModel.setPath($0, for: tab) }
        )) {
            root()
                .navigationDestination(for: Route.self) { route in
                    RouteDestination(route: route, app: appModel)
                }
        }
        .environment(\.appTab, tab)
    }

    // MARK: - Saved paths

    private func storedPath(for tab: AppTab) -> Data? {
        switch tab {
        case .home: return homePath
        case .classes: return classesPath
        case .assignments: return assignmentsPath
        case .review: return reviewPath
        case .exports: return exportsPath
        }
    }

    private func store(_ data: Data?, for tab: AppTab) {
        switch tab {
        case .home: homePath = data
        case .classes: classesPath = data
        case .assignments: assignmentsPath = data
        case .review: reviewPath = data
        case .exports: exportsPath = data
        }
    }

    /// A saved route whose record has since been deleted reopens to its not-found screen.
    private func restorePaths() {
        guard !restoredPaths else { return }
        restoredPaths = true
        for tab in AppTab.allCases {
            guard let data = storedPath(for: tab), let path = try? JSONDecoder().decode([Route].self, from: data) else { continue }
            appModel.setPath(path, for: tab)
        }
    }

    private func savePaths() {
        for tab in AppTab.allCases {
            let path = appModel.path(for: tab)
            let data = path.isEmpty ? nil : (try? JSONEncoder().encode(path))
            store(data, for: tab)
        }
    }
}
