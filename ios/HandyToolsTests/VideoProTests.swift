import XCTest
import AVFoundation
import CoreImage
@testable import HandyTools

/// Camera video gets the same one-button Pro finish as photos: one look for the whole clip, a crooked horizon turned
/// level without black corners, and a finished file that is the same length as what was filmed.
final class VideoProTests: XCTestCase {

    func testAFrameIsLevelledWithoutLeavingTheFrame() {
        let img = CIImage(color: CIColor(red: 0.4, green: 0.5, blue: 0.6)).cropped(to: CGRect(x: 0, y: 0, width: 640, height: 360))
        let plan = VideoPro.Plan(tilt: 3, steps: [("CIVibrance", ["inputAmount": 0.3])])
        let out = VideoPro.finish(img, plan: plan)
        XCTAssertEqual(out.extent, img.extent, "a finished frame keeps the clip's size")
        // The corners are filled by the slight zoom, not left black.
        let ctx = CIContext()
        var px = [UInt8](repeating: 0, count: 4)
        ctx.render(out, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        XCTAssertGreaterThan(Int(px[2]), 60, "a black corner after straightening")
        XCTAssertTrue(VideoPro.Plan(tilt: nil, steps: []).isEmpty)
    }

    func testAClipComesOutFinishedAtTheSameLength() async throws {
        let made0 = await EngineTests.movie(seconds: 2)
        let src = try XCTUnwrap(made0)
        let asset = AVURLAsset(url: src)
        let planned = await VideoPro.plan(for: asset)
        let plan = try XCTUnwrap(planned, "the middle frame could be read")
        let composed = await VideoPro.composition(for: asset, plan: plan)
        let comp = try XCTUnwrap(composed)
        let exported = await VideoPro.export(asset, composition: comp)
        let out = try XCTUnwrap(exported)
        defer { try? FileManager.default.removeItem(at: out) }
        let made = AVURLAsset(url: out)
        let a = try await asset.load(.duration).seconds, b = try await made.load(.duration).seconds
        XCTAssertEqual(b, a, accuracy: 0.15)
        let tracks = try await made.loadTracks(withMediaType: .video)
        XCTAssertEqual(tracks.count, 1)
    }
}
