import XCTest

@MainActor
final class GradeDraftCoreLaneUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCoreNavigationAndExportGateSurfacesRealWorkflowState() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-smoke-test"]
        app.launch()

        XCTAssertTrue(
            app.buttons["Home"].waitForExistence(timeout: 10) || app.staticTexts["Home"].waitForExistence(timeout: 10),
            "The app must launch into a real first screen before any grading workflow can be trusted."
        )

        tapTab(named: "Assignments", in: app)
        XCTAssertTrue(
            app.staticTexts["Assignments"].waitForExistence(timeout: 5) || app.navigationBars["Assignments"].waitForExistence(timeout: 5),
            "Assignments must be reachable through the app shell."
        )

        tapTab(named: "Exports", in: app)
        XCTAssertTrue(
            app.staticTexts["Exports & Backup"].waitForExistence(timeout: 5) || app.navigationBars["Exports & Backup"].waitForExistence(timeout: 5),
            "The export surface must be reachable as a real screen, not a placeholder route."
        )
        XCTAssertTrue(
            app.staticTexts["No exports yet"].exists || app.staticTexts["Create Export"].exists,
            "The export screen must expose actual export state or real export creation controls."
        )
        XCTAssertFalse(
            app.buttons["Share Export"].exists && app.staticTexts["No exports yet"].exists,
            "The UI must not offer sharing when no export artifact has actually been prepared."
        )
    }

    private func tapTab(named name: String, in app: XCUIApplication) {
        if app.tabBars.buttons[name].waitForExistence(timeout: 5) {
            app.tabBars.buttons[name].tap()
        } else if app.buttons[name].waitForExistence(timeout: 5) {
            app.buttons[name].tap()
        } else {
            XCTFail("Could not find \(name) tab or button.")
        }
    }

    func testCoreLaneApprovesFinalReviewAndExportsOnlyAfterConfirmation() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-core-lane-test"]
        app.launch()

        tapTab(named: "Assignments", in: app)
        tapTextOrButton(named: "UI Core Lane Assignment", in: app)
        tapButton(named: "Start Guided Grading", in: app, scrolls: true)

        XCTAssertTrue(app.navigationBars["Guided Grading"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Share Student Report")).firstMatch.exists)

        tapButton(named: "Open Final Review", in: app, scrolls: true)
        tapButton(named: "Approve Final Grade", in: app, scrolls: true)
        tapButton(named: "Approve Final Grade", in: app, scrolls: false)
        XCTAssertTrue(
            app.staticTexts["Approved"].waitForExistence(timeout: 5) ||
            app.staticTexts["Ready"].waitForExistence(timeout: 5),
            "Approving the final review should update the UI to a real approved/export-ready state."
        )

        app.navigationBars.buttons.element(boundBy: 0).tap()
        tapButton(named: "Next", in: app, scrolls: false)
        tapButton(named: "Create Student Report PDF", in: app, scrolls: true)

        acknowledgeVisibleSwitches(in: app)
        tapFirstAvailableButton(["Preview PDF", "Preview Report", "Continue to Export"], in: app, scrolls: true)
        acknowledgeVisibleSwitches(in: app)
        tapFirstAvailableButton(["Export", "Export PDF", "Export Student Report"], in: app, scrolls: true)

        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Share Student Report")).firstMatch.waitForExistence(timeout: 10),
            "The share affordance must appear only after the confirmed export creates a real local artifact."
        )
    }

    private func tapTextOrButton(named name: String, in app: XCUIApplication) {
        if app.buttons[name].waitForExistence(timeout: 5) {
            app.buttons[name].tap()
        } else if app.staticTexts[name].waitForExistence(timeout: 5) {
            app.staticTexts[name].tap()
        } else {
            XCTFail("Could not find \(name).")
        }
    }

    private func tapButton(named name: String, in app: XCUIApplication, scrolls: Bool) {
        let button = app.buttons[name]
        if button.waitForExistence(timeout: 3) {
            button.tap()
            return
        }
        if scrolls {
            for _ in 0..<6 {
                app.swipeUp()
                if button.waitForExistence(timeout: 1) {
                    button.tap()
                    return
                }
            }
        }
        XCTFail("Could not find button \(name).")
    }

    private func tapFirstAvailableButton(_ names: [String], in app: XCUIApplication, scrolls: Bool) {
        for name in names where app.buttons[name].waitForExistence(timeout: 1) {
            app.buttons[name].tap()
            return
        }
        if scrolls {
            for _ in 0..<6 {
                app.swipeUp()
                for name in names where app.buttons[name].waitForExistence(timeout: 1) {
                    app.buttons[name].tap()
                    return
                }
            }
        }
        XCTFail("Could not find any button: \(names.joined(separator: ", ")).")
    }

    private func acknowledgeVisibleSwitches(in app: XCUIApplication) {
        for _ in 0..<8 {
            let switches = app.switches.allElementsBoundByIndex
            if switches.isEmpty { break }
            var changed = false
            for toggle in switches where toggle.exists && toggle.isHittable && (toggle.value as? String) != "1" {
                toggle.tap()
                changed = true
            }
            if !changed { break }
            app.swipeUp()
        }
    }
}
