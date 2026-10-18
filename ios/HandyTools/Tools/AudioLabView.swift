import SwiftUI

/// Audio Lab — the sound utilities people install four apps for: a chromatic tuner with instrument
/// presets, a tone generator (any frequency, three waveforms, pan), speaker/earbud tests, a
/// high-frequency sweep, and the 165 Hz water-eject pulse.
struct AudioLabView: View {
    private enum Kind: Int, CaseIterable { case tuner, tone, speaker, eject
        var title: String { ["Tuner", "Tone", "Speaker test", "Eject water"][rawValue] } }

    @State private var kind: Kind = .tuner
    @StateObject private var tuner = Tuner()
    @StateObject private var tone = ToneGenerator()
    @State private var preset = 0
    @State private var a4: Double = 440
    private let presets: [(String, [Int])] = [("Chromatic", []), ("Guitar", [40, 45, 50, 55, 59, 64]), ("Bass", [28, 33, 38, 43]), ("Ukulele", [67, 60, 64, 69]), ("Violin", [55, 62, 69, 76])]
    @State private var ejecting = false

    var body: some View {
        ToolPage(title: "Audio Lab", subtitle: "Tune an instrument, generate any tone, test your speakers and earbuds, or shake water out of them.") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HandySpacing.s8) {
                    ForEach(Kind.allCases, id: \.rawValue) { k in HChip(text: k.title, selected: kind == k) { switchTo(k) } }
                }
            }
            switch kind {
            case .tuner: tunerPanel
            case .tone: tonePanel
            case .speaker: speakerPanel
            case .eject: ejectPanel
            }
        }
        .onAppear { if kind == .tuner { tuner.start() } }
        .onChange(of: a4) { _, v in tuner.a4 = v }
        .onDisappear { tuner.stop(); tone.stop() }
    }

    private func switchTo(_ k: Kind) {
        guard k != kind else { return }
        tuner.stop(); tone.stop(); ejecting = false
        kind = k
        if k == .tuner { tuner.start() }
    }

    // MARK: tuner

    private var tunerPanel: some View {
        VStack(spacing: HandySpacing.s12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HandySpacing.s8) { ForEach(0..<presets.count, id: \.self) { i in HChip(text: presets[i].0, selected: preset == i) { preset = i } } }
            }
            let inTune = abs(tuner.cents) < 5 && tuner.clarity > 0.85
            ZStack {
                // cents needle −50…50
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(HandyColor.surface).frame(height: 10).frame(maxHeight: .infinity, alignment: .center)
                        Rectangle().fill(HandyColor.success.opacity(0.35)).frame(width: w * 0.1, height: 10).offset(x: w * 0.45).frame(maxHeight: .infinity, alignment: .center)
                        Rectangle().fill(HandyColor.textSecondary).frame(width: 2, height: 24).offset(x: w / 2 - 1).frame(maxHeight: .infinity, alignment: .center)
                        Capsule().fill(inTune ? HandyColor.success : HandyColor.accent).frame(width: 6, height: 40)
                            .offset(x: w / 2 - 3 + CGFloat(max(-50, min(50, tuner.clarity > 0.85 ? tuner.cents : 0))) / 50 * (w / 2 - 6))
                            .animation(.easeOut(duration: 0.08), value: tuner.cents)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                }.frame(height: 48)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(tuner.clarity > 0.85 ? tuner.note : "—").font(.system(size: 80, weight: .bold, design: .rounded))
                Text(tuner.clarity > 0.85 ? "\(tuner.octave)" : "").font(.system(size: 30, weight: .semibold)).foregroundStyle(HandyColor.textSecondary)
            }.foregroundStyle(inTune ? HandyColor.success : HandyColor.textPrimary)
            Text(tuner.clarity > 0.85 ? String(format: "%.1f Hz · %@%.0f cents", tuner.hz, tuner.cents >= 0 ? "+" : "", tuner.cents) : "Play a single note…")
                .font(HandyFont.caption).monospacedDigit().foregroundStyle(HandyColor.textSecondary)
            if !presets[preset].1.isEmpty {
                HStack(spacing: HandySpacing.s8) {
                    ForEach(presets[preset].1, id: \.self) { midi in
                        let n = Pitch.note(for: Pitch.frequency(midi: midi, a4: a4), a4: a4)
                        let active = tuner.clarity > 0.85 && n.name == tuner.note && n.octave == tuner.octave
                        Text("\(n.name)\(n.octave)").font(HandyFont.bodyStrong).frame(maxWidth: .infinity, minHeight: 40)
                            .background(active ? HandyColor.accentSoft : HandyColor.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(active ? HandyColor.accent : HandyColor.border))
                            .onTapGesture { tone.frequency = Pitch.frequency(midi: midi, a4: a4); tone.wave = .sine; tone.volume = 0.5; tone.pan = 0; tone.start(); Task { try? await Task.sleep(for: .seconds(1.5)); tone.stop() } }
                    }
                }
                Text("Tap a string to hear the reference pitch.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            HStack { Text("A4 = \(Int(a4)) Hz").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary); Stepper("", value: $a4, in: 415...466).labelsHidden(); Spacer() }
            if tuner.denied { LimitNote("Microphone access is off. Allow it in Settings to tune.") }
        }
    }

    // MARK: tone

    private var tonePanel: some View {
        VStack(spacing: HandySpacing.s12) {
            Text(tone.frequency < 1000 ? String(format: "%.1f Hz", tone.frequency) : String(format: "%.2f kHz", tone.frequency / 1000))
                .font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit()
            Slider(value: Binding(get: { log10(tone.frequency) }, set: { tone.frequency = pow(10, $0) }), in: log10(20)...log10(20000)).tint(HandyColor.accent)
            HStack(spacing: HandySpacing.s8) {
                ForEach([("50", 50.0), ("100", 100), ("440", 440), ("1k", 1000), ("5k", 5000), ("10k", 10000), ("15k", 15000)], id: \.1) { l, f in HChip(text: l, selected: abs(tone.frequency - f) < 0.5) { tone.frequency = f } }
            }
            HStack(spacing: HandySpacing.s8) {
                ForEach(ToneGenerator.Wave.allCases, id: \.rawValue) { w in HChip(text: w.title, selected: tone.wave == w) { tone.wave = w } }
                Spacer()
            }
            HStack { Image(systemName: "speaker.wave.1"); Slider(value: $tone.volume, in: 0...1).tint(HandyColor.accent); Image(systemName: "speaker.wave.3") }.foregroundStyle(HandyColor.textSecondary)
            HStack { Text("L").font(HandyFont.caption); Slider(value: $tone.pan, in: -1...1).tint(HandyColor.accent); Text("R").font(HandyFont.caption) }.foregroundStyle(HandyColor.textSecondary)
            Button { tone.playing ? tone.stop() : tone.start() } label: { Label(tone.playing ? "Stop" : "Play tone", systemImage: tone.playing ? "stop.fill" : "play.fill").frame(maxWidth: .infinity) }.primaryButton()
            Text("Start quiet with earbuds. Pure tones above ~16 kHz are inaudible for most adults — that's normal.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    // MARK: speaker test

    private var speakerPanel: some View {
        VStack(spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s8) {
                Button { play(pan: -1) } label: { Label("Left", systemImage: "l.circle").frame(maxWidth: .infinity) }.secondaryButton()
                Button { play(pan: 0) } label: { Label("Both", systemImage: "circle.grid.2x1").frame(maxWidth: .infinity) }.secondaryButton()
                Button { play(pan: 1) } label: { Label("Right", systemImage: "r.circle").frame(maxWidth: .infinity) }.secondaryButton()
            }
            Button { tone.volume = 0.6; tone.wave = .sine; tone.pan = 0; tone.sweep(from: 40, to: 16000, seconds: 10) } label: { Label("Full sweep 40 Hz → 16 kHz (10 s)", systemImage: "waveform.path").frame(maxWidth: .infinity) }.secondaryButton()
            Button { tone.volume = 0.5; tone.wave = .sine; tone.pan = 0; tone.sweep(from: 8000, to: 20000, seconds: 12) } label: { Label("How high can you hear? 8 → 20 kHz", systemImage: "ear").frame(maxWidth: .infinity) }.secondaryButton()
            Button { tone.volume = 0.8; tone.wave = .sine; tone.pan = 0; tone.frequency = 45; tone.start() } label: { Label("Bass rattle check — 45 Hz", systemImage: "speaker.wave.3.fill").frame(maxWidth: .infinity) }.secondaryButton()
            if tone.playing { Button { tone.stop() } label: { Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity) }.primaryButton() }
            Text("Left/Right confirms a swapped or dead channel; the sweep exposes buzzes and dropouts. The hearing sweep is a fun check, not a medical test.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private func play(pan: Double) {
        tone.frequency = 440; tone.wave = .sine; tone.volume = 0.5; tone.pan = pan; tone.start()
        Task { try? await Task.sleep(for: .seconds(1.2)); if abs(tone.pan - pan) < 0.01 { tone.stop() } }
    }

    // MARK: eject

    private var ejectPanel: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "drop.fill").font(.system(size: 56)).foregroundStyle(HandyColor.accent).symbolEffect(.pulse, isActive: ejecting)
            Text(ejecting ? "Pulsing… hold the phone speaker-down." : "Phone or earbuds get wet? 165 Hz pulses push water out of the speaker grille, like a sports watch does.")
                .font(HandyFont.body).multilineTextAlignment(.center).foregroundStyle(HandyColor.textSecondary)
            Button {
                if ejecting { tone.stop(); ejecting = false } else { tone.waterEject(); ejecting = true; Task { try? await Task.sleep(for: .seconds(12.5)); ejecting = false } }
            } label: { Label(ejecting ? "Stop" : "Eject water (12 s)", systemImage: ejecting ? "stop.fill" : "drop.triangle").frame(maxWidth: .infinity) }.primaryButton()
            Text("Turn volume to max, unplug earbuds, run it 2–3 times. Dry the port with a cloth afterwards — don't use heat.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }.padding(.top, HandySpacing.s16)
    }
}
