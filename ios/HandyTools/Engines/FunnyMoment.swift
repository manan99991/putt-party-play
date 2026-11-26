import AVFoundation
import CoreImage
import UIKit
import Vision

/// Funny moments (26 Nov, Manan: "the chance to make it the most funny movies of all"): one moment of a video gets a
/// classic comedy beat — the record-scratch freeze ("Yep. That's me."), a dramatic zoom with "dun dun dun", awkward
/// crickets, air horns, a boing, or a ba-dum-tss at the end. The moment is found for you (the loudest laugh or shout)
/// and can be moved. Every sound is Tenzy's own (Synth); everything is made on the phone.
enum FunnyMoment {
    struct Kind: Identifiable, Equatable {
        let id: String, name: String, emoji: String, line: String
        /// The sound it plays at the moment.
        let sound: String
        /// How long the picture stops there (0 = it keeps playing).
        let freeze: Double
        /// The words on the frozen frame, if any (the person can change them).
        let words: String
    }
    static let kinds: [Kind] = [
        Kind(id: "scratch", name: "Record scratch", emoji: "💿", line: "Freeze! \"Yep. That's me.\"", sound: "scratch", freeze: 2.6, words: "Yep. That's me."),
        Kind(id: "dramatic", name: "Dramatic zoom", emoji: "😱", line: "Zooms in on a face — dun dun dun", sound: "sting", freeze: 0, words: ""),
        Kind(id: "crickets", name: "Awkward silence", emoji: "🦗", line: "Everything stops. Crickets.", sound: "crickets", freeze: 2.4, words: "…"),
        Kind(id: "horn", name: "Air horns", emoji: "📯", line: "Horns, a flash and a shake", sound: "horn", freeze: 0, words: ""),
        Kind(id: "boing", name: "Boing", emoji: "🪀", line: "The picture bounces like a spring", sound: "boing", freeze: 0, words: ""),
        Kind(id: "rimshot", name: "Ba-dum-tss", emoji: "🥁", line: "The ending freezes on a drum hit", sound: "rimshot", freeze: 1.8, words: ""),
    ]
    static func kind(_ id: String) -> Kind { kinds.first { $0.id == id } ?? kinds[0] }

    // MARK: where

    /// The moment to use: the loudest stretch between a quarter and 85% of the way through (a laugh, a shout, a crash),
    /// or 60% of the way when there's no sound. Ba-dum-tss always lands on the end. `loudness` is one value per `hop`.
    static func moment(loudness: [Double], hop: Double, duration: Double, kind: String) -> Double {
        if kind == "rimshot" { return max(0, duration - 0.05) }
        let lo = Int(duration * 0.25 / hop), hi = min(loudness.count, Int(duration * 0.85 / hop))
        guard hi > lo + 2 else { return duration * 0.6 }
        // A short running average, so one click doesn't win over a real laugh.
        var best = lo, bestV = -1.0
        for i in lo..<hi {
            let w = loudness[max(0, i - 2)...min(loudness.count - 1, i + 2)]
            let v = w.reduce(0, +) / Double(w.count)
            if v > bestV { bestV = v; best = i }
        }
        return bestV > 0.01 ? Double(best) * hop : duration * 0.6
    }

    static func loudness(_ url: URL, hop: Double = 0.05) async -> [Double] {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first, let reader = try? AVAssetReader(asset: asset) else { return [] }
        let out = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16,
                                                                         AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
                                                                         AVNumberOfChannelsKey: 1, AVSampleRateKey: 16000])
        reader.add(out)
        guard reader.startReading() else { return [] }
        let per = Int(16000 * hop)
        var loud: [Double] = [], acc = 0.0, n = 0
        while let buf = out.copyNextSampleBuffer(), let block = CMSampleBufferGetDataBuffer(buf) {
            var len = 0; var ptr: UnsafeMutablePointer<Int8>?
            guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &len, dataPointerOut: &ptr) == noErr, let ptr else { continue }
            ptr.withMemoryRebound(to: Int16.self, capacity: len / 2) { s in
                for i in 0..<(len / 2) {
                    let x = Double(s[i]) / 32768; acc += x * x; n += 1
                    if n == per { loud.append(sqrt(acc / Double(n))); acc = 0; n = 0 }
                }
            }
        }
        return loud
    }

    // MARK: the picture

    /// What happens to the frame `dt` seconds after the moment (negative: before it). Pure, so the timings are tested:
    /// how much it zooms, how far it shakes, how bright the flash, how grey, and whether the words show.
    struct Look: Equatable { var zoom = 1.0; var dx = 0.0; var dy = 0.0; var flash = 0.0; var grey = 0.0; var squash = 1.0; var words = 0.0 }

    static func look(_ kind: String, dt: Double, freeze: Double) -> Look {
        var l = Look()
        guard dt >= 0 else { return l }
        switch kind {
        case "scratch", "crickets", "rimshot":
            guard dt <= freeze + 0.05 else { return l }
            let p = min(1, dt / max(0.1, freeze))
            l.zoom = 1 + (kind == "rimshot" ? -0.06 : 0.12) * p       // a slow push in (the rimshot pulls back)
            l.grey = kind == "rimshot" ? 0 : min(1, dt / 0.25) * 0.85
            l.flash = dt < 0.12 ? 0.55 * (1 - dt / 0.12) : 0
            l.words = dt > 0.35 ? min(1, (dt - 0.35) / 0.25) : 0
        case "dramatic":
            guard dt <= 2.6 else { return l }
            // Snap in three steps with the three notes of the sting, then hold.
            let steps: [(Double, Double)] = [(0, 1.25), (0.5, 1.55), (1.0, 1.95)]
            for (at, z) in steps where dt >= at { l.zoom = z }
            if dt > 2.3 { l.zoom = 1 + (l.zoom - 1) * max(0, (2.6 - dt) / 0.3) }
            l.grey = 0
        case "horn":
            guard dt <= 1.6 else { return l }
            let amp = 0.03 * max(0, 1 - dt / 1.6)
            l.dx = amp * sin(dt * 90); l.dy = amp * cos(dt * 77)
            l.zoom = 1.06
            for at in [0.0, 0.24, 0.48] where dt >= at && dt < at + 0.1 { l.flash = 0.6 * (1 - (dt - at) / 0.1) }
        case "boing":
            guard dt <= 0.8 else { return l }
            l.squash = 1 + 0.22 * sin(dt * 2 * .pi * 5.5) * exp(-dt * 4.5)
        default: break
        }
        return l
    }

    // MARK: making it

    /// The video with the moment in, sound kept and the effect's sound on top. nil if the phone couldn't make it.
    static func make(_ source: URL, kind kindID: String, at chosen: Double?, words: String?, progress: ((Double) -> Void)? = nil) async -> URL? {
        let k = kind(kindID)
        let asset = AVURLAsset(url: source)
        guard let vTrack = try? await asset.loadTracks(withMediaType: .video).first else { return nil }
        let aTrack = try? await asset.loadTracks(withMediaType: .audio).first
        let duration = (try? await asset.load(.duration).seconds) ?? 0
        guard duration > 0.5 else { return nil }
        let fps = Double((try? await vTrack.load(.nominalFrameRate)) ?? 30)
        let frame = 1 / max(1, min(60, fps))
        let loud = chosen == nil ? await loudness(source) : []
        let t = min(max(0, chosen ?? moment(loudness: loud, hop: 0.05, duration: duration, kind: kindID)), duration - frame)

        // The edit: everything up to the moment, the stopped frame, the rest.
        let comp = AVMutableComposition()
        guard let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }
        cv.preferredTransform = (try? await vTrack.load(.preferredTransform)) ?? .identity
        let ca = aTrack != nil ? comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) : nil
        let ts: (Double) -> CMTime = { CMTime(seconds: $0, preferredTimescale: 600) }
        do {
            try cv.insertTimeRange(CMTimeRange(start: .zero, duration: ts(t)), of: vTrack, at: .zero)
            if let aTrack, let ca { try ca.insertTimeRange(CMTimeRange(start: .zero, duration: ts(t)), of: aTrack, at: .zero) }
            if k.freeze > 0 {
                try cv.insertTimeRange(CMTimeRange(start: ts(t), duration: ts(frame)), of: vTrack, at: ts(t))
                cv.scaleTimeRange(CMTimeRange(start: ts(t), duration: ts(frame)), toDuration: ts(k.freeze))
                ca?.insertEmptyTimeRange(CMTimeRange(start: ts(t), duration: ts(k.freeze)))
            }
            let after = t + k.freeze
            if kindID != "rimshot", duration - t > frame {
                try cv.insertTimeRange(CMTimeRange(start: ts(t), end: ts(duration)), of: vTrack, at: ts(after))
                if let aTrack, let ca { try ca.insertTimeRange(CMTimeRange(start: ts(t), end: ts(duration)), of: aTrack, at: ts(after)) }
            }
        } catch { return nil }
        // The effect's own sound, on its own track, at the moment.
        if let sfxURL = Synth.file(Synth.effect(k.sound), name: "sfx"),
           let sfxTrack = try? await AVURLAsset(url: sfxURL).loadTracks(withMediaType: .audio).first,
           let cs = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let len = (try? await AVURLAsset(url: sfxURL).load(.duration)) ?? ts(1)
            try? cs.insertTimeRange(CMTimeRange(start: .zero, duration: len), of: sfxTrack, at: ts(t))
        }

        // The picture: the look of each moment, from its time after the cut.
        let freeze = k.freeze
        let focus = await faceFocus(source, at: t)
        let wordsText = freeze > 0 ? (words ?? k.words).trimmingCharacters(in: .whitespaces) : ""
        let orient = orientation((try? await vTrack.load(.preferredTransform)) ?? .identity)
        let cache = WordsCache()
        guard let vc = try? await AVMutableVideoComposition.videoComposition(with: comp, applyingCIFiltersWithHandler: { request in
            let render = request.renderSize
            var src = request.sourceImage
            if abs(src.extent.width - render.width) > 2 || abs(src.extent.height - render.height) > 2, orient != .up { src = src.oriented(orient) }
            if src.extent.origin != .zero { src = src.transformed(by: CGAffineTransform(translationX: -src.extent.minX, y: -src.extent.minY)) }
            let l = look(kindID, dt: request.compositionTime.seconds - t, freeze: freeze)
            var words: CIImage?
            if l.words > 0, !wordsText.isEmpty { words = cache.image(wordsText, size: render) }
            request.finish(with: apply(l, to: src, size: render, focus: focus, words: words), context: nil)
        }) else { return nil }

        guard let s = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let out = VideoEngine.tempURL("mp4")
        s.outputURL = out; s.outputFileType = .mp4; s.videoComposition = vc; s.metadata = []
        let total = comp.duration.seconds
        let poll = Task { while !Task.isCancelled { progress?(Double(s.progress)); try? await Task.sleep(nanoseconds: 250_000_000) } }
        defer { poll.cancel() }
        return await VideoEngine.run(s, seconds: total) ? out : nil
    }

    /// The words, drawn once per size (the handler runs on many threads).
    private final class WordsCache: @unchecked Sendable {
        private var made: [String: CIImage] = [:]
        private let lock = NSLock()
        func image(_ text: String, size: CGSize) -> CIImage? {
            let key = "\(text)|\(Int(size.width))x\(Int(size.height))"
            lock.lock(); defer { lock.unlock() }
            if let m = made[key] { return m }
            let c = Celebrate.Caption(text: text, scale: 0.075, center: CGPoint(x: 0.5, y: 0.82))
            guard let ui = Celebrate.captionImage(c, frame: size), let cg = ui.cgImage else { return nil }
            let img = CIImage(cgImage: cg)
            let placed = img.transformed(by: CGAffineTransform(translationX: (size.width - img.extent.width) / 2, y: size.height * 0.12))
            made[key] = placed
            return placed
        }
    }

    /// One frame with `l` on it: zoomed toward the face, shaken, squashed, greyed, flashed, with the words.
    static func apply(_ l: Look, to src: CIImage, size: CGSize, focus: CGPoint, words: CIImage?) -> CIImage {
        let rect = CGRect(origin: .zero, size: size)
        let fx = focus.x * size.width, fy = focus.y * size.height
        var tr = CGAffineTransform(translationX: -fx, y: -fy)
            .concatenating(CGAffineTransform(scaleX: l.zoom * (2 - l.squash), y: l.zoom * l.squash))
            .concatenating(CGAffineTransform(translationX: fx + l.dx * size.width, y: fy + l.dy * size.height))
        if l.zoom < 1 {   // pulling back shows a soft frame around the picture, never black edges
            tr = CGAffineTransform(translationX: -size.width / 2, y: -size.height / 2)
                .concatenating(CGAffineTransform(scaleX: l.zoom, y: l.zoom)).concatenating(CGAffineTransform(translationX: size.width / 2, y: size.height / 2))
        }
        var img = src.clampedToExtent().transformed(by: tr).cropped(to: rect)
        if l.zoom < 1 { img = img.composited(over: src.clampedToExtent().applyingGaussianBlur(sigma: 30).cropped(to: rect)) }
        if l.grey > 0 {
            let g = img.applyingFilter("CIPhotoEffectNoir")
            img = img.applyingFilter("CIDissolveTransition", parameters: [kCIInputTargetImageKey: g, kCIInputTimeKey: l.grey]).cropped(to: rect)
        }
        if l.flash > 0 {
            img = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: l.flash)).cropped(to: rect).composited(over: img)
        }
        if let words, l.words > 0 {
            img = words.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: l.words)]).composited(over: img)
        }
        return img.cropped(to: rect)
    }

    /// Where to zoom: the biggest face at the moment (0…1, origin bottom left), or the middle a little high.
    static func faceFocus(_ url: URL, at t: Double) async -> CGPoint {
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        guard let cg = try? await gen.image(at: CMTime(seconds: t, preferredTimescale: 600)).image else { return CGPoint(x: 0.5, y: 0.58) }
        let req = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
        guard let f = req.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) else { return CGPoint(x: 0.5, y: 0.58) }
        return CGPoint(x: f.boundingBox.midX, y: f.boundingBox.midY)
    }

    static func orientation(_ tr: CGAffineTransform) -> CGImagePropertyOrientation {
        switch (tr.a, tr.b, tr.c, tr.d) {
        case (0, 1, -1, 0): return .right
        case (0, -1, 1, 0): return .left
        case (-1, 0, 0, -1): return .down
        default: return .up
        }
    }
}
