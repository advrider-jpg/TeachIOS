import SwiftUI

extension View {
    func gradeDraftNativeGroupedList() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.automatic)
    }
}
