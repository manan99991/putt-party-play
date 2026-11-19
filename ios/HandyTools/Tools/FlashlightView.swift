import SwiftUI
import AVFoundation
import UserNotifications

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
    @Published var morseUnitMs = 180
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
    func flashMorse(_ text: String, unitMs: Int? = nil) {
        let unitMs = unitMs ?? morseUnitMs
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

    /// Coming back to the app (e.g. after a lock or a call): if the torch was meant to be on, relight it.
    func resumeIfNeeded() {
        guard isOn, morseText.isEmpty else { return }
        restart()
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var morse = ""
    @State private var screenLight = false
    @State private var mirror = false
    @State private var emergency = false
    @State private var siren = true
    @State private var alertTest: String?
    @State private var sosNote: String?
    @State private var notifyOff = false
    private let cols = [GridItem(.adaptive(minimum: 100), spacing: HandySpacing.s8)]

    var body: some View {
        ToolPage(title: "Flashlight+", subtitle: "Patterns, SOS and Morse on the LED, an emergency light with a siren, a screen light and a mirror — and a one-press SOS from your Action button.") {
            HowTo("light", [
                "Tap a pattern to turn the torch on; tap it again to turn it off.",
                "Set the brightness and an auto-off timer so it won't drain your battery.",
                "Emergency light flashes SOS on the LED and the screen and can sound a siren — for being found in the dark.",
                "Set up once: put SOS on your Action button or Back Tap, and make the flash blink when someone calls.",
            ])
            Button { emergency = true } label: {
                Label(L("Emergency light"), systemImage: "light.beacon.max.fill").frame(maxWidth: .infinity)
            }
            .primaryButton().tint(HandyColor.danger)
            .accessibilityIdentifier("light-emergency")
            .accessibilityHint(L("Flashes SOS on the light and the whole screen, with an optional siren"))
            Toggle(L("Sound a siren with it"), isOn: $siren).font(HandyFont.caption).tint(HandyColor.accent)
            if !torch.available { LimitNote("No flash on this device — the screen light and mirror still work.") }

            HStack(spacing: HandySpacing.s8) {
                Button { screenLight = true } label: { Label(L("Screen light"), systemImage: "sun.max.fill").frame(maxWidth: .infinity) }.secondaryButton()
                Button { mirror = true } label: { Label(L("Mirror"), systemImage: "person.crop.square").frame(maxWidth: .infinity) }.secondaryButton()
            }

            VStack(spacing: HandySpacing.s12) {
                Image(systemName: torch.isOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(torch.isOn ? HandyColor.accent : HandyColor.textSecondary)
                    .shadow(color: HandyColor.accent.opacity(torch.isOn ? Double(torch.level) * 0.6 : 0), radius: 22)
                HStack {
                    Text(L("Brightness")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Spacer()
                    Text("\(Int(torch.level * 100))%").font(HandyFont.bodyStrong).monospacedDigit()
                }
                Slider(value: $torch.level, in: 0.05...1.0).tint(HandyColor.accent)
                HandyFlow(spacing: HandySpacing.s8) {
                    Text(L("Auto-off")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
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
                Text(L("Morse a message")).font(HandyFont.bodyStrong)
                HStack(spacing: HandySpacing.s8) {
                    TextField(L("e.g. HELP or your name"), text: $morse)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .padding(HandySpacing.s12)
                        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    Button {
                        if !torch.morseText.isEmpty { torch.stop() } else { torch.flashMorse(morse) }
                    } label: { Text(torch.morseText.isEmpty ? "Flash it" : "Stop") }.compactButton().disabled(!torch.available || (morse.trimmingCharacters(in: .whitespaces).isEmpty && torch.morseText.isEmpty))
                }
                HandyFlow(spacing: HandySpacing.s8) {
                    Text(L("Speed")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    ForEach(TorchExtras.morseSpeeds, id: \.unitMs) { sp in
                        HChip(text: L(sp.label), selected: torch.morseUnitMs == sp.unitMs) { torch.morseUnitMs = sp.unitMs }
                    }
                }
                if !morse.isEmpty, TorchExtras.morseSeconds(morse, unitMs: torch.morseUnitMs) > 0 {
                    Text("\(L("One pass takes about")) \(Int(TorchExtras.morseSeconds(morse, unitMs: torch.morseUnitMs).rounded(.up))) \(L("seconds, then it repeats."))")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                if !morse.isEmpty {
                    Text(Torch.encodeMorse(morse)).font(.system(.body, design: .monospaced)).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
                }
            }
            .cardStyle()

            quickStartCard
            ringFlashCard

            Text(torch.isOn ? (torch.morseText.isEmpty ? "On — \(torch.mode.label). Tap it again to turn off." : "Flashing “\(torch.morseText)” in Morse. Tap Stop to end.") : "Off. Tap any pattern to start.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                .frame(maxWidth: .infinity)
                .animation(.easeOut(duration: HandyMotion.base), value: torch.isOn)
        }
        // Keep the phone awake while the LED is lit: iOS drops the torch the moment the screen
        // locks or the app leaves the foreground, so an auto-lock would silently kill it.
        .onChange(of: torch.isOn) { _, on in UIApplication.shared.isIdleTimerDisabled = on }
        .onChange(of: scenePhase) { _, phase in if phase == .active { torch.resumeIfNeeded() } }
        // A full-screen cover can count as leaving this page; the emergency light owns the torch then.
        .onDisappear { if !emergency { torch.stop(); UIApplication.shared.isIdleTimerDisabled = false } }
        .onAppear { takeShortcut() }
        .onReceive(NotificationCenter.default.publisher(for: .openTool)) { n in if (n.object as? String) == "light" { takeShortcut() } }
        .fullScreenCover(isPresented: $screenLight) { ScreenLightSheet() }
        .fullScreenCover(isPresented: $emergency) { EmergencyLightSheet(torch: torch, siren: siren) }
        .fullScreenCover(isPresented: $mirror) { MirrorSheet() }
    }

    /// A shortcut (Action button, Back Tap, Siri) asked for a pattern: start it the moment the page opens.
    private func takeShortcut() {
        guard let p = TorchExtras.takePending() else { return }
        if p == "emergency" { emergency = true; return }
        if let m = Torch.Mode(rawValue: p), torch.available, !(torch.isOn && torch.mode == m) { torch.select(m) }
    }

    /// Set once: SOS from the Action button, Back Tap or Siri, without unlocking and hunting for the app.
    private var quickStartCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("One press to SOS"), systemImage: "bolt.fill").font(HandyFont.bodyStrong)
            Text(L("Put the light on a button so it's there in the dark. Do this once and it's always ready."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array([
                    "Action button (iPhone 15 Pro and later): Settings → Action Button → swipe to Shortcut → choose Tenzy → Flashlight pattern.",
                    "Back Tap (any recent iPhone): first open Shortcuts → + → add Tenzy's Flashlight pattern → pick SOS. Then Settings → Accessibility → Touch → Back Tap → Double Tap → choose that shortcut.",
                    "Siri: just say “Start SOS light in Tenzy” — nothing to set up.",
                ].enumerated()), id: \.offset) { i, line in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(i + 1).").font(HandyFont.caption.monospacedDigit()).foregroundStyle(HandyColor.accent)
                        Text(L(line)).font(HandyFont.caption).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            HStack(spacing: HandySpacing.s8) {
                Button { if let u = URL(string: "shortcuts://") { UIApplication.shared.open(u) } } label: {
                    Label(L("Open Shortcuts"), systemImage: "square.2.layers.3d").frame(maxWidth: .infinity)
                }.secondaryButton()
                Button {
                    // Test run: exactly what the button will do — SOS starts, then stops by itself.
                    if !(torch.isOn && torch.mode == .sos && torch.morseText.isEmpty) { torch.select(.sos) }
                    sosNote = "SOS is flashing — that's what your button will do. It stops in 6 seconds."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) { if torch.isOn && torch.mode == .sos { torch.stop() }; sosNote = nil }
                } label: { Label(L("Test run"), systemImage: "checkmark.seal").frame(maxWidth: .infinity) }
                .secondaryButton().disabled(!torch.available).accessibilityIdentifier("light-sos-test")
            }
            if let sosNote { Text(L(sosNote)).font(HandyFont.caption).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true) }
        }
        .cardStyle()
    }

    /// iPhone can blink the flash for calls and alerts — a built-in setting most people never find.
    private var ringFlashCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Flash when someone calls"), systemImage: "phone.badge.waveform.fill").font(HandyFont.bodyStrong)
            Text(L("See calls and messages in a loud room or with the sound off: iPhone can blink its flash for every call and alert. It's built into iPhone — Tenzy shows you where."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array([
                    "Open Settings → Accessibility → Audio & Visual.",
                    "Turn on LED Flash for Alerts. Turn on Flash on Silent too, if you want it with the ringer off.",
                    "Tap Test run below, then lock your phone and wait 10 seconds.",
                ].enumerated()), id: \.offset) { i, line in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(i + 1).").font(HandyFont.caption.monospacedDigit()).foregroundStyle(HandyColor.accent)
                        Text(L(line)).font(HandyFont.caption).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            NotificationsOffCard(isOff: $notifyOff)
            Button { Task { await ringTest() } } label: {
                Label(L("Test run"), systemImage: "checkmark.seal").frame(maxWidth: .infinity)
            }.secondaryButton().accessibilityIdentifier("light-ring-test")
            if let alertTest { Text(L(alertTest)).font(HandyFont.caption).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true) }
        }
        .cardStyle()
    }

    private func ringTest() async {
        guard await NotifyPermission.ensure() else { notifyOff = true; return }
        notifyOff = false
        let c = UNMutableNotificationContent()
        c.title = L("Flashlight+ test"); c.body = L("Did the flash blink? Then calls and alerts will blink it too."); c.sound = .default
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "light-flash-test", content: c,
                                                                                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)))
        alertTest = "Lock your phone now. In 10 seconds a test alert arrives — if the flash blinks, you're set."
    }
}

/// Emergency: SOS on the LED and the whole screen at full brightness, with a siren that plays even
/// on silent. One big Stop. Keeps the phone awake so it keeps going until you stop it.
private struct EmergencyLightSheet: View {
    @ObservedObject var torch: Torch
    let siren: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var bright = true
    @State private var player: AVAudioPlayer?
    @State private var flasher: Task<Void, Never>?
    @State private var saved: CGFloat = UIScreen.main.brightness
    @State private var sound = true

    var body: some View {
        ZStack {
            (bright ? Color.white : Color.red).ignoresSafeArea()
            VStack(spacing: HandySpacing.s16) {
                Text("SOS").font(.system(size: 96, weight: .black)).foregroundStyle(bright ? Color.red : Color.white)
                    .accessibilityLabel(L("Emergency light is on"))
                Spacer()
                if siren {
                    Button { sound.toggle(); sound ? player?.play() : player?.pause() } label: {
                        Label(sound ? L("Mute siren") : L("Siren on"), systemImage: sound ? "speaker.slash.fill" : "speaker.wave.3.fill")
                            .font(HandyFont.bodyStrong).padding(.horizontal, 20).padding(.vertical, 12)
                            .background(.black.opacity(0.75), in: Capsule()).foregroundStyle(.white)
                    }
                }
                Button { dismiss() } label: {
                    Text(L("Stop")).font(.system(size: 28, weight: .bold)).frame(maxWidth: .infinity, minHeight: 72)
                        .background(.black, in: RoundedRectangle(cornerRadius: 22, style: .continuous)).foregroundStyle(.white)
                }
                .accessibilityIdentifier("emergency-stop")
            }
            .padding(HandySpacing.gutter)
        }
        .statusBarHidden()
        .onAppear(perform: start)
        .onDisappear(perform: end)
    }

    private func start() {
        saved = UIScreen.main.brightness
        UIScreen.main.brightness = 1
        UIApplication.shared.isIdleTimerDisabled = true
        if torch.available, !(torch.isOn && torch.mode == .sos && torch.morseText.isEmpty) { torch.select(.sos) }
        if siren {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)   // plays even with the ringer off
            try? AVAudioSession.sharedInstance().setActive(true)
            if let p = try? AVAudioPlayer(data: TorchExtras.sirenWAV()) { p.numberOfLoops = -1; p.volume = 1; p.play(); player = p }
        }
        // The screen flashes the same SOS rhythm as the LED: · · · — — — · · ·
        flasher = Task { @MainActor in
            let pattern = [200, 200, 200, 600, 600, 600, 200, 200, 200]
            while !Task.isCancelled {
                for d in pattern { bright = false; try? await Task.sleep(for: .milliseconds(d)); bright = true; try? await Task.sleep(for: .milliseconds(200)) }
                try? await Task.sleep(for: .milliseconds(1200))
            }
        }
    }

    private func end() {
        flasher?.cancel(); flasher = nil
        player?.stop(); player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        torch.stop()
        UIScreen.main.brightness = saved
        UIApplication.shared.isIdleTimerDisabled = false
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
                Text(L("Tap anywhere to close")).font(HandyFont.caption).foregroundStyle(.black.opacity(0.55)).onTapGesture { dismiss() }
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
                .overlay {
                    if !cam.authorized {
                        PermissionOffCard(line: "Camera access is off", sub: "The mirror needs the front camera. Turn it on in Settings.")
                            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
                            .padding(HandySpacing.gutter)
                    }
                }
            VStack {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "xmark").accessibilityLabel(L("Close")).font(.system(size: 16, weight: .bold)).padding(10).background(.ultraThinMaterial, in: Circle()) }
                    Spacer()
                    Button { lit.toggle() } label: { Image(systemName: lit ? "sun.max.fill" : "sun.max").accessibilityLabel(L("Brightness")).font(.system(size: 16, weight: .bold)).padding(10).background(.ultraThinMaterial, in: Circle()) }
                }
                Spacer()
                HStack(spacing: HandySpacing.s12) {
                    Image(systemName: "minus.magnifyingglass")
                    Slider(value: $zoom, in: 1...4).onChange(of: zoom) { _, z in cam.setZoom(z) }
                    Image(systemName: "plus.magnifyingglass")
                    Button { frozen.toggle(); cam.setPaused(frozen) } label: { Image(systemName: frozen ? "play.fill" : "pause.fill").accessibilityLabel(L("Freeze")).font(.system(size: 16, weight: .bold)).padding(10).background(.ultraThinMaterial, in: Circle()) }
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
