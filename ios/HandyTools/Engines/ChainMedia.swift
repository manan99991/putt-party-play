import UIKit
import SwiftUI
import AVFoundation
import Speech
import CoreImage
@preconcurrency import Translation
#if canImport(SwiftOGG)
import SwiftOGG   // libopus/libogg: decodes WhatsApp/Telegram Ogg-Opus voice notes, which AVFoundation can't demux
#endif

/// The steps of Build your own that need the phone's speech engine, a voice, the translator, the writing model or the
/// video encoder. App only: the share sheet has a small stand-in (see ShareExtension/EngineShims.swift).
///
/// Every one of them checks what this phone can do first. A phone that can't run a step gets a plain sentence saying
/// so; the step is greyed out in the builder and every other step keeps working.
enum ChainMedia {
    /// Speech is only ever recognised on the phone. A phone (or language) without on-device recognition can't use
    /// these steps, because Tenzy never sends a recording away.
    static let canTranscribe: Bool = (SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer())?.supportsOnDeviceRecognition == true

    static func unavailable(_ b: Block) -> String? {
        switch b {
        case .speechText, .videoCaptions:
            return canTranscribe ? nil : "It can't turn speech into text by itself in this phone's language, and Tenzy never sends a recording away to do it."
        case .rewrite:
            return AIEngine.isAvailable ? nil : "Rewriting needs the writing model that newer phones carry, with Apple Intelligence turned on in Settings."
        default:
            return nil
        }
    }

    static func apply(_ step: ChainStep, to input: ChainPayload, dryRun: Bool) async -> ChainExtras.Outcome? {
        let b = step.block
        switch (b, input) {
        case (.speechText, .file(let d, let ext)):
            let url = VideoEngine.tempURL(ext.isEmpty ? "m4a" : ext.lowercased())
            guard (try? d.write(to: url)) != nil else { return .failure(.failed(b)) }
            defer { try? FileManager.default.removeItem(at: url) }
            // "auto"/unset = the phone's own language (the smart default); a chosen language transcribes in it.
            let lang = step.settings["lang"] ?? "auto"
            let auto = lang == "auto" || lang.isEmpty
            let locale = auto ? Locale.current : Locale(identifier: lang)
            switch await Transcriber.listen(to: url, locale: locale, detect: auto) {
            case .failure(let p): return .failure(.invalid(p.words(for: b)))
            case .success(let heard):
                var text = heard.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty, !heard.cantDo.isEmpty {
                    text += "\n\n(" + "This phone can't write out \(heard.cantDo.joined(separator: ", ")) on the device, so those parts may be missing or spelled as English." + ")"
                }
                return text.isEmpty ? .failure(.invalid("\(b.title) didn't hear any words in that recording.")) : .success(.text(text))
            }

        case (.readAloud, .text(let t)):
            let words = String(t.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20_000))
            guard !words.isEmpty else { return .failure(.nothingFound(b)) }
            guard let url = await speak(words, rate: ttsRate(step.settings["speed"])), let d = try? Data(contentsOf: url), !d.isEmpty else {
                return .failure(.invalid("Read it aloud couldn't make the audio on this phone. Check that a voice is installed in Settings, under Accessibility, Spoken Content."))
            }
            return .success(.file(d, ext: url.pathExtension.isEmpty ? "m4a" : url.pathExtension.lowercased()))

        case (.translate, .text(let t)):
            let words = t.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !words.isEmpty else { return .failure(.nothingFound(b)) }
            let to = ChainText.languageCode(step.settings["to"])
            let from = NLLanguageGuess.language(of: words)
            if let from, from.hasPrefix(to) { return .success(.text(words)) }      // already in that language
            guard let out = await TranslateBridge.run(words, from: from, to: to), !out.isEmpty else {
                return .failure(.invalid("Translate couldn't finish. Keep Tenzy open, and if the phone asks to download \(ChainText.languageName(to)), allow it once. After that it works with no connection."))
            }
            return .success(.text(out))

        case (.rewrite, .text(let t)):
            let words = String(t.trimmingCharacters(in: .whitespacesAndNewlines).prefix(6000))
            guard !words.isEmpty else { return .failure(.nothingFound(b)) }
            let ask = ChainText.rewriteAsk(ChainText.rewriteStyle(step.settings["style"]))
            guard let out = try? await AIEngine.run(instructions: ask, prompt: words), !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .failure(.failed(b)) }
            return .success(.text(out.trimmingCharacters(in: .whitespacesAndNewlines)))

        case (.videoTrim, .video(let url)):
            let length = await VideoEngine.duration(url)
            // The part you picked on the run screen, else the tool's default (first/last N seconds).
            let picked = Double(step.settings["start"] ?? "").flatMap { s in Double(step.settings["end"] ?? "").map { (start: max(0, s), end: min(length, $0)) } }
            let keep = picked ?? ChainText.trimWindow(side: step.settings["side"], secs: step.settings["secs"], duration: length)
            guard keep.end > keep.start, let out = await VideoEngine.trim(url, start: keep.start, end: keep.end) else { return .failure(.failed(b)) }
            return .success(.video(out))

        case (.videoGif, .video(let url)):
            // The first six seconds. Put "Keep the start or the end" before this step to pick another part.
            let length = await VideoEngine.duration(url)
            guard let gif = await tenzyGIFFromVideo(url: url, start: 0, duration: min(max(length, 0.2), 6), fps: 10, speed: 1, maxDim: 480),
                  let d = try? Data(contentsOf: gif) else { return .failure(.failed(b)) }
            return .success(.file(d, ext: "gif"))

        case (.voiceChange, .file(let d, let ext)):
            let url = VideoEngine.tempURL(ext.isEmpty ? "m4a" : ext.lowercased())
            guard (try? d.write(to: url)) != nil else { return .failure(.failed(b)) }
            defer { try? FileManager.default.removeItem(at: url) }
            // Character voices (robot/alien/monster) pitch-shift without changing tempo via offline DSP; the classic
            // chipmunk/deep/giant/helium stay on the simple varispeed path. DSP falls back to varispeed on any failure.
            let voiceID = step.settings["voice"]
            let wav = (voiceID.flatMap { characters[$0] }.flatMap { revoiceDSP(url, $0) })
                ?? revoice(url, rate: ChainText.voiceRate(voiceID))
            guard let wav else {
                return .failure(.invalid("Change the voice couldn't read that recording. Try another one."))
            }
            return .success(.file(wav, ext: "wav"))

        case (.videoSpeed, .video(let url)):
            guard let out = await respeed(url, rate: ChainText.speedRate(step.settings["speed"])) else { return .failure(.failed(b)) }
            return .success(.video(out))

        case (.videoCelebrate, .video(let url)):
            // The same decorations and words as the Celebrate tool; an empty choice means the next festival coming up.
            let picked = step.settings["theme"] ?? ""
            let theme = picked.isEmpty ? (Celebrate.comingUp().first ?? Celebrate.themes[0]) : (Celebrate.theme(picked) ?? Celebrate.resolve(picked))
            let words = (step.settings["text"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            var cap = Celebrate.Caption(text: words.isEmpty ? L(theme.greeting) : words)
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url)); gen.appliesPreferredTrackTransform = true; gen.maximumSize = CGSize(width: 640, height: 640)
            cap.center = Celebrate.clearSpot(in: try? await gen.image(at: CMTime(seconds: 1, preferredTimescale: 600)).image)
            guard let out = await Celebrate.export(url, theme: theme, amount: 1, caption: step.settings["words"] == "0" ? nil : cap) else { return .failure(.failed(b)) }
            return .success(.video(out))

        case (.postTo, .video(let url)):
            // The video goes on as it is: the finish is Post it's own card, which makes it ready for the platform
            // (shape, length or story pieces, size) and opens the app — exactly as the Post it tool does.
            return .success(.video(url))

        case (.videoLoop, .video(let url)):
            // The liveliest moment of the video, looped in the chosen style (Snap, Stutter, Slingshot, Dramatic zoom…).
            guard let gif = await Boomerang.make(url, style: step.settings["style"]),
                  let d = try? Data(contentsOf: gif) else { return .failure(.failed(b)) }
            return .success(.file(d, ext: "gif"))

        case (.videoRotate, .video(let url)):
            let turn = ChainText.turnDegrees(step.settings["turn"])
            let side: CGImagePropertyOrientation = turn == 270 ? .left : turn == 180 ? .down : .right
            let turned = await reframe(url, size: { turn == 180 ? $0 : CGSize(width: $0.height, height: $0.width) }, change: { frame, _ in
                let t = frame.oriented(side)
                return t.transformed(by: CGAffineTransform(translationX: -t.extent.minX, y: -t.extent.minY))
            })
            guard let turned else { return .failure(.failed(b)) }
            return .success(.video(turned))

        case (.videoVertical, .video(let url)):
            let tall = await reframe(url, size: { tallCrop($0).size }, change: { frame, _ in
                let crop = tallCrop(frame.extent.size).offsetBy(dx: frame.extent.minX, dy: frame.extent.minY)
                return frame.cropped(to: crop).transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
            })
            guard let tall else { return .failure(.failed(b)) }
            return .success(.video(tall))

        case (.videoCaptions, .video(let url)):
            guard let sound = await VideoEngine.extractAudio(url) else { return .failure(.invalid("Add captions found no sound in that video.")) }
            defer { try? FileManager.default.removeItem(at: sound) }
            // Captions hear the same way as "Write out what was said": your languages, the surer one per stretch.
            switch await Transcriber.listen(to: sound, detect: true) {
            case .failure(let p): return .failure(.invalid(p.words(for: b)))
            case .success(let heard):
                let lines = ChainText.captionLines(heard.words)
                guard !lines.isEmpty else { return .failure(.invalid("Add captions didn't hear any words in that video.")) }
                let art = CaptionArt(lines: lines)
                let captioned = await reframe(url, size: { $0 }, change: { frame, time in art.draw(over: frame, at: time) })
                guard let captioned else { return .failure(.failed(b)) }
                return .success(.video(captioned))
            }

        default:
            return nil
        }
    }

    /// The speaking rate for "Read it aloud", from the tool's speed option. Normal is the device default.
    static func ttsRate(_ speed: String?) -> Float {
        let d = AVSpeechUtteranceDefaultSpeechRate
        switch speed {
        case "slow": return max(AVSpeechUtteranceMinimumSpeechRate, d * 0.8)
        case "fast": return min(AVSpeechUtteranceMaximumSpeechRate, d * 1.28)
        default: return d
        }
    }

    @MainActor private static func speak(_ text: String, rate: Float = AVSpeechUtteranceDefaultSpeechRate) async -> URL? {
        let reader = Reader()
        reader.rate = rate
        reader.load(text)
        return await reader.exportAudio()
    }

    /// The recording played faster (higher, like a chipmunk) or slower (deeper), as a .wav file. At most the first ten minutes.
    static func revoice(_ url: URL, rate: Double) -> Data? {
        guard rate > 0, let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let limit = Int(min(file.length, Int64(format.sampleRate * 600)))
        let lanes = max(1, Int(format.channelCount))
        guard limit > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 65_536) else { return nil }
        var pcm: [UInt8] = []
        pcm.reserveCapacity(limit * 2)
        // Read a piece at a time, so a long recording never sits in memory twice over.
        while pcm.count < limit * 2 {
            guard (try? file.read(into: buffer, frameCount: 65_536)) != nil, buffer.frameLength > 0, let sound = buffer.floatChannelData else { break }
            for i in 0..<Int(buffer.frameLength) {
                var sum: Float = 0
                for c in 0..<lanes { sum += sound[c][i] }
                let v = Int16(max(-1, min(1, sum / Float(lanes))) * 32767)
                pcm.append(UInt8(truncatingIfNeeded: v)); pcm.append(UInt8(truncatingIfNeeded: v >> 8))
            }
        }
        guard !pcm.isEmpty else { return nil }
        return Data(ChainText.wavHeader(sampleRate: Int((format.sampleRate * rate).rounded()), channels: 1, dataBytes: pcm.count)) + Data(pcm)
    }

    /// Voice "characters" that need real DSP — the pitch shifted WITHOUT changing tempo (so the speech stays
    /// intelligible, unlike the varispeed chipmunk/deep), plus a timbre effect. Keyed by the same voice id in settings.
    struct VoiceCharacter {
        let pitchCents: Float
        let distortion: AVAudioUnitDistortionPreset?
        let wet: Float
        var rate: Float = 1                          // speaking speed (1 = as recorded); pitch stays independent
        var reverb: AVAudioUnitReverbPreset? = nil   // the space the voice is in
        var reverbWet: Float = 0
    }
    /// Every voice is a real pitch shift that keeps the words clear, tuned per character: a touch faster for
    /// the small voices, slower and roomier for the big ones, a timbre for the strange ones.
    static let characters: [String: VoiceCharacter] = [
        "chipmunk": VoiceCharacter(pitchCents: 1000, distortion: nil, wet: 0, rate: 1.12),
        "helium":   VoiceCharacter(pitchCents:  700, distortion: nil, wet: 0, rate: 1.04, reverb: .smallRoom, reverbWet: 8),
        "deep":     VoiceCharacter(pitchCents: -450, distortion: nil, wet: 0, rate: 0.97),
        "giant":    VoiceCharacter(pitchCents: -900, distortion: nil, wet: 0, rate: 0.9, reverb: .largeHall, reverbWet: 22),
        "robot":    VoiceCharacter(pitchCents: -150, distortion: .multiDecimated2,    wet: 55),
        "alien":    VoiceCharacter(pitchCents:  500, distortion: .speechAlienChatter, wet: 45),
        "monster":  VoiceCharacter(pitchCents: -650, distortion: .multiBrokenSpeaker, wet: 35, rate: 0.95, reverb: .mediumHall, reverbWet: 15),
        "walkie":   VoiceCharacter(pitchCents:    0, distortion: .speechRadioTower,   wet: 60),
        "cave":     VoiceCharacter(pitchCents: -100, distortion: nil, wet: 0, reverb: .cathedral, reverbWet: 45),
        "ghost":    VoiceCharacter(pitchCents:  250, distortion: .speechWaves,        wet: 30, rate: 0.93, reverb: .largeHall2, reverbWet: 40),
    ]

    /// Pitch-shifts a recording without changing its tempo and adds a character timbre, rendered entirely offline
    /// on the phone (no playback, nothing uploaded). Returns 16-bit mono WAV, or nil so the caller falls back to
    /// the simple varispeed path — any failure is graceful, never a crash.
    static func revoiceDSP(_ url: URL, _ c: VoiceCharacter, maxSeconds: Double? = nil) -> Data? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        guard format.sampleRate > 0, file.length > 0, file.length < Int64(format.sampleRate * 600) else { return nil }
        // A preview renders just the opening seconds; the result renders it all.
        let inFrames = maxSeconds.map { min(file.length, Int64(format.sampleRate * $0)) } ?? file.length
        let rate = max(0.5, min(2, c.rate))
        let outFrames = Int64(Double(inFrames) / Double(rate)) + (c.reverb != nil ? Int64(format.sampleRate * 1.2) : 0)
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let pitch = AVAudioUnitTimePitch(); pitch.pitch = max(-2400, min(2400, c.pitchCents)); pitch.rate = rate
        engine.attach(player); engine.attach(pitch)
        engine.connect(player, to: pitch, format: format)
        var tail: AVAudioNode = pitch
        if let preset = c.distortion {
            let dist = AVAudioUnitDistortion(); dist.loadFactoryPreset(preset); dist.wetDryMix = c.wet
            engine.attach(dist); engine.connect(pitch, to: dist, format: format); tail = dist
        }
        if let room = c.reverb {
            let verb = AVAudioUnitReverb(); verb.loadFactoryPreset(room); verb.wetDryMix = c.reverbWet
            engine.attach(verb); engine.connect(tail, to: verb, format: format); tail = verb
        }
        engine.connect(tail, to: engine.mainMixerNode, format: format)
        do {
            try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
            try engine.start()
        } catch { return nil }
        defer { engine.stop() }
        player.scheduleSegment(file, startingFrame: 0, frameCount: AVAudioFrameCount(inFrames), at: nil)
        player.play()
        guard let render = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: engine.manualRenderingMaximumFrameCount) else { return nil }
        let lanes = max(1, Int(engine.manualRenderingFormat.channelCount))
        let cap = Int(outFrames) * 2
        var pcm: [UInt8] = []; pcm.reserveCapacity(cap)
        while engine.manualRenderingSampleTime < outFrames && pcm.count < cap {
            let remaining = outFrames - engine.manualRenderingSampleTime
            let frames = AVAudioFrameCount(min(Int64(render.frameCapacity), remaining))
            guard let status = try? engine.renderOffline(frames, to: render), status == .success,
                  let ch = render.floatChannelData, render.frameLength > 0 else { break }
            for i in 0..<Int(render.frameLength) {
                var sum: Float = 0
                for c2 in 0..<lanes { sum += ch[c2][i] }
                let v = Int16(max(-1, min(1, sum / Float(lanes))) * 32767)
                pcm.append(UInt8(truncatingIfNeeded: v)); pcm.append(UInt8(truncatingIfNeeded: v >> 8))
            }
        }
        guard !pcm.isEmpty else { return nil }
        return Data(ChainText.wavHeader(sampleRate: Int(engine.manualRenderingFormat.sampleRate.rounded()), channels: 1, dataBytes: pcm.count)) + Data(pcm)
    }

    /// Soundboard: apply one named character voice to an already-readable audio file, returning 16-bit mono WAV.
    /// robot/alien/monster use the offline pitch-shift + timbre DSP (so the speech stays intelligible); the classic
    /// chipmunk/helium/giant/deep use the simple varispeed path, and a DSP voice falls back to varispeed if the
    /// device can't render the effect. Pure reuse of the proven voice-change path — no new DSP. Returns nil only
    /// when the audio itself can't be read at all.
    /// The opening seconds of a recording in a voice, for "hear it before you choose".
    static func previewVoice(_ url: URL, voice: String, seconds: Double = 8) -> Data? {
        guard let c = characters[voice] else { return nil }
        return revoiceDSP(url, c, maxSeconds: seconds)
    }

    static func soundboardVoice(_ url: URL, voice: String) -> Data? {
        if let c = characters[voice], let dsp = revoiceDSP(url, c) { return dsp }
        return revoice(url, rate: ChainText.voiceRate(voice))
    }

    /// The same video played slower or faster. It comes out without sound, since sound at another speed is only noise.
    /// Faster or slower, sound kept: voices keep their natural pitch (no chipmunk, no growl), the picture is turned
    /// upright. (It used to drop the sound entirely.)
    static func respeed(_ url: URL, rate: Double) async -> URL? {
        guard rate > 0 else { return nil }
        await MainActor.run { RunProgress.shared.begin() }
        let out = await VideoJoin.join([url], rate: rate) { f in Task { @MainActor in RunProgress.shared.set(min(0.99, f)) } }
        await MainActor.run { RunProgress.shared.end() }
        return out
    }

    /// The middle of the frame at 9:16 (a phone held upright), with even pixel sizes as video encoders need.
    static func tallCrop(_ s: CGSize) -> CGRect {
        func even(_ v: CGFloat) -> CGFloat { max(2, (v / 2).rounded(.down) * 2) }
        var w = s.width, h = s.height
        if w / max(1, h) > 9.0 / 16.0 { w = even(h * 9 / 16); h = even(h) } else { h = even(min(h, w * 16 / 9)); w = even(w) }
        return CGRect(x: ((s.width - w) / 2).rounded(.down), y: ((s.height - h) / 2).rounded(.down), width: w, height: h)
    }

    /// Re-saves the video with every frame passed through `change`, at the frame size `size` returns. The new file
    /// carries no location or camera details. nil when this phone's encoder can't do it.
    private static func reframe(_ url: URL, size: (CGSize) -> CGSize, change: @escaping (CIImage, Double) -> CIImage) async -> URL? {
        let asset = AVURLAsset(url: url)
        guard (try? await asset.loadTracks(withMediaType: .video))?.isEmpty == false else { return nil }
        let comp = AVMutableVideoComposition(asset: asset) { request in
            request.finish(with: change(request.sourceImage, request.compositionTime.seconds), context: nil)
        }
        comp.renderSize = size(comp.renderSize)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let out = VideoEngine.tempURL("mp4")
        session.outputURL = out; session.outputFileType = .mp4; session.videoComposition = comp; session.metadata = []
        return await VideoEngine.run(session, seconds: (try? await asset.load(.duration))?.seconds ?? 0) ? out : nil
    }
}

extension ChainCombine {
    /// "One GIF for everything": the results of a multi-photo run played one after another, for ever. Every picture
    /// fills the shape of the first one. nil when a result isn't a picture.
    static func oneGif(_ results: [ChainPayload], long: CGFloat = 600, hold: Double = 0.6) -> ChainPayload? {
        var images: [UIImage] = []
        for r in results {
            switch r {
            case .image(let i): images.append(i)
            case .file(let d, let ext) where ChainPayload.isPhoto(ext):
                guard let i = UIImage(data: d) else { return nil }
                images.append(i)
            default: return nil
            }
        }
        guard let first = images.first, first.size.width > 0, first.size.height > 0 else { return nil }
        let k = long / max(first.size.width, first.size.height)
        let size = CGSize(width: max(2, (first.size.width * k).rounded()), height: max(2, (first.size.height * k).rounded()))
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        let frames: [CGImage] = images.compactMap { img in
            UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
                let s = max(size.width / max(1, img.size.width), size.height / max(1, img.size.height))
                let w = img.size.width * s, h = img.size.height * s
                img.draw(in: CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h))
            }.cgImage
        }
        guard !frames.isEmpty, let url = tenzyWriteGIF(frames: frames, delay: hold), let d = try? Data(contentsOf: url) else { return nil }
        try? FileManager.default.removeItem(at: url)
        return .file(d, ext: "gif")
    }
}

/// A value handed over exactly once, from whichever callback gets there first (a result, an error or a timeout).
final class Once<T>: @unchecked Sendable {
    private var waiting: CheckedContinuation<T, Never>?
    private var early: T?
    private var done = false
    private let lock = NSLock()

    func wait(_ c: CheckedContinuation<T, Never>) {
        lock.lock()
        if let v = early { early = nil; lock.unlock(); c.resume(returning: v); return }
        waiting = c
        lock.unlock()
    }
    func finish(_ v: T) {
        lock.lock()
        if done { lock.unlock(); return }
        done = true
        let c = waiting; waiting = nil
        if c == nil { early = v }
        lock.unlock()
        c?.resume(returning: v)
    }
}

/// Turns a recording into words, on the phone only.
enum Transcriber {
    struct Heard {
        let text: String; let words: [(text: String, start: Double, end: Double)]
        /// Languages the person speaks that this phone can't write out on device (said plainly under the text).
        var cantDo: [String] = []
    }
    enum Problem: Error {
        case denied, unavailable, nothing, recognizerFailed
        func words(for b: Block) -> String {
            switch self {
            case .denied: return "\(b.title) needs permission to recognise speech. Allow Speech Recognition for Tenzy in Settings, then run this again."
            case .unavailable: return "\(b.title) isn't available on this phone right now. Speech can't be turned into text on the phone in its language."
            // On-device dictation erroring out (model still downloading, or Dictation turned off) looks just
            // like "no words" to the user — so say what's really wrong and how to fix it, and don't blame
            // their recording.
            case .recognizerFailed: return "\(b.title) couldn't run on-device dictation — your recording is fine. Turn on Dictation in Settings › General › Keyboard, let the language finish downloading, then run this again."
            case .nothing: return "\(b.title) didn't find any speech in that recording. If it has talking in it, make sure Dictation is on in Settings › General › Keyboard and try again."
            }
        }
    }

    /// Holds the best transcript produced so far, the live recognition task, and the quiet-timer —
    /// so a recording that never reports 'final' (common on-device past ~a minute) still yields text.
    final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var _latest: Heard?
        var idle: DispatchWorkItem?
        var task: SFSpeechRecognitionTask?
        var latest: Heard? {
            get { lock.lock(); defer { lock.unlock() }; return _latest }
            set { lock.lock(); _latest = newValue; lock.unlock() }
        }
    }

    /// A thread-safe "did any recognition window actually error" flag, so an empty result from a failing
    /// recogniser (model not ready / Dictation off) is told apart from a recording that truly has no speech.
    final class Flag: @unchecked Sendable {
        private let lock = NSLock(); private var v = false
        func set() { lock.lock(); v = true; lock.unlock() }
        var value: Bool { lock.lock(); defer { lock.unlock() }; return v }
    }

    // ── Pure, unit-tested helpers ────────────────────────────────────────────
    // The "one line from a 22-minute memo" bug was a whole-file-coverage failure. These three funcs
    // hold that logic as pure functions so EngineTests can prove, on every build, that a long file is
    // split across the WHOLE recording (not one window), that every window's text is stitched back in,
    // and that progress moves honestly 0→1. listen() below uses them, so the tests guard real behaviour.

    /// Seconds of audio each on-device recognition window covers — well inside what one request handles.
    static let windowSeconds: Double = 40

    /// File endings the recogniser's own reader (AVAudioFile) handles directly. Anything else — an MP3 or
    /// other compressed recording from an external recorder — must be transcoded first: AVAudioFile *opens*
    /// an MP3 but reads it unreliably, which is why an external MP3 ran the progress bar to 100% yet came
    /// back with no words. Pure, so a test pins which formats get transcoded.
    static let readableExts: Set<String> = ["m4a", "aac", "wav", "wave", "caf", "aif", "aiff", "mp4", "mov", "m4v", "adts"]
    static func needsTranscode(_ ext: String) -> Bool { !readableExts.contains(ext.lowercased()) }

    /// A URL the recogniser's reader can handle: the original when it's already a supported format, else a
    /// temporary .m4a transcoded from it (MP3 and friends). Falls back to the original if transcoding
    /// fails, so the worst case is the old behaviour rather than a crash.
    /// Extensions whose audio is Opus inside an Ogg container — WhatsApp and Telegram voice notes. AVFoundation
    /// can decode Opus but can't demux the Ogg container, so these are decoded to .m4a with libopus first.
    static let oggOpusExts: Set<String> = ["opus", "ogg", "oga"]

    /// Decodes an Ogg-Opus file to a temporary .m4a using libopus (SwiftOGG), or nil if the decode fails or the
    /// library isn't linked. Isolated so the rest of the pipeline is unchanged and a missing package still compiles.
    static func oggOpusToM4A(_ src: URL) -> URL? {
        #if canImport(SwiftOGG)
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("tenzy-opus-\(UUID().uuidString).m4a")
        do {
            try OGGConverter.convertOpusOGGToM4aFile(src: src, dest: out)
            if FileManager.default.fileExists(atPath: out.path) { return out }
        } catch {}
        // Not Opus: an Ogg Vorbis file (podcasts, many Android recordings) — decoded the other way, so it works
        // everywhere an Ogg is accepted (File Opener, voice tools, ready-made tools, the Share sheet).
        return VorbisAudio.toM4A(src)
        #else
        return VorbisAudio.toM4A(src)
        #endif
    }

    static func readableAudioURL(for url: URL) async -> URL {
        // WhatsApp/Telegram voice notes (Ogg-Opus) are decoded to .m4a up front; the result then flows through
        // the normal readable path. If the decode fails we fall through to the old behaviour rather than crash.
        if oggOpusExts.contains(url.pathExtension.lowercased()), let decoded = oggOpusToM4A(url) { return decoded }
        guard needsTranscode(url.pathExtension) else { return url }
        let asset = AVURLAsset(url: url)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else { return url }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("tenzy-stt-\(UUID().uuidString).m4a")
        export.outputURL = out
        export.outputFileType = .m4a
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            export.exportAsynchronously { cont.resume() }
        }
        return export.status == .completed ? out : url
    }

    /// Number of windows a recording of `frames` at `sampleRate` is split into. It always covers the
    /// whole file: a 22-minute memo is ~33 windows, never 1. Zero only for an empty/invalid file.
    static func windowCount(frames: AVAudioFramePosition, sampleRate: Double, seconds: Double = windowSeconds) -> Int {
        guard frames > 0, sampleRate > 0, seconds > 0 else { return 0 }
        return Int((Double(frames) / (sampleRate * seconds)).rounded(.up))
    }

    /// Stitches the per-window transcripts back into one, dropping empties and trimming — turning the
    /// ~33 window results of a long memo back into a single transcript.
    static func stitch(_ parts: [String]) -> String {
        parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Fraction 0…1 of the file consumed — what the progress bar's time-remaining is derived from.
    static func fraction(_ pos: AVAudioFramePosition, of total: AVAudioFramePosition) -> Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(pos) / Double(total)))
    }

    /// The languages worth trying when the tool is set to "auto": the phone's own, then the person's other
    /// preferred languages (a family that speaks Hindi at home and English at work has both), each only if this
    /// phone can recognise it on device.
    static func candidateLocales(_ preferred: [String] = Locale.preferredLanguages, current: Locale = .current) -> [Locale] {
        var out: [Locale] = [], seen = Set<String>()
        // Indian languages are often mixed with English: Indian English hears that English far better than US English.
        let indian: Set<String> = ["hi", "gu", "mr", "ta", "te", "bn", "kn", "ml", "pa", "ur"]
        let codes = ([current.identifier] + preferred).compactMap { Locale(identifier: $0).language.languageCode?.identifier }
        var ids = [current.identifier] + preferred
        if current.region?.identifier == "IN" || codes.contains(where: indian.contains) { ids.insert("en-IN", at: 1) }
        for id in ids {
            let l = Locale(identifier: id)
            let key = l.identifier == "en-IN" ? "en-IN" : (l.language.languageCode?.identifier ?? id)
            guard !seen.contains(key) else { continue }
            seen.insert(key); out.append(l)
            if out.count == 4 { break }
        }
        return out
    }

    /// One window of speech through one recogniser: the words and how sure it was (0…1, averaged over words).
    /// How long to wait for the recogniser's answer on a stretch of audio: half again its length plus a few seconds,
    /// never more than a minute. A memo of silence or music gets no answer at all — with a flat minute per language
    /// tried and per stretch, a 3-second clip with no words sat for minutes before saying so (21 Nov test run).
    static func waitFor(seconds: Double) -> Double { min(60, max(8, seconds * 1.5 + 8)) }

    private static func probe(_ recognizer: SFSpeechRecognizer, url: URL) async -> (text: String, sure: Double) {
        guard let file = try? AVAudioFile(forReading: url) else { return ("", 0) }
        let fmt = file.processingFormat
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.requiresOnDeviceRecognition = true; req.shouldReportPartialResults = false
        let once = Once<(String, Double)>()
        let box = Box()
        box.task = recognizer.recognitionTask(with: req) { result, error in
            if let result, result.isFinal {
                let segs = result.bestTranscription.segments
                let sure = segs.isEmpty ? 0 : segs.map { Double($0.confidence) }.reduce(0, +) / Double(segs.count)
                once.finish((result.bestTranscription.formattedString, sure * min(1, Double(segs.count) / 8)))
            } else if error != nil { once.finish(("", 0)) }
        }
        let frames = AVAudioFrameCount(min(Double(file.length), fmt.sampleRate * windowSeconds))
        var read: AVAudioFrameCount = 0
        while read < frames {
            guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: min(16000, frames - read)) else { break }
            do { try file.read(into: buf, frameCount: min(16000, frames - read)) } catch { break }
            if buf.frameLength == 0 { break }
            req.append(buf); read += buf.frameLength
        }
        req.endAudio()
        // A recogniser that never answers just loses the comparison — it doesn't hold the job up. With no speech in it,
        // a stretch can get no answer at all, so the wait matches the audio's length instead of a flat minute.
        DispatchQueue.global().asyncAfter(deadline: .now() + waitFor(seconds: Double(read) / fmt.sampleRate)) { box.task?.cancel(); once.finish(("", 0)) }
        let r = await withCheckedContinuation { once.wait($0) }
        return (r.0, r.1)
    }

    static func listen(to url: URL, locale: Locale = .current, detect: Bool = false) async -> Result<Heard, Problem> {
        var cantDo: [String] = []
        var also: SFSpeechRecognizer? = nil
        let asked = Once<SFSpeechRecognizerAuthorizationStatus>()
        Permission.speech { asked.finish($0) }
        let status = await withCheckedContinuation { asked.wait($0) }
        guard status == .authorized else { return .failure(.denied) }
        var locale = locale
        if detect {
            // Which language is it? Try the first stretch in each of the person's languages and keep the one the
            // phone is surest about, instead of forcing Hindi or Spanish speech through English ("Mama mama mama").
            let readable = await readableAudioURL(for: url)
            var scored: [(Locale, Double)] = []
            for l in candidateLocales() {
                guard let r = SFSpeechRecognizer(locale: l), r.isAvailable, r.supportsOnDeviceRecognition else {
                    let name = Locale.current.localizedString(forLanguageCode: l.language.languageCode?.identifier ?? "") ?? l.identifier
                    if !l.identifier.hasPrefix("en") { cantDo.append(name) }
                    continue
                }
                scored.append((l, await probe(r, url: readable).sure))
            }
            if readable != url { try? FileManager.default.removeItem(at: readable) }
            scored.sort { $0.1 > $1.1 }
            if let b = scored.first {
                locale = b.0
                // A second language that came close is listened with too, stretch by stretch — for talk that mixes
                // English with Hindi or Gujarati, each stretch keeps whichever the phone is surer of.
                if scored.count > 1, scored[1].1 > b.1 - 0.2, let r = SFSpeechRecognizer(locale: scored[1].0) { also = r }
            }
        }
        // The phone's best transcriber first (BestSpeech): the whole file in one pass, nothing dropped after a pause.
        // When two languages came close (talk that mixes English with Hindi, say), both are heard in full and the one
        // the phone is surer of is kept — never a few stray words from the older recogniser.
        do {
            let readable = await readableAudioURL(for: url)
            let tries = [locale] + (also.map { [$0.locale] } ?? [])
            await MainActor.run { RunProgress.shared.begin() }
            var best: BestSpeech.Heard?
            for (i, l) in tries.enumerated() {
                let share = 1 / Double(tries.count), base = Double(i) * share
                if let h = await BestSpeech.transcribe(readable, locale: l, progress: { p in Task { @MainActor in RunProgress.shared.set(base + p * share) } }),
                   best == nil || h.sure * Double(min(h.words.count, 40)) > best!.sure * Double(min(best!.words.count, 40)) {
                    best = h
                }
            }
            await MainActor.run { RunProgress.shared.end() }
            if readable != url { try? FileManager.default.removeItem(at: readable) }
            if let best { return .success(Heard(text: best.text, words: best.words, cantDo: cantDo)) }
        }
        // The chosen language first; fall back to the device's, then any available recognizer, so a tool
        // set to transcribe Hindi uses a Hindi recogniser instead of forcing the words through English.
        guard let recognizer = (SFSpeechRecognizer(locale: locale).flatMap { $0.supportsOnDeviceRecognition ? $0 : nil })
                ?? SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else { return .failure(.unavailable) }

        // On-device recognition only keeps a short span of a single long request — a 20-minute memo
        // comes back as a few words. So we read the file ourselves and transcribe it in ~40-second
        // windows (well inside what on-device handles), then stitch the pieces. That captures the
        // WHOLE recording and gives a true position for the progress bar.
        // An external recorder's MP3 (and other compressed formats) is transcoded to .m4a first, because
        // AVAudioFile reads those unreliably — the reason an 8-minute MP3 came back empty. iPhone voice
        // memos are already .m4a and pass straight through.
        let readURL = await readableAudioURL(for: url)
        defer { if readURL != url { try? FileManager.default.removeItem(at: readURL) } }
        guard let file = try? AVAudioFile(forReading: readURL) else { return .failure(.nothing) }
        let fmt = file.processingFormat
        let total = file.length
        guard total > 0, fmt.sampleRate > 0 else { return .failure(.nothing) }
        // Short stretches: the older recogniser keeps only what it heard after the last pause in a request, so a long
        // stretch lost most of a chatty video (22 Nov: 6 words from a minute of talk).
        let windowFrames = AVAudioFrameCount(fmt.sampleRate * 12)

        await MainActor.run { RunProgress.shared.begin() }
        defer { Task { @MainActor in RunProgress.shared.end() } }

        var parts: [String] = []
        var allWords: [(text: String, start: Double, end: Double)] = []   // timed words, for captions
        let recogError = Flag()
        let listeners = [recognizer] + (also.map { [$0] } ?? [])
        while file.framePosition < total {
            if Task.isCancelled { break }
            // The same stretch goes to each language being listened in; the surer result is kept.
            typealias Said = (text: String, sure: Double, words: [(text: String, start: Double, end: Double)])
            let offset = Double(file.framePosition) / fmt.sampleRate   // where this stretch starts in the recording
            var reqs: [SFSpeechAudioBufferRecognitionRequest] = [], waits: [Once<Said>] = [], boxes: [Box] = []
            for r in listeners {
                let req = SFSpeechAudioBufferRecognitionRequest()
                req.requiresOnDeviceRecognition = true
                req.shouldReportPartialResults = false
                req.addsPunctuation = true
                let once = Once<Said>(), box = Box()
                box.task = r.recognitionTask(with: req) { result, error in
                    if let result, result.isFinal {
                        let segs = result.bestTranscription.segments
                        let sure = segs.isEmpty ? 0 : segs.map { Double($0.confidence) }.reduce(0, +) / Double(segs.count)
                        // Each word's time in the whole recording — what captions are timed by.
                        let words = segs.map { (text: $0.substring, start: offset + $0.timestamp, end: offset + $0.timestamp + max(0.2, $0.duration)) }
                        once.finish((result.bestTranscription.formattedString, sure, words))
                    } else if error != nil { recogError.set(); once.finish(("", 0, [])) }
                }
                reqs.append(req); waits.append(once); boxes.append(box)
            }
            var read: AVAudioFrameCount = 0
            while read < windowFrames && file.framePosition < total {
                let cap = min(AVAudioFrameCount(16000), windowFrames - read)
                guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: cap) else { break }
                do { try file.read(into: buf, frameCount: cap) } catch { break }
                if buf.frameLength == 0 { break }
                for req in reqs { req.append(buf) }
                read += buf.frameLength
            }
            for req in reqs { req.endAudio() }
            // A recogniser that never answers for a stretch just gives that stretch up; the job carries on.
            let wait = waitFor(seconds: Double(read) / fmt.sampleRate)
            for (box, once) in zip(boxes, waits) { DispatchQueue.global().asyncAfter(deadline: .now() + wait) { box.task?.cancel(); once.finish(("", 0, [])) } }
            var heard: [Said] = []
            for once in waits { heard.append(await withCheckedContinuation { once.wait($0) }) }
            if let best = heard.filter({ !$0.text.isEmpty }).max(by: { $0.sure < $1.sure }) {
                parts.append(best.text); allWords += best.words
            }
            await MainActor.run { RunProgress.shared.set(fraction(file.framePosition, of: total)) }
            if read == 0 { break }   // nothing read — avoid an endless loop on a malformed file
        }
        let joined = stitch(parts)
        // Empty because the recogniser erred (model/Dictation not ready) is a different problem from a
        // recording that genuinely has no speech — report the right one so the message is honest.
        guard !joined.isEmpty else { return .failure(recogError.value ? .recognizerFailed : .nothing) }
        return .success(Heard(text: joined, words: allWords, cantDo: cantDo))
    }
}

/// Draws the caption that is due at a moment of the video onto its frame. Each caption is drawn once and kept.
final class CaptionArt: @unchecked Sendable {
    private let lines: [(text: String, start: Double, end: Double)]
    private var made: [Int: CIImage] = [:]
    private let lock = NSLock()

    init(lines: [(text: String, start: Double, end: Double)]) { self.lines = lines }

    func draw(over frame: CIImage, at time: Double) -> CIImage {
        guard let i = lines.firstIndex(where: { time >= $0.start && time < $0.end }) else { return frame }
        let size = frame.extent.size
        lock.lock()
        var art = made[i]
        if art == nil { art = CaptionArt.picture(lines[i].text, in: size); made[i] = art }
        lock.unlock()
        guard let art else { return frame }
        // Centred, a little above the bottom edge (a frame's origin is its bottom-left corner).
        let x = frame.extent.minX + (size.width - art.extent.width) / 2, y = frame.extent.minY + size.height * 0.08
        return art.transformed(by: CGAffineTransform(translationX: x.rounded(), y: y.rounded())).composited(over: frame)
    }

    /// White words on a soft dark plate, sized to the frame so they read on a phone.
    static func picture(_ text: String, in frame: CGSize) -> CIImage? {
        let font = UIFont.boldSystemFont(ofSize: max(18, min(frame.width, frame.height) * 0.05))
        let style = NSMutableParagraphStyle(); style.alignment = .center
        let words = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: UIColor.white, .paragraphStyle: style])
        let pad = font.pointSize * 0.5
        let fit = words.boundingRect(with: CGSize(width: frame.width * 0.86 - pad * 2, height: frame.height), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let size = CGSize(width: ceil(fit.width + pad * 2), height: ceil(fit.height + pad * 2))
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            UIColor.black.withAlphaComponent(0.62).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: pad * 0.7).fill()
            words.draw(with: CGRect(x: pad, y: pad, width: size.width - pad * 2, height: size.height - pad * 2), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        }
        return img.cgImage.map { CIImage(cgImage: $0) }
    }
}

/// Runs the phone's translator from a step. The translator only hands out a session to something on screen, so a
/// tiny invisible view is placed over the app for the moment the translation takes. If a language still has to be
/// downloaded, the phone asks the person itself.
@MainActor enum TranslateBridge {
    static func run(_ text: String, from: String?, to: String) async -> String? {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              var top = scene.keyWindow?.rootViewController else { return nil }
        while let next = top.presentedViewController { top = next }
        let result = Once<String?>()
        let config = TranslationSession.Configuration(source: from.map { Locale.Language(identifier: $0) }, target: Locale.Language(identifier: to))
        let host = UIHostingController(rootView: TranslateProbe(text: text, config: config, result: result))
        host.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        host.view.alpha = 0.01
        host.view.isUserInteractionEnabled = false
        top.addChild(host); top.view.addSubview(host.view); host.didMove(toParent: top)
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { result.finish(nil) }
        let out = await withCheckedContinuation { result.wait($0) }
        host.willMove(toParent: nil); host.view.removeFromSuperview(); host.removeFromParent()
        return out
    }
}

private struct TranslateProbe: View {
    let text: String
    let config: TranslationSession.Configuration
    let result: Once<String?>

    var body: some View {
        Color.clear.translationTask(config) { session in
            let out = try? await session.translate(text)
            result.finish(out?.targetText)
        }
    }
}
