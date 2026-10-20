import SwiftUI
import CoreImage
import AVFoundation

/// Pro Camera — the manual camera iPhone never shipped: lock ISO, shutter, focus and white balance,
/// see focus peaking, zebras and a live histogram, shoot RAW (DNG) where the hardware allows, and
/// make light-trail / silky-water long exposures by averaging frames.
struct ProCameraView: View {
    @StateObject private var cam = ProCameraController()
    @State private var holder = MetalViewHolder()
    private enum Panel: Int, CaseIterable { case exposure, focus, wb, long
        var title: String { ["Exposure", "Focus", "White balance", "Long exposure"][rawValue] } }
    @State private var panel: Panel = .exposure
    @State private var peaking = false
    @State private var zebras = false
    @State private var grid = true
    @State private var raw = false
    @State private var longSeconds = 2
    @State private var histogram: [Float] = []
    @State private var longResult: UIImage?
    @State private var shooting = false
    private let ctx = CIContext()
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var processed: CIImage? {
        guard var img = cam.latest else { return nil }
        if zebras { img = ProImage.zebras(img) }
        if peaking { img = ProImage.peaking(img) }
        return img
    }

    var body: some View {
        ToolPage(title: "Pro Camera", subtitle: "Manual ISO, shutter, focus and white balance; peaking, zebras, histogram; RAW and long exposures.") {
            ZStack {
                ProcessedFrameView(image: processed, holder: holder)
                if grid {
                    GeometryReader { g in
                        Path { p in
                            for i in 1...2 { p.move(to: CGPoint(x: g.size.width * CGFloat(i) / 3, y: 0)); p.addLine(to: CGPoint(x: g.size.width * CGFloat(i) / 3, y: g.size.height))
                                             p.move(to: CGPoint(x: 0, y: g.size.height * CGFloat(i) / 3)); p.addLine(to: CGPoint(x: g.size.width, y: g.size.height * CGFloat(i) / 3)) }
                        }.stroke(.white.opacity(0.35), lineWidth: 0.5)
                    }.allowsHitTesting(false)
                }
                VStack {
                    HStack {
                        if !histogram.isEmpty { HistogramView(values: histogram).frame(width: 96, height: 36).background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6)) }
                        Spacer()
                        Text(readout).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.white).padding(6).background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
                    }
                    Spacer()
                    if cam.accumulating { Text("Exposing… \(cam.accumulated)/\(longSeconds * 30) frames").font(HandyFont.caption).foregroundStyle(.white).padding(6).background(.black.opacity(0.5), in: Capsule()) }
                }.padding(HandySpacing.s8)
            }
            .frame(height: 420)
            .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))

            HStack(spacing: HandySpacing.s8) {
                toggle("Peaking", $peaking, "scope"); toggle("Zebras", $zebras, "sun.max.trianglebadge.exclamationmark"); toggle("Grid", $grid, "grid")
                if cam.rawSupported { toggle("RAW", $raw, "r.square") }
                Spacer()
                shutterButton
            }

            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(Panel.allCases, id: \.rawValue) { p in HChip(text: p.title, selected: panel == p) { panel = p } }
            }
            switch panel {
            case .exposure: exposurePanel
            case .focus: focusPanel
            case .wb: wbPanel
            case .long: longPanel
            }

            if let img = cam.lastSaved ?? longResult {
                HStack(spacing: HandySpacing.s12) {
                    Image(uiImage: img).resizable().scaledToFill().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(cam.lastMessage).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Spacer()
                    if let longResult, let d = longResult.jpegData(compressionQuality: 0.95) {
                        ShareLink(item: JPEGFile(data: d), preview: SharePreview("Long exposure")) { Image(systemName: "square.and.arrow.up") }.compactButton()
                    }
                }.cardStyle(padding: HandySpacing.s12)
            }
            if !cam.authorized { LimitNote("Camera access is off. Allow it in Settings.") }
            Text(cam.rawSupported ? "RAW saves a DNG alongside the HEIF — edit it in Photos, Lightroom or Darkroom. Long exposures average frames, so use a tripod or a steady ledge."
                                  : "This camera doesn't offer RAW capture to apps; HEIF at full quality is saved. Long exposures average frames — steady the phone.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .onAppear { if Launch.startHardware { cam.start() } }
        .onDisappear { cam.stop() }
        .onReceive(timer) { _ in if let l = cam.latest { histogram = ProImage.histogram(l, context: ctx) } }
        .onChange(of: cam.accumulating) { was, now in if was, !now, panel == .long { finishLong() } }
    }

    private var readout: String {
        let d = cam.device
        let isoRaw = d?.iso ?? cam.current.iso
        let iso = Int(isoRaw.isFinite ? isoRaw : cam.current.iso)
        let shRaw = d?.exposureDuration.seconds ?? cam.current.shutter
        let sh = ProImage.shutterLabel(shRaw.isFinite && shRaw > 0 ? shRaw : cam.current.shutter)
        return "ISO \(iso) · \(sh)" + (cam.current.autoExposure ? " · AUTO" : " · M")
    }

    private func toggle(_ t: String, _ b: Binding<Bool>, _ icon: String) -> some View {
        Button { b.wrappedValue.toggle() } label: { Image(systemName: icon).frame(width: 36, height: 36) }
            .buttonStyle(.plain).foregroundStyle(b.wrappedValue ? .white : HandyColor.textPrimary)
            .background(b.wrappedValue ? HandyColor.accent : HandyColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(b.wrappedValue ? Color.clear : HandyColor.border))
            .accessibilityLabel(t)
    }

    private var shutterButton: some View {
        Button { panel == .long ? startLong() : shoot() } label: {
            ZStack {
                Circle().stroke(HandyColor.textPrimary, lineWidth: 3).frame(width: 58, height: 58)
                Circle().fill(panel == .long ? HandyColor.accent : HandyColor.danger).frame(width: 46, height: 46)
                if shooting || cam.saving { ProgressView().tint(.white) }
            }
        }.buttonStyle(.plain).disabled(shooting || cam.saving || cam.accumulating || cam.latest == nil)
        .accessibilityLabel(panel == .long ? "Start long exposure" : "Take photo")
    }

    // MARK: panels

    private var exposurePanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Picker("", selection: $cam.current.autoExposure) { Text("Auto").tag(true); Text("Manual").tag(false) }.pickerStyle(.segmented).frame(width: 180)
                .onChange(of: cam.current.autoExposure) { _, auto in if !auto { cam.syncFromDevice() }; cam.applyExposure() }
            if cam.current.autoExposure {
                HStack { Text("EV").font(HandyFont.caption).frame(width: 60, alignment: .leading); Slider(value: $cam.current.ev, in: -3...3, step: 0.3).tint(HandyColor.accent).onChange(of: cam.current.ev) { _, _ in cam.applyExposure() }; Text(String(format: "%+.1f", cam.current.ev)).font(HandyFont.caption).monospacedDigit().frame(width: 40) }
            } else {
                HStack { Text("ISO").font(HandyFont.caption).frame(width: 60, alignment: .leading)
                    Slider(value: Binding(get: { log2(Double(cam.current.iso)) }, set: { cam.current.iso = Float(pow(2, $0)); cam.applyExposure() }), in: log2(Double(cam.ranges.minISO))...log2(Double(cam.ranges.maxISO))).tint(HandyColor.accent)
                    Text("\(Int(cam.current.iso))").font(HandyFont.caption).monospacedDigit().frame(width: 44) }
                HStack { Text("Shutter").font(HandyFont.caption).frame(width: 60, alignment: .leading)
                    Slider(value: Binding(get: { log2(cam.current.shutter) }, set: { cam.current.shutter = pow(2, $0); cam.applyExposure() }), in: log2(cam.ranges.minShutter)...log2(cam.ranges.maxShutter)).tint(HandyColor.accent)
                    Text(ProImage.shutterLabel(cam.current.shutter)).font(HandyFont.caption).monospacedDigit().frame(width: 44) }
            }
            Text("Manual: low ISO + slow shutter for clean night shots on a tripod; fast shutter to freeze motion. Zebras show what's blowing out.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private var focusPanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Picker("", selection: $cam.current.autoFocus) { Text("Auto").tag(true); Text("Manual").tag(false) }.pickerStyle(.segmented).frame(width: 180)
                .onChange(of: cam.current.autoFocus) { _, auto in if !auto { cam.syncFromDevice() }; cam.applyFocus() }
            if !cam.current.autoFocus {
                HStack { Text("Near").font(HandyFont.caption); Slider(value: $cam.current.lens, in: 0...1).tint(HandyColor.accent).onChange(of: cam.current.lens) { _, _ in cam.applyFocus() }; Text("Far").font(HandyFont.caption) }
                Text("Turn on Peaking — the red edges show exactly what's sharp.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            } else {
                Text("Lock focus for macro, through glass, or so it stops hunting in video.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        }
    }

    private var wbPanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Picker("", selection: $cam.current.autoWB) { Text("Auto").tag(true); Text("Manual").tag(false) }.pickerStyle(.segmented).frame(width: 180)
                .onChange(of: cam.current.autoWB) { _, auto in if !auto { cam.syncFromDevice() }; cam.applyWhiteBalance() }
            if !cam.current.autoWB {
                HStack { Text("Warm").font(HandyFont.caption); Slider(value: $cam.current.temp, in: cam.ranges.minTemp...cam.ranges.maxTemp, step: 50).tint(HandyColor.accent).onChange(of: cam.current.temp) { _, _ in cam.applyWhiteBalance() }; Text("Cool").font(HandyFont.caption) }
                HStack(spacing: HandySpacing.s8) {
                    ForEach([("Tungsten", 3200), ("Fluorescent", 4200), ("Daylight", 5500), ("Cloudy", 6500), ("Shade", 7500)], id: \.1) { n, k in HChip(text: n, selected: Int(cam.current.temp) == k) { cam.current.temp = Float(k); cam.applyWhiteBalance() } }
                }
                Text("\(Int(cam.current.temp)) K").font(HandyFont.caption).monospacedDigit().foregroundStyle(HandyColor.textSecondary)
            } else {
                Text("Lock it when mixed lighting keeps shifting colours between shots.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        }
    }

    private var longPanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(spacing: HandySpacing.s8) { ForEach([1, 2, 4, 8, 15], id: \.self) { s in HChip(text: "\(s) s", selected: longSeconds == s) { longSeconds = s } } }
            Text("Averages ~30 frames per second into one image: silky water, light trails, crowds that vanish. Brace the phone and press the blue button.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    // MARK: actions

    private func shoot() {
        shooting = true
        Task { @MainActor in
            let (processed, rawData) = await cam.capture(raw: raw && cam.rawSupported)
            shooting = false
            guard processed != nil || rawData != nil else { cam.lastMessage = "Capture failed — try again."; return }
            cam.saving = true
            let ok = await cam.save(processed: processed, raw: rawData)
            cam.saving = false
            if let p = processed, let img = UIImage(data: p) { cam.lastSaved = img.resized(maxDimension: 300) }
            cam.lastMessage = ok ? (rawData != nil ? "Saved to Photos — HEIF + DNG" : "Saved to Photos") : "Couldn't save — allow Photos access in Settings."
            if ok { HandyHaptics.success() }
        }
    }

    private func startLong() { longResult = nil; cam.lastSaved = nil; cam.beginLongExposure(frames: longSeconds * 30) }

    private func finishLong() {
        guard let img = cam.finishLongExposure() else { cam.lastMessage = "Long exposure failed."; return }
        longResult = img
        Task { @MainActor in
            cam.saving = true
            let ok = await cam.save(processed: img.jpegData(compressionQuality: 0.95), raw: nil)
            cam.saving = false
            cam.lastMessage = ok ? "Long exposure saved to Photos" : "Saved here — allow Photos access to keep it in your library."
            HandyHaptics.success()
        }
    }
}

/// Tiny luminance histogram bars.
struct HistogramView: View {
    let values: [Float]
    var body: some View {
        GeometryReader { g in
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                    Rectangle().fill(.white.opacity(0.9)).frame(height: max(1, CGFloat(v) * g.size.height))
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }.padding(3)
    }
}
