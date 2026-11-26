import XCTest
import AVFoundation
@testable import HandyTools

/// Settings › Help › Watch how (26 Nov): the three films ship inside the app, each is a real short video that plays,
/// and each list line fits on one line.
final class HowToVideosTests: XCTestCase {
    func testAllThreeFilmsShipAndPlay() async throws {
        XCTAssertEqual(HowToVideo.available.map(\.id), HowToVideo.all.map(\.id), "a how-to film is missing from the app")
        for v in HowToVideo.all {
            let url = try XCTUnwrap(v.url, "\(v.id).mp4 isn't in the app")
            let asset = AVURLAsset(url: url)
            let seconds = try await asset.load(.duration).seconds
            XCTAssert(seconds > 8 && seconds < 40, "\(v.id) runs \(seconds) s — a how-to film should be short but complete")
            let tracks = try await asset.loadTracks(withMediaType: .video)
            XCTAssertEqual(tracks.count, 1, "\(v.id) has no picture")
            if let t = tracks.first {
                let size = try await t.load(.naturalSize)
                XCTAssertGreaterThan(size.height, size.width, "\(v.id) isn't the phone's tall shape: \(size)")
            }
        }
    }

    func testEachLineIsShort() {
        for v in HowToVideo.all {
            XCTAssertLessThanOrEqual(v.line.count, 34, "\"\(v.line)\" is too long for one line")
            XCTAssertLessThanOrEqual(v.title.count, 30, "\"\(v.title)\" is too long for one line")
        }
    }
}
