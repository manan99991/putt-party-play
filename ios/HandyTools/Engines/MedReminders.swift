import Foundation
import UserNotifications

/// Medication reminders — private, on device. Each medicine has a schedule (set times every day, set
/// times on chosen weekdays, or every N hours within waking hours), an optional start and end date, and
/// an optional follow-up ("refill / see the doctor in 3 months"). Reminders arrive with "Taken" and
/// "Snooze 10 min" buttons; every dose is logged so the screen shows what's done today and this week.
///
/// iPhone allows an app 64 scheduled alerts at once, so open-ended schedules use repeating alerts (one
/// per time, or per time-and-weekday), and dated ones (start later / end on a date) are scheduled two
/// weeks ahead and topped up every time Tenzy opens. A reminder tool — not medical advice.
struct TimeOfDay: Codable, Hashable, Comparable {
    var hour: Int
    var minute: Int
    static func < (a: TimeOfDay, b: TimeOfDay) -> Bool { (a.hour, a.minute) < (b.hour, b.minute) }
    var label: String {
        let d = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return d.formatted(date: .omitted, time: .shortened)
    }
}

struct Med: Identifiable, Codable, Equatable {
    enum Pattern: String, Codable, CaseIterable { case daily, weekdays, everyHours }

    var id = UUID()
    var name: String = ""
    var dose: String = ""            // "1 tablet", "5 ml"
    var note: String = ""            // "with food"
    var pattern: Pattern = .daily
    var times: [TimeOfDay] = [TimeOfDay(hour: 8, minute: 0)]
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]          // Calendar weekday: 1 = Sunday … 7 = Saturday
    var everyHours: Int = 8
    var firstHour: Int = 8
    var lastHour: Int = 22
    var start: Date = Calendar.current.startOfDay(for: Date())
    var end: Date?
    var followUp: Date?
    var followUpNote: String = "Refill or check in with your doctor"
    var paused = false
    // Optional pill count (optional so medicines saved before this still load): how many are left, how many
    // each dose uses, and the count at which to say "time to refill".
    var supply: Int?
    var perDose: Int?
    var refillAt: Int?
}

struct DoseLog: Codable, Identifiable, Equatable {
    var id = UUID()
    var medID: UUID
    var scheduled: Date
    var taken: Date?
}

enum MedSchedule {
    static let category = "MED"
    static let takenAction = "MED_TAKEN"
    static let snoozeAction = "MED_SNOOZE"
    /// Leave room under iPhone's 64 for Tenzy's other reminders.
    static let budget = 56
    static let lookaheadDays = 14

    /// The clock times a med is due on any day it's due.
    static func clockTimes(_ m: Med) -> [TimeOfDay] {
        switch m.pattern {
        case .daily, .weekdays:
            return Array(Set(m.times)).sorted()
        case .everyHours:
            let step = max(1, min(24, m.everyHours))
            let last = m.lastHour >= m.firstHour ? m.lastHour : m.firstHour
            return stride(from: m.firstHour, through: last, by: step).map { TimeOfDay(hour: $0 % 24, minute: 0) }
        }
    }

    /// Is the med due at all on `day`?
    static func isDue(_ m: Med, on day: Date, cal: Calendar = .current) -> Bool {
        guard !m.paused else { return false }
        let d = cal.startOfDay(for: day)
        if d < cal.startOfDay(for: m.start) { return false }
        if let e = m.end, d > cal.startOfDay(for: e) { return false }
        if m.pattern == .weekdays { return m.weekdays.contains(cal.component(.weekday, from: d)) }
        return true
    }

    /// Every dose of `m` on `day`, as exact dates.
    static func doses(_ m: Med, on day: Date, cal: Calendar = .current) -> [Date] {
        guard isDue(m, on: day, cal: cal) else { return [] }
        return clockTimes(m).compactMap { cal.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: day) }
    }

    /// Today's doses across all meds, in time order.
    static func today(_ meds: [Med], now: Date = Date(), cal: Calendar = .current) -> [(med: Med, at: Date)] {
        meds.flatMap { m in doses(m, on: now, cal: cal).map { (m, $0) } }.sorted { $0.at < $1.at }
    }

    /// What should be scheduled with the system, in priority order (soonest first), within the budget.
    struct Plan: Equatable {
        let id: String
        let medID: UUID
        let title: String
        let body: String
        let components: DateComponents
        let repeats: Bool
        let at: Date?         // for one-off alerts
    }

    static func plans(_ meds: [Med], now: Date = Date(), cal: Calendar = .current) -> (plans: [Plan], dropped: Int) {
        var all: [Plan] = []
        for m in meds where !m.paused && !m.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let title = "Time for \(m.name)"
            let body = [m.dose, m.note].filter { !$0.isEmpty }.joined(separator: " · ")
            let openEnded = m.end == nil && cal.startOfDay(for: m.start) <= cal.startOfDay(for: now)
            if openEnded {
                for t in clockTimes(m) {
                    if m.pattern == .weekdays {
                        for wd in m.weekdays.sorted() {
                            all.append(Plan(id: "med-\(m.id.uuidString)-w\(wd)-\(t.hour)-\(t.minute)", medID: m.id, title: title,
                                            body: body, components: DateComponents(hour: t.hour, minute: t.minute, weekday: wd),
                                            repeats: true, at: nil))
                        }
                    } else {
                        all.append(Plan(id: "med-\(m.id.uuidString)-d-\(t.hour)-\(t.minute)", medID: m.id, title: title, body: body,
                                        components: DateComponents(hour: t.hour, minute: t.minute), repeats: true, at: nil))
                    }
                }
            } else {
                for offset in 0..<lookaheadDays {
                    guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)) else { continue }
                    for at in doses(m, on: day, cal: cal) where at > now {
                        all.append(Plan(id: "med-\(m.id.uuidString)-o\(Int(at.timeIntervalSince1970))", medID: m.id, title: title,
                                        body: body, components: cal.dateComponents([.year, .month, .day, .hour, .minute], from: at),
                                        repeats: false, at: at))
                    }
                }
            }
            if let f = m.followUp, f > now {
                let at = cal.date(bySettingHour: 10, minute: 0, second: 0, of: f) ?? f
                all.append(Plan(id: "med-\(m.id.uuidString)-follow", medID: m.id, title: "\(m.name): \(m.followUpNote)",
                                body: "The follow-up you set in Tenzy.", components: cal.dateComponents([.year, .month, .day, .hour, .minute], from: at),
                                repeats: false, at: at))
            }
        }
        // Soonest first: repeating alerts fire at least weekly, so they outrank far-off one-offs.
        let soon = cal.date(byAdding: .day, value: 7, to: now) ?? now
        all.sort { ($0.at ?? soon) < ($1.at ?? soon) }
        let kept = Array(all.prefix(budget))
        return (kept, all.count - kept.count)
    }

    // MARK: - Pill count

    /// Doses a week, from the schedule (a "some days" medicine counts only its days).
    static func dosesPerWeek(_ m: Med) -> Int {
        clockTimes(m).count * (m.pattern == .weekdays ? m.weekdays.count : 7)
    }
    /// Roughly how many days the pills last, or nil when not counting.
    static func daysLeft(_ m: Med) -> Int? {
        guard let left = m.supply else { return nil }
        let perDay = Double(dosesPerWeek(m) * max(1, m.perDose ?? 1)) / 7
        return perDay > 0 ? Int((Double(left) / perDay).rounded(.down)) : nil
    }
    /// The count after a dose is logged (+1 dose back when it's un-logged). Never below zero.
    static func counted(_ m: Med, taken: Bool) -> Med {
        var x = m
        guard let left = m.supply else { return x }
        let n = max(1, m.perDose ?? 1)
        x.supply = max(0, taken ? left - n : left + n)
        return x
    }
    /// True only on the dose that takes the count down to the refill point — so the alert comes once, not every dose.
    static func crossedRefill(from old: Med, to new: Med) -> Bool {
        guard let a = old.supply, let b = new.supply else { return false }
        let at = old.refillAt ?? 7
        return a > at && b <= at
    }
    static func refillMessage(_ m: Med) -> (title: String, body: String) {
        let left = m.supply ?? 0
        let days = daysLeft(m).map { $0 <= 0 ? " That's less than a day." : " That's about \($0) day\($0 == 1 ? "" : "s")." } ?? ""
        return ("Time to refill \(m.name)", "\(left) left.\(days) Order more or ask your pharmacy, then update the count in Tenzy.")
    }
    static func postRefill(_ m: Med) {
        let msg = refillMessage(m)
        let c = UNMutableNotificationContent()
        c.title = msg.title; c.body = msg.body; c.sound = .default
        c.userInfo = ["open": "medreminder"]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "medrefill-\(m.id.uuidString)", content: c, trigger: nil))
    }

    /// "Mon, Wed, Fri at 8:00 AM and 8:00 PM" — plain words for the schedule.
    static func summary(_ m: Med) -> String {
        let times = MedSchedule.clockTimes(m).map(\.label)
        let timeText = times.count <= 4 ? times.joined(separator: ", ") : "\(times.count) times a day"
        var s: String
        switch m.pattern {
        case .daily: s = "Every day at \(timeText)"
        case .everyHours: s = "Every \(m.everyHours) h, \(timeText)"
        case .weekdays:
            let names = [2, 3, 4, 5, 6, 7, 1].filter { m.weekdays.contains($0) }.map { Calendar.current.shortWeekdaySymbols[$0 - 1] }
            s = "\(names.joined(separator: ", ")) at \(timeText)"
        }
        if let e = m.end { s += " · until \(e.formatted(date: .abbreviated, time: .omitted))" }
        if let f = m.followUp { s += " · follow-up \(f.formatted(date: .abbreviated, time: .omitted))" }
        if let left = m.supply { s += " · \(left) left" + (daysLeft(m).map { " (about \($0) d)" } ?? "") }
        return s
    }

    // MARK: - System scheduling

    static func registerCategory() -> UNNotificationCategory {
        UNNotificationCategory(identifier: category,
                               actions: [UNNotificationAction(identifier: takenAction, title: "Taken ✓", options: []),
                                         UNNotificationAction(identifier: snoozeAction, title: "Snooze 10 min", options: [])],
                               intentIdentifiers: [], options: [])
    }

    /// Replace every Tenzy med alert with `plans`.
    static func apply(_ plans: [Plan]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix("med-") && !$0.hasPrefix("med-snooze") }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for p in plans {
                let c = UNMutableNotificationContent()
                c.title = p.title
                c.body = p.body
                c.sound = .default
                c.categoryIdentifier = category
                c.userInfo = ["med": p.medID.uuidString]
                let trigger = UNCalendarNotificationTrigger(dateMatching: p.components, repeats: p.repeats)
                center.add(UNNotificationRequest(identifier: p.id, content: c, trigger: trigger))
            }
        }
    }

    static func snooze(_ content: UNNotificationContent, minutes: Int = 10) {
        let c = (content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "med-snooze-\(UUID().uuidString)", content: c, trigger: trigger))
    }
}

/// The meds and the dose log, saved privately in the app's own storage.
@MainActor
final class MedStore: ObservableObject {
    static let shared = MedStore()
    @Published private(set) var meds: [Med] = []
    @Published private(set) var log: [DoseLog] = []
    @Published private(set) var droppedAlerts = 0

    private struct Saved: Codable { var meds: [Med]; var log: [DoseLog] }
    private static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("tenzy-meds.json")
    }

    init() {
        if let d = try? Data(contentsOf: Self.url), let s = try? JSONDecoder().decode(Saved.self, from: d) {
            meds = s.meds; log = s.log
        }
    }

    func save(_ m: Med) {
        if let i = meds.firstIndex(where: { $0.id == m.id }) { meds[i] = m } else { meds.append(m) }
        persist(); reschedule()
    }

    func delete(_ m: Med) {
        meds.removeAll { $0.id == m.id }
        log.removeAll { $0.medID == m.id }
        persist(); reschedule()
    }

    func togglePaused(_ m: Med) {
        guard let i = meds.firstIndex(where: { $0.id == m.id }) else { return }
        meds[i].paused.toggle(); persist(); reschedule()
    }

    func isTaken(_ m: Med, at: Date) -> Bool {
        log.contains { $0.medID == m.id && abs($0.scheduled.timeIntervalSince(at)) < 60 && $0.taken != nil }
    }

    func setTaken(_ m: Med, at: Date, _ taken: Bool) {
        // Count pills only when the logged state really changes (a second tap on Taken doesn't take two).
        if isTaken(m, at: at) != taken, let i = meds.firstIndex(where: { $0.id == m.id }), meds[i].supply != nil {
            let before = meds[i]
            meds[i] = MedSchedule.counted(before, taken: taken)
            if MedSchedule.crossedRefill(from: before, to: meds[i]) {
                let after = meds[i]
                Task { if await NotifyPermission.state() == .allowed { MedSchedule.postRefill(after) } }
            }
        }
        log.removeAll { $0.medID == m.id && abs($0.scheduled.timeIntervalSince(at)) < 60 }
        if taken { log.append(DoseLog(medID: m.id, scheduled: at, taken: Date())) }
        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        log.removeAll { $0.scheduled < cutoff }
        persist()
    }

    /// From a notification's "Taken" button: log the dose nearest to now.
    func takenFromAlert(medID: UUID, now: Date = Date()) {
        guard let m = meds.first(where: { $0.id == medID }) else { return }
        let nearest = MedSchedule.doses(m, on: now).min { abs($0.timeIntervalSince(now)) < abs($1.timeIntervalSince(now)) } ?? now
        setTaken(m, at: nearest, true)
    }

    /// Doses taken vs. due over the last 7 days (up to now).
    func week(now: Date = Date()) -> (taken: Int, due: Int) {
        let cal = Calendar.current
        var due = 0, taken = 0
        for back in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -back, to: now) else { continue }
            for m in meds { for at in MedSchedule.doses(m, on: day) where at <= now { due += 1; if isTaken(m, at: at) { taken += 1 } } }
        }
        return (taken, due)
    }

    func reschedule() {
        let r = MedSchedule.plans(meds)
        droppedAlerts = r.dropped
        MedSchedule.apply(r.plans)
    }

    private func persist() {
        try? JSONEncoder().encode(Saved(meds: meds, log: log)).write(to: Self.url, options: .completeFileProtection)
    }
}
