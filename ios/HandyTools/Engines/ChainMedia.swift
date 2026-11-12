import UIKit
import SwiftUI
import AVFoundation
import Speech
import CoreImage
@preconcurrency import Translation

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
            switch await Transcriber.listen(to: url) {
            case .failure(let p): return .failure(.invalid(p.words(for: b)))
            case .success(let heard):
                let text = heard.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? .failure(.invalid("\(b.title) didn't hear any words in that recording.")) : .success(.text(text))
            }

        case (.readAloud, .text(let t)):
            let words = String(t.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20_000))
            guard !words.isEmpty else { return .failure(.nothingFound(b)) }
            guard let url = await speak(words), let d = try? Data(contentsOf: url), !d.isEmpty else {
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
            let keep = ChainText.trimWindow(side: step.settings["side"], secs: step.settings["secs"], duration: length)
            guard keep.end > keep.start, let out = await VideoEngine.trim(url, start: keep.start, end: keep.end) else { return .failure(.failed(b)) }
            return .success(.video(out))

        case (.videoGif, .video(let url)):
            // The first six seconds. Put "Keep the start or the end" before this step to pick another part.
            let length = await VideoEngine.duration(url)
            guard let gif = await tenzyGIFFromVideo(url: url, start: 0, duration: min(max(length, 0.2), 6), fps: 10, speed: 1, maxDim: 480),
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
            switch await Transcriber.listen(to: sound) {
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

    @MainActor private static func speak(_ text: String) async -> URL? {
        let reader = Reader()
        reader.load(text)
        return await reader.exportAudio()
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
        await session.export()
        return session.status == .completed ? out : nil
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
    struct Heard { let text: String; let words: [(text: String, start: Double, end: Double)] }
    enum Problem: Error {
        case denied, unavailable, nothing
        func words(for b: Block) -> String {
            switch self {
            case .denied: return "\(b.title) needs permission to recognise speech. Allow Speech Recognition for Tenzy in Settings, then run this again."
            case .unavailable: return "\(b.title) isn't available on this phone right now. Speech can't be turned into text on the phone in its language."
            case .nothing: return "\(b.title) couldn't make out any words. Try a clearer recording."
            }
        }
    }

    static func listen(to url: URL) async -> Result<Heard, Problem> {
        let asked = Once<SFSpeechRecognizerAuthorizationStatus>()
        Permission.speech { asked.finish($0) }
        let status = await withCheckedContinuation { asked.wait($0) }
        guard status == .authorized else { return .failure(.denied) }
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(), recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else { return .failure(.unavailable) }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        let seconds = await VideoEngine.duration(url)
        let result = Once<Heard?>()
        let task = recognizer.recognitionTask(with: request) { found, error in
            if let found, found.isFinal {
                let t = found.bestTranscription
                result.finish(Heard(text: t.formattedString, words: t.segments.map { (text: $0.substring, start: $0.timestamp, end: $0.timestamp + $0.duration) }))
            } else if error != nil {
                result.finish(nil)
            }
        }
        // A recogniser that never answers must not hang the tool: give it three times the recording's length, at least a minute.
        DispatchQueue.global().asyncAfter(deadline: .now() + max(60, seconds * 3)) { task.cancel(); result.finish(nil) }
        guard let heard = await withCheckedContinuation({ result.wait($0) }) else { return .failure(.nothing) }
        return .success(heard)
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
