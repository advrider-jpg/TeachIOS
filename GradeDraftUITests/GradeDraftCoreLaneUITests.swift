import XCTest

/// Both tests launch the DEBUG build against the shared preview fixture (`PreviewFixtures`): one class,
/// one assignment, and three students whose work is "none", "scanned text needing review" and
/// "approved final grade". On-device AI is reported unavailable, so the lane uses the manual final review.
@MainActor
final class GradeDraftCoreLaneUITests: XCTestCase {
    // IDs from PreviewFixtures (uppercase, as `UUID.uuidString` prints them).
    private let assignmentID = "6F1A0C2E-0000-4000-8000-000000000002"
    private let scannedSubmissionID = "6F1A0C2E-0000-4000-8000-000000000012"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Smoke flow

    func testCoreNavigationAndExportGateSurfacesRealWorkflowState() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-smoke-test"]
        app.launch()

        XCTAssertTrue(
            element("home.aiStatus", in: app).waitForExistence(timeout: 10),
            "The app must launch into the Home screen before any grading workflow can be trusted."
        )

        tapTab("Assignments", in: app)
        XCTAssertTrue(
            element("assignments.row.\(assignmentID)", in: app).waitForExistence(timeout: 10),
            "The fixture assignment must be listed on the Assignments tab."
        )

        tapTab("Exports", in: app)
        let approvedStudent = element("exportsTab.submission.0", in: app)
        XCTAssertTrue(
            approvedStudent.waitForExistence(timeout: 10),
            "The student whose final grade is approved and current must be listed as ready to export."
        )
        XCTAssertTrue(element("exportsTab.createBackup", in: app).exists, "The Exports tab must offer backup.")

        approvedStudent.tap()
        let studentReport = app.buttons["exports.studentMarkdown"]
        XCTAssertTrue(studentReport.waitForExistence(timeout: 5))
        XCTAssertTrue(studentReport.isEnabled, "An approved, current final grade must allow the student report.")
    }

    // MARK: - Core lane with accessibility audit (T17)

    func testCoreLaneAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-core-lane-test"]
        app.launch()

        // Home -> the student whose scanned text needs review.
        let row = element("home.needsReview.\(scannedSubmissionID)", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The scanned submission must be listed under Needs your review.")
        try app.performAccessibilityAudit()
        row.tap()

        // Student work.
        let scannedText = element("studentWork.scannedText", in: app)
        XCTAssertTrue(scannedText.waitForExistence(timeout: 10))
        try app.performAccessibilityAudit()
        scannedText.tap()

        // Scanned text review: "Confirm all" must leave the low-confidence line (index 1) unresolved.
        let confirmAll = app.buttons["scannedText.confirmAll"]
        XCTAssertTrue(confirmAll.waitForExistence(timeout: 10))
        let markReviewed = app.buttons["scannedText.markReviewed"]
        XCTAssertFalse(markReviewed.isEnabled, "Scanned text cannot be marked reviewed while a line needs action.")
        confirmAll.tap()
        reveal(markReviewed, in: app)
        XCTAssertFalse(markReviewed.isEnabled, "Confirm all must not confirm the low-confidence line.")
        let confirmLowConfidence = app.buttons["scannedText.lineConfirm.1"]
        reveal(confirmLowConfidence, in: app)
        confirmLowConfidence.tap()
        reveal(markReviewed, in: app)
        waitUntil("Mark Scanned Text Reviewed becomes available once every line is resolved") { markReviewed.isEnabled }
        try app.performAccessibilityAudit()
        markReviewed.tap()
        tapDialogButton(identifier: "scannedText.markReviewedConfirm", label: "Mark Reviewed", in: app)
        waitUntil("The scanned text is marked reviewed") { !markReviewed.isEnabled }
        goBack(in: app)

        // Final review: start manually (AI is unavailable on the fixture).
        let finalReviewLink = element("studentWork.finalReview", in: app)
        reveal(finalReviewLink, in: app)
        finalReviewLink.tap()
        let startManual = app.buttons["finalReview.startManual"]
        XCTAssertTrue(startManual.waitForExistence(timeout: 10))
        try app.performAccessibilityAudit()
        waitUntil("Start Manual Final Review is enabled") { startManual.isEnabled }
        startManual.tap()

        // Not approved yet: the student-facing exports are blocked.
        let exportsLink = element("finalReview.exports", in: app)
        reveal(exportsLink, in: app)
        try app.performAccessibilityAudit()
        exportsLink.tap()
        let studentMarkdown = app.buttons["exports.studentMarkdown"]
        XCTAssertTrue(studentMarkdown.waitForExistence(timeout: 10))
        XCTAssertFalse(studentMarkdown.isEnabled, "Student reports must be blocked before the final grade is approved.")
        try app.performAccessibilityAudit()
        goBack(in: app)

        // Accept all three rubric criteria, then approve.
        for index in 0..<3 {
            let accept = app.buttons["finalReview.accept.\(index)"]
            reveal(accept, in: app)
            accept.tap()
        }
        let approve = app.buttons["finalReview.approve"]
        reveal(approve, in: app)
        waitUntil("Approve Final Grade is enabled once every criterion is accepted") { approve.isEnabled }
        try app.performAccessibilityAudit()
        approve.tap()
        tapDialogButton(identifier: "finalReview.approveConfirm", label: "Approve Final Grade", in: app)

        // Approved and current: the student report is now allowed.
        let exportsAfterApproval = element("finalReview.exports", in: app)
        reveal(exportsAfterApproval, in: app)
        exportsAfterApproval.tap()
        XCTAssertTrue(studentMarkdown.waitForExistence(timeout: 10))
        waitUntil("The student report is allowed after approval") { studentMarkdown.isEnabled }
        try app.performAccessibilityAudit()
    }

    // MARK: - Helpers

    /// Any element carrying the identifier (rows and links report as different element types).
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func tapTab(_ name: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Could not find the \(name) tab.")
        tab.tap()
    }

    private func goBack(in app: XCUIApplication) {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Could not find the back button.")
        back.tap()
    }

    /// Scrolls the list until the element can be tapped.
    private func reveal(_ target: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(target.waitForExistence(timeout: 10), "Element never appeared: \(target)")
        var swipes = 0
        while !target.isHittable && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        swipes = 0
        while !target.isHittable && swipes < 16 {
            app.swipeDown()
            swipes += 1
        }
        XCTAssertTrue(target.isHittable, "Could not scroll to \(target)")
    }

    /// Confirmation-dialog buttons: by identifier, else by visible label (the topmost match).
    private func tapDialogButton(identifier: String, label: String, in app: XCUIApplication) {
        let byIdentifier = app.buttons[identifier]
        if byIdentifier.waitForExistence(timeout: 3) {
            byIdentifier.tap()
            return
        }
        let byLabel = app.buttons.matching(NSPredicate(format: "label == %@", label)).allElementsBoundByIndex
        guard let button = byLabel.last(where: { $0.exists && $0.isHittable }) else {
            XCTFail("Could not find the \(label) confirmation button.")
            return
        }
        button.tap()
    }

    private func waitUntil(_ description: String, timeout: TimeInterval = 10, _ condition: @escaping () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        XCTAssertTrue(condition(), "Timed out: \(description).")
    }
}
