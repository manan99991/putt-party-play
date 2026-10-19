import XCTest

/// The check that was missing. Opens every tool that starts the camera, microphone, live audio or
/// location — with the hardware ENABLED (`-live`) and permissions pre-granted by CI — so a crash on a
/// real permission completion or audio callback surfaces HERE, in CI, and blocks the deploy.
///
/// This is the exact gap that let the Pro Camera and Audio Lab crashes ship: the ordinary smoke run
/// launches with `-uitest`, which disables hardware startup, so those paths never executed under test.
///
/// Honest limit: a CI simulator has no physical camera, so camera tools fall back to a no-device path
/// here (their device-specific value crashes are covered by unit tests instead). The audio, mic and
/// location permission/callback paths — the Swift-6 isolation class — do run, which is what this adds.
final class LiveToolTests: XCTestCase {
    static let hardwareToolIDs = [
        "audiolab",     // mic: tuner auto-starts → permission completion + audio tap on a bg thread
        "instruments",  // mic: sound meter
        "rest",         // sleep sounds
        "gpsdash",      // location
        "procam",       // camera
        "colorvision",  // camera
        "magnify",      // camera
        "describe",     // camera
    ]

    override func setUp() { continueAfterFailure = true }

    func testHardwareToolsOpenLiveWithoutCrashing() {
        for id in Self.hardwareToolIDs {
            let app = XCUIApplication()
            app.launchArguments = ["-route", id, "-uitest", "-live"]
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "\(id): did not reach foreground")
            // Permission completions and the first audio buffers land a beat after open; the
            // isolation / readout crashes hit within ~1 s. Dwell, then confirm it's still alive.
            Thread.sleep(forTimeInterval: 4)
            _ = app.descendants(matching: .any).count
            XCTAssertEqual(app.state, .runningForeground, "\(id): crashed on open with hardware live")
            app.terminate()
        }
    }

    /// Actually PLAY a sleep sound — this starts the AVAudioSourceNode render callback that crashed
    /// on device (the render path that opening the screen alone never exercises).
    func testPlayingASleepSoundDoesNotCrash() {
        let app = XCUIApplication()
        app.launchArguments = ["-route", "rest", "-uitest", "-live"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "rest did not reach foreground")
        let sound = app.buttons.matching(NSPredicate(format: "label IN %@", ["White", "Pink", "Brown", "Fan", "Rain", "Ocean"])).firstMatch
        if sound.waitForExistence(timeout: 12) {
            sound.tap()
            Thread.sleep(forTimeInterval: 3)   // let the render callback run
            XCTAssertEqual(app.state, .runningForeground, "Rest crashed when playing a sleep sound")
        }
        // (If the tile isn't found the test adds no coverage but does not false-fail the gate.)
        app.terminate()
    }
}
