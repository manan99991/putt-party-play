import Foundation
import UIKit
import NaturalLanguage

/// Text utilities that work without a language model — spelling fixes, extractive summaries,
/// bullet-ing, stats — used as the always-available layer under Text Studio, Voice → Notes and
/// the Explainer. The on-device model improves on these when present.
enum TextTools {
    /// Fix misspellings using the system spell checker (keeps the author's words otherwise).
    @MainActor static func fixSpelling(_ text: String, language: String = "en") -> (text: String, fixes: Int) {
        let checker = UITextChecker()
        var out = text as NSString
        var fixes = 0
        var offset = 0
        while offset < out.length {
            let r = checker.rangeOfMisspelledWord(in: out as String, range: NSRange(location: offset, length: out.length - offset), startingAt: offset, wrap: false, language: language)
            if r.location == NSNotFound { break }
            let word = out.substring(with: r)
            if let g = checker.guesses(forWordRange: r, in: out as String, language: language)?.first, g.lowercased() != word.lowercased(), word.rangeOfCharacter(from: .decimalDigits) == nil, word.first?.isUppercase != true || g.first?.isUppercase == true {
                out = out.replacingCharacters(in: r, with: g) as NSString
                fixes += 1
                offset = r.location + (g as NSString).length
            } else { offset = r.location + r.length }
        }
        var s = out as String
        // basic mechanics: double spaces, space before punctuation, capital after sentence end, "i" → "I"
        s = s.replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #" +([,.!?;:])"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\bi\b"#, with: "I", options: .regularExpression)
        s = capitalizeSentences(s)
        return (s, fixes)
    }

    static func capitalizeSentences(_ s: String) -> String {
        var out = "", capNext = true
        for ch in s {
            if capNext, ch.isLetter { out.append(contentsOf: String(ch).uppercased()); capNext = false }
            else { out.append(ch) }
            if ".!?".contains(ch) { capNext = true } else if ch.isLetter || ch.isNumber { capNext = false }
        }
        return out
    }

    static func sentences(_ text: String) -> [String] {
        var out: [String] = []
        let tok = NLTokenizer(unit: .sentence); tok.string = text
        tok.enumerateTokens(in: text.startIndex..<text.endIndex) { r, _ in
            let s = text[r].trimmingCharacters(in: .whitespacesAndNewlines); if !s.isEmpty { out.append(s) }; return true }
        return out
    }

    /// Extractive summary: score sentences by content-word frequency, keep the top `count` in original order.
    static func summarize(_ text: String, sentences count: Int = 3) -> [String] {
        let sents = sentences(text)
        guard sents.count > count else { return sents }
        var freq: [String: Int] = [:]
        for w in words(text) { freq[w, default: 0] += 1 }
        let scored = sents.enumerated().map { i, s -> (Int, Double) in
            let ws = words(s); guard !ws.isEmpty else { return (i, 0) }
            let score = ws.reduce(0.0) { $0 + Double(freq[$1] ?? 0) } / Double(ws.count) * (i == 0 ? 1.3 : 1.0)   // lead sentence bonus
            return (i, score)
        }
        let keep = Set(scored.sorted { $0.1 > $1.1 }.prefix(count).map(\.0))
        return sents.enumerated().filter { keep.contains($0.offset) }.map(\.element)
    }

    /// Lines that read like tasks ("need to", "remember to", "by Friday", imperative verbs).
    static func actionItems(_ text: String) -> [String] {
        let pattern = #"\b(need(s)? to|have to|must|should|remember to|don'?t forget|todo|to-do|action item|follow up|follow-up|send|call|email|schedule|book|buy|order|fix|finish|review|prepare|submit|pay|by (monday|tuesday|wednesday|thursday|friday|saturday|sunday|tomorrow|next week|end of day|eod))\b"#
        return sentences(text).filter { $0.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " .")) }
    }

    static func bullets(_ text: String) -> String { sentences(text).map { "• " + $0 }.joined(separator: "\n") }

    static func words(_ text: String) -> [String] {
        let tok = NLTokenizer(unit: .word); tok.string = text
        var out: [String] = []
        tok.enumerateTokens(in: text.startIndex..<text.endIndex) { r, _ in
            let w = text[r].lowercased(); if w.count > 3, !stop.contains(w) { out.append(w) }; return true }
        return out
    }
    private static let stop: Set<String> = ["this", "that", "with", "from", "have", "will", "your", "about", "there", "their", "they", "them", "then", "than", "what", "when", "which", "would", "could", "should", "been", "were", "into", "also", "just", "like", "more", "some", "very", "over", "only", "such", "here", "these", "those", "because", "while", "where", "after", "before"]

    struct Stats { let words: Int; let characters: Int; let sentences: Int; let readingSeconds: Int; let grade: Double }
    static func stats(_ text: String) -> Stats {
        let w = text.split { $0.isWhitespace || $0.isNewline }.count
        let s = max(1, sentences(text).count)
        let syll = text.split { !$0.isLetter }.reduce(0) { $0 + syllables(String($1)) }
        let grade = w > 0 ? 0.39 * Double(w) / Double(s) + 11.8 * Double(syll) / Double(w) - 15.59 : 0   // Flesch–Kincaid
        return Stats(words: w, characters: text.count, sentences: s, readingSeconds: Int(Double(w) / 230 * 60), grade: max(0, grade))
    }
    static func syllables(_ word: String) -> Int {
        let w = word.lowercased(); guard w.count > 2 else { return 1 }
        var count = 0, prevVowel = false
        for ch in w { let v = "aeiouy".contains(ch); if v && !prevVowel { count += 1 }; prevVowel = v }
        if w.hasSuffix("e"), !w.hasSuffix("le"), count > 1 { count -= 1 }
        return max(1, count)
    }
}
