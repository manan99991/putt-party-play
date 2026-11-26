import Foundation
import UIKit
import Photos
import Contacts

/// Smart autorun: business cards into contacts (25 Nov). Today's photos of business cards are read on the phone the
/// same way the Business Cards tool reads them, each becomes a contact (name, title, company, phones, emails, website,
/// address, and "Met on <day>"), and anyone already in Contacts — by email or phone — is shown, not duplicated.
/// Nothing is saved until the person taps Save; a ready "nice to meet you" email is one tap away for each.
enum SmartCards {
    struct Entry: Codable, Equatable, Identifiable {
        var id: String                // the photo's id
        var taken: Date
        var name = "", title = "", company = ""
        var phones: [String] = [], emails: [String] = []
        var website = "", address = ""
        var already: String?          // the name it's already saved under, if it is

        var card: DataGrab.Card {
            DataGrab.Card(name: name, title: title, company: company, phones: phones, emails: emails, website: website, address: address)
        }
        init(id: String, taken: Date, card c: DataGrab.Card) {
            self.id = id; self.taken = taken
            name = c.name; title = c.title; company = c.company; phones = c.phones; emails = c.emails; website = c.website; address = c.address
        }
    }

    /// The same person twice (both sides photographed, or two shots of one card) counts once: a shared email or phone.
    static func deduped(_ entries: [Entry]) -> [Entry] {
        var out: [Entry] = []
        for e in entries {
            let mails = Set(e.emails.map { $0.lowercased() }), phones = Set(e.phones.map(CardKit.digits).filter { $0.count >= 7 })
            if let i = out.firstIndex(where: { o in
                !mails.isDisjoint(with: o.emails.map { $0.lowercased() }) || !phones.isDisjoint(with: o.phones.map(CardKit.digits))
            }) {
                out[i] = Entry(id: out[i].id, taken: out[i].taken, card: CardKit.merge(out[i].card, e.card))
            } else { out.append(e) }
        }
        return out
    }

    /// A friendly follow-up, in the person's words to edit.
    static func niceToMeetYou(_ e: Entry, on day: Date) -> (subject: String, body: String) {
        let first = e.name.split(separator: " ").first.map(String.init) ?? ""
        let when = day.formatted(.dateTime.weekday(.wide))
        return ("\(L("Great to meet you"))\(e.company.isEmpty ? "" : " — \(e.company)")",
                "\(L("Hi")) \(first.isEmpty ? "" : first + ",")\n\n\(L("It was great to meet you on")) \(when). \(L("I'd love to stay in touch."))\n\n")
    }

    /// Today's business cards, read and checked against Contacts.
    static func gather(in window: DateInterval, progress: ((Double, String) -> Void)? = nil) async -> [Entry] {
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", window.start as NSDate, window.end as NSDate)
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let r = PHAsset.fetchAssets(with: .image, options: o)
        var assets: [PHAsset] = []
        r.enumerateObjects { a, _, _ in assets.append(a) }
        var cache = PhotoFinder.loadCache()
        var out: [Entry] = []
        for (i, a) in assets.enumerated() {
            if Task.isCancelled { break }
            progress?(Double(i) / Double(max(1, assets.count)), "\(L("Looking at photo")) \(i + 1)/\(assets.count)")
            let seen: PhotoFinder.Seen?
            if let s = cache[a.localIdentifier], s.modified == (a.modificationDate?.timeIntervalSince1970 ?? 0) { seen = s }
            else { seen = await PhotoFinder.read(a); if let seen { cache[a.localIdentifier] = seen } }
            guard let seen, !seen.screenshot, PhotoFinder.score(seen, for: .card) >= PhotoFinder.threshold,
                  let img = await PhotoFinder.image(a, side: 2400) else { continue }
            let text = await Task.detached(priority: .userInitiated) { ChainText.documentText(img) }.value
            guard CardKit.looksLikeCard(text) else { continue }
            let c = DataGrab.card(text)
            guard !c.emails.isEmpty || !c.phones.isEmpty else { continue }
            out.append(Entry(id: a.localIdentifier, taken: a.creationDate ?? window.end, card: c))
        }
        PhotoFinder.saveCache(cache)
        var list = deduped(out)
        if CNContactStore.authorizationStatus(for: .contacts) == .authorized {
            let store = CNContactStore()
            for i in list.indices {
                if let c = CardKit.existing(list[i].card, in: store) { list[i].already = "\(c.givenName) \(c.familyName)".trimmingCharacters(in: .whitespaces) }
            }
        }
        progress?(1, L("Done"))
        return list
    }

    /// Saves the new ones (not already in Contacts) with "Met on <day>". Returns how many were added.
    static func save(_ entries: [Entry]) async -> Int? {
        let store = CNContactStore()
        guard (try? await store.requestAccess(for: .contacts)) == true else { return nil }
        let req = CNSaveRequest(); var n = 0
        for e in entries where e.already == nil && CardKit.existing(e.card, in: store) == nil {
            var k = CardKit.Entry(card: e.card)
            k.note = CardKit.metNote(where: "", on: e.taken)
            req.add(CardKit.contact(k), toContainerWithIdentifier: nil); n += 1
        }
        guard n > 0 else { return 0 }
        do { try store.execute(req); return n } catch { return nil }
    }
}
