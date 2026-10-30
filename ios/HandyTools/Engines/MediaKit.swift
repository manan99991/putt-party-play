import SwiftUI
import UIKit
import CoreImage
import ImageIO
import Photos
import AVFoundation
import UniformTypeIdentifiers

/// Small helpers the Media Studio hub needs on top of ImageStudio / SizeTarget / VideoEngine /
/// Scrubber: a blurred-background composite, source-format sniffing, video metadata, and a direct
/// "Save to Photos". All on-device.
enum MediaKit {

    /// Subject (alpha cut-out) laid over a softly blurred copy of the original — the "portrait" look.
    static func blurBackground(subject: UIImage, original: UIImage) -> UIImage {
        let base = original.normalizedUp()
        let size = CGSize(width: base.size.width * base.scale, height: base.size.height * base.scale)
        var backdrop = base
        if let cg = base.cgImage {
            let ci = CIImage(cgImage: cg)
            let radius = max(8.0, Double(max(size.width, size.height)) / 60.0)
            let blurred = ci.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius]).cropped(to: ci.extent)
            if let out = CIContext().createCGImage(blurred, from: ci.extent) { backdrop = UIImage(cgImage: out) }
        }
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            backdrop.draw(in: CGRect(origin: .zero, size: size))
            subject.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// "HEIC" / "PNG" / "JPG" / "GIF" / "Image" from the picked bytes.
    static func format(of data: Data) -> String {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil), let uti = CGImageSourceGetType(src) as String? else { return "Image" }
        let u = uti.lowercased()
        if u.contains("heic") || u.contains("heif") { return "HEIC" }
        if u.contains("png") { return "PNG" }
        if u.contains("jpeg") || u.contains("jpg") { return "JPG" }
        if u.contains("gif") { return "GIF" }
        if u.contains("tiff") { return "TIFF" }
        if u.contains("webp") { return "WebP" }
        return "Image"
    }

    static func dims(_ img: UIImage) -> String {
        "\(Int(img.size.width * img.scale))×\(Int(img.size.height * img.scale))"
    }

    /// Frame size of a video as "W×H" (orientation applied), or nil if unreadable.
    static func videoDims(_ url: URL) async -> String? {
        let asset = AVURLAsset(url: url)
        guard let t = try? await asset.loadTracks(withMediaType: .video).first,
              let n = try? await t.load(.naturalSize) else { return nil }
        let tf = (try? await t.load(.preferredTransform)) ?? .identity
        let r = CGRect(origin: .zero, size: n).applying(tf)
        return "\(Int(abs(r.width)))×\(Int(abs(r.height)))"
    }

    /// What a video quietly carries (location, device, date) — read from its common metadata.
    static func videoMetadata(_ url: URL) async -> Scrubber.Metadata {
        var m = Scrubber.Metadata()
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.metadata) else { return m }
        for item in items {
            guard let key = item.commonKey else { continue }
            let value = (try? await item.load(.stringValue)) ?? nil
            switch key {
            case .commonKeyLocation: m.hasGPS = true
            case .commonKeyCreationDate: if let value, m.taken == nil { m.taken = value }
            case .commonKeyModel, .commonKeyMake, .commonKeySoftware: if let value, m.device == nil { m.device = value }
            default: break
            }
        }
        return m
    }

    // MARK: save to Photos

    static func saveImage(_ data: Data) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            return true
        } catch { return false }
    }

    static func saveVideo(_ url: URL) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
            }
            return true
        } catch { return false }
    }
}

// MARK: - Redaction canvas

/// One black-out box in normalized (0…1, top-left origin) image coordinates.
struct RedactBox: Identifiable {
    enum Kind { case face, text, manual }
    let id = UUID()
    let rect: CGRect
    let kind: Kind
    var on: Bool
}

/// The photo with its redaction boxes drawn on top. Drag to add a box, tap a box to toggle it.
/// Same geometry as the Privacy Scrubber canvas, lifted out so the hub can draw on its shared preview.
struct RedactCanvas: View {
    let image: UIImage
    @Binding var boxes: [RedactBox]
    var busy = false
    @State private var drawing: CGRect?

    var body: some View {
        GeometryReader { geo in
            let fit = fitRect(image: image.size, in: geo.size)
            ZStack(alignment: .topLeading) {
                Image(uiImage: image).resizable().scaledToFit().frame(width: geo.size.width, height: geo.size.height)
                ForEach(boxes) { b in
                    let r = denorm(b.rect, fit)
                    Rectangle()
                        .fill(b.on ? Color.black.opacity(0.88) : Color.clear)
                        .overlay(Rectangle().stroke(b.on ? HandyColor.accent : HandyColor.textSecondary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: b.on ? [] : [4, 3])))
                        .frame(width: max(2, r.width), height: max(2, r.height))
                        .offset(x: r.minX, y: r.minY)
                        .onTapGesture { toggle(b.id) }
                }
                if let d = drawing {
                    let r = denorm(d, fit)
                    Rectangle().fill(Color.black.opacity(0.5)).overlay(Rectangle().stroke(HandyColor.accent, lineWidth: 1.5))
                        .frame(width: max(2, r.width), height: max(2, r.height)).offset(x: r.minX, y: r.minY)
                }
                if busy { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 6)
                .onChanged { v in drawing = normRect(from: v.startLocation, to: v.location, fit) }
                .onEnded { v in
                    let r = normRect(from: v.startLocation, to: v.location, fit)
                    if r.width > 0.01 && r.height > 0.01 { boxes.append(RedactBox(rect: r, kind: .manual, on: true)); HandyHaptics.light() }
                    drawing = nil
                })
        }
    }

    private func toggle(_ id: UUID) { if let i = boxes.firstIndex(where: { $0.id == id }) { boxes[i].on.toggle(); HandyHaptics.light() } }
    private func fitRect(image: CGSize, in c: CGSize) -> CGRect {
        let s = min(c.width / max(1, image.width), c.height / max(1, image.height))
        let w = image.width * s, h = image.height * s
        return CGRect(x: (c.width - w) / 2, y: (c.height - h) / 2, width: w, height: h)
    }
    private func denorm(_ r: CGRect, _ fit: CGRect) -> CGRect {
        CGRect(x: fit.minX + r.minX * fit.width, y: fit.minY + r.minY * fit.height, width: r.width * fit.width, height: r.height * fit.height)
    }
    private func normRect(from a: CGPoint, to b: CGPoint, _ fit: CGRect) -> CGRect {
        func n(_ p: CGPoint) -> CGPoint { CGPoint(x: min(max((p.x - fit.minX) / max(1, fit.width), 0), 1), y: min(max((p.y - fit.minY) / max(1, fit.height), 0), 1)) }
        let p = n(a), q = n(b)
        return CGRect(x: min(p.x, q.x), y: min(p.y, q.y), width: abs(p.x - q.x), height: abs(p.y - q.y))
    }
}
