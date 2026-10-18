import SwiftUI
import Speech
import AVFoundation
import UIKit

/// Live voice-to-text, transcribed on the phone (private, no upload). Tap record, talk, get clean
/// text you can copy or share — notes, memos, meeting bits.
struct AudioToTextView: View {
    @EnvironmentObject var store: StoreManager
    @StateObject private var t = AudioTranscriber()
    private var overQuota: Bool { !Usage.hasRoom("audiotext", limit: Limits.freeAudioPerDay) }

    var body: some View {
        ToolPage(title: "Audio → Text", subtitle: "Talk, and it writes it down — on your phone, private.") {
            ZStack {
                RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).fill(HandyColor.surface)
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                if t.transcript.isEmpty {
                    Text(t.recording ? "Listening…" : "Your transcript will appear here.").foregroundStyle(HandyColor.textSecondary)
                } else {
                    ScrollView { Text(t.transcript).font(HandyFont.body).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).padding(HandySpacing.s12) }
                }
            }.frame(minHeight: 200)

            if !store.isPremium { QuotaChip(name: "audiotext", limit: Limits.freeAudioPerDay).environmentObject(store) }
            if overQuota { LimitReachedBanner(message: "You've used today's \(Limits.freeAudioPerDay) free recordings.") }

            Button {
                if t.recording { t.stop() }
                else { guard Usage.use("audiotext", limit: Limits.freeAudioPerDay) else { return }; t.start() }
            } label: {
                HStack {
                    Image(systemName: t.recording ? "stop.fill" : "mic.fill")
                    Text(t.recording ? "Stop" : "Record")
                }.frame(maxWidth: .infinity)
            }
            .primaryButton().disabled(overQuota && !t.recording)

            if !t.transcript.isEmpty {
                HStack {
                    Button { UIPasteboard.general.string = t.transcript; HandyHaptics.success() } label: { Label("Copy", systemImage: "doc.on.doc") }.compactButton()
                    ShareLink(item: t.transcript) { Label("Share", systemImage: "square.and.arrow.up") }.compactButton()
                    Button { t.clear() } label: { Label("Clear", systemImage: "trash") }.textButton()
                    Spacer()
                }
            }
            if let e = t.errorText { Text(e).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .onDisappear { t.stop() }
    }
}

@MainActor
final class AudioTranscriber: ObservableObject {
    @Published var transcript = ""
    @Published var recording = false
    @Published var errorText: String?

    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start() {
        errorText = nil
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                guard status == .authorized else { self.errorText = "Allow Speech Recognition in Settings to transcribe."; return }
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
        guard let recognizer, recognizer.isAvailable else { errorText = "Speech recognition isn't available right now."; return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        nonisolated(unsafe) let sink = req   // the audio tap runs on a realtime thread
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in sink.append(buffer) }
        engine.prepare()
        do { try engine.start() } catch { errorText = "Couldn't start the microphone."; return }
        recording = true

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            // Pull out only Sendable values before hopping to the main actor.
            let text = result?.bestTranscription.formattedString
            let done = (error != nil) || (result?.isFinal ?? false)
            Task { @MainActor in
                guard let self else { return }
                if let text { self.transcript = text }
                if done { self.stop() }
            }
        }
    }

    func stop() {
        guard recording else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio(); request = nil
        task?.cancel(); task = nil
        recording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func clear() { transcript = "" }
}
