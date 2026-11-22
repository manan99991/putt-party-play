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
        sleep(3)                                   // the headline and Home, still

        any["first-try"].tap()                     // a real job on a sample: hidden, stripped, shrunk
        sleep(7)
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }
        sleep(1)

        let field = app.textFields["describe-field"].exists ? app.textFields["describe-field"] : app.textViews["describe-field"]
        field.tap()
        field.typeText("Shrink a photo under 1 MB and hide where it was taken")
        sleep(1)
        any["describe-build"].tap()                // Tenzy builds it
        sleep(6)
        if app.buttons["Cancel"].firstMatch.exists { app.buttons["Cancel"].firstMatch.tap() } else { app.swipeDown(velocity: .fast) }
        sleep(1)

        any["shelf-phone"].tap()                   // every tool, one tap away
        sleep(3)
        if any["shelf-tool-light"].exists { any["shelf-tool-light"].tap() }
        sleep(4)
    }
}
