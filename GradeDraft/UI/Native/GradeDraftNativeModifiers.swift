import SwiftUI

struct StationeryScreenModifier: ViewModifier {
    var theme: StationeryTheme

    init(theme: StationeryTheme = .gradeDraft) {
        self.theme = theme
    }

    func body(content: Content) -> some View {
        content
            .tint(theme.accent)
            .scrollContentBackground(.hidden)
            .background(theme.deskBackground.ignoresSafeArea())
    }
}

extension View {
    func gradeDraftNativeGroupedList() -> some View {
        self
            .listStyle(.insetGrouped)
            .modifier(StationeryScreenModifier())
    }

    func stationeryScreen(theme: StationeryTheme = .gradeDraft) -> some View {
        modifier(StationeryScreenModifier(theme: theme))
    }
}
