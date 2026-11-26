import Foundation

/// "Remind me to call Mum at 6", "remind me every Monday to put the bins out", "remind me in 20 minutes to check the
/// oven", "tomorrow at 9 remind me to pay rent" — a remind-me sentence in the ask box becomes a set reminder in one tap
/// (26 Nov, Manan: reminders that are genuinely easy). Pure: the sentence and the time now go in, the reminder comes
/// out, so every way of saying it is unit-tested. nil when the sentence isn't a reminder.
enum ReminderWords {
    static func isReminder(_ text: String) -> Bool {
        let s = " " + text.lowercased() + " "
        return [" remind me", " reminder to", " reminder for", " set a reminder", " don't let me forget", " dont let me forget"].contains { s.contains($0) }
    }

    static func parse(_ text: String, now: Date = Date(), calendar: Calendar = .current) -> OwnReminder? {
        guard isReminder(text) else { return nil }
        // Matched in lower case; what to be reminded of keeps the person's own capitals ("Call Mum").
        let said = (" " + text.replacingOccurrences(of: "’", with: "'") + " ").replacingOccurrences(of: #"[.!?,;]"#, with: " ", options: .regularExpression)
        let s = said.lowercased()
        var cut: [String] = []                      // the time words found, taken out of what's left to say

        // MARK: repeats
        let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        func dayNumber(_ w: String) -> Int? {
            for (i, n) in dayNames.enumerated() where w.hasPrefix(String(n.prefix(3))) { return i + 1 }
            return nil
        }
        var days: [Int] = []
        var repeats = false
        if let m = first(#" (every|each) (week ?days?|weekday)s? "#, in: s) ?? first(#" (on )?weekdays "#, in: s) {
            repeats = true; days = [2, 3, 4, 5, 6]; cut.append(m)
        } else if let m = first(#" (every|each|on) weekends? "#, in: s) {
            repeats = true; days = [1, 7]; cut.append(m)
        } else if let m = first(#" (every|each) ((sun|mon|tues?|wed(nes)?|thu(rs)?|fri|sat(ur)?)(day)?s?( and |, ?| & )?)+"#, in: s) {
            repeats = true; cut.append(m)
            days = m.split(whereSeparator: { !$0.isLetter }).compactMap { w in ["every", "each", "and"].contains(String(w)) ? nil : dayNumber(String(w)) }
        } else if let m = first(#" on ((sun|mon|tues?|wed(nes)?|thu(rs)?|fri|sat(ur)?)days( and |, ?| & )?)+"#, in: s) {
            repeats = true; cut.append(m)     // "on Mondays" repeats; "on Monday" is once
            days = m.split(whereSeparator: { !$0.isLetter }).compactMap { w in ["on", "and"].contains(String(w)) ? nil : dayNumber(String(w)) }
        } else if let m = first(#" (every|each) (day|morning|evening|night|afternoon) "#, in: s) ?? first(#" daily "#, in: s) {
            repeats = true; cut.append(m)
        }

        // MARK: in N minutes / hours (a one-off from now)
        var exact: Date?
        if let m = first(#" in (an?|one|\d+|a few|a couple of) ?(half an? )?(minutes?|mins?|hours?|hrs?) "#, in: s) {
            cut.append(m)
            let words = m.split(separator: " ").map(String.init)
            let n: Double = words.dropFirst().first.flatMap { Double($0) } ?? (m.contains("few") ? 3 : m.contains("couple") ? 2 : 1)
            let secs = m.contains("hour") || m.contains("hr") ? n * 3600 : n * 60
            exact = now.addingTimeInterval(m.contains("half an hour") ? 1800 : secs)
        } else if let m = first(#" in half an hour "#, in: s) {
            cut.append(m); exact = now.addingTimeInterval(1800)
        }

        // MARK: the clock
        var hour: Int?, minute = 0, meridiem: String?
        if let m = first(#" at (\d{1,2})([:.](\d{2}))? ?(am|pm|a m|p m)? "#, in: s) ?? first(#" (\d{1,2})([:.](\d{2}))? ?(am|pm) "#, in: s) {
            cut.append(m)
            let digits = m.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            hour = digits.first.flatMap(Int.init)
            if digits.count > 1, let mm = Int(digits[1]) { minute = mm }
            if m.contains("pm") || m.contains("p m") { meridiem = "pm" } else if m.contains("am") || m.contains("a m") { meridiem = "am" }
        } else if let m = first(#" at noon | at midday | noon "#, in: s) { cut.append(m); hour = 12 }
        else if let m = first(#" at midnight "#, in: s) { cut.append(m); hour = 0 }

        // MARK: which day, for a one-off
        var dayOffset: Int?
        var onWeekday: Int?
        if let m = first(#" tomorrow "#, in: s) { cut.append(m); dayOffset = 1 }
        else if let m = first(#" (today|tonight) "#, in: s) { if !cut.contains(m) { cut.append(m) }; dayOffset = 0 }
        else if !repeats, let m = first(#" (on |next |this )?(sun|mon|tues?|wed(nes)?|thu(rs)?|fri|sat(ur)?)day "#, in: s) {
            cut.append(m)
            onWeekday = m.split(separator: " ").compactMap { dayNumber(String($0)) }.first
        }

        // Parts of the day: also say which half of the clock a bare "at 7" means.
        var part: String?
        for (words, p) in [(" tonight ", "night"), (" this evening ", "evening"), (" in the evening ", "evening"), (" every evening ", "evening"),
                           (" this morning ", "morning"), (" in the morning ", "morning"), (" every morning ", "morning"),
                           (" this afternoon ", "afternoon"), (" in the afternoon ", "afternoon"), (" every afternoon ", "afternoon"),
                           (" every night ", "night"), (" at night ", "night"),
                           (" tomorrow morning ", "morning"), (" tomorrow afternoon ", "afternoon"), (" tomorrow evening ", "evening"),
                           (" tomorrow night ", "night")] where s.contains(words) {
            part = p; if !cut.contains(words) { cut.append(words) }; break
        }
        if part == nil, let m = first(#" (on |next |this )?(sun|mon|tues?|wed(nes)?|thu(rs)?|fri|sat(ur)?)day (morning|afternoon|evening|night) "#, in: s) {
            part = m.split(separator: " ").last.map(String.init); cut.append(m)    // "Friday evening"
        }
        if var h = hour {
            if meridiem == "pm", h < 12 { h += 12 } else if meridiem == "am", h == 12 { h = 0 }
            else if meridiem == nil, h >= 1, h <= 11 {
                if part == "evening" || part == "night" || part == "afternoon" { h += 12 }
                else if part != "morning" {
                    // A bare "at 6": the next 6 o'clock that's still ahead — but nobody means 1–6 in the morning.
                    if h <= 6 { h += 12 }
                    else if !repeats, exact == nil, (dayOffset ?? 0) == 0, onWeekday == nil {
                        let am = calendar.date(bySettingHour: h, minute: minute, second: 0, of: now) ?? now
                        let pm = calendar.date(bySettingHour: h + 12, minute: minute, second: 0, of: now) ?? now
                        if am <= now && pm > now { h += 12 }
                    }
                }
            }
            hour = min(23, h)
        } else if let p = part {
            hour = ["morning": 8, "afternoon": 15, "evening": 19, "night": 21][p]
        }

        // MARK: what to be reminded of
        var what = said
        for c in cut.sorted(by: { $0.count > $1.count }) { what = what.replacingOccurrences(of: c, with: " ", options: .caseInsensitive) }
        for lead in [" please ", " can you ", " could you ", " hey tenzy ", " tenzy "] { what = what.replacingOccurrences(of: lead, with: " ", options: .caseInsensitive) }
        what = what.replacingOccurrences(of: #" +"#, with: " ", options: .regularExpression)
        for intro in [#"^ ?(set (a|me a) )?reminder (to|for|about|that) "#, #"^ ?(don'?t let me forget) (to )?"#, #"^ ?remind me (to|about|that|of|i need to|i have to) "#,
                      #"^ ?remind me "#, #" (and )?remind me (to|about|that|of) "#, #" (and )?remind me "#] {
            what = what.replacingOccurrences(of: intro, with: " ", options: [.regularExpression, .caseInsensitive])
        }
        what = what.replacingOccurrences(of: #"^ ?(to|about|that) "#, with: " ", options: [.regularExpression, .caseInsensitive])
        what = what.replacingOccurrences(of: #" (at|on|in|by)$"#, with: "", options: [.regularExpression, .caseInsensitive])
        what = what.replacingOccurrences(of: #" +"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        // "my" back to "your" is wrong in a note to yourself; keep the person's own words, capitalised.
        if what.isEmpty { what = "Reminder" }       // "remind me at 7": the time was the whole of it
        what = what.prefix(1).uppercased() + what.dropFirst()

        // MARK: put it together
        var r = OwnReminder(text: what)
        if let exact {
            r.once = true; r.onceAt = exact
            r.schedule.hour = calendar.component(.hour, from: exact); r.schedule.minute = calendar.component(.minute, from: exact)
            return r
        }
        let h = hour ?? 9
        r.schedule.hour = h; r.schedule.minute = minute
        if repeats {
            r.schedule.days = days
            return r
        }
        r.once = true
        var when: Date
        if let off = dayOffset {
            let day = calendar.date(byAdding: .day, value: off, to: now) ?? now
            when = calendar.date(bySettingHour: h, minute: minute, second: 0, of: day) ?? day
            // "Today at 9" said at 10 means tomorrow — never a reminder in the past.
            if when <= now { when = calendar.date(byAdding: .day, value: 1, to: when) ?? when }
        } else if let wd = onWeekday {
            let today = calendar.component(.weekday, from: now)
            var ahead = (wd - today + 7) % 7
            let atToday = calendar.date(bySettingHour: h, minute: minute, second: 0, of: now) ?? now
            if ahead == 0 && atToday <= now { ahead = 7 }
            let day = calendar.date(byAdding: .day, value: ahead, to: now) ?? now
            when = calendar.date(bySettingHour: h, minute: minute, second: 0, of: day) ?? day
        } else {
            when = OwnReminders.next(hour: h, minute: minute, after: now, calendar: calendar)
        }
        r.onceAt = when
        return r
    }

    /// The first match of a pattern, as it appears in the sentence.
    private static func first(_ pattern: String, in s: String) -> String? {
        guard let r = s.range(of: pattern, options: .regularExpression) else { return nil }
        return String(s[r])
    }
}
