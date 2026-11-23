import Foundation
import AVFoundation
import CoreImage

/// The Pro finish for a clip — the same steps a photo gets (straighten a slightly crooked horizon, Apple's own
/// automatic adjustments for light, shadows and colour), worked out once from the clip's middle frame and applied to
/// every frame on the phone. One look for the whole clip, so nothing flickers from frame to frame.
enum VideoPro {
    /// What to do to every frame: a turn (degrees, + = clockwise to fix) and the adjustment filters with their settings.
    /// Filters are rebuilt per frame from these settings, since frames are finished on several threads at once.
    final class Plan: @unchecked Sendable {
        let tilt: Double?
        let steps: [(name: String, settings: [String: Any])]
        init(tilt: Double?, steps: [(name: String, settings: [String: Any])]) { self.tilt = tilt; self.steps = steps }
        /// Nothing worth changing: the clip is level and already well exposed.
        var isEmpty: Bool { tilt == nil && steps.isEmpty }
    }

    /// Read the clip's middle frame and decide its finish. nil when no frame can be read.
    static func plan(for asset: AVAsset) async -> Plan? {
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 1280, height: 1280)
        gen.requestedTimeToleranceBefore = .positiveInfinity; gen.requestedTimeToleranceAfter = .positiveInfinity
        let secs = (try? await asset.load(.duration).seconds) ?? 0
        guard secs > 0, let cg = try? await gen.image(at: CMTime(seconds: secs / 2, preferredTimescale: 600)).image else { return nil }
        let frame = CIImage(cgImage: cg)
        let tilt = SceneSense.horizon(frame).flatMap { SceneSense.shouldStraighten(degrees: $0) ? $0 : nil }
        // Face-led balance is left out: a face in the middle frame may be gone by the end of the clip.
        let filters = frame.autoAdjustmentFilters(options: [.redEye: false, .features: []])
        let steps: [(name: String, settings: [String: Any])] = filters.map { f in
            var s: [String: Any] = [:]
            for key in f.inputKeys where key != kCIInputImageKey { if let v = f.value(forKey: key) { s[key] = v } }
            return (f.name, s)
        }
        return Plan(tilt: tilt, steps: steps)
    }

    /// One frame, finished. Pure apart from Core Image, so it's tested on a still.
    static func finish(_ img: CIImage, plan: Plan) -> CIImage {
        let e = img.extent
        var out = img
        if let deg = plan.tilt {
            let s = SceneSense.coverScale(degrees: deg, size: e.size)
            let c = CGPoint(x: e.midX, y: e.midY)
            out = out.clampedToExtent().transformed(by: CGAffineTransform(translationX: -c.x, y: -c.y)
                .concatenating(CGAffineTransform(rotationAngle: CGFloat(-deg * Double.pi / 180)))
                .concatenating(CGAffineTransform(scaleX: s, y: s))
                .concatenating(CGAffineTransform(translationX: c.x, y: c.y))).cropped(to: e)
        }
        for step in plan.steps {
            guard let f = CIFilter(name: step.name) else { continue }
            for (k, v) in step.settings { f.setValue(v, forKey: k) }
            f.setValue(out, forKey: kCIInputImageKey)
            if let o = f.outputImage { out = o }
        }
        return out.cropped(to: e)
    }

    /// Plays and exports with the finish applied (the player shows it live, before anything is saved).
    static func composition(for asset: AVAsset, plan: Plan) async -> AVVideoComposition? {
        try? await AVVideoComposition.videoComposition(with: asset) { request in
            request.finish(with: finish(request.sourceImage, plan: plan), context: nil)
        }
    }

    /// Write the finished clip (sound kept) to a new file. nil if the phone couldn't export it — the caller keeps the original.
    static func export(_ asset: AVAsset, composition: AVVideoComposition) async -> URL? {
        guard let s = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("pro-\(UUID().uuidString).mov")
        s.videoComposition = composition
        do { try await s.export(to: out, as: .mov) } catch { return nil }
        return FileManager.default.fileExists(atPath: out.path) ? out : nil
    }
}
