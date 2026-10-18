import SwiftUI
import PhotosUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Photo Studio — the photo jobs that are genuinely hard to do on a stock iPhone, in one tool:
///   • Straighten — flatten a skewed photo of a document, whiteboard or artwork
///   • Redact — auto-find faces and text, blur them before you share
///   • Color pop — keep the subject in colour, the background black & white
///   • Cleanup — paint over a small object or blemish to make it disappear
/// Everything runs on the phone.
struct PhotoStudioView: View {
    @EnvironmentObject var store: StoreManager
    private let ctx = CIContext()

    @State private var mode = 0
    @State private var pickedItem: PhotosPickerItem?
    @State private var original: UIImage?
    @State private var result: UIImage?
    @State private var working = false
    @State private var errorText: String?

    // Redact options
    @State private var blurFaces = true
    @State private var blurText = true
    // Cleanup strokes (normalized to the image's fitted rect)
    @State private var strokes: [[CGPoint]] = []
    @State private var brush: Double = 26
    @State private var lastStart = CGPoint(x: -1, y: -1)

    private let modes = ["Straighten", "Redact", "Color pop", "Cleanup"]
    private var overQuota: Bool { !Usage.hasRoom("photostudio", limit: Limits.freePhotoStudioPerDay) }

    var body: some View {
        ToolPage(title: "Photo Studio", subtitle: "Straighten, redact, colour-pop or clean up — the photo jobs iOS makes hard.") {
            if original == nil {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("Choose a photo", systemImage: "photo").frame(maxWidth: .infinity)
                }.secondaryButton()
            }

            if original != nil {
                Picker("Mode", selection: $mode) { ForEach(0..<modes.count, id: \.self) { Text(modes[$0]).tag($0) } }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _, _ in result = nil; errorText = nil; strokes = [] }

                Text(hint).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)

                if mode == 3 {
                    cleanupCanvas
                } else if let show = result ?? original {
                    Image(uiImage: show).resizable().scaledToFit().frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                }

                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("Choose a different photo", systemImage: "photo.on.rectangle.angled")
                }.textButton()

                if mode == 1 {
                    Toggle("Blur faces", isOn: $blurFaces).tint(HandyColor.accent)
                    Toggle("Blur text", isOn: $blurText).tint(HandyColor.accent)
                }
                if mode == 3 {
                    SliderRow(label: "Brush size", valueText: "\(Int(brush))", value: $brush, range: 10...60, step: 1)
                    HStack {
                        Button("Undo") { if !strokes.isEmpty { strokes.removeLast() } }.textButton().disabled(strokes.isEmpty)
                        Button("Clear") { strokes = [] }.textButton().disabled(strokes.isEmpty)
                        Spacer()
                    }
                }

                if !store.isPremium { QuotaChip(name: "photostudio", limit: Limits.freePhotoStudioPerDay).environmentObject(store) }
                if overQuota { LimitReachedBanner(message: "You've used today's \(Limits.freePhotoStudioPerDay) free Photo Studio edits.") }

                Button { run() } label: {
                    HStack { if working { ProgressView().tint(.white) }; Text(working ? "Working…" : actionLabel) }.frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || overQuota || (mode == 3 && strokes.isEmpty))
            }

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            if let result, let png = result.pngData() {
                ShareLink(item: PNGFile(data: png), preview: SharePreview("Edited photo")) {
                    Label("Save or share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }.primaryButton()
            }
        }
        .onChange(of: pickedItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    original = img.normalizedUp(); result = nil; errorText = nil; strokes = []
                }
            }
        }
    }

    private var hint: String {
        switch mode {
        case 0: return "Point at a document, whiteboard or picture with four clear edges."
        case 1: return "We find faces and text and pixelate them — check the result before sharing."
        case 2: return "Keeps the main subject in colour and drains the background to black & white."
        default: return "Paint over a small object or blemish. Best for small things, not whole people."
        }
    }
    private var actionLabel: String {
        switch mode { case 0: return "Straighten"; case 1: return "Blur them"; case 2: return "Pop the colour"; default: return "Remove painted areas" }
    }

    // MARK: cleanup canvas (paint a mask over the photo)

    private var cleanupCanvas: some View {
        GeometryReader { geo in
            let img = original!
            let fit = fitRect(image: img.size, in: geo.size)
            ZStack {
                Image(uiImage: result ?? img).resizable().scaledToFit()
                // painted strokes, shown over the image
                Path { p in
                    for s in strokes { if let f = s.first { p.move(to: denorm(f, fit)); for pt in s.dropFirst() { p.addLine(to: denorm(pt, fit)) } } }
                }.stroke(HandyColor.accent.opacity(0.5), style: StrokeStyle(lineWidth: brush, lineCap: .round, lineJoin: .round))
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let n = norm(v.location, fit)
                if strokes.isEmpty || v.startLocation != lastStart { strokes.append([n]); lastStart = v.startLocation }
                else { strokes[strokes.count - 1].append(n) }
            }.onEnded { _ in lastStart = .init(x: -1, y: -1) })
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }

    // normalized ↔ view coords within the fitted image rect
    private func fitRect(image: CGSize, in container: CGSize) -> CGRect {
        let scale = min(container.width / image.width, container.height / image.height)
        let w = image.width * scale, h = image.height * scale
        return CGRect(x: (container.width - w) / 2, y: (container.height - h) / 2, width: w, height: h)
    }
    private func norm(_ p: CGPoint, _ fit: CGRect) -> CGPoint { CGPoint(x: (p.x - fit.minX) / fit.width, y: (p.y - fit.minY) / fit.height) }
    private func denorm(_ p: CGPoint, _ fit: CGRect) -> CGPoint { CGPoint(x: fit.minX + p.x * fit.width, y: fit.minY + p.y * fit.height) }

    // MARK: run

    private func run() {
        guard let src = original else { return }
        guard Usage.use("photostudio", limit: Limits.freePhotoStudioPerDay) else { return }
        working = true; errorText = nil
        let m = mode, faces = blurFaces, text = blurText
        let strokeData = strokes, brushW = brush
        Task { @MainActor in
            var out: UIImage?
            var failMsg = "Couldn't process that photo. Try another."
            switch m {
            case 0:
                out = straighten(src); failMsg = "Couldn't find four clear edges. Try a straight-on shot of the whole document."
            case 1:
                out = redact(src, faces: faces, text: text); failMsg = "Found nothing to blur. Try a photo with visible faces or text."
            case 2:
                out = colorPop(src); failMsg = "Couldn't pick out a subject. Try a photo with a clear foreground."
            default:
                out = cleanup(src, strokes: strokeData, brush: brushW)
            }
            working = false
            if let out { result = out; HandyHaptics.success() } else { errorText = failMsg }
        }
    }

    // MARK: image ops

    private func straighten(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        let req = VNDetectRectanglesRequest()
        req.maximumObservations = 1; req.minimumConfidence = 0.5; req.minimumSize = 0.2; req.quadratureTolerance = 30
        try? handler.perform([req])
        guard let r = req.results?.first else { return nil }
        let W = ci.extent.width, H = ci.extent.height
        let f = CIFilter.perspectiveCorrection()
        f.inputImage = ci
        f.topLeft = CGPoint(x: r.topLeft.x * W, y: r.topLeft.y * H)
        f.topRight = CGPoint(x: r.topRight.x * W, y: r.topRight.y * H)
        f.bottomLeft = CGPoint(x: r.bottomLeft.x * W, y: r.bottomLeft.y * H)
        f.bottomRight = CGPoint(x: r.bottomRight.x * W, y: r.bottomRight.y * H)
        guard let out = f.outputImage, let outCG = ctx.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: outCG)
    }

    private func redact(_ image: UIImage, faces: Bool, text: Bool) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let W = CGFloat(cg.width), H = CGFloat(cg.height)
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        var rects: [CGRect] = []     // UIKit (top-left) pixel rects
        if faces {
            let fr = VNDetectFaceRectanglesRequest(); try? handler.perform([fr])
            for o in (fr.results ?? []) { rects.append(uiRect(o.boundingBox, W, H).insetBy(dx: -o.boundingBox.width * W * 0.08, dy: -o.boundingBox.height * H * 0.08)) }
        }
        if text {
            let tr = VNRecognizeTextRequest(); tr.recognitionLevel = .fast; try? handler.perform([tr])
            for o in (tr.results as? [VNRecognizedTextObservation] ?? []) { rects.append(uiRect(o.boundingBox, W, H)) }
        }
        guard !rects.isEmpty else { return nil }

        // Mask: white where we redact, built in UIKit coords so it aligns with the source bitmap.
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        let maskImg = UIGraphicsImageRenderer(size: CGSize(width: W, height: H), format: fmt).image { c in
            UIColor.black.setFill(); c.fill(CGRect(x: 0, y: 0, width: W, height: H))
            UIColor.white.setFill()
            for r in rects { UIBezierPath(roundedRect: r, cornerRadius: min(r.width, r.height) * 0.12).fill() }
        }
        guard let maskCG = maskImg.cgImage else { return nil }

        let ci = CIImage(cgImage: cg)
        let scale = max(W, H) / 36
        let pix = ci.clampedToExtent().applyingFilter("CIPixellate", parameters: [kCIInputScaleKey: scale]).cropped(to: ci.extent)
        let blend = CIFilter.blendWithMask()
        blend.inputImage = pix; blend.backgroundImage = ci; blend.maskImage = CIImage(cgImage: maskCG)
        guard let out = blend.outputImage, let outCG = ctx.createCGImage(out, from: ci.extent) else { return nil }
        return UIImage(cgImage: outCG)
    }

    private func colorPop(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let handler = VNImageRequestHandler(cgImage: cg)
        let req = VNGenerateForegroundInstanceMaskRequest()
        guard (try? handler.perform([req])) != nil, let res = req.results?.first,
              let masked = try? res.generateMaskedImage(ofInstances: res.allInstances, from: handler, croppedToInstancesExtent: false) else { return nil }
        let subject = CIImage(cvPixelBuffer: masked)
        let ci = CIImage(cgImage: cg)
        let mono = ci.applyingFilter("CIPhotoEffectMono")
        let out = subject.composited(over: mono)
        guard let outCG = ctx.createCGImage(out, from: ci.extent) else { return nil }
        return UIImage(cgImage: outCG)
    }

    /// Diffusion inpaint: repeatedly blur the current image and keep that only inside the painted
    /// mask, so surrounding colour creeps in over the spot. Good for small objects, not whole people.
    private func cleanup(_ image: UIImage, strokes: [[CGPoint]], brush: Double) -> UIImage? {
        guard let cg = image.cgImage, !strokes.isEmpty else { return nil }
        let W = CGFloat(cg.width), H = CGFloat(cg.height)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        // Brush is in the 300pt-tall view; scale it to pixels via the fitted height.
        let viewFit = fitRect(image: image.size, in: CGSize(width: UIScreen.main.bounds.width - 2 * HandySpacing.gutter, height: 300))
        let pxBrush = brush * (H / max(1, viewFit.height))
        let maskImg = UIGraphicsImageRenderer(size: CGSize(width: W, height: H), format: fmt).image { c in
            UIColor.black.setFill(); c.fill(CGRect(x: 0, y: 0, width: W, height: H))
            UIColor.white.setStroke()
            for s in strokes {
                let path = UIBezierPath(); path.lineWidth = pxBrush; path.lineCapStyle = .round; path.lineJoinStyle = .round
                if let f = s.first { path.move(to: CGPoint(x: f.x * W, y: f.y * H)); for pt in s.dropFirst() { path.addLine(to: CGPoint(x: pt.x * W, y: pt.y * H)) } }
                path.stroke()
            }
        }
        guard let maskCG = maskImg.cgImage else { return nil }
        let maskCI = CIImage(cgImage: maskCG)
        let original = CIImage(cgImage: cg)
        var current = original
        let blend = CIFilter.blendWithMask()
        for _ in 0..<14 {
            let blurred = current.clampedToExtent().applyingGaussianBlur(sigma: 10).cropped(to: original.extent)
            blend.inputImage = blurred; blend.backgroundImage = original; blend.maskImage = maskCI
            if let o = blend.outputImage { current = o }
        }
        guard let outCG = ctx.createCGImage(current, from: original.extent) else { return nil }
        return UIImage(cgImage: outCG)
    }

    private func uiRect(_ box: CGRect, _ W: CGFloat, _ H: CGFloat) -> CGRect {
        CGRect(x: box.minX * W, y: (1 - box.maxY) * H, width: box.width * W, height: box.height * H)
    }
}
