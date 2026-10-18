import Foundation

/// Turns OCR'd text into structured data without a model: receipts → line items + totals,
/// business cards → vCard, events → .ics, anything tabular → CSV. Rule-based, so it's testable and
/// works on every phone; an on-device model can refine it when present.
enum DataGrab {
    enum Kind: String { case receipt = "Receipt", card = "Business card", event = "Event", table = "Table", text = "Text" }

    struct Receipt: Equatable { var merchant = ""; var date: Date?; var items: [(String, Double)] = []; var subtotal: Double?; var tax: Double?; var tip: Double?; var total: Double?; var currency = ""
        static func == (a: Receipt, b: Receipt) -> Bool { a.merchant == b.merchant && a.total == b.total && a.items.map(\.0) == b.items.map(\.0) } }
    struct Card: Equatable { var name = ""; var title = ""; var company = ""; var phones: [String] = []; var emails: [String] = []; var website = ""; var address = "" }
    struct Event: Equatable { var title = ""; var start: Date?; var end: Date?; var location = "" }

    // MARK: detect

    static func detect(_ text: String) -> Kind {
        let lower = text.lowercased()
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let moneyLines = lines.filter { $0.range(of: moneyPattern, options: .regularExpression) != nil }.count
        if lower.range(of: #"\b(total|subtotal|amount due|balance due|change|cash|visa|mastercard|receipt|thank you for)\b"#, options: .regularExpression) != nil, moneyLines >= 2 { return .receipt }
        let emails = matches(#"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, in: text, options: .caseInsensitive).count
        let phones = phoneNumbers(in: text).count
        if lines.count <= 14, (emails > 0 || phones > 0), moneyLines == 0, lower.range(of: #"\b(ceo|cto|manager|director|engineer|sales|consultant|founder|partner|agent|realtor|designer|developer|attorney|md|dds|llc|inc|ltd|gmbh|www\.|\.com)\b"#, options: .regularExpression) != nil { return .card }
        if dates(in: text).count >= 1, lower.range(of: #"\b(join us|invite|invitation|rsvp|meeting|webinar|concert|conference|workshop|party|appointment|doors|starts? at|pm|am|tickets?)\b"#, options: .regularExpression) != nil, moneyLines <= 2 { return .event }
        if lines.count >= 3, lines.filter({ columns($0).count >= 2 }).count >= Int(Double(lines.count) * 0.6) { return .table }
        if emails > 0 || phones > 0, lines.count <= 14 { return .card }
        return .text
    }

    // MARK: receipt

    static let moneyPattern = #"(?:[$€£₹]|USD|EUR|GBP|INR|CAD|AUD)?\s?-?\d{1,3}(?:[,\d]{0,9})(?:[.,]\d{2})\b"#

    static func receipt(_ text: String) -> Receipt {
        var r = Receipt()
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        r.merchant = lines.first { $0.range(of: moneyPattern, options: .regularExpression) == nil && $0.count > 2 && $0.range(of: #"^\d"#, options: .regularExpression) == nil } ?? ""
        r.date = dates(in: text).first
        if let sym = text.range(of: #"[$€£₹]"#, options: .regularExpression) { r.currency = String(text[sym]) }
        for l in lines {
            guard let amt = lastAmount(in: l) else { continue }
            let label = l.replacingOccurrences(of: moneyPattern, with: "", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: " .:-\t"))
            let low = label.lowercased()
            if low.range(of: #"\b(sub ?total)\b"#, options: .regularExpression) != nil { r.subtotal = amt }
            else if low.range(of: #"\b(tax|vat|gst|hst)\b"#, options: .regularExpression) != nil { r.tax = (r.tax ?? 0) + amt }
            else if low.range(of: #"\b(tip|gratuity)\b"#, options: .regularExpression) != nil { r.tip = amt }
            else if low.range(of: #"\b(total|amount due|balance due|grand total)\b"#, options: .regularExpression) != nil { r.total = amt }
            else if low.range(of: #"\b(change|cash|tendered|visa|mastercard|amex|card|auth|approval|balance)\b"#, options: .regularExpression) != nil { continue }
            else if !label.isEmpty, amt > 0 { r.items.append((label, amt)) }
        }
        if r.total == nil, let s = r.subtotal { r.total = s + (r.tax ?? 0) + (r.tip ?? 0) }
        if r.total == nil, !r.items.isEmpty { r.total = r.items.map(\.1).reduce(0, +) }
        return r
    }

    static func receiptCSV(_ r: Receipt) -> String {
        var rows = ["Item,Amount"]
        rows += r.items.map { "\(csv($0.0)),\(String(format: "%.2f", $0.1))" }
        if let s = r.subtotal { rows.append("Subtotal,\(String(format: "%.2f", s))") }
        if let t = r.tax { rows.append("Tax,\(String(format: "%.2f", t))") }
        if let t = r.tip { rows.append("Tip,\(String(format: "%.2f", t))") }
        if let t = r.total { rows.append("Total,\(String(format: "%.2f", t))") }
        return rows.joined(separator: "\n")
    }

    /// One row for an expense sheet.
    static func expenseRow(_ r: Receipt) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return "Date,Merchant,Total,Tax,Currency\n\(r.date.map { f.string(from: $0) } ?? ""),\(csv(r.merchant)),\(r.total.map { String(format: "%.2f", $0) } ?? ""),\(r.tax.map { String(format: "%.2f", $0) } ?? ""),\(r.currency)"
    }

    private static func lastAmount(in line: String) -> Double? {
        let ms = matches(moneyPattern, in: line)
        guard let last = ms.last else { return nil }
        var s = last.replacingOccurrences(of: #"[^\d.,-]"#, with: "", options: .regularExpression)
        // "1.234,56" → 1234.56 ; "1,234.56" → 1234.56
        if let c = s.lastIndex(of: ","), let d = s.lastIndex(of: "."), c > d { s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".") }
        else if s.contains(","), !s.contains(".") , s.split(separator: ",").last?.count == 2 { s = s.replacingOccurrences(of: ",", with: ".") }
        else { s = s.replacingOccurrences(of: ",", with: "") }
        return Double(s)
    }

    // MARK: business card

    static func card(_ text: String) -> Card {
        var c = Card()
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        c.emails = matches(#"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, in: text, options: .caseInsensitive)
        c.phones = phoneNumbers(in: text)
        c.website = matches(#"(?:https?://)?(?:www\.)?[a-z0-9-]+\.(?:com|net|org|io|co|ai|app|dev|uk|ca|au|de|fr|in)(?:/\S*)?"#, in: text, options: .caseInsensitive).first { !$0.contains("@") } ?? ""
        let titleWords = #"\b(ceo|cto|cfo|coo|vp|president|manager|director|head|lead|engineer|sales|consultant|founder|co-founder|partner|agent|realtor|designer|developer|attorney|lawyer|md|dds|phd|specialist|analyst|associate|officer|owner|principal)\b"#
        let used = Set(c.emails + c.phones + [c.website])
        let candidates = lines.filter { l in !used.contains(where: { !$0.isEmpty && l.contains($0) }) && l.range(of: #"^\+?[\d\s().-]{7,}$"#, options: .regularExpression) == nil }
        c.title = candidates.first { $0.range(of: titleWords, options: [.regularExpression, .caseInsensitive]) != nil } ?? ""
        c.company = candidates.first { $0 != c.title && ($0.range(of: #"\b(inc|llc|ltd|gmbh|corp|co\.|company|group|studio|labs|partners|agency|solutions|technologies|consulting)\b"#, options: [.regularExpression, .caseInsensitive]) != nil || $0 == $0.uppercased() && $0.count > 3 && $0.rangeOfCharacter(from: .letters) != nil) } ?? ""
        c.name = candidates.first { l in l != c.title && l != c.company && l.range(of: #"^[A-Z][a-zA-Z'’.-]+(?: [A-Z][a-zA-Z'’.-]+){1,3}$"#, options: .regularExpression) != nil } ?? candidates.first { $0 != c.title && $0 != c.company } ?? ""
        if let addr = matches(#"\d{1,6} [A-Za-z0-9 .'-]{3,40}(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Way|Suite|Ste|Floor)\b.*"#, in: text).first { c.address = addr }
        return c
    }

    static func vcard(_ c: Card) -> String {
        var v = ["BEGIN:VCARD", "VERSION:3.0"]
        let parts = c.name.split(separator: " ").map(String.init)
        v.append("N:\(parts.last ?? "");\(parts.dropLast().joined(separator: " "));;;")
        v.append("FN:\(c.name)")
        if !c.company.isEmpty { v.append("ORG:\(c.company)") }
        if !c.title.isEmpty { v.append("TITLE:\(c.title)") }
        for p in c.phones { v.append("TEL;TYPE=WORK,VOICE:\(p)") }
        for e in c.emails { v.append("EMAIL;TYPE=WORK:\(e)") }
        if !c.website.isEmpty { v.append("URL:\(c.website.hasPrefix("http") ? c.website : "https://" + c.website)") }
        if !c.address.isEmpty { v.append("ADR;TYPE=WORK:;;\(c.address.replacingOccurrences(of: ",", with: "\\,"));;;;") }
        v.append("END:VCARD")
        return v.joined(separator: "\r\n")
    }

    // MARK: event

    static func event(_ text: String) -> Event {
        var e = Event()
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let ds = dateMatches(in: text)
        e.start = ds.first?.date
        if let first = ds.first { e.end = first.duration > 0 ? first.date.addingTimeInterval(first.duration) : ds.dropFirst().first?.date }
        if e.end == nil, let s = e.start { e.end = s.addingTimeInterval(3600) }
        e.title = lines.first { l in l.range(of: #"\d"#, options: .regularExpression) == nil && l.count >= 4 && l.lowercased().range(of: #"\b(rsvp|join us|tickets|doors|location|venue|where|when)\b"#, options: .regularExpression) == nil } ?? lines.first ?? "Event"
        if let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue), let m = det.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            e.location = (text as NSString).substring(with: m.range)
        } else if let l = lines.first(where: { $0.lowercased().hasPrefix("at ") || $0.lowercased().hasPrefix("location") || $0.lowercased().hasPrefix("venue") || $0.lowercased().hasPrefix("where") }) {
            e.location = l.replacingOccurrences(of: #"^(at|location|venue|where)[:\s-]*"#, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return e
    }

    static func ics(_ e: Event) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"; f.timeZone = TimeZone(identifier: "UTC")
        let start = e.start ?? Date(), end = e.end ?? start.addingTimeInterval(3600)
        return ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Tenzy//Data Grabber//EN", "BEGIN:VEVENT", "UID:\(UUID().uuidString)@tenzy", "DTSTAMP:\(f.string(from: Date()))", "DTSTART:\(f.string(from: start))", "DTEND:\(f.string(from: end))", "SUMMARY:\(e.title)", e.location.isEmpty ? nil : "LOCATION:\(e.location.replacingOccurrences(of: ",", with: "\\,"))", "END:VEVENT", "END:VCALENDAR"].compactMap { $0 }.joined(separator: "\r\n")
    }

    // MARK: table

    /// Split a line into columns on 2+ spaces, tabs, pipes, or commas (whichever the line uses).
    static func columns(_ line: String) -> [String] {
        if line.contains("\t") { return line.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) } }
        if line.contains("|") { return line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        let bySpaces = line.components(separatedBy: "  ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if bySpaces.count >= 2 { return bySpaces }
        if line.contains(",") { return line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        return [line.trimmingCharacters(in: .whitespaces)]
    }

    static func tableCSV(_ text: String) -> String {
        let rows = text.split(whereSeparator: \.isNewline).map { columns(String($0)) }.filter { !$0.isEmpty }
        let width = rows.map(\.count).max() ?? 0
        return rows.map { r in (r + Array(repeating: "", count: max(0, width - r.count))).map(csv).joined(separator: ",") }.joined(separator: "\n")
    }

    // MARK: helpers

    static func csv(_ s: String) -> String { s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s }

    static func matches(_ pattern: String, in text: String, options: NSRegularExpression.Options = []) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        return re.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }

    static func phoneNumbers(in text: String) -> [String] {
        guard let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue) else { return [] }
        return det.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap(\.phoneNumber)
    }
    static func dates(in text: String) -> [Date] { dateMatches(in: text).map(\.date) }
    private static func dateMatches(in text: String) -> [(date: Date, duration: TimeInterval)] {
        guard let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return [] }
        return det.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { m in m.date.map { ($0, m.duration) } }
    }
}
