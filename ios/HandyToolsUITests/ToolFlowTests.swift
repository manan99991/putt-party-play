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
        b.tap()
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
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: go); waitForExpectations(timeout: 60)
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

    func testCaptureShowsActionsForGrabbedText() {
        launch("capture")
        expect(button(containing: "Copy"), "copy action", timeout: 20)
        expect(button(starting: "Call"), "call action", timeout: 10)
        expect(button(starting: "Open"), "open link action", timeout: 10)
        button(containing: "Copy").tap()
        alive("capture")
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
        expect(button(containing: "Save or share"), "wifi card", timeout: 30)
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

    func testExplainerShowsGlossaryAndRedFlags() {
        launch("explain")
        button(containing: "Explain it").tap()
        expect(text(containing: "Clauses to look at twice"), "red flags", timeout: 60)
        expect(text(containing: "Auto-renewal"), "auto-renewal flag", timeout: 10)
        expect(text(containing: "Terms in this text"), "glossary", timeout: 10)
        alive("explain")
    }

    func testReadAloudPlaysSampleText() {
        launch("readaloud")
        button(containing: "Read this").tap()
        expect(text(containing: "1 / 3"), "sentence counter", timeout: 30)
        app.buttons["Next sentence"].firstMatch.tap()
        expect(text(containing: "2 / 3"), "advanced to sentence 2", timeout: 10)
        button(containing: "Voice").tap(); expect(app.staticTexts["Automatic (match the text)"], "voice picker", timeout: 10)
        app.buttons["Done"].firstMatch.tap()
        alive("readaloud")
    }

    func testTranslateModesAndSwap() {
        launch("translate")
        app.buttons["Swap languages"].firstMatch.tap()
        tapChip("Talk"); expect(button(containing: "speaks"), "talk buttons", timeout: 10)
        tapChip("Photo"); tapChip("Text")
        alive("translate")
    }

    func testClipboardGrabsCleansLinkAndSavesSnippet() {
        UIPasteboard.general.string = "https://example.com/post?id=42&utm_source=newsletter&fbclid=abc"
        launch("clips")
        button(containing: "Grab what").tap()
        expect(button(containing: "Clean link"), "clean link action", timeout: 15)
        button(containing: "Clean link").tap()
        expect(text(containing: "tracking removed"), "clean link toast", timeout: 10)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Snippets'")).firstMatch.tap()
        button(containing: "New snippet").tap()
        let title = app.textFields.firstMatch; expect(title, "snippet title", timeout: 10); title.tap(); title.typeText("Home")
        let editor = app.textViews.firstMatch; editor.tap(); editor.typeText("1 Infinite Loop")
        button(containing: "Save snippet").tap()
        expect(text(containing: "1 Infinite Loop"), "saved snippet", timeout: 10)
        alive("clips")
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
