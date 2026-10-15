import SwiftUI
import AVFoundation

/// Live sound level. Measures only — nothing is recorded to disk (we write to /dev/null).
@MainActor
final class DecibelMeter: ObservableObject {
    @Published var db: Double = 0
    @Published var peak: Double = 0
    @Published var running = false
    @Published var denied = false
    private var rec: AVAudioRecorder?
    private var timer: Timer?

    func start() {
        AVAudioApplication.requestRecordPermission { ok in
            Task { @MainActor in
                guard ok else { self.denied = true; return }
                try? AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement)
                try? AVAudioSession.sharedInstance().setActive(true)
                let settings: [String: Any] = [AVFormatIDKey: kAudioFormatAppleLossless, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1]
                self.rec = try? AVAudioRecorder(url: URL(fileURLWithPath: "/dev/null"), settings: settings)
                self.rec?.isMeteringEnabled = true
                self.rec?.record()
                self.running = true; self.peak = 0
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in Task { @MainActor in self.tick() } }
            }
        }
    }

    private func tick() {
        rec?.updateMeters()
        // AVAudioRecorder gives dBFS (−160…0). Map to an approximate dB SPL. Uncalibrated — fine for "is this loud".
        let dbfs = Double(rec?.averagePower(forChannel: 0) ?? -160)
        db = max(0, dbfs + 100)
        peak = max(peak, db)
    }

    func stop() { timer?.invalidate(); rec?.stop(); rec = nil; running = false; try? AVAudioSession.sharedInstance().setActive(false) }
}

struct DecibelMeterView: View {
    @StateObject private var m = DecibelMeter()
    var body: some View {
        ToolPage(title: "Decibel Meter", subtitle: "Is the restaurant too loud? Is the baby room quiet? Now you know.") {
            VStack(spacing: 4) {
                Text("\(Int(m.db))").font(.system(size: 96, weight: .thin)).monospacedDigit().contentTransition(.numericText())
                Text("dB (approx.)").foregroundStyle(.secondary)
                Text(label(m.db)).font(.headline).foregroundStyle(.tint)
            }.frame(maxWidth: .infinity)
            Gauge(value: m.db, in: 0...120) { Text("") }.gaugeStyle(.accessoryLinearCapacity).tint(gradient)
            HStack { Text("Peak"); Spacer(); Text("\(Int(m.peak)) dB").monospacedDigit() }.font(.callout)
            Button { m.running ? m.stop() : m.start() } label: { Label(m.running ? "Stop" : "Start", systemImage: m.running ? "stop.fill" : "mic.fill").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large)
            if m.denied { Text("Microphone access is off. Enable it in Settings › HandyTools.").font(.caption).foregroundStyle(.red) }
            Text("Phone mics aren't calibrated lab gear; treat this as ±5 dB.").font(.caption2).foregroundStyle(.tertiary)
        }
        .onDisappear { m.stop() }
    }
    private var gradient: Gradient { Gradient(colors: [.green, .yellow, .orange, .red]) }
    private func label(_ d: Double) -> String {
        switch d { case ..<30: "Whisper quiet"; case ..<50: "Quiet room"; case ..<65: "Conversation"; case ..<80: "Busy street"; case ..<95: "Loud. Limit exposure."; default: "Very loud. Protect your ears." }
    }
}
