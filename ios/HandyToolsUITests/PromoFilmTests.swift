import XCTest

/// The promo video's five scenes, filmed from the real app on the 6.9-inch simulator (28 Nov, Manan's store video).
/// The ios-promo workflow records the simulator while each walks one job at a viewer's pace, cuts it on FILM-START /
/// FILM-END, and pulls a store-size still at every FILM-SHOT. Only runs there (PROMO_FILM=1), never in normal runs.
final class PromoFilmTests: XCTestCase {
    private var app: XCUIApplication!
    private var any: XCUIElementQuery { app.descendants(matching: .any) }

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PROMO_FILM"] == "1", "only for the promo film")
        continueAfterFailure = true
        app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "permission") { alert in
            for b in ["Allow", "Allow While Using App", "OK", "Allow Full Access"] where alert.buttons[b].exists { alert.buttons[b].tap(); return true }
            return false
        }
    }

    private var shot = 0
    private func mark(_ name: String) {
        XCTContext.runActivity(named: "\(name)@\(String(format: "%.2f", Date().timeIntervalSince1970))") { _ in }
        // A still at every shot, straight from the screen at full resolution, written where the workflow collects it
        // (the simulator shares the Mac's disk). Cutting stills from the film by time was off by seconds (28 Nov).
        if name == "FILM-SHOT", let dir = ProcessInfo.processInfo.environment["PROMO_DIR"], !dir.isEmpty {
            shot += 1
            let n = (name: String(describing: self.name).components(separatedBy: " ").last?.replacingOccurrences(of: "]", with: "") ?? "scene", k: shot)
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(n.name)-shot\(n.k).png"))
        }
    }
    /// Looks now and then, never continuously (a continuous wait starves the app's main thread in this Xcode).
    private func appears(_ e: XCUIElement, within seconds: Int) -> Bool {
        for _ in 0..<max(1, seconds / 2) { if e.exists { return true }; sleep(2) }
        return e.exists
    }
    private func tap(_ id: String) {
        let b = app.buttons[id]
        (b.exists ? b : any[id].firstMatch).tap()
    }

    /// 1 · Say it: one sentence becomes a weekly reminder.
    func testPromoSayIt() {
        app.launchArguments = ["-route", "home", "-uitest"]
        app.launch()
        let field = app.textFields["describe-field"].exists ? app.textFields["describe-field"] : app.textViews["describe-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 30))
        sleep(2); mark("FILM-START"); sleep(2)
        mark("FILM-SHOT")
        field.tap()
        if app.buttons["Continue"].waitForExistence(timeout: 2) { app.buttons["Continue"].tap() }
        field.typeText("Remind me every Monday to put the bins out")
        sleep(1); mark("FILM-SHOT")
        tap("describe-build")
        sleep(2)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03)).tap()   // answers the notifications question
        _ = appears(any["reminder-set-text"].firstMatch, within: 20)
        sleep(2); mark("FILM-SHOT"); sleep(2)
        mark("FILM-END")
    }

    /// 2 · Snap it: the camera takes a receipt, and Tenzy says what it can do with it.
    func testPromoCamera() {
        app.launchArguments = ["-route", "home", "-uitest", "-homecam"]
        app.launch()
        XCTAssertTrue(any["home-camera"].firstMatch.waitForExistence(timeout: 30))
        sleep(2); mark("FILM-START"); sleep(1)
        tap("home-camera")
        sleep(2); mark("FILM-SHOT"); sleep(1)
        tap("homecam-shutter")
        _ = appears(any["guide-suggested"].firstMatch, within: 40)
        sleep(2); mark("FILM-SHOT"); sleep(2)
        mark("FILM-END")
    }

    /// 3 · Free space: copies found and picked in one tap.
    func testPromoFreeSpace() {
        app.launchArguments = ["-route", "cleaner", "-uitest", "-seeddupes"]
        app.launch()
        let pick = any["keep-newest-select"].firstMatch
        _ = appears(pick, within: 90)
        sleep(2); mark("FILM-START"); sleep(2)
        mark("FILM-SHOT")
        if pick.exists { pick.tap() }
        sleep(2); mark("FILM-SHOT"); sleep(2)
        mark("FILM-END")
    }

    /// 4 · Post it: a clip made the right shape for Reels, TikTok or Shorts.
    func testPromoSocial() {
        app.launchArguments = ["-route", "post", "-uitest", "-sample"]
        app.launch()
        let make = any["post-make"].firstMatch
        _ = appears(make, within: 60)
        sleep(2); mark("FILM-START"); sleep(2)
        mark("FILM-SHOT")
        if make.exists { make.tap() }
        _ = appears(any["post-ready"].firstMatch, within: 90)
        sleep(2); mark("FILM-SHOT"); sleep(2)
        mark("FILM-END")
    }

    /// 5 · Sign it: the form gets signed where it asks.
    func testPromoSign() {
        app.launchArguments = ["-route", "pdfsign", "-uitest", "-sample"]
        app.launch()
        let auto = any["sign-auto"].firstMatch
        _ = appears(auto, within: 40)
        sleep(2); mark("FILM-START"); sleep(2)
        mark("FILM-SHOT")
        if auto.exists { auto.tap() }
        sleep(5); mark("FILM-SHOT"); sleep(2)
        mark("FILM-END")
    }
}
