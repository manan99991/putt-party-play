import XCTest

/// Every tool in the catalog opened with its sample loaded (photo, receipt, screenshots, movie, recording — the
/// tools that take one start working on it straight away), left to work, then read in full the way VoiceOver reads
/// it, top and bottom. The app must still be open after each. Covers what ToolSmokeTests can't: a tool with
/// something in it.
final class ToolRealInputTests: XCTestCase {
    static let tools: [String] = [
        "studio", "procam", "video", "formatfix", "fitit", "scrub", "identify", "stitch",
        "qrwifi", "cleaner", "scan", "datagrab", "pdfredact", "sorted", "memory", "warranty",
        "textstudio", "thinking", "medreminder", "pricewatch", "planner", "brief", "daydiary", "untangle",
        "menu", "cards", "pdfannotate", "pdfconvert", "pdfpages", "pdfsign", "pdfprotect", "pdfsearchable",
        "pdfform", "zipmaker", "celebrate", "animate", "collage", "faceemoji", "comicstrip", "sticker",
        "audioconvert", "audiocompress", "ringtone", "audioedit", "audiomix", "audiotags", "audioclean", "meetingnotes",
        "soundboard", "translate", "voicenotes", "shield", "contacts", "light", "measure", "gpsdash",
        "audiolab", "rest", "seeread", "colorvision", "fileviewer", "pricecheck", "vault", "speechnotes",
        "audiostudio", "invoice"
    ]

    func testEveryToolWithItsSampleKeepsTheAppOpen() {
        continueAfterFailure = true
        var crashed: [String] = []
        for id in Self.tools {
            let began = Date()   // 23 Nov: the run timed out after soundboard; each line now says how long its tool took
            let app = XCUIApplication()
            app.launchArguments = ["-route", id, "-uitest", "-sample"]
            app.launch()
            guard app.wait(for: .runningForeground, timeout: 30) else { crashed.append("\(id) (didn't open)"); continue }
            var alive = true
            for _ in 0..<6 {   // ~18 s of work, reading the screen as it changes
                sleep(3)
                if app.state != .runningForeground { alive = false; break }
                _ = app.debugDescription
            }
            if alive { app.swipeUp(); app.swipeUp(); _ = app.debugDescription; alive = app.state == .runningForeground }
            print("TOOLINPUT \(id): \(alive ? "ok" : "CRASHED") \(Int(Date().timeIntervalSince(began)))s")
            if !alive { crashed.append(id) }
            app.terminate()
        }
        XCTAssertTrue(crashed.isEmpty, "The app closed on: \(crashed.joined(separator: ", "))")
    }
}
