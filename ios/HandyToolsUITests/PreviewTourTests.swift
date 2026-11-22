import XCTest

/// The App Store video, filmed from the real app: the workflow records the simulator screen while this walks
/// through Home → the 10-second demo → every tool one tap away → "say it, Tenzy builds it". Paced for a viewer,
/// so it only runs from the ios-preview workflow (PREVIEW_TOUR=1), never in the normal test runs.
final class PreviewTourTests: XCTestCase {
    func testStoreVideoTour() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PREVIEW_TOUR"] == "1", "only for the store video")
        let app = XCUIApplication()
        app.launchArguments = ["-route", "home", "-uitest"]
        app.launch()
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["first-try"].waitForExistence(timeout: 30))
        // The simulator's one-time keyboard tip would cover half the video: open and close the keyboard once first.
        let field = app.textFields["describe-field"].exists ? app.textFields["describe-field"] : app.textViews["describe-field"]
        field.tap()
        if app.buttons["Continue"].waitForExistence(timeout: 2) { app.buttons["Continue"].tap() }
        app.swipeDown(velocity: .fast)
        sleep(1)

        mark("TOUR-START")                         // the workflow cuts the video from here (30 s in all)
        sleep(2)                                   // the headline and Home, still

        any["first-try"].tap()                     // a real job on a sample: hidden, stripped, shrunk
        _ = app.staticTexts["Your result"].waitForExistence(timeout: 12)
        sleep(2)                                   // the result, on screen
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }
        sleep(1)

        let shelf = any["shelf-phone"]             // every tool, one tap away
        if shelf.waitForExistence(timeout: 5) { shelf.tap() }
        sleep(3)
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }
        sleep(1)

        field.tap()
        field.typeText("Shrink a photo, remove location, email it")
        any["describe-build"].tap()                // Tenzy builds it, step by step
        sleep(5)
        mark("TOUR-END")
    }

    /// A line in the test log the workflow times, so the video starts and stops exactly on the tour.
    private func mark(_ name: String) { XCTContext.runActivity(named: name) { _ in } }
}
