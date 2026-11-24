import XCTest
@testable import HandyTools

/// "For you now" (UX audit decision 2): the cards Home offers are the right ones, most pressing first, never more
/// than two, and Not now / Don't suggest really keep them away.
final class ForYouTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_795_460_400)   // a fixed moment, so times don't drift
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Chicago")!; return c }

    func testNothingSetUpMeansNoCards() {
        XCTAssertEqual(ForYou.cards(ForYou.Facts(now: now), cal: cal), [])
    }

    func testAMissedDoseComesFirstAndMarksTaken() {
        var f = ForYou.Facts(now: now)
        let med = UUID()
        f.doses = [(med, "Vitamin D", now.addingTimeInterval(-1800), false)]
        f.car = (41.7, -88.2, now.addingTimeInterval(-600))
        f.freeGB = 2
        let c = ForYou.cards(f, cal: cal)
        XCTAssertEqual(c.map(\.kind), [.dose, .car], "the missed dose, then the car; space waits (two cards at most)")
        XCTAssertEqual(c.first?.action, .markTaken(medID: med, at: now.addingTimeInterval(-1800)))
        XCTAssertTrue(c.first?.title.contains("did you take it") ?? false)
    }

    /// 24 Nov: lines built from the person's own data ("Vitamin D at 8:00 PM") stayed English in other languages. In
    /// German the card says it in German, with the medicine's own name kept as it was typed.
    func testCardLinesFollowTheAppLanguage() {
        let before = Localizer.chosen
        Localizer.shared.use("de")
        defer { Localizer.shared.use(before) }
        var f = ForYou.Facts(now: now)
        f.doses = [(UUID(), "Vitamin D", now.addingTimeInterval(-1800), false)]
        f.invoices = []
        let c = ForYou.cards(f, cal: cal)
        XCTAssertEqual(c.first?.title, "Vitamin D: hast du sie genommen?")
        XCTAssertTrue(c.first?.why.hasPrefix("Sie war um ") ?? false, "why: \(c.first?.why ?? "-")")
        XCTAssertEqual(c.first?.button, "Mark taken", "the button is translated where it's shown")
        f.doses = []
        f.screenshots = 812; f.screenshotLimit = 500
        XCTAssertEqual(ForYou.cards(f, cal: cal).first?.title, "812 Bildschirmfotos")
    }

    func testATakenOrFarOffDoseShowsNothing() {
        var f = ForYou.Facts(now: now)
        f.doses = [(UUID(), "A", now.addingTimeInterval(-1800), true),        // already taken
                   (UUID(), "B", now.addingTimeInterval(3 * 3600), false),    // hours away
                   (UUID(), "C", now.addingTimeInterval(-5 * 3600), false)]   // too long ago to nag
        XCTAssertEqual(ForYou.cards(f, cal: cal), [])
    }

    func testTheCarGivesWalkingDirectionsForTwoDays() {
        var f = ForYou.Facts(now: now)
        f.car = (41.7, -88.2, now.addingTimeInterval(-3600))
        XCTAssertEqual(ForYou.cards(f, cal: cal).first?.action, .directions(latitude: 41.7, longitude: -88.2))
        f.car = (41.7, -88.2, now.addingTimeInterval(-49 * 3600))
        XCTAssertEqual(ForYou.cards(f, cal: cal), [], "a spot from three days ago is old news")
    }

    func testAMeterRunningOutOutranksABill() {
        var f = ForYou.Facts(now: now)
        f.car = (1, 2, now.addingTimeInterval(-3600))
        f.meterEnds = now.addingTimeInterval(20 * 60)
        f.due = [("Electric bill", now.addingTimeInterval(86400), "$84")]
        let c = ForYou.cards(f, cal: cal)
        XCTAssertEqual(c.map(\.kind), [.car, .bill])
        XCTAssertEqual(c.first?.title, "Parking ends soon")
        XCTAssertEqual(c.last?.title, "Electric bill, $84")
    }

    func testABillMoreThanThreeDaysOutWaits() {
        var f = ForYou.Facts(now: now)
        f.due = [("Rent", now.addingTimeInterval(6 * 86400), nil)]
        XCTAssertEqual(ForYou.cards(f, cal: cal), [])
    }

    func testContactsBackupOnlyForABigListWithNoRecentBackup() {
        var f = ForYou.Facts(now: now)
        f.contactCount = 1240
        XCTAssertEqual(ForYou.cards(f, cal: cal).first?.title, "Back up 1,240 contacts")
        f.lastContactsBackup = now.addingTimeInterval(-10 * 86400)
        XCTAssertEqual(ForYou.cards(f, cal: cal), [], "backed up 10 days ago")
        f.lastContactsBackup = nil; f.contactCount = 80
        XCTAssertEqual(ForYou.cards(f, cal: cal), [], "a small list doesn't need nagging")
        f.contactCount = nil
        XCTAssertEqual(ForYou.cards(f, cal: cal), [], "no Contacts access: say nothing")
    }

    func testNotNowHidesThatCardAndDontSuggestHidesTheKind() {
        var f = ForYou.Facts(now: now)
        f.freeGB = 3
        let card = ForYou.cards(f, cal: cal)[0]
        XCTAssertEqual(ForYou.cards(f, hidden: [card.id: now.addingTimeInterval(7 * 86400)], cal: cal), [])
        XCTAssertEqual(ForYou.cards(f, hidden: [card.id: now.addingTimeInterval(-1)], cal: cal).count, 1, "a week later it can come back")
        XCTAssertEqual(ForYou.cards(f, off: [.space], cal: cal), [])
    }

    func testNeverMoreThanTwo() {
        var f = ForYou.Facts(now: now)
        f.doses = [(UUID(), "A", now.addingTimeInterval(600), false)]
        f.car = (1, 2, now)
        f.due = [("Water", now, nil)]
        f.freeGB = 1
        f.contactCount = 500
        XCTAssertEqual(ForYou.cards(f, cal: cal).count, ForYou.maxCards)
    }
}
