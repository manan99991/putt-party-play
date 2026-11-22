import XCTest
@testable import HandyTools

final class ContactFinderTests: XCTestCase {
    typealias P = ContactBook.Person
    private let people: [P] = [
        P(id: "1", given: "Priya", family: "Shah", company: "Lakeview", phones: [.init(label: "Mobile", value: "630 555 0142")],
          emails: [.init(label: "Work", value: "p@l.org")], addresses: [.init(label: "Work", value: "12 Main St")],
          birthday: DateComponents(month: 3, day: 14), hasPhoto: true),
        P(id: "2", given: "Asha", phones: [.init(label: "Home", value: "630 555 0199")]),
        P(id: "3", company: "Joe's Plumbing", emails: [.init(label: "Home", value: "joe@pipes.com")]),
        P(id: "4", family: "Kumar"),
    ]

    /// Every pair splits everyone in two: each person is on exactly one side ("No email" or "Has an email").
    func testEveryPairSplitsEveryone() {
        for (a, b) in ContactBook.Filter.pairs where (a, b) != (.emailOnly, .phoneOnly) {
            for p in people {
                XCTAssertNotEqual(ContactBook.passes(p, a, tags: []), ContactBook.passes(p, b, tags: []), "\(p.id) on both or neither side of \(a)/\(b)")
            }
            XCTAssertEqual(a.opposite, b); XCTAssertEqual(b.opposite, a)
        }
        // Every filter is shown somewhere on the finder, once.
        let shown = ContactBook.Filter.pairs.flatMap { [$0.0, $0.1] } + ContactBook.Filter.marks + ContactBook.Filter.kinds
        XCTAssertEqual(Set(shown), Set(ContactBook.Filter.allCases))
        XCTAssertEqual(shown.count, Set(shown).count)
    }

    func testWhatEachFinds() {
        let c = ContactBook.counts(people, tags: ["2": [.favorite]])
        XCTAssertEqual(c[.noPhone], 2); XCTAssertEqual(c[.hasPhone], 2)
        XCTAssertEqual(c[.noFirst], 2); XCTAssertEqual(c[.noLast], 2)
        XCTAssertEqual(c[.noCompany], 2); XCTAssertEqual(c[.company], 2)
        XCTAssertEqual(c[.emailOnly], 1); XCTAssertEqual(c[.phoneOnly], 1)
        XCTAssertEqual(c[.mobile], 1); XCTAssertEqual(c[.noMobile], 3)
        XCTAssertEqual(c[.hasAddress], 1); XCTAssertEqual(c[.birthday], 1); XCTAssertEqual(c[.hasPhoto], 1)
        XCTAssertEqual(c[.favorite], 1)
        func ids(_ f: Set<ContactBook.Filter>) -> [String] { ContactBook.filtered(people, query: "", filters: f, group: nil, account: nil, tags: [:]).map(\.id) }
        XCTAssertEqual(Set(ids([.noPhone, .noEmail])), ["4"], "conditions add up")
        XCTAssertEqual(ids([.emailOnly]), ["3"])
    }
}
