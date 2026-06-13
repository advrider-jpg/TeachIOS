import SwiftUI

struct StationeryMetric: View {
    var title: String
    var value: String
    var status: GradeDraftUIStatus?
    var theme: StationeryTheme

    init(title: String, value: String, status: GradeDraftUIStatus? = nil, theme: StationeryTheme = .gradeDraft) {
        self.title = title
        self.value = value
        self.status = status
        self.theme = theme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(GradeDraftTypography.stationeryMetricValue)
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)
                if let status {
                    Image(systemName: status.systemImage)
                        .imageScale(.small)
                        .foregroundStyle(status.color)
                        .accessibilityHidden(true)
                }
            }
            Text(title)
                .font(GradeDraftTypography.helper)
                .foregroundStyle(theme.mutedInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background((status?.color ?? theme.accent).opacity(0.09), in: RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GradeDraftLayout.rowCornerRadius, style: .continuous)
                .stroke(status.map { theme.statusStroke(for: $0) } ?? Color(.separator), lineWidth: status == nil ? 0.5 : 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        if let status {
            return "\(value). Status: \(status.fullAccessibilityLabel)"
        }
        return value
    }
}

struct WorkflowTimeline: View {
    struct Step: Identifiable, Equatable {
        var id: String
        var index: Int
        var title: String
        var detail: String
        var status: GradeDraftUIStatus

        init(id: String? = nil, index: Int, title: String, detail: String, status: GradeDraftUIStatus) {
            self.id = id ?? title
            self.index = index
            self.title = title
            self.detail = detail
            self.status = status
        }
    }

    var steps: [Step]
    var theme: StationeryTheme

    init(steps: [Step], theme: StationeryTheme = .gradeDraft) {
        self.steps = steps
        self.theme = theme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { offset, step in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        timelineBubble(step)
                        if offset < steps.count - 1 {
                            Rectangle()
                                .fill(step.status.color.opacity(0.22))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(width: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title)
                            .font(GradeDraftTypography.rowTitle)
                            .foregroundStyle(theme.ink)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(step.detail)
                            .font(GradeDraftTypography.helper)
                            .foregroundStyle(theme.mutedInk)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                        StatusChip(step.status, compact: true)
                            .padding(.top, 2)
                    }
                    .layoutPriority(1)
                }
                .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
                .padding(.vertical, 10)
                .frame(minHeight: 68, alignment: .top)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Step \(step.index), \(step.title)")
                .accessibilityValue("\(step.detail) Status: \(step.status.fullAccessibilityLabel)")
            }
        }
    }

    private func timelineBubble(_ step: Step) -> some View {
        ZStack {
            Circle()
                .fill(theme.statusFill(for: step.status))
            Text("\(step.index)")
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(step.status.color)
        }
        .frame(width: 30, height: 30)
        .overlay(Circle().stroke(theme.statusStroke(for: step.status), lineWidth: 1))
    }
}

struct MetricStrip: View {
    struct Metric: Identifiable, Equatable {
        var id: String { title }
        var title: String
        var value: String
        var status: GradeDraftUIStatus?

        init(_ title: String, value: String, status: GradeDraftUIStatus? = nil) {
            self.title = title
            self.value = value
            self.status = status
        }
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var metrics: [Metric]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(metrics) { metric in
                MetricCell(metric: metric)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var columns: [GridItem] {
        let count = max(1, min(metrics.count, preferredColumnCount))
        return Array(repeating: GridItem(.flexible(minimum: 112), spacing: 8, alignment: .leading), count: count)
    }

    private var preferredColumnCount: Int {
        if horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize {
            return 2
        }
        return 4
    }
}

private struct MetricCell: View {
    var metric: MetricStrip.Metric

    var body: some View {
        StationeryMetric(title: metric.title, value: metric.value, status: metric.status)
    }
}

struct WorkflowStepRow: View {
    var index: Int
    var title: String
    var detail: String
    var status: GradeDraftUIStatus

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(status.color.opacity(0.14))
                Text("\(index)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(status.color)
            }
            .frame(width: 28, height: 28)
            .accessibilityLabel("Step \(index)")
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            StatusChip(status, compact: true)
                .layoutPriority(2)
        }
        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
        .padding(.vertical, 10)
        .frame(minHeight: 64)
    }
}


struct WorkflowProgressRail: View {
    var steps: [WorkflowStepRow]

    var body: some View {
        WorkflowTimeline(steps: steps.map { WorkflowTimeline.Step(index: $0.index, title: $0.title, detail: $0.detail, status: $0.status) })
    }
}


struct BlockingIssueRow: View {
    var title: String
    var detail: String
    var status: GradeDraftUIStatus

    init(title: String, detail: String, status: GradeDraftUIStatus = .fixBeforeContinuing) {
        self.title = title
        self.detail = detail
        self.status = status
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: status.systemImage)
                .foregroundStyle(status.color)
                .frame(width: 22, height: 22)
                .accessibilityLabel("Status")
                .accessibilityValue(status.fullAccessibilityLabel)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
        .padding(.vertical, 10)
        .frame(minHeight: 54)
    }
}
