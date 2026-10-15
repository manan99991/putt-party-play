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
            if !torch.available { Text("No flash on this device.").foregroundStyle(.secondary) }
            Button { torch.toggle() } label: {
                Label(torch.isOn ? "Turn off" : "Turn on", systemImage: torch.isOn ? "flashlight.off.fill" : "flashlight.on.fill").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).controlSize(.large).disabled(!torch.available)
            Text("Brightness \(Int(torch.level * 100))%").font(.headline)
            Slider(value: $torch.level, in: 0.05...1.0)
            Picker("Mode", selection: $torch.mode) { ForEach(Torch.Mode.allCases, id: \.self) { Text($0.rawValue) } }.pickerStyle(.segmented)
        }
        .onDisappear { if torch.isOn { torch.toggle() } }
    }
}
