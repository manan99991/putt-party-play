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

    /// Diagnostics (rulebook §8, run 1 led with "Night Sky 56%"): what each view of the photo is called, and how sure the
    /// classifier is of the TV and room words in each, so the next fix is chosen from numbers, not a guess.
    func testWhatEachViewOfTheLivingRoomIsCalled() throws {
        guard let root = ProcessInfo.processInfo.environment["REAL_PHOTOS"] else { throw XCTSkip("private photos not decrypted") }
        let url = URL(fileURLWithPath: root).appendingPathComponent("private/identify-living-room.jpg")
        guard let img = UIImage(contentsOfFile: url.path), let cg = img.normalizedUp().cgImage else { throw XCTSkip("no living-room photo") }
        let watch = ["television", "computer_monitor", "living_room", "sofa", "interior_room", "night_sky", "moon", "celestial_body", "screenshot", "container", "vase"]
        func views(_ f: CGFloat) -> [(String, CGImage)] {
            let w = CGFloat(cg.width), h = CGFloat(cg.height), cw = w * f, ch = h * f
            var out: [(String, CGImage)] = []; var y: CGFloat = 0
            while y + ch <= h + 1 { var x: CGFloat = 0
                while x + cw <= w + 1 { if let c = cg.cropping(to: CGRect(x: x, y: y, width: cw, height: ch).integral) { out.append(("\(Int(f * 100))% at \(Int(x / w * 100)),\(Int(y / h * 100))", c)) }; x += cw / 2 }
                y += ch / 2 }
            return out
        }
        var all: [(String, CGImage)] = [("whole \(cg.width)x\(cg.height)", cg)]
        let sal = VNGenerateObjectnessBasedSaliencyImageRequest()
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([sal])
        for (i, o) in ((sal.results?.first as? VNSaliencyImageObservation)?.salientObjects ?? []).enumerated() {
            let b = o.boundingBox
            print("IDENTIFY| salient \(i): x \(Int(b.minX * 100)) y \(Int((1 - b.maxY) * 100)) w \(Int(b.width * 100)) h \(Int(b.height * 100)) conf \(Int(o.confidence * 100))")
            let r = CGRect(x: b.minX * CGFloat(cg.width), y: (1 - b.maxY) * CGFloat(cg.height), width: b.width * CGFloat(cg.width), height: b.height * CGFloat(cg.height))
            if let c = cg.cropping(to: r.integral) { all.append(("salient \(i)", c)) }
        }
        all += views(0.5) + views(0.33)
        let rects = VNDetectRectanglesRequest(); rects.maximumObservations = 4; rects.minimumSize = 0.15; rects.minimumConfidence = 0.4; rects.minimumAspectRatio = 0.3
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([rects])
        for r in rects.results ?? [] { print("IDENTIFY| rectangle: x \(Int(r.boundingBox.minX * 100)) y \(Int((1 - r.boundingBox.maxY) * 100)) w \(Int(r.boundingBox.width * 100)) h \(Int(r.boundingBox.height * 100)) conf \(Int(r.confidence * 100))") }
        for (name, c) in all {
            let req = VNClassifyImageRequest()
            try? VNImageRequestHandler(cgImage: c, orientation: .up).perform([req])
            let res = req.results ?? []
            let top = res.prefix(6).map { "\($0.identifier) \(Int($0.confidence * 100))" }.joined(separator: ", ")
            let w = watch.compactMap { id in res.first { $0.identifier == id }.map { "\(id)=\(String(format: "%.2f", $0.confidence))" } }.joined(separator: " ")
            print("IDENTIFY| view \(name): \(top) || \(w)")
        }
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
