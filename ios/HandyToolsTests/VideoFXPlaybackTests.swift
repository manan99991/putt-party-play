import XCTest
import AVFoundation
@testable import HandyTools

/// Gold Book review, 24 Nov: on the build machine the Video Effects preview player failed ("The operation could not be
/// completed") while the export of the same effects worked. Plays the same sample plain (the control) and with the
/// effects, and says exactly what each one did, so the fix is chosen from facts (rulebook §8).
@MainActor
final class VideoFXPlaybackTests: XCTestCase {
    private func play(_ item: AVPlayerItem, _ name: String) async -> (status: AVPlayerItem.Status, t: Double, detail: String) {
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.play()
        for _ in 0..<40 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if item.status == .failed || player.currentTime().seconds > 1 { break }
        }
        let e = item.error as NSError?
        let under = e?.userInfo[NSUnderlyingErrorKey] as? NSError
        let log = item.errorLog()?.events.last.map { "\($0.errorDomain) \($0.errorStatusCode) \($0.errorComment ?? "-")" } ?? "-"
        let detail = "status \(item.status.rawValue) t \(String(format: "%.2f", player.currentTime().seconds)) "
            + "wait \(player.reasonForWaitingToPlay?.rawValue ?? "-") err \(e?.domain ?? "-") \(e?.code ?? 0) \(e?.localizedFailureReason ?? "-") "
            + "under \(under?.domain ?? "-") \(under?.code ?? 0) log \(log)"
        print("VIDEOFX| \(name): \(detail)")
        player.pause()
        return (item.status, player.currentTime().seconds, detail)
    }

    func testPreviewPlaysWithTheEffectsOn() async throws {
        let made = await Celebrate.videoFromPhoto(SampleAssets.photo())
        let url = try XCTUnwrap(made, "the sample photo didn't become a video")
        let asset = AVURLAsset(url: url)
        let track = try await asset.loadTracks(withMediaType: .video).first
        let codec = (try? await track?.load(.formatDescriptions).first).map { CMFormatDescriptionGetMediaSubType($0) } ?? 0
        let size = (try? await track?.load(.naturalSize)) ?? .zero
        print("VIDEOFX| sample: codec \(String(format: "%08x", codec)) size \(size) duration \((try? await asset.load(.duration).seconds) ?? -1)")

        let plain = await play(AVPlayerItem(asset: asset), "plain")

        let built = await VideoFX.composition(for: asset, recipe: VideoFX.vibes[0].recipe, caption: nil, beats: [])
        let comp = try XCTUnwrap(built, "no composition for the effects")
        print("VIDEOFX| comp: render \(comp.renderSize) frame \(comp.frameDuration.seconds) instructions \(comp.instructions.count)")
        let item = AVPlayerItem(asset: asset)
        item.videoComposition = comp
        let fx = await play(item, "effects")

        XCTAssertNotEqual(plain.status, .failed, "the control (plain video) failed too: \(plain.detail)")
        XCTAssertNotEqual(fx.status, .failed, "the preview with effects failed: \(fx.detail)")
        XCTAssertGreaterThan(fx.t, 0.25, "the preview with effects never moved: \(fx.detail)")
    }
}
