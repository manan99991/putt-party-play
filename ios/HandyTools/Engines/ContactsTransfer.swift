import Contacts
import Foundation

/// A place contacts live: iCloud, a Gmail/Google account, Exchange, or On My iPhone.
struct ContactAccount: Identifiable, Hashable {
    let id: String          // CNContainer.identifier
    let name: String
    let kind: String        // "iCloud", "Google / other account", "Exchange", "On this phone"
    let count: Int
    /// iOS lets apps add to every container; a container with no policy to write is still tried and reports failure.
    var title: String { name.isEmpty || name == kind ? kind : "\(name) · \(kind)" }
}

/// Copy or move contacts between accounts (for example Gmail to iCloud, or the phone into Gmail), on-device.
/// Copy is the default and never touches the originals. Move removes them only after the copy is saved.
enum ContactsTransfer {
    struct Item: Equatable { let id: String; let name: String; let numbers: [String]; let emails: [String] }
    struct Outcome: Equatable { var copied = 0; var alreadyThere = 0; var failed = 0; var removed = 0 }

    // MARK: pure matching (unit-tested)

    static func normName(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }
    static func digits(_ n: String) -> String { String(n.filter(\.isNumber).suffix(10)) }

    /// Same person already in the target: same name AND a shared number or email (or nothing else to compare).
    static func same(_ a: Item, _ b: Item) -> Bool {
        let an = a.numbers.map(digits).filter { $0.count >= 7 }, bn = b.numbers.map(digits).filter { $0.count >= 7 }
        let ae = a.emails.map { $0.lowercased() }, be = b.emails.map { $0.lowercased() }
        let shared = !Set(an).isDisjoint(with: bn) || !Set(ae).isDisjoint(with: be)
        let na = normName(a.name), nb = normName(b.name)
        if na.isEmpty || nb.isEmpty { return shared }
        if na != nb { return false }
        return shared || (an.isEmpty && ae.isEmpty && bn.isEmpty && be.isEmpty)
    }

    static func plan(source: [Item], existing: [Item]) -> (copy: [Item], present: [Item]) {
        var copy: [Item] = [], present: [Item] = []
        var seen = existing
        for s in source {
            if seen.contains(where: { same(s, $0) }) { present.append(s) } else { copy.append(s); seen.append(s) }
        }
        return (copy, present)
    }

    // MARK: accounts

    private static let keys: [CNKeyDescriptor] = [
        CNContactVCardSerialization.descriptorForRequiredKeys(),
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
        CNContactPhoneNumbersKey as CNKeyDescriptor, CNContactEmailAddressesKey as CNKeyDescriptor,
    ]

    static func accounts() -> [ContactAccount] {
        let store = CNContactStore()
        guard let containers = try? store.containers(matching: nil) else { return [] }
        return containers.map { c in
            let n = (try? store.unifiedContacts(matching: CNContact.predicateForContactsInContainer(withIdentifier: c.identifier),
                                                keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]).count) ?? 0
            return ContactAccount(id: c.identifier, name: c.name, kind: kind(c.type), count: n)
        }.sorted { $0.count > $1.count }
    }

    private static func kind(_ t: CNContainerType) -> String {
        switch t { case .local: return "On this phone"; case .exchange: return "Exchange"; case .cardDAV: return "iCloud or an online account"; default: return "Other" }
    }

    private static func contacts(in id: String, store: CNContactStore) -> [CNContact] {
        let req = CNContactFetchRequest(keysToFetch: keys)
        req.predicate = CNContact.predicateForContactsInContainer(withIdentifier: id)
        req.unifyResults = false
        var out: [CNContact] = []
        try? store.enumerateContacts(with: req) { c, _ in out.append(c) }
        return out
    }

    private static func item(_ c: CNContact) -> Item {
        Item(id: c.identifier, name: CNContactFormatter.string(from: c, style: .fullName) ?? c.organizationName,
             numbers: c.phoneNumbers.map { $0.value.stringValue }, emails: c.emailAddresses.map { $0.value as String })
    }

    // MARK: transfer

    /// Copies (or moves) everything in `from` into `to`, skipping people already there.
    static func transfer(from: String, to: String, move: Bool, progress: ((Double) -> Void)? = nil) -> Outcome {
        let store = CNContactStore()
        let source = contacts(in: from, store: store)
        let existing = contacts(in: to, store: store).map(item)
        let byId = Dictionary(uniqueKeysWithValues: source.map { ($0.identifier, $0) })
        let p = plan(source: source.map(item), existing: existing)

        var out = Outcome(); out.alreadyThere = p.present.count
        var savedIds: [String] = []
        let total = max(1, p.copy.count)
        for (i, it) in p.copy.enumerated() {
            if let c = byId[it.id], addCopy(c, to: to, store: store) { out.copied += 1; savedIds.append(it.id) } else { out.failed += 1 }
            if i % 20 == 0 { progress?(Double(i) / Double(total)) }
        }
        if move {
            // Remove an original only if its copy is saved or it was already in the target.
            let safe = Set(savedIds + p.present.map(\.id))
            let del = CNSaveRequest()
            for id in safe { if let c = byId[id], let m = c.mutableCopy() as? CNMutableContact { del.delete(m) } }
            if (try? store.execute(del)) != nil { out.removed = safe.count }
        }
        progress?(1)
        return out
    }

    /// Round-trips through vCard so the copy is a fresh contact carrying names, numbers, emails, addresses and photo.
    private static func addCopy(_ c: CNContact, to container: String, store: CNContactStore) -> Bool {
        guard let data = try? CNContactVCardSerialization.data(with: [c]),
              let card = (try? CNContactVCardSerialization.contacts(with: data))?.first,
              let fresh = card.mutableCopy() as? CNMutableContact else { return false }
        let save = CNSaveRequest(); save.add(fresh, toContainerWithIdentifier: container)
        return (try? store.execute(save)) != nil
    }

    /// Put contacts from a .vcf file (for example Google's "Export as vCard") straight into an account.
    static func importVCard(_ url: URL, to container: String) -> Outcome {
        let store = CNContactStore()
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let cards = try? CNContactVCardSerialization.contacts(with: data) else { return Outcome(failed: 1) }
        let existing = contacts(in: container, store: store).map(item)
        let src = cards.enumerated().map { i, c in
            Item(id: String(i), name: CNContactFormatter.string(from: c, style: .fullName) ?? c.organizationName,
                 numbers: c.phoneNumbers.map { $0.value.stringValue }, emails: c.emailAddresses.map { $0.value as String })
        }
        let p = plan(source: src, existing: existing)
        var out = Outcome(); out.alreadyThere = p.present.count
        for it in p.copy {
            guard let i = Int(it.id), let m = cards[i].mutableCopy() as? CNMutableContact else { out.failed += 1; continue }
            let save = CNSaveRequest(); save.add(m, toContainerWithIdentifier: container)
            if (try? store.execute(save)) != nil { out.copied += 1 } else { out.failed += 1 }
        }
        return out
    }
}
