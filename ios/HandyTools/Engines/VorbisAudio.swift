import Foundation
import AVFoundation
#if canImport(StbVorbis)
import StbVorbis
#endif

/// Ogg Vorbis (.ogg / .oga — podcasts, game audio, many Android recordings) decoded on the phone into a normal
/// .m4a, since iPhone can't play Vorbis by itself. Opus voice notes go through SwiftOGG instead.
enum VorbisAudio {
    /// The decoded file, or nil if it isn't Ogg Vorbis (or is damaged).
    static func toM4A(_ url: URL) -> URL? {
        #if canImport(StbVorbis)
        guard let data = try? Data(contentsOf: url), data.count > 28, data.prefix(4) == Data("OggS".utf8) else { return nil }
        var channels: Int32 = 0, rate: Int32 = 0
        var pcm: UnsafeMutablePointer<Int16>? = nil
        let frames = data.withUnsafeBytes { raw -> Int32 in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return -1 }
            return stb_vorbis_decode_memory(base, Int32(data.count), &channels, &rate, &pcm)
        }
        defer { if let pcm { free(pcm) } }
        guard frames > 0, channels > 0, rate > 0, let pcm else { return nil }
        let ch = Int(channels), n = Int(frames)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Double(rate), channels: AVAudioChannelCount(ch)),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(n)
        for c in 0..<ch {
            let dst = buffer.floatChannelData![c]
            for i in 0..<n { dst[i] = Float(pcm[i * ch + c]) / 32768 }
        }
        return AudioOut.save(buffer, name: url.deletingPathExtension().lastPathComponent)
        #else
        return nil
        #endif
    }
}
