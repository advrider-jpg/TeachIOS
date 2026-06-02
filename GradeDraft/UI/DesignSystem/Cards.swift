import SwiftUI

struct StationeryScreen<Content: View>: View {
    var theme: StationeryTheme
    private let content: Content

    init(theme: StationeryTheme = .gradeDraft, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.content = content()
    }

    var body: some View {
        ZStack {
            theme.deskBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: GradeDraftLayout.sectionSpacing) {
                    content
                }
                .padding(GradeDraftLayout.stationeryScreenPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct StationeryPageHeader: View {
    var eyebrow: String?
    var title: String
    var subtitle: String?
    var status: GradeDraftUIStatus?
    var theme: StationeryTheme

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        status: GradeDraftUIStatus? = nil,
        theme: StationeryTheme = .gradeDraft
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.theme = theme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hasTopLine {
                HStack(alignment: .center, spacing: 10) {
                    if let eyebrow, !eyebrow.isEmpty {
                        TapeLabel(eyebrow, theme: theme)
                    }
                    Spacer(minLength: 0)
                    if let status {
                        StatusChip(status, compact: true)
                    }
                }
            }
            Text(title)
                .font(GradeDraftTypography.pageTitle)
                .foregroundStyle(theme.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(GradeDraftTypography.rowMetadata)
                    .foregroundStyle(theme.mutedInk)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var hasTopLine: Bool {
        if let eyebrow, !eyebrow.isEmpty { return true }
        return status != nil
    }
}

struct NotebookCard<Content: View>: View {
    var theme: StationeryTheme
    var status: GradeDraftUIStatus?
    var showsPerforation: Bool
    private let content: Content

    init(
        theme: StationeryTheme = .gradeDraft,
        status: GradeDraftUIStatus? = nil,
        showsPerforation: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.theme = theme
        self.status = status
        self.showsPerforation = showsPerforation
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GradeDraftLayout.stationeryCardSpacing) {
            content
        }
        .padding(GradeDraftLayout.stationeryCardPadding)
        .padding(.leading, showsPerforation ? 10 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(alignment: .leading) {
            if showsPerforation {
                PerforatedPaperEdge(side: .leading, theme: theme)
                    .padding(.vertical, 10)
                    .accessibilityHidden(true)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: GradeDraftLayout.cardCornerRadius, style: .continuous)
                .stroke(status.map { theme.statusStroke(for: $0) } ?? Color(.separator), lineWidth: status == nil ? 0.5 : 1)
        )
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: GradeDraftLayout.cardCornerRadius, style: .continuous)
                .fill(theme.paper)
                .shadow(color: theme.shadow, radius: 12, x: 0, y: 6)
            RuledPaperLines(theme: theme)
                .clipShape(RoundedRectangle(cornerRadius: GradeDraftLayout.cardCornerRadius, style: .continuous))
                .accessibilityHidden(true)
        }
    }
}

private struct RuledPaperLines: View {
    var theme: StationeryTheme

    var body: some View {
        GeometryReader { proxy in
            let count = max(1, Int(proxy.size.height / GradeDraftLayout.stationeryRuleSpacing))
            ForEach(0..<count, id: \.self) { index in
                Path { path in
                    let y = CGFloat(index) * GradeDraftLayout.stationeryRuleSpacing + GradeDraftLayout.stationeryRuleSpacing
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
                .stroke(theme.ruledLine, lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
    }
}

struct PerforatedPaperEdge: View {
    enum Side {
        case leading
        case trailing
        case top
        case bottom
    }

    var side: Side
    var theme: StationeryTheme

    init(side: Side = .leading, theme: StationeryTheme = .gradeDraft) {
        self.side = side
        self.theme = theme
    }

    var body: some View {
        GeometryReader { proxy in
            let vertical = side == .leading || side == .trailing
            let length = vertical ? proxy.size.height : proxy.size.width
            let count = max(1, Int(length / GradeDraftLayout.stationeryHoleSpacing))
            ZStack {
                perforationGuide(in: proxy.size)
                    .stroke(theme.ruledLine.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                ForEach(0..<count, id: \.self) { index in
                    Circle()
                        .fill(theme.deskBackground)
                        .overlay(Circle().stroke(theme.ruledLine, lineWidth: 0.5))
                        .frame(width: GradeDraftLayout.stationeryHoleDiameter, height: GradeDraftLayout.stationeryHoleDiameter)
                        .position(holePosition(index: index, count: count, size: proxy.size))
                }
            }
        }
        .frame(width: side == .leading || side == .trailing ? 18 : nil, height: side == .top || side == .bottom ? 18 : nil)
    }

    private func perforationGuide(in size: CGSize) -> Path {
        Path { path in
            switch side {
            case .leading:
                path.move(to: CGPoint(x: 9, y: 0))
                path.addLine(to: CGPoint(x: 9, y: size.height))
            case .trailing:
                path.move(to: CGPoint(x: size.width - 9, y: 0))
                path.addLine(to: CGPoint(x: size.width - 9, y: size.height))
            case .top:
                path.move(to: CGPoint(x: 0, y: 9))
                path.addLine(to: CGPoint(x: size.width, y: 9))
            case .bottom:
                path.move(to: CGPoint(x: 0, y: size.height - 9))
                path.addLine(to: CGPoint(x: size.width, y: size.height - 9))
            }
        }
    }

    private func holePosition(index: Int, count: Int, size: CGSize) -> CGPoint {
        let step = (side == .leading || side == .trailing ? size.height : size.width) / CGFloat(count + 1)
        let offset = CGFloat(index + 1) * step
        switch side {
        case .leading:
            return CGPoint(x: 9, y: offset)
        case .trailing:
            return CGPoint(x: size.width - 9, y: offset)
        case .top:
            return CGPoint(x: offset, y: 9)
        case .bottom:
            return CGPoint(x: offset, y: size.height - 9)
        }
    }
}

struct PaperStack<Content: View>: View {
    var theme: StationeryTheme
    private let content: Content

    init(theme: StationeryTheme = .gradeDraft, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: GradeDraftLayout.cardCornerRadius, style: .continuous)
                .fill(theme.paperTint)
                .offset(x: 5, y: 7)
            RoundedRectangle(cornerRadius: GradeDraftLayout.cardCornerRadius, style: .continuous)
                .fill(theme.paper.opacity(0.92))
                .offset(x: 2, y: 3)
            NotebookCard(theme: theme, showsPerforation: true) {
                content
            }
        }
    }
}

struct TapeLabel: View {
    var text: String
    var theme: StationeryTheme

    init(_ text: String, theme: StationeryTheme = .gradeDraft) {
        self.text = text
        self.theme = theme
    }

    var body: some View {
        Text(text)
            .font(GradeDraftTypography.stationeryEyebrow)
            .textCase(.uppercase)
            .foregroundStyle(theme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .frame(minHeight: GradeDraftLayout.stationeryTapeHeight)
            .background(theme.tape, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
            )
            .rotationEffect(.degrees(-1.5))
    }
}

struct PaperclipDecoration: View {
    var theme: StationeryTheme

    init(theme: StationeryTheme = .gradeDraft) {
        self.theme = theme
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(theme.clip, lineWidth: 2)
                .frame(width: GradeDraftLayout.stationeryClipSize.width, height: GradeDraftLayout.stationeryClipSize.height)
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(theme.clip, lineWidth: 2)
                .frame(width: GradeDraftLayout.stationeryClipSize.width - 11, height: GradeDraftLayout.stationeryClipSize.height - 17)
                .offset(y: 5)
        }
        .rotationEffect(.degrees(10))
        .accessibilityHidden(true)
    }
}

struct StatusIconBubble: View {
    var status: GradeDraftUIStatus
    var theme: StationeryTheme
    var size: CGFloat

    init(_ status: GradeDraftUIStatus, theme: StationeryTheme = .gradeDraft, size: CGFloat = 36) {
        self.status = status
        self.theme = theme
        self.size = size
    }

    var body: some View {
        Image(systemName: status.systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(status.color)
            .frame(width: size, height: size)
            .background(theme.statusFill(for: status), in: Circle())
            .overlay(Circle().stroke(theme.statusStroke(for: status), lineWidth: 1))
            .accessibilityLabel("Status")
            .accessibilityValue(status.fullAccessibilityLabel)
    }
}

struct HandwrittenAnnotation: View {
    var text: String
    var status: GradeDraftUIStatus?
    var theme: StationeryTheme

    init(_ text: String, status: GradeDraftUIStatus? = nil, theme: StationeryTheme = .gradeDraft) {
        self.text = text
        self.status = status
        self.theme = theme
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            if let status {
                Image(systemName: status.systemImage)
                    .imageScale(.small)
                    .foregroundStyle(status.color)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(GradeDraftTypography.stationeryAnnotation)
                .foregroundStyle(status?.color ?? theme.mutedInk)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background((status?.color ?? theme.accent).opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct DeskEdgeDecoration: View {
    var theme: StationeryTheme

    init(theme: StationeryTheme = .gradeDraft) {
        self.theme = theme
    }

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [theme.deskBackground, theme.paperTint.opacity(0.65), theme.deskBackground],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 10)
            .overlay(Rectangle().fill(Color(.separator)).frame(height: 0.5), alignment: .top)
            .accessibilityHidden(true)
    }
}

struct WarningBanner: View {
    var title: String
    var message: String
    var status: GradeDraftUIStatus

    init(title: String, message: String, status: GradeDraftUIStatus = .needsAttention) {
        self.title = title
        self.message = message
        self.status = status
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            StatusIconBubble(status, size: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StationeryTheme.gradeDraft.statusFill(for: status), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(StationeryTheme.gradeDraft.statusStroke(for: status), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}


struct ReviewGateBanner: View {
    var title: String
    var message: String
    var status: GradeDraftUIStatus

    var body: some View {
        WarningBanner(title: title, message: message, status: status)
    }
}
