import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

/// Audio Editor: pick an audio file (or a video — its audio is used), trim it to a slice, fade the start
/// and end, and auto-remove long silent gaps ("dead air"). You preview the exact result with the built-in
/// player before you ever Save or Share, and it lands straight in the share sheet. Everything runs on the
/// phone; nothing is uploaded. Output is M4A (small, plays everywhere) or WAV (uncompressed).
struct AudioEditView: View {
    @State private var sourceURL: URL?
    @State private var fileName = "Audio"
    @State private var total: Double = 0
    @State private var start: Double = 0
    @State private var end: Double = 0
    @State private var fadeIn: Double = 0
    @State private var fadeOut: Double = 0
    @State private var removeSilence = false
    @State private var format: AudioConvert.Format = .m4a
    @State private var progress: Double = 0
    @State private var working = false
    @State private var resultURL: URL?
    @State private var errorText: String?
    @State private var showFiles = false

    /// Only M4A and WAV are offered here — the two formats that cover "send it anywhere" and
    /// "uncompressed", without burdening the trim screen with every container.
    private let outputFormats: [AudioConvert.Format] = [.m4a, .wav]

    var body: some View {
        ToolPage(title: "Audio Editor",
                 subtitle: "Trim, fade, and cut dead air from a clip — on your phone.",
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
        .finishes(working, tool: "Audio Editor")
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "waveform.badge.minus").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose a song, recording or clip, then trim it, fade the ends, and cut out dead air."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Text(L("Works with M4A, MP3, WAV, AIFF, CAF and the audio from a video."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { showFiles = true } label: {
                Label(L("Choose audio or video"), systemImage: "folder").frame(maxWidth: .infinity)
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
                Text(clock(total)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HandySpacing.s12)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))

            if total > 0 {
                trimControls
                fadeControls
                silenceControl
                formatPicker
            } else if errorText == nil {
                HStack(spacing: HandySpacing.s8) {
                    ProgressView()
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
                    Label(L("Save edit"), systemImage: "scissors").frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || total <= 0)
            }

            if working {
                ToolProgressBar(value: progress, label: "Editing your audio…")
            }

            Button(L("Choose a different file")) { reset() }.textButton().font(HandyFont.caption)
        }
    }

    private var trimControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L("Start")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Spacer()
                    Text(clock(start)).font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary).monospacedDigit()
                }
                Slider(value: $start, in: 0...max(1.0, total))
                    .tint(HandyColor.accent)
                    .onChange(of: start) { _, _ in
                        if end <= start { end = min(total, start + 1) }
                        clearResult()
                    }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L("End")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Spacer()
                    Text(clock(end)).font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary).monospacedDigit()
                }
                Slider(value: $end, in: 0...max(1.0, total))
                    .tint(HandyColor.accent)
                    .onChange(of: end) { _, _ in
                        if start >= end { start = max(0, end - 1) }
                        clearResult()
                    }
            }
            Text("\(L("Keeping:")) \(clock(start)) – \(clock(max(start, end)))")
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).monospacedDigit()
        }
    }

    private var fadeControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L("Fade in")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Spacer()
                    Text(fadeIn < 0.05 ? L("Off") : secs(fadeIn))
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary).monospacedDigit()
                }
                Slider(value: $fadeIn, in: 0...5)
                    .tint(HandyColor.accent)
                    .accessibilityIdentifier("audioedit-fadein")
                    .onChange(of: fadeIn) { _, _ in clearResult() }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L("Fade out")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Spacer()
                    Text(fadeOut < 0.05 ? L("Off") : secs(fadeOut))
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary).monospacedDigit()
                }
                Slider(value: $fadeOut, in: 0...5)
                    .tint(HandyColor.accent)
                    .accessibilityIdentifier("audioedit-fadeout")
                    .onChange(of: fadeOut) { _, _ in clearResult() }
            }
        }
    }

    private var silenceControl: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $removeSilence) {
                Text(L("Remove dead air")).font(HandyFont.body).foregroundStyle(HandyColor.textPrimary)
            }
            .tint(HandyColor.accent)
            .accessibilityIdentifier("audioedit-silence")
            .onChange(of: removeSilence) { _, _ in clearResult() }
            Text(L("Cuts out silent gaps longer than half a second."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Save as")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            Picker("", selection: $format) {
                ForEach(outputFormats) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("audioedit-format")
            .onChange(of: format) { _, _ in clearResult() }
            Text(L(format.detail)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
    }

    // MARK: - Result

    private func result(_ url: URL) -> some View {
        VStack(spacing: HandySpacing.s8) {
            Label(L("Edited — play it below, then save or share."), systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            AudioPlayBar(url: url)
            ShareLink(item: url) {
                Label(L("Save or share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }.primaryButton()
            Button(L("Edit again")) { clearResult() }.textButton().font(HandyFont.caption)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    // MARK: - Actions

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        // The shared way in: kept readable, voice notes decoded, the name made readable.
        guard let took = AudioIntake.local(url) else {
            errorText = "Couldn't open that file."; return
        }
        let local = took.url
        sourceURL = local
        fileName = took.name
        total = 0; start = 0; end = 0; fadeIn = 0; fadeOut = 0; removeSilence = false
        clearResult()
        Task {
            let d = (try? await AVURLAsset(url: local).load(.duration))?.seconds ?? 0
            await MainActor.run {
                total = max(0, d)
                if total > 0 {
                    start = 0; end = total
                } else {
                    errorText = "That file has no audio Tenzy can read."
                }
            }
        }
    }

    private func reset() {
        sourceURL = nil; fileName = "Audio"; total = 0; start = 0; end = 0
        fadeIn = 0; fadeOut = 0; removeSilence = false; clearResult()
    }

    private func clearResult() {
        resultURL = nil; errorText = nil; progress = 0
    }

    private func run() {
        guard let src = sourceURL, total > 0, end > start else { return }
        working = true; errorText = nil; progress = 0
        let opts = AudioEdit.Options(start: start, end: end,
                                     fadeIn: fadeIn, fadeOut: fadeOut,
                                     removeSilence: removeSilence)
        let target = format, name = safeName(fileName)
        Task {
            let outcome = await AudioEdit.edit(src, options: opts, format: target) { p in
                Task { @MainActor in progress = p }
            }
            await MainActor.run {
                working = false
                switch outcome {
                case .success(let tmp):
                    let named = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-edited.\(target.ext)")
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

    private func secs(_ s: Double) -> String { String(format: "%.1fs", s) }

    private func safeName(_ raw: String) -> String {
        let trimmed = raw.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Audio" : String(trimmed.prefix(60))
    }
}
