import SwiftUI
import PhotosUI
import CoreImage
import simd
import AVFoundation

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
    @State private var current: SIMD3<Float>?
    @State private var held: (rgb: SIMD3<Float>, name: String, hex: String)?
    @State private var checking = false
    @State private var checkNote: String?
    @State private var speaker = AVSpeechSynthesizer()
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
        ToolPage(title: "Color Vision", subtitle: "Live correction for colour-blind eyes, a one-colour highlight, a colour namer that says it out loud and tells you if two things match — camera or photo.") {
            HowTo("colorvision", [
                "Not sure which type you are? Tap “Which type am I?” — a 1-minute check sets it for you.",
                "Correct shifts confusing colours into ones you can tell apart; Highlight keeps just one colour.",
                "Name it reads the colour in the ring. Hold one colour, then point at another to see if they match.",
                "Simulate shows family or a designer how you see the scene.",
            ])
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
                        Button { photo = nil; frozen = false; cam.setPaused(false) } label: { Label(L("Back to camera"), systemImage: "camera") }.compactButton()
                    } else {
                        Button { frozen.toggle(); cam.setPaused(frozen) } label: { Label(frozen ? "Live" : "Freeze", systemImage: frozen ? "play.fill" : "pause.fill") }.compactButton()
                    }
                    Spacer()
                    Button { save() } label: { Image(systemName: "square.and.arrow.down").accessibilityLabel(L("Save")).frame(width: 36, height: 36) }.compactButton().disabled(processed == nil)
                    PhotosPicker(selection: $photoItem, matching: .images) { Image(systemName: "photo").frame(width: 36, height: 36) }.compactButton()
                }.padding(HandySpacing.s12)
            }

            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(Mode.allCases, id: \.rawValue) { m in HChip(text: m.title, selected: mode == m) { mode = m; snapshot = nil } }
            }

            switch mode {
            case .correct, .simulate: typeControls
            case .highlight: highlightControls
            case .name: nameControls
            }

            if let snapshot {
                ShareLink(item: JPEGFile(data: snapshot), preview: SharePreview("Color Vision")) { Label(L("Save or share this frame"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
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
        .sheet(isPresented: $checking) {
            NavigationStack {
                ColorTypeCheckView { type, line in
                    if let type { deficiencyRaw = type.rawValue; mode = .correct; checkNote = "\(L("Set to")) \(L(type.short)) \(L("from your check — correction is on."))" }
                    else { checkNote = L(line) }
                }
            }
        }
    }

    private var typeControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Button { checking = true } label: {
                Label(L("Which type am I?"), systemImage: "eye.circle").frame(maxWidth: .infinity)
            }.secondaryButton().accessibilityIdentifier("cv-check")
            if let checkNote { Text(checkNote).font(HandyFont.caption).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true) }
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(ColorVision.Deficiency.allCases, id: \.rawValue) { d in HChip(text: d.short, selected: deficiency == d) { deficiencyRaw = d.rawValue } }
            }
            HStack { Text(L("How strong is it")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(width: 118, alignment: .leading); Slider(value: $severity, in: 0.2...1).tint(HandyColor.accent); Text("\(Int(severity * 100))%").font(HandyFont.caption).monospacedDigit().frame(width: 40) }
            if mode == .correct {
                HStack { Text(L("Correction")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(width: 118, alignment: .leading); Slider(value: $strength, in: 0...1.5).tint(HandyColor.accent); Text("\(Int(strength * 100))%").font(HandyFont.caption).monospacedDigit().frame(width: 40) }
            }
        }
    }

    /// Say the colour, hold it, and compare it with the next thing you point at ("do these socks match?").
    private var nameControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Centre the ring on the thing. The name and hex code update live; freeze to hold it.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HStack(spacing: HandySpacing.s8) {
                Button { say(colorName) } label: { Label(L("Say it"), systemImage: "speaker.wave.2.fill").frame(maxWidth: .infinity) }
                    .secondaryButton().disabled(colorName.isEmpty).accessibilityIdentifier("cv-say")
                Button {
                    if held != nil { held = nil } else if let c = current { held = (c, colorName, colorHex); HandyHaptics.success() }
                } label: { Label(held == nil ? L("Hold this colour") : L("Let go"), systemImage: held == nil ? "pin.fill" : "pin.slash").frame(maxWidth: .infinity) }
                    .secondaryButton().disabled(held == nil && current == nil).accessibilityIdentifier("cv-hold")
            }
            if let h = held {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Do these match?")).font(HandyFont.bodyStrong)
                    HStack(spacing: HandySpacing.s12) {
                        swatch(Color(hex: h.hex), L(h.name))
                        Image(systemName: "arrow.left.and.right").foregroundStyle(HandyColor.textSecondary)
                        swatch(Color(hex: colorHex.isEmpty ? h.hex : colorHex), L(colorName.isEmpty ? h.name : colorName))
                    }
                    if let c = current {
                        Text(L(ColorVisionCheck.matchWords(h.rgb, c))).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.accent)
                            .accessibilityIdentifier("cv-match")
                    }
                    Text(L("Point the ring at the second thing — socks, paint, a cable, a shirt and tie.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                .cardStyle()
            }
        }
    }

    private func swatch(_ c: Color, _ name: String) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(c).frame(width: 56, height: 40)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(HandyColor.border))
            Text(name).font(HandyFont.caption).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private func say(_ text: String) {
        guard !text.isEmpty else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        speaker.stopSpeaking(at: .immediate)
        speaker.speak(AVSpeechUtterance(string: L(text)))
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
        colorName = n.name; colorHex = n.hex; current = c
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

/// "Which type am I?": six quick rounds of tiles where one is a different colour. Each round uses a pair that
/// only one kind of colour-blind eye mixes up; the rounds you can't do point to your type. A helper, not a diagnosis.
struct ColorTypeCheckView: View {
    let done: (ColorVision.Deficiency?, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rounds = ColorVisionCheck.rounds()
    @State private var index = 0
    @State private var missed: [ColorVision.Deficiency] = []
    @State private var result: (type: ColorVision.Deficiency?, line: String)?
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                if let result {
                    Image(systemName: "eye.circle.fill").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
                    Text(L(result.line)).font(HandyFont.bodyStrong).fixedSize(horizontal: false, vertical: true)
                    Text(L("This is a quick helper, not an eye test. For a real answer, an optician can check your colour vision.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    Button { done(result.type, result.line); dismiss() } label: { Text(L("Use this")).frame(maxWidth: .infinity) }.primaryButton()
                        .accessibilityIdentifier("cv-check-use")
                    Button { rounds = ColorVisionCheck.rounds(); index = 0; missed = []; self.result = nil } label: { Text(L("Try again")).frame(maxWidth: .infinity) }.secondaryButton()
                } else {
                    Text("\(L("Round")) \(index + 1) / \(rounds.count)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Text(L("Tap the square that's a different colour.")).font(HandyFont.title).fixedSize(horizontal: false, vertical: true)
                    Text(L("Turn your screen brightness up and don't tilt the phone. Go with your first look.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    let r = rounds[index]
                    LazyVGrid(columns: cols, spacing: 10) {
                        ForEach(Array(r.tiles.enumerated()), id: \.offset) { i, c in
                            Button { answer(i == r.oddIndex) } label: {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(red: Double(c.x), green: Double(c.y), blue: Double(c.z)))
                                    .aspectRatio(1, contentMode: .fit)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(L("Square")) \(i + 1)")
                            .accessibilityIdentifier("cv-tile-\(i)")
                        }
                    }
                    Button { answer(false) } label: { Text(L("They all look the same")).frame(maxWidth: .infinity) }.secondaryButton()
                        .accessibilityIdentifier("cv-same")
                }
            }
            .padding(HandySpacing.gutter)
        }
        .background(Ground())
        .navigationTitle(L("Which type am I?")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Close")) { dismiss() } } }
    }

    private func answer(_ right: Bool) {
        HandyHaptics.light()
        if !right { missed.append(rounds[index].deficiency) }
        if index + 1 < rounds.count { index += 1 } else { result = ColorVisionCheck.result(missed: missed) }
    }
}
