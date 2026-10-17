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
    private var device: AVCaptureDevice? { AVCaptureDevice.default(for: .video) }
    var available: Bool { device?.hasTorch == true }

    /// Tap a pattern: same one while on → off; otherwise switch to it and turn on.
    func select(_ m: Mode) {
        if isOn && mode == m { stop() } else { mode = m; isOn = true; restart() }
    }

    func stop() {
        isOn = false
        task?.cancel(); task = nil
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
    private let cols = [GridItem(.adaptive(minimum: 100), spacing: HandySpacing.s8)]

    var body: some View {
        ToolPage(title: "Flashlight", subtitle: "Tap a pattern to start it, tap it again to stop. Patterns the built-in flashlight doesn't have.") {
            if !torch.available { LimitNote("No flash on this device.") }

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
            }
            .cardStyle()

            LazyVGrid(columns: cols, spacing: HandySpacing.s8) {
                ForEach(Torch.Mode.allCases) { m in
                    let active = torch.isOn && torch.mode == m
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

            Text(torch.isOn ? "On — \(torch.mode.label). Tap it again to turn off." : "Off. Tap any pattern to start.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                .frame(maxWidth: .infinity)
                .animation(.easeOut(duration: HandyMotion.base), value: torch.isOn)
        }
        .onDisappear { torch.stop() }
    }
}
