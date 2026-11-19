import SwiftUI
import AVFoundation

/// "Change the voice", as one place: every voice with its picture and a line on how it sounds. Tap one and you
/// hear the opening seconds of YOUR recording in it; tap another to compare, or play the original. When it's the
/// one, "Use this voice" makes the whole recording. Everything is rendered on the phone.
struct VoicePickerView: View {
    let payload: ChainPayload
    @State private var picked = "chipmunk"
    @State private var previews: [String: Data] = [:]
    @State private var rendering: String?
    @State private var playing: String?
    @State private var player: AVAudioPlayer?
    @State private var source: URL?
    @State private var problem: String?

    private var pickedName: String { L(ChainText.voices.first { $0.id == picked }?.name ?? "Chipmunk") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                Text(L("Change the voice")).font(HandyFont.title)
                Text(L("Tap a voice to hear the first seconds of your recording in it. Compare as many as you like, then use the one you love."))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                Button { playOriginal() } label: {
                    Label(playing == "original" ? L("Stop") : L("Play my original"), systemImage: playing == "original" ? "stop.fill" : "waveform")
                        .frame(maxWidth: .infinity)
                }.secondaryButton().accessibilityIdentifier("voice-original")

                VStack(spacing: HandySpacing.s8) {
                    ForEach(ChainText.voices, id: \.id) { v in row(v.id, name: v.name) }
                }
                if let problem { Text(L(problem)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            }
            .padding(HandySpacing.gutter)
        }
        .safeAreaInset(edge: .bottom) {
            NavigationLink {
                ChainRunView(chain: Chain(id: "voice-\(picked)", name: "\(pickedName) \(L("voice"))",
                                          steps: [ChainStep(block: .voiceChange, settings: ["voice": picked])]), initial: payload)
            } label: {
                Label("\(L("Use the")) \(pickedName) \(L("voice"))", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
            }
            .primaryButton()
            .padding(.horizontal, HandySpacing.gutter).padding(.vertical, HandySpacing.s8)
            .background(HandyColor.bg)
            .simultaneousGesture(TapGesture().onEnded { stop() })
            .accessibilityIdentifier("voice-use")
        }
        .background(Ground())
        .navigationTitle(L("Voices")).navigationBarTitleDisplayMode(.inline)
        .onAppear { prepare() }
        .onDisappear { stop() }
    }

    private func row(_ id: String, name: String) -> some View {
        let look = ChainText.voiceLooks[id] ?? ("🎙️", "")
        let on = picked == id
        return Button { choose(id) } label: {
            HStack(spacing: HandySpacing.s12) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20)).foregroundStyle(on ? HandyColor.accent : HandyColor.textSecondary)
                Text(look.emoji).font(.system(size: 30))
                    .frame(width: 52, height: 52)
                    .background((on ? HandyColor.accent : HandyColor.textSecondary).opacity(on ? 0.18 : 0.08), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L(name)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                    Text(L(look.line)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                Spacer(minLength: 0)
                if rendering == id { ProgressView() }
                else { Image(systemName: playing == id ? "speaker.wave.2.fill" : "play.circle").font(.system(size: 22)).foregroundStyle(HandyColor.accent) }
            }
            .padding(HandySpacing.s12)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous).stroke(on ? HandyColor.accent : HandyColor.border, lineWidth: on ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L(name)). \(L(look.line))")
        .accessibilityHint(L("Plays a preview of your recording in this voice"))
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("voice-\(id)")
    }

    // MARK: - Sound

    private func prepare() {
        guard source == nil else { return }
        switch payload {
        case .file(let d, let ext):
            let u = FileManager.default.temporaryDirectory.appendingPathComponent("voice-src-\(UUID().uuidString.prefix(6)).\(ext.isEmpty ? "m4a" : ext)")
            if (try? d.write(to: u)) != nil { source = u } else { problem = "That recording couldn't be read. Try another one." }
        default:
            problem = "Pick a recording to change its voice."
        }
    }

    private func choose(_ id: String) {
        picked = id
        if playing == id { stop(); return }
        if let d = previews[id] { play(d, as: id); return }
        guard let src = source else { return }
        rendering = id
        Task {
            let d = await Task.detached(priority: .userInitiated) { ChainMedia.previewVoice(src, voice: id) }.value
            await MainActor.run {
                if rendering == id { rendering = nil }
                guard let d else { problem = "That voice couldn't be made from this recording."; return }
                previews[id] = d
                if picked == id { play(d, as: id) }
            }
        }
    }

    private func playOriginal() {
        if playing == "original" { stop(); return }
        guard let src = source, let d = try? Data(contentsOf: src) else { return }
        play(d, as: "original")
    }

    private func play(_ d: Data, as id: String) {
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let p = try? AVAudioPlayer(data: d) else { problem = "That preview couldn't play."; return }
        p.play(); player = p; playing = id; problem = nil
        let length = p.duration
        DispatchQueue.main.asyncAfter(deadline: .now() + length + 0.1) { if playing == id, player === p { playing = nil } }
    }

    private func stop() { player?.stop(); player = nil; playing = nil }
}
