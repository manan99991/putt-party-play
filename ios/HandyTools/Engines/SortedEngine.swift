import Foundation
import UIKit

/// The engine behind Sorted — point the camera at a bill, appointment card, form or notice and get
/// back what it is, what you owe, and the date that matters, then drop it on your calendar. Dates and
/// amounts are found with the system data detector (works on every phone); on Apple Intelligence
/// phones the on-device model adds the plain-English "what it is / what to do". Nothing is uploaded.
enum SortedEngine {

    struct Parsed {
        var kind: String          // Bill, Appointment, Form, Notice, Receipt, Document
        var title: String
        var amount: String?
        var due: Date?
        var summary: String
    }

    // MARK: universal extraction (no AI)

    static func dates(in text: String) -> [Date] {
        guard let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return [] }
        var out: [Date] = []
        det.enumerateMatches(in: text, range: NSRange(text.startIndex..., in: text)) { m, _, _ in
            if let d = m?.date { out.append(d) }
        }
        return out
    }

    /// The most useful date: the soonest one that's still in the future, else the latest found.
    static func keyDate(in text: String) -> Date? {
        let all = dates(in: text)
        let future = all.filter { $0 > Date() }.sorted()
        return future.first ?? all.sorted().last
    }

    static func amount(in text: String) -> String? {
        let pattern = #"[$£€]\s?\d[\d,]*(?:\.\d{2})?"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = re.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { Range($0.range, in: text).map { String(text[$0]) } }
        // Prefer the largest-looking amount (usually the total).
        return matches.max { numeric($0) < numeric($1) }
    }

    private static func numeric(_ s: String) -> Double {
        Double(s.filter { $0.isNumber || $0 == "." }) ?? 0
    }

    static func guessKind(_ text: String) -> String {
        let t = text.lowercased()
        if t.contains("appointment") || t.contains("appt") || t.contains("visit") || t.contains("booking") { return "Appointment" }
        if t.contains("invoice") || t.contains("amount due") || t.contains("balance due") || t.contains("bill") || t.contains("payment due") { return "Bill" }
        if t.contains("receipt") || t.contains("subtotal") || t.contains("total") { return "Receipt" }
        if t.contains("renew") || t.contains("expires") || t.contains("notice") { return "Notice" }
        if t.contains("sign") || t.contains("form") || t.contains("application") { return "Form" }
        return "Document"
    }

    static func titleGuess(_ text: String) -> String {
        text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.count > 2 } ?? "Scanned document"
    }

    /// Always-available parse from OCR text.
    static func basicParse(_ text: String) -> Parsed {
        let due = keyDate(in: text)
        let amt = amount(in: text)
        var summary = "Pulled the key details from the scan."
        if due != nil && amt != nil { summary = "Looks like something to pay by the date below — check the amount and deadline." }
        else if due != nil { summary = "There's a date on this — added below so you can calendar it." }
        return Parsed(kind: guessKind(text), title: titleGuess(text), amount: amt, due: due, summary: summary)
    }

    // MARK: AI parse (iPhone 15 Pro+)

    static func aiParse(_ text: String) async -> Parsed? {
        guard AIEngine.isAvailable else { return nil }
        let instructions = "You read a scanned everyday document (a bill, appointment card, form, or notice) and summarise it for a busy person. Reply with EXACTLY these five lines and nothing else:\nKIND: <Bill|Appointment|Form|Notice|Receipt|Document>\nTITLE: <short name, max 6 words>\nAMOUNT: <the money owed with its symbol, or none>\nDUE: <the single most important date as YYYY-MM-DD, or none>\nSUMMARY: <one or two plain sentences: what it is and what to do>"
        guard let raw = try? await AIEngine.run(instructions: instructions, prompt: String(text.prefix(2500))) else { return nil }
        var p = basicParse(text)   // start from the reliable extraction, let the model refine
        for line in raw.components(separatedBy: .newlines) {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let value = parts[1]
            switch parts[0].uppercased() {
            case "KIND" where !value.isEmpty: p.kind = value
            case "TITLE" where !value.isEmpty: p.title = value
            case "AMOUNT": p.amount = value.lowercased() == "none" ? p.amount : value
            case "DUE":
                if value.lowercased() != "none", let d = isoDate(value) { p.due = d }
            case "SUMMARY" where !value.isEmpty: p.summary = value
            default: break
            }
        }
        return p
    }

    private static func isoDate(_ s: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return f.date(from: s)
    }

    // MARK: calendar file (.ics) — no permission needed; the user confirms in Calendar

    /// Writes a calendar event file for the parsed item with a one-day-before alert, and returns its
    /// URL to share. Opening it adds the event via the system Calendar, so Sorted never needs calendar
    /// access of its own.
    static func icsURL(_ p: Parsed) -> URL? {
        guard let due = p.due else { return nil }
        let cal = Calendar.current
        // 9am on the due day.
        let start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: due) ?? due
        let end = start.addingTimeInterval(3600)
        let fmt = DateFormatter(); fmt.dateFormat = "yyyyMMdd'T'HHmmss"; fmt.timeZone = .current
        let stamp = DateFormatter(); stamp.dateFormat = "yyyyMMdd'T'HHmmss'Z'"; stamp.timeZone = TimeZone(identifier: "UTC")
        var notes = p.summary
        if let a = p.amount { notes += "\\nAmount: \(a)" }
        notes += "\\nAdded by Tenzy"
        let title = p.amount != nil ? "\(p.title) — \(p.amount!)" : p.title
        let ics = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Tenzy//Sorted//EN
        CALSCALE:GREGORIAN
        METHOD:PUBLISH
        BEGIN:VEVENT
        UID:\(UUID().uuidString)@tenzy.app
        DTSTAMP:\(stamp.string(from: Date()))
        DTSTART:\(fmt.string(from: start))
        DTEND:\(fmt.string(from: end))
        SUMMARY:\(escape(title))
        DESCRIPTION:\(escape(notes))
        BEGIN:VALARM
        TRIGGER:-P1D
        ACTION:DISPLAY
        DESCRIPTION:\(escape(title))
        END:VALARM
        END:VEVENT
        END:VCALENDAR
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tenzy-\(UUID().uuidString.prefix(6)).ics")
        guard (try? ics.write(to: url, atomically: true, encoding: .utf8)) != nil else { return nil }
        return url
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: ",", with: "\\,").replacingOccurrences(of: ";", with: "\\;")
    }

    static func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .full; f.timeStyle = .none; return f.string(from: d)
    }
}
