import XCTest
@testable import HandyTools

/// Sheets (25 Nov redesign): a new sheet starts each week, two weeks, month, quarter or year; the one being filled is
/// marked "Now"; "start a new one" never overwrites; and a receipt that doesn't add up can't slip into a sheet.
final class SheetPeriodTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = Calendar(identifier: .gregorian); c.timeZone = utc
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testEachPeriodNamesItsSheet() {
        let wed = day(2026, 11, 25)
        XCTAssertEqual(SheetPeriod.monthly.token(wed, timeZone: utc), "2026-11")
        XCTAssertEqual(SheetPeriod.quarterly.token(wed, timeZone: utc), "2026-Q4")
        XCTAssertEqual(SheetPeriod.yearly.token(wed, timeZone: utc), "2026")
        XCTAssertEqual(SheetPeriod.weekly.token(wed, timeZone: utc), "2026-W48")
        XCTAssertEqual(SheetPeriod.biweekly.token(wed, timeZone: utc), "2026-W47-48")
        XCTAssertEqual(SheetPeriod.biweekly.token(day(2026, 11, 16), timeZone: utc), "2026-W47-48", "both weeks of a pair share a sheet")
        XCTAssertEqual(SheetPeriod.biweekly.token(day(2026, 11, 30), timeZone: utc), "2026-W49-50")
        XCTAssertEqual(SheetPeriod.quarterly.token(day(2026, 1, 1), timeZone: utc), "2026-Q1")
        XCTAssertEqual(SheetPeriod.quarterly.token(day(2026, 6, 30), timeZone: utc), "2026-Q2")
    }

    func testTheYearsEndWeeksBelongToTheRightYear() {
        // 1 Jan 2027 is in ISO week 53 of 2026; a 53rd week has no partner, so it stands alone.
        XCTAssertEqual(SheetPeriod.weekly.token(day(2027, 1, 1), timeZone: utc), "2026-W53")
        XCTAssertEqual(SheetPeriod.biweekly.token(day(2026, 12, 31), timeZone: utc), "2026-W53")
        XCTAssertEqual(SheetPeriod.monthly.token(day(2027, 1, 1), timeZone: utc), "2027-01")
        // 29 Dec 2025 is week 1 of 2026.
        XCTAssertEqual(SheetPeriod.weekly.token(day(2025, 12, 29), timeZone: utc), "2026-W01")
    }

    func testTheSheetsPeriodIsReadFromItsName() {
        XCTAssertEqual(RunningList.periodToken(in: "Expenses 2026-11"), "2026-11")
        XCTAssertEqual(RunningList.periodToken(in: "Expenses 2026-11 (2).csv"), "2026-11")
        XCTAssertEqual(RunningList.periodToken(in: "Miles 2026-W47-48"), "2026-W47-48")
        XCTAssertEqual(RunningList.periodToken(in: "Expenses 2026-Q4"), "2026-Q4")
        XCTAssertEqual(RunningList.periodToken(in: "Expenses 2026"), "2026")
        XCTAssertNil(RunningList.periodToken(in: "Invoice 1234"), "a number is not a year")
        XCTAssertNil(RunningList.periodToken(in: "Groceries"))
    }

    func testNowIsOnlyThisPeriodsSheet() {
        let now = day(2026, 11, 15)
        XCTAssertTrue(RunningList.isCurrent("Expenses \(SheetPeriod.monthly.token(now))", period: .monthly, now: now))
        XCTAssertTrue(RunningList.isCurrent("Expenses \(SheetPeriod.monthly.token(now)) (2)", period: .monthly, now: now))
        XCTAssertFalse(RunningList.isCurrent("Expenses 2026-10", period: .monthly, now: now))
        XCTAssertFalse(RunningList.isCurrent("Expenses 2026-11", period: .yearly, now: now), "a month's sheet is not the year's")
        XCTAssertFalse(RunningList.isCurrent("Groceries", period: .monthly, now: now))
    }

    func testStartingANewSheetNeverOverwrites() {
        XCTAssertEqual(RunningList.nextName(after: "Expenses 2026-11.csv", taken: []), "Expenses 2026-11 (2).csv")
        XCTAssertEqual(RunningList.nextName(after: "Expenses 2026-11.csv", taken: ["Expenses 2026-11 (2).csv"]), "Expenses 2026-11 (3).csv")
        XCTAssertEqual(RunningList.nextName(after: "Expenses 2026-11 (2).csv", taken: ["Expenses 2026-11 (2).csv"]), "Expenses 2026-11 (3).csv")
    }

    func testAMonthlySheetKeepsTheNameItAlwaysHad() {
        let before = UserDefaults.standard.string(forKey: SheetPeriod.key)
        defer { UserDefaults.standard.set(before, forKey: SheetPeriod.key) }
        SheetPeriod.current = .monthly
        let d = day(2026, 11, 15)
        XCTAssertEqual(ChainName.file(pattern: RunningList.defaultName, tool: "List", day: d, ext: "csv"), "Expenses \(SheetPeriod.monthly.token(d)).csv")
        SheetPeriod.current = .quarterly
        XCTAssertEqual(ChainName.file(pattern: RunningList.defaultName, tool: "List", day: d, ext: "csv"), "Expenses 2026-Q4.csv")
    }

    func testAReceiptThatDoesntAddUpCantBeAdded() {
        var r = DataGrab.Receipt()
        r.merchant = "Corner Store"; r.date = day(2026, 11, 20)
        XCTAssertNotNil(DataGrab.entryProblems(r).block, "no total")
        r.total = 0
        XCTAssertNotNil(DataGrab.entryProblems(r).block, "a zero total is a misread")
        r.total = 12.50
        XCTAssertNil(DataGrab.entryProblems(r).block)
        XCTAssertTrue(DataGrab.entryProblems(r).unsure.isEmpty)
        r.lines = [.init(name: "Milk", qty: nil, unit: nil, amount: 4.00), .init(name: "Bread", qty: nil, unit: nil, amount: 3.00)]
        XCTAssertNotNil(DataGrab.entryProblems(r).block, "items add up to 7.00 but the total says 12.50")
        XCTAssertTrue(DataGrab.entryProblems(r).unsure.contains("total"))
        r.total = 7.00
        XCTAssertNil(DataGrab.entryProblems(r).block)
    }

    func testAMissingShopOrDateIsMarkedNotBlocked() {
        var r = DataGrab.Receipt(); r.total = 9.99
        let p = DataGrab.entryProblems(r)
        XCTAssertNil(p.block)
        XCTAssertEqual(p.unsure, ["shop", "date"])
    }
}
