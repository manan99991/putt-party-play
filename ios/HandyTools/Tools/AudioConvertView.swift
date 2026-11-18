import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

/// Convert an audio file between the common phone formats — M4A, WAV, AIFF or CAF — on your phone.
/// Pick a file, choose the output format (M4A is the sensible default: small and plays everywhere),
/// and convert with a live progress bar and honest time-left. You preview the result with a built-in
/// player before you ever Save or Share, and it lands straight in the share sheet. MP3 can be read but
/// not written on an iPhone, so the tool says so and steers you to M4A instead of failing silently.
struct AudioConvertView: View {
    @State private var sourceURL: URL?
    @State private var fileName = "Audio"
    @State private var sourceIsMP3 = false
    @State private var format: AudioConvert.Format = .m4a
    @State private var progress: Double = 0
    @State private var working = false
    @State private var resultURL: URL?
    @State private var errorText: String?
    @State private var showFiles = false

    var body: some View {
        ToolPage(title: "Audio Convert",
                 subtitle: "Swap an audio file between M4A, WAV, AIFF and CAF — on your phone.",
                 working: working) {
            VStack(spacing: HandySpacing.s16) {
                if sourceURL == nil {
                    pickCard
                } else {
                    editor
                }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.audio]) { res in
            if case .success(let url) = res { load(url) }
        }
        .onChange(of: format) { _, _ in clearResult() }
        .finishes(working, tool: "Audio Convert")
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "waveform.path").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose an audio file, then convert it to another format."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Text(L("Works with M4A, MP3, WAV, AIFF, CAF and the audio from a video."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { showFiles = true } label: {
                Label(L("Choose audio"), systemImage: "folder").frame(maxWidth: .infinity)
            }.primaryButton()
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s8) {
                Image(systemName: "waveform").foregroundStyle(HandyColor.accent)
                Text(fileName).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HandySpacing.s12)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))

            formatPicker

            if sourceIsMP3 {
                Label(L(AudioConvert.mp3Note), systemImage: "info.circle")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let e = errorText {
                Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let url = resultURL {
                result(url)
            } else {
                Button { run() } label: {
                    Label(L("Convert"), systemImage: "arrow.right.circle").frame(maxWidth: .infinity)
                }.primaryButton().disabled(working)
            }

            if working {
                ToolProgressBar(value: progress, label: "Converting to \(format.ext.uppercased())…")
            }

            Button(L("Choose a different file")) { reset() }.textButton().font(HandyFont.caption)
        }
    }

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Convert to")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            Picker("", selection: $format) {
                ForEach(AudioConvert.Format.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("audio-format")
            Text(L(format.detail)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
    }

    // MARK: - Result

    private func result(_ url: URL) -> some View {
        VStack(spacing: HandySpacing.s8) {
            Label(L("Converted — play it below, then save or share."), systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            AudioPlayBar(url: url)
            ShareLink(item: url) {
                Label(L("Save or share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }.primaryButton()
            Button(L("Convert again")) { clearResult() }.textButton().font(HandyFont.caption)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    // MARK: - Actions

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        // Copy into our own temp dir so the file stays readable after the security-scoped access ends.
        let local = FileManager.default.temporaryDirectory
            .appendingPathComponent("acin-\(UUID().uuidString.prefix(6)).\(url.pathExtension.isEmpty ? "audio" : url.pathExtension)")
        try? FileManager.default.removeItem(at: local)
        guard (try? FileManager.default.copyItem(at: url, to: local)) != nil else {
            errorText = "Couldn't open that audio file."; return
        }
        sourceURL = local
        fileName = url.deletingPathExtension().lastPathComponent
        sourceIsMP3 = url.pathExtension.lowercased() == "mp3"
        // A sensible default: converting an MP3? aim at M4A. Otherwise keep the current choice.
        if sourceIsMP3 { format = .m4a }
        clearResult()
    }

    private func reset() {
        sourceURL = nil; fileName = "Audio"; sourceIsMP3 = false; clearResult()
    }

    private func clearResult() {
        resultURL = nil; errorText = nil; progress = 0
    }

    private func run() {
        guard let src = sourceURL else { return }
        working = true; errorText = nil; progress = 0
        let target = format, name = safeName(fileName)
        Task {
            let outcome = await AudioConvert.convert(src, to: target) { p in
                Task { @MainActor in progress = p }
            }
            await MainActor.run {
                working = false
                switch outcome {
                case .success(let tmp):
                    // Give the shared file a friendly name instead of the random temp one.
                    let named = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).\(target.ext)")
                    try? FileManager.default.removeItem(at: named)
                    let final = (try? FileManager.default.moveItem(at: tmp, to: named)) != nil ? named : tmp
                    resultURL = final
                    HandyHaptics.success()
                case .failure(let f):
                    errorText = f.message
                }
            }
        }
    }

    /// Keep the shared filename to safe characters so the temp file writes and the share sheet shows a
    /// sensible name.
    private func safeName(_ raw: String) -> String {
        let trimmed = raw.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Audio" : String(trimmed.prefix(60))
    }
}

/// A simple play/pause preview for a converted audio file, so the user confirms what was built before
/// it leaves the app. Plays through the speaker, resets to the start when it reaches the end, and stops
/// when the screen goes away. Shared by the audio tools (Audio Convert, Ringtone).
struct AudioPlayBar: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var playing = false

    var body: some View {
        Button {
            let p = player ?? AVPlayer(url: url)
            player = p
            if playing {
                p.pause()
                playing = false
            } else {
                let item = p.currentItem
                let pos = item?.currentTime().seconds ?? 0
                let dur = item?.duration.seconds ?? 0
                if dur > 0, pos >= dur - 0.1 { p.seek(to: .zero) }
                try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
                try? AVAudioSession.sharedInstance().setActive(true)
                p.play()
                playing = true
            }
        } label: {
            Label(playing ? L("Pause preview") : L("Play preview"),
                  systemImage: playing ? "pause.circle.fill" : "play.circle.fill").frame(maxWidth: .infinity)
        }
        .secondaryButton()
        .onDisappear { player?.pause() }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in playing = false }
    }
}
