import Foundation
import SwiftUI
import UserNotifications

/// How often contacts are backed up automatically.
enum BackupFrequency: String, CaseIterable, Codable {
    case off, weekly, monthly, quarterly, yearly
    var title: String {
        switch self { case .off: return "Off"; case .weekly: return "Weekly"; case .monthly: return "Monthly"; case .quarterly: return "Quarterly"; case .yearly: return "Yearly" }
    }
    var days: Int? {
        switch self { case .off: return nil; case .weekly: return 7; case .monthly: return 30; case .quarterly: return 91; case .yearly: return 365 }
    }
}

/// Auto-backup for contacts: on the schedule the user picks, write a dated .vcf into the app's
/// Documents folder (so it shows up in the Files app and syncs with the device backup) and, when the
/// device has it, iCloud Drive — then remind the user so they can also email themselves a copy. iOS
/// won't let an app send mail silently, so "email" is a one-tap composer, not a background send.
@MainActor final class ContactsBackup: ObservableObject {
    @Published var frequency: BackupFrequency {
        didSet { UserDefaults.standard.set(frequency.rawValue, forKey: Keys.freq); if frequency != .off { scheduleReminder() } else { cancelReminder() } }
    }
    @Published private(set) var lastBackup: Date?
    @Published private(set) var lastBackupURL: URL?

    private enum Keys { static let freq = "contacts.backup.freq"; static let last = "contacts.backup.last" }

    init() {
        frequency = BackupFrequency(rawValue: UserDefaults.standard.string(forKey: Keys.freq) ?? "") ?? .off
        let t = UserDefaults.standard.double(forKey: Keys.last)
        lastBackup = t > 0 ? Date(timeIntervalSince1970: t) : nil
        lastBackupURL = Self.latestBackup()
    }

    /// The Files-visible folder where backups are kept.
    static var folder: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Contact Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// Pure, testable: is a backup due now given the last run and the chosen cadence?
    static func isDue(last: Date?, frequency: BackupFrequency, now: Date = Date()) -> Bool {
        guard let days = frequency.days else { return false }   // .off
        guard let last else { return true }                      // never backed up → due
        return now.timeIntervalSince(last) >= Double(days) * 86_400
    }

    func isDue(now: Date = Date()) -> Bool { Self.isDue(last: lastBackup, frequency: frequency, now: now) }

    /// Run a backup now: export every contact, save a dated copy to Documents (and iCloud if available),
    /// prune to the last few, record the time, and re-arm the reminder. Returns the saved file.
    @discardableResult
    func runBackup() async throws -> URL {
        let temp = try await Task.detached { try ContactsEngine.exportVCard() }.value   // all contacts → temp .vcf
        let name = "Contacts-\(Self.stamp()).vcf"
        let dest = Self.folder.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: temp, to: dest)
        copyToICloud(from: dest, name: name)
        prune()

        lastBackup = Date(); lastBackupURL = dest
        UserDefaults.standard.set(lastBackup!.timeIntervalSince1970, forKey: Keys.last)
        if frequency != .off { scheduleReminder() }
        return dest
    }

    /// Mirror a copy into the app's iCloud Drive container if the device has iCloud Documents on.
    private func copyToICloud(from url: URL, name: String) {
        guard let base = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents", isDirectory: true) else { return }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let dest = base.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: url, to: dest)
    }

    /// Keep the five most recent backups; delete older ones so the folder doesn't grow forever.
    private func prune(keep: Int = 5) {
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let sorted = files.sorted { (mod($0) ?? .distantPast) > (mod($1) ?? .distantPast) }
        for f in sorted.dropFirst(keep) { try? FileManager.default.removeItem(at: f) }
    }
    private func mod(_ u: URL) -> Date? { (try? u.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate }

    private static func latestBackup() -> URL? {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files.sorted { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast)
                            > ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast) }.first
    }

    private static func stamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd-HHmm"; return f.string(from: Date())
    }

    // MARK: reminder

    private func scheduleReminder() {
        guard let days = frequency.days else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            center.removePendingNotificationRequests(withIdentifiers: ["contacts-backup"])
            let c = UNMutableNotificationContent()
            c.title = "Back up your contacts"
            c.body = "It's been \(self.frequency.title.lowercased()). Open Contacts to save a fresh copy or email it to yourself."
            c.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(days) * 86_400, repeats: false)
            center.add(UNNotificationRequest(identifier: "contacts-backup", content: c, trigger: trigger))
        }
    }
    private func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["contacts-backup"])
    }
}
