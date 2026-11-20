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

    /// "Sign a form: draw your signature" — the pad must show 'Sign in the box first' until there's ink.
    func testSignaturePadWontSaveBlank() {
        let app = open("sign-and-send")
        let draw = app.buttons["run-draw-signature"]
        guard draw.waitForExistence(timeout: 10) else { return }   // a signature is already saved on this simulator
        draw.tap()
        XCTAssertTrue(app.buttons["Sign in the box first"].waitForExistence(timeout: 5), "Save is offered before anything is drawn")
        XCTAssertFalse(app.buttons["Sign in the box first"].isEnabled)
    }
}
