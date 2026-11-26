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
        sleep(2); mark("FILM-START"); sleep(2)      // the recorder starts on this mark; give it a moment
        field.tap()
        if app.buttons["Continue"].waitForExistence(timeout: 2) { app.buttons["Continue"].tap() }   // the keyboard's one-time tip
        sleep(1)
        field.typeText("Every evening, help me email today's screenshots to myself")
        sleep(2)
        any["describe-build"].firstMatch.tap()
        sleep(3)                                  // Tenzy puts the steps together, with an evening reminder…
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03)).tap()   // …and asks to send it: Allow
        sleep(6)
        mark("FILM-END")
    }

    /// 2 · Set an autorun: switch one on, tap Test run, see what it found and add it.
    func testFilmSetAnAutorun() {
        app.launchArguments = ["-route", "smartruns", "-uitest", "-seedreceipt"]
        app.launch()
        let on = any["smartrun-on-receipts"].firstMatch
        XCTAssertTrue(on.waitForExistence(timeout: 30))
        sleep(2); mark("FILM-START"); sleep(2)
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
        sleep(2); mark("FILM-START"); sleep(3)
        // "Send it" (smaller, private, the right format) works on any photo; the sample isn't one to cut out.
        let send = any["goal-share"].firstMatch
        let goal = send.waitForExistence(timeout: 10) ? send : any.matching(NSPredicate(format: "identifier BEGINSWITH 'goal-'")).firstMatch
        if goal.waitForExistence(timeout: 10) { goal.tap() }
        sleep(3)
        let way = any.matching(NSPredicate(format: "identifier BEGINSWITH 'guide-' AND identifier != 'guide-more' AND identifier != 'guide-suggested'")).firstMatch
        if way.waitForExistence(timeout: 10) { way.tap() }
        sleep(4)                                  // the photo arrives and the job starts looking at it
        // A simulator finds faces and writing far slower than a phone: the film skips that wait and shows what was found.
        let looking = any["scrub-detecting"].firstMatch
        if looking.exists {
            mark("FILM-PAUSE")
            let until = Date().addingTimeInterval(90)
            while looking.exists && Date() < until { sleep(1) }
            mark("FILM-RESUME")
        }
        sleep(5)
        mark("FILM-END")
    }
}
