import XCTest

/// 26 Nov (Manan: "camera button for tools that might need a camera directly in the app"): every tool that works on a
/// photo or video takes one right there. With `-fakecamera` the camera hands over a generated picture or clip at once,
/// so each test proves the tool actually received it and moved on — not just that a button exists.
final class CameraButtonTests: XCTestCase {
    private func open(_ route: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-route", route, "-uitest", "-fakecamera"]
        app.launch()
        return app
    }

    /// Looks now and then, never continuously (a continuous wait starves the app's main thread in this Xcode).
    private func appears(_ e: XCUIElement, within seconds: Int) -> Bool {
        for _ in 0..<max(1, seconds / 2) { if e.exists { return true }; sleep(2) }
        return e.exists
    }

    private func tap(_ app: XCUIApplication, _ id: String, _ file: StaticString = #filePath, _ line: UInt = #line) {
        let b = app.buttons[id].firstMatch
        XCTAssertTrue(b.waitForExistence(timeout: 30), "no \(id) button — \(PromiseTests.onScreen(app))", file: file, line: line)
        var swipes = 0
        while b.exists && !b.isHittable && swipes < 6 { app.swipeUp(); swipes += 1 }
        sleep(1)
        b.tap()
    }

    func testPhotoStudioTakesAPhoto() {
        let app = open("studio")
        tap(app, "tool-camera")
        let job = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'studio-job-'")).firstMatch
        XCTAssertTrue(appears(job, within: 20), "the photo didn't reach Photo Studio — \(PromiseTests.onScreen(app))")
    }

    func testTranslateReadsAPhotoItTook() {
        let app = open("translate")
        let photo = app.buttons["Photo"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 30))
        photo.tap()
        tap(app, "tool-camera")
        // The words it read show under "Original text" (a disclosure: a button, or text on some systems).
        let read = app.buttons["Original text"].firstMatch
        var seen = false
        for _ in 0..<20 where !seen { seen = read.exists || app.staticTexts["Original text"].exists || app.staticTexts["No text found in that photo."].exists; if !seen { sleep(2) } }
        XCTAssertTrue(seen, "Translate didn't read the photo it took — \(PromiseTests.onScreen(app))")
    }

    func testPriceCheckReadsAShelfPhoto() {
        let app = open("pricecheck")
        tap(app, "tool-camera")
        let said = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Found ' OR label BEGINSWITH 'Couldn'")).firstMatch
        XCTAssertTrue(appears(said, within: 40), "Price check didn't read the photo it took — \(PromiseTests.onScreen(app))")
    }

    func testFitUnderALimitTakesAPhoto() {
        let app = open("fitit")
        tap(app, "tool-camera")
        let fit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Fit under'")).firstMatch
        XCTAssertTrue(appears(fit, within: 20), "the photo didn't reach Fit Under a Limit — \(PromiseTests.onScreen(app))")
    }

    func testPrivacyScrubberTakesAPhoto() {
        let app = open("scrub")
        tap(app, "tool-camera")
        XCTAssertTrue(appears(app.buttons["Choose a different photo or video"].firstMatch, within: 30),
                      "the photo didn't reach the Scrubber — \(PromiseTests.onScreen(app))")
    }

    func testReadyToSendTakesAPhoto() {
        let app = open("shareready")
        tap(app, "tool-camera")
        let ready = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '1 file ready'")).firstMatch
        XCTAssertTrue(appears(ready, within: 20), "the photo didn't join the queue — \(PromiseTests.onScreen(app))")
    }

    func testCelebrateRecordsAClip() {
        let app = open("celebrate")
        tap(app, "tool-record")
        let preview = app.descendants(matching: .any)["celebrate-preview"].firstMatch
        XCTAssertTrue(appears(preview, within: 60), "the recorded clip didn't open in Celebrate — \(PromiseTests.onScreen(app))")
    }

    func testVideoRecordsAClip() {
        let app = open("video")
        tap(app, "tool-record")
        XCTAssertTrue(appears(app.buttons["Choose a different video"].firstMatch, within: 60),
                      "the recorded clip didn't open in Video — \(PromiseTests.onScreen(app))")
    }

    /// Funny Moments: film a clip, keep the record scratch it suggests, and a finished video comes out to watch.
    func testFunnyMomentsRecordsAClipAndMakesTheJoke() {
        let app = open("funny")
        tap(app, "tool-record")
        XCTAssertTrue(appears(app.buttons["funny-kind-scratch"].firstMatch, within: 60), "the recorded clip didn't open in Funny Moments — \(PromiseTests.onScreen(app))")
        tap(app, "funny-make")
        XCTAssertTrue(appears(app.descendants(matching: .any)["funny-result"].firstMatch, within: 240),
                      "no finished funny moment — \(PromiseTests.onScreen(app))")
    }

    /// Beat Reel: film a clip, and a reel cut to the music comes out to watch.
    func testBeatReelRecordsAClipAndCutsAReel() {
        let app = open("beatreel")
        tap(app, "tool-record")
        XCTAssertTrue(appears(app.buttons["reel-make"].firstMatch, within: 60), "the recorded clip didn't reach Beat Reel — \(PromiseTests.onScreen(app))")
        tap(app, "reel-style-party")
        tap(app, "reel-make")
        XCTAssertTrue(appears(app.descendants(matching: .any)["reel-result"].firstMatch, within: 300),
                      "no finished reel — \(PromiseTests.onScreen(app))")
    }

    func testPostItRecordsAClip() {
        let app = open("post")
        tap(app, "tool-record")
        XCTAssertTrue(appears(app.staticTexts["Your video"].firstMatch, within: 60),
                      "the recorded clip didn't open in Post it — \(PromiseTests.onScreen(app))")
    }

    /// The smart photo picker (every tool that opens it: receipts, cards, menus, "Got something? Photo"…).
    func testThePhotoPickerTakesAPhoto() {
        let app = open("home")
        tap(app, "have-photo")
        tap(app, "finder-camera")
        XCTAssertTrue(appears(app.staticTexts["What do you want to do?"].firstMatch, within: 40),
                      "a photo taken from the picker didn't reach \"What do you want to do?\" — \(PromiseTests.onScreen(app))")
    }

    /// A ready-made helper that starts with a video: Record a video runs it.
    func testAVideoHelperRunsOnAClipItRecorded() {
        let app = open("run-video-quiet")
        tap(app, "run-record-video")
        let done = app.descendants(matching: .any)["run-result"].firstMatch
        XCTAssertTrue(appears(done, within: 150), "the helper didn't finish on the recorded clip — \(PromiseTests.onScreen(app))")
    }
}
