import Foundation
import UserNotifications

/// "Tell me when" for tools you build: after a run, the number in the result is checked against the tool's watch.
enum ToolWatch {
    private static func key(_ id: String) -> String { "watch.memory.\(id)" }
    static func memory(_ id: String) -> WatchMemory {
        (UserDefaults.standard.data(forKey: key(id))).flatMap { try? JSONDecoder().decode(WatchMemory.self, from: $0) } ?? WatchMemory()
    }
    static func remember(_ m: WatchMemory, for id: String) {
        if let d = try? JSONEncoder().encode(m) { UserDefaults.standard.set(d, forKey: key(id)) }
    }

    /// Check a finished run. Returns the line to show on screen when the watch speaks up (and posts the
    /// same as a notification, so a run from Shortcuts or a reminder reaches you too). Nil: nothing to say.
    @discardableResult
    static func check(_ chain: Chain, text: String?, notify: Bool = true) -> String? {
        guard let w = chain.watch, let text, let v = NumberReader.pick(in: text, near: w.near) else { return nil }
        var m = memory(chain.id)
        let before = m.last
        let fire = NumberReader.evaluate(w, value: v, memory: &m)
        remember(m, for: chain.id)
        guard fire else { return nil }
        let line = NumberReader.message(w, value: v, previous: before, what: w.near.isEmpty ? "The number" : w.near.capitalized)
        if notify {
            let c = UNMutableNotificationContent()
            c.title = chain.name; c.body = line; c.sound = .default
            c.userInfo = ["tool": chain.id]
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "watch-\(chain.id)-\(UUID().uuidString)", content: c, trigger: nil))
        }
        return line
    }
}

/// Price Watch: a number on a web page you care about — a price, a stock count, a rate — checked now and then.
/// Battery- and data-light by design: at most 10 pages, only when iPhone's Background App Refresh decides
/// (usually a few times a day, never on a tight timer), one small download per page, skipped when the page
/// says it hasn't changed, and nothing at all when you have no watches.
struct PageWatch: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var url: URL
    var watch = NumberWatch()
    var memory = WatchMemory()
    var lastChecked: Date?
    var lastValue: Double?
    var problem: String?
    var etag: String?
}

enum PageWatcher {
    static let limit = 10
    static let maxBytes = 3_000_000
    /// When Tenzy is open, look again only if it's been this long — opening the app never triggers a download storm.
    static let minGap: TimeInterval = 2 * 3600
    private static let key = "pricewatch.pages"

    static func load() -> [PageWatch] {
        (UserDefaults.standard.data(forKey: key)).flatMap { try? JSONDecoder().decode([PageWatch].self, from: $0) } ?? []
    }
    static func save(_ p: [PageWatch]) {
        if let d = try? JSONEncoder().encode(Array(p.prefix(limit))) { UserDefaults.standard.set(d, forKey: key) }
    }
    static var any: Bool { !load().isEmpty }

    /// Page HTML → the words a person sees (scripts, styles and tags removed, entities decoded).
    static func visibleText(_ html: String) -> String {
        // Prices in structured data ("price": "49.99") are often the most reliable — keep them readable
        // before the scripts that hold them are dropped.
        var structured: [String] = []
        if let re = try? NSRegularExpression(pattern: #"(?i)"price"\s*:\s*"?([0-9][0-9.,]*)"?"#) {
            let ns = html as NSString
            structured = re.matches(in: html, range: NSRange(location: 0, length: ns.length)).prefix(3).map { ns.substring(with: $0.range(at: 1)) }
        }
        var s = html
        for p in [#"(?is)<script\b.*?</script>"#, #"(?is)<style\b.*?</style>"#, #"(?is)<noscript\b.*?</noscript>"#, #"(?s)<!--.*?-->"#] {
            s = s.replacingOccurrences(of: p, with: " ", options: .regularExpression)
        }
        s = s.replacingOccurrences(of: #"(?s)<[^>]+>"#, with: " ", options: .regularExpression)
        for (e, r) in [("&nbsp;", " "), ("&amp;", "&"), ("&pound;", "£"), ("&euro;", "€"), ("&#36;", "$"), ("&quot;", "\""), ("&#39;", "'"), ("&lt;", "<"), ("&gt;", ">")] {
            s = s.replacingOccurrences(of: e, with: r)
        }
        if !structured.isEmpty { s += " " + structured.map { "Price \($0)" }.joined(separator: " ") }
        return s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    enum Fetch: Equatable { case text(String, etag: String?), unchanged, failed(String) }

    static func fetch(_ url: URL, etag: String?) async -> Fetch {
        guard url.scheme == "https" || url.scheme == "http" else { return .failed("That isn't a web address.") }
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 15; cfg.timeoutIntervalForResource = 25
        cfg.allowsExpensiveNetworkAccess = true; cfg.allowsConstrainedNetworkAccess = false   // respect Low Data Mode
        let session = URLSession(configuration: cfg)
        var req = URLRequest(url: url)
        req.setValue("text/html", forHTTPHeaderField: "Accept")
        if let etag { req.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        do {
            let (data, resp) = try await session.data(for: req)
            let http = resp as? HTTPURLResponse
            if http?.statusCode == 304 { return .unchanged }
            guard let code = http?.statusCode, (200..<300).contains(code) else { return .failed("The page didn't open (error \(http?.statusCode ?? 0)).") }
            guard data.count <= maxBytes else { return .failed("That page is too big to check.") }
            let html = String(decoding: data, as: UTF8.self)
            return .text(visibleText(html), etag: http?.value(forHTTPHeaderField: "ETag"))
        } catch {
            return .failed("Couldn't reach the page — no connection, or the site blocked the check.")
        }
    }

    /// Look at one page now. Returns the updated watch and, when it should speak up, the line to send.
    static func check(_ p: PageWatch, now: Date = Date()) async -> (PageWatch, String?) {
        var p = p
        p.lastChecked = now
        switch await fetch(p.url, etag: p.etag) {
        case .unchanged:
            return (p, nil)
        case .failed(let why):
            p.problem = why
            return (p, nil)
        case .text(let text, let etag):
            p.etag = etag
            guard let v = NumberReader.pick(in: text, near: p.watch.near) else {
                p.problem = "No number found on the page. Some shops only show prices after the page runs scripts — try the product's mobile page, or add the words next to the price."
                return (p, nil)
            }
            p.problem = nil
            let before = p.memory.last
            p.lastValue = v
            let fire = NumberReader.evaluate(p.watch, value: v, memory: &p.memory, now: now)
            return (p, fire ? NumberReader.message(p.watch, value: v, previous: before, what: p.name) : nil)
        }
    }

    /// Check every page that's due, post what crossed, save. Called by the background refresh and when Tenzy opens.
    static func checkAll(force: Bool = false, now: Date = Date()) async {
        var pages = load()
        guard !pages.isEmpty else { return }
        let allowed = await NotifyPermission.state() == .allowed
        for i in pages.indices {
            if !force, let last = pages[i].lastChecked, now.timeIntervalSince(last) < minGap { continue }
            let (updated, line) = await check(pages[i], now: now)
            pages[i] = updated
            if allowed, let line { post(updated, line) }
        }
        // Keep edits made while we were checking: only write back the fields a check changes.
        var fresh = load()
        for p in pages {
            if let k = fresh.firstIndex(where: { $0.id == p.id }) {
                fresh[k].lastChecked = p.lastChecked; fresh[k].lastValue = p.lastValue; fresh[k].memory = p.memory
                fresh[k].problem = p.problem; fresh[k].etag = p.etag
            }
        }
        save(fresh)
    }

    static func post(_ p: PageWatch, _ line: String, test: Bool = false) {
        let c = UNMutableNotificationContent()
        c.title = (test ? "Test · " : "") + "Price Watch"
        c.body = line + " Tap to see it."
        c.sound = .default
        c.userInfo = ["open": "pricewatch", "url": p.url.absoluteString]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "pricewatch-\(p.id.uuidString)-\(UUID().uuidString)", content: c, trigger: nil))
    }
}
