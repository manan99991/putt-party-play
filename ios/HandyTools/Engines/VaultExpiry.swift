import Foundation
import UserNotifications

/// Documents in the Vault that run out: what the document is and when it expires, read from its own photo, and a
/// reminder 6 months and 1 month before (many countries won't let you in on a passport with under 6 months left).
/// The reminder never shows what the document is on the lock screen.
enum VaultExpiry {
    static let kinds: [(word: String, name: String)] = [
        ("passport", "Passport"), ("driver", "Driving licence"), ("driving licen", "Driving licence"), ("visa", "Visa"),
        ("residence permit", "Residence permit"), ("identity card", "ID card"), ("national id", "ID card"),
        ("insurance", "Insurance card"), ("membership", "Membership card"), ("permit", "Permit"),
    ]

    /// What it is and when it expires, from the text on the document. The date comes from an "expiry / expires /
    /// valid until / date of expiry / exp" line, or failing that the latest future date on it.
    static func read(_ text: String, now: Date = Date()) -> (name: String?, expires: Date?) {
        let low = text.lowercased()
        let name = kinds.first { low.contains($0.word) }?.name
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        var date: Date?
        for (i, l) in lines.enumerated() where l.range(of: #"(?i)\b(expir\w*|valid (until|thru|through|to)|date of expiry|exp\.?|end date|renew by)\b"#, options: .regularExpression) != nil {
            // The date is often on the same line, or the line below the label.
            let here = l + " " + (i + 1 < lines.count ? lines[i + 1] : "")
            date = DataGrab.printedDates(in: here, dayFirst: true).first ?? DataGrab.calendarDates(in: here).first ?? monthYear(here)
            if date != nil { break }
        }
        if date == nil {
            date = (DataGrab.printedDates(in: text, dayFirst: true) + DataGrab.calendarDates(in: text)).filter { $0 > now }.max()
        }
        return (name, date)
    }

    /// "EXP 08/29" or "08/2029" on cards: the last day of that month.
    static func monthYear(_ s: String) -> Date? {
        guard let r = s.range(of: #"\b(0?[1-9]|1[0-2])\s?/\s?(\d{4}|\d{2})\b"#, options: .regularExpression) else { return nil }
        let parts = s[r].split(separator: "/").map { Int($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
        guard parts.count == 2 else { return nil }
        let year = parts[1] < 100 ? 2000 + parts[1] : parts[1]
        let cal = Calendar(identifier: .gregorian)
        guard let first = cal.date(from: DateComponents(year: year, month: parts[0], day: 1)),
              let last = cal.date(byAdding: DateComponents(month: 1, day: -1), to: first) else { return nil }
        return last
    }

    /// The reminder moments that are still ahead: 6 months before and 1 month before, at 9:00.
    static func reminders(for expires: Date, now: Date = Date(), cal: Calendar = .current) -> [(months: Int, at: Date)] {
        [6, 1].compactMap { m in
            guard let d = cal.date(byAdding: .month, value: -m, to: expires), let at = cal.date(bySettingHour: 9, minute: 0, second: 0, of: d), at > now else { return nil }
            return (m, at)
        }
    }

    static func schedule(id: UUID, expires: Date?) {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: ["vault-exp-\(id)-6", "vault-exp-\(id)-1"])
        guard let expires else { return }
        let f = DateFormatter(); f.dateStyle = .long
        for r in reminders(for: expires) {
            let n = UNMutableNotificationContent()
            n.title = r.months == 6 ? "A document expires in 6 months" : "A document expires next month"
            n.body = "Something in your Vault runs out on \(f.string(from: expires)). Open Vault to see what — and renew it in time."
            n.sound = .default; n.userInfo = ["open": "vault"]
            c.add(UNNotificationRequest(identifier: "vault-exp-\(id)-\(r.months)", content: n,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: r.at), repeats: false)))
        }
    }
}


/// The travel pack: the papers you need at a border or a check-in desk, together and offline, with what to fix
/// before you go. Passports, visas, permits, travel insurance, licences, tickets and bookings are in it by what they
/// are; anything else can be added, and anything taken out.
enum TravelPack {
    static let words = ["passport", "visa", "permit", "insurance", "licence", "license", "boarding", "ticket", "booking",
                        "itinerary", "reservation", "vaccin", "yellow fever", "id card", "identity"]

    static func belongs(title: String, expires: Date?, chosen: Bool?) -> Bool {
        if let chosen { return chosen }
        let t = title.lowercased()
        return words.contains { t.contains($0) }
    }

    /// What needs doing before a trip, plain: a passport under 6 months, anything already expired or running out soon.
    static func warning(title: String, expires: Date?, now: Date = Date()) -> String? {
        guard let exp = expires else { return nil }
        if exp < now { return "Expired — renew it before you travel." }
        let months = Calendar.current.dateComponents([.month], from: now, to: exp).month ?? 0
        if title.lowercased().contains("passport"), months < 6 { return "Under 6 months left — many countries won't let you in. Renew it first." }
        if months < 1 { return "Runs out within a month." }
        return nil
    }
}
