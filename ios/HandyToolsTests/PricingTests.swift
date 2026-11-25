import XCTest
@testable import HandyTools

/// Manan's pricing (22 Nov, shipped 25 Nov): Pro monthly $2.99 or yearly $29.99, each with a 7-day free trial;
/// a few tools free, the rest Pro. These keep the store, the paywall and the free list honest.
@MainActor
final class PricingTests: XCTestCase {
    func testBothPlansAreSold() {
        XCTAssertEqual(Set(StoreManager.productIDs), ["tenzy_pro_yearly", "tenzy_pro_month"])
    }

    func testNothingOnHomesFrontRowIsLocked() {
        // A new person taps the "Most loved" row first; none of those may meet a lock.
        for id in BuilderView.popular { XCTAssertFalse(TOOLS.first { $0.id == id }?.pro ?? true, "\(id) is on Home's front row but is Pro") }
        XCTAssertFalse(TOOLS.first { $0.id == "gpsdash" }?.pro ?? true, "Find my car (and automatic parking) is free")
    }

    func testTheFreeToolsPeopleAlreadyHadStayFree() {
        for id in ["light", "qrwifi", "seeread", "measure", "cleaner", "translate", "vault"] {
            XCTAssertFalse(TOOLS.first { $0.id == id }?.pro ?? true, "\(id) was free in the live app; taking it away would upset people")
        }
    }

    func testMostToolsArePro() {
        let pro = TOOLS.filter(\.pro).count
        XCTAssertGreaterThan(pro, TOOLS.count / 2, "a few tools free, the rest Pro")
        XCTAssertEqual(Tool.freeIDs.count, 13)
    }

    func testThePurchaseTermsSayEverythingAppleRequires() {
        // Guideline 3.1.2: price, period, when payment is taken, auto-renewal and how to cancel.
        for t in [PaywallView.trialTermsYear, PaywallView.trialTermsMonth, PaywallView.termsYear, PaywallView.termsMonth] {
            XCTAssertTrue(t.contains("%@"), "the price is shown")
            XCTAssertTrue(t.contains("Renews automatically"))
            XCTAssertTrue(t.contains("24 hours"))
            XCTAssertTrue(t.contains("Subscriptions"))
        }
        XCTAssertTrue(PaywallView.trialTermsMonth.contains("a month") && PaywallView.trialTermsYear.contains("a year"))
    }

    func testEveryPricingPhraseIsTranslatedWithTheSamePlaceholders() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "translations", withExtension: "json"))
        let table = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: [String: String]])
        let keys = [PaywallView.trialTermsYear, PaywallView.trialTermsMonth, PaywallView.termsYear, PaywallView.termsMonth,
                    "Try Pro free for %@", "Go Pro · %@ a year", "Go Pro · %@ a month", "%@ free, then %@ a year",
                    "%@ free, then %@ a month", "Save %d%%", "See Pro plans", "%@ a month or %@ a year · cancel anytime"]
        for k in keys {
            let row = try XCTUnwrap(table[k], "not translated: \(k)")
            XCTAssertEqual(row.count, 8, k)
            for (lang, v) in row {
                XCTAssertEqual(v.components(separatedBy: "%@").count, k.components(separatedBy: "%@").count, "\(lang): \(k)")
            }
        }
    }
}
