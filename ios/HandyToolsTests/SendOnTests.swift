import XCTest
@testable import HandyTools

final class SendOnTests: XCTestCase {
    private func place(_ id: String) -> SendOn.Place { SendOn.places.first { $0.id == id }! }

    /// Sending in a chat or by email stays here; posting (Stories, Status, Reels, X…) is Post it's job (SocialPostTests).
    func testOnlyChatsAndEmailLiveHere() {
        XCTAssertEqual(Set(SendOn.places.map(\.id)), ["wa", "email", "discord", "imessage"])
    }

    func testEmailShrinksOnlyWhenItHasTo() {
        XCTAssertEqual(SendOn.plan(duration: 30, bytes: 50_000_000, place: place("email")).targetBytes, 19_000_000)
        XCTAssertNil(SendOn.plan(duration: 30, bytes: 8_000_000, place: place("email")).targetBytes, "already small enough — original quality kept")
    }

    func testNoMoreThanEightPlacesAndEachHasALimit() {
        XCTAssertLessThanOrEqual(SendOn.places.count, 8)
        XCTAssertTrue(SendOn.places.allSatisfy { $0.maxBytes != nil || $0.maxSeconds != nil })
    }
}
