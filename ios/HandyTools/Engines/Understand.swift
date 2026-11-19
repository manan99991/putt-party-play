import Foundation
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Reads a photo of real-world planning — a whiteboard of lists, a wall calendar with notes and sticky notes,
/// a people-by-day schedule, a fridge to-do list — and returns what a person would: sections, tasks (and which
/// are already done), events on dates with times, and who is doing what on which day.
///
/// Two readers, best first:
///  1. Apple Intelligence on the phone, looking at the photo itself (iOS 27+), with the text the camera read as
///     a hint. It understands handwriting, ticks, crossings-out, sticky notes and grids.
///  2. Text recognition plus layout rules on every other phone: columns, headings, checkboxes and ticks,
///     calendar grids (weekday columns and day numbers), and name-by-day grids.
/// Either way the result is checked (dates must fit the calendar's weekdays, junk is dropped) and every item can
/// be fixed before it goes anywhere.
enum Understand {

    enum Kind: String, Codable { case lists, calendar, people, other }

    struct Item: Identifiable, Equatable, Codable {
        var id = UUID()
        var text: String
        var section: String = ""
        var done = false
        var person: String?
        var due: Date?
        var include = true
    }

    struct Event: Identifiable, Equatable, Codable {
        var id = UUID()
        var title: String
        var date: Date?            // the day (and time, when one is written)
        var hasTime = false
        var place = ""
        var include = true
    }

    struct PersonDay: Identifiable, Equatable, Codable {
        var id = UUID()
        var person: String
        var day: String            // "Mon"…"Sun"
        var what: String
    }

    struct Board: Equatable {
        var kind: Kind = .other
        var sections: [String] = []
        var tasks: [Item] = []
        var events: [Event] = []
        var people: [PersonDay] = []
        var month: DateComponents?      // the month a calendar shows, when worked out
        var byAI = false
        var notes: [String] = []        // plain-words cautions ("Arrows across days can't be read…")
        var isEmpty: Bool { tasks.isEmpty && events.isEmpty && people.isEmpty }
    }

    // MARK: read

    static func read(_ image: UIImage, now: Date = Date()) async -> Board {
        let up = image.normalizedUp()
        let ocr = await Task.detached(priority: .userInitiated) { DocEngine.recognize(up) }.value
        var rules = parse(ocr, now: now)
        #if canImport(FoundationModels)
        if #available(iOS 27.0, *), let ai = await readWithAI(up, ocr: ocr, hint: rules.kind, now: now), !ai.isEmpty {
            var b = ai
            b.notes += rules.notes.filter { !$0.contains("Arrows") }
            return b
        }
        #endif
        rules.notes.append("Read by text recognition. Handwriting can be misread — tap any item to fix it.")
        return rules
    }

    // MARK: rules (every phone)

    static let weekdays = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    static func weekday(_ s: String) -> Int? {
        let t = s.uppercased().trimmingCharacters(in: CharacterSet.letters.inverted)
        guard t.count >= 3 else { return nil }
        let full = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]
        if let i = weekdays.firstIndex(of: String(t.prefix(3))), t.count <= 4 || full[i] == t { return i }
        if t == "TUES" { return 1 }; if t == "THUR" || t == "THURS" { return 3 }
        return nil
    }

    static func parse(_ lines: [DocEngine.OCRLine], now: Date) -> Board {
        let clean = lines.filter { !isJunk($0.text) }
        let heads = clean.filter { weekday($0.text) != nil }
        let distinct = Set(heads.compactMap { weekday($0.text) })
        if distinct.count >= 4 {
            let dayNumbers = clean.filter { dayNumber($0.text) != nil }
            if dayNumbers.count >= 6 { return calendar(clean, heads: heads, now: now) }
            return people(clean, heads: heads)
        }
        return lists(clean, now: now)
    }

    static func isJunk(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.count < 2 { return dayNumber(t) == nil }      // a lone "7" is a calendar day, not noise
        let letters = t.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.count
        if Double(letters) / Double(t.unicodeScalars.count) < 0.4 { return true }
        let low = t.lowercased()
        return ["shutterstock", "www.nipic", "expo", "quartet"].contains { low.contains($0) }
    }

    static func dayNumber(_ s: String) -> Int? {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.count <= 2, let n = Int(t), (1...31).contains(n) else { return nil }
        return n
    }

    // MARK: lists

    static let doneMarks: Set<Character> = ["✓", "✔", "☑", "☒", "✅", "√"]
    static let boxMarks: Set<Character> = ["☐", "□", "◻", "▢", "○", "◯", "•", "·", "-", "–", "—", "*", "■", "▪"]

    /// One item's text without its checkbox, bullet or number, and whether it was ticked.
    static func item(_ raw: String) -> (text: String, done: Bool, boxed: Bool) {
        var s = raw.trimmingCharacters(in: .whitespaces)
        var done = false, boxed = false
        if s.lowercased().hasPrefix("[x]") || s.lowercased().hasPrefix("[✓]") { done = true; boxed = true; s = String(s.dropFirst(3)) }
        else if s.hasPrefix("[ ]") || s.hasPrefix("[]") { boxed = true; s = String(s.drop { $0 == "[" || $0 == "]" || $0 == " " }) }
        while let c = s.first, doneMarks.contains(c) || boxMarks.contains(c) {
            if doneMarks.contains(c) { done = true }
            boxed = true; s.removeFirst(); s = s.trimmingCharacters(in: .whitespaces)
        }
        // A lone "o", "O" or "0" before a word is usually a hand-drawn box.
        if s.count > 3, let f = s.first, "oO0D".contains(f), s.dropFirst().first == " " { boxed = true; s = String(s.dropFirst(2)) }
        if let r = s.range(of: #"^\(?\d{1,2}[.)]\s+"#, options: .regularExpression) { s.removeSubrange(r); boxed = true }
        if let l = s.last, doneMarks.contains(l) { done = true; s.removeLast() }
        return (s.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ":"))), done, boxed)
    }

    /// A heading: short, in capitals or ending in ":" or "!", and not a ticked item.
    static func isHeading(_ raw: String, height: CGFloat, median: CGFloat) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespaces)
        let letters = t.filter(\.isLetter)
        guard letters.count >= 3, t.split(separator: " ").count <= 5 else { return false }
        if let f = t.first, doneMarks.contains(f) || boxMarks.contains(f) { return false }
        let caps = letters == letters.uppercased() && letters != letters.lowercased()
        return caps || t.hasSuffix(":") || (t.hasSuffix("!") && caps) || height > median * 1.6
    }

    /// Group pieces of text into the columns they were written in, left to right, top to bottom in each.
    static func columns(_ lines: [DocEngine.OCRLine]) -> [[DocEngine.OCRLine]] {
        let sorted = lines.sorted { $0.box.minX < $1.box.minX }
        var cols: [[DocEngine.OCRLine]] = []
        for l in sorted {
            if let i = cols.firstIndex(where: { c in c.contains { abs($0.box.minX - l.box.minX) < 0.06 } }) { cols[i].append(l) }
            else { cols.append([l]) }
        }
        // Merge thin columns (one or two stragglers) into the nearest real one.
        let real = cols.filter { $0.count >= 3 }
        if !real.isEmpty {
            for c in cols where c.count < 3 {
                for l in c {
                    let j = real.indices.min { a, b in abs(real[a][0].box.minX - l.box.minX) < abs(real[b][0].box.minX - l.box.minX) }!
                    if let k = cols.firstIndex(where: { $0.first?.box == real[j].first?.box }) { cols[k].append(l) }
                }
            }
            cols = cols.filter { $0.count >= 3 }
        }
        return cols.sorted { ($0.map(\.box.minX).min() ?? 0) < ($1.map(\.box.minX).min() ?? 0) }
                   .map { $0.sorted { $0.box.minY < $1.box.minY } }
    }

    static func lists(_ lines: [DocEngine.OCRLine], now: Date) -> Board {
        var b = Board(kind: .lists)
        let heights = lines.map(\.box.height).sorted()
        let median = heights.isEmpty ? 0 : heights[heights.count / 2]
        for col in columns(lines) {
            var section = ""
            for l in col {
                if isHeading(l.text, height: l.box.height, median: median) {
                    section = l.text.trimmingCharacters(in: CharacterSet(charactersIn: ": ")); b.sections.append(section); continue
                }
                let it = item(l.text)
                guard it.text.filter(\.isLetter).count >= 2 else { continue }
                b.tasks.append(Item(text: it.text, section: section, done: it.done, due: due(in: it.text, now: now)))
            }
        }
        return b
    }

    /// "by Friday", "Fri", "tomorrow", "12/3" in a task → its due date.
    static func due(in s: String, now: Date) -> Date? {
        let low = s.lowercased()
        let cal = Calendar.current
        if low.contains("tomorrow") { return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) }
        if low.contains("today") { return cal.startOfDay(for: now) }
        let names = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        for (i, n) in names.enumerated() where low.range(of: "\\b\(n)[a-z]*\\b", options: .regularExpression) != nil && low.range(of: "\\b(by|on|due|before)\\s+\(n)", options: .regularExpression) != nil {
            return cal.nextDate(after: now, matching: DateComponents(weekday: i + 1), matchingPolicy: .nextTime)
        }
        return nil
    }

    // MARK: calendars

    /// Which month a calendar shows: the one (this month or the next two, or the last) where the day numbers
    /// sit under the right weekdays.
    static func month(for placed: [(day: Int, weekday: Int)], now: Date) -> DateComponents? {
        guard !placed.isEmpty else { return nil }
        let cal = Calendar(identifier: .gregorian)
        var best: (DateComponents, Int)?
        for offset in [0, 1, -1, 2] {
            guard let m = cal.date(byAdding: .month, value: offset, to: now) else { continue }
            let c = cal.dateComponents([.year, .month], from: m)
            let hits = placed.filter { p in
                guard let d = cal.date(from: DateComponents(year: c.year, month: c.month, day: p.day)),
                      cal.component(.month, from: d) == c.month else { return false }
                return (cal.component(.weekday, from: d) + 5) % 7 == p.weekday     // Mon = 0
            }.count
            if hits > (best?.1 ?? 0) { best = (c, hits) }
        }
        guard let b = best, Double(b.1) >= Double(placed.count) * 0.6 else { return nil }
        return b.0
    }

    /// A time written on a calendar: "1930", "900", "7:30pm", "7pm", "19:30".
    static func time(in s: String) -> (hour: Int, minute: Int, range: Range<String.Index>)? {
        if let r = s.range(of: #"\b(\d{1,2})(?::(\d{2}))?\s?(am|pm|a\.m\.|p\.m\.)"#, options: [.regularExpression, .caseInsensitive]) {
            let t = s[r].lowercased()
            let nums = t.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            guard var h = nums.first, h <= 12 else { return nil }
            let m = nums.count > 1 ? nums[1] : 0
            if t.contains("p"), h < 12 { h += 12 }; if t.contains("a"), h == 12 { h = 0 }
            return (h, m, r)
        }
        if let r = s.range(of: #"\b([01]?\d|2[0-3]):([0-5]\d)\b"#, options: .regularExpression) {
            let p = s[r].split(separator: ":").compactMap { Int($0) }
            return (p[0], p[1], r)
        }
        if let r = s.range(of: #"\b([01]?\d|2[0-3])([0-5]0|[0-5]5|15|45)\b"#, options: .regularExpression) {
            let t = String(s[r]); let n = Int(t) ?? 0
            return (n / 100, n % 100, r)
        }
        return nil
    }

    static func calendar(_ lines: [DocEngine.OCRLine], heads: [DocEngine.OCRLine], now: Date) -> Board {
        var b = Board(kind: .calendar)
        // Column centres from the weekday headings.
        var centre = [Int: CGFloat]()
        for h in heads { if let w = weekday(h.text), centre[w] == nil { centre[w] = h.box.midX } }
        let headBottom = heads.map(\.box.maxY).max() ?? 0
        func column(_ x: CGFloat) -> Int? { centre.min { abs($0.value - x) < abs($1.value - x) }?.key }
        let numbers = lines.compactMap { l -> (day: Int, col: Int, y: CGFloat, line: DocEngine.OCRLine)? in
            guard let d = dayNumber(l.text), l.box.minY > headBottom, let c = column(l.box.midX) else { return nil }
            return (d, c, l.box.minY, l)
        }
        b.month = month(for: numbers.map { ($0.day, $0.col) }, now: now)
        let cal = Calendar(identifier: .gregorian)
        let rowHeight = max(0.06, (numbers.map(\.y).max() ?? 1) / CGFloat(max(1, Set(numbers.map(\.day)).count / 7 + 1)))
        var section = ""
        for l in lines.sorted(by: { $0.box.minY < $1.box.minY }) where weekday(l.text) == nil && dayNumber(l.text) == nil {
            // Which day's box it's in: the nearest day number above it in the same column.
            let col = column(l.box.midX)
            let cell = numbers.filter { $0.col == col && $0.y <= l.box.midY + 0.02 && l.box.midY - $0.y < rowHeight * 1.4 }.max { $0.y < $1.y }
            let text = l.text.trimmingCharacters(in: .whitespaces)
            if let cell, l.box.minY > headBottom {
                var date: Date?
                if let m = b.month { date = cal.date(from: DateComponents(year: m.year, month: m.month, day: cell.day)) }
                if let t = time(in: text) {
                    var title = text; title.removeSubrange(t.range)
                    title = title.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "@-–,")))
                    if let d = date { date = cal.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: d) }
                    b.events.append(Event(title: title.isEmpty ? text : title, date: date, hasTime: date != nil))
                } else {
                    b.tasks.append(Item(text: text, section: date.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none) } ?? "Day \(cell.day)", due: date))
                }
            } else if isHeading(text, height: l.box.height, median: 0.02) {
                section = text.trimmingCharacters(in: CharacterSet(charactersIn: ": ")); b.sections.append(section)
            } else if l.box.minY > headBottom {
                let it = item(text)
                b.tasks.append(Item(text: it.text, section: section.isEmpty ? "Notes" : section, done: it.done))
            }
        }
        if b.month == nil { b.notes.append("Couldn't tell which month this is — check the dates before adding them.") }
        return b
    }

    // MARK: people by day

    static func people(_ lines: [DocEngine.OCRLine], heads: [DocEngine.OCRLine]) -> Board {
        var b = Board(kind: .people)
        var centre = [Int: CGFloat]()
        for h in heads { if let w = weekday(h.text), centre[w] == nil { centre[w] = h.box.midX } }
        let firstDayX = (heads.map(\.box.minX).min() ?? 0.2)
        let headBottom = heads.map(\.box.maxY).max() ?? 0
        let names = lines.filter { $0.box.maxX < firstDayX + 0.01 && $0.box.minY > headBottom && $0.text.filter(\.isLetter).count >= 3 && weekday($0.text) == nil }
        guard !names.isEmpty else { return lists(lines, now: Date()) }
        for l in lines where l.box.minX >= firstDayX - 0.01 && l.box.minY > headBottom && weekday(l.text) == nil {
            guard let row = names.min(by: { abs($0.box.midY - l.box.midY) < abs($1.box.midY - l.box.midY) }),
                  abs(row.box.midY - l.box.midY) < max(0.02, row.box.height),
                  let day = centre.min(by: { abs($0.value - l.box.midX) < abs($1.value - l.box.midX) })?.key else { continue }
            b.people.append(PersonDay(person: titled(row.text), day: weekdays[day].capitalized, what: l.text.trimmingCharacters(in: .whitespaces)))
        }
        b.notes.append("Arrows and ditto marks that carry a job across days can't be read from text alone — check the week.")
        return b
    }

    static func titled(_ s: String) -> String {
        s.lowercased().split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    // MARK: Apple Intelligence (iOS 27+): looks at the photo itself

    #if canImport(FoundationModels)
    @available(iOS 27.0, *)
    @Generable struct AIItem {
        @Guide(description: "The task or note exactly as written, spelling fixed, without checkbox or bullet") var text: String
        @Guide(description: "True only if it is ticked, checked, crossed out or struck through") var done: Bool
        @Guide(description: "Who it is for, if a name is written with it") var who: String?
    }
    @available(iOS 27.0, *)
    @Generable struct AISection {
        @Guide(description: "The heading written above this group, or an empty string") var title: String
        var items: [AIItem]
    }
    @available(iOS 27.0, *)
    @Generable struct AIEvent {
        @Guide(description: "What is happening, without the time") var title: String
        @Guide(description: "Day of the month it is written in, 1 to 31") var day: Int?
        @Guide(description: "Time as 24-hour HH:MM if one is written, e.g. '1930' means 19:30") var time: String?
        @Guide(description: "Place if written") var place: String?
    }
    @available(iOS 27.0, *)
    @Generable struct AIPersonDay {
        var person: String
        @Guide(description: "Mon, Tue, Wed, Thu, Fri, Sat or Sun") var day: String
        @Guide(description: "What they are doing that day. If an arrow carries an entry across days, repeat it for each day it covers") var what: String
    }
    @available(iOS 27.0, *)
    @Generable struct AIBoard {
        @Guide(description: "lists, calendar, people (names down the side, days across the top) or other") var kind: String
        @Guide(description: "Month and year printed on the calendar, like 'March 2026', or empty") var monthYear: String
        var sections: [AISection]
        var events: [AIEvent]
        var people: [AIPersonDay]
    }

    @available(iOS 27.0, *)
    static func readWithAI(_ image: UIImage, ocr: [DocEngine.OCRLine], hint: Kind, now: Date) async -> Board? {
        guard case .available = SystemLanguageModel.default.availability, let cg = image.cgImage else { return nil }
        let hintText = String(ChainRunner.rows(ocr).prefix(1800))
        let session = LanguageModelSession(instructions: """
        You read photos of whiteboards, wall calendars, sticky notes, to-do lists and schedules, and write down \
        exactly what is on them so the person can put it in their planner. Keep every item; never invent one. \
        Ticked, checked, crossed-out or struck-through items are done. Sticky notes on a calendar day belong to \
        that day. For a calendar, anything with a time is an event on that day; other notes on a day are items. \
        Headings like 'TO PUBLISH:' or 'BUILD-FIX' are section titles.
        """)
        do {
            let r = try await withThrowingTaskGroup(of: AIBoard?.self) { g in
                g.addTask {
                    try await session.respond(generating: AIBoard.self, options: GenerationOptions(samplingMode: .greedy)) {
                        "Read this photo. The camera's text reading, which may have mistakes, was:\n\(hintText)"
                        Attachment(cg)
                    }.content
                }
                g.addTask { try await Task.sleep(nanoseconds: 45_000_000_000); return nil }
                defer { g.cancelAll() }
                return try await g.next() ?? nil
            }
            guard let r else { return nil }
            return board(from: r, rulesHint: hint, now: now)
        } catch { return nil }
    }

    @available(iOS 27.0, *)
    static func board(from r: AIBoard, rulesHint: Kind, now: Date) -> Board {
        var b = Board(kind: Kind(rawValue: r.kind.lowercased()) ?? rulesHint, byAI: true)
        for s in r.sections {
            let title = s.title.trimmingCharacters(in: CharacterSet(charactersIn: ": ").union(.whitespaces))
            if !title.isEmpty { b.sections.append(title) }
            for i in s.items where !i.text.trimmingCharacters(in: .whitespaces).isEmpty {
                b.tasks.append(Item(text: i.text, section: title, done: i.done, person: i.who, due: due(in: i.text, now: now)))
            }
        }
        b.people = r.people.map { PersonDay(person: titled($0.person), day: String($0.day.prefix(3)).capitalized, what: $0.what) }
        // Calendar dates: the printed month if there is one, else the month whose weekdays fit.
        let cal = Calendar(identifier: .gregorian)
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; f.locale = Locale(identifier: "en_US_POSIX")
        let printed = f.date(from: r.monthYear).map { cal.dateComponents([.year, .month], from: $0) }
        let month = printed ?? cal.dateComponents([.year, .month], from: now)
        b.month = month
        for e in r.events {
            var date: Date?
            if let d = e.day, (1...31).contains(d) { date = cal.date(from: DateComponents(year: month.year, month: month.month, day: d)) }
            var hasTime = false
            if let t = e.time, let tt = time(in: t), let d = date { date = cal.date(bySettingHour: tt.hour, minute: tt.minute, second: 0, of: d); hasTime = true }
            b.events.append(Event(title: e.title, date: date, hasTime: hasTime, place: e.place ?? ""))
        }
        if printed == nil, !b.events.isEmpty { b.notes.append("No month is written on the board, so this month is assumed — check the dates.") }
        return b
    }
    #endif
}
