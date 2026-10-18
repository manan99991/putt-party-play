import SwiftUI
import AVFoundation

/// Three pocket instruments in one: a bubble level, a compass, and a sound meter. Replaces the old
/// one-trick tools so the home stays clean.
struct MeasureView: View {
    @State private var mode = 0
    var body: some View {
        ToolPage(title: "Measure", subtitle: "Level, compass, and sound — pick one.") {
            Picker("", selection: $mode) {
                Text("Level").tag(0); Text("Compass").tag(1); Text("Sound").tag(2)
            }.pickerStyle(.segmented)
            switch mode {
            case 0: LevelGauge()
            case 1: CompassGauge()
            default: SoundGauge()
            }
        }
    }
}

// MARK: Level (reuses Motion)

private struct LevelGauge: View {
    @StateObject private var mo = Motion()
    var body: some View {
        VStack(spacing: HandySpacing.s16) {
            ZStack {
                Circle().stroke(HandyColor.border, lineWidth: 2).frame(width: 240, height: 240)
                Circle().stroke(HandyColor.border.opacity(0.5), lineWidth: 1).frame(width: 84, height: 84)
                Circle().fill(mo.level ? HandyColor.success : HandyColor.accent).frame(width: 56, height: 56)
                    .offset(x: CGFloat(mo.x) * 110, y: CGFloat(mo.y) * 110)
                    .animation(.easeOut(duration: 0.1), value: mo.x)
            }.frame(maxWidth: .infinity).padding(.top, HandySpacing.s16)
            Text(String(format: "%.1f°", mo.angle)).font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(mo.level ? HandyColor.success : HandyColor.textPrimary).frame(maxWidth: .infinity)
        }.onAppear { mo.start() }.onDisappear { mo.stop() }
    }
}

// MARK: Compass (reuses Heading)

private struct CompassGauge: View {
    @StateObject private var h = Heading()
    var body: some View {
        VStack {
            ZStack {
                Circle().stroke(HandyColor.border, lineWidth: 2)
                ForEach(0..<12) { i in
                    Rectangle().fill(HandyColor.textSecondary).frame(width: i % 3 == 0 ? 3 : 1, height: i % 3 == 0 ? 16 : 10)
                        .offset(y: -108).rotationEffect(.degrees(Double(i) * 30))
                }
                Text("N").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.danger).offset(y: -126)
                VStack(spacing: 0) {
                    Text("\(Int(h.degrees))°").font(.system(size: 48, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(h.cardinal).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                }
            }
            .frame(width: 250, height: 260).rotationEffect(.degrees(-h.degrees)).animation(.easeOut(duration: 0.15), value: h.degrees)
            .padding(.top, HandySpacing.s16).frame(maxWidth: .infinity)
            if !h.available {
                Text("Compass needs location access — enable it in Settings.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            }
        }.onAppear { h.start() }.onDisappear { h.stop() }
    }
}

// MARK: Sound meter

private struct SoundGauge: View {
    @StateObject private var s = SoundLevel()
    var body: some View {
        VStack(spacing: HandySpacing.s16) {
            ZStack {
                Circle().stroke(HandyColor.border, lineWidth: 10).frame(width: 220, height: 220)
                Circle().trim(from: 0, to: CGFloat(min(s.db, 120) / 120)).stroke(color(for: s.db), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90)).frame(width: 220, height: 220).animation(.easeOut(duration: 0.1), value: s.db)
                VStack(spacing: 0) {
                    Text("\(Int(s.db))").font(.system(size: 52, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("dB").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                }
            }.padding(.top, HandySpacing.s16)
            Text(label(for: s.db)).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
            if s.denied { Text("Microphone is off. Enable it in Settings.").font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }.frame(maxWidth: .infinity).onAppear { s.start() }.onDisappear { s.stop() }
    }
    private func color(for db: Double) -> Color { db < 70 ? HandyColor.success : db < 90 ? HandyColor.accent : HandyColor.danger }
    private func label(for db: Double) -> String {
        switch db { case ..<40: return "Quiet"; case ..<60: return "Conversation"; case ..<80: return "Busy street"; case ..<100: return "Loud — be careful"; default: return "Very loud — protect your ears" }
    }
}

@MainActor
final class SoundLevel: ObservableObject {
    @Published var db: Double = 0
    @Published var denied = false
    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func start() {
        AVAudioApplication.requestRecordPermission { [weak self] ok in
            Task { @MainActor in
                guard let self else { return }
                if !ok { self.denied = true; return }
                self.begin()
            }
        }
    }

    private func begin() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let url = URL(fileURLWithPath: "/dev/null")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleIMA4), AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue,
        ]
        recorder = try? AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.record()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    private func sample() {
        guard let r = recorder else { return }
        r.updateMeters()
        // Map dBFS (-160…0) to a friendly ~30…120 dB SPL scale.
        let power = r.averagePower(forChannel: 0)
        let normalized = max(0, (power + 60) / 60)   // 0…1 over the top 60 dBFS
        db = 30 + normalized * 90
    }

    func stop() {
        timer?.invalidate(); timer = nil
        recorder?.stop(); recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
