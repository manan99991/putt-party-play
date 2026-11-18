import Foundation

/// Turn a raw dictation dump into something you'd actually read: filler words ("um", "uh") and stutters
/// ("the the") removed, sentences restored when the recognizer left none, every sentence capitalized and
/// ended, and the whole thing split into short paragraphs that start where the speaker changes topic.
/// Pure text — runs instantly on every phone, offline. It tidies; it never rewrites what was said.
enum TranscriptTidy {
    static let fillers: Set<String> = ["um", "umm", "uh", "uhh", "uhm", "erm", "er", "ah", "hmm", "mm", "mhm"]
    /// Words that legitimately repeat ("had had", "that that", "very very") — never collapsed.
    static let realDoubles: Set<String> = ["had", "that", "is", "do", "very", "so", "no", "bye", "ha", "yeah", "really", "well", "go", "now", "knock", "night"]
    /// Openings that usually start a new topic.
    static let topicStarts = ["anyway", "moving on", "next", "another thing", "the other thing", "okay so", "ok so",
                              "alright so", "all right so", "so anyway", "last thing", "one more thing", "secondly",
                              "finally", "also", "now let's", "let's move", "on another note", "speaking of"]

    /// Remove fillers and stutters; keep everything else exactly as said.
    static func clean(_ raw: String) -> String {
        var out: [String] = []
        for tok in raw.split(whereSeparator: \.isWhitespace).map(String.init) {
            let core = tok.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if fillers.contains(core) {
                // Keep a sentence end the filler carried ("…okay um.") on the previous word.
                if let p = tok.last, ".!?".contains(p), let last = out.last, let lc = last.last, !".!?".contains(lc) {
                    out[out.count - 1] = last.trimmingCharacters(in: CharacterSet(charactersIn: ",;")) + String(p)
                }
                continue
            }
            if let prev = out.last, !realDoubles.contains(core), !core.isEmpty,
               prev.lowercased() == core, tok.lowercased().hasPrefix(core) {
                out[out.count - 1] = tok      // "the the," → "the,"
                continue
            }
            out.append(tok)
        }
        var s = out.joined(separator: " ")
        while s.contains(",,") { s = s.replacingOccurrences(of: ",,", with: ",") }
        s = s.replacingOccurrences(of: " ,", with: ",")
        return s.trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespacesAndNewlines))
    }

    /// Sentences, each capitalized and ended. If the recognizer gave almost no punctuation, breaks are
    /// restored at topic words or every ~18 words.
    static func sentences(_ text: String) -> [String] {
        let words = text.split(whereSeparator: \.isWhitespace).count
        let stops = text.filter { ".!?".contains($0) }.count
        let raw: [String]
        if words > 24 && stops * 30 < words {
            raw = chunk(text)
        } else {
            raw = TextTools.sentences(text)
        }
        return raw.map(finish).filter { !$0.isEmpty }
    }

    /// Short paragraphs: a new one at a topic change, or after `per` sentences.
    static func paragraphs(_ raw: String, per: Int = 4) -> [String] {
        var paras: [[String]] = [], cur: [String] = []
        for s in sentences(clean(raw)) {
            let lower = s.lowercased()
            if !cur.isEmpty, cur.count >= per || topicStarts.contains(where: { lower.hasPrefix($0 + " ") || lower.hasPrefix($0 + ",") }) {
                paras.append(cur); cur = []
            }
            cur.append(s)
        }
        if !cur.isEmpty { paras.append(cur) }
        return paras.map { $0.joined(separator: " ") }
    }

    // MARK: helpers

    /// Words a new spoken sentence usually opens with.
    static let starters: Set<String> = ["i", "we", "you", "they", "so", "but", "then", "because", "also", "let's", "anyway", "okay", "ok"]

    private static func chunk(_ text: String) -> [String] {
        let ws = text.split(whereSeparator: \.isWhitespace).map(String.init)
        var out: [String] = [], cur: [String] = []
        for (i, w) in ws.enumerated() {
            let rest = ws[i...].prefix(3).joined(separator: " ").lowercased()
            let topic = topicStarts.contains { rest.hasPrefix($0 + " ") || rest == $0 }
            let opener = starters.contains(w.lowercased().trimmingCharacters(in: .punctuationCharacters))
            let joined = ["and", "or", "to", "the", "a", "of", "with", "but", "if", "so", "because", "which", "that"].contains(cur.last?.lowercased() ?? "")
            if (!joined && ((cur.count >= 6 && topic) || (cur.count >= 12 && opener))) || cur.count >= 30 {
                out.append(cur.joined(separator: " ")); cur = []
            }
            cur.append(w)
        }
        if !cur.isEmpty { out.append(cur.joined(separator: " ")) }
        return out
    }

    /// Day and month names the recognizer often leaves lower-case ("may" and "march" are left alone —
    /// they're everyday words too).
    static let properNames: [String: String] = Dictionary(uniqueKeysWithValues:
        ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "january", "february",
         "april", "june", "july", "august", "september", "october", "november", "december"].map { ($0, $0.prefix(1).uppercased() + $0.dropFirst()) })

    private static func capitalizeNames(_ s: String) -> String {
        s.split(separator: " ", omittingEmptySubsequences: false).map { w -> String in
            let core = w.lowercased().trimmingCharacters(in: .punctuationCharacters)
            guard let proper = properNames[core], let r = w.range(of: core, options: .caseInsensitive) else { return String(w) }
            return w.replacingCharacters(in: r, with: proper)
        }.joined(separator: " ")
    }

    private static func finish(_ s: String) -> String {
        var t = capitalizeNames(s.trimmingCharacters(in: CharacterSet(charactersIn: ",; ").union(.whitespacesAndNewlines)))
        guard let first = t.first else { return "" }
        t = String(first).uppercased() + t.dropFirst()
        if let last = t.last, !".!?…\"”')".contains(last) { t += "." }
        return t
    }
}
