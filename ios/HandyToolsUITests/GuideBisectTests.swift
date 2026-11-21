import XCTest

/// Finds which part of the "What do you want to do?" screen closes the app when several photos are
/// handed over (your 20 Nov crash): opens it with parts left out and reports which versions survive.
/// It never asks the screen for its contents (that query itself times out while the app is stuck) — it only
/// checks whether the app is still running.
final class GuideBisectTests: XCTestCase {
    func testWhichPartCloses() {
        continueAfterFailure = true
        var report: [String] = []
        for skip in ["", "all", "task", "header", "suggest", "preview", "grid", "steps", "header,preview", "task,header,suggest,grid,steps"] {
            let app = XCUIApplication()
            var args = ["-route", "home", "-uitest", "-givephotos", "2"]
            if !skip.isEmpty { args += ["-guideskip", skip] }
            app.launchArguments = args
            app.launch()
            sleep(12)
            let before = app.state == .runningForeground
            // Reading the screen the way VoiceOver (or a UI test) does is what tips it over.
            let found = app.staticTexts["What do you want to do?"].waitForExistence(timeout: 30)
            sleep(3)
            let line = "BISECT skip=[\(skip)] alive=\(before) read=\(found) aliveAfterRead=\(app.state == .runningForeground)"
            print(line); report.append(line)
            app.terminate()
            sleep(2)
        }
        XCTContext.runActivity(named: report.joined(separator: " | ")) { _ in }
    }
}
