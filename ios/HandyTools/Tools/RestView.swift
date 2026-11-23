import SwiftUI
import AVFoundation
import MediaPlayer

/// Rest — sleep sounds that never loop (synthesized live), a sleep timer that fades, and a night
/// recorder that only keeps the moments something was loud: snoring, talking, the cat, the neighbour.
/// Wake up to a short list of clips with times, not an eight-hour file. Everything stays on the phone.
struct RestView: View {
    @StateObject private var player = NoisePlayer()
    @StateObject private var recorder = NightRecorder()
    @State private var tab = 0
    @State private var playingClip: URL?
    @State private var bedOn = RestNight.on
    @State private var bedTime = Calendar.current.date(bySettingHour: RestNight.hour, minute: RestNight.minute, second: 0, of: Date()) ?? Date()
    @State private var bedNote: String?
    @State private var notifyOff = false

    var body: some View {
        ToolPage(title: "Sleep Sounds", subtitle: "Rich sleep sounds you can mix — rain, waves, fire, birdsong, bowls and more — with a fading timer, a bedtime nudge, and a recorder that keeps only the noisy moments.") {
            HowTo("rest", [
                "Tap a sound to play it — rain, waves, a campfire, birds, a singing bowl and more.",
                "Tap two or three to mix them and set each one's level, or tap a ready-made mix.",
                "Set a sleep timer so it fades out on its own. It keeps playing with the screen locked.",
                "Turn on the bedtime nudge once; every night it reminds you to wind down.",
                "Night recorder: start it, put the phone by the bed, and see in the morning when it was noisy.",
            ])
            Picker(L(""), selection: $tab) { Text(L("Sounds")).tag(0); Text(L("Night recorder")).tag(1) }.pickerStyle(.segmented)
            if tab == 0 { soundsPanel } else { recorderPanel }
        }
        .onDisappear { if !player.playing && !recorder.armed { player.stop() } }
    }

    // MARK: sounds

    private var soundsPanel: some View {
        VStack(spacing: HandySpacing.s20) {
            mixCard
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                shelf("Ready-made mixes", "One tap plays sounds that belong together.")
                RestThreeUp(count: NoiseSynth.mixes.count) { i in mixTile(NoiseSynth.mixes[i]) }
            }
            ForEach(NoiseSynth.Group.allCases) { g in
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    shelf(g.title, Self.blurb(g))
                    RestThreeUp(count: g.kinds.count) { i in soundTile(g.kinds[i]) }
                }
            }
            Text(L("Keeps playing with the screen locked. Every sound is made live on your phone, so it never loops. Brown, Fan and Roof rain mask traffic and snoring best."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
            bedtimeCard
        }
    }

    /// The hero: what's playing, each sound's own level, one big play button, volume and the sleep timer.
    private var mixCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L(player.playing ? "Now playing" : "Your mix")).font(HandyFont.micro).textCase(.uppercase).tracking(0.8)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(player.layers.isEmpty ? L("Pick up to three sounds") : player.title)
                        .font(HandyFont.title).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.7)
                }
                Spacer(minLength: HandySpacing.s8)
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { player.playPause() } } label: {
                    Image(systemName: player.playing ? "pause.fill" : "play.fill").font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: 0x2A1F5C))
                        .frame(width: 56, height: 56)
                        .background(Color.white, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L(player.playing ? "Pause" : "Play"))
                .accessibilityIdentifier("rest-play")
            }
            if player.layers.isEmpty {
                Text(L("Tap sounds below to layer them — rain with a crackling fire, waves with a breeze. Each gets its own level."))
                    .font(HandyFont.caption).foregroundStyle(.white.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(player.layers) { layerRow($0) }
            }
            if let note = player.note {
                Text(note).font(HandyFont.caption).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: HandySpacing.s8) {
                Image(systemName: "speaker.wave.1")
                Slider(value: $player.volume, in: 0...1).tint(.white).accessibilityLabel(L("Volume"))
                Image(systemName: "speaker.wave.3")
            }
            .foregroundStyle(.white.opacity(0.8))
            timerRow
        }
        .padding(HandySpacing.s16)
        .background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [Color(hex: 0x12143A), Color(hex: 0x2A2266), Color(hex: 0x5A2D7E)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFE9B0).opacity(0.32), .clear], center: .center, startRadius: 2, endRadius: 90))
                    .frame(width: 180, height: 180).offset(x: 50, y: -60)
                RestStars().opacity(player.playing ? 1 : 0.55)
            }
            .clipShape(RoundedRectangle(cornerRadius: HandyRadius.card + 4, style: .continuous))
            .accessibilityHidden(true)
        }
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.card + 4, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: Color(hex: 0x3B2A7A).opacity(0.35), radius: 14, y: 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: player.layers)
    }

    private func layerRow(_ layer: NoisePlayer.Layer) -> some View {
        HStack(spacing: HandySpacing.s8) {
            Image(systemName: layer.kind.icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(LinearGradient(colors: Self.tint(layer.kind.group), startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                .accessibilityHidden(true)
            Text(L(layer.kind.title)).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7).frame(width: 88, alignment: .leading)
            Slider(value: Binding(get: { layer.level }, set: { player.setLevel(layer.kind, $0) }), in: 0.05...1).tint(.white)
                .accessibilityLabel("\(L(layer.kind.title)) \(L("level"))")
            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { player.remove(layer.kind) } } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                    .frame(width: 28, height: 28).background(.white.opacity(0.15), in: Circle())
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(L("Remove")) \(L(layer.kind.title))")
        }
    }

    private var timerRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(L("Sleep timer"), systemImage: "timer").font(.system(size: 13, weight: .semibold))
                Spacer()
                if let r = player.remaining {
                    Text("\(L("fades out in")) \(GeoFormat.duration(r))").font(HandyFont.caption).monospacedDigit()
                }
            }
            .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 6) {
                ForEach([0, 15, 30, 45, 60, 90], id: \.self) { m in
                    let on = player.timerMinutes == m
                    Button { player.setTimer(minutes: m) } label: {
                        Text(m == 0 ? L("Off") : "\(m) min").font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
                            .foregroundStyle(on ? Color(hex: 0x2A1F5C) : .white)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(on ? Color.white : Color.white.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private func shelf(_ title: String, _ blurb: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L(title)).font(HandyFont.cardTitle).foregroundStyle(HandyColor.textPrimary).accessibilityAddTraits(.isHeader)
            Text(L(blurb)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func soundTile(_ k: NoiseSynth.Kind) -> some View {
        let on = player.isOn(k)
        let colors = Self.tint(k.group)
        let shape = RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous)
        return Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { player.toggle(k) } } label: {
            VStack(spacing: HandySpacing.s8) {
                Image(systemName: k.icon).font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(on ? Color.white : colors[0])
                    .frame(width: 40, height: 40)
                    .background(on ? Color.white.opacity(0.18) : colors[0].opacity(0.14), in: Circle())
                Text(L(k.title)).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(on ? Color.white : HandyColor.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 92)
            .background {
                if on { shape.fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)) }
                else { shape.fill(HandyColor.surface) }
            }
            .overlay(shape.stroke(on ? Color.white.opacity(0.22) : HandyColor.border, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if on {
                    Image(systemName: player.playing ? "speaker.wave.2.fill" : "checkmark").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white).padding(8)
                }
            }
            .shadow(color: on ? colors[0].opacity(0.35) : .clear, radius: 8, y: 4)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L(k.title))
        .accessibilityValue(on ? L("In your mix") : "")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func mixTile(_ m: NoiseSynth.Mix) -> some View {
        let on = player.playing && player.isMix(m)
        let shape = RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous)
        return Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { player.play(m) } } label: {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: m.icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                Spacer(minLength: 4)
                Text(L(m.title)).font(.system(size: 13, weight: .bold)).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.8)
                Text(m.layers.map { L($0.kind.title) }.joined(separator: " · ")).font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82)).lineLimit(2).minimumScaleFactor(0.8)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .background(LinearGradient(colors: Self.mixColors(m.id), startPoint: .topLeading, endPoint: .bottomTrailing), in: shape)
            .overlay(shape.stroke(Color.white.opacity(on ? 0.9 : 0.15), lineWidth: on ? 2 : 1))
            .overlay(alignment: .topTrailing) {
                if on { Image(systemName: "speaker.wave.2.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white).padding(9) }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L(m.title))
        .accessibilityValue(on ? L("Playing") : m.layers.map { L($0.kind.title) }.joined(separator: ", "))
        .accessibilityIdentifier("rest-mix-\(m.id)")
    }

    static func blurb(_ g: NoiseSynth.Group) -> String {
        switch g {
        case .nature: return "Rain, waves, wind and wild things."
        case .noise: return "Steady sound that hides traffic and snoring."
        case .calm: return "Slow tones and heartbeats to breathe with."
        }
    }
    static func tint(_ g: NoiseSynth.Group) -> [Color] {
        switch g {
        case .nature: return [Color(hex: 0x138A6B), Color(hex: 0x34B37E)]
        case .noise: return [Color(hex: 0x3446A0), Color(hex: 0x6274E0)]
        case .calm: return [Color(hex: 0x7B3FA8), Color(hex: 0xD9578F)]
        }
    }
    static func mixColors(_ id: String) -> [Color] {
        switch id {
        case "cabin": return [Color(hex: 0x8A3B12), Color(hex: 0xD9772B)]
        case "summer": return [Color(hex: 0x0F2A4A), Color(hex: 0x2E6B5E)]
        case "beach": return [Color(hex: 0x0B4F79), Color(hex: 0x2BA3C4)]
        case "deep": return [Color(hex: 0x1B1D3F), Color(hex: 0x4B3F8F)]
        case "meditate": return [Color(hex: 0x5B2C83), Color(hex: 0xC2588F)]
        default: return [Color(hex: 0x6A4C93), Color(hex: 0xE59CB5)]
        }
    }

    // MARK: recorder

    private var recorderPanel: some View {
        VStack(spacing: HandySpacing.s12) {
            VStack(spacing: HandySpacing.s8) {
                HStack {
                    Circle().fill(recorder.armed ? (recorder.capturing ? HandyColor.danger : HandyColor.success) : HandyColor.border).frame(width: 12, height: 12)
                    Text(recorder.armed ? (recorder.capturing ? "Recording a loud moment…" : "Listening — quiet") : "Off").font(HandyFont.bodyStrong)
                    Spacer()
                    Text("\(Int(recorder.db)) dB").font(HandyFont.caption).monospacedDigit().foregroundStyle(HandyColor.textSecondary)
                }
                if recorder.armed { Text("Room baseline \(Int(recorder.baseline)) dB · triggers above \(Int(recorder.baseline + 12)) dB").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading) }
                Button { recorder.armed ? recorder.stop() : recorder.start() } label: {
                    Label(recorder.armed ? "Stop for tonight" : "Start listening", systemImage: recorder.armed ? "stop.fill" : "moon.zzz.fill").frame(maxWidth: .infinity)
                }.primaryButton()
                if recorder.denied { LimitNote("Microphone access is off. Allow it in Settings to record.") }
            }.cardStyle()

            if recorder.events.isEmpty {
                Text(L("Nothing captured yet. Plug the phone in, put it on the nightstand, start listening, and check back in the morning.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            } else {
                if let sm = RestNight.summary(recorder.events.map { (date: $0.date, seconds: $0.seconds, peakDB: $0.peakDB) }) { nightCard(sm) }
                HStack {
                    Text("\(recorder.events.count) moment\(recorder.events.count == 1 ? "" : "s") · \(GeoFormat.duration(recorder.events.reduce(0) { $0 + $1.seconds })) total").font(HandyFont.bodyStrong)
                    Spacer()
                    Button(role: .destructive) { recorder.clearAll(); playingClip = nil } label: { Text(L("Clear all")) }.textButton()
                }
                ForEach(recorder.events.reversed()) { e in
                    HStack(spacing: HandySpacing.s12) {
                        Button { toggle(e) } label: { Image(systemName: playingClip == e.url ? "stop.circle.fill" : "play.circle.fill").accessibilityLabel(L("Play")).font(.system(size: 30)).foregroundStyle(HandyColor.accent) }.buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.date.formatted(date: .abbreviated, time: .shortened)).font(HandyFont.bodyStrong)
                            Text("\(GeoFormat.duration(e.seconds)) · peak \(Int(e.peakDB)) dB").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        }
                        Spacer()
                        ShareLink(item: e.url) { Image(systemName: "square.and.arrow.up") }.buttonStyle(.plain).foregroundStyle(HandyColor.textSecondary)
                        Button(role: .destructive) { recorder.delete(e) } label: { Image(systemName: "trash").accessibilityLabel(L("Delete")) }.buttonStyle(.plain).foregroundStyle(HandyColor.textSecondary)
                    }.cardStyle(padding: HandySpacing.s12)
                }
            }
            Text(L("Clips live only on this phone. A noisy night usually comes back as 5–40 short clips.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    /// Last night at a glance: how many noisy moments, how long, and which hour was the worst.
    private func nightCard(_ sm: RestNight.Summary) -> some View {
        let top = sm.byHour.map(\.seconds).max() ?? 1
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Last night")).font(HandyFont.bodyStrong)
            Text("\(sm.count) \(L(sm.count == 1 ? "noisy moment" : "noisy moments")) · \(GeoFormat.duration(sm.seconds)) · \(L("loudest")) \(Int(sm.loudestDB)) dB")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            if let h = sm.busiestHour {
                Text("\(L("Noisiest around")) \(RestNight.hourLabel(h))").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.accent)
            }
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(sm.byHour, id: \.hour) { b in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3).fill(HandyColor.accent.opacity(b.hour == sm.busiestHour ? 1 : 0.45))
                            .frame(height: max(4, 60 * b.seconds / max(1, top)))
                        Text(RestNight.hourLabel(b.hour)).font(.system(size: 9)).foregroundStyle(HandyColor.textSecondary).lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(RestNight.hourLabel(b.hour)): \(GeoFormat.duration(b.seconds))")
                }
            }
            .frame(height: 80)
        }
        .cardStyle()
    }

    /// A nightly "time to wind down" nudge — set once, Test run proves it.
    private var bedtimeCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Toggle(isOn: $bedOn) { Label(L("Bedtime nudge"), systemImage: "bed.double.fill").font(HandyFont.bodyStrong) }
                .tint(HandyColor.accent).accessibilityIdentifier("rest-bedtime")
            Text(L("Every night at this time, a gentle reminder to wind down — tap it to start your sound and the recorder.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            DatePicker(L("Remind me at"), selection: $bedTime, displayedComponents: .hourAndMinute).font(HandyFont.caption)
            NotificationsOffCard(isOff: $notifyOff)
            Button {
                Task {
                    guard await NotifyPermission.ensure() else { notifyOff = true; return }
                    await RestNight.testRun(); bedNote = L("Test sent — it arrives in 5 seconds."); bedNote = await NotifyCheck.report()
                }
            } label: { Label(L("Test run"), systemImage: "checkmark.seal").frame(maxWidth: .infinity) }.secondaryButton()
            if let bedNote { Text(bedNote).font(HandyFont.caption).foregroundStyle(HandyColor.success) }
        }
        .cardStyle(padding: HandySpacing.s12)
        .onChange(of: bedOn) { _, _ in saveBedtime() }
        .onChange(of: bedTime) { _, _ in if bedOn { saveBedtime() } }
    }

    private func saveBedtime() {
        let c = Calendar.current.dateComponents([.hour, .minute], from: bedTime)
        Task {
            if bedOn, !(await NotifyPermission.ensure()) { notifyOff = true; bedOn = false; return }
            await RestNight.set(on: bedOn, hour: c.hour ?? 22, minute: c.minute ?? 0)
            bedNote = bedOn ? "\(L("On — every night at")) \(bedTime.formatted(date: .omitted, time: .shortened))." : nil
        }
    }

    private func toggle(_ e: NightRecorder.Event) {
        if playingClip == e.url { recorder.stopPlayback(); playingClip = nil }
        else { recorder.play(e); playingClip = e.url }
    }
}

/// Equal-width rows of three, so every shelf on the Sounds page lines up (a short last row keeps its spacing).
private struct RestThreeUp<Cell: View>: View {
    let count: Int
    @ViewBuilder let cell: (Int) -> Cell
    var body: some View {
        VStack(spacing: HandySpacing.s8) {
            ForEach(Array(stride(from: 0, to: count, by: 3)), id: \.self) { row in
                HStack(spacing: HandySpacing.s8) {
                    ForEach(row..<min(row + 3, count), id: \.self) { i in cell(i).frame(maxWidth: .infinity) }
                    ForEach(0..<max(0, row + 3 - count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 0) }
                }
            }
        }
    }
}

/// A quiet sky of stars for the Your mix card — fixed positions, drawn once.
private struct RestStars: View {
    var body: some View {
        Canvas { ctx, size in
            var seed: UInt64 = 0x5EED
            func next() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 33) / CGFloat(1 << 31) }
            for _ in 0..<46 {
                let p = CGPoint(x: next() * size.width, y: next() * size.height)
                let r = 0.5 + next() * 1.3
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.25 + 0.55 * next())))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - noise player

/// Plays a mix of up to three sleep sounds at once, each at its own level. The sounds are synthesised on the audio
/// thread; changing the mix crossfades (no clicks), and the last mix is remembered for next time.
@MainActor final class NoisePlayer: ObservableObject {
    struct Layer: Identifiable, Equatable {
        var kind: NoiseSynth.Kind
        var level: Double
        var id: Int { kind.rawValue }
    }
    @Published private(set) var layers: [Layer] = NoisePlayer.savedMix()
    @Published var playing = false
    @Published var volume: Double = 0.7 { didSet { shared.master = Float(volume) } }
    @Published var timerMinutes = 0
    @Published var remaining: Double? = nil
    /// A one-line note after the mix changes on its own (a fourth sound swapped one out).
    @Published var note: String?

    /// What is playing, in words: "Rain + Campfire".
    var title: String { layers.map { L($0.kind.title) }.joined(separator: " + ") }
    func isOn(_ k: NoiseSynth.Kind) -> Bool { layers.contains { $0.kind == k } }
    func isMix(_ m: NoiseSynth.Mix) -> Bool { Set(layers.map(\.kind)) == Set(m.layers.map(\.kind)) }

    /// Slots the audio thread reads. The main thread writes `kinds`/`gains`; everything else is the audio thread's own.
    private final class Shared: @unchecked Sendable {
        let n = NoiseSynth.maxLayers
        let kinds: UnsafeMutablePointer<Int32>      // wanted sound per slot, -1 = empty
        let gains: UnsafeMutablePointer<Float>
        let sounding: UnsafeMutablePointer<Int32>   // what the slot is actually rendering (fades out before it changes)
        let current: UnsafeMutablePointer<Float>    // the slot's level right now, gliding toward its gain
        let states: UnsafeMutablePointer<NoiseSynth.State>
        var master: Float = 0.7
        var fade: Float = 1
        init() {
            let n = NoiseSynth.maxLayers
            kinds = .allocate(capacity: n); kinds.initialize(repeating: -1, count: n)
            gains = .allocate(capacity: n); gains.initialize(repeating: 0, count: n)
            sounding = .allocate(capacity: n); sounding.initialize(repeating: -1, count: n)
            current = .allocate(capacity: n); current.initialize(repeating: 0, count: n)
            states = .allocate(capacity: n)
            for i in 0..<n { (states + i).initialize(to: NoiseSynth.State()) }   // each its own storage: no copy-on-write on the audio thread
        }
        deinit {
            kinds.deallocate(); gains.deallocate(); sounding.deallocate(); current.deallocate()
            states.deinitialize(count: n); states.deallocate()
        }
    }
    private let shared = Shared()
    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode?
    private var timer: Task<Void, Never>?

    init() { shared.master = Float(volume); sync() }

    // MARK: the mix

    /// Tap a sound: on if it's off, off if it's on. A fourth sound replaces the one added first.
    func toggle(_ k: NoiseSynth.Kind) {
        note = nil
        if isOn(k) { remove(k); return }
        if layers.count >= NoiseSynth.maxLayers {
            let gone = layers.removeFirst()
            note = "\(L(gone.kind.title)) \(L("made way — a mix holds three sounds."))"
        }
        layers.append(Layer(kind: k, level: layers.isEmpty ? 0.8 : 0.55))
        sync()
        if !playing { start() }
    }

    func remove(_ k: NoiseSynth.Kind) {
        layers.removeAll { $0.kind == k }
        sync()
        if layers.isEmpty {
            // let the fade finish, then let go of the audio session
            Task { try? await Task.sleep(for: .milliseconds(400)); if self.layers.isEmpty { self.stop() } }
        }
    }

    func setLevel(_ k: NoiseSynth.Kind, _ v: Double) {
        guard let i = layers.firstIndex(where: { $0.kind == k }) else { return }
        layers[i].level = v
        sync()
    }

    /// One tap on a ready-made mix plays it (tap it again to stop).
    func play(_ m: NoiseSynth.Mix) {
        note = nil
        if isMix(m) && playing { stop(); return }
        layers = m.layers.map { Layer(kind: $0.kind, level: $0.level) }
        sync()
        if !playing { start() }
    }

    func playPause() {
        if playing { stop(); return }
        if layers.isEmpty { layers = [Layer(kind: .brown, level: 0.8)]; sync() }
        start()
    }

    /// Give each sound a stable slot so changing one never restarts the others.
    private func sync() {
        let n = NoiseSynth.maxLayers
        let wanted = layers.prefix(n)
        for s in 0..<n where shared.kinds[s] >= 0 && !wanted.contains(where: { Int32($0.kind.rawValue) == shared.kinds[s] }) { shared.kinds[s] = -1 }
        for l in wanted {
            let id = Int32(l.kind.rawValue)
            let slot = (0..<n).first { shared.kinds[$0] == id } ?? (0..<n).first { shared.kinds[$0] == -1 }
            guard let s = slot else { continue }
            shared.gains[s] = Float(l.level)
            shared.kinds[s] = id
        }
        Self.save(layers)
        if playing { updateNowPlaying() }
    }

    // MARK: playback

    func start() {
        if playing || layers.isEmpty { return }
        let session = AVAudioSession.sharedInstance()
        // Take over "now playing" (no mixWithOthers) so the sound appears on the Lock Screen and
        // Control Center with a stop control — otherwise you can't turn it off after walking away.
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        let hwRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let rate = hwRate > 0 ? hwRate : 44_100   // hardware can report 0 before the route is ready
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else { return }
        let sh = shared
        sh.fade = 1
        let n = AVAudioSourceNode(format: fmt) { _, _, frames, abl -> OSStatus in
            let bufs = UnsafeMutableAudioBufferListPointer(abl)
            guard bufs.count >= 2, let l = bufs[0].mData?.assumingMemoryBound(to: Float.self), let r = bufs[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let slots = sh.n
            // A slot changes sound only once its old sound has faded out.
            for s in 0..<slots where sh.sounding[s] != sh.kinds[s] && sh.current[s] < 0.0005 {
                sh.sounding[s] = sh.kinds[s]
                if sh.kinds[s] >= 0 { sh.states[s].reset() }
            }
            let g = sh.master * sh.fade
            for i in 0..<Int(frames) {
                var L: Float = 0, R: Float = 0
                for s in 0..<slots {
                    let playingKind = sh.sounding[s]
                    guard playingKind >= 0, let k = NoiseSynth.Kind(rawValue: Int(playingKind)) else { continue }
                    let target: Float = sh.kinds[s] == playingKind ? sh.gains[s] : 0
                    sh.current[s] += (target - sh.current[s]) * 0.0004        // ~50 ms glide: no clicks
                    let f = sh.states[s].frame(k, sampleRate: rate)
                    L += f.0 * sh.current[s]; R += f.1 * sh.current[s]
                }
                l[i] = tanhf(L) * g; r[i] = tanhf(R) * g
            }
            return noErr
        }
        engine.attach(n); engine.connect(n, to: engine.mainMixerNode, format: fmt); node = n
        try? engine.start()
        playing = engine.isRunning
        if playing { wireRemoteCommands(); updateNowPlaying() }
        if timerMinutes > 0 { setTimer(minutes: timerMinutes) }
    }

    func stop() {
        timer?.cancel(); timer = nil; remaining = nil
        engine.stop(); if let n = node { engine.detach(n); node = nil }
        // start the next play fresh: every slot fades in from silence
        for s in 0..<shared.n { shared.sounding[s] = -1; shared.current[s] = 0 }
        playing = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Lock Screen / Control Center

    private var commandsWired = false
    private func wireRemoteCommands() {
        guard !commandsWired else { return }
        commandsWired = true
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.start() }; return .success }
        c.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.stop() }; return .success }
        c.stopCommand.addTarget { [weak self] _ in Task { @MainActor in self?.stop() }; return .success }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playPause() }
            return .success
        }
    }

    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title.isEmpty ? L("Sleep sounds") : title,
            MPMediaItemPropertyArtist: "Tenzy · Sleep sounds",
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
        ]
    }

    func setTimer(minutes: Int) {
        timerMinutes = minutes
        timer?.cancel(); timer = nil; remaining = nil
        guard minutes > 0, playing else { return }
        let total = Double(minutes * 60)
        remaining = total
        timer = Task {
            var left = total
            while left > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1)); left -= 1
                self.remaining = left
                if left < 60 { self.shared.fade = Float(max(0, left / 60)) }   // last minute fades out
            }
            if !Task.isCancelled { self.stop(); self.timerMinutes = 0 }
        }
    }

    // MARK: remembered mix

    private static let mixKey = "rest.mix"
    /// "4:0.80,11:0.55" — sound number and level.
    static func encode(_ layers: [Layer]) -> String { layers.map { "\($0.kind.rawValue):\(String(format: "%.2f", $0.level))" }.joined(separator: ",") }
    static func decode(_ s: String) -> [Layer] {
        var out: [Layer] = []
        for part in s.split(separator: ",") {
            let f = part.split(separator: ":")
            guard f.count == 2, let n = Int(f[0]), let k = NoiseSynth.Kind(rawValue: n), let v = Double(f[1]), !out.contains(where: { $0.kind == k }) else { continue }
            out.append(Layer(kind: k, level: min(1, max(0, v))))
        }
        return Array(out.prefix(NoiseSynth.maxLayers))
    }
    private static func savedMix() -> [Layer] { decode(UserDefaults.standard.string(forKey: mixKey) ?? "") }
    private static func save(_ layers: [Layer]) { UserDefaults.standard.set(encode(layers), forKey: mixKey) }
}

// MARK: - night recorder

@MainActor final class NightRecorder: ObservableObject {
    struct Event: Identifiable, Codable, Equatable {
        var id = UUID(); var date: Date; var seconds: Double; var peakDB: Double; var file: String
        var url: URL { NightRecorder.dir.appendingPathComponent(file) }
    }
    @Published var armed = false
    @Published var capturing = false
    @Published var denied = false
    @Published var db = 0.0
    @Published var baseline = 35.0
    @Published var events: [Event] = NightRecorder.loadEvents()

    nonisolated static let dir: URL = {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Rest", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    private let engine = AVAudioEngine()
    private var detector = SoundEventDetector()
    private var file: AVAudioFile?
    private var fileStart = Date()
    private var startTime = Date()
    private var player: AVAudioPlayer?
    private let offset = UserDefaults.standard.double(forKey: "instruments.db.offset")

    func start() {
        Permission.microphone { [weak self] ok in
            Task { @MainActor in
                guard let self else { return }
                if !ok { self.denied = true; return }
                self.begin()
            }
        }
    }
    private func begin() {
        let session = AVAudioSession.sharedInstance()
        if MicCheck.onCall { MicCheck.announce(.onCall); return }
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth])
        try? session.setActive(true)
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        guard fmt.sampleRate > 0 else { MicCheck.announce(MicCheck.diagnose()); return }
        detector = SoundEventDetector()
        startTime = Date()
        input.installSendableTap(bufferSize: 4096, format: fmt) { [weak self] buf, when in
            guard let ch = buf.floatChannelData?[0] else { return }
            var sum: Float = 0
            let n = Int(buf.frameLength)
            for i in 0..<n { sum += ch[i] * ch[i] }
            let rms = sqrt(sum / Float(max(1, n)))
            let power = Double(20 * log10(max(rms, 1e-6)))
            nonisolated(unsafe) let b = buf
            Task { @MainActor in self?.handle(power: power, buffer: b) }
        }
        try? engine.start()
        armed = engine.isRunning
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func handle(power: Double, buffer: AVAudioPCMBuffer) {
        let level = SensorMath.dbSPL(fromPower: power, offset: offset)
        db = level; baseline = detector.baselineDB
        let t = Date().timeIntervalSince(startTime)
        switch detector.feed(db: level, at: t) {
        case .start:
            let name = "rest-\(Int(Date().timeIntervalSince1970)).caf"
            file = try? AVAudioFile(forWriting: Self.dir.appendingPathComponent(name), settings: buffer.format.settings)
            fileStart = Date(); capturing = file != nil
        case .stop:
            if let f = file, let ev = detector.events.last {
                let e = Event(date: fileStart, seconds: ev.end - ev.start, peakDB: ev.peakDB, file: f.url.lastPathComponent)
                events.append(e); Self.saveEvents(events)
            }
            file = nil; capturing = false
        case .none: break
        }
        if capturing, let f = file { try? f.write(from: buffer) }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0); engine.stop()
        if file != nil { file = nil; capturing = false }
        armed = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func play(_ e: Event) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers]); try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: e.url); player?.play()
    }
    func stopPlayback() { player?.stop(); player = nil }
    func delete(_ e: Event) { try? FileManager.default.removeItem(at: e.url); events.removeAll { $0.id == e.id }; Self.saveEvents(events) }
    func clearAll() { for e in events { try? FileManager.default.removeItem(at: e.url) }; events = []; Self.saveEvents(events) }

    nonisolated private static var index: URL { dir.appendingPathComponent("events.json") }
    nonisolated private static func loadEvents() -> [Event] { (try? JSONDecoder().decode([Event].self, from: Data(contentsOf: index))) ?? [] }
    private static func saveEvents(_ e: [Event]) { try? JSONEncoder().encode(e).write(to: index) }
}
