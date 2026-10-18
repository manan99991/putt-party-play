import SwiftUI
import PhotosUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import UniformTypeIdentifiers

/// Lifts the subject off the background in one tap — product shots, a clean headshot, a cut-out for
/// a sticker. Runs on the phone with Apple's Vision models; no upload, no watermark.
struct BackgroundRemoverView: View {
    @EnvironmentObject var store: StoreManager
    @State private var pickedItem: PhotosPickerItem?
    @State private var original: UIImage?
    @State private var result: UIImage?
    @State private var working = false
    @State private var errorText: String?
    private var overQuota: Bool { !Usage.hasRoom("bgremove", limit: Limits.freeBgRemovePerDay) }

    var body: some View {
        ToolPage(title: "Background Remover", subtitle: "Cut the subject out cleanly — on your phone, no watermark.") {
            PhotosPicker(selection: $pickedItem, matching: .images) {
                Label(original == nil ? "Pick a photo" : "Pick a different photo", systemImage: "person.crop.rectangle").frame(maxWidth: .infinity)
            }
            .compactButton()
            .onChange(of: pickedItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                        original = img; result = nil; errorText = nil
                    }
                }
            }

            if let show = result ?? original {
                ZStack {
                    if result != nil { CheckerboardBG() }
                    Image(uiImage: show).resizable().scaledToFit()
                }
                .frame(maxHeight: 260).clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            }

            if original != nil && result == nil {
                if !store.isPremium { QuotaChip(name: "bgremove", limit: Limits.freeBgRemovePerDay).environmentObject(store) }
                if overQuota { LimitReachedBanner(message: "You've removed today's \(Limits.freeBgRemovePerDay) free backgrounds.") }
                Button { remove() } label: {
                    HStack { if working { ProgressView().tint(.white) }; Text(working ? "Removing…" : "Remove background") }.frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || overQuota)
            }

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            if let result, let png = result.pngData() {
                ShareLink(item: PNGFile(data: png), preview: SharePreview("Cutout")) {
                    Label("Save or share (PNG)", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }.primaryButton()
            }
        }
    }

    private func remove() {
        guard let src = original, let cg = src.normalizedUp().cgImage else { return }
        guard Usage.use("bgremove", limit: Limits.freeBgRemovePerDay) else { return }
        working = true; errorText = nil
        Task { @MainActor in
            let out = Self.cutout(cg)
            working = false
            if let out { result = out; HandyHaptics.success() }
            else { errorText = "Couldn't find a clear subject in that photo. Try one with a distinct foreground." }
        }
    }

    /// Vision foreground-instance mask, applied as an alpha matte.
    private static func cutout(_ cg: CGImage) -> UIImage? {
        let handler = VNImageRequestHandler(cgImage: cg)
        let request = VNGenerateForegroundInstanceMaskRequest()
        guard (try? handler.perform([request])) != nil, let res = request.results?.first else { return nil }
        guard let masked = try? res.generateMaskedImage(ofInstances: res.allInstances, from: handler, croppedToInstancesExtent: false) else { return nil }
        let ci = CIImage(cvPixelBuffer: masked)
        let ctx = CIContext()
        guard let outCG = ctx.createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: outCG)
    }
}

/// A transparent-background checkerboard so a cut-out reads as "no background".
private struct CheckerboardBG: View {
    var body: some View {
        GeometryReader { geo in
            let s: CGFloat = 12
            Path { p in
                let cols = Int(geo.size.width / s) + 1, rows = Int(geo.size.height / s) + 1
                for r in 0..<rows { for c in 0..<cols where (r + c) % 2 == 0 {
                    p.addRect(CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s, height: s))
                } }
            }.fill(HandyColor.border.opacity(0.35))
        }
    }
}

/// Lets ShareLink hand off raw PNG data as a real file.
struct PNGFile: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
    }
}
