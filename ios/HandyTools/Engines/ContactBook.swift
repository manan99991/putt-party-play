import Foundation
import Contacts
import UserNotifications
import UIKit

/// Contacts Pro: every contact flattened into something easy to search, filter, group, tag and export.
/// Reading and writing go through Apple's Contacts framework on the phone; nothing is uploaded.
/// The deciding (search, filters, CSV, birthdays, leave-by times) is pure and unit-tested.
enum ContactBook {
    struct Labeled: Hashable { var label: String; var value: String }

    struct Person: Identifiable, Hashable {
        var id: String
        var given = ""
        var family = ""
        var company = ""
        var title = ""
        var phones: [Labeled] = []
        var emails: [Labeled] = []
        var addresses: [Labeled] = []
        var socials: [Labeled] = []        // service → username ("Facebook" → "jane.d")
        var urls: [String] = []
        var birthday: DateComponents?
        var hasPhoto = false
        var account = ""                   // iCloud, Gmail, Outlook, On My iPhone…
        var groups: [String] = []          // group ids

        var name: String {
            let n = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
            return n.isEmpty ? (company.isEmpty ? (phones.first?.value ?? emails.first?.value ?? "No name") : company) : n
        }
        var initials: String {
            let parts = [given, family].filter { !$0.isEmpty }
            let s = parts.isEmpty ? String(name.prefix(1)) : parts.map { String($0.prefix(1)) }.joined()
            return s.uppercased()
        }
        var sortKey: String { (family.isEmpty ? name : family + " " + given).lowercased() }
    }

    /// The one-tap filters. Each is plain words a person would use, and most come in pairs — "No phone" and its
    /// opposite "Has a phone" — so any contact can be found from either side.
    enum Filter: String, CaseIterable, Identifiable {
        case favorite, emergency, important
        case noPhone, hasPhone, noEmail, hasEmail, noFirst, hasFirst, noLast, hasLast, noCompany, company
        case noPhoto, hasPhoto, noBirthday, birthday, noAddress, hasAddress, emailOnly, phoneOnly, noMobile, mobile
        case work, home, social
        var id: String { rawValue }
        var title: String {
            switch self {
            case .favorite: return "Favorites"
            case .emergency: return "Emergency"
            case .important: return "Important"
            case .noPhone: return "No phone number"
            case .hasPhone: return "Has a phone number"
            case .noEmail: return "No email"
            case .hasEmail: return "Has an email"
            case .noFirst: return "No first name"
            case .hasFirst: return "Has a first name"
            case .noLast: return "No last name"
            case .hasLast: return "Has a last name"
            case .noCompany: return "No company"
            case .company: return "Has a company"
            case .noPhoto: return "No photo"
            case .hasPhoto: return "Has a photo"
            case .noBirthday: return "No birthday"
            case .birthday: return "Has a birthday"
            case .noAddress: return "No address"
            case .hasAddress: return "Has an address"
            case .emailOnly: return "Only an email"
            case .phoneOnly: return "Only a phone number"
            case .noMobile: return "No mobile number"
            case .mobile: return "Has a mobile number"
            case .work: return "Work"
            case .home: return "Home"
            case .social: return "Social media"
            }
        }
        var icon: String {
            switch self {
            case .favorite: return "star.fill"
            case .emergency: return "cross.case.fill"
            case .important: return "exclamationmark.circle.fill"
            case .noPhone: return "phone.down"
            case .hasPhone: return "phone.fill"
            case .noEmail: return "envelope.badge"
            case .hasEmail: return "envelope.fill"
            case .noFirst, .noLast: return "person.fill.questionmark"
            case .hasFirst, .hasLast: return "person.fill.checkmark"
            case .noCompany: return "building.2.crop.circle"
            case .company: return "building.2.fill"
            case .noPhoto: return "person.crop.circle.badge.questionmark"
            case .hasPhoto: return "person.crop.circle.fill"
            case .noBirthday: return "gift"
            case .birthday: return "gift.fill"
            case .noAddress: return "mappin.slash"
            case .hasAddress: return "mappin.and.ellipse"
            case .emailOnly: return "at"
            case .phoneOnly: return "phone.connection"
            case .noMobile: return "iphone.slash"
            case .mobile: return "iphone"
            case .work: return "briefcase.fill"
            case .home: return "house.fill"
            case .social: return "bubble.left.and.bubble.right.fill"
            }
        }
        /// The other side of a pair ("No email" ↔ "Has an email"); nil for marks and kinds.
        var opposite: Filter? { Self.pairs.first { $0.0 == self }?.1 ?? Self.pairs.first { $0.1 == self }?.0 }
        /// What's missing first, the opposite next to it.
        static let pairs: [(Filter, Filter)] = [
            (.noPhone, .hasPhone), (.noEmail, .hasEmail), (.noFirst, .hasFirst), (.noLast, .hasLast),
            (.noCompany, .company), (.noPhoto, .hasPhoto), (.noBirthday, .birthday), (.noAddress, .hasAddress),
            (.noMobile, .mobile), (.emailOnly, .phoneOnly),
        ]
        static let marks: [Filter] = [.favorite, .emergency, .important]
        static let kinds: [Filter] = [.work, .home, .social]
    }

    /// Tenzy's own marks (iPhone doesn't let apps change its Favorites or Medical ID).
    enum Tag: String, CaseIterable, Codable, Identifiable {
        case favorite, emergency, important
        var id: String { rawValue }
        var title: String { ["Favorite", "Emergency", "Important"][Self.allCases.firstIndex(of: self)!] }
        var icon: String { ["star.fill", "cross.case.fill", "exclamationmark.circle.fill"][Self.allCases.firstIndex(of: self)!] }
    }

    // MARK: - Deciding (pure)

    static func kind(_ label: String) -> String {
        let l = label.lowercased()
        if l.contains("work") { return "work" }
        if l.contains("home") { return "home" }
        if l.contains("mobile") || l.contains("iphone") || l.contains("cell") { return "mobile" }
        return "other"
    }
    /// "_$!<Mobile>!$_" → "Mobile"; custom labels pass through.
    static func plainLabel(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "Other" }
        return CNLabeledValue<NSString>.localizedString(forLabel: raw).capitalized
    }

    static func passes(_ p: Person, _ f: Filter, tags: Set<Tag>) -> Bool {
        func blank(_ s: String) -> Bool { s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        switch f {
        case .favorite: return tags.contains(.favorite)
        case .emergency: return tags.contains(.emergency)
        case .important: return tags.contains(.important)
        case .noPhone: return p.phones.isEmpty
        case .hasPhone: return !p.phones.isEmpty
        case .noEmail: return p.emails.isEmpty
        case .hasEmail: return !p.emails.isEmpty
        case .noFirst: return blank(p.given)
        case .hasFirst: return !blank(p.given)
        case .noLast: return blank(p.family)
        case .hasLast: return !blank(p.family)
        case .noCompany: return blank(p.company)
        case .company: return !blank(p.company)
        case .noPhoto: return !p.hasPhoto
        case .hasPhoto: return p.hasPhoto
        case .noBirthday: return !(p.birthday?.month != nil && p.birthday?.day != nil)
        case .birthday: return p.birthday?.month != nil && p.birthday?.day != nil
        case .noAddress: return p.addresses.isEmpty
        case .hasAddress: return !p.addresses.isEmpty
        case .emailOnly: return p.phones.isEmpty && !p.emails.isEmpty
        case .phoneOnly: return !p.phones.isEmpty && p.emails.isEmpty
        case .noMobile: return !p.phones.contains { kind($0.label) == "mobile" }
        case .mobile: return p.phones.contains { kind($0.label) == "mobile" }
        case .work: return !p.company.isEmpty || (p.phones + p.emails + p.addresses).contains { kind($0.label) == "work" }
        case .home: return (p.phones + p.emails + p.addresses).contains { kind($0.label) == "home" }
        case .social: return !p.socials.isEmpty
        }
    }

    /// How many people each filter finds — what the finder shows on every button. Pure.
    static func counts(_ people: [Person], tags: [String: Set<Tag>]) -> [Filter: Int] {
        var out: [Filter: Int] = [:]
        for f in Filter.allCases { out[f] = people.filter { passes($0, f, tags: tags[$0.id] ?? []) }.count }
        return out
    }

    /// Search by any part of the name, company, job title, email, or the digits of a number.
    static func matches(_ p: Person, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        let digits = q.filter(\.isNumber)
        if digits.count >= 3, q.allSatisfy({ $0.isNumber || " +-()".contains($0) }) {
            return p.phones.contains { $0.value.filter(\.isNumber).contains(digits) }
        }
        let hay = ([p.name, p.company, p.title] + p.emails.map(\.value) + p.socials.map(\.value)).joined(separator: " ").lowercased()
        return q.split(separator: " ").allSatisfy { hay.contains($0) }
    }

    /// Everyone who matches the search and every chosen filter, in A–Z order.
    static func filtered(_ people: [Person], query: String, filters: Set<Filter>, group: String?, account: String?,
                         tags: [String: Set<Tag>]) -> [Person] {
        people.filter { p in
            (group == nil || p.groups.contains(group!)) && (account == nil || p.account == account) &&
            matches(p, query: query) && filters.allSatisfy { passes(p, $0, tags: tags[p.id] ?? []) }
        }.sorted { $0.sortKey < $1.sortKey }
    }

    // MARK: Spreadsheet

    static func csvCell(_ s: String) -> String {
        s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
    }
    static let csvHeader = ["Name", "First name", "Last name", "Company", "Job title", "Mobile", "Work phone", "Home phone", "Other phones",
                            "Emails", "Address", "Birthday", "Social", "Marks", "Account"]

    /// A spreadsheet that opens in Excel, Numbers or Google Sheets, one row per person.
    static func csv(_ people: [Person], tags: [String: Set<Tag>] = [:]) -> String {
        func phones(_ p: Person, _ k: String) -> String { p.phones.filter { kind($0.label) == k }.map(\.value).joined(separator: "; ") }
        let rows = people.map { p -> String in
            let bday: String = {
                guard let m = p.birthday?.month, let d = p.birthday?.day else { return "" }
                return p.birthday?.year.map { String(format: "%04d-%02d-%02d", $0, m, d) } ?? String(format: "--%02d-%02d", m, d)
            }()
            let cells = [p.name, p.given, p.family, p.company, p.title,
                         phones(p, "mobile"), phones(p, "work"), phones(p, "home"), phones(p, "other"),
                         p.emails.map(\.value).joined(separator: "; "),
                         p.addresses.first?.value.replacingOccurrences(of: "\n", with: ", ") ?? "",
                         bday,
                         p.socials.map { "\($0.label): \($0.value)" }.joined(separator: "; "),
                         (tags[p.id] ?? []).map(\.title).sorted().joined(separator: "; "),
                         p.account]
            return cells.map(csvCell).joined(separator: ",")
        }
        return ([csvHeader.joined(separator: ",")] + rows).joined(separator: "\r\n") + "\r\n"
    }

    // MARK: Birthdays

    /// The next time a birthday comes round (today counts), at midnight.
    static func nextBirthday(_ b: DateComponents, after now: Date, cal: Calendar = .current) -> Date? {
        guard let m = b.month, let d = b.day else { return nil }
        let today = cal.startOfDay(for: now)
        let y = cal.component(.year, from: now)
        for year in [y, y + 1, y + 2, y + 3, y + 4] {   // Feb 29 comes round within four years
            if let date = cal.date(from: DateComponents(year: year, month: m, day: d)), cal.component(.day, from: date) == d, date >= today { return date }
        }
        return nil
    }

    /// The soonest birthdays, for reminders (iPhone keeps a limited number of pending alerts, so only the next few).
    static func upcoming(_ people: [Person], now: Date = Date(), limit: Int = 24, cal: Calendar = .current) -> [(person: Person, date: Date)] {
        people.compactMap { p in p.birthday.flatMap { nextBirthday($0, after: now, cal: cal) }.map { (p, $0) } }
            .sorted { $0.1 < $1.1 }.prefix(limit).map { $0 }
    }

    static func age(_ b: DateComponents, on date: Date, cal: Calendar = .current) -> Int? {
        guard let y = b.year, y > 1800 else { return nil }
        return cal.component(.year, from: date) - y
    }

    /// A birthday wish ready to send, in their name — with the milestone when the year is known.
    static func birthdayWish(_ p: Person, on date: Date, cal: Calendar = .current) -> String {
        let first = p.given.isEmpty ? p.name : p.given
        if let a = p.birthday.flatMap({ age($0, on: date, cal: cal) }), a > 0, a % 10 == 0 || a == 18 || a == 21 {
            return "Happy \(ordinal(a)) birthday, \(first)! 🎉 What a milestone — hope it's a brilliant day."
        }
        return "Happy birthday, \(first)! 🎂 Hope you have a wonderful day."
    }

    static func ordinal(_ n: Int) -> String {
        let s = (11...13).contains(n % 100) ? "th" : (["th", "st", "nd", "rd"] + Array(repeating: "th", count: 6))[n % 10]
        return "\(n)\(s)"
    }

    /// Messages, addressed to their mobile, with the wish written — you press Send.
    static func wishURL(_ p: Person, wish: String) -> URL? {
        guard let phone = (p.phones.first { $0.label.lowercased().contains("mobile") || $0.label.lowercased().contains("iphone") } ?? p.phones.first)?.value else { return nil }
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return URL(string: "sms:\(digits)&body=\(wish.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
    }

    static func birthdayMessage(_ p: Person, on date: Date, cal: Calendar = .current) -> (title: String, body: String) {
        let turning = p.birthday.flatMap { age($0, on: date, cal: cal) }.map { " — turning \($0)" } ?? ""
        let reach = p.phones.first.map { " Call or text: \($0.value)." } ?? ""
        return ("\(p.name)'s birthday is tomorrow\(turning)", "Don't forget to wish them.\(reach)")
    }

    // MARK: Plans (call or visit at a time)

    enum PlanKind: String, CaseIterable, Identifiable { case call, visit, meeting
        var id: String { rawValue }
        var title: String { ["Call", "Visit", "Meet"][Self.allCases.firstIndex(of: self)!] }
    }

    /// When to set off: the start, less the drive, less a few minutes to park and walk in.
    static func leaveBy(start: Date, travelMinutes: Int?, buffer: Int = 10) -> Date? {
        guard let t = travelMinutes, t > 0 else { return nil }
        return start.addingTimeInterval(-Double((t + buffer) * 60))
    }

    static func planMessage(_ p: Person, kind: PlanKind, start: Date, travelMinutes: Int?, note: String, leaving: Bool) -> (title: String, body: String) {
        let at = start.formatted(date: .omitted, time: .shortened)
        let phone = p.phones.first?.value
        let addr = p.addresses.first?.value.replacingOccurrences(of: "\n", with: ", ")
        var lines: [String] = []
        if !note.isEmpty { lines.append(note) }
        switch kind {
        case .call:
            if let phone { lines.append("Number: \(phone)") }
            return ("Time to call \(p.name)", lines.joined(separator: " · ").isEmpty ? "Tap to call." : lines.joined(separator: " · "))
        case .visit, .meeting:
            if let addr { lines.append(addr) }
            if let phone { lines.append(phone) }
            if leaving, let t = travelMinutes {
                return ("Leave now for \(p.name) — \(t) min drive", "You're due at \(at). " + lines.joined(separator: " · "))
            }
            return ("\(kind == .visit ? "Visit" : "Meeting with") \(p.name) at \(at)", lines.joined(separator: " · "))
        }
    }
}

// MARK: - Reading and writing the real contacts

extension ContactBook {
    static var keys: [CNKeyDescriptor] {
        [CNContactIdentifierKey, CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey, CNContactJobTitleKey,
         CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactPostalAddressesKey, CNContactSocialProfilesKey,
         CNContactInstantMessageAddressesKey, CNContactUrlAddressesKey, CNContactBirthdayKey, CNContactImageDataAvailableKey] as [CNKeyDescriptor]
    }

    static func person(_ c: CNContact, account: String, groups: [String]) -> Person {
        var p = Person(id: c.identifier)
        p.given = c.givenName; p.family = c.familyName; p.company = c.organizationName; p.title = c.jobTitle
        p.phones = c.phoneNumbers.map { Labeled(label: plainLabel($0.label), value: $0.value.stringValue) }
        p.emails = c.emailAddresses.map { Labeled(label: plainLabel($0.label), value: $0.value as String) }
        p.addresses = c.postalAddresses.map { Labeled(label: plainLabel($0.label), value: CNPostalAddressFormatter.string(from: $0.value, style: .mailingAddress)) }
        p.socials = c.socialProfiles.map { Labeled(label: $0.value.service.isEmpty ? "Social" : $0.value.service, value: $0.value.username.isEmpty ? $0.value.urlString : $0.value.username) }
            + c.instantMessageAddresses.map { Labeled(label: $0.value.service.isEmpty ? "Messaging" : $0.value.service, value: $0.value.username) }
        p.urls = c.urlAddresses.map { $0.value as String }
        p.birthday = c.birthday
        p.hasPhoto = c.imageDataAvailable
        p.account = account
        p.groups = groups
        return p
    }

    struct Group: Identifiable, Hashable { let id: String; var name: String; var account: String }

    /// Everyone, with which account and groups they're in. Runs off the main thread (it can take a moment).
    static func load(store: CNContactStore = CNContactStore()) -> (people: [Person], groups: [Group], accounts: [String]) {
        var accountOf: [String: String] = [:], groupsOf: [String: [String]] = [:]
        var accounts: [String] = [], groups: [Group] = []
        for c in (try? store.containers(matching: nil)) ?? [] {
            let name = accountName(c)
            accounts.append(name)
            let ids = (try? store.unifiedContacts(matching: CNContact.predicateForContactsInContainer(withIdentifier: c.identifier), keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])) ?? []
            for x in ids { accountOf[x.identifier] = name }
        }
        for g in (try? store.groups(matching: nil)) ?? [] {
            let acct = (try? store.containers(matching: CNContainer.predicateForContainerOfGroup(withIdentifier: g.identifier)))?.first.map(accountName) ?? ""
            groups.append(Group(id: g.identifier, name: g.name, account: acct))
            let members = (try? store.unifiedContacts(matching: CNContact.predicateForContactsInGroup(withIdentifier: g.identifier), keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])) ?? []
            for m in members { groupsOf[m.identifier, default: []].append(g.identifier) }
        }
        var people: [Person] = []
        let req = CNContactFetchRequest(keysToFetch: keys)
        req.unifyResults = true
        try? store.enumerateContacts(with: req) { c, _ in
            people.append(person(c, account: accountOf[c.identifier] ?? "", groups: groupsOf[c.identifier] ?? []))
        }
        return (people.sorted { $0.sortKey < $1.sortKey }, groups.sorted { $0.name.lowercased() < $1.name.lowercased() }, Array(Set(accounts)).sorted())
    }

    static func accountName(_ c: CNContainer) -> String {
        switch c.type {
        case .local: return "On My iPhone"
        case .exchange: return c.name.isEmpty ? "Outlook / Exchange" : c.name
        case .cardDAV:
            let n = c.name.lowercased()
            if n.contains("gmail") || n.contains("google") { return "Gmail" }
            if n.isEmpty || n == "card" || n.contains("icloud") { return "iCloud" }
            return c.name
        default: return c.name.isEmpty ? "Other" : c.name
        }
    }

    static func fetch(_ ids: [String], keys extra: [CNKeyDescriptor] = [], store: CNContactStore = CNContactStore()) -> [CNContact] {
        let k = keys + extra + [CNContactVCardSerialization.descriptorForRequiredKeys()]
        return (try? store.unifiedContacts(matching: CNContact.predicateForContacts(withIdentifiers: ids), keysToFetch: k)) ?? []
    }

    /// Contact cards (.vcf) for these people — opens in any phone's or computer's contacts.
    static func vcard(_ ids: [String], name: String) -> URL? {
        let cs = fetch(ids)
        guard !cs.isEmpty, let d = try? CNContactVCardSerialization.data(with: cs) else { return nil }
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe(name)).vcf")
        return (try? d.write(to: u)) != nil ? u : nil
    }

    static func csvFile(_ people: [Person], tags: [String: Set<Tag>], name: String) -> URL? {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe(name)).csv")
        // A byte-order mark so Excel reads accents and non-Latin names correctly.
        let d = Data([0xEF, 0xBB, 0xBF]) + Data(csv(people, tags: tags).utf8)
        return (try? d.write(to: u)) != nil ? u : nil
    }

    static func safe(_ s: String) -> String {
        let t = s.components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|")).joined(separator: "-").trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "Contacts" : String(t.prefix(60))
    }

    static func delete(_ ids: [String], store: CNContactStore = CNContactStore()) throws {
        let req = CNSaveRequest()
        for c in fetch(ids, store: store) { if let m = c.mutableCopy() as? CNMutableContact { req.delete(m) } }
        try store.execute(req)
    }

    static func setPhoto(_ id: String, image: UIImage?, store: CNContactStore = CNContactStore()) throws {
        guard let c = fetch([id], keys: [CNContactImageDataKey as CNKeyDescriptor], store: store).first,
              let m = c.mutableCopy() as? CNMutableContact else { return }
        m.imageData = image.flatMap { $0.resized(maxDimension: 800).jpegData(compressionQuality: 0.85) }
        let req = CNSaveRequest(); req.update(m); try store.execute(req)
    }

    /// A new group, made in the account most of these people are in (or the phone's default).
    @discardableResult
    static func makeGroup(_ name: String, store: CNContactStore = CNContactStore()) throws -> String {
        let g = CNMutableGroup(); g.name = name
        let req = CNSaveRequest(); req.add(g, toContainerWithIdentifier: nil); try store.execute(req)
        return g.identifier
    }

    /// Add people to a group. Returns how many couldn't be added (a group lives in one account, so people
    /// stored in another account — e.g. Gmail people into an iCloud group — can't join it; iPhone's rule).
    static func add(_ ids: [String], toGroup gid: String, store: CNContactStore = CNContactStore()) -> Int {
        guard let g = (try? store.groups(matching: CNGroup.predicateForGroups(withIdentifiers: [gid])))?.first else { return ids.count }
        var failed = 0
        for c in fetch(ids, store: store) {
            let req = CNSaveRequest(); req.addMember(c, to: g)
            if (try? store.execute(req)) == nil { failed += 1 }
        }
        return failed
    }

    // MARK: bulk edit

    enum BulkField: String, CaseIterable, Identifiable {
        case company, jobTitle, countryCode
        var id: String { rawValue }
        var title: String { ["Set company", "Set job title", "Add country code to phone numbers"][Self.allCases.firstIndex(of: self)!] }
        var prompt: String { ["Company name (leave empty to clear)", "Job title (leave empty to clear)", "Country code, e.g. +1 or +44"][Self.allCases.firstIndex(of: self)!] }
    }

    /// A local number → international, so WhatsApp, travel and other countries' phones can reach it.
    /// "+…" and "00…" numbers are already international and left alone (nil). One leading trunk "0" is
    /// dropped ("07700 900123" + 44 → "+44 7700 900123"). Too-short numbers (codes, extensions) are skipped.
    static func withCountryCode(_ number: String, code raw: String) -> String? {
        let code = raw.filter(\.isNumber)
        let t = number.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty, !t.hasPrefix("+"), !t.hasPrefix("00") else { return nil }
        let digits = t.filter(\.isNumber)
        guard digits.count >= 7 else { return nil }
        if code == "1", digits.count == 11, digits.hasPrefix("1") {          // "1 555 123 4567" already has the 1
            let afterOne = t.drop { !$0.isNumber }.dropFirst()
            return "+1 " + afterOne.trimmingCharacters(in: .whitespaces)
        }
        var rest = Substring(t)
        if let i = rest.firstIndex(where: \.isNumber), rest[i] == "0" { rest.remove(at: i) }
        return "+\(code) " + rest.trimmingCharacters(in: .whitespaces)
    }

    /// Change one field on everyone picked. Returns (changed, failed).
    static func bulkSet(_ ids: [String], field: BulkField, value: String, store: CNContactStore = CNContactStore()) -> (changed: Int, failed: Int) {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var changed = 0, failed = 0
        for c in fetch(ids, store: store) {
            guard let m = c.mutableCopy() as? CNMutableContact else { failed += 1; continue }
            var touched = false
            switch field {
            case .company: if m.organizationName != v { m.organizationName = v; touched = true }
            case .jobTitle: if m.jobTitle != v { m.jobTitle = v; touched = true }
            case .countryCode:
                m.phoneNumbers = m.phoneNumbers.map { lv in
                    guard let n = withCountryCode(lv.value.stringValue, code: v) else { return lv }
                    touched = true
                    return CNLabeledValue(label: lv.label, value: CNPhoneNumber(stringValue: n))
                }
            }
            guard touched else { continue }
            let req = CNSaveRequest(); req.update(m)
            if (try? store.execute(req)) != nil { changed += 1 } else { failed += 1 }
        }
        return (changed, failed)
    }

    static func remove(_ ids: [String], fromGroup gid: String, store: CNContactStore = CNContactStore()) {
        guard let g = (try? store.groups(matching: CNGroup.predicateForGroups(withIdentifiers: [gid])))?.first else { return }
        for c in fetch(ids, store: store) { let req = CNSaveRequest(); req.removeMember(c, from: g); try? store.execute(req) }
    }
}

// MARK: - Tenzy's own marks

enum ContactTags {
    private static let key = "contacts.tags"
    static func load() -> [String: Set<ContactBook.Tag>] {
        guard let d = UserDefaults.standard.data(forKey: key), let m = try? JSONDecoder().decode([String: Set<ContactBook.Tag>].self, from: d) else { return [:] }
        return m
    }
    static func save(_ m: [String: Set<ContactBook.Tag>]) {
        if let d = try? JSONEncoder().encode(m.filter { !$0.value.isEmpty }) { UserDefaults.standard.set(d, forKey: key) }
    }
}

// MARK: - Birthday reminders

enum BirthdayReminders {
    static var on: Bool { UserDefaults.standard.bool(forKey: "birthdays.on") }
    static var hour: Int { let h = UserDefaults.standard.integer(forKey: "birthdays.hour"); return h == 0 ? 9 : h }
    static let prefix = "bday-"

    /// Re-set the reminders for the next birthdays (call on open and after changes). Off → all cleared.
    static func refresh(_ people: [ContactBook.Person], now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
            guard on else { return }
            let cal = Calendar.current
            for (p, date) in ContactBook.upcoming(people, now: now) {
                guard let day = cal.date(byAdding: .day, value: -1, to: date),
                      let at = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day), at > now else { continue }
                post(p, birthday: date, at: at, id: prefix + p.id.filter { $0.isLetter || $0.isNumber })
            }
        }
    }

    static func post(_ p: ContactBook.Person, birthday: Date, at: Date?, id: String) {
        let m = ContactBook.birthdayMessage(p, on: birthday)
        let c = UNMutableNotificationContent()
        c.title = (at == nil ? "Test · " : "") + m.title; c.body = m.body; c.sound = .default
        c.userInfo = ["open": "contacts", "contact": p.id]
        let trigger = at.map { UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0), repeats: false) }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: at == nil ? "bday-test-\(UUID().uuidString)" : id, content: c, trigger: trigger))
    }
}


/// "Back up my contacts": a regular nudge (weekly or monthly) — tap it and the full backup is one button.
/// iPhone doesn't let apps save into your iCloud Drive on their own, so the nudge is the honest way.
enum ContactBackupReminder {
    static let id = "contacts-backup"
    static var every: Int { UserDefaults.standard.integer(forKey: "contacts.backup.every") }   // 0 off, 7 weekly, 30 monthly
    static var last: Date? { UserDefaults.standard.object(forKey: "contacts.backup.last") as? Date }
    static func markDone(_ d: Date = Date()) { UserDefaults.standard.set(d, forKey: "contacts.backup.last") }

    static let message = ("Time to back up your contacts", "One tap in Tenzy saves everyone to Files or iCloud Drive.")

    /// Weekly → every Sunday 7 pm; monthly → the 1st at 7 pm.
    static func trigger(every: Int) -> DateComponents? {
        var c = DateComponents(); c.hour = 19; c.minute = 0
        switch every {
        case 7: c.weekday = 1
        case 30: c.day = 1
        default: return nil
        }
        return c
    }

    static func set(every: Int) async {
        UserDefaults.standard.set(every, forKey: "contacts.backup.every")
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard let when = trigger(every: every) else { return }
        let c = UNMutableNotificationContent()
        c.title = message.0; c.body = message.1; c.sound = .default
        c.userInfo = ["open": "contacts"]
        try? await center.add(UNNotificationRequest(identifier: id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)))
    }

    static func testRun() async {
        let c = UNMutableNotificationContent()
        c.title = "Test · " + message.0; c.body = message.1; c.sound = .default
        c.userInfo = ["open": "contacts"]
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "contacts-backup-test-\(UUID().uuidString)", content: c,
                                                                                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }
}
