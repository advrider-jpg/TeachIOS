import SwiftUI

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
        VStack(alignment: .leading, spacing: 4) {
            Text(metric.value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(metric.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background((metric.status?.color ?? Color.gray).opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
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
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            StatusChip(status, compact: true)
        }
        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
        .padding(.vertical, 10)
        .frame(minHeight: 64)
    }
}


struct WorkflowProgressRail: View {
    var steps: [WorkflowStepRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                step
                if step.index != steps.count {
                    Divider().padding(.leading, 56)
                }
            }
        }
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
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
        .padding(.vertical, 10)
        .frame(minHeight: 54)
    }
}
