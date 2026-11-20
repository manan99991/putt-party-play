import Foundation
import AVFoundation
import CoreGraphics

/// Videos in, a video out: join clips end to end (each turned upright and fitted to the first clip's frame, with
/// black bars when shapes differ), and/or play at another speed with voices keeping their natural pitch.
/// Used by Join & Speed when the clips are videos, so joining videos gives a video, not just their sound.
enum VideoJoin {
    /// Even pixel sizes, as video encoders need.
    static func even(_ s: CGSize) -> CGSize {
        CGSize(width: max(2, (s.width / 2).rounded(.down) * 2), height: max(2, (s.height / 2).rounded(.down) * 2))
    }

    /// The transform that turns a clip upright and fits it, centred, inside `render`.
    static func fit(natural: CGSize, transform t: CGAffineTransform, into render: CGSize) -> CGAffineTransform {
        let r = CGRect(origin: .zero, size: natural).applying(t)
        let upright = CGSize(width: abs(r.width), height: abs(r.height))
        guard upright.width > 0, upright.height > 0 else { return t }
        let s = min(render.width / upright.width, render.height / upright.height)
        return t.concatenating(CGAffineTransform(translationX: -r.minX, y: -r.minY))
            .concatenating(CGAffineTransform(scaleX: s, y: s))
            .concatenating(CGAffineTransform(translationX: (render.width - upright.width * s) / 2, y: (render.height - upright.height * s) / 2))
    }

    /// One MP4 from `sources` in order, at `rate` (1 = as recorded). nil if a clip has no picture or the phone can't export.
    static func join(_ sources: [URL], rate: Double = 1, progress: ((Double) -> Void)? = nil) async -> URL? {
        guard !sources.isEmpty else { return nil }
        let r = min(4, max(0.25, rate))
        let comp = AVMutableComposition()
        guard let vt = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let at = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }
        struct Part { let start: CMTime; let duration: CMTime; let natural: CGSize; let transform: CGAffineTransform }
        var parts: [Part] = []
        var cursor = CMTime.zero
        var render = CGSize.zero
        var anySound = false
        for url in sources {
            let asset = AVURLAsset(url: url)
            guard let v = try? await asset.loadTracks(withMediaType: .video).first,
                  let dur = try? await asset.load(.duration), dur.seconds > 0,
                  let natural = try? await v.load(.naturalSize),
                  let t = try? await v.load(.preferredTransform) else { return nil }
            let range = CMTimeRange(start: .zero, duration: dur)
            guard (try? vt.insertTimeRange(range, of: v, at: cursor)) != nil else { return nil }
            if let a = try? await asset.loadTracks(withMediaType: .audio).first, (try? at.insertTimeRange(range, of: a, at: cursor)) != nil { anySound = true }
            if render == .zero {
                let o = CGRect(origin: .zero, size: natural).applying(t)
                render = even(CGSize(width: abs(o.width), height: abs(o.height)))
            }
            parts.append(Part(start: cursor, duration: dur, natural: natural, transform: t))
            cursor = cursor + dur
        }
        if !anySound { comp.removeTrack(at) }
        let total = cursor
        if r != 1 {
            let whole = CMTimeRange(start: .zero, duration: total)
            let scaled = CMTimeMultiplyByFloat64(total, multiplier: 1 / r)
            vt.scaleTimeRange(whole, toDuration: scaled)
            if anySound { at.scaleTimeRange(whole, toDuration: scaled) }
        }
        let vc = AVMutableVideoComposition()
        vc.renderSize = render
        vc.frameDuration = CMTime(value: 1, timescale: 30)
        vc.instructions = parts.map { p in
            let ins = AVMutableVideoCompositionInstruction()
            ins.timeRange = CMTimeRange(start: CMTimeMultiplyByFloat64(p.start, multiplier: 1 / r),
                                        duration: CMTimeMultiplyByFloat64(p.duration, multiplier: 1 / r))
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: vt)
            layer.setTransform(fit(natural: p.natural, transform: p.transform, into: render), at: ins.timeRange.start)
            ins.layerInstructions = [layer]
            return ins
        }
        guard let session = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let out = VideoEngine.tempURL("mp4")
        session.outputURL = out; session.outputFileType = .mp4; session.videoComposition = vc; session.metadata = []
        session.audioTimePitchAlgorithm = .spectral
        let ok: Bool = await withTaskGroup(of: Bool?.self) { group in
            group.addTask { await session.export(); return session.status == .completed }
            group.addTask {
                while !Task.isCancelled { progress?(Double(session.progress)); try? await Task.sleep(nanoseconds: 250_000_000) }
                return nil
            }
            var result = false
            for await v in group { if let v { result = v; group.cancelAll(); break } }
            return result
        }
        return ok ? out : nil
    }
}
