import SwiftUI
import XCTest

@testable import GradeDraft

/// Deterministic tests for LocalCapabilityBanner UI state.
/// Snapshot testing was removed because no reference images were committed.
/// These tests verify the view's observable behavior without image comparison.
@MainActor
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
        let message = "Local AI grading is unavailable. MarkForMe will not send student work to a cloud model."
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

    func testCapabilityBannerExplainsAppleIntelligenceDisabled() {
        let status = LocalAIStatus.unavailable("Apple Intelligence is not enabled. Enable it in Settings to use local AI grading.")
        XCTAssertEqual(LocalCapabilityBannerCopy.title(for: status), "Apple Intelligence disabled")
        XCTAssertTrue(
            LocalCapabilityBannerCopy.details(for: status, message: "").contains {
                $0.contains("Enable Apple Intelligence in Settings")
            }
        )
    }

    func testCapabilityBannerExplainsModelNotReady() {
        let status = LocalAIStatus.unavailable("The on-device language model is not ready yet. Try again after the system finishes preparing it.")
        XCTAssertEqual(LocalCapabilityBannerCopy.title(for: status), "Model not ready")
        XCTAssertTrue(
            LocalCapabilityBannerCopy.details(for: status, message: "").contains {
                $0.contains("finish preparing")
            }
        )
    }

    func testCapabilityBannerAvailableIncludesAirplaneModeReassurance() {
        let details = LocalCapabilityBannerCopy.details(
            for: .available,
            message: "Local AI is available on this device. Student work stays on device."
        )
        XCTAssertTrue(details.contains { $0.contains("Airplane Mode") })
        XCTAssertTrue(details.contains { $0.contains("no cloud fallback") })
    }
}
