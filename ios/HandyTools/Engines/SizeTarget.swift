import UIKit
import ImageIO
import PDFKit
import AVFoundation
import UniformTypeIdentifiers

/// Hits an exact byte target. This exists because no OS lets you say "make this under 2 MB" —
/// you get all-or-nothing share-sheet compression, and an entire web of "compress-to-2MB" tools
/// grew up around that gap. One engine, three media types, shared by Fit It, Studio, Video, Scan
/// and Share-Ready. Everything runs on the phone.
enum SizeTarget {

    static let presets: [(label: String, bytes: Int)] = [
        ("10 MB", 10_000_000), ("5 MB", 5_000_000), ("2 MB", 2_000_000), ("1 MB", 1_000_000),
        ("500 KB", 500_000), ("200 KB", 200_000), ("50 KB", 50_000),
    ]

    static func format(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    // MARK: Image — binary-search JPEG quality, then step the resolution down if quality alone can't get there.

    static func image(_ img: UIImage, targetBytes: Int) -> Data? {
        var cur = img.normalizedUp()
        for _ in 0..<10 {
            if let d = bestJPEG(cur, under: targetBytes) { return d }
            let longest = max(cur.size.width, cur.size.height)
            if longest < 240 { break }
            cur = cur.resized(maxDimension: longest * 0.8)
        }
        return nil
    }

    private static func bestJPEG(_ img: UIImage, under limit: Int) -> Data? {
        var lo: CGFloat = 0.02, hi: CGFloat = 0.95
        var best: Data?
        for _ in 0..<9 {
            let q = (lo + hi) / 2
            guard let d = img.jpegData(compressionQuality: q) else { break }
            if d.count <= limit { best = d; lo = q } else { hi = q }
        }
        return best
    }

    // MARK: PDF — re-render pages at a descending (scale, quality) ladder until it fits. Output is flattened.

    static func pdf(_ data: Data, targetBytes: Int) -> Data? {
        if data.count <= targetBytes { return data }
        guard let doc = PDFDocument(data: data), doc.pageCount > 0 else { return nil }
        let ladder: [(CGFloat, CGFloat)] = [(2.0, 0.8), (1.6, 0.7), (1.3, 0.6), (1.0, 0.55), (0.8, 0.5), (0.65, 0.45), (0.5, 0.4), (0.4, 0.35)]
        for (scale, q) in ladder {
            if let out = rerender(doc, scale: scale, quality: q), out.count <= targetBytes { return out }
        }
        return nil
    }

    private static func rerender(_ doc: PDFDocument, scale: CGFloat, quality: CGFloat) -> Data? {
        guard let first = doc.page(at: 0) else { return nil }
        let renderer = UIGraphicsPDFRenderer(bounds: first.bounds(for: .mediaBox))
        return renderer.pdfData { ctx in
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                ctx.beginPage(withBounds: bounds, pageInfo: [:])
                let px = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
                let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
                let raster = UIGraphicsImageRenderer(size: px, format: fmt).image { c in
                    UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: px))
                    c.cgContext.saveGState()
                    c.cgContext.translateBy(x: 0, y: px.height)
                    c.cgContext.scaleBy(x: scale, y: -scale)
                    page.draw(with: .mediaBox, to: c.cgContext)
                    c.cgContext.restoreGState()
                }
                if let jd = raster.jpegData(compressionQuality: quality), let j = UIImage(data: jd) {
                    j.draw(in: bounds)
                } else {
                    raster.draw(in: bounds)
                }
            }
        }
    }

    // MARK: Video — derive a bitrate from the target and duration, transcode with AVAssetWriter, retry tighter if needed.

    static func video(url: URL, targetBytes: Int) async -> URL? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration).seconds, duration > 0 else { return nil }
        if let src = fileSize(url), src <= targetBytes { return url }
        let audioBps = 96_000
        var videoBps = max(120_000, Int(Double(targetBytes) * 8.0 / duration) - audioBps)
        for _ in 0..<4 {
            guard let out = await transcode(asset: asset, videoBps: videoBps, audioBps: audioBps) else { return nil }
            if let sz = fileSize(out), sz <= targetBytes { return out }
            try? FileManager.default.removeItem(at: out)
            videoBps = Int(Double(videoBps) * 0.78)
        }
        return nil
    }

    static func fileSize(_ url: URL) -> Int? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? nil
    }

    private static func transcode(asset: AVURLAsset, videoBps: Int, audioBps: Int) async -> URL? {
        guard let vTrack = try? await asset.loadTracks(withMediaType: .video).first else { return nil }
        let aTrack = try? await asset.loadTracks(withMediaType: .audio).first
        let natural = (try? await vTrack.load(.naturalSize)) ?? CGSize(width: 1280, height: 720)
        let transform = (try? await vTrack.load(.preferredTransform)) ?? .identity

        // Lower bitrates get a smaller frame too — bitrate alone can't save a 4K frame at 300 kbps.
        let scale: CGFloat = videoBps < 1_200_000 ? 0.5 : (videoBps < 3_000_000 ? 0.75 : 1.0)
        let outW = max(2, Int(natural.width * scale / 2) * 2)
        let outH = max(2, Int(natural.height * scale / 2) * 2)

        let out = FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy-fit-\(UUID().uuidString.prefix(6)).mp4")
        guard let reader = try? AVAssetReader(asset: asset), let writer = try? AVAssetWriter(outputURL: out, fileType: .mp4) else { return nil }

        // Ask the decoder for already-scaled frames so writer dimensions match exactly.
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
                AVVideoAverageBitRateKey: videoBps,
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
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 2, AVSampleRateKey: 44_100, AVEncoderBitRateKey: audioBps,
            ])
            i.expectsMediaDataInRealTime = false
            if reader.canAdd(o), writer.canAdd(i) { reader.add(o); writer.add(i); aOut = o; aIn = i }
        }

        guard reader.startReading(), writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let group = DispatchGroup()
            group.enter()
            vIn.requestMediaDataWhenReady(on: DispatchQueue(label: "tenzy.fit.video")) {
                while vIn.isReadyForMoreMediaData {
                    if let s = vOut.copyNextSampleBuffer() { vIn.append(s) }
                    else { vIn.markAsFinished(); group.leave(); break }
                }
            }
            if let aIn, let aOut {
                group.enter()
                aIn.requestMediaDataWhenReady(on: DispatchQueue(label: "tenzy.fit.audio")) {
                    while aIn.isReadyForMoreMediaData {
                        if let s = aOut.copyNextSampleBuffer() { aIn.append(s) }
                        else { aIn.markAsFinished(); group.leave(); break }
                    }
                }
            }
            group.notify(queue: .global(qos: .userInitiated)) {
                writer.finishWriting { cont.resume() }
            }
        }
        return writer.status == .completed ? out : nil
    }
}
