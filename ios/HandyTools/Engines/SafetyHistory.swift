import Foundation

/// The Safety hub's last 20 checks, kept in UserDefaults so a tester can tap one to re-run it.
/// Only what was checked and the verdict are stored — nothing leaves the phone.
enum SafetyHistory {
    struct Item: Codable, Identifiable, Equatable {
        var id = UUID()
        let text: String
        let label: String?      // nil = message, "link", "phone", "qr"
        let verdict: String
        let score: Int
        let date: Date
    }

    private static let key = "safety.history"
    static let limit = 20

    static func load() -> [Item] {
        guard let d = UserDefaults.standard.data(forKey: key), let items = try? JSONDecoder().decode([Item].self, from: d) else { return [] }
        return items
    }

    static func save(_ items: [Item]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(items), forKey: key)
    }

    /// Newest first, de-duplicated on the text, capped at `limit`.
    static func adding(_ item: Item, to items: [Item]) -> [Item] {
        var out = items.filter { $0.text != item.text }
        out.insert(item, at: 0)
        out = Array(out.prefix(limit))
        save(out)
        return out
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}

/// The prototype's sample messages for the Safety hub chips.
enum SafetySamples {
    static let scam = "URGENT: Your account will be suspended within 24 hours. Verify at http://paypal.secure-login.top/verify and pay the fee in Apple gift cards. Do not tell anyone."
    static let family = "Hi grandma it's me, I lost my phone this is my new number. I'm in trouble and need $800 for bail, please don't tell mom."
    static let package = "USPS: your package is held. Confirm your details to reschedule delivery: usps-redelivery.info/track"
    static let normal = "Hey, running 10 min late, order me a flat white? Thanks!"
    static let chips: [(String, String)] = [("Scam text", scam), ("Family emergency", family), ("Package", package), ("Normal text", normal)]
}
