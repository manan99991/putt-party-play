import UIKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import CoreTransferable

/// The video engine behind Video, Format Fixer and Share-Ready: trim, mute, extract audio, convert
/// to MP4, make a GIF, thumbnail — plus a background-task wrapper so a long export survives the
/// user switching apps (the #1 compressor-app complaint: "lost 20 minutes when I backgrounded it").
enum VideoEngine {

    // MARK: background-safe work

    /// Runs `work` under a UIKit background task so iOS keeps us alive for the few minutes an export needs.
    @MainActor private final class BGToken { var id: UIBackgroundTaskIdentifier = .invalid
        func end() { if id != .invalid { UIApplication.shared.endBackgroundTask(id); id = .invalid } } }

    @MainActor
    static func backgrounded<T>(_ name: String, _ work: () async -> T) async -> T {
        let token = BGToken()
        token.id = UIApplication.shared.beginBackgroundTask(withName: name) { token.end() }
        let result = await work()
        token.end()
        return result
    }

    static func tempURL(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy-\(UUID().uuidString.prefix(6)).\(ext)")
    }

    // MARK: info

    static func duration(_ url: URL) async -> Double { (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0 }

    static func thumbnail(_ url: URL, at seconds: Double = 0.5, maxDim: CGFloat = 640) async -> UIImage? {
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: maxDim, height: maxDim)
        guard let cg = try? gen.copyCGImage(at: CMTime(seconds: seconds, preferredTimescale: 600), actualTime: nil) else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: operations

    /// Re-wrap/re-encode as H.264/AAC MP4 (plays on Windows, Android, the web). Drops metadata.
    /// Robust by design — handles ANY source the device can decode and never hangs:
    ///   1. already H.264 → a fast passthrough re-wrap to .mp4 (no re-encode);
    ///   2. otherwise a bounded reader/writer transcode that decodes each frame (HEVC, HDR → SDR,
    ///      unusual codecs) and re-encodes H.264 — this is what AVAssetExportSession can't reliably do.
    /// Every path is time-bounded, so a wedged codec fails cleanly instead of freezing the UI.
    static func toMP4(_ src: URL, progress: ((Double) -> Void)? = nil) async -> URL? {
        let asset = AVURLAsset(url: src)
        if await isH264(asset), let fast = await export(asset, preset: AVAssetExportPresetPassthrough, type: .mp4, ext: "mp4") {
            progress?(1); return fast
        }
        return await transcodeH264(asset, progress: progress)
    }

    /// True when the first video track is already H.264 (so we can re-wrap instead of re-encoding).
    static func isH264(_ asset: AVAsset) async -> Bool {
        guard let t = try? await asset.loadTracks(withMediaType: .video).first,
              let desc = (try? await t.load(.formatDescriptions))?.first else { return false }
        return CMFormatDescriptionGetMediaSubType(desc) == kCMVideoCodecType_H264
    }

    /// Universal video → H.264/AAC MP4 transcode via AVAssetReader/Writer. Decodes to BGRA pixel
    /// buffers (so any playable source works, HDR included — flattened to SDR) and re-encodes H.264.
    /// ALWAYS returns: a hard timeout cancels the reader/writer and the continuation resumes on every
    /// path, so it can never hang the UI. `maxDimension` caps the longest side; `videoBps` sets the
    /// video bitrate (both derive sane defaults from the source when nil). `progress` is 0...1.
    static func transcodeH264(_ asset: AVAsset, maxDimension: CGFloat? = nil, videoBps: Int? = nil,
                              timeout: TimeInterval = 180, progress: ((Double) -> Void)? = nil) async -> URL? {
        guard let vTrack = try? await asset.loadTracks(withMediaType: .video).first else { return nil }
        let aTrack = try? await asset.loadTracks(withMediaType: .audio).first
        let natural = (try? await vTrack.load(.naturalSize)) ?? CGSize(width: 1280, height: 720)
        let transform = (try? await vTrack.load(.preferredTransform)) ?? .identity
        let durationSec = (try? await asset.load(.duration))?.seconds ?? 0

        let longest = max(natural.width, natural.height, 2)
        let scale = maxDimension.map { min(1, $0 / longest) } ?? 1
        let outW = max(2, Int(natural.width * scale / 2) * 2)
        let outH = max(2, Int(natural.height * scale / 2) * 2)
        // Default bitrate: ~pixels × fps heuristic, capped — good quality without being wasteful.
        let bps = videoBps ?? min(16_000_000, max(1_500_000, outW * outH * 4))

        let out = tempURL("mp4")
        guard let reader = try? AVAssetReader(asset: asset),
              let writer = try? AVAssetWriter(outputURL: out, fileType: .mp4) else { return nil }

        let vOut = AVAssetReaderTrackOutput(track: vTrack, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: outW,
            kCVPixelBufferHeightKey as String: outH,
        ])
        vOut.alwaysCopiesSampleData = false
        guard reader.canAdd(vOut) else { return nil }
        reader.add(vOut)

        let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: outW, AVVideoHeightKey: outH,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bps,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ])
        vIn.expectsMediaDataInRealTime = false
        vIn.transform = transform
        guard writer.canAdd(vIn) else { return nil }
        writer.add(vIn)

        var aOut: AVAssetReaderTrackOutput?
        var aIn: AVAssetWriterInput?
        if let aTrack {
            let o = AVAssetReaderTrackOutput(track: aTrack, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
            o.alwaysCopiesSampleData = false
            let i = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 2, AVSampleRateKey: 44_100, AVEncoderBitRateKey: 96_000,
            ])
            i.expectsMediaDataInRealTime = false
            if reader.canAdd(o), writer.canAdd(i) { reader.add(o); writer.add(i); aOut = o; aIn = i }
        }

        guard reader.startReading(), writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)

        let finished: Bool = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    let dg = DispatchGroup()
                    dg.enter()
                    vIn.requestMediaDataWhenReady(on: DispatchQueue(label: "tenzy.tc.v")) {
                        while vIn.isReadyForMoreMediaData {
                            // Leave on end-of-stream, a failed append, OR a reader/writer error — so the
                            // group always balances and the continuation always resumes (no dangling hang
                            // if an append pushes the writer into a not-ready failed state).
                            if writer.status == .failed || reader.status == .failed || reader.status == .cancelled {
                                vIn.markAsFinished(); dg.leave(); break
                            }
                            guard let s = vOut.copyNextSampleBuffer(), vIn.append(s) else {
                                vIn.markAsFinished(); dg.leave(); break
                            }
                        }
                    }
                    if let aIn, let aOut {
                        dg.enter()
                        aIn.requestMediaDataWhenReady(on: DispatchQueue(label: "tenzy.tc.a")) {
                            while aIn.isReadyForMoreMediaData {
                                if writer.status == .failed || reader.status == .failed || reader.status == .cancelled {
                                    aIn.markAsFinished(); dg.leave(); break
                                }
                                guard let s = aOut.copyNextSampleBuffer(), aIn.append(s) else {
                                    aIn.markAsFinished(); dg.leave(); break
                                }
                            }
                        }
                    }
                    dg.notify(queue: .global(qos: .userInitiated)) { writer.finishWriting { cont.resume() } }
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
        if finished { progress?(1); return out }
        try? FileManager.default.removeItem(at: out)
        return nil
    }

    /// Keep only [start, end].
    static func trim(_ src: URL, start: Double, end: Double) async -> URL? {
        let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), end: CMTime(seconds: end, preferredTimescale: 600))
        if let fast = await export(src, preset: AVAssetExportPresetPassthrough, type: .mp4, ext: "mp4", range: range) { return fast }
        return await export(src, preset: AVAssetExportPresetHighestQuality, type: .mp4, ext: "mp4", range: range)
    }

    /// Video only — strip every audio track.
    static func mute(_ src: URL) async -> URL? {
        let asset = AVURLAsset(url: src)
        guard let vTrack = try? await asset.loadTracks(withMediaType: .video).first else { return nil }
        let comp = AVMutableComposition()
        guard let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }
        let dur = (try? await asset.load(.duration)) ?? .zero
        try? cv.insertTimeRange(CMTimeRange(start: .zero, duration: dur), of: vTrack, at: .zero)
        cv.preferredTransform = (try? await vTrack.load(.preferredTransform)) ?? .identity
        return await export(comp, preset: AVAssetExportPresetHighestQuality, type: .mp4, ext: "mp4")
    }

    /// Audio only, as M4A (AAC). iOS has no built-in MP3 encoder; M4A plays everywhere.
    static func extractAudio(_ src: URL) async -> URL? {
        let asset = AVURLAsset(url: src)
        guard let tracks = try? await asset.loadTracks(withMediaType: .audio), !tracks.isEmpty else { return nil }
        return await export(asset, preset: AVAssetExportPresetAppleM4A, type: .m4a, ext: "m4a")
    }

    private static func export(_ asset: AVAsset, preset: String, type: AVFileType, ext: String, range: CMTimeRange? = nil) async -> URL? {
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else { return nil }
        let out = tempURL(ext)
        session.outputURL = out
        session.outputFileType = type
        session.shouldOptimizeForNetworkUse = true
        session.metadata = []
        if let range { session.timeRange = range }
        // Hard timeout: some device codecs can wedge an export (certain HDR / slow-mo / long clips), and
        // an unbounded await would hang the spinner forever. Race the export against a timer; whichever
        // finishes first wins, and on timeout we cancel the session so the tool fails cleanly (and the
        // caller surfaces an error) instead of freezing.
        let completed = await withTaskGroup(of: Bool.self) { group -> Bool in
            group.addTask { await session.export(); return session.status == .completed }
            group.addTask {
                try? await Task.sleep(nanoseconds: 180 * 1_000_000_000)   // 3 min ceiling
                session.cancelExport()
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
        return completed ? out : nil
    }
    private static func export(_ src: URL, preset: String, type: AVFileType, ext: String, range: CMTimeRange? = nil) async -> URL? {
        await export(AVURLAsset(url: src), preset: preset, type: type, ext: ext, range: range)
    }
}

// MARK: - GIF

/// Extract frames across a trim range and write them as a looping GIF.
func tenzyGIFFromVideo(url: URL, start: Double, duration: Double, fps: Double, speed: Double, maxDim: CGFloat) async -> URL? {
    let asset = AVURLAsset(url: url)
    let gen = AVAssetImageGenerator(asset: asset)
    gen.appliesPreferredTrackTransform = true
    gen.requestedTimeToleranceBefore = .zero
    gen.requestedTimeToleranceAfter = .zero
    gen.maximumSize = CGSize(width: maxDim, height: maxDim)
    let total = max(0.2, duration)
    let count = min(Int(total * fps), 72)
    guard count > 0 else { return nil }
    var frames: [CGImage] = []
    for i in 0..<count {
        let t = start + (Double(i) / Double(count)) * total
        if let cg = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) { frames.append(cg) }
    }
    guard !frames.isEmpty else { return nil }
    return tenzyWriteGIF(frames: frames, delay: (1.0 / fps) / speed)
}

/// Each photo becomes one frame.
func tenzyGIFFromImageData(_ datas: [Data], delay: Double, maxDim: CGFloat) -> URL? {
    var frames: [CGImage] = []
    for d in datas {
        guard let src = CGImageSourceCreateWithData(d as CFData, nil) else { continue }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: maxDim]
        if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) { frames.append(cg) }
    }
    guard !frames.isEmpty else { return nil }
    return tenzyWriteGIF(frames: frames, delay: delay)
}

private func tenzyWriteGIF(frames: [CGImage], delay: Double) -> URL? {
    let url = VideoEngine.tempURL("gif")
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else { return nil }
    CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]] as CFDictionary)
    let frameProps = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFUnclampedDelayTime as String: delay]] as CFDictionary
    for f in frames { CGImageDestinationAddImage(dest, f, frameProps) }
    return CGImageDestinationFinalize(dest) ? url : nil
}

/// Imports a picked video into a stable temp file we can read frames from.
struct MovieImport: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { SentTransferredFile($0.url) } importing: { received in
            let copy = VideoEngine.tempURL("mov")
            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return MovieImport(url: copy)
        }
    }
}
