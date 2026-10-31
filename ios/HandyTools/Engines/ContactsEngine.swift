import Contacts
import Foundation

/// One contact, flattened for duplicate detection and merge.
struct ContactRec: Identifiable {
    let id: String              // CNContact.identifier
    var name: String
    var numbers: [String]
    var emails: [String]

    var hasName: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    var hasNumber: Bool { !numbers.isEmpty }
    func normName() -> String { name.lowercased().filter { $0.isLetter || $0.isNumber } }
    func normNumbers() -> [String] { numbers.map { String($0.filter(\.isNumber).suffix(10)) }.filter { $0.count >= 7 } }
    var whyIncomplete: String { !hasName && !hasNumber ? "No name or number" : !hasName ? "No name" : "No phone number" }
    var subtitle: String { [numbers.first, emails.first].compactMap { $0 }.joined(separator: " · ") }
}

struct ContactSource: Identifiable { let id = UUID(); let name: String; let count: Int }

struct ContactsReport {
    let total: Int
    let duplicateGroups: [[ContactRec]]
    let incomplete: [ContactRec]
    // Health buckets, each a tidy-up list with simple fixes.
    let noPhone: [ContactRec]       // has a name, but no number
    let emailOnly: [ContactRec]     // no number, only an email
    let noName: [ContactRec]        // a number/email with no name
    let empty: [ContactRec]         // neither name nor number — usually safe to delete
    let sources: [ContactSource]    // where they came from (iCloud / Exchange / On My iPhone…)
    var duplicateCount: Int { duplicateGroups.reduce(0) { $0 + $1.count - 1 } }

    /// Categorise a flat list — pure, so it's unit-testable without the contact store.
    static func categorize(total: Int, recs: [ContactRec], groups: [[ContactRec]], sources: [ContactSource]) -> ContactsReport {
        ContactsReport(total: total,
                       duplicateGroups: groups,
                       incomplete: recs.filter { !$0.hasName || !$0.hasNumber },
                       noPhone: recs.filter { $0.hasName && !$0.hasNumber },
                       emailOnly: recs.filter { !$0.hasNumber && !$0.emails.isEmpty },
                       noName: recs.filter { !$0.hasName && ($0.hasNumber || !$0.emails.isEmpty) },
                       empty: recs.filter { !$0.hasName && !$0.hasNumber && $0.emails.isEmpty },
                       sources: sources)
    }
}

/// Contacts cleanup on iOS: find duplicates + incomplete entries, merge without losing data, and
/// export a .vcf backup. All on-device via the Contacts framework. A merge is permanent (iOS has no
/// contact trash), so the UI backs up first and confirms every merge.
enum ContactsEngine {
    private static var fetchKeys: [CNKeyDescriptor] {
        [CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
         CNContactGivenNameKey as CNKeyDescriptor,
         CNContactFamilyNameKey as CNKeyDescriptor,
         CNContactOrganizationNameKey as CNKeyDescriptor,
         CNContactPhoneNumbersKey as CNKeyDescriptor,
         CNContactEmailAddressesKey as CNKeyDescriptor]
    }

    static func authorized() -> Bool { CNContactStore.authorizationStatus(for: .contacts) == .authorized }

    static func requestAccess() async -> Bool {
        (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
    }

    static func scan() -> ContactsReport {
        let store = CNContactStore()
        var recs: [ContactRec] = []
        let req = CNContactFetchRequest(keysToFetch: fetchKeys)
        try? store.enumerateContacts(with: req) { c, _ in
            let name = CNContactFormatter.string(from: c, style: .fullName) ?? c.organizationName
            recs.append(ContactRec(id: c.identifier,
                                   name: name ?? "",
                                   numbers: c.phoneNumbers.map { $0.value.stringValue },
                                   emails: c.emailAddresses.map { $0.value as String }))
        }

        var groups: [[ContactRec]] = []
        var seen = Set<String>()

        // Group by normalized display name.
        let byName = Dictionary(grouping: recs.filter { !$0.normName().isEmpty }) { $0.normName() }
        for g in byName.values where g.count > 1 { groups.append(g); g.forEach { seen.insert($0.id) } }

        // Then group the rest by a shared normalized phone number.
        var byNum: [String: [ContactRec]] = [:]
        for r in recs where !seen.contains(r.id) {
            for n in r.normNumbers() { byNum[n, default: []].append(r) }
        }
        for bucket in byNum.values {
            var uniq: [ContactRec] = []
            var ids = Set<String>()
            for r in bucket where ids.insert(r.id).inserted { uniq.append(r) }
            if uniq.count > 1 && uniq.allSatisfy({ !seen.contains($0.id) }) {
                groups.append(uniq); uniq.forEach { seen.insert($0.id) }
            }
        }

        return ContactsReport.categorize(total: recs.count, recs: recs, groups: groups, sources: sources(store: store))
    }

    /// Where contacts live (iCloud / an account / On My iPhone), as counts for the tidy-up summary.
    private static func sources(store: CNContactStore) -> [ContactSource] {
        guard let containers = try? store.containers(matching: nil) else { return [] }
        var out: [ContactSource] = []
        for c in containers {
            let pred = CNContact.predicateForContactsInContainer(withIdentifier: c.identifier)
            let n = (try? store.unifiedContacts(matching: pred, keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]).count) ?? 0
            if n > 0 { out.append(ContactSource(name: sourceName(c), count: n)) }
        }
        return out.sorted { $0.count > $1.count }
    }
    private static func sourceName(_ c: CNContainer) -> String {
        if !c.name.isEmpty { return c.name }
        switch c.type {
        case .local:    return "On My iPhone"
        case .exchange: return "Exchange"
        case .cardDAV:  return "iCloud / account"
        default:        return "Other"
        }
    }

    /// Permanently delete contacts by id (used for the "empty" tidy-up bucket). Caller confirms + backs up.
    static func delete(ids: [String]) throws {
        let store = CNContactStore(); let save = CNSaveRequest()
        for id in ids {
            if let c = try? store.unifiedContact(withIdentifier: id, keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]),
               let m = c.mutableCopy() as? CNMutableContact { save.delete(m) }
        }
        try store.execute(save)
    }

    /// Export a specific set of contacts to a .vcf (a single tidy-up bucket, or a saved-search backup).
    static func exportVCard(ids: [String], label: String) throws -> URL {
        let store = CNContactStore()
        let keys = [CNContactVCardSerialization.descriptorForRequiredKeys()]
        let contacts = ids.compactMap { try? store.unifiedContact(withIdentifier: $0, keysToFetch: keys) }
        let data = try CNContactVCardSerialization.data(with: contacts)
        let safe = label.replacingOccurrences(of: " ", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Contacts-\(safe)-\(Int(Date().timeIntervalSince1970)).vcf")
        try data.write(to: url); return url
    }

    /// Merge a duplicate group: build one contact with the union of names/numbers/emails, then remove
    /// the originals. Permanent — the caller must confirm and should back up first.
    static func merge(_ group: [ContactRec]) throws {
        guard group.count > 1 else { return }
        let store = CNContactStore()
        let members = group.compactMap { try? store.unifiedContact(withIdentifier: $0.id, keysToFetch: fetchKeys) }
        guard members.count > 1 else { return }

        let merged = CNMutableContact()
        let named = members.first { !$0.givenName.isEmpty || !$0.familyName.isEmpty } ?? members[0]
        merged.givenName = named.givenName
        merged.familyName = named.familyName
        merged.organizationName = members.first { !$0.organizationName.isEmpty }?.organizationName ?? ""

        var nums = Set<String>(); var mails = Set<String>()
        for m in members {
            for p in m.phoneNumbers where nums.insert(p.value.stringValue).inserted { merged.phoneNumbers.append(p) }
            for e in m.emailAddresses where mails.insert(e.value as String).inserted { merged.emailAddresses.append(e) }
        }

        let save = CNSaveRequest()
        save.add(merged, toContainerWithIdentifier: nil)
        for m in members { if let del = m.mutableCopy() as? CNMutableContact { save.delete(del) } }
        try store.execute(save)
    }

    /// Export every contact to a .vcf backup file and return its URL (to share or save).
    static func exportVCard() throws -> URL {
        let store = CNContactStore()
        var all: [CNContact] = []
        let req = CNContactFetchRequest(keysToFetch: [CNContactVCardSerialization.descriptorForRequiredKeys()])
        try store.enumerateContacts(with: req) { c, _ in all.append(c) }
        let data = try CNContactVCardSerialization.data(with: all)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Contacts-backup-\(Int(Date().timeIntervalSince1970)).vcf")
        try data.write(to: url)
        return url
    }
}
