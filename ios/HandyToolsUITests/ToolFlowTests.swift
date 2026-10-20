import XCTest

/// Drives each tool the way a person would: with a sample input already loaded (`-sample`), tap the
/// primary action, switch modes, type into fields, and assert the *outcome* appears (a share button,
/// a verdict, a result card) — not just that the screen opened. Camera/mic-only paths are exercised
/// as far as the simulator allows (controls render, modes switch, nothing crashes).
final class ToolFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // Permission prompts can't all be pre-granted on the simulator; answer them like a user would.
        addUIInterruptionMonitor(withDescription: "system alert") { alert in
            for label in ["Allow", "OK", "Allow While Using App", "Allow Once"] where alert.buttons[label].exists { alert.buttons[label].tap(); return true }
            return false
        }
    }

    private func launch(_ id: String) {
        app.launchArguments = ["-route", id, "-uitest", "-sample"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25), "\(id) did not launch")
    }

    /// Buttons and links (SwiftUI `Link` is exposed as a link element) by label.
    private func button(starting prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "(elementType == %d OR elementType == %d) AND label BEGINSWITH %@", XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.link.rawValue, prefix)).firstMatch
    }
    private func button(containing s: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "(elementType == %d OR elementType == %d) AND label CONTAINS[c] %@", XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.link.rawValue, s)).firstMatch
    }
    private func text(containing s: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", s)).firstMatch
    }
    private func tapChip(_ title: String) {
        let b = app.buttons[title].firstMatch
        XCTAssertTrue(b.waitForExistence(timeout: 10), "chip \(title) missing")
        if b.isHittable { b.tap(); return }
        // scrolled off a horizontal row — nudge it into view, then tap the frame's centre
        for _ in 0..<4 {
            app.swipeLeft()
            if b.isHittable { b.tap(); return }
        }
        b.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    private func expect(_ e: XCUIElement, _ what: String, timeout: TimeInterval = 60) {
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "\(what) never appeared")
    }
    private func alive(_ id: String) { XCTAssertEqual(app.state, .runningForeground, "\(id) crashed") }

    // MARK: Page 1

    func testFitItShrinksSamplePhotoUnderLimit() {
        launch("fitit")
        let go = button(starting: "Fit under")
        expect(go, "Fit button", timeout: 20); go.tap()
        expect(text(containing: "Fits —"), "fitted result")
        expect(button(containing: "Save or share"), "share button")
        alive("fitit")
    }

    func testStudioCutsOutResizesAndConverts() {
        launch("studio")
        let cut = button(containing: "Cut out subject"); expect(cut, "cut out button", timeout: 20); cut.tap()
        expect(button(containing: "Save or share"), "cut-out result", timeout: 90)
        tapChip("Resize"); button(containing: "Resize photo").tap(); expect(button(containing: "Save or share"), "resize result")
        tapChip("Convert"); tapChip("PNG"); button(starting: "Convert to").tap(); expect(text(containing: "PNG"), "PNG result")
        alive("studio")
    }

    func testLongScreenshotStitchesSamplePair() {
        launch("stitch")
        let go = button(containing: "Stitch into one image"); expect(go, "stitch button", timeout: 20); go.tap()
        expect(button(containing: "Save or share"), "stitched result", timeout: 90)
        alive("stitch")
    }

    func testPrivacyScrubberMakesCleanCopy() {
        launch("scrub")
        let go = button(containing: "clean copy"); expect(go, "scrub button", timeout: 30)
        // wait until face/text detection finishes (button enables)
        let deadline = Date().addingTimeInterval(60)
        while !go.isEnabled && Date() < deadline { sleep(1) }
        XCTAssertTrue(go.isEnabled, "detection never finished")
        go.tap()
        expect(button(containing: "Save or share"), "clean copy", timeout: 60)
        alive("scrub")
    }

    func testFormatFixerConvertsAndShareReadyPreparesPhoto() {
        launch("formatfix")
        let conv = button(starting: "Convert"); expect(conv, "convert button", timeout: 20); conv.tap()
        expect(button(containing: "Save or share"), "converted files")
        alive("formatfix")
        app.terminate()

        launch("shareready")
        let go = button(containing: "Make share"); expect(go, "share-ready button", timeout: 20); go.tap()
        expect(button(containing: "Share them"), "share-ready output", timeout: 90)
        alive("shareready")
    }

    func testVideoTrimsAndShrinksSampleClip() {
        launch("video")
        XCTAssertTrue(app.buttons["Trim"].firstMatch.waitForExistence(timeout: 90), "sample clip never loaded")
        tapChip("Trim")
        // slide the start handle a little so a real trim happens
        let sliders = app.sliders
        XCTAssertTrue(sliders.firstMatch.waitForExistence(timeout: 60), "trim sliders")
        sliders.element(boundBy: 0).adjust(toNormalizedSliderPosition: 0.3)
        let trim = button(starting: "Trim to"); expect(trim, "trim button", timeout: 20); trim.tap()
        expect(text(containing: "Ready —"), "trimmed clip", timeout: 120)
        tapChip("Shrink")
        let shrink = button(starting: "Shrink under"); expect(shrink, "shrink button", timeout: 20)
        if shrink.isEnabled { shrink.tap(); expect(text(containing: "Ready —"), "shrunk clip", timeout: 180) }
        tapChip("GIF"); button(containing: "Make GIF").tap(); expect(text(containing: "GIF ready"), "gif", timeout: 120)
        alive("video")
    }

    func testScanCleansSignsReadsAndExportsSearchablePDF() {
        launch("scan")
        expect(text(containing: "Page 1 of 2"), "two sample pages", timeout: 30)
        tapChip("Black & white")
        app.buttons["Rotate"].firstMatch.tap()
        tapChip("Sign & fill")
        let field = app.textFields.firstMatch
        expect(field, "text field", timeout: 10); field.tap(); field.typeText("Jane Doe")
        app.buttons["Add"].firstMatch.tap()
        tapChip("Text")
        button(containing: "Read this page").tap()
        expect(button(containing: "Copy"), "OCR text", timeout: 90)
        tapChip("Export")
        let exp = button(starting: "Export 2"); expect(exp, "export button", timeout: 10); exp.tap()
        expect(text(containing: "PDF ready"), "searchable PDF", timeout: 120)
        alive("scan")
    }

    func testSortedExtractsBillDetails() {
        launch("sorted")
        button(containing: "Make sense of it").tap()
        expect(text(containing: "$84.20"), "amount extracted", timeout: 20)
        expect(button(containing: "Add to Calendar"), "calendar action", timeout: 10)
        alive("sorted")
    }

    func testLensListensToSampleText() {
        launch("lens")
        button(containing: "Read it aloud").tap()
        expect(text(containing: "1 / 4"), "sentence counter", timeout: 30)
        // Pause before skipping so live-playback auto-advance can't race the manual skip.
        app.buttons["Pause"].firstMatch.tap()
        app.buttons["Next sentence"].firstMatch.tap()
        expect(text(containing: "2 / 4"), "advanced to sentence 2", timeout: 10)
        alive("lens")
    }

    func testQRMakesCodeAndWifiCard() {
        launch("qrwifi")
        tapChip("Make")
        let f = app.textFields.firstMatch; expect(f, "payload field", timeout: 10); f.tap(); f.typeText("https://tenzy.app")
        button(containing: "Make QR code").tap()
        expect(button(containing: "Save or share"), "qr image", timeout: 30)
        button(containing: "Fi card").tap()
        let ssid = app.textFields.firstMatch; expect(ssid, "ssid field", timeout: 10); ssid.tap(); ssid.typeText("HomeNet")
        button(containing: "Make the card").tap()
        expect(button(containing: "Save, share or print"), "wifi card", timeout: 30)
        alive("qrwifi")
    }

    // MARK: Page 2

    func testFlashlightMorseScreenLightAndMirror() {
        launch("light")
        let f = app.textFields.firstMatch; expect(f, "morse field", timeout: 10); f.tap(); f.typeText("SOS")
        expect(text(containing: "... --- ..."), "morse encoding", timeout: 10)
        button(containing: "Screen light").tap()
        expect(text(containing: "Tap anywhere to close"), "screen light sheet", timeout: 10)
        app.staticTexts["Tap anywhere to close"].firstMatch.tap()
        button(containing: "Mirror").tap(); sleep(2)
        alive("light")
    }

    func testInstrumentsSwitchEveryGauge() {
        launch("instruments")
        for g in ["Compass", "Sound", "Light", "Altitude", "Metal", "Ruler", "Level"] { tapChip(g); sleep(1); alive("instruments:\(g)") }
        tapChip("Ruler"); app.buttons["inches"].firstMatch.tap()
        expect(text(containing: "bank card"), "ruler calibration", timeout: 10)
    }

    func testMagnifierLooksOnFrozenFrame() {
        launch("magnify")
        for l in ["High contrast", "Inverted", "Yellow on black", "White on blue", "Grayscale", "Natural"] { tapChip(l); alive("magnify:\(l)") }
        expect(text(containing: "Frozen"), "frozen badge", timeout: 10)
    }

    func testGPSDashboardUnitsAndHUD() {
        launch("gpsdash")
        app.buttons["km/h"].firstMatch.tap(); app.buttons["mph"].firstMatch.tap()
        button(containing: "HUD").tap()
        expect(text(containing: "Mirrored for the windshield"), "HUD", timeout: 10)
        app.buttons["Close HUD"].firstMatch.tap()
        alive("gpsdash")
    }

    func testAudioLabToneSpeakerAndTuner() {
        launch("audiolab")
        if !app.buttons["Tone"].firstMatch.isHittable { app.tap() }
        tapChip("Tone"); button(containing: "Play tone").tap(); sleep(1); button(containing: "Stop").tap()
        tapChip("Speaker test"); app.buttons["Left"].firstMatch.tap(); sleep(2)
        tapChip("Eject water"); button(containing: "(12 s)").tap(); sleep(1); button(containing: "Stop").tap()
        tapChip("Tuner"); tapChip("Guitar")
        alive("audiolab")
    }

    func testRestPlaysSoundsSetsTimerAndShowsRecorder() {
        launch("rest")
        app.buttons["Brown"].firstMatch.tap(); sleep(1)
        tapChip("15 min")
        expect(text(containing: "fades out in"), "sleep timer", timeout: 10)
        app.buttons["Rain"].firstMatch.tap(); sleep(1); app.buttons["Rain"].firstMatch.tap()
        app.buttons["Night recorder"].firstMatch.tap()
        expect(button(containing: "Start listening"), "recorder", timeout: 10)
        alive("rest")
    }

    func testColorVisionModesOnSamplePhoto() {
        launch("colorvision")
        for m in ["Highlight", "Name it", "Simulate", "Correct"] { tapChip(m); sleep(1); alive("colorvision:\(m)") }
        tapChip("Red-weak"); tapChip("Blue-weak")
        tapChip("Name it")
        expect(text(containing: "#"), "colour name + hex", timeout: 15)
    }

    func testSceneDescriberDescribesSamplePhoto() {
        launch("describe")
        expect(button(containing: "Repeat"), "description card", timeout: 90)
        alive("describe")
    }

    func testProCameraAndMeasureRenderControls() {
        launch("procam")
        for p in ["Focus", "White balance", "Long exposure", "Exposure"] { tapChip(p); alive("procam:\(p)") }
        app.buttons["Manual"].firstMatch.tap(); alive("procam:manual")
        app.terminate()
        launch("measure")
        alive("measure")
    }

    // MARK: Page 3

    func testTextStudioFixesBulletsAndSummarizes() {
        launch("textstudio")
        button(containing: "Fix spelling").tap()
        expect(button(containing: "Keep working"), "fixed text", timeout: 60)
        tapChip("Bullets"); button(containing: "bullet points").tap(); expect(text(containing: "•"), "bullets", timeout: 30)
        tapChip("Summarize"); button(containing: "Summarize this").tap(); expect(button(containing: "Keep working"), "summary", timeout: 30)
        alive("textstudio")
    }

    func testMessageShieldFlagsTheSampleScam() {
        launch("shield")
        expect(text(containing: "Likely a scam"), "verdict", timeout: 30)
        expect(text(containing: "untraceable payment"), "gift-card finding", timeout: 10)
        expect(text(containing: "Link looks wrong"), "link finding", timeout: 10)
        expect(text(containing: "What to do"), "advice", timeout: 10)
        alive("shield")
    }

    func testDataGrabberParsesSampleReceipt() {
        launch("datagrab")
        expect(text(containing: "Total"), "receipt total", timeout: 90)
        expect(button(containing: "Items as CSV"), "csv export", timeout: 10)
        tapChip("Business card"); alive("datagrab:card")
        tapChip("Table"); expect(button(containing: "Save CSV"), "table csv", timeout: 10)
        tapChip("Receipt")
        button(containing: "Copy expense row").tap()
        alive("datagrab")
    }

    func testLensSimplifiesAndGists() {
        launch("lens")
        tapChip("Plain English")
        // "Put it in plain English" — not "plain English" alone, which also matches the chip.
        button(containing: "Put it in plain").tap()
        expect(text(containing: "Worth a second look"), "red flags", timeout: 60)
        expect(text(containing: "Auto-renewal"), "auto-renewal flag", timeout: 10)
        tapChip("Gist")
        button(containing: "Boil it down").tap()
        expect(text(containing: "•"), "gist bullets", timeout: 20)
        alive("lens")
    }

    func testTranslateModesAndSwap() {
        launch("translate")
        app.buttons["Swap languages"].firstMatch.tap()
        tapChip("Talk"); expect(button(containing: "speaks"), "talk buttons", timeout: 10)
        tapChip("Photo"); tapChip("Text")
        alive("translate")
    }

    func testCleanerOpensAndOffersCategories() {
        launch("cleaner")
        // Either the permission gate (no photo access granted in this suite) or, if access is
        // already granted, the category picker — both must render without crashing.
        let gate = button(containing: "Allow photo access")
        let categories = app.segmentedControls.firstMatch
        XCTAssertTrue(gate.waitForExistence(timeout: 12) || categories.waitForExistence(timeout: 12),
                      "Cleaner should show the access gate or the category picker")
        alive("cleaner")
    }

    func testVoiceNotesAndLiveCaptionsRender() {
        launch("voicenotes")
        expect(button(containing: "Record"), "record button", timeout: 15)
        app.terminate()
        launch("livecaptions")
        expect(button(containing: "Start captions"), "captions button", timeout: 15)
        app.buttons["Text size"].firstMatch.tap(); app.buttons["Huge"].firstMatch.tap()
        let reply = app.textFields.firstMatch; expect(reply, "reply field", timeout: 10); reply.tap(); reply.typeText("Hello")
        app.buttons["Speak reply"].firstMatch.tap()
        alive("livecaptions")
    }

    func testVaultLockScreenAndUnlockAttempt() {
        launch("vault")
        expect(text(containing: "Locked"), "lock screen", timeout: 15)
        button(containing: "Unlock").tap()
        // Simulator: either unlocks (passcode set) or explains what's needed — both are correct, a crash is not.
        let ok = button(containing: "Note").waitForExistence(timeout: 15) || text(containing: "passcode").waitForExistence(timeout: 5) || text(containing: "cancelled").waitForExistence(timeout: 5)
        XCTAssertTrue(ok, "vault neither unlocked nor explained")
        alive("vault")
    }
}
