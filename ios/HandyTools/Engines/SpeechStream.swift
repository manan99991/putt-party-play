import Foundation
import Speech
import AVFoundation

/// Continuous on-device speech-to-text that runs for as long as you like: it quietly rolls the
/// recognition request every ~50 s (Apple caps each one at a minute) and stitches the segments, so
/// Live Captions and Voice → Notes never stop mid-sentence. Nothing leaves the phone when the
/// language supports on-device recognition.
@MainActor final class SpeechStream: ObservableObject {
    @Published var live = ""              // current segment, updating as you speak
    @Published var committed: [String] = []   // finished segments
    @Published var running = false
    @Published var errorText: String?
    @Published var onDevice = true
    // Changing the language ENDS the current session and returns to idle (Start), rather than
    // silently restarting — a restart into a language that can't actually recognise (e.g. an
    // off-device language on the server path) used to leave the Stop button up and "Listening…"
    // showing while nothing was captured. Tap Start to caption in the newly chosen language.
    @Published var locale = Locale(identifier: Locale.preferredLanguages.first ?? "en-US") {
        didSet { if oldValue != locale, running { stop() } }
    }

    var transcript: String { (committed + [live]).filter { !$0.isEmpty }.joined(separator: "\n") }

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest? { didSet { sink = request } }
    nonisolated(unsafe) private var sink: SFSpeechAudioBufferRecognitionRequest?   // read by the realtime audio tap
    private var task: SFSpeechRecognitionTask?
    private var rollTimer: Task<Void, Never>?
    private var tapInstalled = false

    /// "es" → es-MX on a Mexican phone, es-ES elsewhere; falls back to any region the recogniser offers.
    static func bestLocale(forLanguage code: String) -> Locale {
        let all = SFSpeechRecognizer.supportedLocales()
        if let exact = all.first(where: { $0.identifier == code }) { return exact }
        let region = Locale.current.region?.identifier ?? ""
        let same = all.filter { $0.language.languageCode?.identifier == code }
        return same.first { $0.region?.identifier == region } ?? same.first { $0.identifier.hasPrefix(code + "-" + code.uppercased()) } ?? same.first ?? Locale(identifier: code)
    }

    static var supportedLocales: [Locale] { SFSpeechRecognizer.supportedLocales().sorted { ($0.localizedString(forIdentifier: $0.identifier) ?? "") < ($1.localizedString(forIdentifier: $1.identifier) ?? "") } }

    func start() {
        errorText = nil
        Permission.speech { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                guard status == .authorized else { self.errorText = "Allow Speech Recognition in Settings."; return }
                Permission.microphone { ok in
                    Task { @MainActor in
                        guard ok else { self.errorText = "Allow microphone access in Settings."; return }
                        self.begin()
                    }
                }
            }
        }
    }

    private func begin() {
        recognizer = SFSpeechRecognizer(locale: locale)
        guard let recognizer, recognizer.isAvailable else { errorText = "Speech recognition isn't available for this language right now."; return }
        onDevice = recognizer.supportsOnDeviceRecognition
        let session = AVAudioSession.sharedInstance()
        // Does another app already hold audio (a call, a recorder, music)? Captured before we activate
        // so we can give an honest message if the mic never frees up.
        let otherAudioBusy = session.isOtherAudioPlaying
        // Coexist with other audio instead of fighting for the session: .mixWithOthers lets captions
        // run alongside a call that's on speaker (and never cuts the other app off), and we don't duck
        // it — ducking would quiet the very audio we're trying to caption.
        try? session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
        // The input node reports a 0 Hz format for a moment right after activation, and keeps doing so
        // while another app owns the mic (e.g. a Teams/phone call). Wait briefly for it to come up
        // rather than dead-ending on the first check — a transient should never make the user retry by hand.
        Task { @MainActor [weak self] in
            guard let self, !self.running else { return }
            let input = self.engine.inputNode
            var format = input.outputFormat(forBus: 0)
            var tries = 0
            while format.sampleRate <= 0 && tries < 6 {
                try? await Task.sleep(for: .milliseconds(120))
                format = input.outputFormat(forBus: 0)
                tries += 1
            }
            guard format.sampleRate > 0 else {
                self.errorText = otherAudioBusy
                    ? "Another app is using the microphone — likely a call. Live Captions listens through the mic, so it can't hear the other side of a call on a headset; put the call on speaker, then tap Start."
                    : "The microphone didn't start. Close anything else that might be using it (a call or recorder), then tap Start again."
                return
            }
            if !self.tapInstalled {
                input.installSendableTap(bufferSize: 1024, format: format) { [weak self] buffer, _ in
                    self?.sink?.append(buffer)
                }
                self.tapInstalled = true
            }
            self.engine.prepare()
            do { try self.engine.start() } catch {
                self.errorText = "Couldn't start the microphone. Close anything else using it, then tap Start again."
                return
            }
            self.running = true
            self.newSegment()
        }
    }

    private func newSegment() {
        guard let recognizer else { return }
        task?.cancel()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                guard let self else { return }
                if let text, !text.isEmpty { self.live = text }
                // A segment ends on a natural pause (final) or an error (failed). Commit what we have
                // and, while still running, immediately roll a fresh segment so a pause never kills
                // capture — the already-committed text is kept, we just continue after it.
                if final || failed { self.commitLive(); if self.running { self.newSegment() } }
            }
        }
        rollTimer?.cancel()
        rollTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(50))
            guard let self, !Task.isCancelled, self.running else { return }
            self.request?.endAudio()   // the task will deliver a final result, then we start a fresh segment
            try? await Task.sleep(for: .milliseconds(400))
            // If the final callback already rolled a new segment (it resets this timer), don't double it.
            guard !Task.isCancelled else { return }
            if self.running { self.commitLive(); self.newSegment() }
        }
    }

    private func commitLive() {
        let t = live.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty, committed.last != t { committed.append(t) }
        live = ""
    }

    func stop(keepText: Bool = true) {
        rollTimer?.cancel(); rollTimer = nil
        request?.endAudio(); task?.cancel(); task = nil; request = nil
        if engine.isRunning { engine.stop() }
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        running = false
        commitLive()
        if !keepText { committed = [] }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func clear() { committed = []; live = "" }
}
