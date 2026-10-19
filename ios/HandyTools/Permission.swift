import AVFoundation
import Speech

/// Permission and audio-callback plumbing with **@Sendable** closures.
///
/// Why this exists: a closure formed inside a `@MainActor` type (Tuner, ToneGenerator, the night
/// recorder, the camera controllers) is inferred by Swift 6 to be main-actor-isolated. AVFoundation
/// then calls that closure back on a background thread (the permission queue, or the realtime audio
/// render thread), and the Swift 6 runtime's executor check traps — a SIGNAL 5 crash with
/// `dispatch_assert_queue` in the stack. Routing the request through these nonisolated helpers, whose
/// parameters are `@Sendable`, forces the closure to be non-isolated, so it is safe to invoke on any
/// thread. Each handler hops to the main actor itself when it needs to touch published state.
enum Permission {
    static func microphone(_ done: @escaping @Sendable (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission(completionHandler: done)
    }
    static func camera(_ done: @escaping @Sendable (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: done)
    }
    static func speech(_ done: @escaping @Sendable (SFSpeechRecognizerAuthorizationStatus) -> Void) {
        SFSpeechRecognizer.requestAuthorization(done)
    }
}

extension AVAudioNode {
    /// Install a tap whose block is `@Sendable`, so a tap set up from a `@MainActor` type is not
    /// treated as main-actor-isolated and does not trap when the audio render thread calls it.
    func installSendableTap(bufferSize: AVAudioFrameCount, format: AVAudioFormat?,
                            block: @escaping @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void) {
        installTap(onBus: 0, bufferSize: bufferSize, format: format, block: block)
    }
}
