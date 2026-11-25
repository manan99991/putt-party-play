import Foundation

/// How long one running sheet lasts before a new one starts (My stuff › Sheets, 25 Nov). Monthly unless the person
/// picks another. A sheet's name ends with the period it covers, so "Expenses 2026-11" is November's and
/// "Expenses 2026-Q4" the fourth quarter's.
enum SheetPeriod: String, CaseIterable, Identifiable {
    case weekly, biweekly, monthly, quarterly, yearly
    var id: String { rawValue }

    static let key = "sheets.period"
    static var current: SheetPeriod {
        get { SheetPeriod(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .monthly }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    var title: String {
        switch self {
        case .weekly: return "Weekly"
        case .biweekly: return "Every two weeks"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly: return "Yearly"
        }
    }

    private static func gregorian(_ tz: TimeZone) -> Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = tz; return c }
    private static func iso(_ tz: TimeZone) -> Calendar { var c = Calendar(identifier: .iso8601); c.timeZone = tz; return c }

    /// The end of a sheet's name: 2026-W48 (ISO week), 2026-W47-48 (two weeks, odd week first; a 53rd week stands
    /// alone), 2026-11, 2026-Q4, 2026. Digits only, so it reads the same in every language.
    func token(_ day: Date, timeZone: TimeZone = .current) -> String {
        let g = Self.gregorian(timeZone)
        let y = g.component(.year, from: day), m = g.component(.month, from: day)
        switch self {
        case .monthly: return String(format: "%04d-%02d", y, m)
        case .quarterly: return String(format: "%04d-Q%d", y, (m - 1) / 3 + 1)
        case .yearly: return String(format: "%04d", y)
        case .weekly, .biweekly:
            let c = Self.iso(timeZone)
            let wy = c.component(.yearForWeekOfYear, from: day), w = c.component(.weekOfYear, from: day)
            if self == .weekly || w == 53 { return String(format: "%04d-W%02d", wy, w) }
            let first = w % 2 == 1 ? w : w - 1
            return String(format: "%04d-W%02d-%02d", wy, first, first + 1)
        }
    }
}

extension RunningList {
    /// The period a sheet's name ends with ("Expenses 2026-11 (2)" → "2026-11"), or nil for a sheet named by hand.
    static func periodToken(in name: String) -> String? {
        let base = (name as NSString).deletingPathExtension
        let pattern = #"(\d{4}(?:-W\d{2}(?:-\d{2})?|-Q[1-4]|-\d{2})?)(?: \(\d+\))?$"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: base, range: NSRange(base.startIndex..., in: base)),
              let r = Range(m.range(at: 1), in: base) else { return nil }
        // "Invoice 1234" is not a year: a bare 4-digit ending only counts when it follows a space and looks like one.
        let t = String(base[r])
        if t.count == 4, let y = Int(t), !(1990...2200).contains(y) { return nil }
        return t
    }

    /// A sheet is the one being filled now when its name ends with this period's token.
    static func isCurrent(_ name: String, period: SheetPeriod = .current, now: Date = Date()) -> Bool {
        periodToken(in: name) == period.token(now)
    }

    /// "Expenses 2026-11.csv" → "Expenses 2026-11 (2).csv", or the next free number. Pure, so it is tested.
    static func nextName(after file: String, taken: Set<String>) -> String {
        let ext = (file as NSString).pathExtension.isEmpty ? "csv" : (file as NSString).pathExtension
        var base = (file as NSString).deletingPathExtension
        if let re = try? NSRegularExpression(pattern: #" \(\d+\)$"#) {
            base = re.stringByReplacingMatches(in: base, range: NSRange(base.startIndex..., in: base), withTemplate: "")
        }
        var n = 2
        while taken.contains("\(base) (\(n)).\(ext)") { n += 1 }
        return "\(base) (\(n)).\(ext)"
    }

    private static let redirectKey = "sheets.redirect"
    private static var redirects: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: redirectKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: redirectKey) }
    }

    /// The file a helper adds to for this sheet name pattern: this period's sheet, or the newer one the person
    /// started for the same period ("start a new one").
    static func target(pattern: String?, day: Date = Date()) -> String {
        let file = ChainName.file(pattern: pattern ?? defaultName, tool: "List", day: day, ext: "csv")
        if let r = redirects[file], FileManager.default.fileExists(atPath: url(r).path) { return r }
        return file
    }

    /// Starts a fresh sheet for the same period (same columns, no entries) and sends later entries there.
    /// Returns the new file name.
    @discardableResult static func startNew(from file: String) -> String {
        let taken = Set(all().map(\.file))
        let next = nextName(after: file, taken: taken)
        let header = read(file).components(separatedBy: .newlines).first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
        write(next, header)
        // Key by the period's own name so every helper that fills "Expenses {month}" follows.
        let root = (file as NSString).deletingPathExtension.replacingOccurrences(of: #" \(\d+\)$"#, with: "", options: .regularExpression) + ".csv"
        redirects[root] = next
        return next
    }
}
