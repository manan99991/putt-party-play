import Foundation
import Photos
import UserNotifications
import BackgroundTasks
import UIKit

/// Smart alerts: "tell me when…" rules that watch a number on the phone and nudge only when it's true.
/// Checks run when Tenzy opens and when iPhone grants a background refresh (a few times a day, its
/// choice). A rule fires from a fresh reading only, at most once a day, and re-arms after it's dealt with —
/// so an alert is never stale or wrong. The deciding is pure and unit-tested.
enum SmartAlerts {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case screenshots     // more than N screenshots in Photos
        case lowSpace        // less than N GB free on the phone
        case bigVideos       // videos in Photos take more than N GB
        var id: String { rawValue }

        var title: String {
            switch self {
            case .screenshots: return "When my screenshots pile up"
            case .lowSpace: return "When my phone is running out of space"
            case .bigVideos: return "When videos take up a lot of space"
            }
        }
        /// The sentence around the number: "Tell me when I have more than ___ screenshots".
        var sentence: (before: String, after: String) {
            switch self {
            case .screenshots: return ("Tell me when I have more than", "screenshots")
            case .lowSpace: return ("Tell me when my phone has less than", "GB free")
            case .bigVideos: return ("Tell me when videos in Photos take more than", "GB")
            }
        }
        var choices: [Double] {
            switch self {
            case .screenshots: return [100, 150, 200, 500]
            case .lowSpace: return [2, 5, 10, 20]
            case .bigVideos: return [5, 10, 20, 50]
            }
        }
        var defaultLimit: Double { choices[0] == 2 ? 5 : choices[0] }
        /// Above the limit is the problem (screenshots, videos) — or below it (free space).
        var firesAbove: Bool { self != .lowSpace }
        var needsPhotos: Bool { self != .lowSpace }
        /// The tool a tap on the alert opens.
        var opens: String { "cleaner" }
    }

    struct Rule: Codable, Equatable, Identifiable {
        var kind: SmartAlerts.Kind
        var limit: Double
        var on = true
        var lastFired: Date?
        var lastChecked: Date?
        var lastValue: Double?
        var id: String { kind.rawValue }
    }

    // MARK: - Deciding (pure)

    static func crossed(_ r: Rule, value: Double) -> Bool { r.kind.firesAbove ? value > r.limit : value < r.limit }

    /// Fire now? Only when on, the fresh value is past the limit, and it hasn't fired in the last 20 hours.
    static func shouldFire(_ r: Rule, value: Double, now: Date = Date()) -> Bool {
        guard r.on, crossed(r, value: value) else { return false }
        if let last = r.lastFired, now.timeIntervalSince(last) < 20 * 3600 { return false }
        return true
    }

    static func number(_ v: Double, _ k: Kind) -> String {
        k == .screenshots ? String(Int(v)) : (v < 10 ? String(format: "%.1f", v) : String(Int(v.rounded())))
    }

    /// The exact words of the alert, with the person's own numbers.
    static func message(_ k: Kind, value: Double, limit: Double) -> (title: String, body: String) {
        switch k {
        case .screenshots:
            let keep = Int(limit)
            return ("You have \(Int(value)) screenshots",
                    "That's past your \(keep). Want to review them and keep only your newest \(keep)? Tap to see them — nothing is deleted until you say so.")
        case .lowSpace:
            return ("Only \(number(value, k)) GB free on your phone",
                    "Below your \(number(limit, k)) GB. Tap to see the biggest videos, duplicates and old screenshots you could clear.")
        case .bigVideos:
            return ("Videos are taking about \(number(value, k)) GB",
                    "More than your \(number(limit, k)) GB. Tap to see the biggest ones first and free up space.")
        }
    }

    // MARK: - Reading the phone

    static func photosAllowed() -> Bool {
        let s = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return s == .authorized || s == .limited
    }
    static var photosLimited: Bool { PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited }

    /// The current value for a rule, or nil when it can't be read honestly right now.
    static func read(_ k: Kind) -> Double? {
        switch k {
        case .lowSpace:
            let url = URL(fileURLWithPath: NSHomeDirectory())
            guard let v = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage else { return nil }
            return Double(v) / 1_000_000_000
        case .screenshots:
            guard photosAllowed() else { return nil }
            let o = PHFetchOptions()
            o.predicate = NSPredicate(format: "(mediaSubtype & %d) != 0", Int(PHAssetMediaSubtype.photoScreenshot.rawValue))
            return Double(PHAsset.fetchAssets(with: .image, options: o).count)
        case .bigVideos:
            guard photosAllowed() else { return nil }
            var bytes: Int64 = 0
            PHAsset.fetchAssets(with: .video, options: nil).enumerateObjects { a, _, _ in bytes += Int64(PhotoCleaner.estimatedBytes(of: a)) }
            return Double(bytes) / 1_000_000_000
        }
    }

    // MARK: - Running checks

    static let taskID = "com.tenzy.toolkit.smartalerts"

    /// Check every rule that's on; post an alert for each that should fire. Safe to call often.
    static func checkAll(now: Date = Date()) async {
        var rules = AlertStore.load()
        guard rules.contains(where: \.on) else { return }
        let allowed = await NotifyPermission.state() == .allowed
        for i in rules.indices where rules[i].on {
            guard let v = read(rules[i].kind) else { continue }
            rules[i].lastChecked = now; rules[i].lastValue = v
            if allowed, shouldFire(rules[i], value: v, now: now) {
                post(rules[i].kind, value: v, limit: rules[i].limit)
                rules[i].lastFired = now
            }
        }
        AlertStore.save(rules)
    }

    static func post(_ k: Kind, value: Double, limit: Double, test: Bool = false) {
        let m = message(k, value: value, limit: limit)
        let c = UNMutableNotificationContent()
        c.title = (test ? "Test · " : "") + m.title
        c.body = m.body
        c.sound = .default
        c.userInfo = ["open": k.opens]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "smart-\(k.rawValue)-\(UUID().uuidString)", content: c, trigger: nil))
    }

    /// Register the background check (call once at launch) and ask iPhone for the next one.
    static func registerBackground() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            scheduleBackground()
            let work = Task { await checkAll(); task.setTaskCompleted(success: true) }
            task.expirationHandler = { work.cancel() }
        }
    }

    static func scheduleBackground() {
        guard AlertStore.load().contains(where: \.on) else { return }
        let r = BGAppRefreshTaskRequest(identifier: taskID)
        r.earliestBeginDate = Date().addingTimeInterval(3 * 3600)
        try? BGTaskScheduler.shared.submit(r)
    }

    /// iPhone's Background App Refresh: when it's off, count alerts only check while Tenzy is open.
    @MainActor static var backgroundOff: Bool { UIApplication.shared.backgroundRefreshStatus != .available }
}

/// The rules, kept in the app's own settings (they hold only kinds and numbers — nothing personal).
enum AlertStore {
    private static let key = "smartalerts.rules"
    static func load() -> [SmartAlerts.Rule] {
        guard let d = UserDefaults.standard.data(forKey: key), let r = try? JSONDecoder().decode([SmartAlerts.Rule].self, from: d) else { return [] }
        return r
    }
    static func save(_ r: [SmartAlerts.Rule]) {
        if let d = try? JSONEncoder().encode(r) { UserDefaults.standard.set(d, forKey: key) }
    }
    static func rule(_ k: SmartAlerts.Kind) -> SmartAlerts.Rule? { load().first { $0.kind == k } }
    /// Save a rule from the card. Keeps what the checks recorded (last checked / fired) unless the limit
    /// changed — a new limit re-arms the alert so it can fire for the new number.
    static func upsert(_ rule: SmartAlerts.Rule) {
        let all = load()
        var r = rule
        if let old = all.first(where: { $0.kind == rule.kind }) {
            r.lastChecked = old.lastChecked; r.lastValue = old.lastValue
            r.lastFired = old.limit == rule.limit ? old.lastFired : nil
        }
        save(all.filter { $0.kind != rule.kind } + [r])
    }
}
