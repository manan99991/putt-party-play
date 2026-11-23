import XCTest
import AVFoundation
import ImageIO
@testable import HandyTools

/// The `-sample` inputs must be able to fail the checks they feed: a "remove the location" test needs a photo
/// that has one, a "remove the sound" test needs a video that has sound. Otherwise those tests prove nothing.
final class SampleInputsTests: XCTestCase {
    func testSamplePhotoCarriesALocation() throws {
        let data = try XCTUnwrap(SampleAssets.jpegWithLocation(SampleAssets.photo()))
        let src = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any])
        let gps = try XCTUnwrap(props[kCGImagePropertyGPSDictionary] as? [CFString: Any], "sample photo has no GPS block")
        XCTAssertEqual(gps[kCGImagePropertyGPSLatitude] as? Double ?? 0, 41.8781, accuracy: 0.001)
        XCTAssertEqual(gps[kCGImagePropertyGPSLongitudeRef] as? String, "W")
        XCTAssertNotNil(UIImage(data: data), "sample photo must still decode as a normal JPEG")
    }

    func testSampleVideoWithSoundHasAnAudioTrack() async throws {
        let url = try await XCTUnwrapAsync(await SampleAssets.movie(withSound: true))
        let asset = AVURLAsset(url: url)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        let video = try await asset.loadTracks(withMediaType: .video)
        XCTAssertFalse(audio.isEmpty, "sample video with sound has no audio track")
        XCTAssertFalse(video.isEmpty)
        XCTAssertTrue(url.lastPathComponent.hasPrefix("sample-"), "inputs are named sample-… so testers never mistake them for outputs")
    }

    func testDefaultSampleVideoStaysSilent() async throws {
        let url = try await XCTUnwrapAsync(await SampleAssets.movie())
        let audio = try await AVURLAsset(url: url).loadTracks(withMediaType: .audio)
        XCTAssertTrue(audio.isEmpty, "other tests rely on the default sample being silent")
    }

    private func XCTUnwrapAsync<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) async throws -> T {
        try XCTUnwrap(value, file: file, line: line)
    }
}
