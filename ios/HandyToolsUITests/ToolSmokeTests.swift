import XCTest

/// Opens every tool the way a real user would and asserts it renders without crashing. The app
/// supports `-route <id>` deep-linking (used for screenshots), so each tool is launched directly;
/// if a tool's view crashes on appear, the app leaves the foreground and the test fails for that id.
final class ToolSmokeTests: XCTestCase {

    /// Every tool in the catalog (App.swift TOOLS). HandyToolsTests.ToolCatalogCoverageTests fails the build if a tool
    /// is missing here — until 21 Nov this list had 25 of 65, so 40 tools were never opened by any test.
    static let toolIDs = [
        "studio", "procam", "video", "formatfix", "fitit", "scrub", "identify", "stitch",
        "qrwifi", "cleaner", "scan", "datagrab", "pdfredact", "sorted", "memory", "warranty",
        "textstudio", "thinking", "medreminder", "pricewatch", "planner", "brief", "daydiary", "untangle",
        "menu", "cards", "pdfannotate", "pdfconvert", "pdfpages", "pdfsign", "pdfprotect", "pdfsearchable",
        "pdfform", "zipmaker", "celebrate", "animate", "collage", "faceemoji", "comicstrip", "sticker",
        "audioconvert", "audiocompress", "ringtone", "audioedit", "audiomix", "audiotags", "audioclean", "meetingnotes",
        "soundboard", "translate", "voicenotes", "shield", "contacts", "light", "measure", "gpsdash",
        "audiolab", "rest", "seeread", "colorvision", "fileviewer", "pricecheck", "vault", "speechnotes",
        "audiostudio", "post",
        // Older screens still reachable from other tools and links.
        "magnify", "shareready", "lens", "livecaptions", "describe",
    ]

    override func setUp() { continueAfterFailure = true }

    func testEveryToolOpensWithoutCrashing() {
        for id in Self.toolIDs {
            print("SMOKE \(id)")   // so a failure that names no tool (the simulator not closing the app) still says where
            let app = XCUIApplication()
            app.launchArguments = ["-route", id, "-uitest"]
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25), "\(id): did not reach foreground")
            // Read the whole screen the way VoiceOver does (the 20 Nov crash came from exactly that), top and bottom.
            sleep(1)
            _ = app.debugDescription
            XCTAssertEqual(app.state, .runningForeground, "\(id): crashed on open")
            app.swipeUp()
            _ = app.debugDescription
            XCTAssertEqual(app.state, .runningForeground, "\(id): crashed when scrolled")
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
