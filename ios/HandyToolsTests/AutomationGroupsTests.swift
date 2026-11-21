import XCTest
@testable import HandyTools

/// The automations hub sorts every waiting reminder under the tool that set it, by the names the tools use.
final class AutomationGroupsTests: XCTestCase {
    func testEachToolsRemindersLandInItsGroup() {
        let cases: [(String, String, String)] = [
            ("med-1234-d-8-0", "med", "medreminder"), ("medfu-1234-99", "med", "medreminder"),
            ("daily-brief", "brief", "brief"), ("bday-anna", "bday", "contacts"), ("contacts-backup", "backup", "contacts"),
            ("sorted-abc-day", "bills", "sorted"), ("warranty-abc", "warranty", "warranty"), ("vault-exp-x-3", "vault", "vault"),
            ("tool-receipts-0", "tools", "builder"), ("park-meter-soon", "park", "gpsdash"), ("rest-bedtime", "rest", "rest"),
            ("planner.morning.0", "planner", "planner"), ("arrive-1-home", "plans", "untangle"),
        ]
        for (id, key, tool) in cases {
            let g = AutomationGroups.group(id: id)
            XCTAssertEqual(g.key, key, id); XCTAssertEqual(g.tool, tool, id)
        }
    }
    func testAnUnknownReminderFallsBackToItsOpenHint() {
        XCTAssertEqual(AutomationGroups.group(id: "something-new", open: "sorted").key, "bills")
        XCTAssertEqual(AutomationGroups.group(id: "something-new").key, "other")
    }
    func testTestRunsAndSnoozesAreNotShownAsAutomations() {
        XCTAssertTrue(AutomationGroups.isOneOff("brief-test-1"))
        XCTAssertTrue(AutomationGroups.isOneOff("med-snooze-1"))
        XCTAssertFalse(AutomationGroups.isOneOff("med-1-d-8-0"))
    }
    @MainActor func testEveryIdeaOpensARealTool() {
        let ids = Set(TOOLS.map(\.id) + ["builder"])
        for i in AutomationGroups.ideas { XCTAssertTrue(ids.contains(i.tool), i.tool) }
    }
}
