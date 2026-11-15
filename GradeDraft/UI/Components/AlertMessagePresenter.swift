import SwiftUI

extension View {
    /// Shows a model's `alert` with an OK button and clears it when dismissed.
    func alertMessage(_ message: Binding<AlertMessage?>) -> some View {
        alert(message.wrappedValue?.title ?? "", item: message) { _ in
            Button("OK", role: .cancel) {}
        } message: { presented in
            Text(presented.message)
        }
    }
}
