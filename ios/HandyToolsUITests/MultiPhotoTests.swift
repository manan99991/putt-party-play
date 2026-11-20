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

    private func goals() -> [String] {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'goal-'")).allElementsBoundByIndex.map(\.identifier)
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
                app.navigationBars.buttons.element(boundBy: 0).tap()
                sleep(1)
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
            alive("back from \(id)")
        }
    }
}
