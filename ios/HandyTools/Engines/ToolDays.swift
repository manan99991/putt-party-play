import Foundation

/// Which days each tool was opened, over the last month — the habit an autorun offer is built on ("you've used Warranty
/// on four days lately: want receipts done for you?"). Only tool ids and day numbers; nothing about what was in them.
enum ToolDays {
    private static let key = "tooldays.v1"
    static let keepDays = 30

    /// The day, counted in the phone's own calendar (midnight to midnight where the person is).
    static func day(_ d: Date, cal: Calendar = .current) -> Int {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        let utc = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "UTC"), year: c.year, month: c.month, day: c.day).date
        return Int((utc ?? d).timeIntervalSince1970 / 86_400)
    }

    /// Pure: the log with today added for `tool`, and anything older than a month gone.
    static func noted(_ log: [String: [Int]], tool: String, today: Int) -> [String: [Int]] {
        var out = log.mapValues { $0.filter { $0 > today - keepDays } }.filter { !$0.value.isEmpty }
        if !(out[tool] ?? []).contains(today) { out[tool, default: []].append(today) }
        return out
    }

    /// Records that a tool was opened today. Cheap to call on every redraw: it writes only once a day per tool.
    static func note(_ tool: String, now: Date = Date()) {
        guard !tool.isEmpty else { return }
        let log = (AppGroup.defaults.dictionary(forKey: key) as? [String: [Int]]) ?? [:]
        let today = day(now)
        guard !(log[tool] ?? []).contains(today) else { return }
        AppGroup.defaults.set(noted(log, tool: tool, today: today), forKey: key)
    }

    /// Every tool's days of use in the last month.
    static func all(now: Date = Date()) -> [String: Set<Int>] {
        let log = (AppGroup.defaults.dictionary(forKey: key) as? [String: [Int]]) ?? [:]
        let today = day(now)
        return log.mapValues { Set($0.filter { $0 > today - keepDays }) }.filter { !$0.value.isEmpty }
    }
}
