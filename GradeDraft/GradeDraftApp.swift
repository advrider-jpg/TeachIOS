import AppIntents
import SwiftUI

@main
struct GradeDraftApp: App {
    @State private var appModel: AppModel

    init() {
        ExportFileStore.purgeAll()
        let model = Self.makeAppModel()
        _appModel = State(initialValue: model)
        Self.registerDependencies(of: model)
    }

    var body: some Scene {
        WindowGroup {
            RootView(retryStorage: retryStorage)
                .environment(appModel)
        }
    }

    private func retryStorage() {
        appModel.openStorage()
        Self.registerDependencies(of: appModel)
    }

    /// Shortcuts write through the same store the app uses. Registered once storage is open.
    @MainActor
    private static func registerDependencies(of model: AppModel) {
        AppModel.registerDependencies(model)
    }

    @MainActor
    private static func makeAppModel() -> AppModel {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-core-lane-test") || arguments.contains("--ui-smoke-test") {
            // UI tests run against the shared fixture in an in-memory store; nothing on disk is touched.
            return PreviewFixtures.makeAppModel()
        }
        #endif
        return AppModel()
    }
}
