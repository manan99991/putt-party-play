import Foundation

/// On a box, a bottle or a packet, the lines that matter most are read out first, word for word as printed:
/// directions and how much, the warnings, the expiry date, and what it contains (allergens). Nothing is added or
/// worked out — it's the label's own words, in a sensible order.
enum LabelFirst {
    struct Part: Equatable { let title: String; let lines: [String] }

    static let groups: [(title: String, pattern: String)] = [
        ("Directions", #"\b(directions?|how to (use|take)|dosage|dose|take \d|adults?\b.*\d|children\b.*\d|apply|use \d|tablets?\b.*(every|daily|times))"#),
        ("Warnings", #"\b(warning|caution|do not|don't|keep out of reach|ask a (doctor|pharmacist)|stop use|not for|avoid|seek medical)"#),
        ("Expiry", #"\b(exp\.?|expiry|expires?|use by|best before|bb|bbe|discard after)\b"#),
        ("Contains", #"\b(contains?|allergens?|may contain|ingredients?|traces of|made in a factory)\b"#),
    ]

    /// True when the text reads like a label rather than a letter or an article.
    static func isLabel(_ text: String) -> Bool {
        let low = text.lowercased()
        let hits = [#"\b\d+\s?(mg|ml|mcg|g|iu|%)\b"#, #"\b(tablets?|capsules?|caplets?|sachets?|drops)\b"#, #"\b(ingredients|allergens|contains)\b"#,
                    #"\b(exp\.?|expiry|use by|best before)\b"#, #"\b(directions|dosage|warnings?)\b"#]
            .filter { low.range(of: $0, options: .regularExpression) != nil }.count
        return hits >= 2
    }

    /// The parts in order, each with the printed lines that belong to it (a heading line takes the next line too
    /// when it's only a heading, e.g. "Directions:" then the instructions underneath).
    static func parts(_ text: String) -> [Part] {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var used = Set<Int>()
        var out: [Part] = []
        for g in groups {
            var got: [String] = []
            for (i, l) in lines.enumerated() where !used.contains(i) && l.lowercased().range(of: g.pattern, options: .regularExpression) != nil {
                used.insert(i); got.append(l)
                let bare = l.replacingOccurrences(of: #"[:\-\s]+$"#, with: "", options: .regularExpression).split(separator: " ").count <= 2
                if bare, i + 1 < lines.count, !used.contains(i + 1) { used.insert(i + 1); got.append(lines[i + 1]) }
            }
            if !got.isEmpty { out.append(Part(title: g.title, lines: Array(got.prefix(4)))) }
        }
        return out
    }

    static func spoken(_ parts: [Part]) -> String {
        parts.map { "\($0.title). " + $0.lines.joined(separator: ". ") }.joined(separator: ". ")
    }
}
