import SwiftUI
import PhotosUI
import CoreImage
import simd

/// Color Vision — glasses for colour-blind eyes, made of a phone. Live correction shifts the shades a
/// red-weak / green-weak / blue-weak eye confuses into ones it can tell apart; Highlight makes one
/// colour the only colour on screen ("where's the red one?"); Name tells you what the thing in the
/// reticle actually is; Simulate shows everyone else what you see. Works on photos and screenshots too.
struct ColorVisionView: View {
    @StateObject private var cam = FrameCamera()
    @State private var holder = MetalViewHolder()

    private enum Mode: Int, CaseIterable { case correct, highlight, name, simulate
        var title: String { ["Correct", "Highlight", "Name it", "Simulate"][rawValue] } }

    @AppStorage("colorvision.deficiency") private var deficiencyRaw = ColorVision.Deficiency.deutan.rawValue
    @AppStorage("colorvision.severity") private var severity = 0.8
    @AppStorage("colorvision.strength") private var strength = 1.0
    @State private var mode: Mode = .correct
    @State private var highlight: ColorVision.Highlight = .red
    @State private var frozen = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: CIImage?
    @State private var colorName = ""
    @State private var colorHex = ""
    @State private var sampleTick = 0
    @State private var snapshot: Data?
    private let ctx = CIContext()
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    private var deficiency: ColorVision.Deficiency { ColorVision.Deficiency(rawValue: deficiencyRaw) ?? .deutan }
    private var source: CIImage? { photo ?? cam.latest }
    private var cube: Data { ColorVision.cachedCube(highlight) }

    private var processed: CIImage? {
        guard let src = source else { return nil }
        switch mode {
        case .correct:  return ColorVision.apply(ColorVision.correctionMatrix(deficiency, severity: Float(severity), strength: Float(strength)), to: src)
        case .simulate: return ColorVision.apply(ColorVision.simulationMatrix(deficiency, severity: Float(severity)), to: src)
        case .highlight: return ColorVision.applyCube(cube, to: src)
        case .name: return src
        }
    }

    var body: some View {
        ToolPage(title: "Color Vision", subtitle: "Live correction for colour-blind eyes, one-colour highlight, and a colour namer — camera or photo.") {
            ZStack(alignment: .bottom) {
                ProcessedFrameView(image: processed, holder: holder)
                    .frame(height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                if mode == .name {
                    Circle().stroke(.white, lineWidth: 2).frame(width: 36, height: 36).shadow(radius: 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .top) {
                            if !colorName.isEmpty {
                                HStack(spacing: 8) {
                                    Circle().fill(Color(hex: colorHex)).frame(width: 18, height: 18).overlay(Circle().stroke(.white.opacity(0.6)))
                                    Text(colorName).font(HandyFont.bodyStrong)
                                    Text(colorHex).font(HandyFont.caption).monospaced().foregroundStyle(HandyColor.textSecondary)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule()).padding(HandySpacing.s12)
                            }
                        }
                }
                if source == nil {
                    VStack(spacing: 6) {
                        Image(systemName: "camera.fill").font(.system(size: 28))
                        Text(cam.authorized ? "Starting camera… or pick a photo below" : "Camera access is off — allow it in Settings, or pick a photo").font(HandyFont.caption).multilineTextAlignment(.center)
                    }.foregroundStyle(.white.opacity(0.8)).padding().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                HStack(spacing: HandySpacing.s8) {
                    if photo != nil {
                        Button { photo = nil; frozen = false; cam.setPaused(false) } label: { Label("Back to camera", systemImage: "camera") }.compactButton()
                    } else {
                        Button { frozen.toggle(); cam.setPaused(frozen) } label: { Label(frozen ? "Live" : "Freeze", systemImage: frozen ? "play.fill" : "pause.fill") }.compactButton()
                    }
                    Spacer()
                    Button { save() } label: { Image(systemName: "square.and.arrow.down").frame(width: 36, height: 36) }.compactButton().disabled(processed == nil)
                    PhotosPicker(selection: $photoItem, matching: .images) { Image(systemName: "photo").frame(width: 36, height: 36) }.compactButton()
                }.padding(HandySpacing.s12)
            }

            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(Mode.allCases, id: \.rawValue) { m in HChip(text: m.title, selected: mode == m) { mode = m; snapshot = nil } }
            }

            switch mode {
            case .correct, .simulate: typeControls
            case .highlight: highlightControls
            case .name: Text("Centre the ring on the thing. The name and hex code update live; freeze to hold it.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }

            if let snapshot {
                ShareLink(item: JPEGFile(data: snapshot), preview: SharePreview("Color Vision")) { Label("Save or share this frame", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
            }

            Text(mode == .simulate ? "Show this to family, designers, or a teacher: it's how \(deficiency.short.lowercased()) eyes see the scene."
                 : "A helper, not a medical device. If you're not sure which type you are, try each — the one that makes traffic lights and ripe fruit 'pop' is yours.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .onAppear { if Launch.startHardware { cam.start() }; if Launch.sample, photo == nil, let cg = SampleAssets.photo().cgImage { photo = CIImage(cgImage: cg); cam.setPaused(true) } }
        .onDisappear { cam.stop() }
        .onChange(of: photoItem) { _, item in
            Task {
                if let d = try? await item?.loadTransferable(type: Data.self), let ui = UIImage(data: d)?.normalizedUp().resized(maxDimension: 1600), let cg = ui.cgImage {
                    await MainActor.run { photo = CIImage(cgImage: cg); cam.setPaused(true); snapshot = nil }
                }
            }
        }
        .onReceive(timer) { _ in if mode == .name { sampleColor() } }
    }

    private var typeControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(ColorVision.Deficiency.allCases, id: \.rawValue) { d in HChip(text: d.short, selected: deficiency == d) { deficiencyRaw = d.rawValue } }
            }
            HStack { Text("How strong is it").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(width: 118, alignment: .leading); Slider(value: $severity, in: 0.2...1).tint(HandyColor.accent); Text("\(Int(severity * 100))%").font(HandyFont.caption).monospacedDigit().frame(width: 40) }
            if mode == .correct {
                HStack { Text("Correction").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(width: 118, alignment: .leading); Slider(value: $strength, in: 0...1.5).tint(HandyColor.accent); Text("\(Int(strength * 100))%").font(HandyFont.caption).monospacedDigit().frame(width: 40) }
            }
        }
    }

    private var highlightControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(spacing: HandySpacing.s8) {
                ForEach(ColorVision.Highlight.allCases, id: \.rawValue) { h in
                    Button { highlight = h } label: {
                        ZStack {
                            Circle().fill(Color(h.color)).frame(width: 34, height: 34)
                            Circle().stroke(highlight == h ? HandyColor.textPrimary : HandyColor.border, lineWidth: highlight == h ? 3 : 1).frame(width: 34, height: 34)
                        }
                    }.accessibilityLabel(h.title)
                }
                Spacer()
            }
            Text("Only \(highlight.title.lowercased()) things keep their colour — everything else goes grey. Ripe fruit, warning lights, chart lines, cables.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private func sampleColor() {
        guard let src = source, let c = ColorVision.averageColor(of: src, region: CGRect(x: 0.47, y: 0.47, width: 0.06, height: 0.06), context: ctx) else { return }
        let n = ColorVision.name(r: c.x, g: c.y, b: c.z)
        colorName = n.name; colorHex = n.hex
    }

    private func save() {
        guard let img = holder.view?.snapshot(), let d = img.jpegData(compressionQuality: 0.92) else { return }
        snapshot = d; HandyHaptics.success()
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces); if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
