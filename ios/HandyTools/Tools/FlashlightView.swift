import SwiftUI
import AVFoundation

/// The built-in flashlight is on/off plus a coarse brightness slider. This one adds the thing it
/// doesn't have: patterns. Tap a pattern to start it, tap the same one again to stop, tap another
/// to switch live — no separate on/off button. Everything runs on the device LED, nothing else.
@MainActor
final class Torch: ObservableObject {
    @Published var level: Float = 1.0 { didSet { if isOn && mode == .steady { set(true) } } }
    @Published private(set) var isOn = false
    @Published private(set) var mode: Mode = .steady

    enum Mode: String, CaseIterable, Identifiable {
        case steady, strobeSlow, strobeMed, strobeFast, sos, beacon, pulse, candle, heartbeat, disco
        var id: String { rawValue }
        var label: String {
            switch self {
            case .steady: "Steady"
            case .strobeSlow: "Strobe slow"
            case .strobeMed: "Strobe"
            case .strobeFast: "Strobe fast"
            case .sos: "SOS"
            case .beacon: "Beacon"
            case .pulse: "Pulse"
            case .candle: "Candle"
            case .heartbeat: "Heartbeat"
            case .disco: "Disco"
            }
        }
    }

    private var task: Task<Void, Never>?
    private var autoOff: Task<Void, Never>?
    @Published var autoOffMinutes = 0 { didSet { armAutoOff() } }
    @Published private(set) var morseText = ""
    private var device: AVCaptureDevice? { AVCaptureDevice.default(for: .video) }
    var available: Bool { device?.hasTorch == true }

    /// International Morse for A–Z, 0–9 and common punctuation.
    static let morse: [Character: String] = [
        "A": ".-", "B": "-...", "C": "-.-.", "D": "-..", "E": ".", "F": "..-.", "G": "--.", "H": "....", "I": "..", "J": ".---", "K": "-.-", "L": ".-..", "M": "--",
        "N": "-.", "O": "---", "P": ".--.", "Q": "--.-", "R": ".-.", "S": "...", "T": "-", "U": "..-", "V": "...-", "W": ".--", "X": "-..-", "Y": "-.--", "Z": "--..",
        "0": "-----", "1": ".----", "2": "..---", "3": "...--", "4": "....-", "5": ".....", "6": "-....", "7": "--...", "8": "---..", "9": "----.",
        ".": ".-.-.-", ",": "--..--", "?": "..--..", "!": "-.-.--", "/": "-..-.", "@": ".--.-.", "-": "-....-", "'": ".----.",
    ]
    /// Text → dots and dashes (words separated by " / "). Unknown characters are skipped.
    static func encodeMorse(_ text: String) -> String {
        text.uppercased().split(separator: " ").map { word in word.compactMap { morse[$0] }.joined(separator: " ") }.filter { !$0.isEmpty }.joined(separator: " / ")
    }

    /// Blink a message in Morse (dot = 1 unit, dash = 3, gaps 1/3/7), repeating until stopped.
    func flashMorse(_ text: String, unitMs: Int = 180) {
        let code = Self.encodeMorse(text)
        guard !code.isEmpty else { return }
        morseText = text; mode = .steady; isOn = true
        task?.cancel()
        task = Task {
            while !Task.isCancelled {
                for ch in code {
                    if Task.isCancelled { return }
                    switch ch {
                    case ".": set(true); try? await Task.sleep(for: .milliseconds(unitMs)); set(false); try? await Task.sleep(for: .milliseconds(unitMs))
                    case "-": set(true); try? await Task.sleep(for: .milliseconds(unitMs * 3)); set(false); try? await Task.sleep(for: .milliseconds(unitMs))
                    case " ": try? await Task.sleep(for: .milliseconds(unitMs * 2))
                    case "/": try? await Task.sleep(for: .milliseconds(unitMs * 4))
                    default: break
                    }
                }
                try? await Task.sleep(for: .milliseconds(unitMs * 7))
            }
        }
        armAutoOff()
    }

    private func armAutoOff() {
        autoOff?.cancel(); autoOff = nil
        guard autoOffMinutes > 0, isOn else { return }
        let mins = autoOffMinutes
        autoOff = Task { try? await Task.sleep(for: .seconds(mins * 60)); if !Task.isCancelled { stop() } }
    }

    /// Tap a pattern: same one while on → off; otherwise switch to it and turn on.
    func select(_ m: Mode) {
        morseText = ""
        if isOn && mode == m { stop() } else { mode = m; isOn = true; restart(); armAutoOff() }
    }

    func stop() {
        isOn = false; morseText = ""
        task?.cancel(); task = nil
        autoOff?.cancel(); autoOff = nil
        set(false)
    }

    private func set(_ on: Bool, _ lvl: Float? = nil) {
        guard let d = device, d.hasTorch else { return }
        try? d.lockForConfiguration()
        if on { try? d.setTorchModeOn(level: max(0.01, min(1, lvl ?? level))) } else { d.torchMode = .off }
        d.unlockForConfiguration()
    }

    private func blink(_ onMs: Int, _ offMs: Int) -> Task<Void, Never> {
        Task { while !Task.isCancelled {
            set(true); try? await Task.sleep(for: .milliseconds(onMs))
            set(false); try? await Task.sleep(for: .milliseconds(offMs))
        } }
    }

    private func restart() {
        task?.cancel(); task = nil
        guard isOn else { set(false); return }
        switch mode {
        case .steady: set(true)
        case .strobeSlow: task = blink(150, 150)
        case .strobeMed: task = blink(60, 60)
        case .strobeFast: task = blink(26, 26)
        case .sos:
            task = Task {
                let dot: UInt64 = 200, dash: UInt64 = 600
                let pattern: [UInt64] = [dot, dot, dot, dash, dash, dash, dot, dot, dot]
                while !Task.isCancelled {
                    for d in pattern { set(true); try? await Task.sleep(for: .milliseconds(Int(d))); set(false); try? await Task.sleep(for: .milliseconds(200)) }
                    try? await Task.sleep(for: .milliseconds(1200))
                }
            }
        case .beacon: task = blink(110, 1500)
        case .pulse:
            task = Task { while !Task.isCancelled {
                for s in stride(from: 0.05, through: 1.0, by: 0.08) { set(true, Float(s)); try? await Task.sleep(for: .milliseconds(40)) }
                for s in stride(from: 1.0, through: 0.05, by: -0.08) { set(true, Float(s)); try? await Task.sleep(for: .milliseconds(40)) }
            } }
        case .candle:
            task = Task { while !Task.isCancelled {
                set(true, Float.random(in: 0.25...1.0)); try? await Task.sleep(for: .milliseconds(Int.random(in: 45...120)))
            } }
        case .heartbeat:
            task = Task { while !Task.isCancelled {
                set(true); try? await Task.sleep(for: .milliseconds(90))
                set(false); try? await Task.sleep(for: .milliseconds(120))
                set(true); try? await Task.sleep(for: .milliseconds(90))
                set(false); try? await Task.sleep(for: .milliseconds(650))
            } }
        case .disco:
            task = Task { while !Task.isCancelled {
                if Bool.random() { set(true, Float.random(in: 0.4...1.0)) } else { set(false) }
                try? await Task.sleep(for: .milliseconds(Int.random(in: 60...170)))
            } }
        }
    }
}

struct FlashlightView: View {
    @StateObject private var torch = Torch()
    @State private var morse = ""
    @State private var screenLight = false
    @State private var mirror = false
    private let cols = [GridItem(.adaptive(minimum: 100), spacing: HandySpacing.s8)]

    var body: some View {
        ToolPage(title: "Flashlight+", subtitle: "Patterns, SOS and Morse on the LED; a full-screen light and a mirror when you need your face lit.") {
            if !torch.available { LimitNote("No flash on this device — the screen light and mirror still work.") }

            HStack(spacing: HandySpacing.s8) {
                Button { screenLight = true } label: { Label("Screen light", systemImage: "sun.max.fill").frame(maxWidth: .infinity) }.secondaryButton()
                Button { mirror = true } label: { Label("Mirror", systemImage: "person.crop.square").frame(maxWidth: .infinity) }.secondaryButton()
            }

            VStack(spacing: HandySpacing.s12) {
                Image(systemName: torch.isOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(torch.isOn ? HandyColor.accent : HandyColor.textSecondary)
                    .shadow(color: HandyColor.accent.opacity(torch.isOn ? Double(torch.level) * 0.6 : 0), radius: 22)
                HStack {
                    Text("Brightness").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Spacer()
                    Text("\(Int(torch.level * 100))%").font(HandyFont.bodyStrong).monospacedDigit()
                }
                Slider(value: $torch.level, in: 0.05...1.0).tint(HandyColor.accent)
                HandyFlow(spacing: HandySpacing.s8) {
                    Text("Auto-off").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    ForEach([0, 5, 15, 60], id: \.self) { m in HChip(text: m == 0 ? "Never" : "\(m) min", selected: torch.autoOffMinutes == m) { torch.autoOffMinutes = m } }
                }
            }
            .cardStyle()

            LazyVGrid(columns: cols, spacing: HandySpacing.s8) {
                ForEach(Torch.Mode.allCases) { m in
                    let active = torch.isOn && torch.mode == m && torch.morseText.isEmpty
                    Button {
                        HandyHaptics.light()
                        torch.select(m)
                    } label: {
                        Text(m.label)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: HandySpacing.touchTarget)
                            .foregroundStyle(active ? .white : HandyColor.textPrimary)
                            .background(active ? HandyColor.accent : HandyColor.surface, in: Capsule())
                            .overlay(Capsule().stroke(active ? Color.clear : HandyColor.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!torch.available)
                }
            }

            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Text("Morse a message").font(HandyFont.bodyStrong)
                HStack(spacing: HandySpacing.s8) {
                    TextField("e.g. HELP or your name", text: $morse)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .padding(HandySpacing.s12)
                        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    Button {
                        if !torch.morseText.isEmpty { torch.stop() } else { torch.flashMorse(morse) }
                    } label: { Text(torch.morseText.isEmpty ? "Flash it" : "Stop") }.compactButton().disabled(!torch.available || (morse.trimmingCharacters(in: .whitespaces).isEmpty && torch.morseText.isEmpty))
                }
                if !morse.isEmpty {
                    Text(Torch.encodeMorse(morse)).font(.system(.body, design: .monospaced)).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
                }
            }
            .cardStyle()

            Text(torch.isOn ? (torch.morseText.isEmpty ? "On — \(torch.mode.label). Tap it again to turn off." : "Flashing “\(torch.morseText)” in Morse. Tap Stop to end.") : "Off. Tap any pattern to start.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                .frame(maxWidth: .infinity)
                .animation(.easeOut(duration: HandyMotion.base), value: torch.isOn)
        }
        .onDisappear { torch.stop() }
        .fullScreenCover(isPresented: $screenLight) { ScreenLightSheet() }
        .fullScreenCover(isPresented: $mirror) { MirrorSheet() }
    }
}

/// The whole screen as a lamp: pick a tone, slide the brightness, tap to dismiss. Keeps the screen awake.
private struct ScreenLightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var toneIdx = 0
    @State private var brightness: Double = 1
    @State private var saved: CGFloat = UIScreen.main.brightness
    private let tones: [(String, Color)] = [("Daylight", .white), ("Warm", Color(red: 1, green: 0.93, blue: 0.8)), ("Candle", Color(red: 1, green: 0.8, blue: 0.5)), ("Night (red)", Color(red: 0.9, green: 0.1, blue: 0.05)), ("Soft blue", Color(red: 0.85, green: 0.92, blue: 1))]
    var body: some View {
        ZStack(alignment: .bottom) {
            tones[toneIdx].1.ignoresSafeArea().onTapGesture { dismiss() }
            VStack(spacing: HandySpacing.s12) {
                HStack(spacing: HandySpacing.s8) {
                    ForEach(0..<tones.count, id: \.self) { i in
                        Circle().fill(tones[i].1).frame(width: 34, height: 34)
                            .overlay(Circle().stroke(toneIdx == i ? Color.black.opacity(0.7) : Color.black.opacity(0.2), lineWidth: toneIdx == i ? 3 : 1))
                            .onTapGesture { toneIdx = i }
                            .accessibilityLabel(tones[i].0)
                    }
                }
                Slider(value: $brightness, in: 0.2...1).tint(.black.opacity(0.6)).padding(.horizontal)
                    .onChange(of: brightness) { _, b in UIScreen.main.brightness = CGFloat(b) }
                Text("Tap anywhere to close").font(HandyFont.caption).foregroundStyle(.black.opacity(0.55)).onTapGesture { dismiss() }
            }
            .padding(HandySpacing.s24)
            .background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
            .padding(HandySpacing.gutter)
        }
        .statusBarHidden()
        .onAppear { saved = UIScreen.main.brightness; UIScreen.main.brightness = 1; UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIScreen.main.brightness = saved; UIApplication.shared.isIdleTimerDisabled = false }
    }
}

/// Front camera as a mirror: zoom, freeze, and a bright white border to light your face.
private struct MirrorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cam = FrameCamera()
    @State private var holder = MetalViewHolder()
    @State private var zoom: CGFloat = 1
    @State private var frozen = false
    @State private var lit = true
    var body: some View {
        ZStack {
            (lit ? Color.white : Color.black).ignoresSafeArea()
            ProcessedFrameView(image: cam.latest, holder: holder)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(lit ? 28 : 0)
            VStack {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).padding(10).background(.ultraThinMaterial, in: Circle()) }
                    Spacer()
                    Button { lit.toggle() } label: { Image(systemName: lit ? "sun.max.fill" : "sun.max").font(.system(size: 16, weight: .bold)).padding(10).background(.ultraThinMaterial, in: Circle()) }
                }
                Spacer()
                HStack(spacing: HandySpacing.s12) {
                    Image(systemName: "minus.magnifyingglass")
                    Slider(value: $zoom, in: 1...4).onChange(of: zoom) { _, z in cam.setZoom(z) }
                    Image(systemName: "plus.magnifyingglass")
                    Button { frozen.toggle(); cam.setPaused(frozen) } label: { Image(systemName: frozen ? "play.fill" : "pause.fill").font(.system(size: 16, weight: .bold)).padding(10).background(.ultraThinMaterial, in: Circle()) }
                }
                .padding(.horizontal, HandySpacing.s16).padding(.vertical, HandySpacing.s12)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(HandySpacing.gutter)
            .foregroundStyle(lit ? .black : .white)
        }
        .statusBarHidden()
        .onAppear { cam.start(preset: .hd1280x720, position: .front); UIScreen.main.brightness = 1 }
        .onDisappear { cam.stop() }
    }
}
