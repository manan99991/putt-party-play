import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import HandyTools

/// "Shrink a photo to under 2 MB" and "Make a photo safe to share" made a 119 KB photo 124 KB (Nov 21): both
/// re-saved the picture. A photo already under the size, or one that only needs its hidden data removed, must come
/// back no bigger, with the same pixels and the same way up — and with no location in it.
final class NeverBiggerTests: XCTestCase {
    /// A real JPEG with a location, a camera name and a "turned 90°" orientation in it.
    private func taggedJPEG() throws -> Data {
        let size = CGSize(width: 640, height: 480)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            for i in 0..<12 {
                UIColor(hue: CGFloat(i) / 12, saturation: 0.8, brightness: 0.9, alpha: 1).setFill()
                ctx.fill(CGRect(x: CGFloat(i) * 53, y: CGFloat(i % 3) * 120, width: 90, height: 260))
            }
        }
        let cg = try XCTUnwrap(img.cgImage)
        let out = NSMutableData()
        let dst = try XCTUnwrap(CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil))
        let props: [CFString: Any] = [
            kCGImagePropertyOrientation: 6,
            kCGImageDestinationLossyCompressionQuality: 0.8,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 41.77, kCGImagePropertyGPSLatitudeRef: "N",
                                            kCGImagePropertyGPSLongitude: 88.15, kCGImagePropertyGPSLongitudeRef: "W"] as [CFString: Any],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "TestCam", kCGImagePropertyTIFFModel: "One"],
        ]
        CGImageDestinationAddImage(dst, cg, props as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dst))
        return out as Data
    }

    private func props(_ d: Data) throws -> [CFString: Any] {
        let s = try XCTUnwrap(CGImageSourceCreateWithData(d as CFData, nil))
        return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(s, 0, nil) as? [CFString: Any])
    }

    func testCleanCopyDropsLocationAndCameraButKeepsPictureAndWayUp() throws {
        let original = try taggedJPEG()
        XCTAssertNotNil(try props(original)[kCGImagePropertyGPSDictionary], "test photo should start with a location")
        let clean = try XCTUnwrap(ImageClean.withoutMetadata(original))
        let p = try props(clean)
        XCTAssertNil(p[kCGImagePropertyGPSDictionary], "location still in the photo")
        XCTAssertNil((p[kCGImagePropertyTIFFDictionary] as? [CFString: Any])?[kCGImagePropertyTIFFMake], "camera name still in the photo")
        XCTAssertEqual((p[kCGImagePropertyOrientation] as? NSNumber)?.intValue, 6, "the photo would be turned on its side")
        // Same pixels as the original (the renderer draws at screen scale, so compare with it, not with 640).
        XCTAssertEqual((p[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue, (try props(original)[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue)
        XCTAssertLessThanOrEqual(clean.count, original.count, "cleaned copy grew: \(original.count) → \(clean.count) bytes")
    }

    private func run(_ id: String, _ d: Data) async throws -> Data {
        let c = try XCTUnwrap(ChainTemplates.all.first { $0.id == id })
        guard case .success(.file(let out, let ext)) = await ChainRunner.run(c, input: .file(d, ext: "jpg")) else {
            XCTFail("\(id) gave no file"); return Data()
        }
        XCTAssertEqual(ext, "jpg")
        return out
    }

    func testShrinkUnderTwoMBNeverGrowsASmallPhoto() async throws {
        let d = try taggedJPEG()
        let out = try await run("photo-under-2mb", d)
        XCTAssertLessThanOrEqual(out.count, d.count, "\(d.count) → \(out.count) bytes")
        XCTAssertNil(try props(out)[kCGImagePropertyGPSDictionary])
    }

    func testSafeToShareNeverGrowsAndHasNoLocation() async throws {
        let d = try taggedJPEG()
        let out = try await run("safe-to-share", d)
        XCTAssertLessThanOrEqual(out.count, d.count, "\(d.count) → \(out.count) bytes")
        XCTAssertNil(try props(out)[kCGImagePropertyGPSDictionary])
        XCTAssertNotNil(UIImage(data: out))
    }
}
