import SwiftUI
import PhotosUI
import Vision
import CoreImage
import UIKit
import UniformTypeIdentifiers

/// ID / Passport Photo — turn a normal portrait into a compliant ID photo: crop to a country's
/// spec with the face sized and centred the way officials expect, drop in a clean studio
/// background, and lay out a 4×6 print sheet. All on the phone.
struct IDPhotoView: View {
    @EnvironmentObject var store: StoreManager

    struct Spec: Identifiable, Hashable { let id: String; let name: String; let px: CGSize }
    private let specs: [Spec] = [
        Spec(id: "us",   name: "US 2×2 in",        px: CGSize(width: 600, height: 600)),
        Spec(id: "eu",   name: "EU / Schengen 35×45", px: CGSize(width: 413, height: 531)),
        Spec(id: "uk",   name: "UK 35×45 mm",      px: CGSize(width: 413, height: 531)),
        Spec(id: "in",   name: "India 35×45 mm",   px: CGSize(width: 413, height: 531)),
        Spec(id: "ca",   name: "Canada 50×70 mm",  px: CGSize(width: 591, height: 827)),
    ]
    private let bgColors: [(String, Color)] = [
        ("White", .white),
        ("Off-white", Color(hex: 0xF4F4F2)),
        ("Light grey", Color(hex: 0xDDDDDD)),
        ("Light blue", Color(hex: 0xD6E4F2)),
    ]

    @State private var pickedItem: PhotosPickerItem?
    @State private var original: UIImage?
    @State private var result: UIImage?
    @State private var specIdx = 0
    @State private var bgIdx = 0
    @State private var replaceBG = true
    @State private var working = false
    @State private var errorText: String?
    @State private var sheet: URL?

    private var overQuota: Bool { !Usage.hasRoom("idphoto", limit: Limits.freeIdPhotoPerDay) }

    var body: some View {
        ToolPage(title: "ID / Passport Photo", subtitle: "A compliant ID photo from a normal portrait — sized, centred, clean background.") {
            if original == nil {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("Choose a portrait", systemImage: "person.crop.square").frame(maxWidth: .infinity)
                }.secondaryButton()
                Text("Face the camera, even lighting, plain-ish wall. We'll handle the rest.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }

            if let show = result ?? original {
                Image(uiImage: show).resizable().scaledToFit().frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            }

            if original != nil {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("Choose a different photo", systemImage: "photo.on.rectangle.angled")
                }.textButton()

                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text("Size").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Picker("Size", selection: $specIdx) { ForEach(0..<specs.count, id: \.self) { Text(specs[$0].name).tag($0) } }
                        .pickerStyle(.menu).tint(HandyColor.accent).frame(maxWidth: .infinity, alignment: .leading)
                }

                Toggle(isOn: $replaceBG) {
                    Text("Clean studio background").font(HandyFont.body)
                }.tint(HandyColor.accent)

                if replaceBG {
                    HStack(spacing: HandySpacing.s8) {
                        ForEach(0..<bgColors.count, id: \.self) { i in
                            Button { bgIdx = i } label: {
                                Circle().fill(bgColors[i].1).frame(width: 30, height: 30)
                                    .overlay(Circle().stroke(bgIdx == i ? HandyColor.accent : HandyColor.border, lineWidth: bgIdx == i ? 2.5 : 1))
                            }.accessibilityLabel(bgColors[i].0)
                        }
                        Spacer()
                    }
                }

                if !store.isPremium { QuotaChip(name: "idphoto", limit: Limits.freeIdPhotoPerDay).environmentObject(store) }
                if overQuota { LimitReachedBanner(message: "You've made today's \(Limits.freeIdPhotoPerDay) free ID photos.") }

                Button { make() } label: {
                    HStack { if working { ProgressView().tint(.white) }; Text(working ? "Preparing…" : "Make ID photo") }.frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || overQuota)
            }

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            if let result, let jpg = result.jpegData(compressionQuality: 0.95) {
                ShareLink(item: JPEGFile(data: jpg), preview: SharePreview("ID photo")) {
                    Label("Save the photo", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }.primaryButton()
                Button { makeSheet() } label: {
                    Label("Make a 4×6 print sheet", systemImage: "squareshape.split.3x3").frame(maxWidth: .infinity)
                }.secondaryButton()
                if let sheet {
                    ShareLink(item: sheet) { Label("Save the print sheet", systemImage: "printer").frame(maxWidth: .infinity) }.primaryButton()
                }
            }
        }
        .onChange(of: pickedItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    original = img.normalizedUp(); result = nil; sheet = nil; errorText = nil
                }
            }
        }
    }

    private func make() {
        guard let src = original else { return }
        guard Usage.use("idphoto", limit: Limits.freeIdPhotoPerDay) else { return }
        working = true; errorText = nil; sheet = nil
        let spec = specs[specIdx], color = UIColor(bgColors[bgIdx].1), replace = replaceBG
        Task { @MainActor in
            let out = Self.render(src, spec: spec, bg: replace ? color : nil)
            working = false
            if let out { result = out; HandyHaptics.success() }
            else { errorText = "Couldn't find a clear face. Try a straight-on portrait with the whole head visible." }
        }
    }

    private func makeSheet() {
        guard let photo = result else { return }
        sheet = Self.printSheet(photo)
        if sheet != nil { HandyHaptics.success() }
    }

    // MARK: pipeline

    /// Optionally replace the background with a flat colour, then crop to the spec with the face
    /// sized to ~62% head height and positioned a touch above centre — the usual ID layout.
    private static func render(_ image: UIImage, spec: Spec, bg: UIColor?) -> UIImage? {
        guard let baseCG = image.cgImage else { return nil }

        // 1. Background replacement (studio look). Falls back to the original on failure.
        var working = image
        if let bg, let composited = replaceBackground(baseCG, color: bg) { working = composited }
        guard let cg = working.cgImage else { return nil }
        let W = CGFloat(cg.width), H = CGFloat(cg.height)

        // 2. Find the largest face.
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        let faceReq = VNDetectFaceRectanglesRequest()
        try? handler.perform([faceReq])
        guard let face = (faceReq.results)?.max(by: { $0.boundingBox.height < $1.boundingBox.height }) else { return nil }

        // Vision box is normalized, origin bottom-left → pixel rect, origin top-left.
        let fb = face.boundingBox
        let faceRect = CGRect(x: fb.minX * W, y: (1 - fb.maxY) * H, width: fb.width * W, height: fb.height * H)

        // 3. Compute a crop of the spec aspect, face ~62% head height, face centre at ~46% from top.
        let aspect = spec.px.width / spec.px.height
        let headH = faceRect.height * 1.5          // forehead + chin beyond the detected box
        var cropH = headH / 0.62
        var cropW = cropH * aspect
        if cropW > W { cropW = W; cropH = cropW / aspect }
        if cropH > H { cropH = H; cropW = cropH * aspect }
        var originX = faceRect.midX - cropW / 2
        var originY = faceRect.midY - cropH * 0.46
        originX = min(max(0, originX), W - cropW)
        originY = min(max(0, originY), H - cropH)
        let cropRect = CGRect(x: originX, y: originY, width: cropW, height: cropH).integral
        guard let cropped = cg.cropping(to: cropRect) else { return nil }

        // 4. Resize to the exact output pixels.
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: spec.px, format: fmt).image { _ in
            UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: spec.px))
        }
    }

    /// Cut the subject out (Vision foreground mask) and lay it over a flat colour.
    private static func replaceBackground(_ cg: CGImage, color: UIColor) -> UIImage? {
        let handler = VNImageRequestHandler(cgImage: cg)
        let req = VNGenerateForegroundInstanceMaskRequest()
        guard (try? handler.perform([req])) != nil, let res = req.results?.first,
              let masked = try? res.generateMaskedImage(ofInstances: res.allInstances, from: handler, croppedToInstancesExtent: false) else { return nil }
        let ci = CIImage(cvPixelBuffer: masked)
        let ctx = CIContext()
        guard let subjectCG = ctx.createCGImage(ci, from: ci.extent) else { return nil }
        let size = CGSize(width: cg.width, height: cg.height)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { c in
            color.setFill(); c.fill(CGRect(origin: .zero, size: size))
            UIImage(cgImage: subjectCG).draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Tile the finished photo across a 4×6 sheet at 300 dpi with light cut guides.
    private static func printSheet(_ photo: UIImage) -> URL? {
        let sheet = CGSize(width: 1200, height: 1800)   // 4×6 in @ 300 dpi
        let gap: CGFloat = 24, margin: CGFloat = 36
        let pw = photo.size.width, ph = photo.size.height
        let cols = max(1, Int((sheet.width - 2 * margin + gap) / (pw + gap)))
        let rows = max(1, Int((sheet.height - 2 * margin + gap) / (ph + gap)))
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        let img = UIGraphicsImageRenderer(size: sheet, format: fmt).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: sheet))
            let gridW = CGFloat(cols) * pw + CGFloat(cols - 1) * gap
            let gridH = CGFloat(rows) * ph + CGFloat(rows - 1) * gap
            let startX = (sheet.width - gridW) / 2, startY = (sheet.height - gridH) / 2
            UIColor(white: 0.8, alpha: 1).setStroke()
            for r in 0..<rows { for col in 0..<cols {
                let x = startX + CGFloat(col) * (pw + gap)
                let y = startY + CGFloat(r) * (ph + gap)
                let rect = CGRect(x: x, y: y, width: pw, height: ph)
                photo.draw(in: rect)
                let guide = UIBezierPath(rect: rect.insetBy(dx: -0.5, dy: -0.5)); guide.lineWidth = 1; guide.stroke()
            } }
        }
        guard let data = img.jpegData(compressionQuality: 0.95) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy-IDsheet-\(UUID().uuidString.prefix(4)).jpg")
        try? data.write(to: url)
        return url
    }
}

/// Lets ShareLink hand off raw JPEG data as a real file.
struct JPEGFile: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { $0.data }
    }
}
