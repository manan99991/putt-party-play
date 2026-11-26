import Foundation
import UIKit
import BackgroundTasks
import UserNotifications

/// The smart autoruns on this phone: what's switched on, when each last ran, what's waiting for a look, and the work
/// itself — in the background when iPhone allows (overnight on the charger), or when Tenzy is opened, or on Test run.
@MainActor final class SmartRunStore: ObservableObject {
    static let shared = SmartRunStore()
    /// The autoruns built so far. An autorun is only offered once it truly works end to end.
    static let built: [SmartRuns.Kind] = [.receipts, .drives, .overdueInvoices, .heavyVideos, .readyToPost, .dayCollage, .businessCards]

    @Published private(set) var plans: [SmartRuns.Kind: SmartRuns.Plan] = [:]
    @Published private(set) var receipts: [SmartReceipts.Entry] = []      // found, waiting for a look
    @Published private(set) var videos: [SmartVideos.Result] = []          // smaller copies made, waiting for a look
    @Published private(set) var posts: [SmartPosts.Result] = []            // clips made ready to post, waiting for a look
    @Published private(set) var collages: [SmartCollage.Result] = []       // the day's collages, waiting for a look
    @Published private(set) var cards: [SmartCards.Entry] = []             // business cards read, waiting for a look
    @Published var working: SmartRuns.Kind?
    @Published var progress: (share: Double, what: String) = (0, "")
    @Published var started: Date?

    private let plansKey = "smartruns.plans"
    private func lastKey(_ k: SmartRuns.Kind) -> String { "smartruns.last.\(k.rawValue)" }
    private var folder: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SmartRuns", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    private var receiptsURL: URL { folder.appendingPathComponent("receipts.json") }
    private var videosURL: URL { folder.appendingPathComponent("videos.json") }
    private var postsURL: URL { folder.appendingPathComponent("posts.json") }
    private var collagesURL: URL { folder.appendingPathComponent("collages.json") }
    private var cardsURL: URL { folder.appendingPathComponent("cards.json") }

    init() {
        if let d = AppGroup.defaults.data(forKey: plansKey), let p = try? JSONDecoder().decode([String: SmartRuns.Plan].self, from: d) {
            plans = Dictionary(uniqueKeysWithValues: p.compactMap { k, v in SmartRuns.Kind(rawValue: k).map { ($0, v) } })
        }
        if let d = try? Data(contentsOf: receiptsURL), let r = try? JSONDecoder().decode([SmartReceipts.Entry].self, from: d) { receipts = r }
        if let d = try? Data(contentsOf: videosURL), let r = try? JSONDecoder().decode([SmartVideos.Result].self, from: d) {
            videos = r.filter { FileManager.default.fileExists(atPath: SmartVideos.folder.appendingPathComponent($0.file).path) }
        }
        if let d = try? Data(contentsOf: cardsURL), let r = try? JSONDecoder().decode([SmartCards.Entry].self, from: d) { cards = r }
        if let d = try? Data(contentsOf: collagesURL), let r = try? JSONDecoder().decode([SmartCollage.Result].self, from: d) {
            collages = r.filter { FileManager.default.fileExists(atPath: SmartCollage.folder.appendingPathComponent($0.file).path) }
        }
        if let d = try? Data(contentsOf: postsURL), let r = try? JSONDecoder().decode([SmartPosts.Result].self, from: d) {
            posts = r.filter { FileManager.default.fileExists(atPath: SmartPosts.folder.appendingPathComponent($0.file).path) }
        }
    }

    func plan(_ k: SmartRuns.Kind) -> SmartRuns.Plan { plans[k] ?? SmartRuns.Plan() }
    func lastRun(_ k: SmartRuns.Kind) -> Date? {
        let t = AppGroup.defaults.double(forKey: lastKey(k)); return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    func set(_ k: SmartRuns.Kind, _ p: SmartRuns.Plan) {
        plans[k] = p
        let raw = Dictionary(uniqueKeysWithValues: plans.map { ($0.key.rawValue, $0.value) })
        if let d = try? JSONEncoder().encode(raw) { AppGroup.defaults.set(d, forKey: plansKey) }
        Task { await SmartRunAlerts.schedule(k, p, waiting: waitingCount(k)) }
        SmartRunWorker.scheduleBackground()
    }

    func waitingCount(_ k: SmartRuns.Kind) -> Int {
        switch k {
        case .receipts: return receipts.count
        case .drives: return drives.count
        case .overdueInvoices: return overdue.count
        case .heavyVideos: return videos.count
        case .readyToPost: return posts.filter { !$0.saved }.count
        case .dayCollage: return collages.filter { !$0.saved }.count
        case .businessCards: return cards.count
        default: return 0
        }
    }

    /// Unpaid invoices past their pay-by day, latest first.
    var overdue: [Invoice.Doc] { InvoiceStore.shared.docs.filter { $0.overdue() }.sorted { ($0.due ?? .distantPast) < ($1.due ?? .distantPast) } }

    /// Drives from the last week not yet looked at (a missed evening doesn't lose them).
    var drives: [DriveStore.Drive] {
        DriveStore.waiting(DriveStore.all(), in: DateInterval(start: Date().addingTimeInterval(-7 * 86_400), end: Date()))
    }

    /// Logs the drives marked for work (or medical, charity) into the mileage log; every drive shown counts as looked at.
    func logDrives(_ picks: [UUID: (purpose: Mileage.Purpose?, miles: Double, why: String)], places: [UUID: (String, String)]) -> Int {
        var n = 0
        for d in drives {
            guard let p = picks[d.id], let purpose = p.purpose, p.miles > 0 else { continue }
            let pl = places[d.id] ?? ("", "")
            MileageStore.shared.add(Mileage.Trip(date: d.start, from: pl.0, to: pl.1, why: p.why, miles: p.miles, purpose: purpose))
            n += 1
        }
        DriveStore.markReviewed(Set(drives.map(\.id)))
        objectWillChange.send()
        Task { await SmartRunAlerts.ready(.drives, count: 0) }
        return n
    }

    // MARK: running

    /// Runs one autorun now on everything new since its last run (or, for a Test run, the last 24 hours, and the last
    /// run is left alone so tonight's still happens). Findings join what's already waiting.
    func run(_ k: SmartRuns.Kind, test: Bool = false) async {
        guard working == nil else { return }
        working = k; started = Date(); progress = (0, "Starting…")
        defer { working = nil; started = nil }
        let now = Date()
        let window = test ? DateInterval(start: now.addingTimeInterval(-24 * 3600), end: now) : SmartRuns.window(lastRun: lastRun(k), now: now)
        switch k {
        case .receipts:
            let found = await SmartReceipts.gather(in: window) { share, what in Task { @MainActor in self.progress = (share, what) } }
            // Keep what's already waiting (the person may have edited it); add only new ones.
            let have = Set(receipts.map(\.id))
            receipts = SmartReceipts.deduped(receipts + found.filter { !have.contains($0.id) })
            saveReceipts()
        case .drives, .overdueInvoices:
            progress = (1, "Done")   // drives and invoices are Tenzy's own records; the run only gathers them for a look
        case .heavyVideos:
            let have = Set(videos.map(\.id))
            SmartVideos.trail = []
            let picks = SmartVideos.found(in: window).filter { !have.contains($0.0.id) }
            let heavy = SmartRuns.heavy(picks.map(\.0)).compactMap { f in picks.first { $0.0.id == f.id } }
            SmartVideos.note("\(picks.count) videos in the window (\(picks.map { "\($0.0.bytes / 1_000_000) MB/\(Int($0.0.seconds)) s" }.joined(separator: ", "))), \(heavy.count) heavy")
            for (i, (f, a)) in heavy.enumerated() {
                if Task.isCancelled { break }
                let label = "\(L("Making video")) \(i + 1)/\(heavy.count)"
                progress = (Double(i) / Double(max(1, heavy.count)), label)
                if let r = await SmartVideos.shrink(f, a, progress: { p in Task { @MainActor in
                    self.progress = ((Double(i) + p) / Double(max(1, heavy.count)), label) } }) {
                    videos.append(r); saveVideos()
                }
            }
            progress = (1, "Done")
        case .businessCards:
            let found = await SmartCards.gather(in: window) { share, what in Task { @MainActor in self.progress = (share, what) } }
            let have = Set(cards.map(\.id))
            cards = SmartCards.deduped(cards + found.filter { !have.contains($0.id) }); persistCards()
        case .dayCollage:
            if let r = await SmartCollage.make(in: window, progress: { share, what in Task { @MainActor in self.progress = (share, what) } }) {
                collages.removeAll { $0.id == r.id }; collages.insert(r, at: 0); saveCollages()
            }
            progress = (1, "Done")
        case .readyToPost:
            progress = (0.02, "Picking today's best clips…")
            let have = Set(posts.map(\.id))
            let best = await SmartPosts.best(in: window).filter { !have.contains($0.0.id) }
            let look = plan(.readyToPost).look ?? "vivid"
            for (i, (f, a)) in best.enumerated() {
                if Task.isCancelled { break }
                let base = Double(i) / Double(max(1, best.count))
                progress = (base + 0.05, "\(L("Clip")) \(i + 1)/\(best.count)")
                if let r = await SmartPosts.make(f, a, look: look, progress: { what in Task { @MainActor in
                    self.progress = (base + 0.5 / Double(max(1, best.count)), "\(L("Clip")) \(i + 1)/\(best.count) · \(what)") } }) {
                    posts.append(r); savePosts()
                }
            }
            progress = (1, "Done")
        default: break
        }
        if !test { AppGroup.defaults.set(now.timeIntervalSince1970, forKey: lastKey(k)) }
        await SmartRunAlerts.ready(k, count: waitingCount(k))
    }

    /// Runs whichever autoruns are due — on opening Tenzy and from the background task.
    func runDue() async {
        for k in Self.built where SmartRuns.isDue(plan(k), lastRun: lastRun(k), now: Date()) {
            await run(k)
        }
    }

    // MARK: receipts waiting for a look

    func update(_ e: SmartReceipts.Entry) {
        guard let i = receipts.firstIndex(where: { $0.id == e.id }) else { return }
        var e = e; e.recheck(); receipts[i] = e; saveReceipts()
    }
    func drop(_ id: String) { receipts.removeAll { $0.id == id }; saveReceipts() }

    /// Adds the ready ones to the expense sheet and keeps any that still need a fix.
    func addReady() -> (sheet: String, added: Int, already: Int) {
        let r = SmartReceipts.add(receipts)
        let kept = receipts.filter { $0.ready && $0.keep == true }
        if !kept.isEmpty { Task { _ = await SmartReceipts.file(kept) } }   // and into Warranty, with their photos
        receipts.removeAll(where: \.ready); saveReceipts()
        Task { await SmartRunAlerts.ready(.receipts, count: receipts.count) }
        return r
    }

    /// The smaller copies, into Photos (with the originals' dates and places). Returns how many were saved.
    func saveVideos(_ ids: Set<String>) async -> Int {
        var n = 0
        for i in videos.indices where ids.contains(videos[i].id) && !videos[i].saved {
            if let id = await SmartVideos.saveToPhotos(videos[i]) { videos[i].saved = true; videos[i].savedID = id; n += 1 }
        }
        saveVideos()
        return n
    }

    /// iPhone's own prompt to delete the originals of the saved copies; the list then clears.
    func deleteOriginals() async -> Bool {
        let done = videos.filter(\.saved)
        guard !done.isEmpty, await SmartVideos.deleteOriginals(done.map(\.id)) else { return false }
        for r in done { try? FileManager.default.removeItem(at: SmartVideos.folder.appendingPathComponent(r.file)) }
        videos.removeAll(where: \.saved); saveVideos()
        Task { await SmartRunAlerts.ready(.heavyVideos, count: videos.count) }
        return true
    }

    /// Keeps the originals: the copies already saved stay in Photos, the list clears.
    func keepOriginals() {
        for r in videos where !r.saved { try? FileManager.default.removeItem(at: SmartVideos.folder.appendingPathComponent(r.file)) }
        videos.removeAll(); saveVideos()
    }

    /// One ready clip into Photos (for posting from Instagram, TikTok or YouTube). Returns the new id.
    func savePost(_ id: String) async -> String? {
        guard let i = posts.firstIndex(where: { $0.id == id }) else { return nil }
        let r = await SocialPost.saveToPhotos(SmartPosts.folder.appendingPathComponent(posts[i].file))
        guard r.ok else { return nil }
        posts[i].saved = true; posts[i].savedID = r.id; savePosts()
        Task { await SmartRunAlerts.ready(.readyToPost, count: waitingCount(.readyToPost)) }
        return r.id ?? ""
    }
    func dropPost(_ id: String) {
        if let r = posts.first(where: { $0.id == id }) { try? FileManager.default.removeItem(at: SmartPosts.folder.appendingPathComponent(r.file)) }
        posts.removeAll { $0.id == id }; savePosts()
    }
    /// Another layout for a day's collage (Grid, Hero, Mosaic…), made again from that day's photos.
    func remakeCollage(_ id: String, layout: CollageLayout) async {
        guard let old = collages.first(where: { $0.id == id }) else { return }
        let end = (DateFormatter.posixDay.date(from: id) ?? Date()).addingTimeInterval(86_399)
        guard let r = await SmartCollage.make(in: DateInterval(start: end.addingTimeInterval(-86_399), end: min(end, Date())), layout: layout) else { return }
        try? FileManager.default.removeItem(at: SmartCollage.folder.appendingPathComponent(old.file))
        if let i = collages.firstIndex(where: { $0.id == id }) { collages[i] = r }; saveCollages()
    }
    func saveCollage(_ id: String) async -> Bool {
        guard let i = collages.firstIndex(where: { $0.id == id }), await SmartCollage.save(collages[i]) else { return false }
        collages[i].saved = true; saveCollages()
        Task { await SmartRunAlerts.ready(.dayCollage, count: waitingCount(.dayCollage)) }
        return true
    }
    func updateCard(_ e: SmartCards.Entry) {
        if let i = cards.firstIndex(where: { $0.id == e.id }) { cards[i] = e; persistCards() }
    }
    func dropCard(_ id: String) { cards.removeAll { $0.id == id }; persistCards() }
    /// Saves the new contacts; the list clears. nil when Contacts access was refused.
    func saveCards() async -> Int? {
        guard let n = await SmartCards.save(cards) else { return nil }
        cards.removeAll(); persistCards()
        Task { await SmartRunAlerts.ready(.businessCards, count: 0) }
        return n
    }
    private func persistCards() {
        if let d = try? JSONEncoder().encode(cards) { try? d.write(to: cardsURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
    }

    private func saveCollages() {
        if let d = try? JSONEncoder().encode(collages) { try? d.write(to: collagesURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
    }

    private func savePosts() {
        if let d = try? JSONEncoder().encode(posts) { try? d.write(to: postsURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
    }

    private func saveVideos() {
        if let d = try? JSONEncoder().encode(videos) { try? d.write(to: videosURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
    }

    private func saveReceipts() {
        if let d = try? JSONEncoder().encode(receipts) { try? d.write(to: receiptsURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
    }
}

/// The background run: iPhone starts it when it judges best (usually overnight on the charger).
enum SmartRunWorker {
    static let taskID = "com.tenzy.toolkit.smartruns"

    static func registerBackground() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            scheduleBackground()
            let work = Task { @MainActor in await SmartRunStore.shared.runDue(); task.setTaskCompleted(success: true) }
            task.expirationHandler = { work.cancel() }
        }
    }

    @MainActor static func scheduleBackground() {
        let store = SmartRunStore.shared
        let next = SmartRunStore.built.compactMap { SmartRuns.nextDue(store.plan($0), after: Date()) }.min()
        guard let next else { BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskID); return }
        let r = BGProcessingTaskRequest(identifier: taskID)
        r.requiresExternalPower = false
        r.requiresNetworkConnectivity = false
        // A little before the chosen time, so the work is usually done when the notification comes.
        r.earliestBeginDate = max(Date().addingTimeInterval(15 * 60), next.addingTimeInterval(-90 * 60))
        try? BGTaskScheduler.shared.submit(r)
    }
}

/// The notifications: one at each chosen time, saying how many are ready when the work was done ahead of time — or,
/// when it couldn't be yet, that a tap finds and reads them. Never a count that isn't true.
enum SmartRunAlerts {
    static func id(_ k: SmartRuns.Kind, _ n: Int) -> String { "smartrun.\(k.rawValue).\(n)" }

    static func schedule(_ k: SmartRuns.Kind, _ p: SmartRuns.Plan, waiting: Int) async {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: (0..<2).map { id(k, $0) })
        guard p.on else { return }
        // Drives and invoices are known as they happen: nothing waiting, no notification.
        if (k == .drives || k == .overdueInvoices) && waiting == 0 { return }
        for (n, t) in p.times.enumerated() {
            let body = UNMutableNotificationContent()
            body.title = L(k.title)
            switch k {
            case .overdueInvoices:
                body.body = "\(waiting) \(L(waiting == 1 ? "invoice is overdue — a reminder is ready to send." : "invoices are overdue — reminders are ready to send."))"
            case .businessCards:
                body.body = waiting > 0 ? "\(waiting) \(L(waiting == 1 ? "business card read — save it to Contacts?" : "business cards read — save them to Contacts?"))"
                                        : L("Tap and Tenzy reads today's business cards into contacts.")
            case .dayCollage:
                body.body = waiting > 0 ? L("Today's collage is ready — have a look.") : L("Tap and Tenzy makes one collage of the best photos of your day.")
            case .readyToPost:
                body.body = waiting > 0 ? "\(waiting) \(L(waiting == 1 ? "clip is ready to post — watch it first." : "clips are ready to post — watch them first."))"
                                        : L("Tap and Tenzy picks today's best clips and gets them ready to post.")
            case .heavyVideos:
                body.body = waiting > 0 ? "\(waiting) \(L(waiting == 1 ? "video can be made smaller — it looks the same." : "videos can be made smaller — they look the same."))"
                                        : L("Tap and Tenzy finds today's heavy videos and makes them smaller without losing quality.")
            case .drives:
                body.body = waiting > 0 ? "\(waiting) \(L(waiting == 1 ? "drive today — was it for work?" : "drives today — which were for work?"))"
                                        : L("Tap to see today's drives and log the ones for work.")
            default:
                body.body = waiting > 0 ? "\(waiting) \(L(waiting == 1 ? "receipt is ready to check and add." : "receipts are ready to check and add."))"
                                        : L("Tap and Tenzy finds today's receipts, reads them and gets them ready for your sheet.")
            }
            body.sound = .default
            body.userInfo = ["open": "smartruns"]
            let trig = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: t.hour, minute: t.minute), repeats: true)
            try? await c.add(UNNotificationRequest(identifier: id(k, n), content: body, trigger: trig))
        }
    }

    /// After a run: the next notification says what's waiting.
    @MainActor static func ready(_ k: SmartRuns.Kind, count: Int) async {
        await schedule(k, SmartRunStore.shared.plan(k), waiting: count)
    }
}


extension DateFormatter {
    /// "2026-11-25", the same everywhere.
    static let posixDay: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f }()
}
