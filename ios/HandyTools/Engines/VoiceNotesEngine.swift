import Foundation
import AVFoundation
import Speech
import Accelerate

/// File-side helpers under the Voice hub: transcribe an audio file on-device, read a waveform out
/// of it, trim it to a range, and convert the raw CAF the mic tap writes into a small M4A.
enum VoiceAudio {
    /// Transcribe an audio file with SFSpeechURLRecognitionRequest (on-device when the language
    /// supports it). `partial` fires on the main thread with the growing text while it works.
    static func transcribe(_ url: URL, locale: Locale, partial: @escaping @Sendable (String) -> Void) async -> (text: String, error: String?) {
        let status: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { c in Permission.speech { c.resume(returning: $0) } }
        guard status == .authorized else { return ("", "Allow Speech Recognition in Settings to transcribe files.") }
        guard let rec = SFSpeechRecognizer(locale: locale), rec.isAvailable else { return ("", "Speech recognition isn't available for this language right now.") }
        let req = SFSpeechURLRecognitionRequest(url: url)
        req.shouldReportPartialResults = true
        req.addsPunctuation = true
        if rec.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        final class Box: @unchecked Sendable { var done = false; var text = ""; let lock = NSLock() }
        let box = Box()
        return await withCheckedContinuation { cont in
            _ = rec.recognitionTask(with: req) { result, error in
                _ = rec   // keep the recogniser alive for the whole task
                box.lock.lock(); defer { box.lock.unlock() }
                if box.done { return }
                if let t = result?.bestTranscription.formattedString, !t.isEmpty { box.text = t; DispatchQueue.main.async { partial(t) } }
                if result?.isFinal == true {
                    box.done = true; cont.resume(returning: (box.text, nil))
                } else if error != nil {
                    box.done = true; cont.resume(returning: (box.text, box.text.isEmpty ? "Couldn't make out any speech in that file." : nil))
                }
            }
        }
    }

    /// `bars` normalised RMS values (0…1) across the whole file — the static waveform under Trim.
    static func peaks(_ url: URL, bars: Int = 48) -> [Float] {
        guard let f = try? AVAudioFile(forReading: url), f.length > 0 else { return [] }
        let chunk = AVAudioFrameCount(max(1, Int(f.length) / bars))
        guard let buf = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: chunk) else { return [] }
        var out: [Float] = []
        for _ in 0..<bars {
            buf.frameLength = 0
            guard (try? f.read(into: buf, frameCount: chunk)) != nil, buf.frameLength > 0, let ch = buf.floatChannelData?[0] else { break }
            var rms: Float = 0
            vDSP_rmsqv(ch, 1, &rms, vDSP_Length(buf.frameLength))
            out.append(rms)
        }
        let mx = out.max() ?? 0
        return mx > 0 ? out.map { $0 / mx } : out
    }

    static func duration(_ url: URL) -> Double {
        guard let f = try? AVAudioFile(forReading: url), f.fileFormat.sampleRate > 0 else { return 0 }
        return Double(f.length) / f.fileFormat.sampleRate
    }

    /// Keep only [start, end] seconds, written as a fresh M4A (AAC) — the original is untouched.
    static func trim(_ src: URL, start: Double, end: Double) async -> URL? {
        guard end > start else { return nil }
        let asset = AVURLAsset(url: src)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else { return nil }
        let out = VideoEngine.tempURL("m4a")
        session.outputURL = out
        session.outputFileType = .m4a
        session.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), end: CMTime(seconds: end, preferredTimescale: 600))
        await session.export()
        return session.status == .completed ? out : nil
    }

    /// Raw CAF from the mic tap → M4A (≈10× smaller, plays and shares everywhere). Falls back to the
    /// original when the encoder can't handle it, so a recording is never lost.
    static func compact(_ src: URL) async -> URL {
        if let m4a = await VideoEngine.extractAudio(src) { try? FileManager.default.removeItem(at: src); return m4a }
        return src
    }

    /// Copy a picked file into our temp folder (security-scoped URLs from the Files picker expire).
    static func importCopy(_ url: URL) -> URL? {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
        let dst = VideoEngine.tempURL(ext)
        do { try FileManager.default.copyItem(at: url, to: dst); return dst } catch { return nil }
    }

    static func clock(_ s: Double) -> String {
        let t = max(0, Int(s.rounded()))
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

/// Play one file with a seekable position — the player under a note and under the Trim tab.
@MainActor final class AudioPlayback: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var playing = false
    @Published var time: Double = 0
    @Published var duration: Double = 0
    @Published private(set) var url: URL?
    private var player: AVAudioPlayer?
    private var ticker: Task<Void, Never>?

    func load(_ url: URL) {
        stop()
        self.url = url
        player = try? AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
        duration = player?.duration ?? 0
        time = 0
    }
    func toggle(_ url: URL) {
        if self.url != url { load(url) }
        playing ? pause() : play()
    }
    func play() {
        guard let p = player else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers]); try? AVAudioSession.sharedInstance().setActive(true)
        p.play(); playing = true
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, self.playing else { return }
                self.time = self.player?.currentTime ?? 0
            }
        }
    }
    func pause() { player?.pause(); playing = false; ticker?.cancel() }
    func stop() { player?.stop(); player = nil; url = nil; playing = false; ticker?.cancel(); time = 0; duration = 0 }
    func seek(_ t: Double) { player?.currentTime = max(0, min(duration, t)); time = player?.currentTime ?? 0 }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.playing = false; self.time = 0; self.ticker?.cancel() }
    }
}
