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

    /// "The home page fits with no scrolling, and every tool — the flashlight too — is there" (user, Nov 22), and
    /// "Contacts and other tabs are missing — make sure nothing is missing" (Nov 23): every tab, tapped, shows every
    /// one of its tools on screen without scrolling, and a tool opens from its tile.
    func testHomeFitsOneScreenAndShelvesOpenTools() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "home", "-uitest"]
        app.launch()
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["have-photo"].firstMatch.waitForExistence(timeout: 20), "Home didn't open")
        // My tools, Ready-made tools and Reminders moved to the My stuff tab (23 Nov audit decision 3).
        XCTAssertFalse(any["home-templates"].firstMatch.exists, "Templates is still on Home")
        for id in ["have-photo", "have-paste"] {
            XCTAssertTrue(any[id].firstMatch.isHittable, "\(id) isn't on screen without scrolling")
        }
        let tabs = ["camera": 9, "photos": 8, "video": 5, "pdf": 9, "audio": 6, "words": 6, "day": 9, "phone": 5]
        for (tab, count) in tabs.sorted(by: { $0.key < $1.key }) {
            let t = any["tab-\(tab)"].firstMatch
            XCTAssertTrue(t.isHittable, "tab \(tab) isn't on screen")
            t.tap()
            let tiles = any.matching(NSPredicate(format: "identifier BEGINSWITH 'home-tool-'"))
            let shown = (0..<tiles.count).map { tiles.element(boundBy: $0) }
            let off = shown.filter { !$0.isHittable }.map(\.identifier)
            // Diagnostics (rulebook §8): the screen, where the last tile ends, where the tab bar starts, and whether the
            // first-visit "See it work" card is pushing the grid down.
            let win = app.windows.firstMatch.frame
            let lastY = shown.map { Int($0.frame.maxY) }.max() ?? -1
            let bar = Int(app.buttons["builder-entry"].firstMatch.frame.minY)
            let why = "screen \(Int(win.width))x\(Int(win.height)), last tile ends at \(lastY), tab bar at \(bar), first-try card \(any["first-try"].firstMatch.exists)"
            XCTAssertEqual(shown.count, count, "tab \(tab) shows \(shown.count) tools; \(why)")
            XCTAssertEqual(off, [], "tab \(tab): these tools need scrolling to reach; \(why)")
        }
        XCTAssertFalse(app.buttons["Guide"].exists, "Guide is still on Home (it lives in Settings now)")
        any["tab-phone"].firstMatch.tap()
        XCTAssertTrue(any["home-tool-contacts"].firstMatch.isHittable, "Contacts has no tile")
        let light = any["home-tool-light"].firstMatch
        XCTAssertTrue(light.isHittable, "Contacts & phone has no Flashlight")
        light.tap()
        sleep(2)
        XCTAssertFalse(light.isHittable, "tapping Flashlight didn't open it")
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

    /// Audit decision 2 (23 Nov): a parked car shows a "For you now" card on Home with Directions, the whole Camera tab
    /// still fits under it, and Not now puts the card away.
    func testForYouCardShowsTheCarAndNotNowPutsItAway() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "home", "-uitest", "-seedcar"]
        app.launch()
        let any = app.descendants(matching: .any)
        let card = any["foryou-car"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), "no card for the parked car")
        XCTAssertTrue(any["foryou-action-car"].firstMatch.isHittable, "the card has no Directions button. The card as XCTest sees it: \(card.debugDescription.prefix(1500))")
        any["tab-camera"].firstMatch.tap()
        let tiles = any.matching(NSPredicate(format: "identifier BEGINSWITH 'home-tool-'"))
        let off = (0..<tiles.count).map { tiles.element(boundBy: $0) }.filter { !$0.isHittable }.map(\.identifier)
        XCTAssertEqual(tiles.count, 9, "the Camera tab lost tools under the card")
        XCTAssertEqual(off, [], "with the card on Home, these tools need scrolling: \(off)")
        any["foryou-notnow-car"].firstMatch.tap()
        sleep(1)
        XCTAssertFalse(card.exists, "Not now didn't put the card away")
    }

    /// Audit decision 4 (23 Nov): one welcome screen; picking "Documents and PDFs" and Start lands on Home with the
    /// PDF tab open and its tools on screen, with no permission page in between.
    func testWelcomeIsOneScreenAndOpensTheChosenTab() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-resetwelcome"]
        app.launch()
        let any = app.descendants(matching: .any)
        let docs = any["welcome-documents"].firstMatch
        XCTAssertTrue(docs.waitForExistence(timeout: 20), "the welcome didn't show")
        XCTAssertTrue(any["welcome-start"].firstMatch.isHittable, "Start isn't on the same screen")
        docs.tap()
        any["welcome-start"].firstMatch.tap()
        let sign = any["home-tool-pdfsign"].firstMatch
        XCTAssertTrue(sign.waitForExistence(timeout: 15), "Home didn't open on the PDF tab")
        XCTAssertTrue(sign.isHittable)
        XCTAssertFalse(app.staticTexts["Set up once"].exists, "the permission page still follows the welcome")
    }

    /// Business (Manan, 23 Nov): no Business tab until the person says they run a business; with it on, the tab is
    /// there, every job is on screen without scrolling, and a job opens its ready-made tool.
    func testBusinessTabShowsOnlyWhenOnAndItsJobsOpen() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "home", "-uitest"]
        app.launch()
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["have-photo"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertFalse(any["tab-business"].firstMatch.exists, "Business shows for someone who never said they run one")
        app.terminate()
        app.launchArguments = ["-route", "home", "-uitest", "-tenzy.business", "YES"]
        app.launch()
        let tab = any["tab-business"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "Business is switched on but there's no tab")
        tab.tap()
        let jobs = any.matching(NSPredicate(format: "identifier BEGINSWITH 'home-job-'"))
        let off = (0..<jobs.count).map { jobs.element(boundBy: $0) }.filter { !$0.isHittable }.map(\.identifier)
        XCTAssertGreaterThanOrEqual(jobs.count, 7)
        XCTAssertEqual(off, [], "these Business jobs need scrolling: \(off)")
        any["home-job-expense"].firstMatch.tap()
        sleep(2)
        XCTAssertFalse(any["home-job-expense"].firstMatch.isHittable, "Log an expense didn't open its tool")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Business (23 Nov): Send an invoice opens Invoices & Quotes from the Business tab; a filled-in invoice makes a PDF
    /// with a Send button, then waits in the unpaid list until Paid takes it off.
    func testInvoiceOpensFromBusinessMakesAPDFAndWaitsUntilPaid() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "home", "-uitest", "-sample", "-tenzy.business", "YES"]
        app.launch()
        let any = app.descendants(matching: .any)
        let tab = any["tab-business"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "no Business tab")
        tab.tap()
        let job = any["home-job-invoice"].firstMatch
        XCTAssertTrue(job.waitForExistence(timeout: 5), "the Business tab has no Send an invoice")
        job.tap()
        let make = any["invoice-make"].firstMatch
        XCTAssertTrue(make.waitForExistence(timeout: 15), "Send an invoice didn't open Invoices & Quotes")
        let paid = any.matching(NSPredicate(format: "identifier BEGINSWITH 'invoice-paid-'"))
        let before = paid.count
        XCTAssertTrue(make.isEnabled, "the sample invoice can't be made. Total reads: \(any["invoice-total"].firstMatch.label)")
        make.tap()
        XCTAssertTrue(any["invoice-send"].firstMatch.waitForExistence(timeout: 10), "no Send button after Make PDF")
        XCTAssertEqual(paid.count, before + 1, "the new invoice isn't in the unpaid list")
        any["invoice-another"].firstMatch.tap()
        paid.element(boundBy: 0).tap()
        sleep(1)
        XCTAssertEqual(paid.count, before, "Paid didn't take it off the unpaid list")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Audit decision 3 (23 Nov): Templates moved off Home into My stuff as "Ready-made tools". It opens the list, and
    /// Done lands back on My stuff, never a blank page.
    func testReadyMadeToolsOpenFromMyStuffAndComeBack() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "mystuff", "-uitest"]
        app.launch()
        let entry = app.descendants(matching: .any)["mine-readymade"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 20), "My stuff has no Ready-made tools")
        entry.tap()
        XCTAssertTrue(app.navigationBars["Ready-made tools"].waitForExistence(timeout: 15), "Ready-made tools didn't open")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["mine-readymade"].firstMatch.waitForExistence(timeout: 10),
                      "Done didn't come back to My stuff")
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

    /// "I cannot go back to the app. I cannot close that screen" (Manan, 22 Nov, video): Contacts → a person →
    /// "Edit everything in Contacts" opens Apple's own card, which on iOS 26 shows only "Edit" and no way out.
    /// Tenzy's Close strip must be there, and must bring you back — before and after going into Edit.
    func testAppleContactCardAlwaysCloses() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "contacts", "-uitest"]
        app.launch()
        let box = app.buttons["find-hasPhone"]
        XCTAssertTrue(box.waitForExistence(timeout: 20), "Contacts finder didn't show (is contacts access granted?)")
        box.tap()
        let info = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open '")).firstMatch
        XCTAssertTrue(info.waitForExistence(timeout: 10), "no contact opened from the finder")
        info.tap()
        let editAll = app.buttons["Edit everything in Contacts"]
        XCTAssertTrue(editAll.waitForExistence(timeout: 10), "the contact page has no way into Apple's card")
        for round in 1...2 {
            editAll.tap()
            let close = app.buttons["contact-card-close"]
            XCTAssertTrue(close.waitForExistence(timeout: 10), "round \(round): Apple's contact card opened with no Close")
            if round == 2, app.buttons["Edit"].firstMatch.waitForExistence(timeout: 3) {
                app.buttons["Edit"].firstMatch.tap()   // into Apple's edit mode — Close must still be there
                XCTAssertTrue(close.waitForExistence(timeout: 5), "Close vanished in Apple's edit mode")
            }
            close.tap()
            XCTAssertTrue(editAll.waitForExistence(timeout: 10), "round \(round): Close didn't bring you back to Tenzy")
        }
    }

    /// "Give them a preview when they click on the image… review each image… save it or share it. This applies to all
    /// the tools" (Manan, 22 Nov): a finished photo opens full screen with Save / Share, and Done brings you back.
    func testFinishedPhotoOpensFullSizeAndCloses() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "run-photo-under-2mb", "-uitest", "-sample"]
        app.launch()
        let open = app.buttons["full-size"].firstMatch
        let thumb = app.buttons["result-thumb-0"].firstMatch
        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline, !open.exists, !thumb.exists { sleep(2) }
        XCTAssertTrue(open.exists || thumb.exists, "the finished photo has no way to see it full size")
        (open.exists ? open : thumb).tap()
        let done = app.buttons["viewer-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "the full-size view didn't open")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Share' OR label CONTAINS[c] 'Save'")).firstMatch.exists,
                      "the full-size view has no Save or Share")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 10), "Done didn't close the full-size view")
    }

    /// My Day as a flow (Manan, 22 Nov): tap Good → the day is saved → "Record a short message" or "That's all".
    /// Finishing without a message still keeps the day; "Oops" flips it.
    func testMyDaySavesFirstThenOffersAShortMessage() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "daydiary", "-uitest"]
        app.launch()
        let good = app.buttons["Good day"]
        XCTAssertTrue(good.waitForExistence(timeout: 15), "My Day has no Good day button")
        good.tap()
        XCTAssertTrue(app.buttons["day-record-why"].waitForExistence(timeout: 5), "after Good day there's no offer to record why")
        XCTAssertTrue(app.buttons["day-done"].exists, "no way to finish without recording")
        XCTAssertTrue(app.staticTexts["Saved — a good day"].exists, "it doesn't say the day was saved")
        app.buttons["day-flip"].tap()
        XCTAssertTrue(app.staticTexts["Saved — a hard day"].waitForExistence(timeout: 5), "Oops didn't switch it to a hard day")
        app.buttons["day-done"].tap()
        XCTAssertTrue(app.buttons["Good day"].waitForExistence(timeout: 5), "That's all didn't finish the flow")
        app.terminate(); app.launch()   // come back later: the day is still there
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'a hard day'")).firstMatch.waitForExistence(timeout: 15),
                      "the day wasn't kept after finishing without a message")
    }

    /// "Click on photos… show only the photos related to warranty and receipts… they can still access all the photos"
    /// (Manan, 22 Nov): Warranty's From Photos opens the smart picker on receipts, with All photos always there.
    func testWarrantyPhotosOpenOnReceiptsWithAllPhotosAtHand() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "warranty", "-uitest"]
        app.launch()
        let from = app.buttons["warranty-from-photos"]
        XCTAssertTrue(from.waitForExistence(timeout: 15), "Warranty has no From Photos")
        from.tap()
        XCTAssertTrue(app.staticTexts["Receipts and warranty cards"].waitForExistence(timeout: 10), "the picker didn't open on receipts")
        XCTAssertTrue(app.buttons["finder-all"].exists, "no way to reach all photos")
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(from.waitForExistence(timeout: 10), "Cancel didn't close the picker")
    }

    /// "Just swiping the finger lets select multiple files" (Manan, 22 Nov): Home › Photo opens Tenzy's own grid, and a
    /// sideways swipe across the first row ticks every photo it passes over.
    func testSwipeAcrossPhotosPicksSeveral() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "home", "-uitest"]
        app.launch()
        let tile = app.descendants(matching: .any)["have-photo"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 20))
        tile.tap()
        let cells = app.buttons.matching(identifier: "finder-photo")
        XCTAssertTrue(cells.firstMatch.waitForExistence(timeout: 20), "the photo grid didn't open")
        guard cells.count >= 3 else { return }   // a simulator with fewer photos can't show a swipe
        // Three photos side by side in the top row, chosen by where they are on screen: the order the phone lists them
        // in isn't left to right (the 23 Nov run listed x = 308, 81, 195, so the old swipe crossed only two photos).
        let shown = (0..<min(cells.count, 24)).map { cells.element(boundBy: $0) }.filter { $0.isHittable }
        let rows = Dictionary(grouping: shown) { Int(($0.frame.midY / 10).rounded()) }
        guard let row = rows.filter({ $0.value.count >= 3 }).min(by: { $0.key < $1.key })?.value.sorted(by: { $0.frame.minX < $1.frame.minX }) else { return }
        let from = row[0].coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        let to = row[2].coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        from.press(forDuration: 0.05, thenDragTo: to)
        let use = app.buttons["finder-use"]
        XCTAssertTrue(use.waitForExistence(timeout: 5), "swiping across photos didn't pick any")
        XCTAssertTrue(use.label.contains("3"), "a swipe across three photos picked: \(use.label) — \(use.value as? String ?? "") (row x: \(row.prefix(3).map { Int($0.frame.midX) }))")
    }
}
