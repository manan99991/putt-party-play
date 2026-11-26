import Foundation
import Contacts

/// Smart autorun: back up my contacts every week (26 Nov). A dated copy of every contact goes into Files (Tenzy ›
/// Contact Backups, and iCloud Drive when it's on), and it's compared with the copy before it: who's new, and — the part
/// that matters — who has gone. A contact deleted by mistake, or lost when an account was removed, comes back with one
/// tap from the copy it was in. Nothing is sent anywhere; emailing a copy to yourself is one tap, and you press Send.
enum SmartContacts {
    /// One contact as the backup holds it: a name to show, what identifies them, and their whole card (to restore).
    struct Person: Codable, Equatable, Hashable {
        var name: String
        var phones: [String]          // last 10 digits
        var emails: [String]          // lowercased
        var card: String              // the contact's own vCard, exactly as backed up
    }

    struct Report: Codable, Equatable {
        var file: String              // the backup's file name in Contact Backups
        var at: Date
        var total: Int
        var added: [String]           // names new since the copy before
        var gone: [Person]            // in the copy before, not now
        var restored: [String] = []   // names brought back from this report
        var waiting: [Person] { gone.filter { !restored.contains($0.name) } }
    }

    // MARK: pure

    /// Every contact in a .vcf, each with its own card text. Folded lines are unfolded; a card without a full name
    /// takes it from N (Last;First), then the organisation, then a phone or email.
    static func people(fromVCard text: String) -> [Person] {
        let unfolded = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\n ", with: "").replacingOccurrences(of: "\n\t", with: "")
        var out: [Person] = []
        var current: [String] = []
        for line in unfolded.components(separatedBy: "\n") {
            if line.uppercased().hasPrefix("BEGIN:VCARD") { current = [line]; continue }
            guard !current.isEmpty else { continue }
            current.append(line)
            if line.uppercased().hasPrefix("END:VCARD") {
                out.append(person(current)); current = []
            }
        }
        return out
    }

    private static func person(_ lines: [String]) -> Person {
        func value(_ l: String) -> String {
            guard let i = l.firstIndex(of: ":") else { return "" }
            return String(l[l.index(after: i)...]).replacingOccurrences(of: "\\,", with: ",").replacingOccurrences(of: "\\;", with: ";").trimmingCharacters(in: .whitespaces)
        }
        func prop(_ l: String) -> String {
            let head = l.split(separator: ":", maxSplits: 1).first.map(String.init) ?? ""
            let name = head.split(separator: ";").first.map(String.init) ?? head
            return (name.split(separator: ".").last.map(String.init) ?? name).uppercased()   // "item1.TEL" → "TEL"
        }
        var fn = "", n = "", org = ""
        var phones: [String] = [], emails: [String] = []
        for l in lines {
            switch prop(l) {
            case "FN": fn = value(l)
            case "N": n = value(l).split(separator: ";", omittingEmptySubsequences: false).prefix(2).reversed().map(String.init).filter { !$0.isEmpty }.joined(separator: " ")
            case "ORG": org = value(l).replacingOccurrences(of: ";", with: " ").trimmingCharacters(in: .whitespaces)
            case "TEL": let d = String(value(l).filter(\.isNumber).suffix(10)); if d.count >= 7 { phones.append(d) }
            case "EMAIL": let e = value(l).lowercased(); if e.contains("@") { emails.append(e) }
            default: break
            }
        }
        let name = [fn, n, org, emails.first ?? "", phones.first ?? ""].first { !$0.isEmpty } ?? ""
        return Person(name: name, phones: phones, emails: emails, card: lines.joined(separator: "\r\n") + "\r\n")
    }

    /// The same person in both copies: the same name, or a shared phone number or email (so a renamed or edited
    /// contact is neither "gone" nor "new").
    static func same(_ a: Person, _ b: Person) -> Bool {
        let na = a.name.lowercased().filter { $0.isLetter || $0.isNumber }, nb = b.name.lowercased().filter { $0.isLetter || $0.isNumber }
        if !na.isEmpty, na == nb { return true }
        return !Set(a.phones).isDisjoint(with: b.phones) || !Set(a.emails).isDisjoint(with: b.emails)
    }

    static func diff(old: [Person], new: [Person]) -> (added: [Person], gone: [Person]) {
        (new.filter { n in !old.contains { same($0, n) } }, old.filter { o in !new.contains { same(o, $0) } })
    }

    // MARK: on the phone

    /// The same Files folder the Contacts tool's backups use, so every copy is in one place.
    static var folder: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Contact Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private static func backups() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files.filter { $0.pathExtension.lowercased() == "vcf" }.sorted {
            ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast)
                > ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast)
        }
    }

    /// Makes this week's copy and compares it with the last one. nil without Contacts access.
    static func backup() async -> Report? {
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else { return nil }
        let before = backups().first
        guard let temp = try? await Task.detached(priority: .utility, operation: { try ContactsEngine.exportVCard() }).value,
              let data = try? Data(contentsOf: temp) else { return nil }
        defer { try? FileManager.default.removeItem(at: temp) }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd-HHmm"
        let name = "Contacts-\(f.string(from: Date())).vcf"
        let dest = folder.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dest)
        guard (try? data.write(to: dest, options: .atomic)) != nil else { return nil }
        if let cloud = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents", isDirectory: true) {
            try? FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: cloud.appendingPathComponent(name))
            try? FileManager.default.copyItem(at: dest, to: cloud.appendingPathComponent(name))
        }
        // Keep the last eight copies (two months of weeks).
        for old in backups().dropFirst(8) { try? FileManager.default.removeItem(at: old) }
        let now = people(fromVCard: String(decoding: data, as: UTF8.self))
        var added: [Person] = [], gone: [Person] = []
        if let before, before != dest, let old = try? String(contentsOf: before, encoding: .utf8) {
            (added, gone) = diff(old: people(fromVCard: old), new: now)
        }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "contacts.backup.last")
        return Report(file: name, at: Date(), total: now.count, added: added.map(\.name), gone: gone)
    }

    /// Brings a contact back from the copy it was in. False if Contacts refused it.
    static func restore(_ p: Person) -> Bool {
        guard let data = p.card.data(using: .utf8), let c = try? CNContactVCardSerialization.contacts(with: data).first,
              let m = c.mutableCopy() as? CNMutableContact else { return false }
        let req = CNSaveRequest(); req.add(m, toContainerWithIdentifier: nil)
        do { try CNContactStore().execute(req); return true } catch { return false }
    }
}
