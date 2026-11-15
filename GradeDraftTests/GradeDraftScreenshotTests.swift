import SwiftUI
import UIKit
import XCTest

@testable import GradeDraft

/// Renders the app's core screens to PNG files stored in the app's
/// Documents/GradeDraftScreenshots/ directory, which CI can retrieve via
/// `xcrun simctl get_app_container`.
/// Each image is also attached as an XCTAttachment (visible in the .xcresult bundle).
/// Every screen shows the shared preview fixture (`PreviewFixtures`) through an in-memory `AppModel`.
@MainActor
final class GradeDraftScreenshotTests: XCTestCase {
    // MARK: - Core Pages

    func testCaptureHomeScreen() throws {
        try snapshot("01-home", ScreenPreview { _ in HomeScreen() }, to: prepareScreenshotDirectory())
    }

    func testCaptureClassesScreen() throws {
        try snapshot("02-classes", ScreenPreview { _ in ClassesScreen() }, to: prepareScreenshotDirectory())
    }

    func testCaptureAssignmentsScreen() throws {
        try snapshot("03-assignments", ScreenPreview { _ in AssignmentsScreen() }, to: prepareScreenshotDirectory())
    }

    func testCaptureAssignmentOverviewScreen() throws {
        try snapshot(
            "04-assignment-overview",
            ScreenPreview { app in RouteDestination(route: .assignment(PreviewFixtures.assignmentID), app: app) },
            to: prepareScreenshotDirectory()
        )
    }

    func testCaptureRubricInstructionsScreen() throws {
        try snapshot(
            "05-rubric-instructions",
            ScreenPreview { app in RouteDestination(route: .rubric(PreviewFixtures.assignmentID), app: app) },
            to: prepareScreenshotDirectory()
        )
    }

    func testCaptureStudentWorkScreen() throws {
        try snapshot(
            "06-student-work",
            ScreenPreview { app in RouteDestination(route: .submission(PreviewFixtures.noWorkSubmissionID), app: app) },
            to: prepareScreenshotDirectory()
        )
    }

    func testCaptureReviewScannedTextScreen() throws {
        try snapshot(
            "07-review-scanned-text",
            ScreenPreview { app in RouteDestination(route: .scannedText(PreviewFixtures.scannedSubmissionID), app: app) },
            to: prepareScreenshotDirectory()
        )
    }

    func testCaptureAIDraftScreen() throws {
        try snapshot(
            "08-ai-draft",
            ScreenPreview { app in RouteDestination(route: .aiDraft(PreviewFixtures.approvedSubmissionID), app: app) },
            to: prepareScreenshotDirectory()
        )
    }

    func testCaptureFinalReviewScreen() throws {
        try snapshot(
            "09-final-review",
            ScreenPreview { app in RouteDestination(route: .finalReview(PreviewFixtures.approvedSubmissionID), app: app) },
            to: prepareScreenshotDirectory()
        )
    }

    func testCaptureSubmissionExportsScreen() throws {
        try snapshot(
            "10-submission-exports",
            ScreenPreview { app in RouteDestination(route: .submissionExports(PreviewFixtures.approvedSubmissionID), app: app) },
            to: prepareScreenshotDirectory()
        )
    }

    func testCaptureExportsTabScreen() throws {
        try snapshot("11-exports-tab", ScreenPreview { _ in ExportsTabScreen() }, to: prepareScreenshotDirectory())
    }

    func testCaptureSettingsLocalPrivacyScreen() throws {
        try snapshot("12-settings-local-privacy", ScreenPreview { _ in SettingsAboutLocalPrivacyScreen() }, to: prepareScreenshotDirectory())
    }

    func testCaptureReviewScreen() throws {
        try snapshot("13-review", ScreenPreview { _ in ReviewScreen() }, to: prepareScreenshotDirectory())
    }

    func testCaptureClassDetailRosterScreen() throws {
        try snapshot(
            "14-class-detail-roster",
            ScreenPreview { app in RouteDestination(route: .classDetail(PreviewFixtures.classGroupID), app: app) },
            to: prepareScreenshotDirectory()
        )
    }

    func testCaptureCurriculumBrowserScreen() throws {
        try snapshot(
            "15-curriculum-browser",
            ScreenPreview { app in RouteDestination(route: .curriculum(assignmentID: PreviewFixtures.assignmentID), app: app) },
            to: prepareScreenshotDirectory()
        )
    }

    // MARK: - Rendering

    private func snapshot<V: View>(_ name: String, _ view: V, to dir: URL) throws {
        let image = render(view)
        let data = try XCTUnwrap(image.pngData())
        try data.write(to: dir.appendingPathComponent("\(name).png"))

        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The screens read the in-memory store and load their records asynchronously, so the run loop is given
    /// time to deliver them before the picture is taken.
    private func render<V: View>(_ view: V, size: CGSize = CGSize(width: 390, height: 844)) -> UIImage {
        let controller = UIHostingController(rootView: view)
        controller.overrideUserInterfaceStyle = .light
        controller.view.frame = CGRect(origin: .zero, size: size)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
        controller.view.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(bounds: controller.view.bounds)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    private func prepareScreenshotDirectory() throws -> URL {
        let docs = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let dir = docs.appendingPathComponent("GradeDraftScreenshots")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
