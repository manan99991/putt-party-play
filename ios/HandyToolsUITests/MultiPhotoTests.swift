import XCTest

/// Your crash on 20 Nov (1.2.65): in Build your own, tap Photo, pick several photos → the app closed.
/// This hands over full-size phone photos through the same path a real pick takes, then walks every
/// choice the guide offers for them, one by one, and checks the app is still open after each.
final class MultiPhotoTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "system alert") { alert in
            for label in ["Allow", "OK", "Allow While Using App", "Allow Once", "Allow Full Access"] where alert.buttons[label].exists { alert.buttons[label].tap(); return true }
            return false
        }
    }

    private func launch(photos: Int) {
        app.launchArguments = ["-route", "home", "-uitest", "-givephotos", "\(photos)"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25), "Build your own did not launch")
    }

    private func alive(_ step: String) { XCTAssertEqual(app.state, .runningForeground, "crashed: \(step)") }

    /// Back one screen: the bar's back button where there is one, else the tool page's own Back, else an edge swipe.
    private func goBack() {
        let bar = app.navigationBars.buttons.firstMatch
        if bar.exists, bar.isHittable { bar.tap(); return }
        let back = app.buttons.matching(NSPredicate(format: "label ==[c] 'Back' OR identifier ==[c] 'back'")).firstMatch
        if back.exists, back.isHittable { back.tap(); return }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
    }

    private func goals() -> [String] {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'goal-'")).allElementsBoundByIndex.map(\.identifier)
    }

    /// "Got something?" → a photo → Send it → Privacy Scrubber: the photo is already in the tool (26 Nov — the how-to film
    /// showed "Choose a photo or video" instead: the scrubber's face and text search held the screen before it could show).
    func testAPhotoHandedToTheScrubberShowsUp() {
        launch(photos: 1)
        XCTAssertTrue(app.staticTexts["What do you want to do?"].waitForExistence(timeout: 90), "guide never opened")
        let send = app.descendants(matching: .any)["goal-share"].firstMatch
        XCTAssertTrue(send.waitForExistence(timeout: 10), "no Send it")
        send.tap()
        let scrub = app.descendants(matching: .any)["guide-scrub"].firstMatch
        XCTAssertTrue(scrub.waitForExistence(timeout: 10), "no Privacy Scrubber under Send it: \(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'guide-'")).allElementsBoundByIndex.map(\.identifier))")
        scrub.tap()
        XCTAssertTrue(app.buttons["Choose a different photo or video"].waitForExistence(timeout: 8),
                      "the photo didn't arrive in the scrubber within 8 s (it still asks to choose one: \(app.buttons["Choose a photo or video"].exists))")
        alive("scrubber with the handed-over photo")
    }

    func testPickingManyPhotosOpensTheGuide() {
        for n in [1, 2, 8, 20] {
            launch(photos: n)
            XCTAssertTrue(app.staticTexts["What do you want to do?"].waitForExistence(timeout: 90), "guide never opened for \(n) photos")
            sleep(4)   // let the guess and the previews finish
            alive("\(n) photos, guide open")
            app.terminate()
        }
    }

    func testEveryChoiceForSixPhotosOpensWithoutClosingTheApp() {
        launch(photos: 6)
        XCTAssertTrue(app.staticTexts["What do you want to do?"].waitForExistence(timeout: 90), "guide never opened")
        sleep(3)
        let ids = goals()
        XCTAssertFalse(ids.isEmpty, "no choices shown for 6 photos")
        for id in ids {
            let tile = app.descendants(matching: .any)[id].firstMatch
            if !tile.isHittable { app.swipeUp() }
            guard tile.waitForExistence(timeout: 10) else { continue }
            tile.tap()
            sleep(3)
            alive("after choosing \(id)")
            // Open the first way to do it, wait for the tool to start on the photos, then come back.
            let ways = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'guide-' AND identifier != 'guide-more' AND identifier != 'guide-suggested'"))
            if ways.firstMatch.waitForExistence(timeout: 8) {
                ways.firstMatch.tap()
                sleep(6)
                alive("after opening the first way under \(id)")
                goBack()
                sleep(1)
            }
            goBack()
            sleep(1)
            alive("back from \(id)")
        }
    }
}
