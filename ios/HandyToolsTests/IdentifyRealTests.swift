import XCTest
import Vision
import UIKit
@testable import HandyTools

/// Manan, 23 Nov: a photo of his living room with a big TV on the wall came back "Container 88%, Vase 88%,
/// Document, Screenshot, Art". The thing that fills the frame must lead. The photo is decrypted by CI into
/// $REAL_PHOTOS/private (skipped elsewhere).
final class IdentifyRealTests: XCTestCase {
    /// What Apple's on-phone classifier can name at all, for TVs and rooms — printed so a failure says why.
    func testWhatTheClassifierCanNameForATV() throws {
        let all = try VNClassifyImageRequest().supportedIdentifiers()
        let tv = all.filter { id in ["tv", "telev", "monitor", "screen", "display", "living", "sofa", "couch", "room"].contains { id.lowercased().contains($0) } }
        print("IDENTIFY| classifier knows \(all.count) labels; TV and room ones: \(tv.sorted().joined(separator: ", "))")
        XCTAssertGreaterThan(all.count, 500)
    }

    func testALivingRoomWithABigTVIsCalledATV() async throws {
        guard let root = ProcessInfo.processInfo.environment["REAL_PHOTOS"] else { throw XCTSkip("private photos not decrypted") }
        let url = URL(fileURLWithPath: root).appendingPathComponent("private/identify-living-room.jpg")
        guard let img = UIImage(contentsOfFile: url.path) else { throw XCTSkip("no living-room photo") }
        let o = await Identifier.identify(img)
        let labels = o.guesses.map { "\($0.label) \(Int($0.confidence * 100))%" }
        print("IDENTIFY| living room: \(labels.joined(separator: " | ")); subject \(o.subject); category \(o.category)")
        let top = (o.guesses.first?.label ?? "").lowercased()
        XCTAssertTrue(["tv", "televi", "monitor", "screen", "display"].contains { top.contains($0) }, "led with \(labels)")
        XCTAssertFalse(o.guesses.prefix(3).contains { ["container", "screenshot", "document"].contains($0.label.lowercased()) }, "filler words lead: \(labels)")
    }
}
