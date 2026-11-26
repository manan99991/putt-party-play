import XCTest
@testable import HandyTools

/// Voice memos into notes (26 Nov): which memos are written up (sound files saved in the window, each once), and what
/// each one is called.
final class SmartVoiceTests: XCTestCase {
    private let t = Date(timeIntervalSince1970: 1_790_000_000)

    func testOnlyTodaysNewSoundFilesAreWrittenUp() {
        let window = DateInterval(start: t.addingTimeInterval(-86_400), end: t)
        let files: [(name: String, modified: Date, bytes: Int)] = [
            ("New Recording 14.m4a", t.addingTimeInterval(-3600), 900_000),
            ("Standup notes.mp3", t.addingTimeInterval(-7200), 2_000_000),
            ("Lease.pdf", t.addingTimeInterval(-600), 300_000),                     // not a memo
            ("Old idea.m4a", t.addingTimeInterval(-3 * 86_400), 500_000),           // last week
            ("Empty.m4a", t.addingTimeInterval(-60), 1_200),                        // nothing recorded
        ]
        let picks = SmartVoice.picks(files, window: window, done: [])
        XCTAssertEqual(picks.map(\.name), ["Standup notes.mp3", "New Recording 14.m4a"], "oldest first")
        let again = SmartVoice.picks(files, window: window, done: Set(picks.map(\.id)))
        XCTAssertTrue(again.isEmpty, "a memo is never written up twice")
        // The same name saved again with new content is a new memo.
        let edited = SmartVoice.picks([("Standup notes.mp3", t.addingTimeInterval(-60), 2_100_000)], window: window, done: Set(picks.map(\.id)))
        XCTAssertEqual(edited.count, 1)
    }

    func testAMemoIsCalledByWhatItSaysUnlessThePersonNamedIt() {
        XCTAssertEqual(SmartVoice.title(name: "New Recording 14", headline: "Plan for the kitchen remodel"), "Plan for the kitchen remodel")
        XCTAssertEqual(SmartVoice.title(name: "20261126 093012", headline: "Call the bank about the card"), "Call the bank about the card")
        XCTAssertEqual(SmartVoice.title(name: "Standup notes", headline: "Sprint review moved"), "Standup notes")
    }

    func testTheNotesReadWellAsText() {
        let e = SmartVoice.Entry(id: "a", name: "x", recorded: t, seconds: 95, headline: "Kitchen remodel", points: ["Budget is $18k"], decisions: ["Go with quartz"],
                                 todos: [.init(task: "Send the floor plan", owner: "Sam", due: "Friday")], transcript: ["…"], people: ["Sam"])
        XCTAssertTrue(e.text.hasPrefix("Kitchen remodel\n"))
        XCTAssertTrue(e.text.contains("• Budget is $18k")); XCTAssertTrue(e.text.contains("☐ Send the floor plan — Sam · by Friday"))
    }
}
