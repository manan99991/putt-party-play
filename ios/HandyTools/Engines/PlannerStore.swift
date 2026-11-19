import Foundation
import EventKit
import UserNotifications

/// Tenzy Planner: the tasks and events read off whiteboards, calendars, lists and schedules, kept on the phone
/// so they can be checked, fixed and ticked off — Today, This week and by list — and sent on to Apple
/// Reminders and Calendar in one tap.
@MainActor final class PlannerStore: ObservableObject {
    static let shared = PlannerStore()

    struct Entry: Codable, Identifiable, Equatable {
        var id = UUID()
        var text: String
        var list: String
        var done = false
        var due: Date?
        var hasTime = false
        var person: String?
        var place = ""
        var isEvent = false
        var source = ""
        var added = Date()
    }

    @Published private(set) var entries: [Entry] = []
    private let file: URL

    init(file: URL? = nil) {
        if let file { self.file = file } else {
            let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Planner", isDirectory: true)
            try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
            self.file = d.appendingPathComponent("planner.json")
        }
        entries = (try? JSONDecoder().decode([Entry].self, from: Data(contentsOf: self.file))) ?? []
    }

    private func save() { try? JSONEncoder().encode(entries).write(to: file, options: .completeFileProtection) }

    // MARK: adding

    /// Everything included on a board, as planner entries. People's days become entries named for the person.
    static func entries(from b: Understand.Board, source: String) -> [Entry] {
        var out: [Entry] = []
        for t in b.tasks where t.include && !t.text.isEmpty {
            out.append(Entry(text: t.text, list: t.section.isEmpty ? source : t.section, done: t.done, due: t.due, person: t.person, source: source))
        }
        for e in b.events where e.include {
            out.append(Entry(text: e.title, list: "Events", due: e.date, hasTime: e.hasTime, place: e.place, isEvent: true, source: source))
        }
        let cal = Calendar.current
        for p in b.people {
            let idx = Understand.weekdays.firstIndex(of: p.day.uppercased()).map { ($0 + 1) % 7 + 1 }     // Mon → 2
            let date = idx.flatMap { cal.nextDate(after: cal.startOfDay(for: Date()).addingTimeInterval(-1), matching: DateComponents(weekday: $0), matchingPolicy: .nextTime) }
            out.append(Entry(text: "\(p.person): \(p.what)", list: p.person, due: date, person: p.person, source: source))
        }
        return out
    }

    @discardableResult func add(_ new: [Entry]) -> Int {
        // Skip exact repeats (the same board read twice).
        let fresh = new.filter { n in !entries.contains { $0.text == n.text && $0.list == n.list && $0.due == n.due } }
        entries.append(contentsOf: fresh); save()
        Self.rescheduleMorning(entries)
        return fresh.count
    }

    func toggle(_ e: Entry) { if let i = entries.firstIndex(where: { $0.id == e.id }) { entries[i].done.toggle(); save() } }
    func remove(_ e: Entry) { entries.removeAll { $0.id == e.id }; save() }
    func update(_ e: Entry) { if let i = entries.firstIndex(where: { $0.id == e.id }) { entries[i] = e; save() } }

    // MARK: views of it

    func today(_ now: Date = Date()) -> [Entry] {
        let cal = Calendar.current
        return entries.filter { e in guard let d = e.due else { return false }; return cal.isDate(d, inSameDayAs: now) || (d < cal.startOfDay(for: now) && !e.done) }
            .sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
    }
    func week(_ now: Date = Date()) -> [(day: Date, items: [Entry])] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        return (0..<7).compactMap { i in
            guard let day = cal.date(byAdding: .day, value: i, to: start) else { return nil }
            let items = entries.filter { $0.due.map { cal.isDate($0, inSameDayAs: day) } ?? false }
            return items.isEmpty ? nil : (day, items)
        }
    }
    var lists: [(name: String, items: [Entry])] {
        var order: [String] = []
        for e in entries where !e.isEvent && !order.contains(e.list) { order.append(e.list) }
        return order.map { n in (n, entries.filter { $0.list == n && !$0.isEvent }) }
    }

    // MARK: Apple Reminders and Calendar

    enum SendError: Error { case denied, noList }

    /// Not-done tasks into Apple Reminders, in a list named after the board's section where one exists.
    static func toReminders(_ items: [Entry]) async throws -> Int {
        let store = EKEventStore()
        guard (try? await store.requestFullAccessToReminders()) ?? false else { throw SendError.denied }
        guard let fallback = store.defaultCalendarForNewReminders() else { throw SendError.noList }
        let existing = store.calendars(for: .reminder)
        var n = 0
        for e in items where !e.done && !e.isEvent {
            let r = EKReminder(eventStore: store)
            r.calendar = existing.first { $0.title.caseInsensitiveCompare(e.list) == .orderedSame } ?? fallback
            r.title = e.text
            if let d = e.due {
                r.dueDateComponents = Calendar.current.dateComponents(e.hasTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day], from: d)
                if e.hasTime { r.addAlarm(EKAlarm(absoluteDate: d)) }
            }
            if let p = e.person { r.notes = "For \(p)" }
            try store.save(r, commit: false); n += 1
        }
        try store.commit()
        return n
    }

    /// Dated events into Calendar (write-only access).
    static func toCalendar(_ items: [Entry]) async throws -> Int {
        let store = EKEventStore()
        guard (try? await store.requestWriteOnlyAccessToEvents()) ?? false else { throw SendError.denied }
        guard let cal = store.defaultCalendarForNewEvents else { throw SendError.noList }
        var n = 0
        for e in items where e.isEvent {
            guard let d = e.due else { continue }
            let ev = EKEvent(eventStore: store)
            ev.title = e.text; ev.calendar = cal
            if e.hasTime { ev.startDate = d; ev.endDate = d.addingTimeInterval(3600) }
            else { ev.isAllDay = true; ev.startDate = Calendar.current.startOfDay(for: d); ev.endDate = ev.startDate.addingTimeInterval(86_399) }
            if !e.place.isEmpty { ev.location = e.place }
            try store.save(ev, span: .thisEvent, commit: false); n += 1
        }
        try store.commit()
        return n
    }

    // MARK: morning summary (set once, with a Test run)

    static let morningKey = "planner.morning"
    static var morningOn: Bool { UserDefaults.standard.bool(forKey: morningKey) }

    /// The 8:00 note: how many things are due today, named. Rebuilt whenever the planner changes.
    static func rescheduleMorning(_ all: [Entry]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (0..<7).map { "planner.morning.\($0)" })
        guard morningOn else { return }
        let cal = Calendar.current
        for i in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: i, to: cal.startOfDay(for: Date())),
                  let at = cal.date(bySettingHour: 8, minute: 0, second: 0, of: day), at > Date() else { continue }
            let due = all.filter { !$0.done && ($0.due.map { cal.isDate($0, inSameDayAs: day) } ?? false) }
            guard !due.isEmpty else { continue }
            let c = UNMutableNotificationContent()
            c.title = due.count == 1 ? "1 thing today" : "\(due.count) things today"
            c.body = due.prefix(4).map(\.text).joined(separator: " · ")
            c.sound = .default
            center.add(UNNotificationRequest(identifier: "planner.morning.\(i)", content: c,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: at), repeats: false)))
        }
    }

    static func testMorning(_ all: [Entry]) {
        let today = all.filter { !$0.done && ($0.due.map { Calendar.current.isDateInToday($0) } ?? false) }
        let c = UNMutableNotificationContent()
        c.title = "Test run · " + (today.isEmpty ? "Nothing due today" : "\(today.count) things today")
        c.body = today.isEmpty ? "This is how your 8:00 note will look." : today.prefix(4).map(\.text).joined(separator: " · ")
        c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "planner.test", content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }
}
