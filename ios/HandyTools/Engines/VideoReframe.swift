import AVFoundation
import CoreImage

/// Re-shape any clip into a platform format (VideoFormat) — Reels/TikTok/Shorts 9:16, Story, Square,
/// Portrait 4:5 or YouTube 16:9 — at the exact size the platform wants, sound kept. "Fill" crops to the
/// centre with no bars; "fit" keeps the whole frame over a soft, blurred copy of itself (the look
/// creators use instead of black bars). Each frame is composited with Core Image inside the export, so
/// it runs on any iPhone without holding frames in memory.
enum VideoReframe {
    static func reframe(_ src: URL, to spec: VideoFormat.Spec, fit: Bool,
                        progress: ((Double) -> Void)? = nil) async -> URL? {
        let asset = AVURLAsset(url: src)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first else { return nil }
        let fps = (try? await track.load(.nominalFrameRate)).map { $0 > 1 ? $0 : 30 } ?? 30
        let target = spec.size
        let canvas = CGRect(origin: .zero, size: target)

        let comp = AVMutableVideoComposition(asset: asset) { request in
            let raw = request.sourceImage
            let img = raw.transformed(by: CGAffineTransform(translationX: -raw.extent.minX, y: -raw.extent.minY))
            let s = img.extent.size
            guard s.width > 0, s.height > 0 else { request.finish(with: raw, context: nil); return }
            let fillK = max(target.width / s.width, target.height / s.height)
            let filled = img.transformed(by: CGAffineTransform(scaleX: fillK, y: fillK))
                .transformed(by: CGAffineTransform(translationX: (target.width - s.width * fillK) / 2,
                                                   y: (target.height - s.height * fillK) / 2))
            let out: CIImage
            if !fit {
                out = filled.cropped(to: canvas)
            } else {
                let backdrop = filled.clampedToExtent()
                    .applyingGaussianBlur(sigma: Double(max(target.width, target.height)) / 40)
                    .applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey: -0.12, kCIInputSaturationKey: 1.1])
                    .cropped(to: canvas)
                let fitK = min(target.width / s.width, target.height / s.height)
                let fg = img.transformed(by: CGAffineTransform(scaleX: fitK, y: fitK))
                    .transformed(by: CGAffineTransform(translationX: (target.width - s.width * fitK) / 2,
                                                       y: (target.height - s.height * fitK) / 2))
                out = fg.composited(over: backdrop).cropped(to: canvas)
            }
            request.finish(with: out, context: nil)
        }
        comp.renderSize = target
        comp.frameDuration = CMTime(value: 1, timescale: CMTimeScale(max(1, min(60, Int(fps.rounded())))))

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let out = VideoEngine.tempURL("mp4")
        session.outputURL = out
        session.outputFileType = .mp4
        session.videoComposition = comp
        session.shouldOptimizeForNetworkUse = true
        let ok: Bool = await withTaskGroup(of: Bool?.self) { group -> Bool in
            group.addTask { await session.export(); return session.status == .completed }
            group.addTask {
                while !Task.isCancelled {
                    progress?(Double(session.progress))
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
                return nil
            }
            var result = false
            while let r = await group.next() {
                if let r { result = r; break }
            }
            group.cancelAll()
            return result
        }
        guard ok else { try? FileManager.default.removeItem(at: out); return nil }
        progress?(1)
        return out
    }
}
