import SnapshotTesting
import SwiftUI
import XCTest

@testable import GradeDraft

final class GradeDraftSnapshotTests: XCTestCase {
    func testLocalCapabilityBannerUnavailable() {
        let banner = LocalCapabilityBanner(
            status: .unavailable("Local AI grading is unavailable in this build."),
            message: "Dependency wiring and local OCR gating remain explicit."
        )
        assertSnapshot(of: banner, as: .image(layout: .device(config: .iPhoneSe)))
    }
}
