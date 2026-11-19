import AVFoundation
import CallKit

/// Why the microphone can't record right now, in plain words, so no tool ever says "allow the microphone in
/// Settings" when the real reason is a phone, FaceTime, Teams or WhatsApp call holding the mic.
///
///  • Before recording: `blocked()` — a call that's in progress (any app that uses the iPhone's call system)
///    keeps the microphone, so we say so instead of starting a recorder that captures silence.
///  • After a failure: `diagnose()` tells apart "not allowed", "on a call" and "another app has it".
///  • During a recording: `watchInterruptions` stops cleanly when a call comes in and says what happened.
enum MicCheck {
    enum Problem: Equatable { case denied, onCall, busy }

    private static let observer = CXCallObserver()

    /// A call is in progress (phone, FaceTime, or a calling app such as Teams, WhatsApp, Zoom).
    static var onCall: Bool { observer.calls.contains { !$0.hasEnded } }
    static var denied: Bool { AVAudioApplication.shared.recordPermission == .denied }

    /// Checked before starting: nil means go ahead.
    static func blocked() -> Problem? { denied ? .denied : (onCall ? .onCall : nil) }

    /// After a recorder failed to start: the most likely reason.
    static func diagnose() -> Problem { denied ? .denied : (onCall ? .onCall : .busy) }

    /// The message to show. `denied` is the tool's own words for a refused permission; `meanwhile` is what the
    /// person can do instead right now (e.g. "tap Good or Bad for now").
    static func text(_ p: Problem, denied: String = "Tenzy needs the microphone. Allow it in Settings › Tenzy › Microphone.", meanwhile: String? = nil) -> String {
        let tail = meanwhile.map { " Or \($0)." } ?? ""
        switch p {
        case .denied: return denied
        case .onCall: return "You're on a call, so your iPhone keeps the microphone for it. Try again when the call ends." + tail
        case .busy: return "Another app is using the microphone right now (a call, a voice memo or a video). Close it, then try again." + tail
        }
    }

    /// For tools without an error line of their own (meters, tuner): the same words in the app-wide notice.
    @MainActor static func announce(_ p: Problem) {
        CopyToast.shared.notice(L(text(p)), icon: p == .onCall ? "phone.fill" : "mic.slash.fill", seconds: 6)
    }

    /// Calls `stopped` on the main actor when a call (or another app) takes the microphone mid-recording.
    /// Keep the returned token for as long as the recording runs.
    static func watchInterruptions(_ stopped: @escaping @MainActor () -> Void) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            MainActor.assumeIsolated { stopped() }
        }
    }
}
