import SwiftUI

private enum RubricStationeryPalette {
    static let theme = StationeryTheme(
        deskBackground: Color(red: 0.976, green: 0.941, blue: 0.855),
        paper: Color(red: 1.0, green: 0.985, blue: 0.938),
        paperTint: Color(red: 0.988, green: 0.956, blue: 0.878),
        ruledLine: Color(red: 0.64, green: 0.54, blue: 0.39).opacity(0.22),
        ink: Color(red: 0.18, green: 0.15, blue: 0.12),
        mutedInk: Color(red: 0.45, green: 0.36, blue: 0.26),
        accent: Color(red: 0.44, green: 0.31, blue: 0.18),
        tape: Color(red: 0.96, green: 0.78, blue: 0.43).opacity(0.74),
        clip: Color(red: 0.48, green: 0.31, blue: 0.16).opacity(0.72),
        shadow: Color(red: 0.42, green: 0.29, blue: 0.14).opacity(0.14)
    )
}

struct RubricStationeryPage<Content: View>: View {
    var title: String
    var subtitle: String?
    var tapeLabel: String
    var annotation: String?
    var status: GradeDraftUIStatus?
    private let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        tapeLabel: String,
        annotation: String? = nil,
        status: GradeDraftUIStatus? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tapeLabel = tapeLabel
        self.annotation = annotation
        self.status = status
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GradeDraftLayout.sectionSpacing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    TapeLabel(tapeLabel, theme: RubricStationeryPalette.theme)
                    Spacer(minLength: 8)
                    if let status {
                        RubricStationeryStatusChip(status, compact: true)
                    }
                }
                Text(title)
                    .font(.system(.largeTitle, design: .serif).weight(.bold))
                    .foregroundStyle(RubricStationeryPalette.theme.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RubricStationeryPalette.theme.mutedInk)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let annotation {
                    RubricHandwrittenNote(annotation, status: status)
                        .padding(.top, 2)
                }
            }
            content
        }
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .scrollDismissesKeyboard(.interactively)
    }
}

struct RubricStationeryCard<Content: View>: View {
    var title: String?
    var tapeLabel: String
    var annotation: String?
    var status: GradeDraftUIStatus?
    var showsPaperclip: Bool
    private let content: Content

    init(
        title: String? = nil,
        tapeLabel: String,
        annotation: String? = nil,
        status: GradeDraftUIStatus? = nil,
        showsPaperclip: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.tapeLabel = tapeLabel
        self.annotation = annotation
        self.status = status
        self.showsPaperclip = showsPaperclip
        self.content = content()
    }

    var body: some View {
        NotebookCard(theme: RubricStationeryPalette.theme, status: status, showsPerforation: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    TapeLabel(tapeLabel, theme: RubricStationeryPalette.theme)
                    Spacer(minLength: 8)
                    if showsPaperclip {
                        PaperclipDecoration(theme: RubricStationeryPalette.theme)
                    }
                }
                if let title {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(title)
                            .font(.system(.title3, design: .serif).weight(.semibold))
                            .foregroundStyle(RubricStationeryPalette.theme.ink)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        if let status {
                            RubricStationeryStatusChip(status, compact: true)
                        }
                    }
                }
                content
                if let annotation {
                    RubricHandwrittenNote(annotation, status: status)
                }
            }
        }
    }
}

struct RubricFieldRow<Control: View>: View {
    var title: String
    var detail: String?
    private let control: Control

    init(title: String, detail: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RubricStationeryPalette.theme.mutedInk)
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            control
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(RubricStationeryPalette.theme.ruledLine, lineWidth: 1)
        )
    }
}

struct RubricPaperTextEditor: View {
    var title: String
    @Binding var text: String
    var minHeight: CGFloat

    var body: some View {
        RubricFieldRow(title: title) {
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .accessibilityLabel(title)
        }
    }
}

struct RubricHandwrittenNote: View {
    var text: String
    var status: GradeDraftUIStatus?

    init(_ text: String, status: GradeDraftUIStatus? = nil) {
        self.text = text
        self.status = status
    }

    var body: some View {
        HandwrittenAnnotation(text, status: status, theme: RubricStationeryPalette.theme)
    }
}

struct RubricStationeryStatusChip: View {
    var status: GradeDraftUIStatus
    var compact: Bool

    init(_ status: GradeDraftUIStatus, compact: Bool = false) {
        self.status = status
        self.compact = compact
    }

    var body: some View {
        StatusChip(status, compact: compact)
            .padding(3)
            .background(RubricStationeryPalette.theme.tape.opacity(0.22), in: Capsule())
    }
}

struct RubricIconBubble: View {
    var status: GradeDraftUIStatus

    init(_ status: GradeDraftUIStatus) {
        self.status = status
    }

    var body: some View {
        StatusIconBubble(status, theme: RubricStationeryPalette.theme)
    }
}

struct RubricCriterionRow: View {
    var criterion: RubricCriterion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RubricIconBubble(.onTrack)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(criterion.title)
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .lineLimit(2)
                Text("\(GradeTotals.formatted(criterion.maxPoints)) points")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            RubricStationeryStatusChip(.onTrack, compact: true)
        }
        .padding(12)
        .background(Color.white.opacity(0.36), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}


struct CriterionSummaryRow: View {
    var criterion: FinalCriterionScore

    var body: some View {
        HStack(spacing: 12) {
            RubricIconBubble(criterion.teacherApproved ? .approved : .reviewFinalGrade)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(criterion.criterion)
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .lineLimit(2)
                Text(criterion.rating.nilIfBlank ?? "No rating selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text("\(GradeTotals.formatted(criterion.finalPoints)) / \(GradeTotals.formatted(criterion.maxPoints))")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .lineLimit(1)
        }
        .padding(12)
        .background(Color.white.opacity(0.36), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
