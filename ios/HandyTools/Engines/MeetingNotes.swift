import Foundation
import AVFoundation
import Speech
import NaturalLanguage

/// Meeting Notes — turns a recorded meeting (an audio file, or a video's audio) into something useful on the
/// phone only: a clean transcript, the conversation split into turns at the natural pauses, a short summary,
/// a clear to-do list, and a ready-to-send follow-up email addressed to the people who were named.
///
/// Everything here runs on-device. The transcription mirrors `Transcriber.listen`'s proven windowed path (so a
/// long meeting is covered whole, not just its first minute) but keeps each word's timing, which is what the
/// turn-splitting needs. The derived outputs — turns, names, email — live in small pure functions so the unit
/// tests can prove them on fixtures, with no microphone, model or network.
///
/// Honesty: on-device transcription can hear *when* the talking pauses but cannot tell *whose* voice it is, so
/// turns are numbered and time-stamped rather than labelled with invented speaker names.
enum MeetingNotes {

    /// One timed word from the recogniser — the atom the turn-splitter groups.
    struct Timed { let text: String; let start: Double; let end: Double }

    /// A stretch of speech between two pauses. `index` is 1-based for display; `start` is its offset in seconds.
    struct Turn: Identifiable {
        let id = UUID()
        let index: Int
        let start: Double
        let text: String
    }

    // ── Transcription (on-device, windowed, timed) ───────────────────────────

    /// Transcribes the whole recording on-device, returning the stitched transcript and every word with its
    /// approximate start/end time. Progress is reported 0…1 as the file is consumed. Reuses `Transcriber`'s
    /// readable-format handling and windowing constants so external MP3s and long meetings behave the same as
    /// everywhere else in the app.
    static func transcribe(_ url: URL,
                           locale: Locale = .current,
                           progress: @escaping (Double) -> Void) async -> Result<(text: String, words: [Timed]), Transcriber.Problem> {
        let asked = Once<SFSpeechRecognizerAuthorizationStatus>()
        Permission.speech { asked.finish($0) }
        let status = await withCheckedContinuation { asked.wait($0) }
        guard status == .authorized else { return .failure(.denied) }
        guard let recognizer = (SFSpeechRecognizer(locale: locale).flatMap { $0.supportsOnDeviceRecognition ? $0 : nil })
                ?? SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else { return .failure(.unavailable) }

        let readURL = await Transcriber.readableAudioURL(for: url)
        defer { if readURL != url { try? FileManager.default.removeItem(at: readURL) } }
        guard let file = try? AVAudioFile(forReading: readURL) else { return .failure(.nothing) }
        let fmt = file.processingFormat
        let total = file.length
        guard total > 0, fmt.sampleRate > 0 else { return .failure(.nothing) }
        let windowFrames = AVAudioFrameCount(fmt.sampleRate * Transcriber.windowSeconds)

        var parts: [String] = []
        var timed: [Timed] = []
        let recogError = Flag()
        while file.framePosition < total {
            // The window's start time in the whole recording — each window's recogniser timestamps are relative
            // to the window, so they're offset by this to land on the meeting's real timeline.
            let windowStart = Double(file.framePosition) / fmt.sampleRate
            let req = SFSpeechAudioBufferRecognitionRequest()
            req.requiresOnDeviceRecognition = true
            req.shouldReportPartialResults = false
            req.addsPunctuation = true
            let once = Once<SFTranscription?>()
            let box = Transcriber.Box()
            box.task = recognizer.recognitionTask(with: req) { result, error in
                if let result, result.isFinal { once.finish(result.bestTranscription) }
                else if error != nil { recogError.set(); once.finish(nil) }
            }
            var read: AVAudioFrameCount = 0
            while read < windowFrames && file.framePosition < total {
                let cap = min(AVAudioFrameCount(16000), windowFrames - read)
                guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: cap) else { break }
                do { try file.read(into: buf, frameCount: cap) } catch { break }
                if buf.frameLength == 0 { break }
                req.append(buf)
                read += buf.frameLength
            }
            req.endAudio()
            // A 40s window recognises well under a minute; cap so one stuck window can't stall the job.
            DispatchQueue.global().asyncAfter(deadline: .now() + 60) { box.task?.cancel(); once.finish(nil) }
            let transcription = await withCheckedContinuation { once.wait($0) }
            if let transcription {
                let line = transcription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !line.isEmpty { parts.append(line) }
                for seg in transcription.segments {
                    let w = seg.substring.trimmingCharacters(in: .whitespacesAndNewlines)
                    if w.isEmpty { continue }
                    timed.append(Timed(text: w, start: windowStart + seg.timestamp, end: windowStart + seg.timestamp + seg.duration))
                }
            }
            progress(Transcriber.fraction(file.framePosition, of: total))
            if read == 0 { break }   // nothing read — avoid an endless loop on a malformed file
        }
        let joined = Transcriber.stitch(parts)
        guard !joined.isEmpty else { return .failure(recogError.value ? .recognizerFailed : .nothing) }
        return .success((joined, timed))
    }

    // ── Pure, unit-tested derivations ────────────────────────────────────────

    /// Splits the timed words into turns, starting a new turn whenever the talking pauses for longer than `gap`
    /// seconds. Honest about its limits: it finds *when* the conversation breaks, not *who* is speaking.
    static func turns(from words: [Timed], gap: Double = 1.2) -> [Turn] {
        guard !words.isEmpty else { return [] }
        var result: [Turn] = []
        var current: [String] = []
        var currentStart = words[0].start
        var prevEnd = words[0].start
        for (i, w) in words.enumerated() {
            if i > 0, w.start - prevEnd > gap {
                result.append(Turn(index: result.count + 1, start: currentStart, text: current.joined(separator: " ")))
                current = []
                currentStart = w.start
            }
            current.append(w.text)
            prevEnd = max(prevEnd, w.end)
        }
        if !current.isEmpty {
            result.append(Turn(index: result.count + 1, start: currentStart, text: current.joined(separator: " ")))
        }
        return result
    }

    /// The people named in the meeting, in first-seen order, de-duplicated case-insensitively and capped. Uses
    /// the on-device name tagger — it never invents a name, so the worst case is simply an empty list (then the
    /// draft email greets everyone).
    static func people(in text: String, limit: Int = 8) -> [String] {
        guard !text.isEmpty else { return [] }
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var found: [String] = []
        var seen = Set<String>()
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if tag == .personalName {
                let name = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                let key = name.lowercased()
                if name.count >= 2, !seen.contains(key) { seen.insert(key); found.append(name) }
            }
            return found.count < limit
        }
        return found
    }

    /// A ready-to-send follow-up email drafted from the meeting: greets the named people (or everyone), recaps
    /// the summary, and lists the next steps. Pure string work, so a test pins exactly what lands in the draft.
    static func followUpEmail(people: [String], summary: [String], todos: [String]) -> String {
        let greeting: String
        if people.isEmpty { greeting = "Hi all," }
        else { greeting = "Hi " + people.prefix(4).joined(separator: ", ") + "," }

        var body = greeting + "\n\nThanks for your time today — here's a quick recap of what we covered:\n"
        if summary.isEmpty {
            body += "\n(Full notes are below.)\n"
        } else {
            for s in summary { body += "\n• " + s }
            body += "\n"
        }
        if !todos.isEmpty {
            body += "\nNext steps:\n"
            for t in todos { body += "\n☐ " + t }
            body += "\n"
        }
        body += "\nLet me know if I missed anything.\n\nBest,\n"
        return body
    }

    /// `m:ss` timestamp for a turn's start, for the turn header.
    static func clock(_ seconds: Double) -> String {
        let t = Int(max(0, seconds).rounded())
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}
