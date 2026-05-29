import SwiftUI

struct ClassRow: View {
    var name: String
    var subject: String
    var studentCount: Int
    var assignmentCount: Int
    var status: GradeDraftUIStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "Unnamed class" : name)
                    .font(.headline)
                    .lineLimit(1)
                    .layoutPriority(1)
                Text("\(subject.isEmpty ? "Class" : subject) · \(studentCount) students · \(assignmentCount) assignments")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            StatusChip(status, compact: true)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
        .padding(.vertical, 10)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }
}


struct AssignmentRow: View {
    var assignment: AssignmentRecord
    var status: GradeDraftUIStatus
    var actionLabel: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title)
                    .font(.headline)
                    .lineLimit(2)
                    .layoutPriority(1)
                Text(assignmentRowMetadata)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                StatusChip(status, compact: true)
                Text(actionLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
        .padding(.vertical, 10)
        .frame(minHeight: 78)
        .contentShape(Rectangle())
    }

    private var assignmentRowMetadata: String {
        [assignment.studentDisplayName.nilIfBlank ?? "No student selected", assignment.className.nilIfBlank, assignment.assignmentType.displayName]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}


struct StudentRow: View {
    var student: StudentRecord
    var status: GradeDraftUIStatus
    var scoreText: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 21))
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(student.displayName.isEmpty ? "Unnamed student" : student.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(student.localIdentifier.isEmpty ? student.className.nilIfBlank ?? "No local ID" : student.localIdentifier)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let scoreText {
                Text(scoreText)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
            }
            StatusChip(status, compact: true)
        }
        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
        .padding(.vertical, 9)
        .frame(minHeight: 58)
    }
}


struct ReviewQueueRow: View {
    var title: String
    var detail: String
    var countText: String?
    var status: GradeDraftUIStatus
    var actionLabel: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(status.color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .layoutPriority(1)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                if let countText {
                    Text(countText)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(actionLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
        .padding(.vertical, 10)
        .frame(minHeight: 78)
        .contentShape(Rectangle())
    }
}


struct WorkAttachmentRow: View {
    var source: SourceInputRef

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: attachmentIcon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(source.fileName?.nilIfBlank ?? source.sourceType.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(attachmentDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            StatusChip(source.teacherIncludedInExport ? .teacherOnly : .notStarted, compact: true)
        }
        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
        .padding(.vertical, 9)
        .frame(minHeight: 58)
    }

    private var attachmentIcon: String {
        switch source.sourceType {
        case .scan:
            return "doc.viewfinder"
        case .photo:
            return "photo"
        case .pdf:
            return "doc.richtext"
        case .pastedText:
            return "text.alignleft"
        case .handwrittenWork, .visualArtifact:
            return "paperclip"
        }
    }

    private var attachmentDetail: String {
        if let pageIndex = source.pageIndex {
            return "Page \(pageIndex + 1) · Original file kept on device"
        }
        if let pageCount = source.pdfPageCount {
            return "\(pageCount) pages · Original file kept on device"
        }
        return "Original file kept on device"
    }
}
