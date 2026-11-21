import XCTest

/// Screenshots for the visual check, taken by the test runner (which always installs the app — the plain
/// `simctl install` timed out on cold simulators and every "screenshot" was the home screen). Runs only when the
/// screenshot workflow passes SHOTS_DIR and SHOTS_ROUTES; skipped in the normal test gate.
final class ScreenshotTests: XCTestCase {
    func testScreenshotEachRoute() throws {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["SHOTS_DIR"], let routes = env["SHOTS_ROUTES"], !routes.isEmpty else { throw XCTSkip("screenshots only in the screenshot workflow") }
        let mode = env["SHOTS_MODE"] ?? "light"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        func save(_ name: String) {
            let png = XCUIScreen.main.screenshot().pngRepresentation
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(mode)-\(name).png"))
        }
        for r in routes.split(separator: " ").map(String.init) {
            let app = XCUIApplication()
            app.launchArguments = ["-screenshots", "-uitest", "-sample", "-route", r]
            app.launch()
            guard app.wait(for: .runningForeground, timeout: 30) else { continue }
            // A system prompt (speech, photos…) is answered with Allow first, so it doesn't sit over every picture.
            let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            func allow() { for l in ["Allow", "OK", "Allow Full Access", "Allow While Using App"] where sb.alerts.buttons[l].exists { sb.alerts.buttons[l].firstMatch.tap(); break } }
            sleep(1); allow()
            if r.hasPrefix("run-") {
                // A ready-made tool works on its sample: the working card first, then the finished screen.
                sleep(2); allow(); save(r + "-a-working")
                sleep(10); allow(); save(r + "-b-done")
            } else {
                sleep(6); allow(); save(r)
            }
            app.terminate()
        }
    }
}
