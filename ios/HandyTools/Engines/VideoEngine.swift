import UIKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

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
    static func toMP4(_ src: URL, preset: String = AVAssetExportPresetHighestQuality) async -> URL? {
        await export(src, preset: preset, type: .mp4, ext: "mp4")
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
        await session.export()
        return session.status == .completed ? out : nil
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
