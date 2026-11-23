import XCTest
@testable import HandyTools

/// Each text tool offers only the ways in that make sense for it (Manan, 22 Nov: "why would someone speak a text
/// message?… Main ones are pasting an image or opening a screenshot"), and "Send where I am" fills itself in.
final class InputKitTests: XCTestCase {
    func testScamCheckTakesScreenshotsAndPhotosNotSpeechOrLocation() {
        let scam = Chain(id: "t-scam", name: "Check if a message is a scam", steps: [ChainStep(block: .scamCheck)])
        XCTAssertEqual(scam.textInputs, [.screenshot, .photo, .pdf])
        XCTAssertFalse(scam.textInputs.contains(.speak)); XCTAssertFalse(scam.textInputs.contains(.location)); XCTAssertFalse(scam.textInputs.contains(.contact))
        // Location is offered only where it's the point; Contact only for contact tools.
        let anyText = Chain(id: "t-sum", name: "Sum up", steps: [ChainStep(block: .summarize)])
        XCTAssertFalse(anyText.textInputs.contains(.location)); XCTAssertFalse(anyText.textInputs.contains(.contact))
        XCTAssertTrue(Chain(id: "t-qr", name: "QR", steps: [ChainStep(block: .contactQr)]).textInputs.contains(.contact))
        XCTAssertEqual(Chain(id: "where-i-am", name: "Send where I am", steps: [ChainStep(block: .cleanText)]).textInputs, [.location])
    }
}
