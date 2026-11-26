import XCTest
@testable import HandyTools

/// Overdue invoices (25 Nov): how late, the right tone, the client's email, and a reminder that quotes the invoice
/// exactly. Plus a guard for every translated sentence with blanks: a translation with the wrong blanks would crash.
final class SmartInvoicesTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)
    private func day(_ d: Int, _ m: Int = 11) -> Date { cal.date(from: DateComponents(year: 2026, month: m, day: d, hour: 12))! }
    private func invoice(due: Date?, paid: Bool = false) -> Invoice.Doc {
        Invoice.Doc(kind: .invoice, number: "INV-0042", date: day(1), due: due, from: "Manan Shah\nDeeyan Productions",
                    to: "Priya Raman\nNorthwind Analytics\npriya.raman@northwind-analytics.com",
                    lines: [.init(what: "Consulting", qty: 10, price: 125)], taxPercent: 0, notes: "", currency: "USD", paid: paid)
    }

    func testHowLateAndWhichTone() {
        XCTAssertEqual(SmartInvoices.daysLate(invoice(due: day(20)), now: day(25), cal: cal), 5)
        XCTAssertEqual(SmartInvoices.tone(daysLate: 5), .friendly)
        XCTAssertEqual(SmartInvoices.tone(daysLate: 8), .firm)
        XCTAssertEqual(SmartInvoices.tone(daysLate: 31), .final)
        XCTAssertFalse(invoice(due: day(20), paid: true).overdue(now: day(25), cal: cal), "a paid one is never nagged about")
    }

    func testTheClientsEmailIsFound() {
        XCTAssertEqual(SmartInvoices.email(invoice(due: nil).to), "priya.raman@northwind-analytics.com")
        XCTAssertNil(SmartInvoices.email("Acme Plumbing\n12 Main St"))
    }

    func testTheReminderQuotesTheInvoiceExactly() {
        let us = Locale(identifier: "en_US")
        let friendly = SmartInvoices.reminder(invoice(due: day(20)), now: day(25), locale: us)
        XCTAssertTrue(friendly.subject.contains("INV-0042"))
        XCTAssertTrue(friendly.body.contains("$1,250.00"), friendly.body)
        XCTAssertTrue(friendly.body.hasPrefix("Hi Priya,"))
        XCTAssertTrue(friendly.body.hasSuffix("Manan Shah"))
        let last = SmartInvoices.reminder(invoice(due: day(10, 9)), now: day(25), locale: us)
        XCTAssertTrue(last.subject.hasPrefix("Final notice"), last.subject)
        XCTAssertTrue(last.body.contains("76 days"), last.body)
    }

    /// Every translated sentence with blanks (%@, %d, %1$@…) has exactly the blanks its English has, in every language.
    func testEveryTranslationHasTheSameBlanks() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "translations", withExtension: "json"))
        let all = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: [String: String]])
        let spec = try NSRegularExpression(pattern: #"%(?:(\d+)\$)?([@dfs]|ld|lu|\.\d+f)"#)
        func blanks(_ s: String) -> [String] {
            let ms = spec.matches(in: s, range: NSRange(s.startIndex..., in: s))
            var out: [(Int, String)] = []
            for (i, m) in ms.enumerated() {
                let pos = Range(m.range(at: 1), in: s).flatMap { Int(s[$0]) } ?? (i + 1)
                out.append((pos, Range(m.range(at: 2), in: s).map { String(s[$0]) } ?? ""))
            }
            return out.sorted { $0.0 < $1.0 }.map { "\($0.0):\($0.1)" }
        }
        var bad: [String] = []
        for (key, langs) in all where key.contains("%") {
            let want = blanks(key)
            for (lang, t) in langs where blanks(t) != want { bad.append("\(lang): \(key)") }
        }
        XCTAssertEqual(bad, [], "translations whose blanks don't match their English")
    }
}
