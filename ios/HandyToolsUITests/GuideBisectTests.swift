import XCTest

/// Finds which part of the "What do you want to do?" screen closes the app when several photos are handed
/// over and the screen is read (VoiceOver, Voice Control, a UI test). One test per version, so a crash in
/// one doesn't hide the others.
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
    func test1_everything() { survives(skipping: "") }
    func test2_noSuggestion() { survives(skipping: "suggest") }
    func test3_noPreviewPicture() { survives(skipping: "preview") }
    func test4_noGoalTiles() { survives(skipping: "grid") }
    func test5_noHeader() { survives(skipping: "header") }
    func test6_noSuggestionNoGrid() { survives(skipping: "suggest,grid") }
    func test7_onePhoto() { survives(skipping: "", photos: 1) }
}
