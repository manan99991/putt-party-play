import Foundation
import AVFoundation
import PDFKit
import UIKit

/// Sentence-by-sentence reader: plays a document aloud with the current sentence exposed for
/// highlighting, skips, speed/voice control, and can render the whole thing to an audio file.
@MainActor final class Reader: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var sentences: [String] = []
    @Published var index = 0
    @Published var playing = false
    @Published var rate: Float = AVSpeechUtteranceDefaultSpeechRate { didSet { if playing { restartCurrent() } } }
    @Published var voiceID: String? = nil { didSet { if playing { restartCurrent() } } }
    @Published var exporting = false

    private let synth = AVSpeechSynthesizer()
    override init() { super.init(); synth.delegate = self }

    var progress: Double { sentences.isEmpty ? 0 : Double(index) / Double(sentences.count) }
    var remainingMinutes: Int {
        let words = sentences.dropFirst(index).reduce(0) { $0 + $1.split(separator: " ").count }
        let wpm = 160.0 * Double(rate / AVSpeechUtteranceDefaultSpeechRate)
        return Int((Double(words) / max(60, wpm)).rounded(.up))
    }

    /// The language used for the WHOLE document's voice — decided once here, never per sentence.
    /// (Guessing per sentence made the voice flip languages on short lines like an address or a
    /// phone number, which a page of listings is full of.)
    private var documentLanguage = Locale.preferredLanguages.first ?? "en-US"

    func load(_ text: String) {
        stop()
        sentences = TextTools.sentences(text).flatMap { Self.split(longSentence: $0) }
        index = 0
        documentLanguage = NLLanguageGuess.documentLanguage(text)
    }

    /// Keep utterances under ~300 chars so the highlight moves and the engine never chokes.
    static func split(longSentence s: String, max: Int = 300) -> [String] {
        guard s.count > max else { return [s] }
        var out: [String] = [], cur = ""
        for part in s.split(separator: ",", omittingEmptySubsequences: false) {
            let p = String(part)
            if cur.count + p.count > max, !cur.isEmpty { out.append(cur.trimmingCharacters(in: .whitespaces)); cur = "" }
            cur += (cur.isEmpty ? "" : ",") + p
        }
        if !cur.isEmpty { out.append(cur.trimmingCharacters(in: .whitespaces)) }
        return out
    }

    func play(from i: Int? = nil) {
        guard !sentences.isEmpty else { return }
        if let i { index = max(0, min(sentences.count - 1, i)) }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        playing = true
        speakCurrent()
    }
    func pause() { synth.stopSpeaking(at: .word); playing = false }
    func stop() { synth.stopSpeaking(at: .immediate); playing = false }
    func next() { guard index + 1 < sentences.count else { return }; index += 1; if playing { restartCurrent() } }
    func previous() { index = max(0, index - 1); if playing { restartCurrent() } }

    private func restartCurrent() { synth.stopSpeaking(at: .immediate); speakCurrent() }
    private func speakCurrent() {
        guard playing, index < sentences.count else { playing = false; return }
        synth.speak(utterance(sentences[index]))
    }
    private func utterance(_ s: String) -> AVSpeechUtterance {
        let u = AVSpeechUtterance(string: s)
        u.rate = rate
        // A hand-picked voice wins; otherwise the best natural voice for the ONE document language.
        if let id = voiceID, let v = AVSpeechSynthesisVoice(identifier: id) { u.voice = v }
        else { u.voice = Reader.bestVoice(forLanguage: documentLanguage) }
        return u
    }

    /// The most natural installed voice for a language: enhanced/premium first (what people mean by
    /// "not robotic"), preferring the device's own region, and only falling back to the system
    /// default voice (Samantha etc.) — never a novelty voice like "Bubbles" — if none are downloaded.
    static func bestVoice(forLanguage lang: String) -> AVSpeechSynthesisVoice? {
        let base = String(lang.prefix(2))
        let region = Locale.current.region?.identifier
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(base) }
        let natural = candidates
            .filter { $0.quality == .enhanced || $0.quality == .premium }
            .sorted { a, b in
                if a.quality.rawValue != b.quality.rawValue { return a.quality.rawValue > b.quality.rawValue }
                let ar = region.map { a.language.hasSuffix($0) } ?? false
                let br = region.map { b.language.hasSuffix($0) } ?? false
                if ar != br { return ar }
                return a.name < b.name
            }
        if let best = natural.first { return best }
        return AVSpeechSynthesisVoice(language: region.map { "\(base)-\($0)" } ?? lang) ?? AVSpeechSynthesisVoice(language: base)
    }

    /// True when at least one natural (enhanced/premium) voice is installed for the device language —
    /// so the UI can nudge the user to download one when everything on the phone is still robotic.
    static var hasNaturalVoice: Bool {
        let base = String((Locale.preferredLanguages.first ?? "en").prefix(2))
        return AVSpeechSynthesisVoice.speechVoices().contains {
            $0.language.hasPrefix(base) && ($0.quality == .enhanced || $0.quality == .premium)
        }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.playing else { return }
            if self.index + 1 < self.sentences.count { self.index += 1; self.speakCurrent() } else { self.playing = false }
        }
    }

    /// Voices for the picker: enhanced/premium first, then by language name.
    static func voices(for language: String?) -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { language == nil || $0.language.hasPrefix(language!) }
            .sorted { a, b in a.quality.rawValue != b.quality.rawValue ? a.quality.rawValue > b.quality.rawValue : a.name < b.name }
    }

    // MARK: export

    /// Render all sentences to an .m4a (runs off the live synthesizer so playback isn't interrupted).
    private final class WriteSink: @unchecked Sendable { var file: AVAudioFile?; var resumed = false; let url: URL; init(url: URL) { self.url = url } }

    func exportAudio() async -> URL? {
        guard !sentences.isEmpty else { return nil }
        exporting = true; defer { exporting = false }
        let sink = WriteSink(url: VideoEngine.tempURL("caf"))
        let writer = AVSpeechSynthesizer()
        for s in sentences {
            let u = utterance(s)
            sink.resumed = false
            let ok: Bool = await withCheckedContinuation { cont in
                writer.write(u) { buffer in
                    guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                    if pcm.frameLength == 0 { if !sink.resumed { sink.resumed = true; cont.resume(returning: true) }; return }
                    if sink.file == nil { sink.file = try? AVAudioFile(forWriting: sink.url, settings: pcm.format.settings, commonFormat: pcm.format.commonFormat, interleaved: pcm.format.isInterleaved) }
                    try? sink.file?.write(from: pcm)
                }
            }
            if !ok { break }
        }
        sink.file = nil
        guard FileManager.default.fileExists(atPath: sink.url.path) else { return nil }
        if let m4a = await VideoEngine.extractAudio(sink.url) { return m4a }
        return sink.url
    }
}

/// Pulls readable text out of what people actually want read: pasted text, a PDF, a photo, a web page.
enum ReadSource {
    static func fromPDF(_ url: URL) -> String {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let doc = PDFDocument(url: url) else { return "" }
        var parts: [String] = []
        for i in 0..<doc.pageCount { if let s = doc.page(at: i)?.string, s.trimmingCharacters(in: .whitespacesAndNewlines).count > 20 { parts.append(s) } }
        if parts.isEmpty {   // scanned PDF: OCR the pages
            for img in DocEngine.importPDF(url, maxWidth: 1400).prefix(30) { parts.append(DocEngine.text(DocEngine.recognize(img))) }
        }
        return cleanup(parts.joined(separator: "\n\n"))
    }

    static func fromWeb(_ url: URL) async -> String {
        var req = URLRequest(url: url); req.setValue("Mozilla/5.0 (iPhone) Tenzy ReadAloud", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: req), let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return "" }
        return extract(html: html)
    }

    /// Readability-lite: drop scripts/styles/nav, keep headings and paragraphs, decode entities.
    static func extract(html: String) -> String {
        var h = html
        for tag in ["script", "style", "nav", "footer", "header", "aside", "noscript", "svg", "form"] {
            h = h.replacingOccurrences(of: "(?is)<\(tag)\\b[^>]*>.*?</\(tag)>", with: " ", options: .regularExpression)
        }
        h = h.replacingOccurrences(of: "(?is)<!--.*?-->", with: " ", options: .regularExpression)
        var blocks: [String] = []
        if let re = try? NSRegularExpression(pattern: "(?is)<(h1|h2|h3|p|li|blockquote)\\b[^>]*>(.*?)</\\1>") {
            for m in re.matches(in: h, range: NSRange(h.startIndex..., in: h)) {
                guard let r = Range(m.range(at: 2), in: h) else { continue }
                let t = strip(String(h[r]))
                if t.count > 25 || (t.count > 8 && String(h[Range(m.range(at: 1), in: h)!]).hasPrefix("h")) { blocks.append(t) }
            }
        }
        if blocks.joined().count < 200 { return cleanup(strip(h)) }
        return cleanup(blocks.joined(separator: "\n\n"))
    }

    static func strip(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "(?i)<br\\s*/?>", with: "\n", options: .regularExpression)
        t = t.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&nbsp;": " ", "&mdash;": "—", "&ndash;": "–", "&hellip;": "…", "&rsquo;": "’", "&lsquo;": "‘", "&rdquo;": "”", "&ldquo;": "“"]
        for (k, v) in entities { t = t.replacingOccurrences(of: k, with: v) }
        t = t.replacingOccurrences(of: "&#(\\d+);", with: "", options: .regularExpression)
        return cleanup(t)
    }

    static func cleanup(_ s: String) -> String {
        s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
         .replacingOccurrences(of: " ?\\n ?", with: "\n", options: .regularExpression)
         .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

import NaturalLanguage
enum NLLanguageGuess {
    static func language(of s: String) -> String? {
        let r = NLLanguageRecognizer(); r.processString(String(s.prefix(400)))
        guard let l = r.dominantLanguage, l != .undetermined else { return nil }
        return l.rawValue
    }

    /// One stable language for a whole document. Samples a big chunk (not one line), and when the
    /// guess is weak — short, numeric or address-like text, which fools the detector — trusts the
    /// device's own language instead of switching to a foreign voice. Keeps the device's region
    /// when the base language matches (en-US rather than a bare "en").
    static func documentLanguage(_ text: String) -> String {
        let device = Locale.preferredLanguages.first ?? "en-US"
        let r = NLLanguageRecognizer(); r.processString(String(text.prefix(2000)))
        guard let l = r.dominantLanguage, l != .undetermined else { return device }
        let confidence = r.languageHypotheses(withMaximum: 1)[l] ?? 0
        if confidence < 0.65 { return device }
        if device.hasPrefix(l.rawValue) { return device }
        return l.rawValue
    }
}
