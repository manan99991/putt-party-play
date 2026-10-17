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
            ZStack {
                Circle().trim(from: 0.125, to: 0.875).stroke(HandyColor.border, style: StrokeStyle(lineWidth: 14, lineCap: .round)).rotationEffect(.degrees(90))
                Circle().trim(from: 0.125, to: 0.125 + 0.75 * min(m.db, 120) / 120)
                    .stroke(AngularGradient(gradient: gradient, center: .center, startAngle: .degrees(135), endAngle: .degrees(405)), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(90)).animation(.easeOut(duration: HandyMotion.fast), value: m.db)
                Circle().trim(from: 0.125 + 0.75 * min(m.peak, 120) / 120 - 0.004, to: 0.125 + 0.75 * min(m.peak, 120) / 120 + 0.004)
                    .stroke(HandyColor.textPrimary, style: StrokeStyle(lineWidth: 18, lineCap: .butt)).rotationEffect(.degrees(90))
                VStack(spacing: 2) {
                    Text("\(Int(m.db))").font(.system(size: 72, weight: .thin)).monospacedDigit().contentTransition(.numericText())
                    Text("dB (approx.)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Text(label(m.db)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.accent).padding(.top, HandySpacing.s4)
                }
            }
            .frame(width: 220, height: 220).frame(maxWidth: .infinity).padding(.vertical, HandySpacing.s8)
            HStack { Text("Peak").font(HandyFont.body); Spacer(); Text("\(Int(m.peak)) dB").font(HandyFont.bodyStrong).monospacedDigit() }.cardStyle()
            Button { m.running ? m.stop() : m.start() } label: { Label(m.running ? "Stop" : "Start", systemImage: m.running ? "stop.fill" : "mic.fill").frame(maxWidth: .infinity) }
                .primaryButton()
            if m.denied { Text("Microphone access is off. Enable it in Settings › Oddbox.").font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            LimitNote("Phone mics aren't calibrated lab gear; treat this as ±5 dB.")
        }
        .onDisappear { m.stop() }
    }
    private var gradient: Gradient { Gradient(colors: [.green, .yellow, .orange, .red]) }
    private func label(_ d: Double) -> String {
        switch d { case ..<30: "Whisper quiet"; case ..<50: "Quiet room"; case ..<65: "Conversation"; case ..<80: "Busy street"; case ..<95: "Loud. Limit exposure."; default: "Very loud. Protect your ears." }
    }
}
