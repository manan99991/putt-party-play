import XCTest

/// Opens every tool the way a real user would and asserts it renders without crashing. The app
/// supports `-route <id>` deep-linking (used for screenshots), so each tool is launched directly;
/// if a tool's view crashes on appear, the app leaves the foreground and the test fails for that id.
final class ToolSmokeTests: XCTestCase {

    /// Keep in lock-step with the catalog in App.swift. Adding a tool? Add its id here.
    static let toolIDs = [
        // Page 1
        "flash", "timer", "clips", "qr", "pocket", "vault", "ocr", "translate", "gif", "measure",
        // Page 2
        "scan", "pdftools", "imgconvert", "bgremove", "photostudio", "vidcompress", "audiotext", "signfill", "idphoto", "webclip",
        // Page 3 (AI)
        "ai_summarize", "ai_extract", "ai_rewrite", "ai_ask", "ai_proofread", "ai_describe", "ai_handwriting", "ai_reply", "ai_identify", "ai_sticker",
    ]

    override func setUp() { continueAfterFailure = true }

    func testEveryToolOpensWithoutCrashing() {
        for id in Self.toolIDs {
            let app = XCUIApplication()
            app.launchArguments = ["-route", id, "-uitest"]
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25), "\(id): did not reach foreground")
            // Force a UI query — throws/returns 0 against a dead process if the view crashed on appear.
            _ = app.descendants(matching: .any).count
            XCTAssertEqual(app.state, .runningForeground, "\(id): crashed on open")
            app.terminate()
        }
    }

    func testHomePagesAndSearchRender() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "home", "-uitest"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25))
        let search = app.textFields.firstMatch
        if search.waitForExistence(timeout: 10) {
            search.tap()
            search.typeText("pdf")
            XCTAssertEqual(app.state, .runningForeground, "search crashed")
        }
        app.terminate()
    }

    func testPaywallAndSettingsRender() {
        let app = XCUIApplication()
        for route in ["paywall", "settings"] {
            app.launchArguments = ["-route", route, "-uitest"]
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25), "\(route) did not render")
            _ = app.descendants(matching: .any).count
            XCTAssertEqual(app.state, .runningForeground, "\(route) crashed")
            app.terminate()
        }
    }
}
