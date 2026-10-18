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
    @Published var locale = Locale(identifier: Locale.preferredLanguages.first ?? "en-US") { didSet { if running { restart() } } }

    var transcript: String { (committed + [live]).filter { !$0.isEmpty }.joined(separator: "\n") }

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest? { didSet { sink = request } }
    nonisolated(unsafe) private var sink: SFSpeechAudioBufferRecognitionRequest?   // read by the realtime audio tap
    private var task: SFSpeechRecognitionTask?
    private var rollTimer: Task<Void, Never>?
    private var tapInstalled = false

    static var supportedLocales: [Locale] { SFSpeechRecognizer.supportedLocales().sorted { ($0.localizedString(forIdentifier: $0.identifier) ?? "") < ($1.localizedString(forIdentifier: $1.identifier) ?? "") } }

    func start() {
        errorText = nil
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                guard status == .authorized else { self.errorText = "Allow Speech Recognition in Settings."; return }
                AVAudioApplication.requestRecordPermission { ok in
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
        try? session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
        if !tapInstalled {
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.sink?.append(buffer)
            }
            tapInstalled = true
        }
        engine.prepare()
        do { try engine.start() } catch { errorText = "Couldn't start the microphone."; return }
        running = true
        newSegment()
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
                if final || failed { self.commitLive(); if self.running, failed { self.newSegment() } }
            }
        }
        rollTimer?.cancel()
        rollTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(50))
            guard let self, !Task.isCancelled, self.running else { return }
            self.request?.endAudio()   // the task will deliver a final result, then we start a fresh segment
            try? await Task.sleep(for: .milliseconds(400))
            if self.running { self.commitLive(); self.newSegment() }
        }
    }

    private func commitLive() {
        let t = live.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty, committed.last != t { committed.append(t) }
        live = ""
    }

    private func restart() { stop(keepText: true); start() }

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
