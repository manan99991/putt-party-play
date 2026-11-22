import SwiftUI
import AVFoundation

/// The finish for a changed voice — the same after the voice picker, every ready-made voice tool and any built tool
/// that ends in Change the voice: hear it (scrub, skip), play your original to compare, switch to another voice
/// right here without starting over, then Share or Save to Files.
struct VoiceFinishCard: View {
    /// The recording the voice was put on (as the last step was given it).
    let original: (data: Data, ext: String)?
    @State var voice: String
    @State var result: Data
    /// When the voice came from a video: the video, so the result is that video with the new voice — not just a sound file.
    var video: URL? = nil
    @State private var videoOut: URL?
    @State private var mixing = false

    @State private var busy: String?
    @State private var problem: String?
    @State private var player: AVAudioPlayer?
    @State private var playingOriginal = false

    @State private var resultURL: URL?
    private func writeResult() {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("\(L(name(voice))) \(L("voice")).wav")
        try? FileManager.default.removeItem(at: u)
        resultURL = (try? result.write(to: u)) != nil ? u : nil
    }
    private func name(_ id: String) -> String { ChainText.voices.first { $0.id == id }?.name ?? "Changed" }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s8) {
                Text(ChainText.voiceLooks[voice]?.emoji ?? "🎙️").font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(L(name(voice))) \(L("voice"))").font(HandyFont.bodyStrong)
                    if let line = ChainText.voiceLooks[voice]?.line { Text(L(line)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                }
            }
            if video != nil {
                if let v = videoOut { VideoFinishCard(url: v).id(v) }
                else if mixing { ToolProgressBar(label: "Putting the new voice on your video…", showsTime: false) }
            } else if let u = resultURL { AudioResultPreview(url: u).id(result.count ^ voice.hashValue) }
            if original != nil {
                Button { toggleOriginal() } label: {
                    Label(playingOriginal ? L("Stop") : L("Play my original"), systemImage: playingOriginal ? "stop.fill" : "waveform").frame(maxWidth: .infinity)
                }.secondaryButton().accessibilityIdentifier("voice-finish-original")
                Text(L("Try another voice on the same recording")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                HandyFlow(spacing: 8) {
                        ForEach(ChainText.voices, id: \.id) { v in
                            Button { switchTo(v.id) } label: {
                                HStack(spacing: 4) {
                                    if busy == v.id { ProgressView().controlSize(.mini) } else { Text(ChainText.voiceLooks[v.id]?.emoji ?? "") }
                                    Text(L(v.name)).font(HandyFont.caption)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(voice == v.id ? HandyColor.accent : HandyColor.surface, in: Capsule())
                                .foregroundStyle(voice == v.id ? Color.white : HandyColor.textPrimary)
                            }.buttonStyle(.plain).disabled(busy != nil)
                        }
                    }
            }
            if let problem { Text(L(problem)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let u = resultURL {
                if video != nil {
                    ShareLink(item: u) { Label(L("Just the sound (WAV)"), systemImage: "waveform").frame(maxWidth: .infinity) }.textButton()
                } else {
                    KeepShare(u, lead: .share, tool: "Voice", record: false)
                }
            }
            Text("\(SizeTarget.format(result.count)) · WAV").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice-finish")
        .onAppear { if resultURL == nil { writeResult() }; remix() }
        .onDisappear { player?.stop() }
    }

    private func toggleOriginal() {
        if playingOriginal { player?.stop(); playingOriginal = false; return }
        guard let o = original, let p = try? AVAudioPlayer(data: o.data) else { problem = "Couldn't play your original."; return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        player = p; p.play(); playingOriginal = true
    }

    private func switchTo(_ id: String) {
        guard id != voice, let o = original else { return }
        busy = id; problem = nil; player?.stop(); playingOriginal = false
        Task {
            let r = await ChainRunner.apply(ChainStep(block: .voiceChange, settings: ["voice": id]), to: .file(o.data, ext: o.ext))
            await MainActor.run {
                busy = nil
                if case .success(.file(let d, _)) = r { result = d; voice = id; writeResult(); remix() } else { problem = "That voice couldn't be made from this recording." }
            }
        }
    }

    /// Lays the current voice over the video (when it came from one).
    private func remix() {
        guard let v = video else { return }
        mixing = true; videoOut = nil
        let d = result
        Task {
            let a = FileManager.default.temporaryDirectory.appendingPathComponent("voice-\(UUID().uuidString).wav")
            try? d.write(to: a)
            let out = await VideoEngine.replaceAudio(video: v, with: a)
            await MainActor.run { mixing = false; videoOut = out; if out == nil { problem = "Couldn't put the voice on the video — the sound file is below." } }
        }
    }
}
