import Foundation
import UIKit

/// "What is this?" when the answer is writing. An object classifier calls a whiteboard rota "Document" and a
/// receipt "Paper" — true and useless. When a photo is mostly writing, this reads all of it and names the kind
/// of thing the way a person would — a weekly schedule board, a month calendar, a receipt from a shop, a menu,
/// an event poster, a business card, a medicine label, a letter or bill, a list — with what it says in one
/// line, so the result can open the right reader in place (the board's names by day, the receipt's total)
/// instead of a web search for "Document MON THU".
enum Paper {
    enum Kind: String, CaseIterable { case schedule, calendar, receipt, menu, label, card, poster, bill, lists, page }

    struct Read: Equatable {
        var kind: Kind
        var name: String         // "A weekly schedule board"
        var gist: String         // "20 people, Mon – Fri. Most say: Shifter Line."
        var text: String         // everything read, top to bottom
    }

    /// Enough writing to be "a written thing" rather than an object with a label on it.
    static func isMostlyWriting(_ lines: [DocEngine.OCRLine]) -> Bool {
        let words = lines.map(\.text).joined(separator: " ").split(whereSeparator: \.isWhitespace).filter { $0.count >= 2 }
        let area = lines.reduce(CGFloat(0)) { $0 + $1.box.width * $1.box.height }
        return lines.count >= 8 && words.count >= 14 || (lines.count >= 5 && area > 0.06)
    }

    static func classify(_ lines: [DocEngine.OCRLine], now: Date = Date()) -> Read? {
        guard isMostlyWriting(lines) else { return nil }
        let text = lines.map(\.text).joined(separator: "\n")
        let low = text.lowercased()
        func has(_ p: String) -> Bool { low.range(of: p, options: .regularExpression) != nil }

        // A grid with weekday headings: a calendar (day numbers) or a people-by-day schedule (names down the side).
        let board = Understand.parse(lines, now: now)
        if board.kind == .people, !board.people.isEmpty {
            return Read(kind: .schedule, name: "A weekly schedule board", gist: scheduleGist(board, lines: lines), text: text)
        }
        if board.kind == .calendar {
            let n = board.events.count
            return Read(kind: .calendar, name: "A month calendar",
                        gist: n == 0 ? "A calendar page — nothing written on the days." : "\(n) thing\(n == 1 ? "" : "s") written on the days.", text: text)
        }

        // A receipt: a total and several money lines.
        let moneyLines = lines.filter { $0.text.range(of: #"\d[.,]\d{2}\b"#, options: .regularExpression) != nil }.count
        if moneyLines >= 3, has(#"\b(total|subtotal|amount due|balance|cash|change|vat|gst|tax|visa|mastercard)\b"#) {
            let r = DataGrab.receipt(text)
            if let t = r.total {
                let from = r.merchant.isEmpty ? "" : " from \(r.merchant)"
                let when = r.date.map { " on " + $0.formatted(date: .abbreviated, time: .omitted) } ?? ""
                return Read(kind: .receipt, name: "A receipt\(from)", gist: "Total \(r.currency)\(String(format: "%.2f", t))\(when).", text: text)
            }
        }

        // A menu: many dishes with prices, no till words.
        let priced = lines.compactMap { MenuReader.splitPrice($0.text) }.filter { $0.name.filter(\.isLetter).count >= 3 }
        if priced.count >= 5 || (moneyLines >= 6 && !has(#"\b(total|subtotal|change)\b"#)) {
            let n = max(priced.count, moneyLines)
            return Read(kind: .menu, name: "A menu", gist: "\(n) dishes with prices — open it to read it in your language and check allergens.", text: text)
        }

        if LabelFirst.isLabel(text) {
            let medicine = has(#"\b(tablets?|capsules?|mg|dose|dosage|pharmacist|doctor)\b"#)
            return Read(kind: .label, name: medicine ? "A medicine label" : "A product label",
                        gist: medicine ? "The label's own words, grouped: directions, warnings, expiry." : "What it contains and how to use it, as printed.", text: text)
        }

        // A business card: a phone or email and few lines.
        let card = DataGrab.card(text)
        if lines.count <= 14, !card.phones.isEmpty || !card.emails.isEmpty, !card.name.isEmpty || !card.company.isEmpty {
            let who = [card.name, card.company].filter { !$0.isEmpty }.joined(separator: ", ")
            return Read(kind: .card, name: "A business card", gist: who, text: text)
        }

        // An event poster: a date (and usually a time) with a big title, not too much text.
        let ev = DataGrab.event(text, now: now)
        if let s = ev.start, !ev.title.isEmpty, lines.count <= 30 {
            let c = Calendar.current.dateComponents([.hour, .minute], from: s)
            let timed = (c.hour ?? 0) != 0 || (c.minute ?? 0) != 0
            return Read(kind: .poster, name: "An event poster",
                        gist: "\(ev.title) — \(s.formatted(date: .abbreviated, time: timed ? .shortened : .omitted))", text: text)
        }

        if has(#"\b(dear |invoice|statement|account (no|number)|amount due|payment due|due date|pay by|reference|bill)\b"#) {
            let s = ScanSmart.read(text, now: now)
            var g: [String] = []
            if let a = s.amount { g.append("Amount " + String(format: "%.2f", a)) }
            if let d = s.due { g.append("due \(d.formatted(date: .abbreviated, time: .omitted))") }
            return Read(kind: .bill, name: "A letter or bill", gist: g.isEmpty ? (s.from.isEmpty ? "A letter." : "From \(s.from).") : g.joined(separator: ", ") + ".", text: text)
        }

        if board.kind == .lists, board.tasks.count >= 3 {
            let secs = Set(board.tasks.map(\.section).filter { !$0.isEmpty })
            let done = board.tasks.filter(\.done).count
            var g = "\(board.tasks.count) items"
            if secs.count > 1 { g += " under \(secs.count) headings" }
            if done > 0 { g += ", \(done) ticked off" }
            return Read(kind: .lists, name: "A list of things to do", gist: g + ".", text: text)
        }

        let first = lines.max { $0.box.height < $1.box.height }?.text ?? lines[0].text
        return Read(kind: .page, name: "A page of writing", gist: "Starts: “\(first)”. \(lines.count) lines.", text: text)
    }

    /// "20 people, Mon – Fri. Most say: Shifter Line. On vacation: Adam Carraway, Kim Farthington."
    static func scheduleGist(_ b: Understand.Board, lines: [DocEngine.OCRLine]) -> String {
        let people = Array(NSOrderedSet(array: b.people.map(\.person))) as? [String] ?? []
        let order = Understand.weekdays.map { $0.capitalized }
        let days = Set(lines.compactMap { Understand.weekday($0.text) })
        let shown = order.indices.filter { days.contains($0) }
        var g = "\(people.count) \(people.count == 1 ? "person" : "people")"
        if let a = shown.first, let z = shown.last, a != z { g += ", \(order[a]) – \(order[z])" }
        g += "."
        // The most common entry, cleaned of arrows and dashes.
        func norm(_ s: String) -> String { s.trimmingCharacters(in: CharacterSet.alphanumerics.union(.whitespaces).inverted).trimmingCharacters(in: .whitespaces) }
        var counts: [String: (n: Int, shown: String)] = [:]
        for p in b.people { let k = norm(p.what).lowercased(); guard k.count >= 3 else { continue }; counts[k] = ((counts[k]?.n ?? 0) + 1, counts[k]?.shown ?? norm(p.what)) }
        if let top = counts.values.max(by: { $0.n < $1.n }), top.n >= 3 { g += " Most often: \(top.shown)." }
        let away = Array(NSOrderedSet(array: b.people.filter { $0.what.lowercased().range(of: #"vacation|holiday|leave|\boff\b|annual"#, options: .regularExpression) != nil }.map(\.person))) as? [String] ?? []
        if !away.isEmpty { g += " Away: \(away.prefix(4).joined(separator: ", "))\(away.count > 4 ? "…" : "")." }
        return g
    }

    // MARK: result text (the Builder's chain result carries this; the card reads it back)

    static func encode(_ r: Read) -> String { "Paper: \(r.kind.rawValue)\nName: \(r.name)\nGist: \(r.gist)\n---\n\(r.text)" }
    static func decode(_ s: String) -> Read? {
        guard s.hasPrefix("Paper: ") else { return nil }
        let parts = s.components(separatedBy: "\n---\n")
        let head = parts[0].components(separatedBy: "\n")
        func v(_ p: String) -> String { head.first { $0.hasPrefix(p) }.map { String($0.dropFirst(p.count)) } ?? "" }
        guard let k = Kind(rawValue: v("Paper: ")) else { return nil }
        return Read(kind: k, name: v("Name: "), gist: v("Gist: "), text: parts.count > 1 ? parts[1...].joined(separator: "\n---\n") : "")
    }
}
