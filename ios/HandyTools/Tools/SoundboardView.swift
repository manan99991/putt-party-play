import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

/// Soundboard: pick an audio file (or a video — its audio is used), tap a voice card, and hear your
/// clip transformed — chipmunk, helium, deep, giant, robot, alien, monster, walkie-talkie, echo cave or ghost. The character voices
/// (robot/alien/monster) pitch-shift without changing tempo and add a timbre, so the speech stays
/// intelligible; chipmunk/helium/giant/deep use the classic varispeed. Everything renders on the
/// phone, offline — nothing is uploaded. You preview the result before you Save or Share, and tapping
/// another card just re-renders from the same clip. Reuses the proven ChainMedia voice-change DSP.
struct SoundboardView: View {
    private struct Voice: Identifiable {
        let id: String, name: String, blurb: String, icon: String
    }
    /// The same voices, pictures and lines as everywhere else in Tenzy (ChainText.voices / voiceLooks).
    private let voices: [Voice] = ChainText.voices.map { v in
        Voice(id: v.id, name: v.name, blurb: ChainText.voiceLooks[v.id]?.line ?? "", icon: ChainText.voiceLooks[v.id]?.emoji ?? "🎙️")
    }

    @State private var audioURL: URL?        // normalized, readable audio
    @State private var fileName = "Clip"
    @State private var loading = false       // reading / normalizing the picked file
    @State private var working = false       // rendering a voice
    @State private var selected: String?
    @State private var resultURL: URL?
    @State private var errorText: String?
    @State private var showFiles = false

    var body: some View {
        ToolPage(title: "Soundboard",
                 subtitle: "Pick a clip, tap a voice — robot, alien, chipmunk and more, on your phone.",
                 working: working || loading) {
            VStack(spacing: HandySpacing.s16) {
                if audioURL == nil && !loading {
                    pickCard
                } else {
                    picker
                }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.audio, .movie, .mpeg4Movie]) { res in
            if case .success(let url) = res { load(url) }
        }
        .finishes(working, tool: "Soundboard")
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "theatermasks.fill").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose a recording or a video, then tap a voice to transform it."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { showFiles = true } label: {
                Label(L("Choose audio or video"), systemImage: "folder").frame(maxWidth: .infinity)
            }.primaryButton()
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    // MARK: - Picker

    private var picker: some View {
        VStack(spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s8) {
                Image(systemName: "music.note").foregroundStyle(HandyColor.accent)
                Text(fileName).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                Button(L("Change")) { reset() }.textButton().font(HandyFont.caption).disabled(working)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HandySpacing.s12)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))

            if loading {
                HStack(spacing: HandySpacing.s8) {
                    ProgressView()
                    Text(L("Reading the clip…")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(voices) { v in voiceCard(v) }
            }

            if let e = errorText {
                Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if working { ToolProgressBar(label: "Changing the voice…", showsTime: false) }

            if let url = resultURL, !working {
                result(url)
            }
        }
    }

    private func voiceCard(_ v: Voice) -> some View {
        Button { choose(v.id) } label: {
            HStack(spacing: HandySpacing.s12) {
                Text(v.icon).font(.system(size: 28)).frame(width: 46, height: 46)
                    .background(HandyColor.accent.opacity(selected == v.id ? 0.18 : 0.08), in: Circle()).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L(v.name)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                    Text(L(v.blurb)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                Spacer()
                Image(systemName: selected == v.id ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected == v.id ? HandyColor.accent : HandyColor.border)
            }
            .padding(HandySpacing.s12)
            .frame(maxWidth: .infinity)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous)
                .stroke(selected == v.id ? HandyColor.accent : HandyColor.border, lineWidth: selected == v.id ? 2 : 1))
        }
        .buttonStyle(.plain)
        .disabled(working)
    }

    // MARK: - Result

    private func result(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Your new voice is ready — play it, then save or share."), systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            AudioPlayBar(url: url)
            ShareLink(item: url) {
                Label(L("Save or share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }.primaryButton()
            Text(L("Tap another voice above to try a different one."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    // MARK: - Actions

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let local = FileManager.default.temporaryDirectory
            .appendingPathComponent("sbin-\(UUID().uuidString.prefix(6)).\(url.pathExtension.isEmpty ? "audio" : url.pathExtension)")
        try? FileManager.default.removeItem(at: local)
        guard (try? FileManager.default.copyItem(at: url, to: local)) != nil else {
            errorText = "Couldn't open that file."; return
        }
        fileName = url.deletingPathExtension().lastPathComponent
        audioURL = nil; selected = nil; resultURL = nil; errorText = nil
        loading = true
        Task {
            let normalized = await normalize(local)
            await MainActor.run {
                loading = false
                if let a = normalized {
                    audioURL = a
                } else {
                    audioURL = local                  // keep the picker on screen, don't dead-end
                    errorText = "That file has no sound Tenzy can read. Try another one."
                }
            }
        }
    }

    /// A readable audio file for the DSP: a video's audio track is extracted; odd audio formats
    /// (MP3, Ogg-Opus…) are transcoded to m4a; a plain m4a / wav / caf passes straight through.
    /// Returns nil only when there is no audio Tenzy can read.
    private func normalize(_ src: URL) async -> URL? {
        let asset = AVURLAsset(url: src)
        let hasVideo = ((try? await asset.loadTracks(withMediaType: .video))?.isEmpty == false)
        if hasVideo {
            return await VideoEngine.extractAudio(src)
        }
        let audio = await Transcriber.readableAudioURL(for: src)
        if let tracks = try? await AVURLAsset(url: audio).loadTracks(withMediaType: .audio), !tracks.isEmpty {
            return audio
        }
        return nil
    }

    private func choose(_ id: String) {
        guard let src = audioURL, !working else { return }
        selected = id
        resultURL = nil
        errorText = nil
        working = true
        Task {
            let data = await Task.detached(priority: .userInitiated) { () -> Data? in
                ChainMedia.soundboardVoice(src, voice: id)
            }.value
            await MainActor.run {
                working = false
                guard let data, data.count > 44 else {
                    errorText = "Couldn't change that recording. Try another clip."
                    return
                }
                let out = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(safeName(fileName))-\(id).wav")
                try? FileManager.default.removeItem(at: out)
                guard (try? data.write(to: out)) != nil else {
                    errorText = "Couldn't save the result."
                    return
                }
                resultURL = out
                HandyHaptics.success()
            }
        }
    }

    private func reset() {
        audioURL = nil; fileName = "Clip"; selected = nil; resultURL = nil; errorText = nil; loading = false
    }

    private func safeName(_ raw: String) -> String {
        let trimmed = raw.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Voice" : String(trimmed.prefix(40))
    }
}
