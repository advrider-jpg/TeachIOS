import SwiftUI

struct MissingAssignmentRouteView: View {
    var assignmentID: UUID
    var actionName: String

    var body: some View {
        ContentUnavailableView(
            "Assignment not found",
            systemImage: "doc.text.magnifyingglass",
            description: Text("\(actionName) is unavailable because this route points to an assignment that is not saved on this device. Choose a saved assignment before making changes.")
        )
        .accessibilityLabel("Assignment not found")
    }
}
