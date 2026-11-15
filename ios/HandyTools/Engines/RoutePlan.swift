import Foundation

/// Phase 1 of the smart task planner: offline, no permissions. Given the tasks pulled from someone's
/// thoughts, it spots the ones that mean "go somewhere", adds a one-tap Apple/Google Maps **directions**
/// link to each, and puts obvious "first / finally" tasks in order. The maps app shows the live route and
/// drive time when tapped. (Phase 2 adds real in-app ETAs and a timed itinerary via MapKit.)
///
/// Deliberately conservative: it only links a destination it is confident about (a known place, or the
/// words right after "to/at/from"), so it never turns a person's name into a map search.
enum RoutePlan {

    /// Everyday destinations worth a map link, matched as whole words, case-insensitive.
    static let knownPlaces: [String] = [
        "walmart", "target", "costco", "kroger", "safeway", "aldi", "publix", "meijer", "wegmans",
        "trader joe", "whole foods", "home depot", "lowe's", "lowes", "cvs", "walgreens", "ikea",
        "best buy", "sam's club", "sams club", "airport", "train station", "bus station", "station",
        "hospital", "clinic", "pharmacy", "dmv", "post office", "bank", "mall", "gym", "school",
        "college", "university", "library", "temple", "church", "mosque", "synagogue", "shelter",
        "vet", "dealership", "office", "park",
    ]

    /// Words that mark a phrase as a real place, so "to Oak Street Clinic" is a destination but
    /// "to Ana" (a person) is not. The open "to/at/from X" path only fires when one of these is present.
    private static let placeIndicators: Set<String> = [
        "street", "st", "avenue", "ave", "road", "rd", "boulevard", "blvd", "lane", "ln", "drive", "dr",
        "way", "court", "ct", "place", "plaza", "square", "clinic", "hospital", "center", "centre",
        "mall", "store", "shop", "market", "supermarket", "airport", "station", "terminal", "park",
        "school", "college", "university", "library", "office", "building", "tower", "hotel",
        "restaurant", "cafe", "café", "bank", "pharmacy", "church", "temple", "mosque", "synagogue",
        "shelter", "gym", "stadium", "arena", "museum", "theater", "theatre", "dealership", "garage",
        "beach", "lake", "trail", "zoo", "clinic", "depot", "outlet",
    ]

    /// Cue words that carry no place by themselves — we don't treat the word after them as a destination.
    private static let stopWords: Set<String> = ["do", "that", "it", "them", "this", "there", "here", "him", "her", "me", "us", "you", "work", "bed", "sleep"]

    /// The destination in a task line, if there's a confident one. Known place first; otherwise the proper
    /// noun right after "to/at/from". Returns nil when nothing is clear — we never guess.
    static func destination(in line: String) -> String? {
        let lower = line.lowercased()
        // Try the fuller "to/at/from (the) <Capitalised words>" phrase FIRST, so a named place keeps its
        // whole name — "to the Oak Street Clinic" → "Oak Street Clinic", not the bare "Clinic". It only
        // fires when the phrase actually names a place type (Clinic, Mall, Street…), never a bare proper
        // noun — "send it to Ana" must NOT become a map search.
        let pattern = "\\b(?:to|at|from)\\s+(?:the\\s+)?([A-Z][\\w'&.-]+(?:\\s+[A-Z][\\w'&.-]+){0,3})"
        if let re = try? NSRegularExpression(pattern: pattern),
           let m = re.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: line) {
            let cand = String(line[r]).trimmingCharacters(in: .whitespaces)
            let words = cand.lowercased().split(separator: " ").map(String.init)
            if !(words.count == 1 && stopWords.contains(words[0])),
               words.contains(where: { placeIndicators.contains($0) }) {
                return cand
            }
        }
        // Fall back to a known everyday place matched as a whole word — "Pick up milk from Costco" → "Costco".
        if let hit = knownPlaces.first(where: { containsWord($0, in: lower) }) {
            return hit.split(separator: " ").map { $0.capitalized }.joined(separator: " ")   // "walmart" → "Walmart"
        }
        return nil
    }

    /// Apple Maps directions link to a place (opens the Maps app; it shows the live route + ETA).
    static func appleMaps(_ place: String) -> URL? {
        encode(place).flatMap { URL(string: "http://maps.apple.com/?daddr=\($0)&dirflg=d") }
    }
    /// Google Maps directions link to a place.
    static func googleMaps(_ place: String) -> URL? {
        encode(place).flatMap { URL(string: "https://www.google.com/maps/dir/?api=1&destination=\($0)&travelmode=driving") }
    }

    /// Puts an obvious "first" task at the front and an obvious "finally/last" task at the end, keeping
    /// everything else in the order given. Intentionally simple — it never reorders on a guess.
    static func ordered(_ items: [String]) -> [String] {
        guard items.count > 1 else { return items }
        var firsts: [String] = [], lasts: [String] = [], middle: [String] = []
        for it in items {
            let l = it.lowercased()
            if l.contains(" first") || l.hasPrefix("first ") { firsts.append(it) }
            else if l.contains("finally") || l.contains(" last") || l.contains("at the end") { lasts.append(it) }
            else { middle.append(it) }
        }
        return firsts + middle + lasts
    }

    /// A mailto draft when the task means "send/draft an email", with an inferred subject (the words after
    /// "about", else the task itself). Opens Mail's composer so the person just adds the recipient and sends.
    static func emailDraft(for line: String) -> URL? {
        let l = line.lowercased()
        guard l.contains("email") || l.contains("e-mail") else { return nil }
        var subject = line
        if let r = line.range(of: "(?i)\\babout\\b\\s+", options: .regularExpression) { subject = String(line[r.upperBound...]) }
        subject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let enc = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "mailto:?subject=\(enc)")
    }

    /// A tel: link when the task means "call/phone" AND a phone number is actually in the text.
    static func callLink(for line: String) -> URL? {
        let l = line.lowercased()
        guard l.range(of: "\\b(call|phone|ring|dial)\\b", options: .regularExpression) != nil else { return nil }
        guard let r = line.range(of: "\\+?\\d[\\d\\s().\\-]{6,}\\d", options: .regularExpression) else { return nil }
        let digits = String(line[r]).filter { $0.isNumber || $0 == "+" }
        return URL(string: "tel:\(digits)")
    }

    /// The finished plan: ordered tasks as a numbered list, each routed to the right one-tap action —
    /// directions for a place, a draft email, a call — plus a short tip. Markdown, so the links are
    /// tappable in the result. A task with no clear action is listed plainly, so it never gets in the way.
    static func plan(from items: [String]) -> String {
        let rows = ordered(items)
        var lines: [String] = []
        var tips: Set<String> = []
        for (i, task) in rows.enumerated() {
            var actions: [String] = []
            if let place = destination(in: task), let a = appleMaps(place), let g = googleMaps(place) {
                actions.append("[Directions](\(a.absoluteString)) · [Google Maps](\(g.absoluteString))")
                tips.insert("tap Directions for the live route and drive time")
            }
            if let mail = emailDraft(for: task) {
                actions.append("[Draft email](\(mail.absoluteString))")
                tips.insert("tap Draft email to open Mail with the subject ready")
            }
            if let tel = callLink(for: task) { actions.append("[Call](\(tel.absoluteString))") }
            lines.append(actions.isEmpty ? "\(i + 1). \(task)" : "\(i + 1). \(task) — " + actions.joined(separator: " · "))
        }
        var out = lines.joined(separator: "\n")
        if !tips.isEmpty { out += "\n\nTip: " + tips.sorted().joined(separator: "; ") + "." }
        return out
    }

    // MARK: helpers

    private static func encode(_ s: String) -> String? {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?.replacingOccurrences(of: "&", with: "%26")
    }

    /// Whole-word containment, so "park" doesn't match "sparkling".
    private static func containsWord(_ word: String, in text: String) -> Bool {
        guard let re = try? NSRegularExpression(pattern: "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b") else { return text.contains(word) }
        return re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
}
