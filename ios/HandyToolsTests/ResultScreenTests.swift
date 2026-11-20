import XCTest
@testable import HandyTools

/// One job, one finished screen, every door: each ready-made tool must land on its job's real result screen, or be
/// on the public known-gap list (with the tracker group rebuilding it). The list can only shrink.
final class ResultScreenTests: XCTestCase {
    func testEveryReadyMadeToolLandsOnItsJobsScreenOrIsAnOpenGap() {
        var plain: [String] = [], fixedButListed: [String] = []
        for c in ChainTemplates.all {
            let screen = ResultScreens.screen(for: c)
            let listed = ResultScreens.knownGaps[c.id] != nil
            if screen == nil, !listed { plain.append("\(c.id) — \(c.name)") }
            if screen != nil, listed { fixedButListed.append(c.id) }
        }
        let onScreen = ChainTemplates.all.filter { ResultScreens.screen(for: $0) != nil }.count
        print("ACC| SCORE ready-made-on-real-screen n=\(ChainTemplates.all.count) \(String(format: "%.3f", Double(onScreen) / Double(max(1, ChainTemplates.all.count))))")
        XCTAssertEqual(plain, [], "ready-made tools ending on the plain result that aren't on the known-gap list")
        XCTAssertEqual(fixedButListed, [], "these now have a finished screen — take them off ResultScreens.knownGaps")
    }
}
