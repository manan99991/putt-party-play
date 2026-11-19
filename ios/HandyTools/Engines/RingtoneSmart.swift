import Foundation
import AVFoundation

/// The thinking behind Ringtone: how loud each moment of a song is (for the waveform), and where its
/// best part is — the loudest, fullest stretch the length of the tone, usually the chorus — so the tone
/// starts on the part people know. Pure deciding, unit-tested; the reading is on the phone.
enum RingtoneSmart {
    /// Loudness across the clip, `buckets` values from 0 to 1. nil when there's no readable sound.
    static func levels(_ url: URL, buckets: Int = 160) async -> [Float]? {
        let asset = AVURLAsset(url: url)
        guard let tracks = try? await asset.loadTracks(withMediaType: .audio), !tracks.isEmpty,
              let dur = try? await asset.load(.duration), dur.seconds > 0,
              let reader = try? AVAssetReader(asset: asset) else { return nil }
        let rate = 4000.0
        let out = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false, AVNumberOfChannelsKey: 1, AVSampleRateKey: rate])
        guard reader.canAdd(out) else { return nil }
        reader.add(out)
        guard reader.startReading() else { return nil }
        let total = max(1, Int(dur.seconds * rate))
        let per = max(1, total / buckets)
        var sums = [Double](repeating: 0, count: buckets), counts = [Int](repeating: 0, count: buckets)
        var index = 0
        while let sb = out.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(sb) else { continue }
            let n = CMBlockBufferGetDataLength(block) / 2
            guard n > 0 else { continue }
            var samples = [Int16](repeating: 0, count: n)
            let ok = samples.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: n * 2, destination: $0.baseAddress!) }
            guard ok == kCMBlockBufferNoErr else { continue }
            for v in samples {
                let b = min(buckets - 1, index / per)
                sums[b] += Double(v) * Double(v); counts[b] += 1; index += 1
            }
        }
        let rms = zip(sums, counts).map { $1 > 0 ? Float(($0 / Double($1)).squareRoot()) : 0 }
        guard let top = rms.max(), top > 0 else { return nil }
        return rms.map { $0 / top }
    }

    /// Where the best `length` seconds start: the window with the most sound, skipping a quiet intro.
    /// Clips no longer than the tone start at 0.
    static func bestStart(_ levels: [Float], total: Double, length: Double) -> Double {
        guard !levels.isEmpty, total > length + 0.5 else { return 0 }
        let step = total / Double(levels.count)
        let w = max(1, min(levels.count, Int((length / step).rounded())))
        var sum = levels.prefix(w).reduce(0, +), best = sum, at = 0
        guard levels.count > w else { return 0 }
        for i in 1...(levels.count - w) {
            sum += levels[i + w - 1] - levels[i - 1]
            // A loud stretch wins; a later one only when clearly louder (the first chorus beats the last).
            if sum > best * 1.03 { best = sum; at = i }
        }
        return min(Double(at) * step, max(0, total - length))
    }
}
