import SwiftUI
import AVKit
import AVFoundation
import UIKit

/// Shared result preview for any tool that hands back a file. A produced result should always be
/// SHOWN, not just described ("Fits — 869 KB" with no picture) — photos/PDFs show a thumbnail and
/// videos play back inline. Reused across tools so the invariant holds everywhere.
struct ResultPreview: View {
    enum Kind { case image(UIImage), imageData(Data), pdfData(Data), videoURL(URL) }
    let kind: Kind
    var maxHeight: CGFloat = 200

    @State private var thumb: UIImage?
    @State private var playing = false

    private var isVideo: Bool { if case .videoURL = kind { return true }; return false }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).fill(HandyColor.surface)
            if let thumb {
                Image(uiImage: thumb).resizable().scaledToFit()
                    .frame(maxHeight: maxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            } else {
                Image(systemName: isVideo ? "film" : "doc.fill").font(.system(size: 28)).foregroundStyle(HandyColor.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
            if isVideo {
                Image(systemName: "play.circle.fill").font(.system(size: 40)).foregroundStyle(.white.opacity(0.95)).shadow(radius: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: maxHeight)
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { if isVideo { playing = true } }
        .task(id: taskKey) { thumb = await Self.makeThumb(kind) }
        .sheet(isPresented: $playing) { if case .videoURL(let url) = kind { MediaPlayerSheet(url: url) } }
    }

    private var taskKey: String {
        switch kind {
        case .image: return "img-mem"
        case .imageData(let d): return "imgdata-\(d.count)"
        case .pdfData(let d): return "pdf-\(d.count)"
        case .videoURL(let u): return "vid-\(u.path)"
        }
    }

    private static func makeThumb(_ kind: Kind) async -> UIImage? {
        switch kind {
        case .image(let img):
            return img.resized(maxDimension: 600)
        case .imageData(let d):
            return await Task.detached { UIImage(data: d)?.resized(maxDimension: 600) }.value
        case .pdfData(let d):
            return await Task.detached { () -> UIImage? in
                guard let provider = CGDataProvider(data: d as CFData), let doc = CGPDFDocument(provider),
                      let page = doc.page(at: 1) else { return nil }
                let rect = page.getBoxRect(.mediaBox)
                guard rect.width > 0, rect.height > 0 else { return nil }
                let scale = 600 / max(rect.width, rect.height)
                let size = CGSize(width: rect.width * scale, height: rect.height * scale)
                let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
                return UIGraphicsImageRenderer(size: size, format: fmt).image { c in
                    UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
                    c.cgContext.translateBy(x: 0, y: size.height); c.cgContext.scaleBy(x: scale, y: -scale)
                    c.cgContext.drawPDFPage(page)
                }
            }.value
        case .videoURL(let url):
            return await Task.detached { () -> UIImage? in
                let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                gen.appliesPreferredTrackTransform = true
                gen.maximumSize = CGSize(width: 800, height: 800)
                guard let cg = try? gen.copyCGImage(at: CMTime(seconds: 0.1, preferredTimescale: 600), actualTime: nil) else { return nil }
                return UIImage(cgImage: cg)
            }.value
        }
    }
}

/// A plain player sheet that autoplays a clip so the user can check a result before saving/sharing.
struct MediaPlayerSheet: View {
    let url: URL
    @State private var player = AVPlayer()
    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea()
            .onAppear { player.replaceCurrentItem(with: AVPlayerItem(url: url)); player.play() }
            .onDisappear { player.pause() }
    }
}
