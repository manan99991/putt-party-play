import Foundation
import CoreGraphics

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
    struct Event: Equatable { var title = ""; var start: Date?; var end: Date?; var location = ""; var notes = ""; var url = "" }

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

    /// A price: "$12.50", "1,234.56", "1.234,56" — or a whole-number currency grouped in thousands, the way
    /// rupiah, won, yen and dong are printed ("60.000", "Rp 25.000", "1,250,000"). Dates and phone numbers
    /// ("11.02.2019", "555.123.4567") are not prices.
    static let moneyPattern = #"(?:[$€£₹¥₩]|USD|EUR|GBP|INR|CAD|AUD|IDR|Rp\.?)?\s?-?(?:(?<![\d.,/])\d{1,3}(?:[,.]?\d{3}){0,3}[.,]\d{2}\b(?![.,/]\d)|(?<![\d.,])\d{1,3}(?:[.,]\d{3})+(?![.,]?\d))"#

    /// Words that head a receipt but aren't the shop's name.
    private static let notAShop = #"^(receipt|sales receipt|cash receipt|receipt example|invoice|tax invoice|bill|from|bill to|ship to|sold to|customer( name| address)?|logo|date.*|invoice (number|no\.?)|receipt (number|no\.?|#)|description|qty|thank you.*|welcome.*|copy|duplicate|original)$"#
    private static let shopWord = #"\b(inc|llc|ltd|co|corp|company|store|shop|market|mart|cafe|café|coffee|restaurant|restoran|bar|grill|bakery|pharmacy|repair|services?|supply|hardware|foods?|kitchen|kitchenette|motors|garage|salon|studio|posters|stickers|outlet|sdn|bhd|s/b|enterprise|trading|holdings|furnishing|stationery|books?|petrol|grocer|electrical|supermarket|pvt|gmbh|plc|pty)\b"#
    /// Lines near the top that are never the shop: registration numbers, document titles, screenshot chrome.
    private static let notAShopLine = #"(co\.?\s*-?\s*re?g|company\s*(no|reg)|\bgst\b|\btax\s*invoice|order\s*number|\bcash\s*sale|receipt\s*example|^lot\b|^tel\b|^fax\b|google\.com|^\d{1,2}:\d{2}$|^(share|save|visit|done)$|\|)"#

    static func receipt(_ text: String) -> Receipt {
        var r = Receipt()
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let flat = lines.map { columns($0).joined(separator: " ") }

        // The shop: right after "From", else the first top line that names a business, else the first plain line.
        // A business name can sit below a logo, a title or (in a screenshot) the browser bar: look a little further
        // for one that says it's a business, but take a plain line only from the very top.
        let topCells = lines.prefix(25).map { columns($0).first ?? $0 }
        let firstCells = Array(topCells.prefix(10))
        func shopLike(_ l: String) -> Bool {
            let low = l.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " :#"))
            return l.count > 2 && l.range(of: moneyPattern, options: .regularExpression) == nil && l.range(of: #"^\d"#, options: .regularExpression) == nil
                && low.range(of: notAShop, options: .regularExpression) == nil && low.range(of: notAShopLine, options: .regularExpression) == nil
                && !low.contains("@") && !low.contains("www") && l.filter(\.isLetter).count >= 3
        }
        if let i = firstCells.firstIndex(where: { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " :")) == "from" }), i + 1 < firstCells.count, shopLike(firstCells[i + 1]) {
            r.merchant = firstCells[i + 1]
        } else {
            r.merchant = topCells.first { shopLike($0) && $0.range(of: shopWord, options: [.regularExpression, .caseInsensitive]) != nil }
                ?? firstCells.first(where: shopLike) ?? ""
        }

        // The date: one labelled as the receipt's or sale's date wins; a due date never does.
        let dated = flat.filter { !$0.lowercased().contains("due") }
        // Day or month first? A date on the receipt that can only be one way decides (26/02/2019 → day first);
        // else where the receipt is from (ringgit, GST, VAT, pounds, euros, rupees print day first).
        let order = numericDateOrder(in: text)
        let dayFirst: Bool? = order ?? (text.range(of: #"\bRM\s?\d|SDN\.?\s?BHD|\bGST\b|\bVAT\b|£|€|₹|\bS/B\b"#, options: [.regularExpression, .caseInsensitive]) != nil ? true : nil)
        func receiptDates(_ l: String) -> [Date] {
            let printed = printedDates(in: l, dayFirst: dayFirst)
            return printed.isEmpty ? calendarDates(in: l) : printed
        }
        r.date = dated.first { $0.lowercased().contains("date") && !receiptDates($0).isEmpty }.flatMap { receiptDates($0).first }
            ?? dated.lazy.compactMap { receiptDates($0).first }.first
        if let m = matches(#"(?:receipt|invoice|order|transaction|ticket)\s*(?:#|no\.?|number|num)\s*[:#]?\s*[A-Z0-9][A-Z0-9-]{2,}"#, in: flat.joined(separator: "\n"), options: .caseInsensitive).first,
           let id = matches(#"[A-Z0-9][A-Z0-9-]{2,}$"#, in: m, options: .caseInsensitive).first { r.number = id }
        let low = text.lowercased()
        for (word, name) in [("visa", "Visa"), ("mastercard", "Mastercard"), ("amex", "Amex"), ("american express", "Amex"), ("discover", "Discover"),
                             ("apple pay", "Apple Pay"), ("google pay", "Google Pay"), ("debit", "Debit card"), ("credit", "Credit card"),
                             ("cash", "Cash"), ("cheque", "Check"), ("payment method: check", "Check")] where low.contains(word) { r.payment = name; break }
        if let sym = text.range(of: #"[$€£₹¥₩]|\bRp\b"#, options: .regularExpression) { r.currency = String(text[sym]) }

        var balance: Double?, strongTotal: Double?, change: Double?, tendered: Double?
        // "TOTAL" on one line and its amount alone on the next (columns read apart).
        var rows = lines
        for i in rows.indices.dropLast() where rows[i].range(of: #"^\s*(grand\s+)?total\b[^\d]*$"#, options: [.regularExpression, .caseInsensitive]) != nil
            && matches(moneyPattern, in: rows[i]).isEmpty {
            let next = rows[i + 1]
            if next.filter(\.isLetter).count <= 3, !matches(moneyPattern, in: next).isEmpty { rows[i] += "  " + next; rows[i + 1] = "" }
        }
        for raw in rows where !raw.isEmpty {
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
            // "GST 6%" or "Total GST" is tax; "Total Sales (Incl GST)" is the total.
            else if lowLabel.range(of: #"\b(tax|vat|gst|hst)\b"#, options: .regularExpression) != nil,
                    lowLabel.range(of: #"\btotal\b(?!\s*(gst|tax|vat|hst))"#, options: .regularExpression) == nil {
                r.tax = (r.tax ?? 0) + amt
                if let rate { r.taxRate = Double(rate.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) }
            }
            else if lowLabel.range(of: #"\b(tip|gratuity)\b"#, options: .regularExpression) != nil { r.tip = amt }
            else if lowLabel.range(of: #"\b(balance due|balance|amount due)\b"#, options: .regularExpression) != nil { if amt > 0 { balance = amt } }
            else if lowLabel.range(of: #"\btotal\s*(qty|quantity|items?|discount|savings?|saved|gst|tax|vat|excl|exclusive|before)"#, options: .regularExpression) != nil { continue }
            else if lowLabel.range(of: #"\b(grand total|net total|total amount|total payable|amount payable|total sales|total \(?incl|total due|nett?)\b"#, options: .regularExpression) != nil, amt > 0 {
                strongTotal = max(strongTotal ?? 0, amt)
            }
            else if lowLabel.range(of: #"\b(total|total paid|amount paid)\b"#, options: .regularExpression) != nil { if amt > 0 { r.total = max(r.total ?? 0, amt) } }
            else if lowLabel.range(of: #"\b(change|baki)\b"#, options: .regularExpression) != nil { change = amt; continue }
            else if lowLabel.range(of: #"\b(cash|tendered|tunai)\b"#, options: .regularExpression) != nil { tendered = amt; continue }
            else if lowLabel.range(of: #"\b(visa|mastercard|amex|card|auth|approval|paid)\b"#, options: .regularExpression) != nil { continue }
            else if label.filter(\.isLetter).count >= 2, amt > 0, label.split(separator: " ").count <= 9,
                    lowLabel.range(of: #"\b(due date|p\.?o\.?|invoice|receipt (date|number|#))\b"#, options: .regularExpression) == nil {
                // "1  Front and rear brake cables  100.00  100.00": quantity, item, price of one, line amount.
                let unit = amounts.count >= 2 ? amounts[amounts.count - 2] : (qty.map { amt / max($0, 1) })
                r.lines.append(Receipt.Line(name: label, qty: qty, unit: unit, amount: amt))
                r.items.append((label, amt))
            }
        }
        if let st = strongTotal { r.total = st }
        // Cash given minus change is what was paid: settles a total misread or missing.
        if let t = tendered, let c = change, t > c {
            let paid = ((t - c) * 100).rounded() / 100
            if r.total == nil || (r.total.map { abs($0 - paid) > 0.01 && ($0 > t || $0 == 0) } ?? false) { r.total = paid }
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
    private static var layout: [String: [String: CGFloat]] = [:]
    static func rememberHeights(_ text: String, _ h: [String: CGFloat]) {
        memoLock.lock(); defer { memoLock.unlock() }
        if layout.count > 20 { layout.removeAll() }
        layout[text] = h
    }
    static func heights(for text: String) -> [String: CGFloat] {
        memoLock.lock(); defer { memoLock.unlock() }
        return layout[text] ?? [:]
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
    /// Reads like a receipt or invoice: at least two money amounts and a total, tax, paid or card line — and not a
    /// weekly board (day names across the top).
    static func looksLikeReceipt(_ text: String) -> Bool {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        let money = lines.filter { $0.range(of: #"\d[.,]\d{2}\b"#, options: .regularExpression) != nil }.count
        let low = text.lowercased()
        let words = low.range(of: #"\b(total|subtotal|amount|tax|vat|gst|paid|cash|change|visa|mastercard|amex|debit|credit|balance|receipt|invoice)\b"#, options: .regularExpression) != nil
        let days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"].filter { low.range(of: "\\b\($0)\\b", options: .regularExpression) != nil }.count
        return money >= 2 && words && days < 4
    }

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
        else if !s.contains(","), s.range(of: #"^-?\d{1,3}(\.\d{3})+$"#, options: .regularExpression) != nil { s = s.replacingOccurrences(of: ".", with: "") }   // "60.000" → 60000
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
        func cell(_ i: Int) -> String { cells[i].text }
        let ti = candidates.first { cell($0).range(of: titleWords, options: [.regularExpression, .caseInsensitive]) != nil && cell($0).split(separator: " ").count <= 5 }
        c.title = ti.map(cell) ?? ""
        let companyWord = #"\b(inc|llc|ltd|gmbh|corp|co\.|company|group|studio|studios|labs|partners|agency|solutions|technologies|consulting|robotics|systems|bank|university|hospital|clinic|design|media|realty|law|associates|& co)\b"#
        let personLike = #"^[A-Z][a-zA-Z'’.-]+(?: [A-Z][a-zA-Z'’.-]+){1,3}$"#
        var ci = candidates.first { $0 != ti && cell($0).range(of: companyWord, options: [.regularExpression, .caseInsensitive]) != nil }
        if ci == nil { ci = candidates.first { $0 != ti && cell($0) == cell($0).uppercased() && cell($0).count > 3 && cell($0).range(of: personLike, options: .regularExpression) == nil } }
        var companyParts = Set<Int>()
        if let k = ci {
            var name = cell(k); companyParts.insert(k)
            // A company name printed on two lines ("Studio" over "Salford") is one name.
            if let below = candidates.first(where: { cells[$0].row == cells[k].row + 1 && cells[$0].col == cells[k].col && $0 != ti }),
               cell(below).split(separator: " ").count <= 3, cell(below).rangeOfCharacter(from: .decimalDigits) == nil,
               cell(below).range(of: titleWords, options: [.regularExpression, .caseInsensitive]) == nil {
                name += " " + cell(below); companyParts.insert(below)
            }
            c.company = name
        }
        let rest = candidates.filter { $0 != ti && !companyParts.contains($0) }
        c.name = rest.first { cell($0).range(of: personLike, options: .regularExpression) != nil }.map(cell)
            ?? rest.first { cell($0).range(of: #"^[A-Za-z][A-Za-z'’.-]*(?: [A-Za-z][A-Za-z'’.-]*){1,3}$"#, options: .regularExpression) != nil }.map(cell)
            ?? rest.first.map(cell) ?? ""
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

    /// Stock-photo watermarks and print marks — never part of an event.
    static func isWatermark(_ l: String) -> Bool {
        let low = l.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return ["shutterstock", "istock", "getty", "dreamstime", "adobe stock", "alamy", "123rf", "depositphotos", "vector eps", "image id", "©"].contains { low.contains($0) }
    }

    /// Pieces of stock-photo watermarks, however the camera split them.
    static func stripWatermark(_ l: String) -> String {
        l.replacingOccurrences(of: #"(?i)\b\S*(?:utterst|terstoc|dreamstim|istockph|gettyim|depositph|adobestoc|alamy)\S*\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: "  ", options: .regularExpression)
    }

    /// "12 MARCH", "March 12", "Oct 20", "20th October" with no year → that day (the coming one).
    static func monthDay(in text: String, now: Date) -> Date? {
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        let low = text.lowercased()
        let pats = [#"\b(\d{1,2})(?:st|nd|rd|th)?\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\b"#,
                    #"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{1,2})(?:st|nd|rd|th)?\b"#]
        for (i, p) in pats.enumerated() {
            guard let re = try? NSRegularExpression(pattern: p), let m = re.firstMatch(in: low, range: NSRange(low.startIndex..., in: low)) else { continue }
            let ns = low as NSString
            let a = ns.substring(with: m.range(at: 1)), b = ns.substring(with: m.range(at: 2))
            let dayS = i == 0 ? a : b, monS = i == 0 ? b : a
            guard let d = Int(dayS), (1...31).contains(d), let mi = months.firstIndex(of: String(monS.prefix(3))) else { continue }
            let cal = Calendar.current
            var c = cal.dateComponents([.year], from: now); c.month = mi + 1; c.day = d
            guard var date = cal.date(from: c) else { continue }
            if date < cal.startOfDay(for: now), let next = cal.date(byAdding: .year, value: 1, to: date) { date = next }
            return date
        }
        return nil
    }

    private static let eventWords = #"\b(dinner|party|festival|fest|concert|conference|workshop|meetup|meet-up|gala|fair|night|show|class|webinar|seminar|summit|expo|exhibition|tournament|match|game|race|run|walk|market|sale|launch|celebration|ceremony|service|wedding|birthday|reunion|fundraiser|auction|screening|recital|performance|tour|events?|dating|brunch|lunch|breakfast|open house|camp|retreat|talk|lecture)\b"#
    private static let venueWords = #"\b(hall|ballroom|auditorium|center|centre|park|theat(er|re)|stadium|arena|club|hotel|church|temple|school|library|room|gallery|museum|studio|bar|cafe|café|restaurant|garden|plaza|square|pavilion|venue|campus|field|beach)\b"#
    private static let timeRange = #"(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?\s*(?:-|–|—|to|until|till)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)"#
    private static let oneTime = #"\b(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)"#

    /// An event from a poster, flyer or invite. `heights` (each piece of text → its printed height, from the
    /// photo) lets the biggest words become the title, the way a person reads a poster.
    static func event(_ text: String, heights: [String: CGFloat] = [:], now: Date = Date()) -> Event {
        var e = Event()
        // Stock watermarks are read in pieces ("utterstoc", "hutterstock") stuck to real words: cut them out.
        let lines = text.split(whereSeparator: \.isNewline).map { stripWatermark(String($0)).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !isWatermark($0) }
        let flat = lines.map { columns($0).joined(separator: " ") }
        let cal = Calendar.current
        let hasYear = text.range(of: #"\b(19|20)\d{2}\b"#, options: .regularExpression) != nil

        // When: the day from the line that names it; the time (or time range) from wherever it's printed.
        func hm(_ h: String, _ m: String?, _ ap: String?) -> (Int, Int)? {
            guard var hh = Int(h), hh <= 23 else { return nil }
            let mm = Int(m ?? "") ?? 0
            let a = (ap ?? "").lowercased().replacingOccurrences(of: ".", with: "")
            if a == "pm", hh < 12 { hh += 12 }; if a == "am", hh == 12 { hh = 0 }
            return (hh, mm)
        }
        var startHM: (Int, Int)?, endHM: (Int, Int)?
        let joined = flat.joined(separator: "\n")
        if let re = try? NSRegularExpression(pattern: timeRange, options: .caseInsensitive),
           let m = re.firstMatch(in: joined, range: NSRange(joined.startIndex..., in: joined)) {
            func g(_ i: Int) -> String? { Range(m.range(at: i), in: joined).map { String(joined[$0]) } }
            endHM = hm(g(4) ?? "", g(5), g(6))
            startHM = hm(g(1) ?? "", g(2), g(3) ?? g(6))   // "6 - 8pm": the start shares the end's am/pm
        } else if let re = try? NSRegularExpression(pattern: oneTime, options: .caseInsensitive),
                  let m = re.firstMatch(in: joined, range: NSRange(joined.startIndex..., in: joined)) {
            func g(_ i: Int) -> String? { Range(m.range(at: i), in: joined).map { String(joined[$0]) } }
            startHM = hm(g(1) ?? "", g(2), g(3))
        }
        var day: Date?
        var dayLine: Int?
        for (i, l) in flat.enumerated() where !l.lowercased().contains("rsvp") && !l.lowercased().contains("deadline") {
            if let d = dateMatches(in: l).first?.date { day = d; dayLine = i; break }
        }
        if day == nil, let d = dateMatches(in: joined).first?.date { day = d }
        if day == nil, let d = monthDay(in: joined, now: now) { day = d }
        if var d = day {
            // "Saturday Oct 20" with no year is the next one, never one already gone.
            if !hasYear, d < cal.startOfDay(for: now), let next = cal.date(byAdding: .year, value: 1, to: d) { d = next }
            if let t = startHM {
                d = cal.date(bySettingHour: t.0, minute: t.1, second: 0, of: d) ?? d
                e.start = d
                if let et = endHM, var end = cal.date(bySettingHour: et.0, minute: et.1, second: 0, of: d) {
                    if end <= d { end = cal.date(byAdding: .day, value: 1, to: end) ?? end }   // ends after midnight
                    e.end = end
                } else { e.end = d.addingTimeInterval(2 * 3600) }
            } else {
                e.start = d
                let first = dateMatches(in: joined).first
                e.end = d.addingTimeInterval((first?.duration ?? 0) > 0 ? first!.duration : 3600)
            }
        }

        // Where: a labelled place, else a line with a street address, else one that names a venue.
        let labelled = flat.first { $0.range(of: #"^(where|location|venue|place|at)\b[:\s]"#, options: [.regularExpression, .caseInsensitive]) != nil }
        if let l = labelled {
            e.location = l.replacingOccurrences(of: #"^(where|location|venue|place|at)\b[:\s-]*"#, with: "", options: [.regularExpression, .caseInsensitive]).trimmingCharacters(in: .whitespaces)
        } else if let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue),
                  let l = flat.first(where: { det.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }) {
            e.location = l
        } else if let l = flat.first(where: { $0.range(of: venueWords, options: [.regularExpression, .caseInsensitive]) != nil && dateMatches(in: $0).isEmpty }) {
            e.location = l
        }
        if e.location == e.location.uppercased() { e.location = e.location.capitalized }

        // The title: the biggest words on the poster (joined when a title runs over two lines), else the line that
        // names the kind of event, else the first plain line.
        let dated = Set(flat.indices.filter { !dateMatches(in: flat[$0]).isEmpty || flat[$0].range(of: oneTime, options: [.regularExpression, .caseInsensitive]) != nil })
        func plain(_ i: Int) -> Bool {
            let l = flat[i]
            return !dated.contains(i) && l != e.location && l.filter(\.isLetter).count >= 3 && !l.contains("@") && !l.lowercased().contains("www.") && !l.hasSuffix("?")
                && l.range(of: #"^(where|when|tickets?|price|rsvp|please|contact|call)\b"#, options: [.regularExpression, .caseInsensitive]) == nil
        }
        func height(_ l: String) -> CGFloat { heights.filter { l.contains($0.key) || $0.key.contains(l) }.map(\.value).max() ?? 0 }
        if !heights.isEmpty, let tallest = flat.indices.filter(plain).max(by: { height(flat[$0]) < height(flat[$1]) }), height(flat[tallest]) > 0 {
            let top = height(flat[tallest])
            var parts = [flat[tallest]]
            var j = tallest + 1
            while j < flat.count, plain(j), height(flat[j]) >= top * 0.55, parts.count < 3 { parts.append(flat[j]); j += 1 }
            var k = tallest - 1
            while k >= 0, plain(k), height(flat[k]) >= top * 0.75, parts.count < 3 { parts.insert(flat[k], at: 0); k -= 1 }
            e.title = parts.joined(separator: " ")
        } else {
            e.title = flat.indices.filter(plain).first { flat[$0].range(of: eventWords, options: [.regularExpression, .caseInsensitive]) != nil }.map { flat[$0] }
                ?? flat.indices.first(where: plain).map { flat[$0] } ?? lines.first ?? "Event"
        }
        // Poster capitals read as a normal title ("Speed Dating DINNER" → "Speed Dating Dinner").
        e.title = e.title.split(separator: " ").map { w in w.count > 3 && w == w.uppercased() ? w.capitalized : String(w) }.joined(separator: " ")

        // The rest worth keeping with the event: prices, tickets, contact, the details.
        if let link = matches(#"(?:https?://)?(?:www\.)[a-z0-9-]+\.[a-z.]{2,}(?:/\S*)?"#, in: joined, options: .caseInsensitive).first(where: { !isWatermark($0) }) {
            e.url = link.lowercased().hasPrefix("http") ? link : "https://" + link.lowercased()
        }
        // Prices, tickets and how to reach them first; then what the poster says about it.
        var key: [String] = [], more: [String] = []
        for (i, l) in flat.enumerated() where i != dayLine && !e.title.lowercased().contains(l.lowercased()) && l.lowercased() != e.location.lowercased() && !dated.contains(i) {
            let low = l.lowercased()
            let tidy = l == l.uppercased() ? l.prefix(1) + l.dropFirst().lowercased() : l
            if low.range(of: #"[$€£₹]\s?\d|\bfree\b|price|ticket|admission|entry|rsvp|contact|call|@|www\.|dress|bring|parking|doors"#, options: .regularExpression) != nil { key.append(String(tidy)) }
            else if l.split(separator: " ").count >= 4 { more.append(String(tidy)) }
        }
        e.notes = (key + more).prefix(8).joined(separator: "\n")
        return e
    }

    static func ics(_ e: Event) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"; f.timeZone = TimeZone(identifier: "UTC")
        let start = e.start ?? Date(), end = e.end ?? start.addingTimeInterval(3600)
        func esc(_ s: String) -> String { s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: ",", with: "\\,").replacingOccurrences(of: ";", with: "\\;").replacingOccurrences(of: "\n", with: "\\n") }
        return ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Tenzy//Data Grabber//EN", "BEGIN:VEVENT", "UID:\(UUID().uuidString)@tenzy", "DTSTAMP:\(f.string(from: Date()))", "DTSTART:\(f.string(from: start))", "DTEND:\(f.string(from: end))", "SUMMARY:\(esc(e.title))",
                e.location.isEmpty ? nil : "LOCATION:\(esc(e.location))",
                e.notes.isEmpty ? nil : "DESCRIPTION:\(esc(e.notes))",
                e.url.isEmpty ? nil : "URL:\(e.url)",
                "END:VEVENT", "END:VCALENDAR"].compactMap { $0 }.joined(separator: "\r\n")
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

    /// What a table says about itself: columns that are mostly numbers, each one's sum, cells in a number column
    /// that don't read as a number (likely misread), and whether a printed "Total" row matches the rows above it.
    struct TableCheck: Equatable {
        var numberColumns: [Int] = []
        var sums: [Int: Double] = [:]
        var suspect: Set<[Int]> = []                              // [row, column]
        var totals: [(column: Int, printed: Double, added: Double)] = []
        static func == (a: TableCheck, b: TableCheck) -> Bool { a.numberColumns == b.numberColumns && a.sums == b.sums && a.suspect == b.suspect && a.totals.map(\.column) == b.totals.map(\.column) }
        var addsUp: Bool { totals.allSatisfy { abs($0.printed - $0.added) < 0.011 } }
    }

    static func cellNumber(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, t.range(of: #"^[-+]?[$€£₹¥]?\s?-?\d[\d,]*(\.\d+)?%?$"#, options: .regularExpression) != nil else { return nil }
        return Double(t.filter { $0.isNumber || $0 == "." || $0 == "-" })
    }

    static func tableCheck(_ rows: [[String]], header: Bool) -> TableCheck {
        var c = TableCheck()
        let body = Array(rows.dropFirst(header ? 1 : 0).enumerated()).map { (i: $0.offset + (header ? 1 : 0), r: $0.element) }
        let width = rows.map(\.count).max() ?? 0
        func isTotal(_ r: [String]) -> Bool { r.contains { $0.range(of: #"^\s*(grand\s+)?(sub)?total\b"#, options: [.regularExpression, .caseInsensitive]) != nil } }
        for col in 0..<width {
            let cells = body.filter { col < $0.r.count && !$0.r[col].trimmingCharacters(in: .whitespaces).isEmpty }
            guard cells.count >= 2 else { continue }
            let nums = cells.filter { cellNumber($0.r[col]) != nil }
            guard Double(nums.count) >= Double(cells.count) * 0.7 else { continue }
            c.numberColumns.append(col)
            // A cell with a digit in it that still doesn't read as a number is probably a misread ("1O.00", "4S").
            for x in cells where cellNumber(x.r[col]) == nil && x.r[col].contains(where: \.isNumber) && !isTotal(x.r) { c.suspect.insert([x.i, col]) }
            let lines = nums.filter { !isTotal($0.r) }
            let sum = lines.compactMap { cellNumber($0.r[col]) }.reduce(0, +)
            c.sums[col] = sum
            if let t = nums.first(where: { isTotal($0.r) }), let printed = cellNumber(t.r[col]) { c.totals.append((col, printed, sum)) }
        }
        return c
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
    static func dates(in text: String) -> [Date] {
        let found = dateMatches(in: text).map(\.date)
        return found.isEmpty ? printedDates(in: text) : found
    }

    /// Dates printed as numbers ("11/02/2019", "25.12.18", "2019-03-08"), read without the system detector, which
    /// misses some. A first number over 12 means day first; a second over 12 means month first; otherwise the
    /// phone's own order decides. Times and dates that can't exist are skipped.
    static func printedDates(in text: String, dayFirst forced: Bool? = nil) -> [Date] {
        var out: [(Int, Date)] = []
        let cal = Calendar(identifier: .gregorian)
        let dayFirst = forced ?? !(DateFormatter.dateFormat(fromTemplate: "MMdd", options: 0, locale: .current) ?? "MM").hasPrefix("M")
        func make(_ y: Int, _ m: Int, _ d: Int) -> Date? {
            let year = y < 100 ? 2000 + y : y
            guard (1...12).contains(m), (1...31).contains(d), (1990...2100).contains(year) else { return nil }
            let c = DateComponents(calendar: cal, year: year, month: m, day: d, hour: 12)
            guard c.isValidDate(in: cal) else { return nil }
            return cal.date(from: c)
        }
        let ns = text as NSString
        if let re = try? NSRegularExpression(pattern: #"(?<![\d/.-])(\d{4})[/.-](\d{1,2})[/.-](\d{1,2})(?![\d/])"#) {
            for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let n = (1...3).map { Int(ns.substring(with: m.range(at: $0))) ?? 0 }
                if let d = make(n[0], n[1], n[2]) { out.append((m.range.location, d)) }
            }
        }
        if let re = try? NSRegularExpression(pattern: #"(?<![\d/.-])(\d{1,2})[/.-](\d{1,2})[/.-](\d{4}|\d{2})(?![\d/])"#) {
            for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let n = (1...3).map { Int(ns.substring(with: m.range(at: $0))) ?? 0 }
                let dm = n[0] > 12 || (n[1] <= 12 && dayFirst)
                if let d = dm ? make(n[2], n[1], n[0]) : make(n[2], n[0], n[1]) { out.append((m.range.location, d)) }
            }
        }
        return out.sorted { $0.0 < $1.0 }.map(\.1)
    }
    /// true when some numeric date on the page can only be day-first (a first number over 12), false when one can
    /// only be month-first, nil when nothing settles it.
    static func numericDateOrder(in text: String) -> Bool? {
        guard let re = try? NSRegularExpression(pattern: #"(?<![\d/.-])(\d{1,2})[/.-](\d{1,2})[/.-](\d{4}|\d{2})(?![\d/])"#) else { return nil }
        let ns = text as NSString
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let a = Int(ns.substring(with: m.range(at: 1))) ?? 0, b = Int(ns.substring(with: m.range(at: 2))) ?? 0
            if a > 12, b <= 12 { return true }
            if b > 12, a <= 12 { return false }
        }
        return nil
    }

    /// Dates the system finds that really name a day ("5 Mar 2018", "March 5"): a bare time like the phone's
    /// clock in a screenshot ("9:32") is not a date.
    static func calendarDates(in text: String) -> [Date] {
        guard let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return [] }
        let ns = text as NSString
        return det.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let piece = ns.substring(with: m.range).lowercased()
            let names = piece.range(of: #"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\b|\d{1,4}[/.-]\d{1,2}"#, options: .regularExpression) != nil
            return names ? m.date : nil
        }
    }

    private static func dateMatches(in text: String) -> [(date: Date, duration: TimeInterval)] {
        guard let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return [] }
        return det.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { m in m.date.map { ($0, m.duration) } }
    }
}
