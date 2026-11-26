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
    /** Why the last reel or trailer couldn't be made, for the tests (shown on screen only under -uitest). */
    nonisolated(unsafe) static var lastProblem: String?
    static func problem(_ s: String) { print("REEL| " + s); lastProblem = s }

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

    /// A video ready to cut from: its picture track, how long it is, and how it's turned. The asset is kept too: a
    /// track doesn't hold on to its asset, and once the asset goes nothing can be cut from the track (26 Nov: every
    /// reel and trailer came out empty on the test machine until it was kept).
    struct Source {
        let asset: AVURLAsset
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
            out.append(Source(asset: a, track: t, length: d, natural: n, transform: tr))
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
        // The timeline is kept in exact clock ticks: adding up rounded seconds left hairline gaps and overlaps between
        // pieces at tempos whose beats don't fall on the clock's grid (126 BPM), and the export stopped (-11838).
        var cursor = CMTime.zero
        var shapes: [(at: CMTime, transform: CGAffineTransform)] = []
        for (i, c) in cuts.enumerated() {
            guard srcs.indices.contains(c.clip) else { continue }
            let src = srcs[c.clip]
            // The last shot carries on, slowing, while the final hit rings (as on Android). A single held frame
            // stretched to the ring-out left the reel empty on the test machine (26 Nov).
            let lasts = c.lasts + (i == cuts.count - 1 ? hold : 0)
            let piece = ts(c.length)
            do { try cv.insertTimeRange(CMTimeRange(start: ts(c.from), duration: piece), of: src.track, at: cursor) }
            catch { problem("cut \(c.clip) at \(c.from)s couldn't be inserted: \(error.localizedDescription)"); continue }
            var placed = piece
            if abs(lasts - c.length) > 0.01 {
                placed = ts(lasts)
                cv.scaleTimeRange(CMTimeRange(start: cursor, duration: piece), toDuration: placed)
            }
            shapes.append((cursor, fill(natural: src.natural, transform: src.transform)))
            // Carry on from where the track really ends now, not from a sum: if a stretch lands a hair off, the next
            // piece still goes exactly at the end instead of splitting the one before.
            cursor = CMTimeAdd(cv.timeRange.start, cv.timeRange.duration)
        }
        let at = cursor.seconds
        guard at > 0 else { problem("nothing could be cut from \(srcs.count) clips"); return nil }
        // Where the picture really ends (the sum of rounded pieces), so the sound never runs past it.
        let pictureEnd = cv.timeRange.duration.seconds
        // The sound, as long as the picture.
        if let why = await addSound(audio, name: "cut-sound", to: comp, seconds: pictureEnd) { problem(why) }

        // Every clip upright and filling the tall frame.
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: cv)
        for s in shapes { layer.setTransform(s.transform, at: s.at) }
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
        if !ok {
            let pieces = cv.segments.map { $0.timeMapping.target.duration.seconds }
            problem("the edit didn't save: \(s.error?.localizedDescription ?? "no error given") (\((s.error as NSError?)?.code ?? 0)) — " +
                  "\(pieces.count) pieces, shortest \(pieces.min() ?? 0)s, empty \(cv.segments.filter(\.isEmpty).count), picture \(pictureEnd)s, " +
                  "whole \(comp.duration.seconds)s, clips \(srcs.map { "\(Int($0.natural.width))x\(Int($0.natural.height))" })")
        }
        return ok ? (out, at) : nil
    }

    /// The reel from `sources` (videos; photos become short clips first). nil if the phone couldn't make it.
    static func make(_ sources: [URL], style styleID: String, seconds: Double? = nil, progress: ((Double) -> Void)? = nil) async -> URL? {
        let st = Synth.style(styleID)
        lastProblem = nil
        let srcs = await load(sources)
        guard !srcs.isEmpty else { problem("none of the \(sources.count) clips loaded"); return nil }
        let (cuts, total) = plan(lengths: srcs.map(\.length), style: st, seconds: seconds)
        guard !cuts.isEmpty else { problem("no cuts for \(srcs.count) clips"); return nil }
        progress?(0.05)
        let track = Synth.track(st.id, seconds: total)

        // The edit: every cut in turn on one track (the slow moment stretched, the last shot slowing into the ring).
        let comp = AVMutableComposition()
        guard let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }
        let ts: (Double) -> CMTime = { CMTime(seconds: $0, preferredTimescale: 6000) }
        var marks: [(at: Double, clip: Int)] = []
        var cursor = CMTime.zero
        for (i, c) in cuts.enumerated() {
            let lasts = c.lasts + (i == cuts.count - 1 ? ringOut : 0)
            let piece = ts(c.length)
            do { try cv.insertTimeRange(CMTimeRange(start: ts(c.from), duration: piece), of: srcs[c.clip].track, at: cursor) }
            catch { problem("cut \(c.clip) at \(c.from)s couldn't be inserted: \(error.localizedDescription)"); continue }
            if abs(lasts - c.length) > 0.01 { cv.scaleTimeRange(CMTimeRange(start: cursor, duration: piece), toDuration: ts(lasts)) }
            marks.append((cursor.seconds, c.clip))
            cursor = CMTimeAdd(cv.timeRange.start, cv.timeRange.duration)
        }
        let length = cursor.seconds
        guard length > 0 else { problem("nothing could be cut from \(srcs.count) clips"); return nil }
        if let why = await addSound(track.samples, name: "reel-music", to: comp, seconds: length) { problem(why) }
        do { try cv.validateSegments(cv.segments) } catch { print("REEL| the cuts don't line up: \(error.localizedDescription)") }

        // The picture, frame by frame (the same way Funny Moments and the trailer make theirs): each clip upright and
        // filling the tall frame, then the style's look and light, and a punch on every beat of the music itself.
        // Round 6 (26 Nov): the layer-instruction export stopped (-11838) on a single recorded clip; this path didn't.
        var r = VideoFX.Recipe(look: st.look, light: st.light, motion: "pulse", texture: st.id == "epic" ? "bars" : "none")
        r.amount = 0.55
        let kit = VideoFX.Kit(r)
        let beats = track.beats
        let turns = srcs.map { FunnyMoment.orientation($0.transform) }
        let starts = marks
        let rect = CGRect(origin: .zero, size: size)
        guard let vc = try? await AVMutableVideoComposition.videoComposition(with: comp, applyingCIFiltersWithHandler: { request in
            let t = request.compositionTime.seconds
            let clip = starts.last(where: { $0.at <= t + 0.0005 })?.clip ?? 0
            var img = request.sourceImage
            if turns.indices.contains(clip), turns[clip] != .up { img = img.oriented(turns[clip]) }
            img = img.transformed(by: CGAffineTransform(translationX: -img.extent.minX, y: -img.extent.minY))
            let w = max(1, img.extent.width), h = max(1, img.extent.height)
            let k = max(size.width / w, size.height / h)
            img = img.transformed(by: CGAffineTransform(scaleX: k, y: k))
                .transformed(by: CGAffineTransform(translationX: (size.width - w * k) / 2, y: (size.height - h * k) / 2))
                .cropped(to: rect)
            request.finish(with: VideoFX.frame(img, t: t, duration: length, size: size, kit: kit, beats: beats, caption: nil), context: nil)
        }) else { problem("the reel's picture couldn't be set up"); return nil }
        vc.renderSize = size
        vc.frameDuration = CMTime(value: 1, timescale: 30)

        guard let s = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else { problem("no export session"); return nil }
        let out = VideoEngine.tempURL("mp4")
        s.outputURL = out; s.outputFileType = .mp4; s.videoComposition = vc; s.metadata = []
        let poll = Task { while !Task.isCancelled { progress?(0.05 + 0.95 * Double(s.progress)); try? await Task.sleep(nanoseconds: 300_000_000) } }
        let ok = await VideoEngine.run(s, seconds: length)
        poll.cancel()
        if !ok {
            let pieces = cv.segments.map { $0.timeMapping.target.duration.seconds }
            let sound = comp.tracks(withMediaType: .audio).map { $0.segments.count }
            // Which half fails: the edit alone (no picture recipe), saved small and quick.
            let bare = await probe(comp)
            for (i, g) in cv.segments.enumerated() {
                let m = g.timeMapping
                print("REEL| piece \(i): \(m.source.start.value)+\(m.source.duration.value)/\(m.source.duration.timescale) → \(m.target.start.value)+\(m.target.duration.value)/\(m.target.duration.timescale)")
            }
            problem("the reel didn't save: \(s.error?.localizedDescription ?? "no error given") (\((s.error as NSError?)?.code ?? 0)) — " +
                    "\(pieces.count) pieces, shortest \(pieces.min() ?? 0)s, length \(length)s, sound pieces \(sound), the edit alone \(bare), " +
                    "clips \(srcs.map { "\(Int($0.natural.width))x\(Int($0.natural.height))" })")
        }
        progress?(1)
        return ok ? out : nil
    }

    /// Lays `samples` (at Synth.rate) under the picture from the start, for up to `seconds`. nil when it's in, else why
    /// not. The sound file's asset is kept until it's in — a track doesn't hold on to its asset, and when the asset went
    /// first the insert failed silently and left an empty sound track behind, which stops the whole export (-11838) — and
    /// a sound track that couldn't be filled is taken out again rather than left empty.
    static func addSound(_ samples: [Float], name: String, to comp: AVMutableComposition, seconds: Double) async -> String? {
        guard let url = Synth.file(samples, name: name) else { return "the music couldn't be written" }
        let asset = AVURLAsset(url: url)
        defer { withExtendedLifetime(asset) {} }
        guard let mt = try? await asset.loadTracks(withMediaType: .audio).first else { return "the music file has no sound" }
        guard let ca = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return "no room for the music" }
        let len = min(seconds, Double(samples.count) / Synth.rate)
        do { try ca.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: len, preferredTimescale: 6000)), of: mt, at: .zero) }
        catch { comp.removeTrack(ca); return "the music couldn't be laid in: \(error.localizedDescription)" }
        return nil
    }

    /// For the failure report only: whether `comp` saves at all without a picture recipe ("ok" or the error's code).
    private static func probe(_ comp: AVComposition) async -> String {
        guard let s = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetLowQuality) else { return "no session" }
        s.outputURL = VideoEngine.tempURL("mp4"); s.outputFileType = .mp4
        await s.export()
        return s.status == .completed ? "ok" : "\((s.error as NSError?)?.code ?? 0)"
    }

    /// Photos become 3-second clips (with a slow push-in) so they can sit in a reel with the videos.
    static func clip(from photo: UIImage) async -> URL? { await Celebrate.videoFromPhoto(photo) }
}
