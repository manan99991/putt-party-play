import SwiftUI
import AVFoundation

/// Flashlight+ — the "flashlight" power tool (prototype SCREENS.flashlight). A re-skin of the legacy
/// FlashlightView around the same `Torch` engine: lamp indicator, Turn on / Screen light, pattern
/// chips, brightness, a Morse message with progress, Mirror and a Colour lamp. The torch goes off and
/// the screen brightness comes back when you leave. No torch (simulator, iPad)? The patterns run on
/// the lamp indicator and the screen light does the lighting.
struct FlashlightHub: View {
    @StateObject private var torch = Torch()
    @State private var pattern: Torch.Mode = .steady
    @State private var morse = "HELP"
    @State private var screenLight = false
    @State private var mirror = false
    @State private var colourLamp = false
    private static let patterns: [Torch.Mode] = [.steady, .strobeMed, .sos, .beacon, .pulse, .candle, .heartbeat, .disco]

    var body: some View {
        PowerToolPage(id: "flashlight") {
            lampCard
            mainButtons
            patternSection
            brightnessSection
            morseSection
            extrasSection
        }
        .onDisappear { torch.stop() }
        .fullScreenCover(isPresented: $screenLight) { ScreenLightSheet() }
        .fullScreenCover(isPresented: $mirror) { MirrorSheet() }
        .fullScreenCover(isPresented: $colourLamp) { ColourLampSheet() }
    }

    // MARK: lamp indicator (prototype #fl-lamp / #fl-state)

    private var lampCard: some View {
        let a = Double(torch.lit ? torch.litLevel : 0)
        return VStack(spacing: HandySpacing.s12) {
            ZStack {
                Circle().fill(torch.lit ? Color(red: 1, green: 0.95, blue: 0.78).opacity(0.35 + a * 0.65) : HandyColor.border.opacity(0.6))
                    .frame(width: 120, height: 120)
                    .shadow(color: Color(red: 1, green: 0.92, blue: 0.63).opacity(a * 0.8), radius: a > 0 ? 30 * a : 0)
                Image(systemName: torch.lit ? "flashlight.on.fill" : "flashlight.off.fill").font(.system(size: 36))
                    .foregroundStyle(torch.lit ? Color.black.opacity(0.55) : HandyColor.textSecondary)
            }
            Text(stateText).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, HandySpacing.s16).cardStyle()
    }

    private var stateText: String {
        if !torch.morseText.isEmpty { return "Flashing “\(torch.morseText)” in Morse" }
        return torch.isOn ? "On · \(torch.mode.label)" : "Off"
    }

    // MARK: sections (prototype order: buttons → pattern → brightness → morse → mirror/colour)

    @ViewBuilder private var mainButtons: some View {
        HStack(spacing: HandySpacing.s8) {
            Button { toggleTorch() } label: {
                Label(torch.isOn ? "Turn off" : "Turn on", systemImage: torch.isOn ? "power" : "lightbulb.fill").frame(maxWidth: .infinity)
            }.primaryButton()
            Button { screenLight = true } label: { Label("Screen light", systemImage: "sun.max.fill").frame(maxWidth: .infinity) }.secondaryButton()
        }
        if !torch.available { HubPill("No torch on this device — patterns show on the lamp above; Screen light does the lighting", tone: .native) }
    }

    @ViewBuilder private var patternSection: some View {
        HubSection("Pattern")
        FlowLayout(spacing: 8) {
            ForEach(Self.patterns) { m in HubChip(m.label, selected: pattern == m) { select(m) } }
        }
    }

    @ViewBuilder private var brightnessSection: some View {
        HubSection("Brightness \(Int(torch.level * 100))%")
        Slider(value: $torch.level, in: 0.1...1).tint(HandyColor.accent)
        FlowLayout(spacing: 8) {
            HubPill("Auto-off")
            ForEach([0, 5, 15, 60], id: \.self) { m in HubChip(m == 0 ? "Never" : "\(m) min", selected: torch.autoOffMinutes == m) { torch.autoOffMinutes = m } }
        }
    }

    @ViewBuilder private var morseSection: some View {
        HubSection("Morse message")
        HStack(spacing: HandySpacing.s8) {
            TextField("Type a message to flash…", text: $morse)
                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                .padding(HandySpacing.s12)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            Button { flashMorse() } label: { Text(torch.morseText.isEmpty ? "Flash" : "Stop") }.compactButton()
                .disabled(morse.trimmingCharacters(in: .whitespaces).isEmpty && torch.morseText.isEmpty)
        }
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(HandyColor.border.opacity(0.5))
                Capsule().fill(HandyColor.accent).frame(width: g.size.width * CGFloat(min(1, max(0, torch.morseProgress))))
            }
        }
        .frame(height: 6)
        if !morse.isEmpty {
            Text(Torch.encodeMorse(morse)).font(.system(.body, design: .monospaced)).foregroundStyle(HandyColor.textSecondary).lineLimit(3)
        }
    }

    @ViewBuilder private var extrasSection: some View {
        HStack(spacing: HandySpacing.s8) {
            Button { mirror = true } label: { Label("Mirror", systemImage: "person.crop.square").frame(maxWidth: .infinity) }.secondaryButton()
            Button { colourLamp = true } label: { Label("Colour lamp", systemImage: "paintpalette").frame(maxWidth: .infinity) }.secondaryButton()
        }
        HubNote("Patterns, Morse and brightness run on the phone's torch LED. Screen light and Colour lamp use the display — tap to close them, and your brightness comes back.")
    }

    // MARK: actions

    private func toggleTorch() {
        HandyHaptics.light()
        if torch.isOn { torch.stop() } else { torch.select(pattern) }
    }

    /// Pick a pattern: remembered for the next Turn on; switches live when the torch is already on.
    private func select(_ m: Torch.Mode) {
        pattern = m; HandyHaptics.light()
        guard torch.isOn else { return }
        if !torch.morseText.isEmpty { torch.stop(); torch.select(m) }
        else if torch.mode != m { torch.select(m) }
    }

    private func flashMorse() {
        HandyHaptics.light()
        if !torch.morseText.isEmpty { torch.stop(); return }
        let text = morse.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        torch.flashMorse(text, repeats: false)
    }
}

/// Full-screen colour lamp: tap to cycle colours, hold (or Close) to leave. Screen at full brightness
/// while open, restored after.
private struct ColourLampSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var saved: CGFloat = UIScreen.main.brightness
    private let colours: [(String, Color)] = [
        ("Red", Color(red: 1, green: 0.42, blue: 0.42)), ("Yellow", Color(red: 1, green: 0.82, blue: 0.4)),
        ("Green", Color(red: 0.02, green: 0.84, blue: 0.63)), ("Blue", Color(red: 0.3, green: 0.67, blue: 0.97)),
        ("Purple", Color(red: 0.78, green: 0.49, blue: 1)), ("White", .white),
    ]
    var body: some View {
        ZStack(alignment: .bottom) {
            colours[index].1.ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { index = (index + 1) % colours.count; HandyHaptics.light() }
                .onLongPressGesture(minimumDuration: 0.6) { dismiss() }
            VStack(spacing: HandySpacing.s8) {
                Text(colours[index].0).font(HandyFont.bodyStrong).foregroundStyle(.black.opacity(0.55))
                Text("Tap to change colour · hold to close").font(HandyFont.caption).foregroundStyle(.black.opacity(0.5))
                Button { dismiss() } label: {
                    Text("Close").font(HandyFont.bodyStrong).foregroundStyle(.black.opacity(0.7))
                        .padding(.horizontal, HandySpacing.s24).frame(minHeight: HandySpacing.touchTarget)
                        .background(.white.opacity(0.45), in: Capsule())
                }.buttonStyle(.plain).accessibilityLabel("Close colour lamp")
            }
            .padding(.bottom, HandySpacing.s32)
        }
        .statusBarHidden()
        .onAppear { saved = UIScreen.main.brightness; UIScreen.main.brightness = 1; UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIScreen.main.brightness = saved; UIApplication.shared.isIdleTimerDisabled = false }
    }
}
