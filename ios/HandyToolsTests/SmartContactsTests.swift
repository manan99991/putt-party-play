import XCTest
import Contacts
@testable import HandyTools

/// Weekly contacts copy (26 Nov): every contact read back from the copy, and who's gone or new since the copy before —
/// an edited or renamed contact is neither, and a gone contact's own card is kept to bring it back exactly.
final class SmartContactsTests: XCTestCase {
    private let copy = """
    BEGIN:VCARD\r
    VERSION:3.0\r
    N:Raman;Priya;;;\r
    FN:Priya Raman\r
    ORG:Northwind Analytics LLC;\r
    TEL;type=CELL;type=VOICE;type=pref:+1 (630) 555-0142\r
    EMAIL;type=INTERNET;type=WORK:priya.raman@northwind-analytics.com\r
    END:VCARD\r
    BEGIN:VCARD\r
    VERSION:3.0\r
    N:;;;;\r
    ORG:Corner Market;\r
    item1.TEL:(630) 555-0199\r
    END:VCARD\r
    BEGIN:VCARD\r
    VERSION:3.0\r
    N:Ellis;Jordan;;;\r
    FN:Jordan Ellis\r
    NOTE:Met at the lease signing\\, a very long note that the phone folds onto\r
      a second line\r
    TEL;type=HOME:630-555-0123\r
    END:VCARD\r

    """

    func testEveryContactIsReadBackFromTheCopy() {
        let people = SmartContacts.people(fromVCard: copy)
        XCTAssertEqual(people.map(\.name), ["Priya Raman", "Corner Market", "Jordan Ellis"], "a card with no name takes its company")
        XCTAssertEqual(people[0].phones, ["6305550142"]); XCTAssertEqual(people[0].emails, ["priya.raman@northwind-analytics.com"])
        XCTAssertEqual(people[1].phones, ["6305550199"], "grouped properties (item1.TEL) count")
        XCTAssertTrue(people[2].card.hasPrefix("BEGIN:VCARD") && people[2].card.contains("END:VCARD"), "each person keeps their whole card")
        // The kept card is a real contact again.
        let c = try? CNContactVCardSerialization.contacts(with: Data(people[2].card.utf8)).first
        XCTAssertEqual(c?.givenName, "Jordan"); XCTAssertEqual(c?.familyName, "Ellis")
    }

    private func p(_ name: String, phones: [String] = [], emails: [String] = []) -> SmartContacts.Person {
        SmartContacts.Person(name: name, phones: phones, emails: emails, card: "")
    }

    func testWhoIsGoneAndWhoIsNew() {
        let before = [p("Priya Raman", phones: ["6305550142"]), p("Jordan Ellis", phones: ["6305550123"]), p("Mom", phones: ["6305550100"]), p("Dr. Okafor", emails: ["clinic@okafor.example"])]
        let now = [p("Priya Raman", phones: ["6305550142"]),
                   p("Jordan Ellis-Brooks", phones: ["6305550123"]),           // renamed, same number: not gone
                   p("Mom", phones: ["6305550111"]),                            // new number, same name: not gone
                   p("Sam Lee", emails: ["sam@lee.example"])]
        let d = SmartContacts.diff(old: before, new: now)
        XCTAssertEqual(d.gone.map(\.name), ["Dr. Okafor"])
        XCTAssertEqual(d.added.map(\.name), ["Sam Lee"])
        XCTAssertTrue(SmartContacts.diff(old: now, new: now).gone.isEmpty, "the same copy twice: nobody's gone")
    }

    func testRestoredContactsStopWaiting() {
        var r = SmartContacts.Report(file: "Contacts-2026-11-29-2100.vcf", at: Date(), total: 3, added: [], gone: [p("Dr. Okafor"), p("Ana")])
        XCTAssertEqual(r.waiting.count, 2)
        r.restored = ["Ana"]
        XCTAssertEqual(r.waiting.map(\.name), ["Dr. Okafor"])
    }
}
