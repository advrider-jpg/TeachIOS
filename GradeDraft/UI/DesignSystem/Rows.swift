import SwiftUI

struct StationerySearchBar: View {
    @Binding var text: String
    var prompt: String
    var isEnabled: Bool
    var theme: StationeryTheme

    init(
        text: Binding<String>,
        prompt: String = "Search",
        isEnabled: Bool = true,
        theme: StationeryTheme = .gradeDraft
    ) {
        self._text = text
        self.prompt = prompt
        self.isEnabled = isEnabled
        self.theme = theme
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.mutedInk)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .disabled(!isEnabled)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.mutedInk)
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .frame(width: GradeDraftLayout.minimumTapTarget, height: GradeDraftLayout.minimumTapTarget)
                .accessibilityLabel("Clear search")
            }
        }
        .font(.body)
        .padding(.leading, 13)
        .padding(.trailing, text.isEmpty ? 13 : 0)
        .frame(minHeight: GradeDraftLayout.minimumTapTarget)
        .background(theme.paper, in: RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityElement(children: .contain)
    }
}

struct StationeryRow: View {
    var title: String
    var detail: String?
    var systemImage: String
    var status: GradeDraftUIStatus?
    var actionLabel: String?
    var isEnabled: Bool
    var theme: StationeryTheme

    init(
        title: String,
        detail: String? = nil,
        systemImage: String = "doc.text",
        status: GradeDraftUIStatus? = nil,
        actionLabel: String? = nil,
        isEnabled: Bool = true,
        theme: StationeryTheme = .gradeDraft
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.status = status
        self.actionLabel = actionLabel
        self.isEnabled = isEnabled
        self.theme = theme
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            rowIcon
            VStack(alignment: .leading, spacing: 4) {
                Text(title.isEmpty ? "Untitled" : title)
                    .font(GradeDraftTypography.rowTitle)
                    .foregroundStyle(theme.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(GradeDraftTypography.rowMetadata)
                        .foregroundStyle(theme.mutedInk)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            trailingContent
        }
        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
        .padding(.vertical, GradeDraftLayout.rowVerticalPadding)
        .frame(minHeight: 60)
        .background(theme.paper.opacity(isEnabled ? 1 : 0.65), in: RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous)
                .stroke(status.map { theme.statusStroke(for: $0) } ?? Color(.separator), lineWidth: status == nil ? 0.5 : 1)
        )
        .opacity(isEnabled ? 1 : 0.7)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var rowIcon: some View {
        Image(systemName: systemImage)
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(status?.color ?? theme.accent)
            .frame(width: 30, height: 30)
            .background((status?.color ?? theme.accent).opacity(0.10), in: Circle())
            .padding(.top, 1)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var trailingContent: some View {
        if let status {
            VStack(alignment: .trailing, spacing: 6) {
                StatusChip(status, compact: true)
                if let actionLabel, !actionLabel.isEmpty {
                    Text(actionLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isEnabled ? theme.accent : theme.mutedInk)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 132, alignment: .trailing)
            .layoutPriority(2)
        } else if let actionLabel, !actionLabel.isEmpty {
            Text(actionLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isEnabled ? theme.accent : theme.mutedInk)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 110, alignment: .trailing)
                .layoutPriority(2)
        }
    }

    private var accessibilityLabel: String {
        title.isEmpty ? "Untitled row" : title
    }

    private var accessibilityValue: String {
        [
            detail,
            status.map { "Status: \($0.fullAccessibilityLabel)" },
            actionLabel.map { "Action: \($0)" },
            isEnabled ? nil : "Unavailable"
        ]
        .compactMap { $0 }
        .joined(separator: ". ")
    }
}

struct ClassRow: View {
    var name: String
    var subject: String
    var studentCount: Int
    var assignmentCount: Int
    var status: GradeDraftUIStatus

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 28)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "Unnamed class" : name)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(subject.isEmpty ? "Class" : subject) · \(studentCount) students · \(assignmentCount) assignments")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            StatusChip(status, compact: true)
                .layoutPriority(2)
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 28)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title)
                    .font(.headline)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(assignmentRowMetadata)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                StatusChip(status, compact: true)
                Text(actionLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 132, alignment: .trailing)
            .layoutPriority(2)
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 21))
                .foregroundStyle(.secondary)
                .frame(width: 28)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(student.displayName.isEmpty ? "Unnamed student" : student.displayName)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(student.localIdentifier.isEmpty ? student.className.nilIfBlank ?? "No local ID" : student.localIdentifier)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            if let scoreText {
                Text(scoreText)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            StatusChip(status, compact: true)
                .layoutPriority(2)
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: status.systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(status.color)
                .frame(width: 28)
                .padding(.top, 2)
                .accessibilityLabel("Status")
                .accessibilityValue(status.fullAccessibilityLabel)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                if let countText {
                    Text(countText)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                Text(actionLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 120, alignment: .trailing)
            .layoutPriority(2)
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: attachmentIcon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 28)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(source.fileName?.nilIfBlank ?? source.sourceType.displayName)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(attachmentDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            StatusChip(source.teacherIncludedInExport ? .teacherOnly : .notStarted, compact: true)
                .layoutPriority(2)
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
