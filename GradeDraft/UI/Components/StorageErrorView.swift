import SwiftUI

/// Shown instead of the app when the saved-work database cannot be opened. There is no empty store and
/// no placeholder data behind it.
struct StorageErrorView: View {
    var error: AppDatabaseError
    var tryAgain: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("MarkForMe can't open your saved work", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Try Again", action: tryAgain)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("storageError.tryAgain")
        }
    }
}

#if DEBUG
#Preview("Storage error") {
    StorageErrorView(error: .openFailed(underlying: CocoaError(.fileReadNoPermission)), tryAgain: {})
}
#endif
