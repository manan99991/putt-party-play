import AVFoundation
import UIKit

/// The motion engine behind the creative tools: turns a set of still frames into a real MP4, and renders the
/// moving pieces (the before/after swipe-reveal; flipbooks and the other photo animations live in Animate). Drawn on the
/// phone and encoded with the phone's own H.264 encoder — nothing leaves the device.
enum ChainMotion {

    // MARK: - Frames → MP4

    /// Encode a list of frames into an MP4 at `fps`. `size` must have even width/height (H.264 needs it).
    static func framesToMP4(_ frames: [CGImage], fps: Double, size: CGSize) async -> URL? {
        guard !frames.isEmpty, size.width >= 2, size.height >= 2 else { return nil }
        let url = VideoEngine.tempURL("mp4")
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
        guard writer.canAdd(input) else { return nil }
        writer.add(input)
        guard writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)
        let ts = Int32(max(1, fps.rounded()))
        for (i, frame) in frames.enumerated() {
            while !input.isReadyForMoreMediaData { try? await Task.sleep(nanoseconds: 5_000_000) }
            guard let buffer = pixelBuffer(from: frame, size: size, pool: adaptor.pixelBufferPool) else { continue }
            adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(i), timescale: ts))
        }
        input.markAsFinished()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            writer.finishWriting { cont.resume() }
        }
        return writer.status == .completed ? url : nil
    }

    private static func pixelBuffer(from image: CGImage, size: CGSize, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        let status: CVReturn
        if let pool {
            status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
        } else {
            let attrs: [String: Any] = [
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ]
            status = CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, attrs as CFDictionary, &pb)
        }
        guard status == kCVReturnSuccess, let buffer = pb else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                  width: Int(size.width), height: Int(size.height),
                                  bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(origin: .zero, size: size))
        return buffer
    }

    // MARK: - Before / after swipe-reveal

    /// A short video that wipes from the "before" photo to the "after" with a sweeping divider, then back —
    /// the format people actually post transformations in. nil if the phone can't encode it.
    static func revealVideo(before: UIImage, after: UIImage, longEdge: CGFloat = 1080, style: String = "swipe") async -> Data? {
        let size = style == "side" ? fitSize(CGSize(width: before.size.width * 2, height: before.size.height), long: longEdge) : fitSize(before.size, long: longEdge)
        let b = before.normalizedUp(), a = after.normalizedUp()
        let frames = style == "fade" ? fadeFrames(b, a, size: size, steps: 24) : style == "side" ? sideFrames(b, a, size: size) : revealFrames(b, a, size: size, steps: 24)
        guard let url = await framesToMP4(frames, fps: 30, size: size) else { return nil }
        let d = try? Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        return d
    }

    /// Before dissolves into after and back, holding on each.
    private static func fadeFrames(_ before: UIImage, _ after: UIImage, size: CGSize, steps: Int) -> [CGImage] {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: fmt)
        func frame(_ p: CGFloat) -> CGImage? {
            renderer.image { _ in
                drawAspectFill(before, in: size)
                if p > 0 { drawAspectFill(after, in: size, alpha: p) }
                label(p < 0.5 ? "BEFORE" : "AFTER", at: CGPoint(x: size.width / 2, y: size.height * 0.92), size: size)
            }.cgImage
        }
        var out: [CGImage] = []
        for _ in 0..<12 { if let f = frame(0) { out.append(f) } }
        for i in 0...steps { if let f = frame(eased(CGFloat(i) / CGFloat(steps))) { out.append(f) } }
        for _ in 0..<12 { if let f = frame(1) { out.append(f) } }
        for i in stride(from: steps, through: 0, by: -1) { if let f = frame(eased(CGFloat(i) / CGFloat(steps))) { out.append(f) } }
        return out
    }

    /// The two side by side, labelled, with a slow push in so it plays as a video.
    private static func sideFrames(_ before: UIImage, _ after: UIImage, size: CGSize) -> [CGImage] {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: fmt)
        let half = CGSize(width: size.width / 2, height: size.height)
        return (0..<90).compactMap { i in
            let z = 1 + 0.05 * eased(CGFloat(i) / 89)
            return renderer.image { ctx in
                for (n, img) in [before, after].enumerated() {
                    let cell = CGRect(x: CGFloat(n) * half.width, y: 0, width: half.width, height: half.height)
                    ctx.cgContext.saveGState(); ctx.cgContext.clip(to: cell)
                    ctx.cgContext.translateBy(x: cell.midX, y: cell.midY); ctx.cgContext.scaleBy(x: z, y: z)
                    ctx.cgContext.translateBy(x: -half.width / 2, y: -half.height / 2)
                    drawAspectFill(img, in: half)
                    ctx.cgContext.restoreGState()
                    label(n == 0 ? "BEFORE" : "AFTER", at: CGPoint(x: cell.midX, y: size.height * 0.92), size: size)
                }
                UIColor.white.setFill(); ctx.cgContext.fill(CGRect(x: half.width - 2, y: 0, width: 4, height: size.height))
            }.cgImage
        }
    }

    /// A small rounded tag ("BEFORE" / "AFTER") centred on `at`.
    private static func label(_ text: String, at: CGPoint, size: CGSize) {
        let font = UIFont.systemFont(ofSize: max(14, min(size.width, size.height) * 0.04), weight: .heavy)
        let s = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: UIColor.white, .kern: 1.5])
        let t = s.size(), pad = font.pointSize * 0.5
        let box = CGRect(x: at.x - t.width / 2 - pad, y: at.y - t.height / 2 - pad * 0.5, width: t.width + 2 * pad, height: t.height + pad)
        UIColor.black.withAlphaComponent(0.55).setFill()
        UIBezierPath(roundedRect: box, cornerRadius: box.height / 2).fill()
        s.draw(at: CGPoint(x: box.minX + pad, y: box.minY + pad * 0.5))
    }

    private static func revealFrames(_ before: UIImage, _ after: UIImage, size: CGSize, steps: Int) -> [CGImage] {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: fmt)
        func frame(_ p: CGFloat) -> CGImage? {
            renderer.image { ctx in
                drawAspectFill(before, in: size)
                let x = size.width * p
                ctx.cgContext.saveGState()
                ctx.cgContext.clip(to: CGRect(x: 0, y: 0, width: x, height: size.height))
                drawAspectFill(after, in: size)
                ctx.cgContext.restoreGState()
                if x > 1, x < size.width - 1 {
                    UIColor.white.setFill()
                    ctx.cgContext.fill(CGRect(x: x - 1.5, y: 0, width: 3, height: size.height))
                }
            }.cgImage
        }
        var out: [CGImage] = []
        let hold = 8
        for _ in 0..<hold { if let f = frame(0) { out.append(f) } }
        for i in 0...steps { if let f = frame(eased(CGFloat(i) / CGFloat(steps))) { out.append(f) } }
        for _ in 0..<hold { if let f = frame(1) { out.append(f) } }
        for i in stride(from: steps, through: 0, by: -1) { if let f = frame(eased(CGFloat(i) / CGFloat(steps))) { out.append(f) } }
        return out
    }

    // MARK: - Helpers

    /// Smooth ease-in-out so the sweep starts and stops gently instead of at a constant speed.
    private static func eased(_ t: CGFloat) -> CGFloat { t * t * (3 - 2 * t) }

    /// Draw an image to fill `rect` (centre-cropped), using the current UIKit graphics context.
    private static func drawAspectFill(_ img: UIImage, in size: CGSize, alpha: CGFloat = 1) {
        guard img.size.width > 0, img.size.height > 0 else { return }
        let s = max(size.width / img.size.width, size.height / img.size.height)
        let w = img.size.width * s, h = img.size.height * s
        img.draw(in: CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h), blendMode: .normal, alpha: alpha)
    }

    /// Scale a size so its long edge is `long`, with even width/height for the encoder.
    private static func fitSize(_ s: CGSize, long: CGFloat) -> CGSize {
        guard s.width > 0, s.height > 0 else { return CGSize(width: long, height: long) }
        let k = long / max(s.width, s.height)
        let w = Int((s.width * k).rounded()), h = Int((s.height * k).rounded())
        return CGSize(width: max(2, w - w % 2), height: max(2, h - h % 2))
    }
}
