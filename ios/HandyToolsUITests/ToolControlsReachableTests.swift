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
        for id in ToolSmokeTests.toolIDs { XCTContext.runActivity(named: "REACH \(id)") { _ in
            let app = XCUIApplication()
            app.launchArguments = ["-route", id, "-uitest", "-sample"]
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25), "\(id): did not open")
            // The whole screen read once, so every frame comes from the same moment. Asking each button for its
            // frame one by one (26 Nov) failed with "No matches found for Element at index 15" when a control
            // appeared or went while the tool settled — a test race that named no tool and hid the real check.
            var screen: XCUIElementSnapshot?
            for attempt in 1...3 where screen == nil {
                do { screen = try app.snapshot() } catch {
                    if attempt == 3 { XCTFail("\(id): couldn't read the screen: \(error.localizedDescription)") } else { sleep(1) }
                }
            }
            if let screen {
                let screenW = (screen.children.first { $0.elementType == .window } ?? screen).frame.width
                for b in Self.buttons(in: screen) where screenW > 0 && b.frame.width > 1 {
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
        } }
    }

    /// Every button on the screen, as one snapshot holds them.
    private static func buttons(in s: XCUIElementSnapshot) -> [XCUIElementSnapshot] {
        (s.elementType == .button ? [s] : []) + s.children.flatMap { buttons(in: $0) }
    }
}
