import XCTest

/// Every ready-made flow, run on a real file of the kind it starts with (photo, receipt, PDF, video, recording or
/// text), through the same path a pick takes. While it runs and after it finishes, the whole screen is read the way
/// VoiceOver reads it — that is what closed the app on 20 Nov, and no test did it with real files in. Each run must
/// end with the app still open and something shown: a result, or a plain-words reason. A crash, a blank finish or a
/// job that never ends fails the build, so it can't reach TestFlight.
///
/// The list must match ChainTemplates.all — HandyToolsTests.RealInputCoverageTests fails if a flow is missing here.
final class RealInputTests: XCTestCase {
    static let flows: [String] = [
        "receipt-to-row", "photo-under-2mb", "safe-to-share", "card-to-contact", "poster-to-event", "whiteboard-to-tasks",
        "passport-photo", "hide-sensitive", "short-summary", "sticker", "table-to-sheet", "links-and-numbers",
        "tidy-text", "scam-check", "clean-link", "shelf-best-deal", "photo-to-pdf", "text-to-qr",
        "what-is-this", "scan-to-pdf", "sign-and-send", "receipt-run", "whatsapp-no-save", "contact-qr",
        "video-email", "video-chat", "video-still", "video-quiet", "return-by", "wifi-sign",
        "id-both-sides", "share-shield", "id-copy-watermarked", "portal-photo", "memo-to-notes", "memo-to-tasks",
        "qr-safe", "sign-to-english", "page-to-pdf", "page-summary", "listen-later", "pdf-email",
        "pdf-join", "pdf-first-page", "video-story", "video-gif", "video-words", "photo-collage",
        "where-i-am", "photos-gif", "photos-flipbook", "sticker-maker", "emoji-faces", "meme",
        "emoji-mosaic", "video-celebrate", "video-boomerang", "video-slowmo", "video-fast", "photo-sketch",
        "photo-comic", "voice-chipmunk", "voice-deep", "voice-helium", "voice-giant", "voice-robot",
        "voice-alien", "voice-monster", "voice-walkie", "voice-cave", "voice-ghost", "video-voice",
        "before-after", "photo-sell", "letter-listen", "lecture-summary", "meeting-email", "voice-spanish",
        "form-portal", "doc-portal", "id-portal", "reel-captions", "video-minute-email", "pdf-summary",
        "pdf-english", "pdf-listen", "page-listen", "whiteboard-email", "chat-scam", "rewrite-clear",
        "signature-contact"
    ]

    func testFirstHalfOfFlowsRunOnRealFiles() { run(Array(Self.flows.prefix(46))) }
    func testSecondHalfOfFlowsRunOnRealFiles() { run(Array(Self.flows.dropFirst(46))) }

    private let finishes = ["run-result", "run-steplog", "idcopy-result", "pdf-size-check", "video-speed-check", "video-size-check", "passport-score"]

    private func run(_ ids: [String]) {
        continueAfterFailure = true
        var crashed: [String] = [], blank: [String] = [], stuck: [String] = []
        for id in ids {
            let app = XCUIApplication()
            app.launchArguments = ["-route", "run-\(id)", "-uitest", "-sample"]
            app.launch()
            guard app.wait(for: .runningForeground, timeout: 30) else { crashed.append("\(id) (didn't open)"); continue }
            let busy = app.descendants(matching: .any)["run-busy-note"]
            sleep(2)
            let deadline = Date().addingTimeInterval(150)
            var reads = 0
            while Date() < deadline, app.state == .runningForeground {
                // Read the whole screen while it works, as VoiceOver would — the crash path of 20 Nov.
                if reads % 3 == 0 { _ = app.debugDescription }
                reads += 1
                if !busy.exists, finishes.contains(where: { app.descendants(matching: .any)[$0].exists }) || app.descendants(matching: .any)["run-message"].exists { break }
                sleep(2)
            }
            guard app.state == .runningForeground else { crashed.append(id); print("REALINPUT \(id): CRASHED"); continue }
            if busy.exists { stuck.append(id); print("REALINPUT \(id): STILL WORKING after 150 s"); app.terminate(); continue }
            // The finished screen, top to bottom, read in full.
            _ = app.debugDescription
            app.swipeUp(); app.swipeUp()
            _ = app.debugDescription
            guard app.state == .runningForeground else { crashed.append("\(id) (after the result)"); print("REALINPUT \(id): CRASHED after the result"); continue }
            if let f = finishes.first(where: { app.descendants(matching: .any)[$0].exists }) {
                print("REALINPUT \(id): result (\(f))")
            } else if app.descendants(matching: .any)["run-message"].exists {
                print("REALINPUT \(id): message — \(app.descendants(matching: .any)["run-message"].label)")
            } else {
                blank.append(id); print("REALINPUT \(id): NOTHING SHOWN")
            }
            app.terminate()
        }
        XCTAssertTrue(crashed.isEmpty, "The app closed on: \(crashed.joined(separator: ", "))")
        XCTAssertTrue(stuck.isEmpty, "Never finished: \(stuck.joined(separator: ", "))")
        XCTAssertTrue(blank.isEmpty, "Finished with nothing on screen: \(blank.joined(separator: ", "))")
    }
}
