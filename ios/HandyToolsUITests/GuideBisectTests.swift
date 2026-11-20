import XCTest

/// Finds which part of the "What do you want to do?" screen closes the app when several photos are
/// handed over (your 20 Nov crash): opens it with parts left out and reports which versions survive.
final class GuideBisectTests: XCTestCase {
    func testWhichPartCloses() {
        continueAfterFailure = true
        var report: [String] = []
        for skip in ["all", "", "task", "header", "suggest", "grid", "steps", "task,header,suggest,grid,steps"] {
            let app = XCUIApplication()
            var args = ["-route", "builder", "-uitest", "-givephotos", "2"]
            if !skip.isEmpty { args += ["-guideskip", skip] }
            app.launchArguments = args
            app.launch()
            let opened = app.staticTexts["What do you want to do?"].waitForExistence(timeout: 60)
            sleep(6)
            let alive = app.state == .runningForeground
            report.append("BISECT skip=[\(skip)] opened=\(opened) alive=\(alive)")
            app.terminate()
        }
        print(report.joined(separator: "\n"))
        XCTContext.runActivity(named: report.joined(separator: " | ")) { _ in }
        XCTAssertTrue(report.contains { $0.contains("skip=[] ") && $0.hasSuffix("alive=true") }, report.joined(separator: "\n"))
    }
}
