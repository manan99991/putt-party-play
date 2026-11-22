import XCTest
@testable import HandyTools

final class MedCareMessageTests: XCTestCase {
    /// The caregiver's text always says something useful — never just "No doses were due this week."
    func testTheUpdateIsNeverEmpty() {
        var m = Med(); m.name = "Ksif"
        let fresh = MedCare.update(to: "Jay Shah", meds: [m], taken: 0, due: 0, missed: [], today: [])
        XCTAssertTrue(fresh.hasPrefix("Hi Jay — "), fresh)
        XCTAssertTrue(fresh.contains("Reminders are set up"), fresh)
        XCTAssertTrue(fresh.contains("• Ksif — "), "the medicines and their times are in it: \(fresh)")
        let at = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let week = MedCare.update(to: "", meds: [m], taken: 6, due: 7, missed: ["Ksif Tue 8 AM"], today: [(name: "Ksif", at: at, taken: true)])
        XCTAssertTrue(week.contains("6 of 7 doses taken (86%)"), week)
        XCTAssertTrue(week.contains("Missed: Ksif Tue 8 AM"), week)
        XCTAssertTrue(week.contains("✓ taken"), week)
        XCTAssertTrue(week.hasPrefix("My medicines"), week)
        var paused = Med(); paused.name = "Old"; paused.paused = true
        XCTAssertFalse(MedCare.update(to: "", meds: [m, paused], taken: 0, due: 0, missed: [], today: []).contains("Old"))
    }

    func testTheMissedNoteAndTheListToShare() {
        let due = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let n = MedCare.missedNote("Ksif", due: due, to: "Jay")
        XCTAssertTrue(n.hasPrefix("Hi Jay — my Ksif (due "), n)
        XCTAssertTrue(n.hasSuffix("isn't marked taken yet. Just letting you know."), n)
        var m = Med(); m.name = "Ksif"
        let share = MedCare.shareMessage([m])
        XCTAssertTrue(share.contains("• Ksif — "))
        XCTAssertEqual(MedCare.imported(share)?.first?.name, "Ksif", "the whole message pastes straight back in")
    }
}
