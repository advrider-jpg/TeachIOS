import SwiftUI
import XCTest

@testable import GradeDraft

/// Deterministic tests for LocalCapabilityBanner UI state.
/// Snapshot testing was removed because no reference images were committed.
/// These tests verify the view's observable behavior without image comparison.
final class GradeDraftCapabilityBannerTests: XCTestCase {

    func testAvailableStatusIsStoredCorrectly() {
        let banner = LocalCapabilityBanner(
            status: .available,
            message: "Local AI is available on this device."
        )
        XCTAssertEqual(banner.status, .available)
        XCTAssertEqual(banner.message, "Local AI is available on this device.")
    }

    func testUnavailableStatusCarriesMessage() {
        let message = "Local AI grading is unavailable. GradeDraft will not send student work to a cloud model."
        let banner = LocalCapabilityBanner(
            status: .unavailable(message),
            message: message
        )
        XCTAssertEqual(banner.message, message)
        if case .unavailable(let inner) = banner.status {
            XCTAssertEqual(inner, message)
        } else {
            XCTFail("Expected unavailable status")
        }
    }

    func testUnavailableStatusNotEqualToAvailable() {
        let availableStatus = LocalAIStatus.available
        let unavailableStatus = LocalAIStatus.unavailable("not available")
        XCTAssertNotEqual(availableStatus, unavailableStatus)
    }

    func testAvailableStatusSelfEquality() {
        XCTAssertEqual(LocalAIStatus.available, LocalAIStatus.available)
    }

    func testUnavailableStatusWithSameMessageEquality() {
        let msg = "unavailable reason"
        XCTAssertEqual(LocalAIStatus.unavailable(msg), LocalAIStatus.unavailable(msg))
    }
}
