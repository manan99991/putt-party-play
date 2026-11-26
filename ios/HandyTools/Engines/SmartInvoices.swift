import Foundation

/// Smart autorun: overdue invoices (25 Nov). Every unpaid invoice past its pay-by day, with how late it is and a
/// reminder email ready — the invoice PDF attached, the client's address filled in, the tone right for how late it
/// is (a friendly nudge, then a firm one, then a final notice). The person reads it and taps Send; Mark paid clears it.
enum SmartInvoices {
    enum Tone: Equatable { case friendly, firm, final }

    static func daysLate(_ d: Invoice.Doc, now: Date = Date(), cal: Calendar = .current) -> Int {
        guard let due = d.due else { return 0 }
        return max(0, cal.dateComponents([.day], from: cal.startOfDay(for: due), to: cal.startOfDay(for: now)).day ?? 0)
    }

    /// Up to a week late is a friendly nudge; up to a month a firm one; after that, a final notice.
    static func tone(daysLate: Int) -> Tone { daysLate <= 7 ? .friendly : daysLate <= 30 ? .firm : .final }

    /// The client's email, if their details on the invoice have one.
    static func email(_ to: String) -> String? {
        to.range(of: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: [.regularExpression, .caseInsensitive]).map { String(to[$0]) }
    }

    /// The reminder, in plain, polite words: subject and body. Amount and number exactly as on the invoice.
    static func reminder(_ d: Invoice.Doc, now: Date = Date(), locale: Locale = .current) -> (subject: String, body: String) {
        let late = daysLate(d, now: now)
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = d.currency; f.locale = locale
        let amount = f.string(from: NSNumber(value: d.total)) ?? String(format: "%.2f", d.total)
        let dueText = d.due.map { $0.formatted(date: .long, time: .omitted) } ?? ""
        let first = d.who.split(separator: " ").first.map(String.init) ?? ""
        let hi = first.isEmpty ? L("Hello,") : String(format: L("Hi %@,"), first)
        let sign = d.from.split(separator: "\n").first.map(String.init) ?? ""
        func t(_ key: String, _ args: CVarArg...) -> String { String(format: L(key), arguments: args) }
        switch tone(daysLate: late) {
        case .friendly:
            return (t("Friendly reminder: invoice %@", d.number),
                    hi + "\n\n" + t("Just a quick reminder that invoice %@ for %@ was due on %@. I've attached it again for convenience.", d.number, amount, dueText)
                    + "\n\n" + L("If it's already on its way, thank you — please ignore this.") + "\n\n" + sign)
        case .firm:
            return (t("Invoice %@ is %d days overdue", d.number, late),
                    hi + "\n\n" + t("Invoice %@ for %@ was due on %@ and is now %d days overdue. Could you let me know when I can expect payment?", d.number, amount, dueText, late)
                    + "\n\n" + L("The invoice is attached.") + "\n\n" + sign)
        case .final:
            return (t("Final notice: invoice %@", d.number),
                    hi + "\n\n" + t("This is a final reminder that invoice %@ for %@, due on %@, is still unpaid after %d days. Please arrange payment this week, or reply to let me know if there's a problem.", d.number, amount, dueText, late)
                    + "\n\n" + L("The invoice is attached.") + "\n\n" + sign)
        }
    }
}
