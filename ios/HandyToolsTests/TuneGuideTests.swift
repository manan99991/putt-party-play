import XCTest
@testable import HandyTools

final class TuneGuideTests: XCTestCase {
    func testWhichWayToTurnThePeg() {
        let a2 = Pitch.frequency(midi: 45, a4: 440)            // 110 Hz, guitar's A string
        XCTAssertEqual(TuneGuide.advice(hz: 110.1, target: a2), .inTune)
        if case .up = TuneGuide.advice(hz: 104, target: a2) {} else { XCTFail("flat → tune up") }
        if case .down = TuneGuide.advice(hz: 116, target: a2) {} else { XCTFail("sharp → tune down") }
        if case .wrongString = TuneGuide.advice(hz: 147, target: a2) {} else { XCTFail("the D string is another string") }
        XCTAssertTrue(TuneGuide.words(.up(cents: 50)).contains("tighten"))
        XCTAssertTrue(TuneGuide.words(.down(cents: 10)).contains("loosen"))
    }
}

final class MeetingRemindersTests: XCTestCase {
    @MainActor func testWhoAndWhenComeWithEachToDo() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 19))!   // a Thursday
        let r = MeetingNotes.reminders(["Sam to send the deck by Friday", "Priya Shah will book the room tomorrow", "update the budget"], list: "Meeting", now: now)
        XCTAssertEqual(r.map(\.person), ["Sam", "Priya Shah", nil])
        XCTAssertEqual(r[0].due.map { Calendar.current.component(.weekday, from: $0) }, 6, "Friday")
        XCTAssertEqual(r[1].due.map { Calendar.current.component(.day, from: $0) }, 20, "tomorrow")
        XCTAssertNil(r[2].due)
    }
}
