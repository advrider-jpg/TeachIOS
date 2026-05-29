import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: GradeDraftViewModel

    init(viewModel: GradeDraftViewModel = GradeDraftViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        AppTabShell(viewModel: viewModel)
    }
}
