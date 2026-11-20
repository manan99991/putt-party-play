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

extension VideoJoin {
    /// Where the most happens: samples small frames 4 times a second, measures how much each changes from the last,
    /// and returns the busiest stretch of `length` seconds (the jump, the splash, the goal). nil for a still clip.
    static func busiestMoment(_ url: URL, length: Double = 2.5) async -> ClosedRange<Double>? {
        let asset = AVURLAsset(url: url)
        guard let d = try? await asset.load(.duration).seconds, d > length + 0.5 else { return nil }
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 48, height: 48)
        gen.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        gen.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        let step = 0.25
        var lums: [[UInt8]] = []
        var t = 0.0
        while t < d {
            if let (img, _) = try? await gen.image(at: CMTime(seconds: t, preferredTimescale: 600)) { lums.append(gray(img)) } else { lums.append([]) }
            t += step
        }
        let change = motionScores(lums)
        guard let best = busiestWindow(change, window: Int(length / step)) else { return nil }
        let a = Double(best) * step
        return a...min(d, a + length)
    }

    /// 0…255 brightness of a small picture, row by row.
    static func gray(_ cg: CGImage) -> [UInt8] {
        let w = cg.width, h = cg.height
        var px = [UInt8](repeating: 0, count: w * h)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0) else { return [] }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return px
    }

    /// How much each frame differs from the one before (mean absolute brightness change). Pure, so it's unit-tested.
    static func motionScores(_ frames: [[UInt8]]) -> [Double] {
        guard frames.count > 1 else { return [] }
        return (1..<frames.count).map { i in
            let a = frames[i - 1], b = frames[i]
            guard !a.isEmpty, a.count == b.count else { return 0 }
            var sum = 0
            for k in a.indices { sum += abs(Int(a[k]) - Int(b[k])) }
            return Double(sum) / Double(a.count)
        }
    }

    /// The start index of the window with the most change. nil when nothing moves. Pure, so it's unit-tested.
    static func busiestWindow(_ scores: [Double], window: Int) -> Int? {
        let w = max(1, window)
        guard scores.count >= w else { return scores.isEmpty ? nil : 0 }
        var sum = scores.prefix(w).reduce(0, +), best = sum, at = 0
        for i in w..<scores.count {
            sum += scores[i] - scores[i - w]
            if sum > best { best = sum; at = i - w + 1 }
        }
        return best > 0.5 * Double(w) ? at : nil
    }

    /// Normal speed, then `moment` at `rate` (0.25 = 4× slower), then normal again — the slow-mo ramp phones do,
    /// with the sound kept (voices at natural pitch).
    static func ramp(_ url: URL, moment: ClosedRange<Double>, rate: Double, progress: ((Double) -> Void)? = nil) async -> URL? {
        let asset = AVURLAsset(url: url)
        guard let v = try? await asset.loadTracks(withMediaType: .video).first, let dur = try? await asset.load(.duration) else { return nil }
        let comp = AVMutableComposition()
        guard let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }
        let whole = CMTimeRange(start: .zero, duration: dur)
        guard (try? cv.insertTimeRange(whole, of: v, at: .zero)) != nil else { return nil }
        cv.preferredTransform = (try? await v.load(.preferredTransform)) ?? .identity
        var ca: AVMutableCompositionTrack?
        if let a = try? await asset.loadTracks(withMediaType: .audio).first, let t = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            if (try? t.insertTimeRange(whole, of: a, at: .zero)) != nil { ca = t } else { comp.removeTrack(t) }
        }
        let slow = CMTimeRange(start: CMTime(seconds: moment.lowerBound, preferredTimescale: 600),
                               end: CMTime(seconds: min(moment.upperBound, dur.seconds), preferredTimescale: 600))
        let longer = CMTimeMultiplyByFloat64(slow.duration, multiplier: 1 / max(0.1, rate))
        cv.scaleTimeRange(slow, toDuration: longer)
        ca?.scaleTimeRange(slow, toDuration: longer)
        guard let s = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let out = VideoEngine.tempURL("mp4")
        s.outputURL = out; s.outputFileType = .mp4; s.metadata = []; s.audioTimePitchAlgorithm = .spectral
        return await VideoEngine.run(s, seconds: dur.seconds) ? out : nil
    }
}
