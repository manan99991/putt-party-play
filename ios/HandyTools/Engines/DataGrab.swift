import Foundation

/// Turns OCR'd text into structured data without a model: receipts → line items + totals,
/// business cards → vCard, events → .ics, anything tabular → CSV. Rule-based, so it's testable and
/// works on every phone; an on-device model can refine it when present.
enum DataGrab {
    enum Kind: String { case receipt = "Receipt", card = "Business card", event = "Event", table = "Table", text = "Text" }

    struct Receipt: Equatable {
        /// One bought line: what it was, how many, the price of one, and the line's amount.
        struct Line: Equatable { var name: String; var qty: Double?; var unit: Double?; var amount: Double }
        var merchant = ""; var date: Date?; var items: [(String, Double)] = []; var subtotal: Double?; var tax: Double?; var tip: Double?; var total: Double?; var currency = ""
        var number = ""          // the receipt or invoice number
        var payment = ""         // how it was paid, when the receipt says
        var taxRate: Double?     // e.g. 6.25 for "Sales Tax 6.25%"
        var lines: [Line] = []
        static func == (a: Receipt, b: Receipt) -> Bool { a.merchant == b.merchant && a.total == b.total && a.items.map(\.0) == b.items.map(\.0) }
    }
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

    /// Words that head a receipt but aren't the shop's name.
    private static let notAShop = #"^(receipt|sales receipt|cash receipt|receipt example|invoice|tax invoice|bill|from|bill to|ship to|sold to|customer( name| address)?|logo|date.*|invoice (number|no\.?)|receipt (number|no\.?|#)|description|qty|thank you.*|welcome.*|copy|duplicate|original)$"#
    private static let shopWord = #"\b(inc|llc|ltd|co|corp|company|store|shop|market|mart|cafe|café|coffee|restaurant|bar|grill|bakery|pharmacy|repair|services?|supply|hardware|foods?|kitchen|motors|garage|salon|studio|posters|outlet)\b"#

    static func receipt(_ text: String) -> Receipt {
        var r = Receipt()
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let flat = lines.map { columns($0).joined(separator: " ") }

        // The shop: right after "From", else the first top line that names a business, else the first plain line.
        let firstCells = lines.prefix(10).map { columns($0).first ?? $0 }
        func shopLike(_ l: String) -> Bool {
            let low = l.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " :#"))
            return l.count > 2 && l.range(of: moneyPattern, options: .regularExpression) == nil && l.range(of: #"^\d"#, options: .regularExpression) == nil
                && low.range(of: notAShop, options: .regularExpression) == nil && !low.contains("@") && !low.contains("www") && l.filter(\.isLetter).count >= 3
        }
        if let i = firstCells.firstIndex(where: { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " :")) == "from" }), i + 1 < firstCells.count, shopLike(firstCells[i + 1]) {
            r.merchant = firstCells[i + 1]
        } else {
            r.merchant = firstCells.first { shopLike($0) && $0.range(of: shopWord, options: [.regularExpression, .caseInsensitive]) != nil }
                ?? firstCells.first(where: shopLike) ?? ""
        }

        // The date: one labelled as the receipt's or sale's date wins; a due date never does.
        let dated = flat.filter { !$0.lowercased().contains("due") }
        r.date = dated.first { $0.lowercased().contains("date") }.flatMap { dates(in: $0).first }
            ?? dates(in: dated.joined(separator: "\n")).first
        if let m = matches(#"(?:receipt|invoice|order|transaction|ticket)\s*(?:#|no\.?|number|num)\s*[:#]?\s*[A-Z0-9][A-Z0-9-]{2,}"#, in: flat.joined(separator: "\n"), options: .caseInsensitive).first,
           let id = matches(#"[A-Z0-9][A-Z0-9-]{2,}$"#, in: m, options: .caseInsensitive).first { r.number = id }
        let low = text.lowercased()
        for (word, name) in [("visa", "Visa"), ("mastercard", "Mastercard"), ("amex", "Amex"), ("american express", "Amex"), ("discover", "Discover"),
                             ("apple pay", "Apple Pay"), ("google pay", "Google Pay"), ("debit", "Debit card"), ("credit", "Credit card"),
                             ("cash", "Cash"), ("cheque", "Check"), ("payment method: check", "Check")] where low.contains(word) { r.payment = name; break }
        if let sym = text.range(of: #"[$€£₹]"#, options: .regularExpression) { r.currency = String(text[sym]) }

        var balance: Double?
        for raw in lines {
            // A percentage is a rate, never a price ("Sales Tax 6.25%  9.06").
            let rate = matches(#"\d{1,2}(?:[.,]\d{1,3})?\s?%"#, in: raw).first
            let l = raw.replacingOccurrences(of: #"\d{1,2}(?:[.,]\d{1,3})?\s?%"#, with: " ", options: .regularExpression)
            let amounts = matches(moneyPattern, in: l).compactMap(amount)
            guard let amt = amounts.last else { continue }
            var cells = columns(l).map { $0.replacingOccurrences(of: moneyPattern, with: "", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: " .:-\t$€£₹")) }.filter { !$0.isEmpty }
            var qty: Double?
            if let first = cells.first, let q = Double(first), q > 0, q < 1000, first.range(of: #"^\d{1,3}$"#, options: .regularExpression) != nil, cells.count > 1 { qty = q; cells.removeFirst() }
            else if cells.count == 1, amounts.count >= 2, let m = matches(#"^\d{1,3}\s+(?=\D)"#, in: cells[0]).first, let q = Double(m.trimmingCharacters(in: .whitespaces)), q > 0,
                    abs(q * amounts[amounts.count - 2] - amt) <= 0.02 {
                qty = q; cells[0] = String(cells[0].dropFirst(m.count))     // "2 New set of pedal arms 15.00 30.00" read as one piece
            }
            let label = cells.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            let lowLabel = label.lowercased()
            if lowLabel.range(of: #"\b(sub ?total)\b"#, options: .regularExpression) != nil { r.subtotal = amt }
            else if lowLabel.range(of: #"\b(tax|vat|gst|hst)\b"#, options: .regularExpression) != nil {
                r.tax = (r.tax ?? 0) + amt
                if let rate { r.taxRate = Double(rate.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) }
            }
            else if lowLabel.range(of: #"\b(tip|gratuity)\b"#, options: .regularExpression) != nil { r.tip = amt }
            else if lowLabel.range(of: #"\b(balance due|balance|amount due)\b"#, options: .regularExpression) != nil { if amt > 0 { balance = amt } }
            else if lowLabel.range(of: #"\b(total|grand total|total paid|amount paid)\b"#, options: .regularExpression) != nil { r.total = max(r.total ?? 0, amt) }
            else if lowLabel.range(of: #"\b(change|cash|tendered|visa|mastercard|amex|card|auth|approval|paid)\b"#, options: .regularExpression) != nil { continue }
            else if label.filter(\.isLetter).count >= 2, amt > 0, label.split(separator: " ").count <= 9,
                    lowLabel.range(of: #"\b(due date|p\.?o\.?|invoice|receipt (date|number|#))\b"#, options: .regularExpression) == nil {
                // "1  Front and rear brake cables  100.00  100.00": quantity, item, price of one, line amount.
                let unit = amounts.count >= 2 ? amounts[amounts.count - 2] : (qty.map { amt / max($0, 1) })
                r.lines.append(Receipt.Line(name: label, qty: qty, unit: unit, amount: amt))
                r.items.append((label, amt))
            }
        }
        if r.total == nil { r.total = balance }
        if r.total == nil, let s = r.subtotal { r.total = s + (r.tax ?? 0) + (r.tip ?? 0) }
        if r.total == nil, !r.items.isEmpty { r.total = r.items.map(\.1).reduce(0, +) }
        return r
    }

    // The last receipts read by a flow, so the result screen can show the whole receipt (shop, date, lines)
    // rather than just the spreadsheet text the step hands on.
    private static let memoLock = NSLock()
    private static var memo: [String: Receipt] = [:]
    static func remember(_ key: String, _ r: Receipt) {
        memoLock.lock(); defer { memoLock.unlock() }
        if memo.count > 20 { memo.removeAll() }
        memo[key] = r
    }
    static func recalled(_ key: String) -> Receipt? {
        memoLock.lock(); defer { memoLock.unlock() }
        return memo[key]
    }

    /// A plain sentence when the numbers on the receipt don't agree, so a misread is caught before it's filed.
    static func check(_ r: Receipt) -> String? {
        let items = r.lines.map(\.amount).reduce(0, +)
        func money(_ v: Double) -> String { String(format: "%@%.2f", r.currency.isEmpty ? "" : r.currency, v) }
        if !r.lines.isEmpty, let s = r.subtotal, abs(items - s) > 0.02 { return "The items add up to \(money(items)), but the subtotal says \(money(s)). Check the lines below against the photo." }
        if let s = r.subtotal, let t = r.total, abs(s + (r.tax ?? 0) + (r.tip ?? 0) - t) > 0.02 { return "Subtotal plus tax comes to \(money(s + (r.tax ?? 0) + (r.tip ?? 0))), but the total says \(money(t))." }
        if r.subtotal == nil, r.tax == nil, !r.lines.isEmpty, let t = r.total, abs(items - t) > 0.02 { return "The items add up to \(money(items)), but the total says \(money(t))." }
        return nil
    }

    static func receiptCSV(_ r: Receipt) -> String {
        if r.lines.contains(where: { $0.qty != nil }) {
            return receiptRows(r).map { $0.map(csv).joined(separator: ",") }.joined(separator: "\n")
        }
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

    private static func lastAmount(in line: String) -> Double? { matches(moneyPattern, in: line).last.flatMap(amount) }

    /// "$1,234.56" → 1234.56, "1.234,56" → 1234.56.
    private static func amount(_ money: String) -> Double? {
        var s = money.replacingOccurrences(of: #"[^\d.,-]"#, with: "", options: .regularExpression)
        // "1.234,56" → 1234.56 ; "1,234.56" → 1234.56
        if let c = s.lastIndex(of: ","), let d = s.lastIndex(of: "."), c > d { s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".") }
        else if s.contains(","), !s.contains(".") , s.split(separator: ",").last?.count == 2 { s = s.replacingOccurrences(of: ",", with: ".") }
        else { s = s.replacingOccurrences(of: ",", with: "") }
        return Double(s)
    }

    // MARK: business card

    /// A card's text as cells: two-column cards ("Henrietta Mitchell    + Studio") are read as two pieces, not one
    /// line, and decorations ("+", "|", "•") are dropped. Row and column kept, so stacked lines can be joined.
    static func cardCells(_ text: String) -> [(row: Int, col: Int, text: String)] {
        var out: [(Int, Int, String)] = []
        for (r, raw) in text.split(whereSeparator: \.isNewline).enumerated() {
            let line = String(raw)
            let parts: [String]
            if line.contains("\t") { parts = line.components(separatedBy: "\t") }
            else if line.contains("|") { parts = line.components(separatedBy: "|") }
            else { parts = line.components(separatedBy: "  ") }
            var c = 0
            for p in parts {
                let t = p.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "+•·|*~–—-").union(.whitespaces))
                guard !t.isEmpty else { continue }
                out.append((r, c, t)); c += 1
            }
        }
        return out
    }

    static func card(_ text: String) -> Card {
        var c = Card()
        let cells = cardCells(text)
        c.emails = matches(#"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, in: text, options: .caseInsensitive)
        c.phones = phoneNumbers(in: text)
        var noEmails = text
        for e in c.emails { noEmails = noEmails.replacingOccurrences(of: e, with: " ") }
        let sites = matches(#"(?:https?://)?(?:www\.)?[a-z0-9-]+\.(?:com|net|org|io|co|ai|app|dev|uk|ca|au|de|fr|in)(?:/\S*)?"#, in: noEmails, options: .caseInsensitive)
        c.website = sites.first { $0.lowercased().hasPrefix("www.") || $0.lowercased().hasPrefix("http") } ?? sites.first ?? ""
        let titleWords = #"\b(ceo|cto|cfo|coo|vp|president|manager|director|head|lead|engineer|sales|consultant|founder|co-founder|partner|agent|realtor|designer|developer|attorney|lawyer|md|dds|phd|specialist|analyst|associate|officer|owner|principal|creative|artist|photographer|architect|accountant|broker|advisor|adviser|coach|therapist|editor|writer|producer)\b"#
        let used = Set(c.emails + c.phones + [c.website]).filter { !$0.isEmpty }
        func isContact(_ t: String) -> Bool {
            used.contains { t.contains($0) } || t.range(of: #"^\+?[\d\s().-]{7,}$"#, options: .regularExpression) != nil || t.lowercased().hasPrefix("www.") || t.contains("@")
        }
        let street = #"\d{1,6} [A-Za-z0-9 .'-]{2,40}\b(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Way|Suite|Ste|Floor|Court|Ct|Place|Pl|Square|Sq)\b"#
        let cityLine = #"^[A-Za-z .'-]+,\s*[A-Z]{2}\s+\d{5}(?:-\d{4})?$"#
        // The address: the street cell, plus the city line under it in the same column.
        var addressCells = Set<Int>()
        if let si = cells.firstIndex(where: { $0.text.range(of: street, options: .regularExpression) != nil }) {
            var addr = cells[si].text; addressCells.insert(si)
            if let ci = cells.firstIndex(where: { $0.row == cells[si].row + 1 && $0.col == cells[si].col }),
               cells[ci].text.range(of: #"\d{5}|,\s*[A-Z]{2}\b"#, options: .regularExpression) != nil {
                addr += (addr.hasSuffix(",") ? " " : " ") + cells[ci].text; addressCells.insert(ci)
            }
            c.address = addr
        } else if let ci = cells.firstIndex(where: { $0.text.range(of: cityLine, options: .regularExpression) != nil }) {
            c.address = cells[ci].text; addressCells.insert(ci)
        }
        let candidates = cells.indices.filter { !addressCells.contains($0) && !isContact(cells[$0].text) && cells[$0].text.filter(\.isLetter).count >= 2 }
        func text(_ i: Int) -> String { cells[i].text }
        let ti = candidates.first { text($0).range(of: titleWords, options: [.regularExpression, .caseInsensitive]) != nil && text($0).split(separator: " ").count <= 5 }
        c.title = ti.map(text) ?? ""
        let companyWord = #"\b(inc|llc|ltd|gmbh|corp|co\.|company|group|studio|studios|labs|partners|agency|solutions|technologies|consulting|robotics|systems|bank|university|hospital|clinic|design|media|realty|law|associates|& co)\b"#
        let personLike = #"^[A-Z][a-zA-Z'’.-]+(?: [A-Z][a-zA-Z'’.-]+){1,3}$"#
        var ci = candidates.first { $0 != ti && text($0).range(of: companyWord, options: [.regularExpression, .caseInsensitive]) != nil }
        if ci == nil { ci = candidates.first { $0 != ti && text($0) == text($0).uppercased() && text($0).count > 3 && text($0).range(of: personLike, options: .regularExpression) == nil } }
        var companyParts = Set<Int>()
        if let k = ci {
            var name = text(k); companyParts.insert(k)
            // A company name printed on two lines ("Studio" over "Salford") is one name.
            if let below = candidates.first(where: { cells[$0].row == cells[k].row + 1 && cells[$0].col == cells[k].col && $0 != ti }),
               text(below).split(separator: " ").count <= 3, text(below).rangeOfCharacter(from: .decimalDigits) == nil,
               text(below).range(of: titleWords, options: [.regularExpression, .caseInsensitive]) == nil {
                name += " " + text(below); companyParts.insert(below)
            }
            c.company = name
        }
        let rest = candidates.filter { $0 != ti && !companyParts.contains($0) }
        c.name = rest.first { text($0).range(of: personLike, options: .regularExpression) != nil }.map(text)
            ?? rest.first { text($0).range(of: #"^[A-Za-z][A-Za-z'’.-]*(?: [A-Za-z][A-Za-z'’.-]*){1,3}$"#, options: .regularExpression) != nil }.map(text)
            ?? rest.first.map(text) ?? ""
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

    /// The table as rows of cells, every row padded to the same width — what the grid preview and the
    /// Excel export use. `ragged` counts rows that had fewer cells than the widest row.
    static func tableRows(_ text: String) -> (rows: [[String]], ragged: Int) {
        let rows = text.split(whereSeparator: \.isNewline).map { columns(String($0)) }.filter { !$0.isEmpty }
        let width = rows.map(\.count).max() ?? 0
        let ragged = rows.filter { $0.count < width }.count
        return (rows.map { $0 + Array(repeating: "", count: max(0, width - $0.count)) }, ragged)
    }

    /// Receipt lines as spreadsheet rows (header first), money as plain numbers.
    static func receiptRows(_ r: Receipt) -> [[String]] {
        func m(_ v: Double) -> String { String(format: "%.2f", v) }
        guard r.lines.contains(where: { $0.qty != nil }) else {
            var rows = [["Item", "Amount"]]
            rows += r.items.map { [$0.0, m($0.1)] }
            if let s = r.subtotal { rows.append(["Subtotal", m(s)]) }
            if let t = r.tax { rows.append([r.taxRate.map { "Tax (\(formatRate($0))%)" } ?? "Tax", m(t)]) }
            if let t = r.tip { rows.append(["Tip", m(t)]) }
            if let t = r.total { rows.append(["Total", m(t)]) }
            return rows
        }
        var rows = [["Item", "Qty", "Unit price", "Amount"]]
        rows += r.lines.map { [$0.name, $0.qty.map { $0 == $0.rounded() ? String(Int($0)) : String($0) } ?? "", $0.unit.map(m) ?? "", m($0.amount)] }
        if let s = r.subtotal { rows.append(["Subtotal", "", "", m(s)]) }
        if let t = r.tax { rows.append([r.taxRate.map { "Tax (\(formatRate($0))%)" } ?? "Tax", "", "", m(t)]) }
        if let t = r.tip { rows.append(["Tip", "", "", m(t)]) }
        if let t = r.total { rows.append(["Total", "", "", m(t)]) }
        return rows
    }
    static func formatRate(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%g", v) }

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
