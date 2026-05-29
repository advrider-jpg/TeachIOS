import SwiftUI

struct TopLevelHeader<Trailing: View>: View {
    var title: String
    var subtitle: String
    var showsLocalBadge: Bool
    @ViewBuilder var trailing: Trailing

    init(
        title: String,
        subtitle: String,
        showsLocalBadge: Bool = true,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showsLocalBadge = showsLocalBadge
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                trailing
                    .frame(minWidth: 44, alignment: .trailing)
            }
            if showsLocalBadge {
                LocalOnlyBadge()
            }
        }
        .padding(.horizontal, GradeDraftLayout.screenPadding)
        .padding(.top, 10)
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
    }
}


struct DeepWorkflowHeader<Trailing: View>: View {
    var title: String
    var subtitle: String
    var status: GradeDraftUIStatus?
    @ViewBuilder var trailing: Trailing

    init(
        title: String,
        subtitle: String,
        status: GradeDraftUIStatus? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.title.bold())
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                trailing
                    .frame(minWidth: 44, alignment: .trailing)
            }
            if let status {
                StatusChip(status)
            }
        }
        .padding(.horizontal, GradeDraftLayout.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 2)
    }
}


struct LocalOnlyBadge: View {
    var body: some View {
        Label("Local only", systemImage: "lock.shield")
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .foregroundStyle(.secondary)
            .background(Color.gray.opacity(0.14), in: Capsule())
            .accessibilityLabel("Local only. Student work stays on this device unless you export it.")
    }
}
