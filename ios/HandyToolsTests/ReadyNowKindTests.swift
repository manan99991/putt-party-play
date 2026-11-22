import XCTest
@testable import HandyTools

/// "Ready now" suggestions fit what the person said they have.
final class ReadyNowKindTests: XCTestCase {
    func testNamesTheKind() {
        XCTAssertEqual(ReadyNow.kinds(in: "Shrink a photo, remove location, email it"), [.image])
        XCTAssertEqual(ReadyNow.kinds(in: "make this video smaller"), [.video])
        XCTAssertEqual(ReadyNow.kinds(in: "clean up my recording"), [.audio])
        XCTAssertEqual(ReadyNow.kinds(in: "sign the PDF"), [.pdf])
        XCTAssertTrue(ReadyNow.kinds(in: "remind me to call mum").isEmpty)
    }

    func testAPhotoRequestNeverOffersAnAudioTool() {
        let k = ReadyNow.kinds(in: "Shrink a photo, remove location, email it")
        XCTAssertFalse(ReadyNow.fits(tool: "audiocompress", kinds: k))
        XCTAssertTrue(ReadyNow.fits(tool: "fitit", kinds: k))
        XCTAssertTrue(ReadyNow.fits(tool: "scrub", kinds: k))
        XCTAssertTrue(ReadyNow.fits(tool: "light", kinds: k), "tools that take no file are never filtered")
    }

    func testFlowsStartWithWhatWasNamed() {
        XCTAssertTrue(ReadyNow.fits(start: .image, kinds: [.image]))
        XCTAssertTrue(ReadyNow.fits(start: .photoFile, kinds: [.image]))
        XCTAssertFalse(ReadyNow.fits(start: .audio, kinds: [.image]))
        XCTAssertTrue(ReadyNow.fits(start: .audio, kinds: []))
    }
}
