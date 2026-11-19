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
