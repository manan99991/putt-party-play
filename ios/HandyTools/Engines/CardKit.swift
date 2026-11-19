import Foundation
import Contacts
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Business cards → real contacts. Reads a card (or its two sides), lets you fix any field, then saves it
/// straight to Contacts with where/when you met, sets a follow-up reminder, finds them on LinkedIn, or
/// shares it as a contact file or QR code. Pure parts here are unit-tested.
enum CardKit {
    struct Entry: Identifiable, Equatable {
        var id = UUID()
        var card: DataGrab.Card
        var note = ""
        var raw = ""                 // what was read, for "this isn't a card" and for reference
        var front: UIImage?
        static func == (a: Entry, b: Entry) -> Bool { a.id == b.id && a.card == b.card && a.note == b.note }
    }

    /// Does the text read like a business card? A card has a way to reach someone; a chat screenshot or a
    /// page of prose (lots of lines, sentences) doesn't.
    static func looksLikeCard(_ text: String) -> Bool {
        let c = DataGrab.card(text)
        let lines = text.split(whereSeparator: \.isNewline).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let sentences = lines.filter { $0.split(separator: " ").count >= 7 }.count
        return (!c.phones.isEmpty || !c.emails.isEmpty) && lines.count <= 18 && sentences <= 2
    }

    /// Front and back of one card: fill what the front lacks from the back, and add any extra numbers/emails.
    static func merge(_ a: DataGrab.Card, _ b: DataGrab.Card) -> DataGrab.Card {
        var c = a
        if c.name.isEmpty { c.name = b.name }
        if c.title.isEmpty { c.title = b.title }
        if c.company.isEmpty { c.company = b.company }
        if c.website.isEmpty { c.website = b.website }
        if c.address.isEmpty { c.address = b.address }
        for p in b.phones where !c.phones.contains(where: { digits($0) == digits(p) }) { c.phones.append(p) }
        for e in b.emails where !c.emails.contains(where: { $0.lowercased() == e.lowercased() }) { c.emails.append(e) }
        return c
    }

    static func digits(_ s: String) -> String { s.filter(\.isNumber) }

    /// "Met at the Chicago HIMSS conference · 18 Nov 2026" — the note saved with the contact.
    static func metNote(where place: String, on date: Date = Date()) -> String {
        let when = date.formatted(date: .abbreviated, time: .omitted)
        let p = place.trimmingCharacters(in: .whitespacesAndNewlines)
        return p.isEmpty ? "Met \(when) (card scanned with Tenzy)" : "Met at \(p) · \(when)"
    }

    static func contact(_ e: Entry) -> CNMutableContact {
        let c = CNMutableContact()
        let parts = e.card.name.split(separator: " ").map(String.init)
        c.givenName = parts.first ?? ""
        c.familyName = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : ""
        c.jobTitle = e.card.title
        c.organizationName = e.card.company
        c.phoneNumbers = e.card.phones.map { CNLabeledValue(label: CNLabelWork, value: CNPhoneNumber(stringValue: $0)) }
        c.emailAddresses = e.card.emails.map { CNLabeledValue(label: CNLabelWork, value: $0 as NSString) }
        if !e.card.website.isEmpty {
            c.urlAddresses = [CNLabeledValue(label: CNLabelWork, value: (e.card.website.hasPrefix("http") ? e.card.website : "https://" + e.card.website) as NSString)]
        }
        if !e.card.address.isEmpty {
            let a = CNMutablePostalAddress(); a.street = e.card.address
            c.postalAddresses = [CNLabeledValue(label: CNLabelWork, value: a)]
        }
        // When you met, as a labelled date on the contact (Contacts' Notes field needs a special Apple
        // entitlement, so the "where" lives in the follow-up reminder instead).
        let met = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.dates = [CNLabeledValue(label: "Met", value: met as NSDateComponents)]
        if let img = e.front?.resized(maxDimension: 600), let d = img.jpegData(compressionQuality: 0.7) { c.imageData = d }
        return c
    }

    static func linkedIn(_ card: DataGrab.Card) -> URL? {
        let q = [card.name, card.company].filter { !$0.isEmpty }.joined(separator: " ")
        guard !q.isEmpty else { return nil }
        var c = URLComponents(string: "https://www.linkedin.com/search/results/people/")
        c?.queryItems = [URLQueryItem(name: "keywords", value: q)]
        return c?.url
    }

    /// Contacts already on the phone with the same email or number — so a card never makes a duplicate.
    static func existing(_ card: DataGrab.Card, in store: CNContactStore = CNContactStore()) -> CNContact? {
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactIdentifierKey] as [CNKeyDescriptor]
        for e in card.emails {
            if let c = try? store.unifiedContacts(matching: CNContact.predicateForContacts(matchingEmailAddress: e), keysToFetch: keys).first { return c }
        }
        for p in card.phones {
            if let c = try? store.unifiedContacts(matching: CNContact.predicateForContacts(matching: CNPhoneNumber(stringValue: p)), keysToFetch: keys).first { return c }
        }
        return nil
    }

    static func qr(_ card: DataGrab.Card, size: CGFloat = 600) -> UIImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(DataGrab.vcard(card).utf8); f.correctionLevel = "M"
        guard let out = f.outputImage else { return nil }
        let k = size / out.extent.width
        let img = out.transformed(by: CGAffineTransform(scaleX: k, y: k))
        guard let cg = CIContext().createCGImage(img, from: img.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
