import Foundation
import EventKit

/// What a scanned page is, read from its own words — a bill, a receipt, a letter, a form or an ID — so Scan can
/// name the file the way a person would ("Comcast bill Nov 2026") and offer the next step: a reminder before
/// it's due, sign and fill, keep the receipt, or a watermarked copy of an ID.
enum ScanSmart {
    enum Kind: String { case bill, receipt, letter, form, id, other
        var noun: String { ["bill", "receipt", "letter", "form", "ID", "document"][["bill", "receipt", "letter", "form", "id", "other"].firstIndex(of: rawValue)!] }
    }

    struct Read: Equatable {
        var kind: Kind = .other
        var from = ""             // the company or sender
        var due: Date?
        var amount: Double?
        var name = "Scan"         // the file name, without .pdf
        var summary: String {
            var bits = [kind == .other ? "A document" : "A \(kind.noun)" + (from.isEmpty ? "" : " from \(from)")]
            if let due { bits.append("due \(due.formatted(date: .abbreviated, time: .omitted))") }
            if let amount { bits.append(String(format: "%.2f", amount)) }
            return bits.joined(separator: " · ")
        }
    }

    static func read(_ text: String, now: Date = Date()) -> Read {
        var r = Read()
        let low = text.lowercased()
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        func has(_ p: String) -> Bool { low.range(of: p, options: .regularExpression) != nil }

        if has(#"\b(passport|driver'?s? licen[cs]e|identity card|date of birth|\bdob\b|national id|residence permit)\b"#) { r.kind = .id }
        else if has(#"\b(amount due|balance due|total due|payment due|due date|pay by|minimum payment|account number|statement date|billing period)\b"#) { r.kind = .bill }
        else if DataGrab.detect(text) == .receipt || has(#"\b(receipt|subtotal|change due|thank you for (shopping|your purchase))\b"#) { r.kind = .receipt }
        else if has(#"_{5,}|\b(signature|sign here|please print|applicant|tick (one|all))\b"#) { r.kind = .form }
        else if has(#"\b(dear|yours (sincerely|faithfully)|kind regards|best regards|sincerely)\b"#) { r.kind = .letter }

        // Who it's from: the receipt reader's shop, else the first business-looking line near the top.
        if r.kind == .receipt { r.from = DataGrab.receipt(text).merchant }
        if r.from.isEmpty {
            r.from = lines.prefix(8).first { l in
                l.filter(\.isLetter).count >= 3 && l.count <= 40 && l.range(of: #"\d{3,}|@|www\.|page \d|^(dear|to|re|date|invoice|statement|account)\b"#, options: [.regularExpression, .caseInsensitive]) == nil
            } ?? ""
            if r.from == r.from.uppercased(), r.from.count > 3 { r.from = r.from.capitalized }
        }

        // When it's due: the date on a "due / pay by" line.
        for l in lines where l.range(of: #"\b(due|pay by|payment date|deadline|respond by|reply by|before)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            let d = DataGrab.printedDates(in: l).first ?? DataGrab.calendarDates(in: l).first ?? DataGrab.monthDay(in: l, now: now)
            if let d { r.due = d; break }
        }
        // How much: the amount on the "amount due / total due / balance" line, else the receipt total.
        for l in lines where l.range(of: #"\b(amount due|total due|balance due|new balance|total amount|please pay|amount payable)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            if let m = l.range(of: DataGrab.moneyPattern, options: .regularExpression),
               let v = Double(l[m].filter { $0.isNumber || $0 == "." }) { r.amount = v; break }
        }
        if r.amount == nil, r.kind == .receipt { r.amount = DataGrab.receipt(text).total }

        // The name a person would give the file.
        let month = (r.due ?? now).formatted(.dateTime.month(.abbreviated).year())
        let who = String(r.from.prefix(30)).trimmingCharacters(in: .whitespaces)
        switch r.kind {
        case .bill: r.name = [who, "bill", month].filter { !$0.isEmpty }.joined(separator: " ")
        case .receipt: r.name = [who, "receipt", now.formatted(.dateTime.day().month(.abbreviated).year())].filter { !$0.isEmpty }.joined(separator: " ")
        case .letter: r.name = (who.isEmpty ? "Letter" : "Letter from \(who)") + " \(month)"
        case .form: r.name = (lines.first.map { String($0.prefix(40)) } ?? "Form").trimmingCharacters(in: .whitespaces) + " form"
        case .id: r.name = "ID copy \(now.formatted(.dateTime.day().month(.abbreviated).year()))"
        case .other: r.name = lines.first.map { String($0.prefix(40)) } ?? "Scan"
        }
        r.name = safeFileName(r.name)
        return r
    }

    static func safeFileName(_ s: String) -> String {
        let cleaned = s.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|\n\t")).joined(separator: " ")
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Scan" : String(cleaned.prefix(60))
    }

    /// A reminder in Apple Reminders: 3 days before, and on the day, at 9:00.
    static func remind(_ r: Read) async throws -> Bool {
        guard let due = r.due else { return false }
        let store = EKEventStore()
        guard try await store.requestFullAccessToReminders(), let list = store.defaultCalendarForNewReminders() else { return false }
        let cal = Calendar.current
        let rem = EKReminder(eventStore: store)
        rem.calendar = list
        rem.title = r.kind == .bill ? "Pay \(r.from.isEmpty ? "the bill" : r.from)\(r.amount.map { String(format: " — %.2f", $0) } ?? "")" : "Reply: \(r.name)"
        rem.dueDateComponents = cal.dateComponents([.year, .month, .day], from: due)
        let nine = { (d: Date) in cal.date(bySettingHour: 9, minute: 0, second: 0, of: d) ?? d }
        if let before = cal.date(byAdding: .day, value: -3, to: due), nine(before) > Date() { rem.addAlarm(EKAlarm(absoluteDate: nine(before))) }
        rem.addAlarm(EKAlarm(absoluteDate: nine(due)))
        rem.notes = "From a scan in Tenzy: \(r.name)"
        try store.save(rem, commit: true)
        return true
    }
}
