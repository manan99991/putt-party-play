import XCTest
@testable import HandyTools

/// Buttons outside the app (Control Center, the Lock Screen, a Shortcuts automation) hand Tenzy one ask, which it
/// carries out once when it opens — never a stale one from long ago.
final class OutsideAppTests: XCTestCase {
    func testAnAskIsTakenOnceAndGoesStale() {
        OutsideAction.ask("park")
        XCTAssertEqual(OutsideAction.take(), "park")
        XCTAssertNil(OutsideAction.take(), "taken once only")
        OutsideAction.ask("tool:scan")
        XCTAssertNil(OutsideAction.take(now: Date().addingTimeInterval(300)), "an ask from five minutes ago doesn't fire")
        XCTAssertNil(OutsideAction.take())
    }

    @MainActor func testTheParkingAskOpensFindMyCar() {
        var opened: [String] = []
        let o = NotificationCenter.default.addObserver(forName: .openTool, object: nil, queue: nil) { n in
            if let id = n.object as? String { opened.append(id) }
        }
        defer { NotificationCenter.default.removeObserver(o); ParkNow.pending = false }
        OutsideAction.ask("park")
        OutsideActions.run()
        XCTAssertEqual(opened, ["gpsdash"])
        XCTAssertTrue(ParkNow.pending, "the dashboard drops the pin on its first fix")
        OutsideAction.ask("tool:identify")
        OutsideActions.run()
        XCTAssertEqual(opened.last, "identify")
        OutsideAction.ask("tool:not-a-tool")
        OutsideActions.run()
        XCTAssertEqual(opened.count, 2, "an unknown tool opens nothing")
    }
}
