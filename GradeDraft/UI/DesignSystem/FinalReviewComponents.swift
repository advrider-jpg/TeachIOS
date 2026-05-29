import SwiftUI

struct StudentFeedbackPanel: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Student Feedback")
                    .font(.headline)
                Spacer()
                StatusChip(.studentFacing, compact: true)
            }
            Text("Visible to student")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
    }
}


struct PrivateTeacherNotePanel: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Private Teacher Note")
                    .font(.headline)
                Spacer()
                StatusChip(.teacherOnly, compact: true)
            }
            Text("Not visible to student")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .frame(minHeight: 90)
                .padding(8)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
    }
}


struct FinalApprovalGate: View {
    var allCriteriaReviewed: Bool
    var canApprove: Bool
    var onApprove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Final Approval Gate")
                    .font(.headline)
                Spacer()
                StatusChip(allCriteriaReviewed ? .onTrack : .needsAttention, compact: true)
            }
            Label("All criteria reviewed", systemImage: allCriteriaReviewed ? "checkmark.circle" : "circle")
                .font(.subheadline)
                .foregroundStyle(allCriteriaReviewed ? .green : .orange)
            PrimaryActionButton(title: "Approve Final Grade", systemImage: "checkmark.seal", action: onApprove, disabled: !canApprove)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
