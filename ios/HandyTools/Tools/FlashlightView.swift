import SwiftUI
import AVFoundation

/// iOS exposes torch brightness as a float — the stock Control Center slider is coarse.
/// Also SOS (…---…) and a strobe. All run on the device's LED, nothing else.
@MainActor
final class Torch: ObservableObject {
    @Published var level: Float = 1.0 { didSet { if isOn { apply() } } }
    @Published var isOn = false
    @Published var mode: Mode = .steady { didSet { restart() } }
    enum Mode: String, CaseIterable { case steady = "Steady", strobe = "Strobe", sos = "SOS" }
    private var task: Task<Void, Never>?
    private var device: AVCaptureDevice? { AVCaptureDevice.default(for: .video) }
    var available: Bool { device?.hasTorch == true }

    func toggle() { isOn.toggle(); restart() }

    private func set(_ on: Bool) {
        guard let d = device, d.hasTorch else { return }
        try? d.lockForConfiguration()
        if on { try? d.setTorchModeOn(level: max(0.01, level)) } else { d.torchMode = .off }
        d.unlockForConfiguration()
    }
    private func apply() { set(true) }

    private func restart() {
        task?.cancel()
        guard isOn else { set(false); return }
        switch mode {
        case .steady: set(true)
        case .strobe:
            task = Task { while !Task.isCancelled { set(true); try? await Task.sleep(for: .milliseconds(60)); set(false); try? await Task.sleep(for: .milliseconds(60)) } }
        case .sos:
            task = Task {
                let dot: UInt64 = 200, dash: UInt64 = 600
                let pattern: [UInt64] = [dot, dot, dot, dash, dash, dash, dot, dot, dot]
                while !Task.isCancelled {
                    for d in pattern { set(true); try? await Task.sleep(for: .milliseconds(Int(d))); set(false); try? await Task.sleep(for: .milliseconds(200)) }
                    try? await Task.sleep(for: .milliseconds(1200))
                }
            }
        }
    }
}

struct FlashlightView: View {
    @StateObject private var torch = Torch()
    var body: some View {
        ToolPage(title: "Flashlight Dimmer", subtitle: "Full brightness slider, plus strobe and SOS.") {
            if !torch.available { LimitNote("No flash on this device.") }
            Button { torch.toggle() } label: {
                Label(torch.isOn ? "Turn off" : "Turn on", systemImage: torch.isOn ? "flashlight.off.fill" : "flashlight.on.fill").frame(maxWidth: .infinity)
            }.primaryButton().disabled(!torch.available)
            VStack(spacing: HandySpacing.s16) {
                Image(systemName: "lightbulb.fill").font(.system(size: 44))
                    .foregroundStyle(HandyColor.accent.opacity(torch.isOn ? 0.35 + 0.65 * Double(torch.level) : 0.25))
                    .shadow(color: HandyColor.accent.opacity(torch.isOn ? Double(torch.level) * 0.6 : 0), radius: 24)
                Text("\(Int(torch.level * 100))%").font(.system(size: 28, weight: .semibold)).monospacedDigit().contentTransition(.numericText())
                Slider(value: $torch.level, in: 0.05...1.0).tint(HandyColor.accent)
                    .frame(width: 240).rotationEffect(.degrees(-90)).frame(width: 60, height: 240)
            }
            .frame(maxWidth: .infinity)
            .cardStyle()
            HStack(spacing: HandySpacing.s8) {
                ForEach(Torch.Mode.allCases, id: \.self) { m in HChip(text: m.rawValue, selected: torch.mode == m) { torch.mode = m } }
            }
        }
        .onDisappear { if torch.isOn { torch.toggle() } }
    }
}
