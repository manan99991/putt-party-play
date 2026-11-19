import XCTest
@testable import HandyTools

/// The board reader's rules (the path every phone has): headings and their items, ticks, columns, calendars
/// whose day numbers must sit under the right weekdays, times written the way people write them, and
/// people-by-day grids.
final class UnderstandTests: XCTestCase {
    private func l(_ t: String, _ x: CGFloat, _ y: CGFloat, w: CGFloat = 0.2, h: CGFloat = 0.03) -> DocEngine.OCRLine {
        DocEngine.OCRLine(text: t, box: CGRect(x: x, y: y, width: w, height: h))
    }

    func testItemsLoseTheirBoxesAndKeepTheirTicks() {
        XCTAssertEqual(Understand.item("☐ outhouse").text, "outhouse")
        XCTAssertTrue(Understand.item("✓ wheel hoe").done)
        XCTAssertTrue(Understand.item("[x] call the vet").done)
        XCTAssertEqual(Understand.item("1. CHECK (watering)").text, "CHECK (watering)")
        XCTAssertEqual(Understand.item("o weed peas").text, "weed peas")
        XCTAssertFalse(Understand.item("☐ soil test").done)
    }

    func testListsKeepHeadingsAndColumns() {
        let lines = [
            l("BUILD-FIX", 0.05, 0.05), l("☐ outhouse", 0.06, 0.10), l("☐ gutter", 0.06, 0.14), l("✓ ext. lights", 0.06, 0.18),
            l("☐ market stand", 0.65, 0.05), l("☐ field stand", 0.65, 0.09), l("✓ wheel hoe", 0.65, 0.13), l("☐ tom cage", 0.65, 0.17),
        ]
        let b = Understand.parse(lines, now: Date())
        XCTAssertEqual(b.kind, .lists)
        XCTAssertEqual(b.sections, ["BUILD-FIX"])
        XCTAssertEqual(b.tasks.filter { $0.section == "BUILD-FIX" }.map(\.text), ["outhouse", "gutter", "ext. lights"])
        XCTAssertEqual(b.tasks.filter(\.done).map(\.text).sorted(), ["ext. lights", "wheel hoe"])
        XCTAssertEqual(b.tasks.count, 7, "both columns, nothing lost")
    }

    func testTimesWrittenOnCalendars() {
        XCTAssertEqual(Understand.time(in: "Dinner w/ Dad 1930").map { [$0.hour, $0.minute] }, [19, 30])
        XCTAssertEqual(Understand.time(in: "Skype w/ Aaron 900").map { [$0.hour, $0.minute] }, [9, 0])
        XCTAssertEqual(Understand.time(in: "gym 7pm").map { [$0.hour, $0.minute] }, [19, 0])
        XCTAssertEqual(Understand.time(in: "call at 10:15").map { [$0.hour, $0.minute] }, [10, 15])
        XCTAssertNil(Understand.time(in: "The List issue 2"))
    }

    func testCalendarDaysAreAlignedToTheRightMonth() {
        // A month that starts on a Monday: November 2027 starts on a Monday.
        let cal = Calendar(identifier: .gregorian)
        let now = cal.date(from: DateComponents(year: 2027, month: 11, day: 3))!
        var lines = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"].enumerated().map { l($0.element, 0.05 + CGFloat($0.offset) * 0.13, 0.05, w: 0.08) }
        for d in 1...14 {
            let col = (d - 1) % 7, row = (d - 1) / 7
            lines.append(l("\(d)", 0.13 + CGFloat(col) * 0.13, 0.12 + CGFloat(row) * 0.2, w: 0.02))
        }
        lines.append(l("Dinner w/ Dad 1930", 0.30, 0.16, w: 0.1))      // Wed 3
        lines.append(l("dentist", 0.04, 0.36, w: 0.08))                // Mon 8
        let b = Understand.parse(lines, now: now)
        XCTAssertEqual(b.kind, .calendar)
        XCTAssertEqual(b.month?.month, 11)
        let dinner = b.events.first { $0.title.contains("Dinner") }
        XCTAssertNotNil(dinner)
        XCTAssertEqual(dinner?.date.map { cal.component(.day, from: $0) }, 3)
        XCTAssertEqual(dinner?.date.map { cal.component(.hour, from: $0) }, 19)
        XCTAssertEqual(b.tasks.first { $0.text == "dentist" }?.due.map { cal.component(.day, from: $0) }, 8)
    }

    func testPeopleByDay() {
        var lines = ["NAME", "MON", "TUE", "WED", "THU"].enumerated().map { l($0.element, CGFloat($0.offset) * 0.22 + 0.02, 0.05, w: 0.1) }
        lines += [l("AL CANTOR", 0.02, 0.15, w: 0.15), l("Job 209", 0.24, 0.15, w: 0.1), l("Job 216", 0.46, 0.15, w: 0.1), l("Catch-up", 0.68, 0.15, w: 0.1),
                  l("KIM FARTHINGTON", 0.02, 0.25, w: 0.15), l("Vacation", 0.24, 0.25, w: 0.1)]
        let b = Understand.parse(lines, now: Date())
        XCTAssertEqual(b.kind, .people)
        XCTAssertTrue(b.people.contains { $0.person == "Al Cantor" && $0.day == "Tue" && $0.what == "Job 216" })
        XCTAssertTrue(b.people.contains { $0.person == "Kim Farthington" && $0.day == "Mon" && $0.what == "Vacation" })
    }

    @MainActor func testPlannerKeepsWhatWasChosen() {
        var b = Understand.Board(kind: .lists)
        b.tasks = [Understand.Item(text: "weed peas", section: "Farm"), Understand.Item(text: "gutter", section: "Farm", include: false)]
        b.events = [Understand.Event(title: "Dinner w/ Dad", date: Date(), hasTime: true)]
        let e = PlannerStore.entries(from: b, source: "test")
        XCTAssertEqual(e.map(\.text), ["weed peas", "Dinner w/ Dad"], "left-out items stay out")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("planner-\(UUID().uuidString).json")
        let store = PlannerStore(file: file)
        XCTAssertEqual(store.add(e), 2)
        XCTAssertEqual(store.add(e), 0, "the same board twice doesn't duplicate")
        XCTAssertEqual(PlannerStore(file: file).entries.count, 2, "kept on disk")
    }
}
