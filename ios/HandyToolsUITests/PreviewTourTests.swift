import XCTest

/// The App Store video, filmed from the real app: the workflow records the simulator screen while this walks
/// through Home → the 10-second demo → every tool one tap away → "say it, Tenzy builds it". Paced for a viewer,
/// so it only runs from the ios-preview workflow (PREVIEW_TOUR=1), never in the normal test runs.
final class PreviewTourTests: XCTestCase {
    func testStoreVideoTour() throws {
        let mode = ProcessInfo.processInfo.environment["PREVIEW_TOUR"] ?? ""
        try XCTSkipUnless(mode == "1" || mode == "warm", "only for the store video")
        let app = XCUIApplication()
        app.launchArguments = ["-route", "home", "-uitest", "-resetfirsttry"]
        app.launch()
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["first-try"].waitForExistence(timeout: 30))
        let field = app.textFields["describe-field"].exists ? app.textFields["describe-field"] : app.textViews["describe-field"]
        if mode == "warm" {
            // Warm-up (not filmed): run the demo once so the phone's text and face models are loaded for the take,
            // and clear the simulator's one-time keyboard tip.
            any["first-try"].tap()
            _ = app.staticTexts["Your result"].waitForExistence(timeout: 90)
            if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }
            field.tap()
            if app.buttons["Continue"].waitForExistence(timeout: 3) { app.buttons["Continue"].tap() }
            return
        }

        sleep(2)
        mark("PLAY")                               // the film shows 1 s of Home before this, then the tour
        sleep(1)

        any["first-try"].tap()                     // a real job on a sample: hidden, stripped, shrunk
        mark("DEMO-TAP")
        _ = app.staticTexts["Your result"].waitForExistence(timeout: 90)   // slow on the simulator; the wait is cut
        mark("DEMO-RESULT")
        sleep(2)                                   // the result, on screen
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }

        let shelf = any["shelf-phone"]             // every tool, one tap away
        if shelf.waitForExistence(timeout: 5) { shelf.tap() }
        sleep(2)
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }

        field.tap()
        field.typeText("Shrink a photo and email it")
        any["describe-build"].tap()                // Tenzy builds it, step by step
        sleep(4)
        mark("TOUR-END")
    }

    /// A line in the test log the workflow times, so the video starts and stops exactly on the tour.
    private func mark(_ name: String) { XCTContext.runActivity(named: name) { _ in } }
}
