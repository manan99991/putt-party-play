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

struct ContactsReport {
    let total: Int
    let duplicateGroups: [[ContactRec]]
    let incomplete: [ContactRec]
    var duplicateCount: Int { duplicateGroups.reduce(0) { $0 + $1.count - 1 } }
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

        let incomplete = recs.filter { !$0.hasName || !$0.hasNumber }
        return ContactsReport(total: recs.count, duplicateGroups: groups, incomplete: incomplete)
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
