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

    var body: some View {
        ToolPage(title: "Rest", subtitle: "Sleep sounds with a fading timer, and a recorder that only keeps the noisy moments of the night.") {
            Picker("", selection: $tab) { Text("Sounds").tag(0); Text("Night recorder").tag(1) }.pickerStyle(.segmented)
            if tab == 0 { soundsPanel } else { recorderPanel }
        }
        .onDisappear { if !player.playing && !recorder.armed { player.stop() } }
    }

    // MARK: sounds

    private var soundsPanel: some View {
        VStack(spacing: HandySpacing.s12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: HandySpacing.s8)], spacing: HandySpacing.s8) {
                ForEach(NoiseSynth.Kind.allCases, id: \.rawValue) { k in
                    let active = player.playing && player.kind == k
                    Button { if active { player.stop() } else { player.kind = k; player.start() } } label: {
                        VStack(spacing: 6) {
                            Image(systemName: k.icon).font(.system(size: 22))
                            Text(k.title).font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .foregroundStyle(active ? .white : HandyColor.textPrimary)
                        .background(active ? HandyColor.accent : HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(active ? Color.clear : HandyColor.border, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }
            HStack { Image(systemName: "speaker.wave.1"); Slider(value: $player.volume, in: 0...1).tint(HandyColor.accent); Image(systemName: "speaker.wave.3") }.foregroundStyle(HandyColor.textSecondary)
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                HStack { Text("Sleep timer").font(HandyFont.bodyStrong); Spacer()
                    if let r = player.remaining { Text("fades out in \(GeoFormat.duration(r))").font(HandyFont.caption).monospacedDigit().foregroundStyle(HandyColor.accent) } }
                HandyFlow(spacing: HandySpacing.s8) {
                    ForEach([0, 15, 30, 45, 60, 90], id: \.self) { m in HChip(text: m == 0 ? "Off" : "\(m) min", selected: player.timerMinutes == m) { player.setTimer(minutes: m) } }
                }
            }.cardStyle(padding: HandySpacing.s12)
            Text("Keeps playing with the screen locked. Brown and Fan mask traffic and snoring best; Pink is the one studies use for deeper sleep.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
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
                Text("Nothing captured yet. Plug the phone in, put it on the nightstand, start listening, and check back in the morning.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            } else {
                HStack {
                    Text("\(recorder.events.count) moment\(recorder.events.count == 1 ? "" : "s") · \(GeoFormat.duration(recorder.events.reduce(0) { $0 + $1.seconds })) total").font(HandyFont.bodyStrong)
                    Spacer()
                    Button(role: .destructive) { recorder.clearAll(); playingClip = nil } label: { Text("Clear all") }.textButton()
                }
                ForEach(recorder.events.reversed()) { e in
                    HStack(spacing: HandySpacing.s12) {
                        Button { toggle(e) } label: { Image(systemName: playingClip == e.url ? "stop.circle.fill" : "play.circle.fill").font(.system(size: 30)).foregroundStyle(HandyColor.accent) }.buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.date.formatted(date: .abbreviated, time: .shortened)).font(HandyFont.bodyStrong)
                            Text("\(GeoFormat.duration(e.seconds)) · peak \(Int(e.peakDB)) dB").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        }
                        Spacer()
                        ShareLink(item: e.url) { Image(systemName: "square.and.arrow.up") }.buttonStyle(.plain).foregroundStyle(HandyColor.textSecondary)
                        Button(role: .destructive) { recorder.delete(e) } label: { Image(systemName: "trash") }.buttonStyle(.plain).foregroundStyle(HandyColor.textSecondary)
                    }.cardStyle(padding: HandySpacing.s12)
                }
            }
            Text("Clips live only on this phone. A noisy night usually comes back as 5–40 short clips.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private func toggle(_ e: NightRecorder.Event) {
        if playingClip == e.url { recorder.stopPlayback(); playingClip = nil }
        else { recorder.play(e); playingClip = e.url }
    }
}

// MARK: - noise player

@MainActor final class NoisePlayer: ObservableObject {
    @Published var playing = false
    @Published var kind: NoiseSynth.Kind = .brown { didSet { shared.kind = kind.rawValue; if playing { updateNowPlaying() } } }
    @Published var volume: Double = 0.6 { didSet { shared.gain = Float(volume) } }
    @Published var timerMinutes = 0
    @Published var remaining: Double? = nil

    private final class Shared: @unchecked Sendable { var kind = 2; var gain: Float = 0.6; var fade: Float = 1; var l = NoiseSynth.State(); var r = NoiseSynth.State() }
    private let shared = Shared()
    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode?
    private var timer: Task<Void, Never>?

    func start() {
        if playing { return }
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
            let k = NoiseSynth.Kind(rawValue: sh.kind) ?? .brown
            let g = sh.gain * sh.fade
            for i in 0..<Int(frames) { l[i] = sh.l.next(k, sampleRate: rate) * g; r[i] = sh.r.next(k, sampleRate: rate) * g }
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
            Task { @MainActor in guard let self else { return }; self.playing ? self.stop() : self.start() }
            return .success
        }
    }

    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: kind.title,
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
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth])
        try? session.setActive(true)
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        guard fmt.sampleRate > 0 else { return }
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
