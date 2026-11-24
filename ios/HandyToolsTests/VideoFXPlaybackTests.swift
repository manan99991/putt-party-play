import XCTest
import AVFoundation
@testable import HandyTools

/// Gold Book review, 24 Nov: on the build machine the Video Effects preview player failed ("The operation could not be
/// completed") while the export of the same effects worked. Plays the same sample plain (the control) and with the
/// effects, and says exactly what each one did, so the fix is chosen from facts (rulebook §8).
@MainActor
final class VideoFXPlaybackTests: XCTestCase {
    /// Plays the item and pulls real frames from it (a player with nothing to draw into may never run the effects), on
    /// screen in a player layer when `onScreen`, the way the app's preview shows it.
    private func play(_ item: AVPlayerItem, _ name: String, onScreen: Bool = false) async -> (status: AVPlayerItem.Status, t: Double, frames: Int, detail: String) {
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        item.add(output)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        var window: UIWindow?
        if onScreen, let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let w = UIWindow(windowScene: scene)
            w.frame = CGRect(x: 0, y: 0, width: 360, height: 450)
            let host = UIViewController()
            let layer = AVPlayerLayer(player: player)
            layer.frame = host.view.bounds
            host.view.layer.addSublayer(layer)
            w.rootViewController = host
            w.isHidden = false
            window = w
        }
        player.play()
        var frames = 0
        for _ in 0..<40 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            let now = output.itemTime(forHostTime: CACurrentMediaTime())
            if output.hasNewPixelBuffer(forItemTime: now), output.copyPixelBuffer(forItemTime: now, itemTimeForDisplay: nil) != nil { frames += 1 }
            if item.status == .failed || (player.currentTime().seconds > 1.5 && frames >= 3) { break }
        }
        window?.isHidden = true
        let e = item.error as NSError?
        let under = e?.userInfo[NSUnderlyingErrorKey] as? NSError
        let log = item.errorLog()?.events.last.map { "\($0.errorDomain) \($0.errorStatusCode) \($0.errorComment ?? "-")" } ?? "-"
        let detail = "frames \(frames) screen \(onScreen && window != nil) status \(item.status.rawValue) t \(String(format: "%.2f", player.currentTime().seconds)) "
            + "wait \(player.reasonForWaitingToPlay?.rawValue ?? "-") err \(e?.domain ?? "-") \(e?.code ?? 0) \(e?.localizedFailureReason ?? "-") "
            + "under \(under?.domain ?? "-") \(under?.code ?? 0) log \(log)"
        print("VIDEOFX| \(name): \(detail)")
        player.pause()
        return (item.status, player.currentTime().seconds, frames, detail)
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
        let shown = AVPlayerItem(asset: asset)
        shown.videoComposition = comp
        let fxScreen = await play(shown, "effects on screen", onScreen: true)

        XCTAssertNotEqual(plain.status, .failed, "the control (plain video) failed too: \(plain.detail)")
        for r in [fx, fxScreen] {
            XCTAssertNotEqual(r.status, .failed, "the preview with effects failed: \(r.detail)")
            XCTAssertGreaterThan(r.frames, 0, "the effects drew no frames: \(r.detail)")
        }
    }
}
