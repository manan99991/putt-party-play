import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Magnifier+ — a reading glass that does what the Camera app won't: zoom far past the limit, freeze a
/// frame (then zoom inside the frozen frame), and switch to the high-contrast looks low-vision users
/// rely on — inverted, yellow-on-black, white-on-blue — with sharpening and a light.
struct MagnifierView: View {
    @StateObject private var cam = FrameCamera()
    @State private var holder = MetalViewHolder()

    enum Look: Int, CaseIterable { case natural, highContrast, inverted, yellowBlack, whiteBlue, grayscale
        var title: String { ["Natural", "High contrast", "Inverted", "Yellow on black", "White on blue", "Grayscale"][rawValue] } }

    @State private var zoom: CGFloat = 2
    @State private var look: Look = .natural
    @State private var sharpen = true
    @State private var brightness: Double = 0
    @State private var frozen = false
    @State private var frozenFrame: CIImage?
    @State private var frozenZoom: CGFloat = 1
    @State private var snapshot: Data?

    private var source: CIImage? { frozen ? frozenFrame : cam.latest }
    private var processed: CIImage? { source.map { Self.style(Self.cropZoom($0, frozen ? frozenZoom : 1), look: look, sharpen: sharpen, brightness: Float(brightness)) } }

    var body: some View {
        ToolPage(title: "Magnifier+", subtitle: "Zoom past the Camera app, freeze and zoom into the frame, and read in high contrast.") {
            HowTo("magnify", [
                "Point the camera at small print and pinch to zoom in.",
                "Tap to freeze a sharp frame, then study it.",
                "Pick a high-contrast look or turn on the light to read easier.",
            ])
            ZStack(alignment: .bottom) {
                ProcessedFrameView(image: processed, holder: holder)
                    .frame(height: 400)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .gesture(MagnifyGesture().onChanged { v in
                        if frozen { frozenZoom = min(6, max(1, frozenZoom * (1 + (v.magnification - 1) * 0.15))) }
                        else { zoom = min(12, max(1, zoom * (1 + (v.magnification - 1) * 0.15))); cam.setZoom(zoom) }
                    })
                if frozen {
                    Text("Frozen · pinch to zoom in").font(HandyFont.caption).padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule()).padding(HandySpacing.s12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                HStack(spacing: HandySpacing.s8) {
                    Button { cam.setTorch(!cam.torchOn) } label: { Image(systemName: cam.torchOn ? "flashlight.on.fill" : "flashlight.off.fill").frame(width: 36, height: 36) }.compactButton()
                    Spacer()
                    Button { save() } label: { Image(systemName: "square.and.arrow.down").frame(width: 36, height: 36) }.compactButton().disabled(processed == nil)
                    Button { toggleFreeze() } label: { Label(frozen ? "Live" : "Freeze", systemImage: frozen ? "play.fill" : "pause.fill") }.primaryButton()
                }.padding(HandySpacing.s12)
            }

            HStack(spacing: HandySpacing.s12) {
                Image(systemName: "minus.magnifyingglass")
                if frozen {
                    Slider(value: $frozenZoom, in: 1...6).tint(HandyColor.accent)
                } else {
                    Slider(value: $zoom, in: 1...12).tint(HandyColor.accent).onChange(of: zoom) { _, z in cam.setZoom(z) }
                }
                Image(systemName: "plus.magnifyingglass")
                Text(String(format: "%.1f×", frozen ? zoom * frozenZoom : zoom)).font(HandyFont.caption).monospacedDigit().frame(width: 44)
            }.foregroundStyle(HandyColor.textSecondary)

            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(Look.allCases, id: \.rawValue) { l in HChip(text: l.title, selected: look == l) { look = l } }
            }
            HStack(spacing: HandySpacing.s12) {
                Toggle("Sharpen text", isOn: $sharpen).tint(HandyColor.accent).font(HandyFont.body).fixedSize()
                Spacer()
                Image(systemName: "sun.min").foregroundStyle(HandyColor.textSecondary)
                Slider(value: $brightness, in: -0.3...0.4).tint(HandyColor.accent).frame(width: 130)
                Image(systemName: "sun.max").foregroundStyle(HandyColor.textSecondary)
            }

            if let snapshot {
                ShareLink(item: JPEGFile(data: snapshot), preview: SharePreview("Magnifier")) { Label("Save or share this frame", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
            }
            Text("Tip: freeze first, then zoom — no shaky hands. Yellow-on-black and inverted are the looks low-vision readers find easiest.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .onAppear { if Launch.startHardware { cam.start(preset: .hd1920x1080); cam.setZoom(zoom) }; if Launch.sample, let cg = SampleAssets.document().cgImage { frozenFrame = CIImage(cgImage: cg); frozen = true; cam.setPaused(true) } }
        .onDisappear { cam.stop() }
    }

    private func toggleFreeze() {
        if frozen { frozen = false; frozenFrame = nil; frozenZoom = 1; cam.setPaused(false) }
        else if let f = cam.latest { frozenFrame = f; frozen = true; cam.setPaused(true); HandyHaptics.light() }
    }

    private func save() {
        guard let img = holder.view?.snapshot(), let d = img.jpegData(compressionQuality: 0.92) else { return }
        snapshot = d; HandyHaptics.success()
    }

    // MARK: image pipeline (pure, testable)

    /// Centre crop by `factor` (1 = none), scaled back to the original extent so the renderer fills the view.
    static func cropZoom(_ img: CIImage, _ factor: CGFloat) -> CIImage {
        guard factor > 1.001 else { return img }
        let e = img.extent
        let w = e.width / factor, h = e.height / factor
        let crop = CGRect(x: e.midX - w / 2, y: e.midY - h / 2, width: w, height: h)
        return img.cropped(to: crop).transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY)).transformed(by: CGAffineTransform(scaleX: factor, y: factor))
    }

    static func style(_ img: CIImage, look: Look, sharpen: Bool, brightness: Float) -> CIImage {
        var out = img
        if brightness != 0 {
            let cc = CIFilter.colorControls(); cc.inputImage = out; cc.brightness = brightness; out = cc.outputImage ?? out
        }
        if sharpen {
            let s = CIFilter.unsharpMask(); s.inputImage = out; s.radius = 1.6; s.intensity = 0.9; out = s.outputImage ?? out
        }
        switch look {
        case .natural: break
        case .grayscale:
            let f = CIFilter.photoEffectNoir(); f.inputImage = out; out = f.outputImage ?? out
        case .highContrast:
            let f = CIFilter.colorControls(); f.inputImage = out; f.saturation = 0; f.contrast = 2.2; out = f.outputImage ?? out
        case .inverted:
            let c = CIFilter.colorControls(); c.inputImage = out; c.saturation = 0; c.contrast = 1.6
            let f = CIFilter.colorInvert(); f.inputImage = c.outputImage ?? out; out = f.outputImage ?? out
        case .yellowBlack:
            out = falseColor(out, dark: CIColor(red: 0, green: 0, blue: 0), light: CIColor(red: 1, green: 0.92, blue: 0.1))
        case .whiteBlue:
            out = falseColor(out, dark: CIColor(red: 0.03, green: 0.08, blue: 0.4), light: CIColor(red: 1, green: 1, blue: 1))
        }
        return out
    }

    private static func falseColor(_ img: CIImage, dark: CIColor, light: CIColor) -> CIImage {
        let c = CIFilter.colorControls(); c.inputImage = img; c.saturation = 0; c.contrast = 1.9
        let f = CIFilter.falseColor(); f.inputImage = c.outputImage ?? img; f.color0 = dark; f.color1 = light
        return f.outputImage ?? img
    }
}
