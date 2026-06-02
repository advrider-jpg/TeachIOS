import SwiftUI

enum GradeDraftTypography {
    static let pageTitle: Font = .largeTitle.bold()
    static let deepTitle: Font = .title.bold()
    static let sectionTitle: Font = .headline
    static let rowTitle: Font = .headline
    static let rowMetadata: Font = .subheadline
    static let helper: Font = .footnote
    static let chip: Font = .caption.weight(.semibold)
    static let stationeryEyebrow: Font = .caption.weight(.semibold)
    static let stationeryAnnotation: Font = .callout.italic()
    static let stationeryMetricValue: Font = .title3.weight(.semibold).monospacedDigit()
}
