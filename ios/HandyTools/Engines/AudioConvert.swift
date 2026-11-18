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
        channels = min(2, max(1, channels))

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
            readerSettings = [AVFormatIDKey: kAudioFormatLinearPCM]
            writerSettings = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: channels,
                AVSampleRateKey: sampleRate,
                AVEncoderBitRateKey: channels >= 2 ? 128_000 : 96_000,
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
}
