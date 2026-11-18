import Foundation
import CryptoKit
import CommonCrypto
import Security
import UserNotifications

/// My Day — a private diary of how each day went. Logging is instant and needs no password (Good / Bad,
/// or a voice note); reading the past needs the diary's own PIN (or Face ID once set up). Everything is
/// encrypted on the phone with a key kept in the Keychain, never uploaded. A daily reminder can ask
/// "How was your day?" with Good / Bad buttons right on the notification.
enum DayDiary {
    enum Mood: String, Codable { case good, bad }

    struct Note: Codable, Equatable, Identifiable {
        var id = UUID()
        var at: Date
        var mood: Mood
        var audio: String?          // encrypted file name in the diary folder
        var seconds: Double = 0
        var transcript: String?
    }

    struct Day: Codable, Equatable {
        var key: String             // yyyy-MM-dd, the phone's own calendar day
        var mood: Mood
        var notes: [Note] = []
        var updated: Date
    }

    // MARK: - Calendar keys (pure)

    static func key(_ d: Date, cal: Calendar = .current) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// The weeks of a month for a calendar grid: nil = blank cell before the 1st / after the last day.
    static func monthGrid(year: Int, month: Int, cal: Calendar = .current) -> [[Int?]] {
        guard let first = cal.date(from: DateComponents(year: year, month: month, day: 1)),
              let days = cal.range(of: .day, in: .month, for: first)?.count else { return [] }
        let lead = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        var cells: [Int?] = Array(repeating: nil, count: lead) + (1...days).map { Optional($0) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    /// Good and bad days in a set of days, for the month's summary line.
    static func tally(_ days: [Day]) -> (good: Int, bad: Int) {
        (days.filter { $0.mood == .good }.count, days.filter { $0.mood == .bad }.count)
    }

    /// The days in a row (ending today or yesterday) that were logged at all.
    static func streak(_ keys: Set<String>, today: Date = Date(), cal: Calendar = .current) -> Int {
        var d = today
        if !keys.contains(key(d, cal: cal)) { d = cal.date(byAdding: .day, value: -1, to: d) ?? d }
        var n = 0
        while keys.contains(key(d, cal: cal)) { n += 1; d = cal.date(byAdding: .day, value: -1, to: d) ?? d }
        return n
    }

    static func message(for mood: Mood) -> String {
        mood == .good ? "Saved. We hope tomorrow is just as beautiful." : "Saved. We hope tomorrow is kinder to you."
    }

    // MARK: - PIN and recovery (hashes only, never the PIN itself)

    static func hash(_ secret: String, salt: Data) -> Data {
        let normalized = secret.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().folding(options: .diacriticInsensitive, locale: nil)
        var out = Data(count: 32)
        let pw = Array(normalized.utf8).map { Int8(bitPattern: $0) }
        _ = out.withUnsafeMutableBytes { o in
            salt.withUnsafeBytes { s in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), pw, pw.count,
                                     s.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                     CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 120_000,
                                     o.bindMemory(to: UInt8.self).baseAddress, 32)
            }
        }
        return out
    }

    /// A PIN people can remember but not one a stranger guesses first.
    static func pinProblem(_ pin: String) -> String? {
        guard pin.count >= 4, pin.count <= 8, pin.allSatisfy(\.isNumber) else { return "Use 4 to 8 numbers." }
        if Set(pin).count == 1 { return "Too easy to guess — avoid one digit repeated." }
        let digits = pin.compactMap(\.wholeNumberValue)
        let up = zip(digits, digits.dropFirst()).allSatisfy { $1 == $0 + 1 }
        let down = zip(digits, digits.dropFirst()).allSatisfy { $1 == $0 - 1 }
        if up || down { return "Too easy to guess — avoid 1234-style runs." }
        return nil
    }

    static let questions = [
        "The street you grew up on",
        "Your first pet's name",
        "Your childhood best friend's first name",
        "The city where your parents met",
        "Your favourite teacher's last name",
        "A food you hated as a child",
    ]

    // MARK: - Reminder

    static let category = "DAYDIARY"
    static let goodAction = "DAYDIARY_GOOD"
    static let badAction = "DAYDIARY_BAD"
    static let reminderID = "daydiary-evening"

    static func registerCategory() -> UNNotificationCategory {
        UNNotificationCategory(identifier: category,
                               actions: [UNNotificationAction(identifier: goodAction, title: "🟢 Good day", options: []),
                                         UNNotificationAction(identifier: badAction, title: "🔴 Bad day", options: []),
                                         UNNotificationAction(identifier: "DAYDIARY_TALK", title: "🎙 Tell me about it", options: [.foreground])],
                               intentIdentifiers: [], options: [])
    }

    static func scheduleReminder(hour: Int, minute: Int) {
        let c = UNMutableNotificationContent()
        c.title = "How was your day?"
        c.body = "Tap Good or Bad — or tell Tenzy about it. Only you can read it back."
        c.sound = .default
        c.categoryIdentifier = category
        c.userInfo = ["open": "daydiary"]
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
        center.add(UNNotificationRequest(identifier: reminderID, content: c, trigger: trigger))
    }

    /// Answered from the notification without opening the app: a quiet "saved" note back.
    static func confirm(_ mood: Mood) {
        let c = UNMutableNotificationContent()
        c.title = "Saved to My Day"
        c.body = message(for: mood)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "daydiary-saved-\(UUID().uuidString)", content: c, trigger: nil))
    }

    static func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID])
    }
}

/// The diary on disk: one encrypted file per day plus encrypted recordings, in Application Support with
/// complete file protection. The data key lives in the Keychain (this device only, after first unlock), so
/// logging from a notification works without the PIN; reading back is gated by the PIN in the app.
final class DiaryStore {
    static let shared = DiaryStore()

    private let fm = FileManager.default
    private let service = "com.tenzy.daydiary"
    let folder: URL

    init(folder: URL? = nil) {
        let base = folder ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DayDiary", isDirectory: true)
        self.folder = base
        try? fm.createDirectory(at: base, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    }

    // MARK: key

    private var key: SymmetricKey {
        if let d = keychainGet("datakey"), d.count == 32 { return SymmetricKey(data: d) }
        let k = SymmetricKey(size: .bits256)
        keychainSet("datakey", k.withUnsafeBytes { Data($0) })
        return k
    }

    private func seal(_ d: Data) -> Data? { try? AES.GCM.seal(d, using: key).combined }
    private func open(_ d: Data) -> Data? { (try? AES.GCM.SealedBox(combined: d)).flatMap { try? AES.GCM.open($0, using: key) } }

    // MARK: days

    private func url(_ key: String) -> URL { folder.appendingPathComponent(key + ".day") }

    func day(_ key: String) -> DayDiary.Day? {
        guard let raw = try? Data(contentsOf: url(key)), let plain = open(raw) else { return nil }
        return try? JSONDecoder().decode(DayDiary.Day.self, from: plain)
    }

    func allKeys() -> Set<String> {
        let names = (try? fm.contentsOfDirectory(atPath: folder.path)) ?? []
        return Set(names.filter { $0.hasSuffix(".day") }.map { String($0.dropLast(4)) })
    }

    func days(inMonthOf year: Int, _ month: Int) -> [String: DayDiary.Day] {
        let prefix = String(format: "%04d-%02d-", year, month)
        var out: [String: DayDiary.Day] = [:]
        for k in allKeys() where k.hasPrefix(prefix) { if let d = day(k) { out[k] = d } }
        return out
    }

    /// One tap: today's mood (the latest tap wins). Returns the saved day.
    @discardableResult
    func log(_ mood: DayDiary.Mood, at date: Date = Date(), note: DayDiary.Note? = nil) -> DayDiary.Day? {
        let k = DayDiary.key(date)
        var d = day(k) ?? DayDiary.Day(key: k, mood: mood, updated: date)
        d.mood = mood; d.updated = date
        if let note { d.notes.append(note) }
        guard let json = try? JSONEncoder().encode(d), let sealed = seal(json) else { return nil }
        do { try sealed.write(to: url(k), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) } catch { return nil }
        return d
    }

    /// Keep a recording: encrypted copy in the diary folder; returns its stored name.
    func storeAudio(_ src: URL) -> String? {
        guard let data = try? Data(contentsOf: src), let sealed = seal(data) else { return nil }
        let name = UUID().uuidString + ".voice"
        do { try sealed.write(to: folder.appendingPathComponent(name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) } catch { return nil }
        try? fm.removeItem(at: src)
        return name
    }

    /// A playable (decrypted) temporary copy of a stored recording.
    func playable(_ name: String) -> URL? {
        guard let raw = try? Data(contentsOf: folder.appendingPathComponent(name)), let plain = open(raw) else { return nil }
        let u = fm.temporaryDirectory.appendingPathComponent("diary-\(UUID().uuidString).m4a")
        return (try? plain.write(to: u, options: .completeFileProtection)) != nil ? u : nil
    }

    func update(_ d: DayDiary.Day) {
        guard let json = try? JSONEncoder().encode(d), let sealed = seal(json) else { return }
        try? sealed.write(to: url(d.key), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    // MARK: PIN, recovery, reminder time

    var hasPIN: Bool { keychainGet("pin") != nil }

    func setPIN(_ pin: String, question: String, answer: String) {
        let salt = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        keychainSet("salt", salt)
        keychainSet("pin", DayDiary.hash(pin, salt: salt))
        keychainSet("answer", DayDiary.hash(answer, salt: salt))
        keychainSet("question", Data(question.utf8))
    }

    func changePIN(_ pin: String) {
        guard let salt = keychainGet("salt") else { return }
        keychainSet("pin", DayDiary.hash(pin, salt: salt))
    }

    func check(pin: String) -> Bool {
        guard let salt = keychainGet("salt"), let stored = keychainGet("pin") else { return false }
        return DayDiary.hash(pin, salt: salt) == stored
    }

    func check(answer: String) -> Bool {
        guard let salt = keychainGet("salt"), let stored = keychainGet("answer") else { return false }
        return DayDiary.hash(answer, salt: salt) == stored
    }

    var question: String? { keychainGet("question").flatMap { String(data: $0, encoding: .utf8) } }

    var useFaceID: Bool {
        get { UserDefaults.standard.bool(forKey: "daydiary.faceid") }
        set { UserDefaults.standard.set(newValue, forKey: "daydiary.faceid") }
    }

    // MARK: keychain

    private func keychainGet(_ account: String) -> Data? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecReturnData as String: true]
        var out: CFTypeRef?
        return SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
    }

    private func keychainSet(_ account: String, _ data: Data) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock   // moves with an encrypted backup to a new phone
        SecItemAdd(add as CFDictionary, nil)
    }
}
