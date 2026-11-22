import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import PhotosUI

/// Ringtone maker: pick an audio file (or a video — its audio is used), choose up to a 30-second slice,
/// and export a `.m4r` ringtone. You preview the exact slice before you Save or Share. iOS gives apps
/// no way to set a ringtone directly, so the tool is honest about the one manual step: save the `.m4r`
/// to Files and install it through GarageBand (or Finder on a Mac). On device, nothing uploaded.
struct RingtoneView: View {
    @State private var sourceURL: URL?
    @State private var fileName = "Clip"
    @State private var total: Double = 0
    @State private var start: Double = 0
    @State private var length: Double = 30
    @State private var working = false
    @State private var resultURL: URL?
    @State private var errorText: String?
    @State private var showFiles = false
    @State private var levels: [Float] = []
    @State private var fade = true
    @State private var textTone = false                 // a short alert tone (up to 10 s) instead of a ringtone
    @State private var videoPick: PhotosPickerItem?
    @State private var previewPlayer: AVPlayer?
    @State private var previewing = false
    @State private var autoPicked = false

    private var cap: Double { textTone ? 10 : AudioConvert.maxRingtoneSeconds }
    private var maxLen: Double { min(cap, max(0.5, total - start)) }

    var body: some View {
        ToolPage(title: "Ringtone",
                 subtitle: "Trim a clip to a 30-second ringtone (.m4r) — on your phone.",
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
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.audio, .movie, .mpeg4Movie]) { res in
            if case .success(let url) = res { load(url) }
        }
        .onChange(of: videoPick) { _, item in
            guard let item else { return }
            Task {
                let d = try? await item.loadTransferable(type: Data.self)
                let u = FileManager.default.temporaryDirectory.appendingPathComponent("rt-video-\(UUID().uuidString.prefix(6)).mov")
                await MainActor.run {
                    videoPick = nil
                    if let d, (try? d.write(to: u)) != nil { load(u, name: "Video sound") } else { errorText = "That video couldn't be read." }
                }
            }
        }
        .onDisappear { stopPreview() }
        .finishes(working, tool: "Ringtone")
        .handoff("ringtone") { p in if let u = ToolHandoff.fileURL(p) { load(u) } }
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "bell.badge.fill").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose a song or clip, then trim up to 30 seconds for your ringtone."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { showFiles = true } label: {
                Label(L("Choose a song or audio file"), systemImage: "folder").frame(maxWidth: .infinity)
            }.primaryButton()
            PhotosPicker(selection: $videoPick, matching: .videos) {
                Label(L("Use the sound from a video"), systemImage: "video").frame(maxWidth: .infinity)
            }.secondaryButton()
            Text(L("Songs from Apple Music can't be used (they're protected) — use a file you own, a voice memo or a video."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s8) {
                Image(systemName: "music.note").foregroundStyle(HandyColor.accent)
                Text(fileName).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                Text(clock(total)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HandySpacing.s12)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))

            if total > 0 {
                trimControls
            } else if errorText == nil {
                HStack(spacing: HandySpacing.s8) {
                    BusySpinner()
                    Text(L("Reading the clip…")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }

            if let e = errorText {
                Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let url = resultURL {
                result(url)
            } else {
                Button { run() } label: {
                    Label(L("Make ringtone"), systemImage: "bell").frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || total <= 0)
            }

            if working { ToolProgressBar(label: "Making your ringtone…", showsTime: false) }

            Button(L("Choose a different file")) { reset() }.textButton().font(HandyFont.caption)
        }
    }

    /// The song's loudness, with the chosen part lit up. Tap anywhere to start the tone there.
    private var waveform: some View {
        GeometryReader { g in
            let n = max(1, levels.count)
            let w = g.size.width / CGFloat(n)
            HStack(alignment: .center, spacing: 0) {
                ForEach(Array(levels.enumerated()), id: \.offset) { i, v in
                    let t = Double(i) / Double(n) * total
                    let on = t >= start && t < start + length
                    Capsule().fill(on ? HandyColor.accent : HandyColor.textSecondary.opacity(0.3))
                        .frame(width: max(1, w - 1), height: max(3, CGFloat(v) * g.size.height))
                        .frame(width: w)
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { p in start = min(max(0, Double(p.x / g.size.width) * total - length / 2), max(0, total - length)) }
        }
        .frame(height: 64)
        .accessibilityLabel(L("Waveform of the song. The highlighted part becomes your tone."))
    }

    private var trimControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Picker(L("Kind"), selection: $textTone) {
                Text(L("Ringtone · up to 30 s")).tag(false)
                Text(L("Text tone · up to 10 s")).tag(true)
            }.pickerStyle(.segmented)
            .onChange(of: textTone) { _, _ in length = min(length, maxLen); if autoPicked { pickBest() }; clearResult() }
            if !levels.isEmpty {
                waveform
                if autoPicked {
                    Label(L("Started on the song's best part — the loudest, fullest stretch. Tap the waveform to move it."), systemImage: "sparkles")
                        .font(HandyFont.micro).foregroundStyle(HandyColor.accent).fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L("Start")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Spacer()
                    Text(clock(start)).font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary).monospacedDigit()
                }
                Slider(value: $start, in: 0...max(1.0, total - 0.5))
                    .tint(HandyColor.accent)
                    .onChange(of: start) { _, _ in
                        if length > maxLen { length = maxLen }
                        clearResult()
                    }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L("Length")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Spacer()
                    Text("\(clock(length)) / \(clock(cap)) max").font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary).monospacedDigit()
                }
                Slider(value: $length, in: 0.5...max(1.0, maxLen))
                    .tint(HandyColor.accent)
                    .onChange(of: length) { _, _ in clearResult() }
            }
            Text("\(L("Ringtone:")) \(clock(start)) – \(clock(min(start + length, total)))")
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).monospacedDigit()
            Toggle(L("Fade in and out"), isOn: $fade).font(HandyFont.caption).tint(HandyColor.accent)
                .onChange(of: fade) { _, _ in clearResult() }
            HStack(spacing: HandySpacing.s8) {
                Button { previewing ? stopPreview() : playPart() } label: {
                    Label(previewing ? L("Stop") : L("Hear this part"), systemImage: previewing ? "stop.fill" : "play.fill").frame(maxWidth: .infinity)
                }.secondaryButton()
                if !levels.isEmpty {
                    Button { pickBest() } label: { Label(L("Best part"), systemImage: "sparkles").frame(maxWidth: .infinity) }.secondaryButton()
                }
            }
        }
    }

    // MARK: - Result

    private func result(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Ringtone ready — play it, then save or share."), systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            AudioPlayBar(url: url)
            KeepShare(url, tool: "Ringtone")
            VStack(alignment: .leading, spacing: 4) {
                Text(L("To use it as your ringtone")).font(HandyFont.caption.weight(.semibold))
                ForEach(Array(installSteps.enumerated()), id: \.offset) { i, t in
                    Text("\(i + 1). \(L(t))").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                Text(L("iPhone doesn't let any app set a tone directly — this is Apple's own way, and it takes under a minute."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Button(L("Make another")) { clearResult() }.textButton().font(HandyFont.caption)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    // MARK: - Actions

    private var installSteps: [String] {[
        "Tap Save or share, then Save to Files.",
        "Open GarageBand (free from Apple), tap Browse, and open the file you saved.",
        "Press and hold the song, tap Share, then Ringtone, then Export.",
        textTone ? "Tap Use sound as… → Standard Text Tone." : "Tap Use sound as… → Standard Ringtone.",
    ]}

    private func pickBest() {
        guard !levels.isEmpty else { return }
        length = min(cap, total)
        start = RingtoneSmart.bestStart(levels, total: total, length: length)
        autoPicked = true
        clearResult()
    }

    private func playPart() {
        guard let src = sourceURL else { return }
        stopPreview()
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        let p = AVPlayer(url: src)
        p.seek(to: CMTime(seconds: start, preferredTimescale: 600))
        p.play(); previewPlayer = p; previewing = true
        let len = length
        DispatchQueue.main.asyncAfter(deadline: .now() + len) { if previewPlayer === p { stopPreview() } }
    }

    private func stopPreview() { previewPlayer?.pause(); previewPlayer = nil; previewing = false }

    private func load(_ url: URL, name: String? = nil) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let local = FileManager.default.temporaryDirectory
            .appendingPathComponent("rtin-\(UUID().uuidString.prefix(6)).\(url.pathExtension.isEmpty ? "audio" : url.pathExtension)")
        try? FileManager.default.removeItem(at: local)
        guard (try? FileManager.default.copyItem(at: url, to: local)) != nil else {
            errorText = "Couldn't open that file."; return
        }
        sourceURL = local
        fileName = name ?? url.deletingPathExtension().lastPathComponent
        levels = []; autoPicked = false
        start = 0; length = AudioConvert.maxRingtoneSeconds
        clearResult()
        Task {
            let d = (try? await AVURLAsset(url: local).load(.duration))?.seconds ?? 0
            await MainActor.run {
                total = max(0, d)
                if total > 0 { length = min(AudioConvert.maxRingtoneSeconds, total) }
                if total <= 0 { errorText = "That file has no audio Tenzy can read." }
            }
            // The waveform, and the best part picked for you — you can move it.
            if let lv = await RingtoneSmart.levels(local) {
                await MainActor.run { levels = lv; if total > 0 { pickBest() } }
            }
        }
    }

    private func reset() {
        stopPreview(); sourceURL = nil; fileName = "Clip"; total = 0; start = 0; length = 30; levels = []; autoPicked = false; clearResult()
    }

    private func clearResult() {
        resultURL = nil; errorText = nil
    }

    private func run() {
        guard let src = sourceURL, total > 0 else { return }
        working = true; errorText = nil
        stopPreview()
        let s = start, len = length, name = safeName(fileName), f = fade ? 1.0 : 0
        Task {
            let outcome = await AudioConvert.ringtone(src, start: s, length: len, fade: f)
            await MainActor.run {
                working = false
                switch outcome {
                case .success(let tmp):
                    let named = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).m4r")
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

    private func clock(_ s: Double) -> String {
        let t = Int(s.rounded())
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    private func safeName(_ raw: String) -> String {
        let trimmed = raw.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ringtone" : String(trimmed.prefix(60))
    }
}
