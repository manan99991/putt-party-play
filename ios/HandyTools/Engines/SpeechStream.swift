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

    /// Mic level 0…1 (≈ −50 dB … 0 dB), published ~12× a second while running — drives the hub waveforms.
    @Published var level: Float = 0
    /// Set BEFORE start() to also write the raw mic audio to this file (CAF, float PCM) while recognising.
    /// With a record target the session still starts when speech recognition is unavailable or denied —
    /// you get the recording, and `errorText` explains why there's no transcript. Cleared by stop().
    var recordURL: URL?
    /// The file the last session wrote to, if any.
    private(set) var recordedURL: URL?

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest? { didSet { sink = request } }
    nonisolated(unsafe) private var sink: SFSpeechAudioBufferRecognitionRequest?   // read by the realtime audio tap
    nonisolated(unsafe) private var writer: AVAudioFile?                            // written by the realtime audio tap
    nonisolated(unsafe) private var tapCount = 0
    private var speechAuthorized = false
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
                self.speechAuthorized = status == .authorized
                if !self.speechAuthorized {
                    self.errorText = self.recordURL == nil ? "Allow Speech Recognition in Settings." : "Allow Speech Recognition in Settings to get a transcript — the recording still works."
                    if self.recordURL == nil { return }
                }
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
        recognizer = speechAuthorized ? SFSpeechRecognizer(locale: locale) : nil
        let canRecognize = recognizer?.isAvailable ?? false
        if !canRecognize {
            if speechAuthorized { errorText = "Speech recognition isn't available for this language right now." }
            if recordURL == nil { return }
        }
        onDevice = recognizer?.supportsOnDeviceRecognition ?? true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { errorText = "The microphone isn't ready yet. Try again in a moment."; return }
        recordedURL = nil
        if let url = recordURL {
            try? FileManager.default.removeItem(at: url)
            writer = try? AVAudioFile(forWriting: url, settings: format.settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
            recordedURL = writer == nil ? nil : url
        }
        if !tapInstalled {
            input.installSendableTap(bufferSize: 1024, format: format) { [weak self] buffer, _ in
                guard let self else { return }
                self.sink?.append(buffer)
                if let w = self.writer { try? w.write(from: buffer) }
                self.tapCount += 1
                if self.tapCount % 4 == 0, let ch = buffer.floatChannelData?[0] {
                    let n = Int(buffer.frameLength)
                    var sum: Float = 0
                    for i in 0..<n { sum += ch[i] * ch[i] }
                    let rms = sqrt(sum / Float(max(1, n)))
                    let v = min(1, max(0, (20 * log10(max(rms, 1e-5)) + 50) / 50))
                    Task { @MainActor in self.level = v }
                }
            }
            tapInstalled = true
        }
        engine.prepare()
        do { try engine.start() } catch { writer = nil; errorText = "Couldn't start the microphone."; return }
        running = true
        if canRecognize { newSegment() }
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
        writer = nil   // closes the recording file
        recordURL = nil
        running = false
        level = 0
        commitLive()
        if !keepText { committed = [] }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func clear() { committed = []; live = "" }
}
