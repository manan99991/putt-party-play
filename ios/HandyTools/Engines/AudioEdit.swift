import Foundation
import AVFoundation
import Accelerate

/// Audio editing on-device: trim to a slice, fade in / fade out, and auto-remove dead air (long silent
/// gaps). Entirely on the phone, nothing uploaded. The source may be an audio file or a video (its audio
/// track is used), matching the other audio tools.
///
/// Unlike `AudioConvert`, which streams the source straight through a decoder→encoder, editing needs
/// random access to the samples (to cut gaps out of the middle and shape the edges), so the track is
/// decoded to in-memory float PCM, processed, and written back out. A duration cap keeps that bounded so
/// a huge file can never exhaust memory. Writing reuses `AVAudioFile`, which encodes AAC (M4A) or writes
/// linear PCM (WAV) on the fly from a float buffer.
///
/// The sample-level work (silence detection, segment keeping, fades) lives in small pure functions so it
/// is unit-tested directly on buffers, without needing a real file.
enum AudioEdit {

    /// Longest clip the editor will load into memory (30 minutes). Longer files are refused with a clear
    /// message rather than risking an out-of-memory crash — honest about the on-device limit.
    static let maxEditSeconds = 1800.0

    /// What to do to the clip. `end <= 0` (or past the clip) means "to the end".
    struct Options {
        var start: Double = 0           // seconds
        var end: Double = 0             // seconds; <= 0 → to the end
        var fadeIn: Double = 0          // seconds
        var fadeOut: Double = 0         // seconds
        var removeSilence: Bool = false
        var silenceThresholdDB: Double = -40   // below this RMS a window counts as silent
        var minSilence: Double = 0.5           // only gaps at least this long are cut
    }

    enum Failure: Error {
        case noAudioTrack, cannotRead, cannotWrite, tooLong, empty

        var message: String {
            switch self {
            case .noAudioTrack: return "That file has no audio Tenzy can read."
            case .cannotRead:   return "Tenzy couldn't read that audio."
            case .cannotWrite:  return "This phone couldn't save the edited audio."
            case .tooLong:      return "That clip is too long to edit on-device. Trim it in Video first, or pick a shorter file."
            case .empty:        return "Those settings leave nothing to save — widen the range."
            }
        }
    }

    // MARK: - Pure sample processing (unit-tested directly)

    /// Linear fade in over the first `fadeIn` seconds and fade out over the last `fadeOut` seconds, in
    /// place. A zero or negative duration is a no-op; durations longer than the clip are clamped.
    static func applyFades(_ x: inout [Float], rate: Double, fadeIn: Double, fadeOut: Double) {
        let n = x.count
        guard n > 0, rate > 0 else { return }
        let fi = min(n, max(0, Int(fadeIn * rate)))
        if fi > 0 { for i in 0..<fi { x[i] *= Float(i) / Float(fi) } }
        let fo = min(n, max(0, Int(fadeOut * rate)))
        if fo > 0 { for i in 0..<fo { x[n - 1 - i] *= Float(i) / Float(fo) } }
    }

    /// The sample ranges of `mono` that are quiet for at least `minSilence` seconds — the "dead air" to
    /// cut. RMS is measured in 20 ms windows; a run of silent windows at least `minSilence` long becomes
    /// one region. Returns an empty list when nothing qualifies.
    static func silentRegions(_ mono: [Float], rate: Double,
                              thresholdDB: Double = -40, minSilence: Double = 0.5) -> [Range<Int>] {
        guard !mono.isEmpty, rate > 0 else { return [] }
        let win = max(1, Int(rate * 0.02))                 // 20 ms windows
        let thr = Float(pow(10.0, thresholdDB / 20.0))     // dBFS → linear amplitude
        var silent: [Bool] = []
        var i = 0
        mono.withUnsafeBufferPointer { p in
            while i < mono.count {
                let end = min(mono.count, i + win)
                var sumsq: Float = 0
                vDSP_svesq(p.baseAddress! + i, 1, &sumsq, vDSP_Length(end - i))
                let rms = sqrt(sumsq / Float(end - i))
                silent.append(rms < thr)
                i += win
            }
        }
        let minWins = max(1, Int((minSilence / 0.02).rounded()))
        var regions: [Range<Int>] = []
        var w = 0
        while w < silent.count {
            if silent[w] {
                var e = w
                while e < silent.count, silent[e] { e += 1 }
                if e - w >= minWins {
                    let lo = w * win
                    let hi = min(mono.count, e * win)
                    regions.append(lo..<hi)
                }
                w = e
            } else {
                w += 1
            }
        }
        return regions
    }

    /// The complement of `cut` within `0..<total`: the segments to keep, in order, with the cut ranges
    /// removed. Overlapping or out-of-order cut ranges are handled safely.
    static func keepSegments(total: Int, cut: [Range<Int>]) -> [Range<Int>] {
        guard total > 0 else { return [] }
        let sorted = cut.sorted { $0.lowerBound < $1.lowerBound }
        var kept: [Range<Int>] = []
        var pos = 0
        for r in sorted {
            let lo = max(0, min(total, r.lowerBound))
            let hi = max(0, min(total, r.upperBound))
            if lo > pos { kept.append(pos..<lo) }
            pos = max(pos, hi)
        }
        if pos < total { kept.append(pos..<total) }
        return kept
    }

    /// Apply `options` to the decoded channels (one `[Float]` per channel, equal length). Trims to the
    /// chosen slice, removes silent gaps across all channels together (so they stay in sync), then fades
    /// the edges. Returns one processed `[Float]` per input channel (possibly empty when nothing remains).
    static func process(channels: [[Float]], rate: Double, options: Options) -> [[Float]] {
        guard let first = channels.first, !first.isEmpty, rate > 0 else {
            return channels.map { _ in [] }
        }
        let n = first.count
        let s0 = max(0, min(n, Int(options.start * rate)))
        let e0: Int
        if options.end <= 0 || options.end * rate >= Double(n) {
            e0 = n
        } else {
            e0 = max(s0, min(n, Int(options.end * rate)))
        }
        guard e0 > s0 else { return channels.map { _ in [] } }

        // Mono reference over the slice drives silence detection so every channel is cut identically.
        let span = e0 - s0
        var cut: [Range<Int>] = []
        if options.removeSilence {
            var mono = [Float](repeating: 0, count: span)
            for c in channels {
                for i in 0..<span { mono[i] += c[s0 + i] }
            }
            let inv = 1 / Float(channels.count)
            for i in 0..<span { mono[i] *= inv }
            cut = silentRegions(mono, rate: rate,
                                thresholdDB: options.silenceThresholdDB, minSilence: options.minSilence)
        }
        let kept = keepSegments(total: span, cut: cut)

        var out = [[Float]](repeating: [], count: channels.count)
        for (ci, c) in channels.enumerated() {
            var acc = [Float]()
            acc.reserveCapacity(span)
            for r in kept {
                acc.append(contentsOf: c[(s0 + r.lowerBound)..<(s0 + r.upperBound)])
            }
            applyFades(&acc, rate: rate, fadeIn: options.fadeIn, fadeOut: options.fadeOut)
            out[ci] = acc
        }
        return out
    }

    // MARK: - File level

    /// Decode the first audio track of `src` to interleaved float PCM, keeping its sample rate and (up to
    /// stereo) channel count. Returns nil on any read failure or when there is no audio.
    private static func readSamples(_ src: URL) async -> (samples: [Float], rate: Double, channels: Int)? {
        let asset = AVURLAsset(url: src)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else { return nil }
        var rate = 44_100.0
        var channels = 2
        if let desc = (try? await track.load(.formatDescriptions))?.first,
           let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee {
            if asbd.mSampleRate > 0 { rate = asbd.mSampleRate }
            if asbd.mChannelsPerFrame > 0 { channels = Int(asbd.mChannelsPerFrame) }
        }
        channels = min(2, max(1, channels))

        guard let reader = try? AVAssetReader(asset: asset) else { return nil }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: rate,
            AVNumberOfChannelsKey: channels,
        ]
        let aOut = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        aOut.alwaysCopiesSampleData = false
        guard reader.canAdd(aOut) else { return nil }
        reader.add(aOut)
        guard reader.startReading() else { return nil }

        var samples: [Float] = []
        while reader.status == .reading, let sb = aOut.copyNextSampleBuffer() {
            if let bb = CMSampleBufferGetDataBuffer(sb) {
                let len = CMBlockBufferGetDataLength(bb)
                if len > 0 {
                    var data = Data(count: len)
                    let status = data.withUnsafeMutableBytes { raw -> OSStatus in
                        CMBlockBufferCopyDataBytes(bb, atOffset: 0, dataLength: len, destination: raw.baseAddress!)
                    }
                    if status == kCMBlockBufferNoErr {
                        let floats = data.withUnsafeBytes { raw -> [Float] in
                            Array(raw.bindMemory(to: Float.self))
                        }
                        samples.append(contentsOf: floats)
                    }
                }
            }
            CMSampleBufferInvalidate(sb)
        }
        guard reader.status == .completed, !samples.isEmpty else { return nil }
        return (samples, rate, channels)
    }

    /// Edit `src` per `options`, writing the result as `format` (M4A by default). Reports 0…1 `progress`.
    static func edit(_ src: URL, options: Options,
                     format: AudioConvert.Format = .m4a,
                     progress: ((Double) -> Void)? = nil) async -> Result<URL, Failure> {
        let asset = AVURLAsset(url: src)
        guard (try? await asset.loadTracks(withMediaType: .audio).first) != nil else {
            return .failure(.noAudioTrack)
        }
        let durationSec = (try? await asset.load(.duration))?.seconds ?? 0
        if durationSec > maxEditSeconds { return .failure(.tooLong) }

        progress?(0.05)
        guard let read = await readSamples(src) else { return .failure(.cannotRead) }
        progress?(0.5)

        let frames = read.samples.count / read.channels
        guard frames > 0 else { return .failure(.noAudioTrack) }
        var channels = [[Float]](repeating: [Float](repeating: 0, count: frames), count: read.channels)
        read.samples.withUnsafeBufferPointer { p in
            for f in 0..<frames {
                let base = f * read.channels
                for c in 0..<read.channels { channels[c][f] = p[base + c] }
            }
        }

        let processed = process(channels: channels, rate: read.rate, options: options)
        let outFrames = processed.first?.count ?? 0
        guard outFrames > 0 else { return .failure(.empty) }
        progress?(0.65)

        let out = VideoEngine.tempURL(format.ext)
        let writeSettings: [String: Any]
        if format.isPCM {
            writeSettings = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: read.rate,
                AVNumberOfChannelsKey: read.channels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: format.bigEndian,
                AVLinearPCMIsNonInterleaved: false,
            ]
        } else {
            writeSettings = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: read.rate,
                AVNumberOfChannelsKey: read.channels,
                AVEncoderBitRateKey: read.channels >= 2 ? 128_000 : 96_000,
            ]
        }

        guard let file = try? AVAudioFile(forWriting: out, settings: writeSettings) else {
            return .failure(.cannotWrite)
        }
        let procFmt = file.processingFormat
        guard let buf = AVAudioPCMBuffer(pcmFormat: procFmt, frameCapacity: AVAudioFrameCount(outFrames)),
              let dst = buf.floatChannelData else {
            return .failure(.cannotWrite)
        }
        buf.frameLength = AVAudioFrameCount(outFrames)
        let bufChannels = Int(procFmt.channelCount)
        for c in 0..<bufChannels {
            let srcChannel = processed[min(c, processed.count - 1)]
            srcChannel.withUnsafeBufferPointer { p in
                if let base = p.baseAddress { dst[c].update(from: base, count: outFrames) }
            }
        }
        do {
            try file.write(from: buf)
        } catch {
            try? FileManager.default.removeItem(at: out)
            return .failure(.cannotWrite)
        }
        progress?(1)
        return .success(out)
    }
}
