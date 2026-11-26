import XCTest

/// The three short how-to videos in Settings › Help, filmed from the real app (26 Nov). The ios-howto workflow records
/// the simulator while each of these walks one job at a viewer's pace, then cuts it to the app's screens and shrinks it
/// to play inside Tenzy. Only runs there (HOWTO_FILM=1), never in the normal test runs.
final class HowToFilmTests: XCTestCase {
    private var app: XCUIApplication!
    private var any: XCUIElementQuery { app.descendants(matching: .any) }

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["HOWTO_FILM"] == "1", "only for the how-to videos")
        continueAfterFailure = true
        app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "permission") { alert in
            for b in ["Allow", "Allow While Using App", "OK", "Allow Full Access"] where alert.buttons[b].exists { alert.buttons[b].tap(); return true }
            return false
        }
    }

    private func mark(_ name: String) { XCTContext.runActivity(named: name) { _ in } }

    /// 1 · Say what you need: the ask box turns one sentence into a helper that does the whole job.
    func testFilmSayWhatYouNeed() {
        app.launchArguments = ["-route", "home", "-uitest"]
        app.launch()
        let field = app.textFields["describe-field"].exists ? app.textFields["describe-field"] : app.textViews["describe-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 30))
        sleep(2); mark("FILM-START")
        field.tap()
        if app.buttons["Continue"].waitForExistence(timeout: 2) { app.buttons["Continue"].tap() }   // the keyboard's one-time tip
        sleep(1)
        field.typeText("Every evening, help me email today's screenshots to myself")
        sleep(2)
        any["describe-build"].firstMatch.tap()
        sleep(7)                                  // Tenzy puts the steps together, with an evening reminder
        mark("FILM-END")
    }

    /// 2 · Set an autorun: switch one on, tap Test run, see what it found and add it.
    func testFilmSetAnAutorun() {
        app.launchArguments = ["-route", "smartruns", "-uitest", "-seedreceipt"]
        app.launch()
        let on = any["smartrun-on-receipts"].firstMatch
        XCTAssertTrue(on.waitForExistence(timeout: 30))
        sleep(2); mark("FILM-START")
        if (on.value as? String) != "1" { on.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap() }
        sleep(1)
        app.staticTexts["Smart autoruns"].firstMatch.tap()   // lets the monitor answer the notifications prompt
        sleep(2)
        let test = any["smartrun-test-receipts"].firstMatch
        if test.waitForExistence(timeout: 10) { test.tap() }
        let check = any["smartrun-check-receipts"].firstMatch
        if check.waitForExistence(timeout: 120) { sleep(2); check.tap() }
        if any["smartreceipt-card"].firstMatch.waitForExistence(timeout: 10) { sleep(3) }
        let add = any["smartreceipts-add"].firstMatch
        if add.waitForExistence(timeout: 5) { add.tap() }
        sleep(4)
        mark("FILM-END")
    }

    /// 3 · Got something? Hand Tenzy a photo and pick what you want done.
    func testFilmGotSomething() {
        app.launchArguments = ["-route", "home", "-uitest", "-givephotos", "1"]
        app.launch()
        XCTAssertTrue(app.staticTexts["What do you want to do?"].waitForExistence(timeout: 90))
        sleep(3); mark("FILM-START")
        let goal = any.matching(NSPredicate(format: "identifier BEGINSWITH 'goal-'")).firstMatch
        if goal.waitForExistence(timeout: 10) { goal.tap() }
        sleep(3)
        let way = any.matching(NSPredicate(format: "identifier BEGINSWITH 'guide-' AND identifier != 'guide-more' AND identifier != 'guide-suggested'")).firstMatch
        if way.waitForExistence(timeout: 10) { way.tap() }
        sleep(9)                                  // the job runs on the photo and shows the result
        mark("FILM-END")
    }
}
