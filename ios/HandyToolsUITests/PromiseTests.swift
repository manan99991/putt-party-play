import XCTest

/// What we've said a tool does must be on the screen where people use it — not only in an edit screen or a
/// different entry point. Each check opens the ready-made tool directly and looks for the promised control.
/// Add a line here every time a feature is announced as done.
final class PromiseTests: XCTestCase {
    private func open(_ chainID: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "run-\(chainID)", "-uitest"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25))
        return app
    }

    /// "See it work in 10 seconds" (the first-minute demo) must finish on its result, never close the app.
    func testFirstMinuteDemoFinishesWithAResult() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "home", "-uitest", "-resetfirsttry"]
        app.launch()
        let start = app.descendants(matching: .any)["first-try"]
        XCTAssertTrue(start.waitForExistence(timeout: 30), "no first-minute card on Home")
        start.tap()
        XCTAssertTrue(app.staticTexts["Your result"].waitForExistence(timeout: 90), "the demo never showed its result")
        XCTAssertEqual(app.state, .runningForeground, "the demo closed the app")
    }

    /// "The home page fits with no scrolling, and every tool — the flashlight too — is there" (user, Nov 22).
    func testHomeFitsOneScreenAndShelvesOpenTools() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "home", "-uitest"]
        app.launch()
        let mine = app.buttons["home-mytools"]
        XCTAssertTrue(mine.waitForExistence(timeout: 20), "no My tools on Home")
        let screen = app.windows.firstMatch.frame
        XCTAssertTrue(mine.isHittable, "Home doesn't fit: My tools at \(mine.frame), screen \(screen), tab bar top \(app.buttons["Home"].firstMatch.frame.minY)")
        for id in ["have-photo", "have-paste", "shelf-camera", "shelf-phone", "have-reminders"] {
            XCTAssertTrue(app.descendants(matching: .any)[id].firstMatch.isHittable, "\(id) isn't on screen without scrolling")
        }
        XCTAssertFalse(app.buttons["Guide"].exists, "Guide is still on Home (it lives in Settings now)")
        app.buttons["shelf-phone"].tap()
        let light = app.buttons["shelf-tool-light"]
        XCTAssertTrue(light.waitForExistence(timeout: 5), "Flashlight & phone shelf has no Flashlight")
        light.tap()
        sleep(2)
        XCTAssertFalse(light.exists, "tapping Flashlight didn't open it")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// "Every built tool closes instead of running" (user, Nov 22): My stuff › My tools › Run must stay on the run
    /// screen, and Done must land back on My tools — not close everything.
    func testRunFromMyToolsStaysOpenAndComesBack() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "mystuff", "-uitest", "-seedtool"]
        app.launch()
        let entry = app.descendants(matching: .any)["mine-mytools"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 20), "My stuff has no My tools")
        entry.tap()
        let name = "Shrink a photo to under 2 MB"
        let run = app.buttons["Run \(name)"]
        XCTAssertTrue(run.waitForExistence(timeout: 20), "My tools didn't list the saved tool")
        run.tap()
        sleep(3)
        XCTAssertTrue(app.staticTexts[name].exists, "Run closed instead of showing the tool")
        XCTAssertFalse(run.exists, "still on My tools after tapping Run")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(run.waitForExistence(timeout: 10), "Done after a run didn't come back to My tools")
    }

    /// "Editable watermark text — type the words instead of a fixed message" (said done; was only in Edit tool).
    func testWatermarkToolsLetYouTypeYourOwnWords() {
        for id in ["id-copy-watermarked", "id-both-sides"] {
            let app = open(id)
            let field = app.textFields["run-watermark-words"]
            XCTAssertTrue(field.waitForExistence(timeout: 10), "\(id): no field for your own watermark on the run screen")
            field.tap(); field.typeText(" Chase")
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Chase'")).firstMatch.waitForExistence(timeout: 5),
                          "\(id): the line that will be written doesn't show what was typed")
            app.terminate()
        }
    }

    /// "ID copies land on their own finished screen": the copy, the words on it, location gone, size, Photos / PDF —
    /// the same on every ID-copy tool. Runs each on a sample photo and checks the finished screen.
    func testIDCopyToolsFinishOnTheIDCopyScreen() {
        for id in ["id-copy-watermarked", "id-portal", "id-both-sides"] {
            let app = XCUIApplication()
            app.launchArguments = ["-route", "run-\(id)", "-uitest", "-sample"]
            app.launch()
            let done = app.descendants(matching: .any)["idcopy-result"]
            XCTAssertTrue(done.waitForExistence(timeout: 60), "\(id): didn't land on the ID copy screen")
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Marked:'")).firstMatch.exists, "\(id): no line saying what's written on it")
            XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Share'")).firstMatch.exists, "\(id): no Share")
            if id == "id-portal" {
                XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'under'")).firstMatch.exists, "id-portal: size not checked against 500 KB")
            }
            app.terminate()
        }
    }

    /// "Portal PDFs say whether they're under the size the site needs" — checked on the finished file.
    func testPortalPDFShowsItsSizeCheck() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "run-doc-portal", "-uitest", "-sample"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["pdf-size-check"].waitForExistence(timeout: 90), "doc-portal: no size check on the finished PDF")
    }

    /// (The sample movie has no sound track, so muting is checked on real clips in QA, not here.)
    /// "Video tools finish on the same screen as the Video tool, with each promise checked on the file."
    func testVideoToolsCheckTheirPromiseOnTheFile() {
        for (id, check, says) in [("video-fast", "video-speed-check", "faster"), ("video-slowmo", "video-speed-check", "slower"), ("video-chat", "video-size-check", "Under")] {
            let app = XCUIApplication()
            app.launchArguments = ["-route", "run-\(id)", "-uitest", "-sample"]
            app.launch()
            let row = app.descendants(matching: .any).matching(identifier: check).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 120), "\(id): no check on the finished video")
            XCTAssertTrue(row.label.contains(says), "\(id): check says '\(row.label)'")
            app.terminate()
        }
    }

    /// "Scam checks give the same verdict everywhere" — the ready-made check lands on Message Shield's verdict card.
    func testScamCheckLandsOnTheShieldVerdict() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "run-scam-check", "-uitest", "-sample"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["scam-verdict"].waitForExistence(timeout: 30), "scam-check: not on the verdict card")
        XCTAssertTrue(app.staticTexts["What to do"].exists, "scam-check: no 'What to do'")
    }

    /// "Voice tools: compare with your original and switch voice without starting over" — on the finished screen.
    func testVoiceToolsLetYouSwitchVoiceOnTheResult() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "run-voice-robot", "-uitest", "-sample"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["voice-finish"].waitForExistence(timeout: 60), "voice-robot: not on the voice finish")
        XCTAssertTrue(app.buttons["voice-finish-original"].exists, "voice-robot: no way to play the original")
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Deep'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Deep voice"].waitForExistence(timeout: 30), "switching to Deep didn't remake it")
    }

    /// "Every code is tested before you share it" — the made code is read back and says what it does.
    func testMadeCodesAreTestedOnTheFinish() {
        for id in ["text-to-qr", "whatsapp-no-save"] {
            let app = XCUIApplication()
            app.launchArguments = ["-route", "run-\(id)", "-uitest", "-sample"]
            app.launch()
            let tested = app.descendants(matching: .any).matching(identifier: "code-tested").firstMatch
            XCTAssertTrue(tested.waitForExistence(timeout: 30), "\(id): the code wasn't tested")
            XCTAssertTrue(tested.label.contains("Tested"), "\(id): \(tested.label)")
            app.terminate()
        }
    }

    /// "Audio tools take the sound from my videos, not only from Files" (Join & Speed opened Files only).
    func testAudioToolsOfferMyVideos() {
        for id in ["audiomix", "audioclean", "audiocompress", "audioconvert", "audioedit", "meetingnotes", "soundboard"] {
            let app = XCUIApplication()
            app.launchArguments = ["-route", id, "-uitest"]
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any)["audio-from-videos"].waitForExistence(timeout: 15), "\(id): no way to pick from my videos")
            app.terminate()
        }
    }

    /// "Fun photos: try other looks on the result, copy into a chat" — same finish on every fun ready-made tool.
    func testFunPhotoFinishOffersOtherLooks() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "run-photo-sketch", "-uitest", "-sample"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "fun-finish").firstMatch.waitForExistence(timeout: 60), "photo-sketch: not on the fun finish")
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Copy'")).firstMatch.exists, "no Copy into a chat")
        let comic = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Comic'")).firstMatch
        XCTAssertTrue(comic.exists, "no other looks offered"); comic.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "fun-finish").firstMatch.exists)
    }

    /// "Text results read well and say how much shorter" — same finish for summaries, translations, tidied text.
    func testTextToolsFinishOnTheTextScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "run-short-summary", "-uitest", "-sample"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "text-finish").firstMatch.waitForExistence(timeout: 60), "short-summary: not on the text finish")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "text-shorter").firstMatch.exists, "no 'how much shorter' line")
    }

    /// "Sign a form: draw your signature" — the pad must show 'Sign in the box first' until there's ink.
    func testSignaturePadWontSaveBlank() {
        let app = open("sign-and-send")
        let draw = app.buttons["run-draw-signature"]
        guard draw.waitForExistence(timeout: 10) else { return }   // a signature is already saved on this simulator
        draw.tap()
        XCTAssertTrue(app.buttons["Sign in the box first"].waitForExistence(timeout: 5), "Save is offered before anything is drawn")
        XCTAssertFalse(app.buttons["Sign in the box first"].isEnabled)
        // Now really sign with a finger, in blue ink, and save — the 4th report was a pad that never inked.
        let pad = app.descendants(matching: .any).matching(identifier: "signature-pad").firstMatch
        XCTAssertTrue(pad.waitForExistence(timeout: 5), "no signing pad")
        app.buttons["ink-blue"].tap()
        let a = pad.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.6))
        a.press(forDuration: 0.05, thenDragTo: pad.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.3)))
        pad.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.3)).press(forDuration: 0.05, thenDragTo: pad.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.65)))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "signature-looks-good").firstMatch.waitForExistence(timeout: 5),
                      "a finger stroke didn't ink the pad")
        let save = app.buttons["Save signature"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertFalse(app.buttons["Save signature"].waitForExistence(timeout: 3), "the signature wasn't accepted")
        XCTAssertTrue(app.buttons["run-draw-signature"].waitForNonExistence(timeout: 5), "the tool still asks for a signature after one was saved")
    }

    /// "Watermark and lock at the same time" — Protect PDF does watermark + password + no printing in one go, and the
    /// finished screen shows each one checked on the saved file.
    func testProtectPDFDoesEverythingAtOnce() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "pdfprotect", "-uitest", "-sample"]
        app.launch()
        let make = app.buttons["protect-make"]
        XCTAssertTrue(make.waitForExistence(timeout: 20), "no password section next to the watermark")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "protect-mark-text").firstMatch.exists, "watermark words box missing")
        make.tap()
        let noPrint = app.switches["protect-noprint"]
        XCTAssertTrue(noPrint.waitForExistence(timeout: 5), "no block-printing switch")
        for _ in 0..<6 where !noPrint.isHittable { app.swipeUp() }
        noPrint.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(noPrint.value as? String, "1", "block printing didn't switch on")
        let run = app.buttons["protect-run"]
        XCTAssertTrue(run.waitForExistence(timeout: 5)); XCTAssertTrue(run.isEnabled, "can't run with watermark + password")
        run.tap()
        let checks = app.descendants(matching: .any).matching(identifier: "protect-checks").firstMatch
        XCTAssertTrue(checks.waitForExistence(timeout: 30), "no checked result")
        XCTAssertTrue(app.staticTexts["Printing is blocked"].exists || app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Printing is blocked'")).firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'CONFIDENTIAL'")).firstMatch.exists, "watermark not confirmed on the file")
    }

    /// Celebrate: a photo becomes a video with the celebration on it; picking a festival changes the words; typing any
    /// celebration (in another language) picks the right one.
    func testCelebrateOffersEveryFestivalAndTypedOnes() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "celebrate", "-uitest", "-sample"]
        app.launch()
        let preview = app.descendants(matching: .any).matching(identifier: "celebrate-preview").firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 90), "the sample never became a decorated preview")
        // Video effects opens on Vibes; the festivals are their own tab, and picking one puts its greeting on.
        XCTAssertTrue(app.buttons["fx-vibe-cinematic"].waitForExistence(timeout: 10), "no vibes")
        XCTAssertTrue(app.sliders["fx-amount"].exists, "no How much")
        app.buttons["fx-tab-celebrate"].tap()
        let typed = app.textFields["celebrate-type"]
        XCTAssertTrue(typed.waitForExistence(timeout: 5))
        typed.tap(); typed.typeText("Feliz Navidad\n")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "celebrate-caption").firstMatch.waitForExistence(timeout: 5), "no words on the video")
        app.buttons["fx-tab-words"].tap()
        let words = app.descendants(matching: .any).matching(identifier: "celebrate-words").firstMatch
        XCTAssertTrue(words.waitForExistence(timeout: 5))
        XCTAssertEqual(words.value as? String, "Merry Christmas", "typing Feliz Navidad should pick Christmas and its greeting")
        XCTAssertTrue(app.buttons["celebrate-make"].exists)
    }
}
