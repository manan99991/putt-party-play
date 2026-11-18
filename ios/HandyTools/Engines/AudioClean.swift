import Foundation
import AVFoundation
import Accelerate

/// On-device audio cleanup: remove low rumble / mains-hum foundation with a high-pass filter, push down
/// steady background hiss with a downward gate measured from the clip's own quiet parts, and even out the
/// volume to a consistent level. Everything runs on the phone; nothing is uploaded.
///
/// This is honest DSP, not a studio denoiser: it tidies real recordings (a voice memo with a fan in the
/// background, a clip that's too quiet, a hum on the line) without a model. The sample-level work lives in
/// small pure functions so it is unit-tested directly on buffers, without needing a real file. The file
/// plumbing (decode → process → encode) mirrors `AudioEdit` so it stays on proven ground.
enum AudioClean {

    /// Longest clip the tool will load into memory (30 minutes), matching `AudioEdit`. Longer files are
    /// refused with a clear message rather than risking an out-of-memory crash.
    static let maxSeconds = 1800.0

    /// What to tidy. All three are on by default — the common "just clean it up" case — and each can be
    /// turned off. `strength` (0…1) scales how hard the noise gate pushes down the quiet background.
    struct Options {
        var highPass = true        // cut rumble / hum foundation below ~90 Hz
        var reduceNoise = true     // push down steady background hiss
        var normalize = true       // bring the level up to a consistent target
        var strength: Double = 0.6 // 0…1 gate aggressiveness
    }

    enum Failure: Error {
        case noAudioTrack, cannotRead, cannotWrite, tooLong, empty

        var message: String {
            switch self {
            case .noAudioTrack: return "That file has no audio Tenzy can read."
            case .cannotRead:   return "Tenzy couldn't read that audio."
            case .cannotWrite:  return "This phone couldn't save the cleaned-up audio."
            case .tooLong:      return "That clip is too long to clean up on-device. Pick a shorter file."
            case .empty:        return "There's nothing to clean up in that clip."
            }
        }
    }

    // MARK: - Pure sample processing (unit-tested directly)

    /// Second-order (RBJ) high-pass biquad run in place. Removes slow rumble and the foundation of mains
    /// hum below `cutoff` Hz while leaving speech and music intact. A constant (DC) input decays to zero.
    static func highPass(_ x: inout [Float], rate: Double, cutoff: Double = 90) {
        guard x.count > 2, rate > 0, cutoff > 0, cutoff < rate / 2 else { return }
        let w0 = 2 * Double.pi * cutoff / rate
        let cosw = cos(w0), sinw = sin(w0)
        let q = 0.707
        let alpha = sinw / (2 * q)
        let a0 = 1 + alpha
        let nb0 = Float((1 + cosw) / 2 / a0)
        let nb1 = Float(-(1 + cosw) / a0)
        let nb2 = Float((1 + cosw) / 2 / a0)
        let na1 = Float(-2 * cosw / a0)
        let na2 = Float((1 - alpha) / a0)
        var x1: Float = 0, x2: Float = 0, y1: Float = 0, y2: Float = 0
        for i in 0..<x.count {
            let xn = x[i]
            let yn = nb0 * xn + nb1 * x1 + nb2 * x2 - na1 * y1 - na2 * y2
            x2 = x1; x1 = xn
            y2 = y1; y1 = yn
            x[i] = yn
        }
    }

    /// Estimate the steady noise floor (linear RMS) from the quietest part of the signal: the RMS of each
    /// 20 ms window, then the 20th-percentile window. The quiet gaps between speech set the floor, not the
    /// loud passages. Returns 0 for empty / silent input.
    static func noiseFloor(_ x: [Float], rate: Double) -> Float {
        guard !x.isEmpty, rate > 0 else { return 0 }
        let win = max(1, Int(rate * 0.02))
        var rmss: [Float] = []
        var i = 0
        x.withUnsafeBufferPointer { p in
            while i < x.count {
                let end = min(x.count, i + win)
                var sumsq: Float = 0
                vDSP_svesq(p.baseAddress! + i, 1, &sumsq, vDSP_Length(end - i))
                rmss.append(sqrt(sumsq / Float(end - i)))
                i += win
            }
        }
        guard !rmss.isEmpty else { return 0 }
        rmss.sort()
        let idx = max(0, min(rmss.count - 1, Int(Double(rmss.count) * 0.2)))
        return rmss[idx]
    }

    /// Downward gate / expander, in place. Follows the signal envelope; where it sits near the measured
    /// noise `floor` the gain is pulled down toward `floorGain = 1 - strength` (so `strength` 1 would
    /// mute pure noise, 0.6 leaves it at 40%), with smoothing so the gain never chatters. Louder passages
    /// pass at full gain. `strength`/`floor` of 0 is a no-op.
    static func gate(_ x: inout [Float], rate: Double, floor: Float, strength: Double) {
        guard !x.isEmpty, rate > 0, floor > 0, strength > 0 else { return }
        let thr = floor * Float(1 + 2 * strength)        // open above a margin over the floor
        let floorGain = Float(max(0, 1 - strength))      // how far down pure noise is pushed
        let atk = Float(exp(-1.0 / (0.005 * rate)))      // 5 ms attack
        let rel = Float(exp(-1.0 / (0.08 * rate)))       // 80 ms release
        let gSmooth = Float(exp(-1.0 / (0.02 * rate)))   // 20 ms gain smoothing
        var env: Float = 0
        var gain: Float = 1
        for i in 0..<x.count {
            let a = abs(x[i])
            env = a > env ? (atk * env + (1 - atk) * a) : (rel * env + (1 - rel) * a)
            let target: Float = env >= thr ? 1 : floorGain
            gain = gSmooth * gain + (1 - gSmooth) * target
            x[i] *= gain
        }
    }

    /// Scale so the loudest peak across all channels hits `targetPeak` (default ≈ -1 dBFS). Uses one
    /// shared gain for every channel so stereo balance is preserved. Never divides by a (near-)silent
    /// peak and never boosts more than ~20 dB, so a nearly empty clip can't blow up.
    static func normalize(_ channels: inout [[Float]], targetPeak: Float = 0.891) {
        var peak: Float = 0
        for c in channels where !c.isEmpty {
            var p: Float = 0
            vDSP_maxmgv(c, 1, &p, vDSP_Length(c.count))
            peak = max(peak, p)
        }
        guard peak > 1e-6 else { return }
        var g = min(Float(10), targetPeak / peak)
        guard g != 1 else { return }
        for ci in 0..<channels.count where !channels[ci].isEmpty {
            channels[ci].withUnsafeMutableBufferPointer { p in
                if let base = p.baseAddress { vDSP_vsmul(base, 1, &g, base, 1, vDSP_Length(p.count)) }
            }
        }
    }

    /// Apply `options` to the decoded channels (one `[Float]` per channel, equal length). High-passes each
    /// channel, gates with a floor measured from a mono mix (so channels gate in sync), then normalizes
    /// with a shared gain. Length is preserved.
    static func clean(channels: [[Float]], rate: Double, options: Options) -> [[Float]] {
        guard let first = channels.first, !first.isEmpty, rate > 0 else { return channels }
        let n = first.count

        var floor: Float = 0
        if options.reduceNoise {
            var mono = [Float](repeating: 0, count: n)
            for c in channels { for i in 0..<min(n, c.count) { mono[i] += c[i] } }
            let inv = 1 / Float(max(1, channels.count))
            for i in 0..<n { mono[i] *= inv }
            if options.highPass { highPass(&mono, rate: rate) }   // measure the floor after rumble is gone
            floor = noiseFloor(mono, rate: rate)
        }

        var out = channels
        for ci in 0..<out.count {
            if options.highPass { highPass(&out[ci], rate: rate) }
            if options.reduceNoise { gate(&out[ci], rate: rate, floor: floor, strength: options.strength) }
        }
        if options.normalize { normalize(&out) }
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

    /// Clean up `src` per `options`, writing the result as `format` (M4A by default). Reports 0…1
    /// `progress`. Entirely on-device.
    static func clean(_ src: URL, options: Options,
                      format: AudioConvert.Format = .m4a,
                      progress: ((Double) -> Void)? = nil) async -> Result<URL, Failure> {
        let asset = AVURLAsset(url: src)
        guard (try? await asset.loadTracks(withMediaType: .audio).first) != nil else {
            return .failure(.noAudioTrack)
        }
        let durationSec = (try? await asset.load(.duration))?.seconds ?? 0
        if durationSec > maxSeconds { return .failure(.tooLong) }

        progress?(0.05)
        guard let read = await readSamples(src) else { return .failure(.cannotRead) }
        progress?(0.5)

        let frames = read.samples.count / read.channels
        guard frames > 0 else { return .failure(.empty) }
        var channels = [[Float]](repeating: [Float](repeating: 0, count: frames), count: read.channels)
        read.samples.withUnsafeBufferPointer { p in
            for f in 0..<frames {
                let base = f * read.channels
                for c in 0..<read.channels { channels[c][f] = p[base + c] }
            }
        }

        let processed = clean(channels: channels, rate: read.rate, options: options)
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
