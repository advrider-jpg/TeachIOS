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

// MARK: - iPhone-first rubric layout helpers

/// Renders inline Markdown (bold, italic, links, inline code) in teacher-authored
/// rubric descriptors and feedback using the native Foundation parser — no third-party
/// dependency. Falls back to plain text if the string is not valid Markdown.
func inlineRubricMarkdown(_ string: String) -> AttributedString {
    (try? AttributedString(
        markdown: string,
        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(string)
}

/// Lightweight wrapping flow layout (chips/tags) built on the native SwiftUI `Layout`
/// protocol. Source-dropped rather than adding a package, to keep the local-first app's
/// dependency surface flat. Reference: tevelee/SwiftUI-Flow, krishkumar/FlowLayout (MIT).
struct RubricFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let projectedWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty && projectedWidth > maxWidth {
                rows.append(current)
                current = Row(indices: [index], width: size.width, height: size.height)
            } else {
                current.width = projectedWidth
                current.height = max(current.height, size.height)
                current.indices.append(index)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let computed = rows(maxWidth: maxWidth, subviews: subviews)
        let height = computed.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, computed.count - 1))
        let width = proposal.width ?? (computed.map(\.width).max() ?? 0)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var currentY = bounds.minY
        for row in rows(maxWidth: bounds.width, subviews: subviews) {
            var currentX = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: currentX, y: currentY), anchor: .topLeading, proposal: ProposedViewSize(size))
                currentX += size.width + spacing
            }
            currentY += row.height + lineSpacing
        }
    }
}

/// Compact, capsule-style tag for rubric level bands, AI constraints, and curriculum refs.
struct RubricChip: View {
    var text: String
    var systemImage: String?
    var emphasized: Bool

    init(_ text: String, systemImage: String? = nil, emphasized: Bool = false) {
        self.text = text
        self.systemImage = systemImage
        self.emphasized = emphasized
    }

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2.weight(.bold))
            }
            Text(text).font(.caption.weight(.semibold)).lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .foregroundStyle(RubricStationeryPalette.theme.accent)
        .background(
            RubricStationeryPalette.theme.tape.opacity(emphasized ? 0.4 : 0.22),
            in: Capsule(style: .continuous)
        )
        .overlay(Capsule(style: .continuous).stroke(RubricStationeryPalette.theme.ruledLine, lineWidth: 0.5))
    }
}

/// A stationery-styled card whose body collapses behind a tappable header, so the long
/// rubric setup screen folds down to a scannable list of sections on a phone.
struct RubricCollapsibleCard<Content: View>: View {
    var title: String
    var tapeLabel: String
    var collapsedSummary: String?
    var annotation: String?
    var status: GradeDraftUIStatus?
    var showsPaperclip: Bool
    @Binding var isExpanded: Bool
    private let content: Content

    init(
        title: String,
        tapeLabel: String,
        collapsedSummary: String? = nil,
        annotation: String? = nil,
        status: GradeDraftUIStatus? = nil,
        showsPaperclip: Bool = false,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.tapeLabel = tapeLabel
        self.collapsedSummary = collapsedSummary
        self.annotation = annotation
        self.status = status
        self.showsPaperclip = showsPaperclip
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        NotebookCard(theme: RubricStationeryPalette.theme, status: status, showsPerforation: true) {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            TapeLabel(tapeLabel, theme: RubricStationeryPalette.theme)
                            Text(title)
                                .font(.system(.title3, design: .serif).weight(.semibold))
                                .foregroundStyle(RubricStationeryPalette.theme.ink)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            if let collapsedSummary, !isExpanded {
                                Text(collapsedSummary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 8) {
                            if let status {
                                RubricStationeryStatusChip(status, compact: true)
                            }
                            Image(systemName: "chevron.down")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(RubricStationeryPalette.theme.mutedInk)
                                .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        }
                        if showsPaperclip {
                            PaperclipDecoration(theme: RubricStationeryPalette.theme)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(title)
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                .accessibilityHint("Double tap to \(isExpanded ? "collapse" : "expand")")
                .accessibilityAddTraits(.isButton)

                if isExpanded {
                    content
                    if let annotation {
                        RubricHandwrittenNote(annotation, status: status)
                    }
                }
            }
        }
    }
}

/// A tappable summary row for the setup checklist at the top of the rubric screen.
struct RubricOverviewRow: View {
    var label: String
    var value: String
    var status: GradeDraftUIStatus
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RubricStationeryStatusChip(status, compact: true)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RubricStationeryPalette.theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(value)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RubricStationeryPalette.theme.mutedInk)
            }
            .contentShape(Rectangle())
            .frame(minHeight: GradeDraftLayout.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityHint("Double tap to open this section")
    }
}
