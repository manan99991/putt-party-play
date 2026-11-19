import Foundation
import UserNotifications

/// What Sorted keeps after reading a letter: the ways to act on it (call, email, pay link, reference
/// number), the letters you saved with their dates, and a reminder before each one. All on the phone.
enum SortedLetters {
    /// The ways to act on a letter that were printed on it.
    struct Actions: Equatable {
        var phones: [String] = []
        var emails: [String] = []
        var links: [URL] = []
        var reference: String?
        var isEmpty: Bool { phones.isEmpty && emails.isEmpty && links.isEmpty && reference == nil }
    }

    static func actions(in text: String) -> Actions {
        var a = Actions()
        var seenPhones = Set<String>()
        a.phones = DataGrab.phoneNumbers(in: text).filter { seenPhones.insert($0.filter(\.isNumber)).inserted }.prefix(3).map { $0 }
        a.emails = Array(Set(DataGrab.matches(#"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, in: text, options: .caseInsensitive).map { $0.lowercased() })).sorted()
        if let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let urls = det.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap(\.url)
                .filter { $0.scheme == "http" || $0.scheme == "https" }
            var seen = Set<String>()
            a.links = urls.filter { seen.insert($0.absoluteString.lowercased()).inserted }.prefix(3).map { $0 }
        }
        a.reference = reference(in: text)
        return a
    }

    /// "Account 55-2910", "Ref: AB12345", "Invoice # 99812", "Policy number X-77" → the number itself.
    static func reference(in text: String) -> String? {
        let p = #"(?i)\b(?:account|acct|reference|ref|invoice|policy|member|customer|case|claim)\s*(?:no\.?|number|num|#|id)?\s*[:#]?\s*([A-Z0-9][A-Z0-9\-/]{3,24})"#
        guard let re = try? NSRegularExpression(pattern: p),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(m.range(at: 1), in: text) else { return nil }
        let v = String(text[r])
        return v.contains(where: \.isNumber) ? v : nil   // "Account Holder" isn't a number
    }

    /// A letter you kept.
    struct Item: Codable, Identifiable, Equatable {
        var id = UUID()
        var kind: String
        var title: String
        var amount: String?
        var due: Date?
        var summary: String
        var remindDays: Int?          // nil = no reminder; 0 = on the day
        var remindHour = 9
        var done = false
        var added = Date()
    }

    static let remindChoices: [(days: Int?, label: String)] = [(nil, "No reminder"), (0, "On the day"), (1, "Day before"), (3, "3 days before"), (7, "A week before")]

    /// When the reminder fires, or nil when there's no date, no reminder, or that moment has passed.
    static func remindAt(_ i: Item, now: Date = Date(), cal: Calendar = .current) -> Date? {
        guard !i.done, let due = i.due, let days = i.remindDays,
              let day = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: due)),
              let at = cal.date(bySettingHour: i.remindHour, minute: 0, second: 0, of: day), at > now else { return nil }
        return at
    }

    /// Saved letters in the order to deal with them: open ones by date (undated last), then the done ones.
    static func ordered(_ items: [Item]) -> [Item] {
        items.sorted { a, b in
            if a.done != b.done { return !a.done }
            switch (a.due, b.due) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.added > b.added
            }
        }
    }

    static func message(_ i: Item, now: Date = Date(), cal: Calendar = .current) -> (title: String, body: String) {
        let when: String
        if let d = i.due {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: d)).day ?? 0
            when = days <= 0 ? "today" : days == 1 ? "tomorrow" : "in \(days) days"
        } else { when = "soon" }
        let title = "\(i.title) — due \(when)"
        return (title, [i.amount.map { "Amount: \($0)." }, "Tap to see the letter in Tenzy."].compactMap { $0 }.joined(separator: " "))
    }

    // MARK: reminders

    static func schedule(_ i: Item) {
        cancel(i)
        guard let at = remindAt(i) else { return }
        let m = message(i, now: at)
        let c = UNMutableNotificationContent()
        c.title = m.title; c.body = m.body; c.sound = .default
        c.userInfo = ["open": "sorted"]
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: at)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "sorted-\(i.id.uuidString)", content: c,
                                                                     trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }
    static func cancel(_ i: Item) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["sorted-\(i.id.uuidString)"])
    }

    /// Test run: the exact reminder this letter will send, in 5 seconds.
    static func testRun(_ i: Item) async {
        let m = message(i, now: remindAt(i) ?? Date())
        let c = UNMutableNotificationContent()
        c.title = "Test · " + m.title; c.body = m.body; c.sound = .default
        c.userInfo = ["open": "sorted"]
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "sorted-test-\(UUID().uuidString)", content: c,
                                                                                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }
}

/// The saved letters, kept privately in the app's own storage.
@MainActor final class SortedStore: ObservableObject {
    @Published private(set) var items: [SortedLetters.Item] = []
    private static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("tenzy-sorted.json")
    }
    init() {
        if let d = try? Data(contentsOf: Self.url), let v = try? JSONDecoder().decode([SortedLetters.Item].self, from: d) { items = v }
    }
    func save(_ i: SortedLetters.Item) {
        if let k = items.firstIndex(where: { $0.id == i.id }) { items[k] = i } else { items.append(i) }
        SortedLetters.schedule(i); persist()
    }
    func toggleDone(_ i: SortedLetters.Item) {
        var x = i; x.done.toggle(); save(x)
    }
    func delete(_ i: SortedLetters.Item) {
        SortedLetters.cancel(i); items.removeAll { $0.id == i.id }; persist()
    }
    private func persist() {
        try? JSONEncoder().encode(items).write(to: Self.url, options: .completeFileProtection)
    }
}
