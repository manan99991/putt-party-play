import Foundation

/// "Tell me when…" for a number: above a value, below it, or whenever it changes. Used by tools you build
/// (the number in a tool's result) and by Price Watch (a number on a web page). Pure and unit-tested; it lives
/// on its own so the share-sheet extension, which also loads saved tools, can read it.
struct NumberWatch: Codable, Equatable {
    enum Condition: String, Codable, CaseIterable, Identifiable {
        case above, below, changes
        var id: String { rawValue }
        var label: String {
            switch self {
            case .above: "goes above"
            case .below: "drops below"
            case .changes: "changes at all"
            }
        }
    }
    var condition: Condition = .below
    var value: Double = 0
    /// Words printed next to the number ("Total", "Price", "Balance") — picks the right one when there are several.
    var near: String = ""

    func sentence(unit: String = "") -> String {
        condition == .changes ? "when the number changes" : "when it \(condition.label) \(unit)\(NumberReader.plain(value))"
    }
}

/// What a watch remembers between checks, so it tells you once per crossing — not every time it looks.
struct WatchMemory: Codable, Equatable {
    var last: Double?
    var armed = true
    var fired: Date?
}

enum NumberReader {
    /// "1,299.99" / "1.299,99" / "$45" / "€ 12,50" / "-3.2" → a number. Nil when there's no number at all.
    static func number(_ raw: String) -> Double? {
        var s = raw.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }
        guard s.contains(where: \.isNumber) else { return nil }
        let lastDot = s.lastIndex(of: "."), lastComma = s.lastIndex(of: ",")
        if let d = lastDot, let c = lastComma {
            // Whichever comes last is the decimal mark.
            if c > d { s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".") }
            else { s = s.replacingOccurrences(of: ",", with: "") }
        } else if let c = lastComma {
            // "12,50" is a decimal; "1,299" is thousands.
            let after = s.distance(from: c, to: s.endIndex) - 1
            s = after == 2 ? s.replacingOccurrences(of: ",", with: ".") : s.replacingOccurrences(of: ",", with: "")
        } else if let d = lastDot, s.filter({ $0 == "." }).count > 1 || s.distance(from: d, to: s.endIndex) - 1 == 3 && s.count > 5 {
            s = s.replacingOccurrences(of: ".", with: "")        // "1.299.000" thousands
        }
        return Double(s)
    }

    private static let pattern = try! NSRegularExpression(
        pattern: #"(?:[$€£₹¥]\s?)?-?\d{1,3}(?:[,.]\d{3})*(?:[.,]\d{1,2})?(?:\s?[$€£₹¥])?|(?:[$€£₹¥]\s?)?-?\d+(?:[.,]\d+)?"#)

    struct Found: Equatable { let value: Double; let money: Bool; let offset: Int }

    static func all(in text: String) -> [Found] {
        let ns = text as NSString
        return pattern.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let s = ns.substring(with: m.range).trimmingCharacters(in: .whitespaces)
            guard let v = number(s) else { return nil }
            return Found(value: v, money: s.contains { "$€£₹¥".contains($0) }, offset: m.range.location)
        }
    }

    /// The number a person means: the one right after the words they gave ("Total"); otherwise the first amount
    /// of money; otherwise the first number.
    static func pick(in text: String, near hint: String) -> Double? {
        let found = all(in: text)
        guard !found.isEmpty else { return nil }
        let h = hint.trimmingCharacters(in: .whitespaces)
        if !h.isEmpty, let r = wholeWord(h, in: text) {
            let utf16At = NSRange(r, in: text).upperBound
            if let after = found.first(where: { $0.offset >= utf16At && $0.offset - utf16At < 120 }) { return after.value }
            if let before = found.last(where: { $0.offset < utf16At }) { return before.value }
        }
        return (found.first { $0.money } ?? found[0]).value
    }

    /// The hint as a word on its own ("Total", not the end of "Subtotal"); the first loose match if there's none.
    static func wholeWord(_ h: String, in text: String) -> Range<String.Index>? {
        var from = text.startIndex, loose: Range<String.Index>?
        while let r = text.range(of: h, options: [.caseInsensitive, .diacriticInsensitive], range: from..<text.endIndex) {
            if loose == nil { loose = r }
            let before = r.lowerBound == text.startIndex ? nil : text[text.index(before: r.lowerBound)]
            let after = r.upperBound == text.endIndex ? nil : text[r.upperBound]
            if !(before?.isLetter ?? false), !(after?.isLetter ?? false) { return r }
            from = r.upperBound
        }
        return loose
    }

    static func plain(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v)
    }

    /// Should the watch speak up for this reading? Once per crossing: it re-arms only after the number goes back.
    static func evaluate(_ w: NumberWatch, value: Double, memory m: inout WatchMemory, now: Date = Date()) -> Bool {
        defer { m.last = value }
        switch w.condition {
        case .changes:
            guard let last = m.last else { return false }          // the first look only learns the number
            if abs(last - value) > 0.0001 { m.fired = now; return true }
            return false
        case .above, .below:
            let hit = w.condition == .above ? value > w.value : value < w.value
            if !hit { m.armed = true; return false }
            guard m.armed else { return false }
            m.armed = false; m.fired = now
            return true
        }
    }

    static func message(_ w: NumberWatch, value: Double, previous: Double?, what: String) -> String {
        let v = plain(value)
        switch w.condition {
        case .above: return "\(what) is \(v) — above your \(plain(w.value))."
        case .below: return "\(what) is \(v) — below your \(plain(w.value))."
        case .changes: return previous.map { "\(what) changed from \(plain($0)) to \(v)." } ?? "\(what) is \(v)."
        }
    }
}
