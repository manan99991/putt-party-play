import AVFoundation
import UIKit

/// Beat Reel (26 Nov, Manan: "the bestest and easiest way to make the most amazing social media reels"): a few clips
/// and photos become one tall reel cut to the beat of Tenzy's own music — every cut lands on a beat, the second bar
/// drops with a slow-motion moment, each cut punches in, and the style's look and light go over it all. Made on the
/// phone; the music is Tenzy's own (Synth), so the reel can be posted anywhere.
enum BeatReel {
    static let size = CGSize(width: 1080, height: 1920)
    /// How long the last shot holds after the final beat, while the music's last hit rings.
    static let ringOut = 0.8

    /// One piece of the reel: which clip, where in it, how long it lasts in the clip and in the reel.
    struct Cut: Equatable {
        let clip: Int
        let from: Double
        let length: Double      // in the clip
        let lasts: Double       // in the reel (twice `length` for the slow-motion moment)
        var slow: Bool { lasts > length * 1.2 }
    }

    /// How the reel is cut, from the clips' lengths and the style. Pure, so it's tested: whole bars, cuts on beats,
    /// every clip used, each clip's pieces spread through it, one slow-motion moment where the music drops.
    static func plan(lengths: [Double], style: Synth.Style, seconds: Double? = nil) -> (cuts: [Cut], total: Double) {
        let usable = lengths.filter { $0 > 0.2 }
        guard !usable.isEmpty else { return ([], 0) }
        let beat = 60 / style.bpm, bar = beat * 4, cutLen = beat * Double(style.beatsPerCut)
        // Long enough to show everything without dragging: 60% of what was given, 12–60 s, whole bars.
        let want = seconds ?? min(60, max(12, lengths.reduce(0, +) * 0.6))
        let bars = max(2, Int((want / bar).rounded()))
        let total = Double(bars) * bar
        let count = Int((total / cutLen).rounded())
        // Clips take turns; the slow moment is the first cut of the second bar (where the music drops).
        let slowAt = Int((bar / cutLen).rounded())
        var uses = [Int](repeating: 0, count: lengths.count)
        var order: [Int] = []
        for i in 0..<count { let c = i % lengths.count; order.append(c); uses[c] += 1 }
        var seen = [Int](repeating: 0, count: lengths.count)
        var cuts: [Cut] = []
        for (i, c) in order.enumerated() {
            let slow = i == slowAt && count > slowAt + 1
            let need = slow ? cutLen / 2 : cutLen
            let len = min(need, max(0.1, lengths[c]))
            // Skip the shaky first and last moments when there's room; spread this clip's turns through it.
            let margin = min(0.4, max(0, (lengths[c] - len) / 4))
            let room = max(0, lengths[c] - len - 2 * margin)
            let from = margin + room * (Double(seen[c]) + 0.5) / Double(max(1, uses[c]))
            seen[c] += 1
            cuts.append(Cut(clip: c, from: from, length: len, lasts: cutLen))
        }
        return (cuts, total)
    }

    /// The clip's frames turned upright and scaled to fill the tall reel, centred.
    static func fill(natural: CGSize, transform: CGAffineTransform) -> CGAffineTransform {
        let r = CGRect(origin: .zero, size: natural).applying(transform)
        guard r.width > 0, r.height > 0 else { return transform }
        let k = max(size.width / r.width, size.height / r.height)
        return transform
            .concatenating(CGAffineTransform(translationX: -r.minX, y: -r.minY))
            .concatenating(CGAffineTransform(scaleX: k, y: k))
            .concatenating(CGAffineTransform(translationX: (size.width - r.width * k) / 2, y: (size.height - r.height * k) / 2))
    }

    /// A video ready to cut from: its picture track, how long it is, and how it's turned.
    struct Source {
        let track: AVAssetTrack
        let length: Double
        let natural: CGSize
        let transform: CGAffineTransform
    }

    /// The videos that load (photos should already be clips); ones without a picture or shorter than 0.2 s are left out.
    static func load(_ urls: [URL]) async -> [Source] {
        var out: [Source] = []
        for u in urls {
            let a = AVURLAsset(url: u)
            guard let t = try? await a.loadTracks(withMediaType: .video).first,
                  let d = try? await a.load(.duration).seconds, d > 0.2,
                  let n = try? await t.load(.naturalSize), let tr = try? await t.load(.preferredTransform) else { continue }
            out.append(Source(track: t, length: d, natural: n, transform: tr))
        }
        return out
    }

    /// The edit itself, shared by reels and trailers: every cut in turn on one tall track (each clip upright and filling
    /// the frame, stretched where a cut lasts longer than its piece), the last frame held `hold` seconds, and `audio`
    /// (samples at Synth.rate) underneath from the start. Saved once at full quality; `progress` runs 0…1.
    static func assemble(_ srcs: [Source], cuts: [Cut], hold: Double, audio: [Float], progress: ((Double) -> Void)?) async -> (url: URL, seconds: Double)? {
        let comp = AVMutableComposition()
        guard let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }
        let ts: (Double) -> CMTime = { CMTime(seconds: $0, preferredTimescale: 6000) }
        var at = 0.0
        var shapes: [(at: Double, transform: CGAffineTransform)] = []
        for c in cuts where srcs.indices.contains(c.clip) {
            let src = srcs[c.clip]
            do { try cv.insertTimeRange(CMTimeRange(start: ts(c.from), duration: ts(c.length)), of: src.track, at: ts(at)) } catch { continue }
            if abs(c.lasts - c.length) > 0.01 { cv.scaleTimeRange(CMTimeRange(start: ts(at), duration: ts(c.length)), toDuration: ts(c.lasts)) }
            shapes.append((at, fill(natural: src.natural, transform: src.transform)))
            at += c.lasts
        }
        guard at > 0 else { return nil }
        // The last shot holds while the music's final hit rings out.
        if hold > 0, let last = cuts.last, srcs.indices.contains(last.clip) {
            let src = srcs[last.clip], end = max(0, last.from + last.length - 1.0 / 30)
            if (try? cv.insertTimeRange(CMTimeRange(start: ts(end), duration: ts(1.0 / 30)), of: src.track, at: ts(at))) != nil {
                cv.scaleTimeRange(CMTimeRange(start: ts(at), duration: ts(1.0 / 30)), toDuration: ts(hold))
                at += hold
            }
        }
        // The sound, as long as the picture.
        if let mu = Synth.file(audio, name: "cut-sound"),
           let mt = try? await AVURLAsset(url: mu).loadTracks(withMediaType: .audio).first,
           let ca = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? ca.insertTimeRange(CMTimeRange(start: .zero, duration: ts(min(at, Double(audio.count) / Synth.rate))), of: mt, at: .zero)
        }

        // Every clip upright and filling the tall frame.
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: cv)
        for s in shapes { layer.setTransform(s.transform, at: ts(s.at)) }
        let ins = AVMutableVideoCompositionInstruction()
        ins.timeRange = CMTimeRange(start: .zero, duration: comp.duration)
        ins.layerInstructions = [layer]
        let vc = AVMutableVideoComposition()
        vc.instructions = [ins]
        vc.renderSize = size
        vc.frameDuration = CMTime(value: 1, timescale: 30)

        guard let s = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let out = VideoEngine.tempURL("mp4")
        s.outputURL = out; s.outputFileType = .mp4; s.videoComposition = vc; s.metadata = []
        let poll = Task { while !Task.isCancelled { progress?(Double(s.progress)); try? await Task.sleep(nanoseconds: 300_000_000) } }
        let ok = await VideoEngine.run(s, seconds: at)
        poll.cancel()
        return ok ? (out, at) : nil
    }

    /// The reel from `sources` (videos; photos become short clips first). nil if the phone couldn't make it.
    static func make(_ sources: [URL], style styleID: String, seconds: Double? = nil, progress: ((Double) -> Void)? = nil) async -> URL? {
        let st = Synth.style(styleID)
        let srcs = await load(sources)
        guard !srcs.isEmpty else { return nil }
        let (cuts, total) = plan(lengths: srcs.map(\.length), style: st, seconds: seconds)
        guard !cuts.isEmpty else { return nil }
        progress?(0.05)
        let music = Synth.track(st.id, seconds: total).samples
        guard let cut = await assemble(srcs, cuts: cuts, hold: ringOut, audio: music, progress: { p in progress?(0.05 + 0.45 * p) })?.url else { return nil }
        progress?(0.5)

        // The style over it all: its look and light, a punch on every beat (found in the music itself).
        var r = VideoFX.Recipe(look: st.look, light: st.light, motion: "pulse", texture: st.id == "epic" ? "bars" : "none")
        r.amount = 0.55
        let out = await VideoFX.export(cut, recipe: r, caption: nil)
        try? FileManager.default.removeItem(at: cut)
        progress?(1)
        return out
    }

    /// Photos become 3-second clips (with a slow push-in) so they can sit in a reel with the videos.
    static func clip(from photo: UIImage) async -> URL? { await Celebrate.videoFromPhoto(photo) }
}
