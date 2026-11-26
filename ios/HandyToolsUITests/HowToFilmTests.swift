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

    /// Looks now and then rather than continuously. In this Xcode every look runs inside the app, on its main thread:
    /// a continuous wait over the whole screen starved the app (26 Nov) — the autorun film froze once and ran five
    /// times slower the next time, and the sampler caught the app's main thread inside XCTest's query.
    private func appears(_ e: XCUIElement, within seconds: Int) -> Bool {
        for _ in 0..<max(1, seconds / 2) { if e.exists { return true }; sleep(2) }
        return e.exists
    }

    /// 2 · Set an autorun: switch one on, tap Test run, see what it found and add it.
    func testFilmSetAnAutorun() {
        app.launchArguments = ["-route", "smartruns", "-uitest", "-seedreceipt"]
        app.launch()
        let on = any["smartrun-on-receipts"].firstMatch
        XCTAssertTrue(on.waitForExistence(timeout: 30))
        let toggle = { on.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap() }
        sleep(3)
        // Off camera: switch it on once so iPhone's notifications question is answered, then off again.
        if (on.value as? String) != "1" { toggle(); sleep(1); app.staticTexts["Smart autoruns"].firstMatch.tap(); sleep(3) }
        if (on.value as? String) == "1" { toggle(); sleep(2) }
        mark("FILM-START"); sleep(5)              // the recorder starts on this mark; give it a moment
        toggle()
        sleep(2)
        let test = app.buttons["smartrun-test-receipts"]
        (test.exists ? test : any["smartrun-test-receipts"].firstMatch).tap()
        let check = app.buttons["smartrun-check-receipts"]
        if appears(check, within: 120) { sleep(2); check.tap() }
        if appears(any["smartreceipt-card"].firstMatch, within: 10) { sleep(3) }
        let add = app.buttons["smartreceipts-add"]
        if appears(add, within: 6) { add.tap() }
        sleep(4)
        mark("FILM-END")
    }

    /// 3 · Got something? Hand Tenzy a photo and pick what you want done.
    func testFilmGotSomething() {
        app.launchArguments = ["-route", "home", "-uitest", "-givephotos", "1"]
        app.launch()
        XCTAssertTrue(app.staticTexts["What do you want to do?"].waitForExistence(timeout: 90))
        sleep(2); mark("FILM-START"); sleep(5)
        // "Send it" (smaller, private, the right format) works on any photo; Privacy Scrubber is its first way.
        let send = app.buttons["goal-share"]
        (send.exists ? send : any["goal-share"].firstMatch).tap()
        sleep(3)
        let way = app.buttons["guide-tool-scrub"]
        (way.exists ? way : any["guide-tool-scrub"].firstMatch).tap()
        sleep(4)                                  // the photo arrives and the job starts looking at it
        // A simulator finds faces and writing far slower than a phone: the film skips that wait and shows what was found.
        let looking = any["scrub-detecting"].firstMatch
        if looking.exists {
            mark("FILM-PAUSE")
            let until = Date().addingTimeInterval(90)
            while looking.exists && Date() < until { sleep(2) }
            mark("FILM-RESUME")
        }
        sleep(5)
        mark("FILM-END")
    }
}
