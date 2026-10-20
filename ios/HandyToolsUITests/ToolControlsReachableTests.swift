import XCTest

/// Catches the "controls run off the screen" class of bug — the one that hid Text Studio's "Bullets"
/// chip and "Fix spelling & grammar" button past the right edge. The smoke test only proves a tool
/// OPENS; the flow tests scroll to reach a chip, so they mask it too. This one launches every tool and
/// fails if a control starts on-screen but is clipped by the right edge: something the user can see is
/// cut off and can't fully read or reliably tap. When the fix lands (controls wrap instead of scroll),
/// it stays green and guards against the pattern creeping back in.
final class ToolControlsReachableTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    func testNoToolControlIsCutOffAtTheRightEdge() {
        for id in ToolSmokeTests.toolIDs {
            let app = XCUIApplication()
            app.launchArguments = ["-route", id, "-uitest", "-sample"]
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25), "\(id): did not open")
            let screenW = app.windows.firstMatch.frame.width
            if screenW > 0 {
                for b in app.buttons.allElementsBoundByIndex where b.exists && b.frame.width > 1 {
                    let f = b.frame
                    // Starts visibly on-screen, its right edge is clipped past the screen, and it isn't a
                    // full-width control — i.e. a chip/button cut off at the right rather than a normal
                    // edge-to-edge button.
                    if f.minX >= 0, f.minX < screenW - 24, f.maxX > screenW + 2, f.width < screenW - 8 {
                        XCTFail("\(id): control “\(b.label)” is cut off at the right edge (x \(Int(f.minX))–\(Int(f.maxX)) of \(Int(screenW)))")
                    }
                }
            }
            app.terminate()
        }
    }
}
