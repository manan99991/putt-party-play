import Foundation
import UIKit
import BackgroundTasks
import UserNotifications

/// The smart autoruns on this phone: what's switched on, when each last ran, what's waiting for a look, and the work
/// itself — in the background when iPhone allows (overnight on the charger), or when Tenzy is opened, or on Test run.
@MainActor final class SmartRunStore: ObservableObject {
    static let shared = SmartRunStore()
    /// The autoruns built so far. An autorun is only offered once it truly works end to end.
    static let built: [SmartRuns.Kind] = [.receipts]

    @Published private(set) var plans: [SmartRuns.Kind: SmartRuns.Plan] = [:]
    @Published private(set) var receipts: [SmartReceipts.Entry] = []      // found, waiting for a look
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

    init() {
        if let d = AppGroup.defaults.data(forKey: plansKey), let p = try? JSONDecoder().decode([String: SmartRuns.Plan].self, from: d) {
            plans = Dictionary(uniqueKeysWithValues: p.compactMap { k, v in SmartRuns.Kind(rawValue: k).map { ($0, v) } })
        }
        if let d = try? Data(contentsOf: receiptsURL), let r = try? JSONDecoder().decode([SmartReceipts.Entry].self, from: d) { receipts = r }
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

    func waitingCount(_ k: SmartRuns.Kind) -> Int { k == .receipts ? receipts.count : 0 }

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
        receipts.removeAll(where: \.ready); saveReceipts()
        Task { await SmartRunAlerts.ready(.receipts, count: receipts.count) }
        return r
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
        for (n, t) in p.times.enumerated() {
            let body = UNMutableNotificationContent()
            body.title = L(k.title)
            body.body = waiting > 0 ? "\(waiting) \(L(waiting == 1 ? "receipt is ready to check and add." : "receipts are ready to check and add."))"
                                    : L("Tap and Tenzy finds today's receipts, reads them and gets them ready for your sheet.")
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
