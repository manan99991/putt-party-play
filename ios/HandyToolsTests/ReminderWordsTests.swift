import XCTest
@testable import HandyTools

/// 26 Nov: "remind me…" in the ask box sets the reminder in one tap. Every common way of saying it, at fixed times, so
/// the what, the when and whether it repeats are exactly right — a wrong reminder is worse than none.
final class ReminderWordsTests: XCTestCase {
    private var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Chicago")!; return c }()
    /// Wednesday 25 Nov 2026 at the given time, Chicago. (It said 26 Nov, which is a Thursday, so "on Friday" was
    /// tomorrow and the test expected the wrong day; the reader was right.)
    private func wed(_ h: Int, _ m: Int = 0) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: h, minute: m))! }
    private func parts(_ d: Date?) -> (day: Int, hour: Int, minute: Int) {
        guard let d else { return (-1, -1, -1) }
        let c = cal.dateComponents([.day, .hour, .minute], from: d)
        return (c.day!, c.hour!, c.minute!)
    }
    private func r(_ s: String, at now: Date) -> OwnReminder? { ReminderWords.parse(s, now: now, calendar: cal) }

    func testOnlyRemindMeSentencesAreReminders() {
        XCTAssertNil(r("email today's screenshots to myself every evening", at: wed(10)))
        XCTAssertNil(r("make my voice sound like a robot", at: wed(10)))
        XCTAssertNotNil(r("Remind me to call Mum", at: wed(10)))
        XCTAssertNotNil(r("don't let me forget the passports", at: wed(10)))
        XCTAssertNotNil(r("set a reminder to water the plants", at: wed(10)))
    }

    func testAOneOffAtATime() {
        let a = r("Remind me to call Mum at 6", at: wed(10))!
        XCTAssertEqual(a.text, "Call Mum", "the person's own capitals are kept")
        XCTAssertTrue(a.once)
        XCTAssertEqual(parts(a.onceAt).day, 25); XCTAssertEqual(parts(a.onceAt).hour, 18, "a bare 6 is the evening")
        let b = r("remind me to take the cake out at 7:45 pm.", at: wed(10))!
        XCTAssertEqual(b.text, "Take the cake out")
        XCTAssertEqual(parts(b.onceAt).hour, 19); XCTAssertEqual(parts(b.onceAt).minute, 45)
        // "at 9" said at 10 in the morning: 9 tonight, not tomorrow morning.
        let c = r("remind me at 9 to lock the back door", at: wed(10))!
        XCTAssertEqual(c.text, "Lock the back door")
        XCTAssertEqual(parts(c.onceAt).day, 25); XCTAssertEqual(parts(c.onceAt).hour, 21)
        // "at 9am" said at 10: tomorrow at 9.
        let d = r("remind me at 9am to call the bank", at: wed(10))!
        XCTAssertEqual(parts(d.onceAt).day, 26); XCTAssertEqual(parts(d.onceAt).hour, 9)
        XCTAssertEqual(r("remind me to have lunch at noon", at: wed(9))!.onceAt.map { parts($0).hour }, 12)
    }

    func testTomorrowTonightAndADay() {
        let a = r("tomorrow at 9 remind me to pay rent", at: wed(22))!
        XCTAssertEqual(a.text, "Pay rent")
        XCTAssertEqual(parts(a.onceAt).day, 26); XCTAssertEqual(parts(a.onceAt).hour, 9, "tomorrow's 9 is the morning even late at night")
        let b = r("remind me tonight to charge the car", at: wed(10))!
        XCTAssertEqual(b.text, "Charge the car")
        XCTAssertEqual(parts(b.onceAt).day, 25); XCTAssertEqual(parts(b.onceAt).hour, 21)
        let c = r("remind me tonight at 8 to put the bins out", at: wed(10))!
        XCTAssertEqual(parts(c.onceAt).hour, 20)
        let d = r("remind me on Friday to send the invoice", at: wed(10))!
        XCTAssertEqual(d.text, "Send the invoice")
        XCTAssertEqual(parts(d.onceAt).day, 27); XCTAssertEqual(parts(d.onceAt).hour, 9)
        let e = r("remind me tomorrow morning about the dentist", at: wed(10))!
        XCTAssertEqual(e.text, "The dentist")
        XCTAssertEqual(parts(e.onceAt).day, 26); XCTAssertEqual(parts(e.onceAt).hour, 8)
        let f = r("remind me on friday evening to call bob", at: wed(10))!
        XCTAssertEqual(f.text, "Call bob")
        XCTAssertEqual(parts(f.onceAt).day, 27); XCTAssertEqual(parts(f.onceAt).hour, 19)
    }

    func testInSomeMinutes() {
        let a = r("remind me in 20 minutes to check the oven", at: wed(10))!
        XCTAssertEqual(a.text, "Check the oven")
        XCTAssertEqual(parts(a.onceAt).hour, 10); XCTAssertEqual(parts(a.onceAt).minute, 20)
        let b = r("Remind me in an hour to move the car", at: wed(10, 30))!
        XCTAssertEqual(b.text, "Move the car")
        XCTAssertEqual(parts(b.onceAt).hour, 11); XCTAssertEqual(parts(b.onceAt).minute, 30)
        let c = r("remind me in half an hour to take the laundry out", at: wed(10))!
        XCTAssertEqual(parts(c.onceAt).minute, 30)
    }

    func testRepeats() {
        let a = r("remind me every Monday to put the bins out", at: wed(10))!
        XCTAssertEqual(a.text, "Put the bins out")
        XCTAssertFalse(a.once); XCTAssertEqual(a.schedule.days, [2]); XCTAssertEqual(a.schedule.hour, 9)
        let b = r("Remind me to take my vitamins every day at 8am", at: wed(10))!
        XCTAssertEqual(b.text, "Take my vitamins")
        XCTAssertFalse(b.once); XCTAssertEqual(b.schedule.days, []); XCTAssertEqual(b.schedule.hour, 8)
        let c = r("remind me on weekdays at 7:30 to leave for school", at: wed(10))!
        XCTAssertEqual(c.text, "Leave for school")
        XCTAssertEqual(c.schedule.days, [2, 3, 4, 5, 6]); XCTAssertEqual(c.schedule.hour, 7); XCTAssertEqual(c.schedule.minute, 30)
        let d = r("every evening remind me to lock up", at: wed(10))!
        XCTAssertEqual(d.text, "Lock up")
        XCTAssertFalse(d.once); XCTAssertEqual(d.schedule.hour, 19)
        let e = r("remind me every monday and thursday at 6 to go to the gym", at: wed(10))!
        XCTAssertEqual(e.text, "Go to the gym")
        XCTAssertEqual(e.schedule.days.sorted(), [2, 5]); XCTAssertEqual(e.schedule.hour, 18)
        let f = r("remind me on saturdays to water the plants", at: wed(10))!
        XCTAssertFalse(f.once); XCTAssertEqual(f.schedule.days, [7])
    }

    func testNeverInThePastAndAlwaysSays() {
        for s in ["remind me to call Mum at 6", "remind me at 7", "remind me tonight to stretch", "remind me today at 9 to read",
                  "remind me to pay rent", "remind me on wednesday to call", "remind me in 5 minutes"] {
            for h in [0, 6, 9, 12, 17, 21, 23] {
                guard let x = r(s, at: wed(h)) else { XCTFail("\(s) wasn't read as a reminder"); continue }
                XCTAssertFalse(x.text.isEmpty, s)
                if x.once { XCTAssertGreaterThan(x.onceAt ?? .distantPast, wed(h), "\(s) at \(h):00 was set in the past") }
            }
        }
        XCTAssertEqual(r("remind me at 7", at: wed(10))!.text, "Reminder")
    }
}
