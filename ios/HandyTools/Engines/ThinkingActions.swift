import Foundation

/// The spine of the thinking tools' "Act on it" layer: given a single task line, work out which of the
/// phone's apps it belongs to — Reminders, Calendar, Maps, a phone call — and pull out the bits each needs
/// (the place, the number). Pure and deterministic so it is unit-tested off-device; the Android twin
/// (`ThinkingActions.kt`) uses the SAME rules, so both platforms agree on every task.
///
/// Deliberately self-contained (its own date/place/phone detection, not each platform's different parser)
/// so the two platforms never disagree, and conservative + additive: a task only picks up Calendar when it
/// has a date, Maps when it names a real place, Call when it has a number or a call cue. It never
/// dead-ends — every task is at least a reminder.
enum ThinkingActions {
    /// A built-in app a task can flow into. `.calendar`/`.reminder` are written directly (with permission);
    /// `.maps` opens Maps pre-filled; `.call` offers a one-tap dial when a number is present.
    enum Kind: String, Equatable { case calendar, reminder, maps, call }

    struct Plan: Equatable {
        /// The apps this task flows into, in the order the UI should show them. Always contains `.reminder`.
        var kinds: [Kind]
        /// True when the task carries a date/deadline — the signal to flag it (Calendar + a dated reminder).
        var isDated: Bool
        /// A confident place in the task, for a Maps hand-off. Nil when there is none.
        var place: String?
        /// A phone number found in the task, for a one-tap call. Nil when there is none.
        var phone: String?
        /// True when the task reads like a call/text even without a number ("call the dentist").
        var isCall: Bool
    }

    /// Words that mark a task as a phone/text action even when no number is written in it.
    private static let callCues: Set<String> = ["call", "phone", "ring", "dial", "text", "callback"]

    /// Place-type words that confirm a capitalised phrase after "at/to/from/in" names a real location.
    private static let placeWords: Set<String> = [
        "street", "st", "ave", "avenue", "road", "rd", "blvd", "boulevard", "lane", "ln", "drive", "dr",
        "court", "ct", "way", "place", "plaza", "square", "clinic", "hospital", "center", "centre", "mall",
        "park", "station", "airport", "hotel", "motel", "cafe", "restaurant", "store", "shop", "market",
        "gym", "school", "college", "university", "library", "church", "temple", "office", "bank",
        "pharmacy", "dmv", "salon", "studio", "arena", "stadium", "theater", "theatre", "museum", "gallery",
    ]
    /// Everyday places people name without a place-type word, matched whole-word.
    private static let knownPlaces: [String] = [
        "costco", "target", "walmart", "aldi", "kroger", "safeway", "cvs", "walgreens", "ikea",
        "starbucks", "jewel", "jewel-osco", "trader joe's", "whole foods", "home depot", "lowe's", "lowes",
        "best buy", "sam's club", "the gym", "the office", "the airport", "the bank", "the pharmacy",
        "the dmv", "the post office", "the library", "the park",
    ]

    /// One date/deadline cue regex, kept identical to the Android twin: a clock time, a weekday,
    /// today/tonight/tomorrow, a month, a numeric date, or an "in/by/within/next N days/weeks" phrase.
    static func hasDateCue(_ s: String) -> Bool {
        let pattern = #"(\b\d{1,2}(:\d{2})?\s?(am|pm)\b)"#
            + #"|(\b\d{1,2}:\d{2}\b)"#
            + #"|(\b(mon|tues?|wed(nes)?|thur?s?|fri|sat(ur)?|sun)(day)?\b)"#
            + #"|(\b(today|tonight|tomorrow|tmrw|tmr)\b)"#
            + #"|(\b(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\b)"#
            + #"|(\b\d{1,2}/\d{1,2}\b)"#
            + #"|(\b(in|by|within|next)\s+\d*\s*(day|week|month|hour)s?\b)"#
        return s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// A confident place in a task, or nil. First a capitalised phrase after a locative word that names a
    /// place type ("…from Oak Street Clinic" → "Oak Street Clinic"); otherwise a known everyday place.
    static func placeIn(_ task: String) -> String? {
        let locative = #"\b(?:at|to|from|in)\s+(?:the\s+)?([A-Z][\p{L}'&.\-]*(?:\s+[A-Z][\p{L}'&.\-]*){0,3})"#
        if let phrase = firstGroup(locative, in: task) {
            let tokens = Set(phrase.lowercased().split { !$0.isLetter }.map(String.init))
            if !tokens.isDisjoint(with: placeWords) { return phrase.trimmingCharacters(in: .whitespaces) }
        }
        let low = task.lowercased()
        for k in knownPlaces where low.range(of: #"\b"# + NSRegularExpression.escapedPattern(for: k) + #"\b"#, options: .regularExpression) != nil {
            return k.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
        }
        return nil
    }

    /// The first phone number in a task (10 digits, optional country code), or nil — the whole-word rule
    /// keeps a longer account/card number from being mistaken for one.
    static func phoneIn(_ task: String) -> String? {
        firstMatch(#"(?<!\d)(?:\+?\d{1,3}[\s.\-]?)?(?:\(\d{3}\)|\d{3})[\s.\-]?\d{3}[\s.\-]?\d{4}(?!\d)"#, in: task)?
            .trimmingCharacters(in: .whitespaces)
    }

    /// Read one task line into the apps it belongs to. Order: Calendar (if dated), Reminder (always), Maps
    /// (if a place), Call (if a number or a call cue) — deduped, so each app appears once.
    static func plan(for task: String) -> Plan {
        let trimmed = task.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDated = hasDateCue(trimmed)
        let place = placeIn(trimmed)
        let phone = phoneIn(trimmed)
        let words = Set(trimmed.lowercased().split { !$0.isLetter }.map(String.init))
        let isCall = phone != nil || !words.isDisjoint(with: callCues)

        var kinds: [Kind] = []
        if isDated { kinds.append(.calendar) }
        kinds.append(.reminder)                 // never a dead end — a task is always at least a reminder
        if place != nil { kinds.append(.maps) }
        if isCall { kinds.append(.call) }
        var seen = Set<Kind>()
        kinds = kinds.filter { seen.insert($0).inserted }
        return Plan(kinds: kinds, isDated: isDated, place: place, phone: phone, isCall: isCall)
    }

    /// A `tel:` URL string for a one-tap dial, or nil — digits (and a leading +) only.
    static func telURL(_ phone: String) -> String? {
        let keep = phone.filter { $0.isNumber || $0 == "+" }
        return keep.filter(\.isNumber).count >= 7 ? "tel:" + keep : nil
    }

    /// A Maps directions URL for a place (opens Maps), or nil. Reuses the tuned RoutePlan builder.
    static func mapsURL(_ place: String) -> String? { RoutePlan.appleMaps(place)?.absoluteString }

    /// A one-event .ics calendar payload for a dated task — reuses the Data Grabber's ICS writer, so the
    /// format stays identical to the rest of the app. The caller adds it to the calendar (or shares it).
    static func icsEvent(title: String, due: Date, place: String = "") -> String {
        DataGrab.ics(DataGrab.Event(title: title, start: due, end: nil, location: place))
    }

    /// One .ics holding every dated task as its own event, so "Add to Calendar" adds the whole plan at
    /// once. Same event format as the rest of the app. Pure and testable.
    static func icsCalendar(_ events: [(title: String, due: Date, place: String)]) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"; f.timeZone = TimeZone(identifier: "UTC")
        var lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Tenzy//Thinking//EN"]
        for e in events {
            lines += ["BEGIN:VEVENT", "UID:\(UUID().uuidString)@tenzy", "DTSTAMP:\(f.string(from: Date()))",
                      "DTSTART:\(f.string(from: e.due))", "DTEND:\(f.string(from: e.due.addingTimeInterval(3600)))",
                      "SUMMARY:\(e.title)"]
            if !e.place.isEmpty { lines.append("LOCATION:\(e.place.replacingOccurrences(of: ",", with: "\\,"))") }
            lines.append("END:VEVENT")
        }
        lines.append("END:VCALENDAR")
        return lines.joined(separator: "\r\n")
    }

    /// Weekday words → `Calendar.component(.weekday)` numbers (Sunday = 1 … Saturday = 7).
    private static let weekdays: [String: Int] = [
        "sunday": 1, "sun": 1, "monday": 2, "mon": 2, "tuesday": 3, "tues": 3, "tue": 3,
        "wednesday": 4, "weds": 4, "wed": 4, "thursday": 5, "thurs": 5, "thur": 5, "thu": 5,
        "friday": 6, "fri": 6, "saturday": 7, "sat": 7,
    ]

    /// Turn a task into the concrete moment it is due, or nil when it carries no date. Deterministic given
    /// `now` and `calendar` (the tests pin both). Reads a clock time ("2pm", "9:30am"), a day anchor
    /// (today/tonight/tomorrow, a weekday → its next occurrence, "in N days/weeks", "next week"), and
    /// combines them; a day with no clock time defaults to 9am (tonight → 8pm); a time today that has
    /// already passed rolls to tomorrow. Same rules as the Android twin.
    static func dueDate(from task: String, now: Date, calendar: Calendar = .current) -> Date? {
        let t = task.lowercased()
        // Time of day.
        var hour: Int? = nil; var minute = 0
        if let g = groups(#"\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b"#, in: t), let h = Int(g[1]) {
            hour = (h % 12) + (g[3] == "pm" ? 12 : 0); minute = Int(g[2]) ?? 0
        } else if let g = groups(#"\b(\d{1,2}):(\d{2})\b"#, in: t), let h = Int(g[1]) {
            hour = h; minute = Int(g[2]) ?? 0
        }
        // Day anchor.
        var offset: Int? = nil; var tonight = false
        func has(_ p: String) -> Bool { t.range(of: p, options: [.regularExpression]) != nil }
        if has(#"\btonight\b"#) { offset = 0; tonight = true }
        else if has(#"\btoday\b"#) { offset = 0 }
        else if has(#"\b(tomorrow|tmrw|tmr)\b"#) { offset = 1 }
        else if let g = groups(#"\bin\s+(\d+)\s+(day|week)s?\b"#, in: t), let n = Int(g[1]) {
            offset = n * (g[2] == "week" ? 7 : 1)
        } else if has(#"\bnext week\b"#) { offset = 7 }
        else if let wd = weekdays.first(where: { has(#"\b"# + $0.key + #"\b"#) })?.value {
            let cur = calendar.component(.weekday, from: now)
            let d = ((wd - cur) % 7 + 7) % 7
            offset = d == 0 ? 7 : d
        }
        guard let off = offset ?? (hour != nil ? 0 : nil) else { return nil }

        guard let shifted = calendar.date(byAdding: .day, value: off, to: now) else { return nil }
        var comps = calendar.dateComponents([.year, .month, .day], from: shifted)
        comps.hour = hour ?? (tonight ? 20 : 9)
        comps.minute = hour == nil ? 0 : minute
        guard var res = calendar.date(from: comps) else { return nil }
        if off == 0, hour != nil, res < now, !has(#"\btoday\b|\btonight\b"#) {
            res = calendar.date(byAdding: .day, value: 1, to: res) ?? res
        }
        return res
    }

    // MARK: - tiny regex helpers
    private static func groups(_ pattern: String, in s: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        let ns = s as NSString
        return (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i); return r.location == NSNotFound ? "" : ns.substring(with: r)
        }
    }
    private static func firstMatch(_ pattern: String, in s: String) -> String? {
        guard let r = s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return String(s[r])
    }
    private static func firstGroup(_ pattern: String, in s: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1 else { return nil }
        let r = m.range(at: 1)
        return r.location == NSNotFound ? nil : ns.substring(with: r)
    }
}
