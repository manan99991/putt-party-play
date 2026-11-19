import Foundation
import AVFoundation
import UniformTypeIdentifiers

/// Audio format conversion between the common phone formats, entirely on-device. Decodes anything iOS
/// can read (M4A/AAC, MP3, WAV, AIFF, CAF, and the audio inside a MOV/MP4) and re-encodes to a format
/// the phone can actually write: M4A (AAC), WAV, AIFF or CAF.
///
/// Honesty about what the phone can do: iOS ships an MP3 *decoder* but no MP3 *encoder*, so an MP3 can
/// be converted *from* but never *to* on an iPhone. The tool accepts MP3 input and steers the user to
/// M4A (which is smaller and plays everywhere) instead of silently failing.
///
/// Built on the same AVAssetReader → AVAssetWriter streaming path proven in `VideoEngine`: real 0…1
/// progress, a hard timeout so it can never hang the UI, and a background-task wrapper so a long file
/// keeps converting if the user switches apps.
enum AudioConvert {

    /// The output formats an iPhone can genuinely encode on-device. (MP3 is intentionally absent — see
    /// the type doc; `mp3Note` is the line the UI shows about it.)
    enum Format: String, CaseIterable, Identifiable {
        case m4a, wav, aiff, caf

        var id: String { rawValue }
        var ext: String { rawValue }

        var title: String {
            switch self {
            case .m4a: return "M4A (AAC)"
            case .wav: return "WAV"
            case .aiff: return "AIFF"
            case .caf: return "CAF"
            }
        }

        /// "What's it for?" → the format that fits, so nobody has to know what AIFF is.
        static let purposes: [(label: String, format: Format, why: String)] = [
            ("Email or message it", .m4a, "M4A is about a tenth the size of WAV and plays on every phone and computer."),
            ("Works everywhere", .wav, "WAV opens in every app, website and car stereo — it's just bigger."),
            ("Edit in GarageBand or Logic", .aiff, "AIFF is the lossless format Apple's audio apps prefer."),
            ("Burn to a CD or DJ software", .wav, "WAV is what CD burners and DJ apps expect."),
            ("Upload to a website", .wav, "Most upload forms accept WAV even when they refuse M4A."),
            ("Very long recording", .caf, "CAF has no 4 GB limit, so hours of audio stay in one file."),
        ]

        /// Roughly how big the result will be, from the length — shown before converting.
        static func estimatedBytes(_ f: Format, seconds: Double, sampleRate: Double = 44_100, channels: Int = 2) -> Double {
            switch f {
            case .m4a: return seconds * 128_000 / 8
            case .wav, .aiff, .caf: return seconds * sampleRate * Double(channels) * 2
            }
        }

        var detail: String {
            switch self {
            case .m4a: return "Small file, plays everywhere"
            case .wav: return "Uncompressed, universally supported"
            case .aiff: return "Uncompressed, Apple standard"
            case .caf: return "Uncompressed, good for long audio"
            }
        }

        var fileType: AVFileType {
            switch self {
            case .m4a: return .m4a
            case .wav: return .wav
            case .aiff: return .aiff
            case .caf: return .caf
            }
        }

        /// WAV/AIFF/CAF carry linear PCM; M4A carries AAC. AIFF stores PCM big-endian.
        var isPCM: Bool { self != .m4a }
        var bigEndian: Bool { self == .aiff }
    }

    enum Failure: Error {
        case noAudioTrack, cannotWrite, timedOut

        var message: String {
            switch self {
            case .noAudioTrack: return "That file has no audio Tenzy can read."
            case .cannotWrite: return "This phone couldn't create that format."
            case .timedOut: return "Converting took too long and was stopped."
            }
        }
    }

    /// The honest MP3 line the tool shows, since the iPhone can read MP3 but not write it.
    static let mp3Note = "iPhone can read MP3 but can't create one — convert to M4A, which is smaller and plays everywhere."

    /// Convert `src` to `format`. Streams the source through a decoder → encoder, reporting 0…1
    /// `progress`, and never hangs: a hard `timeout` cancels the pipeline and resolves cleanly.
    static func convert(_ src: URL, to format: Format,
                        timeout: TimeInterval = 180,
                        bitRate: Int? = nil, maxChannels: Int = 2, maxSampleRate: Double? = nil,
                        progress: ((Double) -> Void)? = nil) async -> Result<URL, Failure> {
        let asset = AVURLAsset(url: src)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else {
            return .failure(.noAudioTrack)
        }
        let durationSec = (try? await asset.load(.duration))?.seconds ?? 0

        // Preserve the source's sample rate and channel count (down to mono/stereo for exotic layouts),
        // so converting the container doesn't quietly resample or remix the audio.
        var sampleRate = 44_100.0
        var channels = 2
        if let desc = (try? await track.load(.formatDescriptions))?.first,
           let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee {
            if asbd.mSampleRate > 0 { sampleRate = asbd.mSampleRate }
            if asbd.mChannelsPerFrame > 0 { channels = Int(asbd.mChannelsPerFrame) }
        }
        channels = min(max(1, min(2, maxChannels)), max(1, channels))
        if let cap = maxSampleRate, sampleRate > cap { sampleRate = cap }

        let out = VideoEngine.tempURL(format.ext)
        guard let reader = try? AVAssetReader(asset: asset),
              let writer = try? AVAssetWriter(outputURL: out, fileType: format.fileType) else {
            return .failure(.cannotWrite)
        }

        // For a PCM target, decode straight to the integer PCM we'll write and let the writer pass it
        // through (identical settings on both sides). For M4A, decode to linear PCM and let the
        // writer's AAC encoder compress it — the pattern VideoEngine uses for a movie's audio track.
        let readerSettings: [String: Any]
        let writerSettings: [String: Any]
        if format.isPCM {
            let pcm: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: format.bigEndian,
                AVLinearPCMIsNonInterleaved: false,
            ]
            readerSettings = pcm
            writerSettings = pcm
        } else {
            if maxChannels < 2 || maxSampleRate != nil {
                // Downmix / resample in the decoder so the AAC encoder gets exactly what it encodes.
                readerSettings = [AVFormatIDKey: kAudioFormatLinearPCM,
                                  AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: channels]
            } else {
                readerSettings = [AVFormatIDKey: kAudioFormatLinearPCM]
            }
            writerSettings = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: channels,
                AVSampleRateKey: sampleRate,
                AVEncoderBitRateKey: bitRate ?? (channels >= 2 ? 128_000 : 96_000),
            ]
        }

        let aOut = AVAssetReaderTrackOutput(track: track, outputSettings: readerSettings)
        aOut.alwaysCopiesSampleData = false
        guard reader.canAdd(aOut) else { return .failure(.cannotWrite) }
        reader.add(aOut)

        let aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: writerSettings)
        aIn.expectsMediaDataInRealTime = false
        guard writer.canAdd(aIn) else { return .failure(.cannotWrite) }
        writer.add(aIn)

        guard reader.startReading(), writer.startWriting() else { return .failure(.cannotWrite) }
        writer.startSession(atSourceTime: .zero)

        let finished: Bool = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    aIn.requestMediaDataWhenReady(on: DispatchQueue(label: "tenzy.audioconvert")) {
                        while aIn.isReadyForMoreMediaData {
                            // Leave on end-of-stream OR a reader/writer error, finishing the file and
                            // resuming the continuation on every path — so the task group always
                            // balances and the pipeline can never dangle.
                            if writer.status == .failed || reader.status == .failed || reader.status == .cancelled {
                                aIn.markAsFinished(); writer.finishWriting { cont.resume() }; return
                            }
                            guard let s = aOut.copyNextSampleBuffer(), aIn.append(s) else {
                                aIn.markAsFinished(); writer.finishWriting { cont.resume() }; return
                            }
                            if durationSec > 0, let p = progress {
                                p(min(0.99, CMSampleBufferGetPresentationTimeStamp(s).seconds / durationSec))
                            }
                        }
                    }
                }
                return writer.status == .completed
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                reader.cancelReading(); writer.cancelWriting()
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }

        if finished { progress?(1); return .success(out) }
        try? FileManager.default.removeItem(at: out)
        return .failure(reader.status == .cancelled ? .timedOut : .cannotWrite)
    }

    /// Longest a ringtone may be: iOS rejects a custom tone over 30 seconds.
    static let maxRingtoneSeconds = 30.0

    /// Build a ringtone: the [start, start+length] slice of the source re-encoded as AAC in an `.m4r`
    /// container (the same MPEG-4 audio container iOS uses for tones). `length` is clamped to 30s, and
    /// the slice is clamped inside the source so a bad range can never produce an empty or over-long
    /// file. The caller hands the result off via the share sheet (Files → GarageBand), since iOS gives
    /// no API to set a ringtone directly.
    static func ringtone(_ src: URL, start: Double, length: Double, fade: Double = 0) async -> Result<URL, Failure> {
        let asset = AVURLAsset(url: src)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else {
            return .failure(.noAudioTrack)
        }
        let total = (try? await asset.load(.duration))?.seconds ?? 0
        guard total > 0 else { return .failure(.noAudioTrack) }
        let begin = max(0, min(start, max(0, total - 0.5)))
        let len = max(0.5, min(min(length, maxRingtoneSeconds), total - begin))
        let range = CMTimeRange(start: CMTime(seconds: begin, preferredTimescale: 600),
                                duration: CMTime(seconds: len, preferredTimescale: 600))

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            return .failure(.cannotWrite)
        }
        let out = VideoEngine.tempURL("m4r")
        session.outputURL = out
        session.outputFileType = .m4a   // .m4r is the same container; only the extension differs
        session.timeRange = range
        session.metadata = []
        // A gentle fade in and out, so the tone starts softly and never cuts off mid-note.
        if fade > 0 {
            let f = min(fade, len / 3)
            let p = AVMutableAudioMixInputParameters(track: track)
            p.setVolumeRamp(fromStartVolume: 0, toEndVolume: 1, timeRange: CMTimeRange(start: range.start, duration: CMTime(seconds: f, preferredTimescale: 600)))
            p.setVolumeRamp(fromStartVolume: 1, toEndVolume: 0, timeRange: CMTimeRange(start: CMTime(seconds: begin + len - f, preferredTimescale: 600), duration: CMTime(seconds: f, preferredTimescale: 600)))
            let mix = AVMutableAudioMix(); mix.inputParameters = [p]
            session.audioMix = mix
        }

        let ok = await withTaskGroup(of: Bool.self) { group -> Bool in
            group.addTask { await session.export(); return session.status == .completed }
            group.addTask {
                try? await Task.sleep(nanoseconds: 120 * 1_000_000_000)
                session.cancelExport(); return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
        if ok { return .success(out) }
        try? FileManager.default.removeItem(at: out)
        return .failure(.cannotWrite)
    }
}

// MARK: - Compress

extension AudioConvert {
    /// Compression levels, smallest last. Each is a bitrate/channel/sample-rate combination the AAC
    /// encoder accepts on every iPhone, so a level never fails for being "invalid".
    enum Level: Int, CaseIterable, Identifiable {
        case high, balanced, small, smallest
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .high: return "High quality"
            case .balanced: return "Balanced"
            case .small: return "Small"
            case .smallest: return "Smallest (voice)"
            }
        }
        var detail: String {
            switch self {
            case .high: return "Stereo · 128 kbps — music sounds like the original"
            case .balanced: return "Stereo · 96 kbps — great for most music"
            case .small: return "Mono · 64 kbps — podcasts, lectures, voice memos"
            case .smallest: return "Mono · 32 kbps — speech only, tiny files"
            }
        }
        var bitRate: Int {
            switch self {
            case .high: return 128_000
            case .balanced: return 96_000
            case .small: return 64_000
            case .smallest: return 32_000
            }
        }
        var channels: Int { self == .high || self == .balanced ? 2 : 1 }
        var sampleRate: Double { self == .smallest ? 22_050 : 44_100 }

        /// Expected output size for `seconds` of audio (AAC + container overhead ≈ 3%).
        func estimatedBytes(seconds: Double) -> Int { Int(Double(bitRate) / 8 * max(0, seconds) * 1.03) }
    }

    /// The best-sounding level whose estimate fits under `bytes` — or `.smallest` if nothing does
    /// (the caller says so honestly).
    static func level(fitting bytes: Int, seconds: Double) -> (level: Level, fits: Bool) {
        for l in Level.allCases where l.estimatedBytes(seconds: seconds) <= bytes { return (l, true) }
        return (.smallest, false)
    }

    /// Re-encode `src` as M4A at `level`. If this phone's encoder refuses that combination, steps up to
    /// the next level instead of failing — best effort, never a dead end.
    static func compress(_ src: URL, level: Level,
                         progress: ((Double) -> Void)? = nil) async -> Result<(url: URL, level: Level), Failure> {
        var lastError: Failure = .cannotWrite
        for l in Level.allCases.reversed() where l.rawValue <= level.rawValue {
            let r = await convert(src, to: .m4a, timeout: 600, bitRate: l.bitRate, maxChannels: l.channels,
                                  maxSampleRate: l.sampleRate, progress: progress)
            switch r {
            case .success(let url): return .success((url, l))
            case .failure(let f):
                lastError = f
                if f != .cannotWrite { return .failure(f) }   // no audio / timed out: a higher level won't help
            }
        }
        return .failure(lastError)
    }
}
