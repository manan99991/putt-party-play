import XCTest
@testable import HandyTools

/// Meeting Notes' written part (Manan, 23 Nov: summary was "Okay. Okay. Okay.", 36 "to-dos" that were just chat, and
/// an email that dumped all of it). Built from lines of his real meeting.
final class MeetingDigestTests: XCTestCase {
    private let meeting = """
    Okay. Okay. Okay. So when we try, we get into the information page and it says there are like 2 star features that you have to look into. \
    And then, in order to do, like, payload trials, you would just put, like, an hourglass in the bottom right corner of the payload icon. \
    The whole point of the modal dialogue is that the operator has to acknowledge that a feature was installed before they get to the landing screen. \
    Once the operator acknowledges the change, the dialogue box goes away and the badges go away. \
    When the trial has expired, the information page should show that the feature is no longer installed. \
    Yeah, I, when I do, all those changes and then for one final checkup, maybe I'll send it to you. \
    And then, like, yeah, I've got all the requirements, so now I should, I'll start working on it for this week. \
    Sam will send the revised mockups by Friday. Can you share the passcode rules before Monday? \
    We agreed that the dialogue shows once per install. So I'll do a quick rebase next week when everybody's back. \
    I need to drop another call. Thank you, everybody. I'll talk to you all next week. Have a wonderful day. Bye guys. Thank you, bye-bye.
    """

    func testFillerAndSmallTalkNeverBecomeAPoint() {
        XCTAssertTrue(MeetingDigest.isNoise("Okay."))
        XCTAssertTrue(MeetingDigest.isNoise("Thank you, bye-bye."))
        XCTAssertTrue(MeetingDigest.isNoise("Bye guys."))
        XCTAssertFalse(MeetingDigest.isNoise("The operator has to acknowledge that a feature was installed."))
        let r = MeetingDigest.builtIn(meeting)
        XCTAssertFalse(r.points.isEmpty)
        XCTAssertLessThanOrEqual(r.points.count, 4, "a summary is short")
        for p in r.points {
            XCTAssertFalse(p.lowercased().hasPrefix("okay"), "a filler line became a point: \(p)")
            XCTAssertLessThanOrEqual(p.split(separator: " ").count, 32, "a point is one readable sentence: \(p)")
        }
    }

    func testCleaningKeepsTheMeaning() {
        XCTAssertEqual(MeetingDigest.clean("And then, like, you know, we I I ship it"), "And then, we I ship it")
        XCTAssertEqual(MeetingDigest.clean("um so the payload page"), "So the payload page")
    }

    func testOnlyRealCommitmentsBecomeToDos() {
        let todos = MeetingDigest.builtIn(meeting).actions
        let lines = todos.map(\.line)
        XCTAssertTrue(todos.contains { $0.owner == "Sam" && $0.task.hasPrefix("Send the revised mockups") && $0.due == "Friday" }, "\(lines)")
        XCTAssertTrue(todos.contains { $0.task.hasPrefix("Share the passcode rules") && $0.due == "Monday" }, "\(lines)")
        XCTAssertTrue(todos.contains { $0.task.hasPrefix("Start working on it") && $0.owner == "Me" }, "\(lines)")
        XCTAssertTrue(todos.contains { $0.task.hasPrefix("Do a quick rebase") }, "\(lines)")
        XCTAssertFalse(lines.contains { $0.lowercased().contains("drop another call") }, "leaving the call isn't a to-do: \(lines)")
        XCTAssertFalse(lines.contains { $0.lowercased().contains("send it to you") }, "\"maybe I'll\" is hedged, not a commitment: \(lines)")
        XCTAssertFalse(lines.contains { $0.lowercased().contains("talk to you") }, "\(lines)")
        XCTAssertLessThanOrEqual(todos.count, 8)
    }

    func testDecisionsArePickedOut() {
        XCTAssertEqual(MeetingDigest.builtIn(meeting).decisions.count, 1)
    }

    func testReadingTheModelsNotes() {
        let n = MeetingDigest.parse("""
        HEADLINE: Feature-install dialogue on the operator screen
        POINT: The operator must acknowledge each new feature before the landing screen.
        DECISION: The dialogue shows once per install
        ACTION: Send the revised mockups | Sam | Friday
        ACTION: Share the passcode rules | - | before Monday
        ACTION: Talk | - | -
        """)
        XCTAssertEqual(n.headline, "Feature-install dialogue on the operator screen")
        XCTAssertEqual(n.points.count, 1)
        XCTAssertEqual(n.decisions, ["The dialogue shows once per install."])
        XCTAssertEqual(n.actions, [MeetingDigest.Action(task: "Send the revised mockups", owner: "Sam", due: "Friday"),
                                   MeetingDigest.Action(task: "Share the passcode rules", owner: nil, due: "before Monday")])
        XCTAssertEqual(MeetingDigest.parse("NONE"), MeetingDigest.Notes())
    }

    func testTheSameTaskTwiceIsKeptOnce() {
        let a = MeetingDigest.dedupe([MeetingDigest.Action(task: "Send the revised mockups", owner: nil, due: nil),
                                      MeetingDigest.Action(task: "Send revised mockups to the team", owner: "Sam", due: "Friday")])
        XCTAssertEqual(a.count, 1)
        XCTAssertEqual(a[0].owner, "Sam"); XCTAssertEqual(a[0].due, "Friday")
    }

    func testPartsFitTheModel() {
        let long = Array(repeating: "The operator acknowledges the install and the badge goes away.", count: 400).joined(separator: " ")
        let parts = MeetingDigest.chunks(long, words: 850)
        XCTAssertGreaterThan(parts.count, 3)
        XCTAssertTrue(parts.allSatisfy { $0.split(separator: " ").count <= 860 })
    }

    func testTheEmailIsCrisp() {
        let r = MeetingDigest.Result(headline: "Feature-install dialogue", points: ["One.", "Two.", "Three.", "Four."],
                                     decisions: ["Show it once per install."],
                                     actions: [.init(task: "Send the revised mockups", owner: "Sam", due: "Friday"),
                                               .init(task: "Start the build", owner: "Me", due: nil),
                                               .init(task: "Share the passcode rules", owner: nil, due: "Monday")],
                                     engine: .builtIn)
        let e = MeetingDigest.email(r, people: ["Sam"], meeting: "Weekly")
        XCTAssertEqual(e.subject, "Recap: Feature-install dialogue")
        XCTAssertTrue(e.body.hasPrefix("Hi Sam,"))
        XCTAssertFalse(e.body.contains("Four."), "three points at most")
        XCTAssertTrue(e.body.contains("We agreed:\n\n• Show it once per install."))
        XCTAssertTrue(e.body.contains("• Sam: Send the revised mockups — by Friday"))
        XCTAssertTrue(e.body.contains("• I'll start the build"))
        XCTAssertTrue(e.body.contains("• Share the passcode rules — by Monday"))
        XCTAssertFalse(e.body.contains("☐"))
        let none = MeetingDigest.email(MeetingDigest.Result(headline: "About: roadmap", points: ["A."], decisions: [], actions: [], engine: .builtIn), people: [], meeting: "Weekly")
        XCTAssertEqual(none.subject, "Recap: roadmap")
        XCTAssertTrue(none.body.contains("No action items came up"))
    }

    func testTheNarratorReadsWordsNotSymbols() {
        XCTAssertEqual(MeetingDigest.speakable(["☐ Send the deck — Sam · by Friday", "• Done"]), "Send the deck, Sam, by Friday. Done.")
    }
}
