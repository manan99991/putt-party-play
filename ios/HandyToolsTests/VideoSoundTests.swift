import XCTest
import AVFoundation
import CoreImage
import UIKit
@testable import HandyTools

/// 26 Nov: the Video Studio's sound and the person's own photo behind them. Proved on the saved file: music Tenzy
/// makes is really under the video for its whole length, "No sound" has none, a short song is repeated to the end,
/// and the mix slider is the volumes it says.
final class VideoSoundTests: XCTestCase {
    func testTheMixSliderIsBothFullInTheMiddle() {
        XCTAssertEqual(VideoSound.volumes(keep: 0).music, 1); XCTAssertEqual(VideoSound.volumes(keep: 0).video, 0)
        XCTAssertEqual(VideoSound.volumes(keep: 1).music, 0); XCTAssertEqual(VideoSound.volumes(keep: 1).video, 1)
        XCTAssertEqual(VideoSound.volumes(keep: 0.5).music, 1); XCTAssertEqual(VideoSound.volumes(keep: 0.5).video, 1)
        XCTAssertEqual(VideoSound.volumes(keep: 0.25).video, 0.5, accuracy: 0.001)
        XCTAssertEqual(VideoSound.volumes(keep: 7).video, 1); XCTAssertEqual(VideoSound.volumes(keep: -3).music, 1)
    }

    func testAShortSongIsRepeatedToTheEndOfTheVideo() {
        let l = VideoSound.loops(song: 4, video: 10)
        XCTAssertEqual(l.map(\.at), [0, 4, 8]); XCTAssertEqual(l.map(\.play), [4, 4, 2])
        XCTAssertEqual(VideoSound.loops(song: 30, video: 10).map(\.play), [10], "a long song plays once, cut at the video's end")
        XCTAssertTrue(VideoSound.loops(song: 0, video: 10).isEmpty)
        XCTAssertEqual(VideoSound.loops(song: 3, video: 9).reduce(0) { $0 + $1.play }, 9, accuracy: 0.001)
    }

    func testEveryMusicChoiceHasAShortName() {
        XCTAssertEqual(VideoSound.choices.first?.id, "original")
        XCTAssertEqual(VideoSound.choices.filter { $0.id.hasPrefix("synth:") }.count, Synth.styles.count)
        for c in VideoSound.choices { XCTAssertLessThanOrEqual(c.name.count, 12, c.id) }
    }

    /// How loud the saved file's sound is over each half-second (nil if it has no sound).
    private func loudness(_ url: URL) async -> [Double]? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first, let reader = try? AVAssetReader(asset: asset) else { return nil }
        let out = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
                                                                          AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false, AVNumberOfChannelsKey: 1, AVSampleRateKey: 22_050])
        reader.add(out); reader.startReading()
        var all: [Int16] = []
        while let buf = out.copyNextSampleBuffer(), let block = CMSampleBufferGetDataBuffer(buf) {
            let n = CMBlockBufferGetDataLength(block)
            var bytes = [UInt8](repeating: 0, count: n)
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: n, destination: &bytes)
            bytes.withUnsafeBytes { all.append(contentsOf: $0.bindMemory(to: Int16.self)) }
        }
        let win = 11_025
        return stride(from: 0, to: all.count - win + 1, by: win).map { i in
            sqrt(all[i..<(i + win)].reduce(0.0) { $0 + Double($1) * Double($1) } / Double(win)) / 32768
        }
    }

    func testMusicIsUnderTheWholeVideoAndNoSoundHasNone() async throws {
        let movie = await SampleAssets.movie(seconds: 5, size: CGSize(width: 320, height: 568))
        let src = try XCTUnwrap(movie)
        // Music Tenzy makes, on its own.
        var r = VideoFX.Recipe(); r.music = "synth:party"; r.keep = 0
        XCTAssertFalse(r.isPlain, "music alone is a change worth saving")
        let made = await VideoFX.export(src, recipe: r, caption: nil)
        let withMusic = try XCTUnwrap(made, "the video with music couldn't be saved")
        let seconds = try await AVURLAsset(url: withMusic).load(.duration).seconds
        XCTAssertEqual(seconds, 5, accuracy: 0.4, "the music mustn't make the video longer")
        let loudOpt = await loudness(withMusic)
        let loud = try XCTUnwrap(loudOpt, "the saved video has no sound track")
        print("VIDEOFX|studio-music|" + loud.map { String(format: "%.3f", $0) }.joined(separator: " "))
        XCTAssertGreaterThanOrEqual(loud.count, 8)
        for (i, v) in loud.dropLast(3).enumerated() { XCTAssertGreaterThan(v, 0.02, "the music stops at \(Double(i) / 2) s") }
        XCTAssertLessThan(loud.last ?? 1, (loud.dropLast(4).max() ?? 0) * 0.7, "the music doesn't fade out at the end")
        let videoTracks = try await AVURLAsset(url: withMusic).loadTracks(withMediaType: .video)
        XCTAssertEqual(videoTracks.count, 1)
        // No sound at all.
        var quiet = VideoFX.Recipe(); quiet.music = "none"
        let q = await VideoFX.export(src, recipe: quiet, caption: nil)
        let silent = try XCTUnwrap(q)
        let tracks = try await AVURLAsset(url: silent).loadTracks(withMediaType: .audio)
        XCTAssertTrue(tracks.isEmpty, "\"No sound\" kept a sound track")
        // Their own short song (a 1.5-second tone here) is repeated to the end.
        let tone = (0..<Int(1.5 * Synth.rate)).map { Float(sin(2 * .pi * 440 * Double($0) / Synth.rate)) * 0.5 }
        var own = VideoFX.Recipe(); own.music = "file"; own.song = Synth.file(tone, name: "test-song"); own.keep = 0
        let o = await VideoFX.export(src, recipe: own, caption: nil)
        let ownOpt = await loudness(try XCTUnwrap(o))
        let ownLoud = try XCTUnwrap(ownOpt)
        for (i, v) in ownLoud.dropLast(3).enumerated() { XCTAssertGreaterThan(v, 0.1, "their song stops at \(Double(i) / 2) s instead of repeating") }
        // A song that isn't there: the video keeps its own sound and the reason is said.
        let missing = await VideoSound.build(src, music: "file", song: nil, keep: 0)
        XCTAssertNotNil(missing.problem); XCTAssertNil(missing.mix)
        // And the preview copy plays with the music too.
        let clip = await VideoFX.previewClip(src, recipe: r, beats: [])
        let clipLoud = await loudness(try XCTUnwrap(clip))
        XCTAssertGreaterThan(try XCTUnwrap(clipLoud).max() ?? 0, 0.02, "the preview has no music")
    }

    /// Their own photo for behind the person is read upright and offered as a background (that it really lands behind
    /// a real person, and only there, is proved on real photos in FaceFunTests).
    func testOwnPhotoIsReadForTheBackdrop() throws {
        let red = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200)).image { c in UIColor.red.setFill(); c.fill(CGRect(x: 0, y: 0, width: 300, height: 200)) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("backdrop-test.jpg")
        try XCTUnwrap(red.jpegData(compressionQuality: 0.95)).write(to: url)
        var r = VideoFX.Recipe(); r.background = "photo"; r.backdrop = url
        let kit = VideoFX.Kit(r)
        let photo = try XCTUnwrap(kit.backdrop, "the photo wasn't loaded")
        XCTAssertEqual(photo.extent.width / photo.extent.height, 1.5, accuracy: 0.02)
        XCTAssertTrue(VideoFX.backgrounds.contains { $0.id == "photo" })
    }
}
