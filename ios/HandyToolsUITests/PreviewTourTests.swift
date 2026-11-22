import XCTest

/// The App Store video, filmed from the real app: the workflow records the simulator screen while this walks
/// through Home → the 10-second demo → "say it, Tenzy builds it" → every tool one tap away. Paced for a viewer,
/// so it only runs from the ios-preview workflow (PREVIEW_TOUR=1), never in the normal test runs.
final class PreviewTourTests: XCTestCase {
    func testStoreVideoTour() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PREVIEW_TOUR"] == "1", "only for the store video")
        let app = XCUIApplication()
        app.launchArguments = ["-route", "home", "-uitest"]
        app.launch()
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["first-try"].waitForExistence(timeout: 30))
        mark("TOUR-START")                         // the workflow cuts the video from here (30 s in all)
        sleep(2)                                   // the headline and Home, still

        any["first-try"].tap()                     // a real job on a sample: hidden, stripped, shrunk
        sleep(5)
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }

        let field = app.textFields["describe-field"].exists ? app.textFields["describe-field"] : app.textViews["describe-field"]
        field.tap()
        field.typeText("Shrink a photo, remove location, email it")
        sleep(1)
        any["describe-build"].tap()                // Tenzy builds it, step by step
        sleep(4)
        backHome(app)

        let shelf = any["shelf-phone"]
        if shelf.waitForExistence(timeout: 5) { shelf.tap() }   // every tool, one tap away
        sleep(2)
        if any["shelf-tool-light"].exists { any["shelf-tool-light"].tap() }
        sleep(2)
        mark("TOUR-END")
    }

    /// Close whatever the build opened (the editor, a confirmation, the keyboard) and land on Home again.
    private func backHome(_ app: XCUIApplication) {
        for label in ["Cancel", "Discard", "Discard Changes", "Done"] where app.buttons[label].firstMatch.exists {
            app.buttons[label].firstMatch.tap(); sleep(1)
        }
        if !app.descendants(matching: .any)["shelf-phone"].isHittable { app.swipeDown(velocity: .fast); sleep(1) }
    }

    /// A line in the test log the workflow times, so the video starts and stops exactly on the tour.
    private func mark(_ name: String) { XCTContext.runActivity(named: name) { _ in } }
}
