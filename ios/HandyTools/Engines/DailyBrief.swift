import Foundation
import UserNotifications
import Contacts

/// Daily brief: one short notification each morning with what matters today — your medicines, letters and
/// bills coming due, birthdays, and one tidy-up nudge — then tap to see it all with the weather and what to wear.
/// It's re-written each time Tenzy opens (and when iPhone gives a background refresh), so it's never stale.
enum DailyBrief {
    static let id = "daily-brief"
    static var on: Bool { UserDefaults.standard.bool(forKey: "brief.on") }
    static var hour: Int { let h = UserDefaults.standard.integer(forKey: "brief.hour"); return h == 0 ? 7 : h }
    static var minute: Int { UserDefaults.standard.integer(forKey: "brief.minute") }

    /// Everything the brief can mention, gathered for one day.
    struct Facts: Equatable {
        var doses: [(name: String, time: Date)] = []
        var due: [(title: String, date: Date, amount: String?)] = []
        var birthdays: [(name: String, today: Bool)] = []
        var screenshots: Int?
        var screenshotLimit: Int?
        var freeGB: Double?
        static func == (a: Facts, b: Facts) -> Bool {
            a.doses.map(\.name) == b.doses.map(\.name) && a.due.map(\.title) == b.due.map(\.title) && a.birthdays.map(\.name) == b.birthdays.map(\.name)
                && a.screenshots == b.screenshots && a.freeGB == b.freeGB
        }
    }

    /// The brief in words: a title, a short body for the notification, and the full lines for the screen.
    static func compose(_ f: Facts, for day: Date, cal: Calendar = .current) -> (title: String, body: String, lines: [String]) {
        var lines: [String] = []
        if !f.doses.isEmpty {
            let times = f.doses.sorted { $0.time < $1.time }.map { "\($0.name) \($0.time.formatted(date: .omitted, time: .shortened))" }
            lines.append("💊 " + (f.doses.count == 1 ? "Medicine: " : "\(f.doses.count) doses: ") + times.prefix(4).joined(separator: ", ") + (times.count > 4 ? "…" : ""))
        }
        for d in f.due.sorted(by: { $0.date < $1.date }).prefix(3) {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: day), to: cal.startOfDay(for: d.date)).day ?? 0
            let when = days < 0 ? "overdue" : days == 0 ? "due today" : days == 1 ? "due tomorrow" : "due in \(days) days"
            lines.append("📄 \(d.title)\(d.amount.map { " (\($0))" } ?? "") — \(when)")
        }
        for b in f.birthdays.prefix(3) { lines.append("🎂 \(b.name)'s birthday \(b.today ? "is today" : "is tomorrow")") }
        if let s = f.screenshots, let lim = f.screenshotLimit, s > lim { lines.append("🧹 \(s) screenshots — tidy up to your \(lim)") }
        else if let g = f.freeGB, g < 5 { lines.append("🧹 Only \(g < 10 ? String(format: "%.1f", g) : String(Int(g))) GB free on your phone") }
        let title = "Your day · " + day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        let body = lines.isEmpty ? "Nothing pressing today. Tap for the weather and what to wear." : lines.prefix(4).joined(separator: "\n")
        return (title, body, lines)
    }

    /// The next time the brief goes out (today if that time hasn't passed yet).
    static func nextFire(after now: Date = Date(), hour: Int, minute: Int, cal: Calendar = .current) -> Date {
        let today = cal.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        return today > now ? today : (cal.date(byAdding: .day, value: 1, to: today) ?? today)
    }

    // MARK: - Gathering (on the phone)

    @MainActor static func gather(for day: Date, cal: Calendar = .current) async -> Facts {
        var f = Facts()
        f.doses = MedSchedule.today(MedStore.shared.meds, now: day, cal: cal).map { ($0.med.name, $0.at) }
        let horizon = cal.date(byAdding: .day, value: 3, to: cal.startOfDay(for: day)) ?? day
        f.due = SortedStore().items.filter { !$0.done }.compactMap { i in i.due.flatMap { $0 <= horizon ? (i.title, $0, i.amount) : nil } }
        if CNContactStore.authorizationStatus(for: .contacts) == .authorized {
            let people = await Task.detached(priority: .utility) { ContactBook.load().people }.value
            for (p, date) in ContactBook.upcoming(people, now: day, limit: 6, cal: cal) {
                if cal.isDate(date, inSameDayAs: day) { f.birthdays.append((p.name, true)) }
                else if let t = cal.date(byAdding: .day, value: 1, to: day), cal.isDate(date, inSameDayAs: t) { f.birthdays.append((p.name, false)) }
            }
        }
        if let rule = AlertStore.rule(.screenshots), rule.on {
            f.screenshotLimit = Int(rule.limit)
            f.screenshots = await Task.detached(priority: .utility) { SmartAlerts.read(.screenshots) }.value.map { Int($0) }
        }
        f.freeGB = await Task.detached(priority: .utility) { SmartAlerts.read(.lowSpace) }.value
        return f
    }

    /// Re-write tomorrow's (or today's) brief with fresh facts. Off → removed.
    @MainActor static func refresh(now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard on, await NotifyPermission.state() == .allowed else { return }
        let fire = nextFire(after: now, hour: hour, minute: minute)
        let m = compose(await gather(for: fire), for: fire)
        let c = UNMutableNotificationContent()
        c.title = m.title; c.body = m.body; c.sound = .default
        c.userInfo = ["open": "brief"]
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        try? await center.add(UNNotificationRequest(identifier: id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }

    /// Today's brief, right now — what tomorrow morning will look like.
    @MainActor static func testRun() async {
        let now = Date()
        let m = compose(await gather(for: now), for: now)
        let c = UNMutableNotificationContent()
        c.title = "Test · " + m.title; c.body = m.body; c.sound = .default
        c.userInfo = ["open": "brief"]
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "brief-test-\(UUID().uuidString)", content: c, trigger: nil))
    }
}
