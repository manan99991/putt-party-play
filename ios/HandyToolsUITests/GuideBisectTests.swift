import XCTest

/// Your 20 Nov crash: the suggested choice's preview picture (a 2×2 of your photos) closes the app when the
/// screen is read. Each test draws that picture a different way; the one that survives is the fix.
final class GuideBisectTests: XCTestCase {
    private func survives(skipping skip: String, photos: Int = 2) {
        let app = XCUIApplication()
        var args = ["-route", "home", "-uitest", "-givephotos", "\(photos)"]
        if !skip.isEmpty { args += ["-guideskip", skip] }
        app.launchArguments = args
        app.launch()
        sleep(12)
        let found = app.staticTexts["What do you want to do?"].waitForExistence(timeout: 30)
        sleep(2)
        let alive = app.state == .runningForeground
        print("BISECT skip=[\(skip)] read=\(found) alive=\(alive)")
        XCTAssertTrue(found && alive, "skip=[\(skip)] closed the app")
    }
    func test1_asShipped() { survives(skipping: "") }
    func test2_withoutTheBadge() { survives(skipping: "nobadge") }
    func test3_decorativePicture() { survives(skipping: "flat") }
    func test4_drawnByUIKit() { survives(skipping: "uikit") }
    func test5_noPreview() { survives(skipping: "preview") }
}
