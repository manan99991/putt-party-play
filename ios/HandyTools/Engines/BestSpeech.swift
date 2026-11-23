import AVFoundation
import Speech

/// The best speech-to-text this phone has: Apple's SpeechAnalyzer + SpeechTranscriber (iOS 26), the long-form,
/// on-device model behind Notes and Voice Memos transcripts. It reads the whole file in one go — no 40-second
/// windows, no dropped stretches after a pause — and gives every word its time.
///
/// Why: the older recogniser (SFSpeechRecognizer) only keeps what it heard after the last pause in each request, so a
/// diary note came back as one sentence of a longer message (Manan, 22 Nov: "missing a lot of text… not complete at
/// all"). Every transcript in Tenzy — Mood Diary, Meeting Notes, Speech → Notes, captions, flows — tries this first and
/// falls back to the older recogniser only where this one can't run (an unsupported language, a model that won't
/// download).
enum BestSpeech {
    struct Heard { let text: String; let words: [(text: String, start: Double, end: Double)] }

    /// nil when this phone/language can't use the new transcriber — the caller then uses the older path.
    static func transcribe(_ url: URL, locale: Locale = .current, progress: @escaping (Double) -> Void = { _ in }) async -> Heard? {
        guard SpeechTranscriber.isAvailable,
              let lang = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else { return nil }
        let transcriber = SpeechTranscriber(locale: lang, transcriptionOptions: [], reportingOptions: [],
                                            attributeOptions: [.audioTimeRange])
        // The language model is downloaded once (in the background, by the system) the first time it's needed.
        do {
            if let req = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await req.downloadAndInstall()
            }
        } catch { return nil }
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let total = Double(file.length) / max(1, file.processingFormat.sampleRate)
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        let collect = Task { () -> Heard in
            var text = ""
            var words: [(text: String, start: Double, end: Double)] = []
            do {
                for try await r in transcriber.results where r.isFinal {
                    let piece = String(r.text.characters)
                    if !piece.trimmingCharacters(in: .whitespaces).isEmpty {
                        if !text.isEmpty, !text.hasSuffix(" "), !piece.hasPrefix(" ") { text += " " }
                        text += piece
                    }
                    for run in r.text.runs {
                        let w = String(r.text[run.range].characters).trimmingCharacters(in: .whitespaces)
                        guard !w.isEmpty, let tr = run.audioTimeRange else { continue }
                        words.append((w, tr.start.seconds, tr.end.seconds))
                    }
                    if total > 0 { progress(min(0.99, r.range.end.seconds / total)) }
                }
            } catch {}
            return Heard(text: text.trimmingCharacters(in: .whitespacesAndNewlines), words: words)
        }
        do {
            try await analyzer.start(inputAudioFile: file, finishAfterFile: true)
        } catch {
            collect.cancel(); return nil
        }
        let heard = await collect.value
        progress(1)
        return heard.text.isEmpty ? nil : heard
    }
}
