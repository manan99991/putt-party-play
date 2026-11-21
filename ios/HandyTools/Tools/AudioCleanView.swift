import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

/// Audio Cleanup: pick an audio file (or a video — its audio is used), and tidy it up on-device — cut low
/// rumble and hum, push down steady background hiss, and even out the volume so a too-quiet clip comes up
/// to a consistent level. You preview the exact result with the built-in player before you ever Save or
/// Share, and it lands straight in the share sheet. Everything runs on the phone; nothing is uploaded.
/// Honest about its reach: this is DSP tidy-up, not a studio denoiser.
struct AudioCleanView: View {
    @State private var sourceURL: URL?
    @State private var fileName = "Audio"
    @State private var total: Double = 0
    @State private var highPass = true
    @State private var reduceNoise = true
    @State private var normalize = true
    @State private var strength: Double = 0.6
    @State private var format: AudioConvert.Format = .m4a
    @State private var progress: Double = 0
    @State private var working = false
    @State private var resultURL: URL?
    @State private var errorText: String?
    @State private var showFiles = false

    /// Only M4A and WAV here — "send it anywhere" and "uncompressed" — without a wall of containers.
    private let outputFormats: [AudioConvert.Format] = [.m4a, .wav]

    var body: some View {
        ToolPage(title: "Audio Cleanup",
                 subtitle: "Cut noise and even out the volume — on your phone.",
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
        .finishes(working, tool: "Audio Cleanup")
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "wand.and.stars").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Pick a recording or clip and Tenzy will cut the background noise, drop the rumble and hum, and bring the volume up to an even level."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Text(L("Best on a voice memo or a too-quiet clip. On-device tidy-up, not a studio denoiser."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { showFiles = true } label: {
                Label(L("Choose audio or video"), systemImage: "folder").frame(maxWidth: .infinity)
            }.primaryButton()
            FromVideosButton { if let u = $0.first { load(u) } }
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
                options
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
                    Label(L("Clean it up"), systemImage: "wand.and.stars").frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || total <= 0)
            }

            if working {
                ToolProgressBar(value: progress, label: "Cleaning up your audio…")
            }

            Button(L("Choose a different file")) { reset() }.textButton().font(HandyFont.caption)
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Toggle(isOn: $reduceNoise) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Reduce background noise")).font(HandyFont.body).foregroundStyle(HandyColor.textPrimary)
                    Text(L("Pushes down steady hiss between words.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
            }
            .tint(HandyColor.accent)
            .accessibilityIdentifier("audioclean-noise")
            .onChange(of: reduceNoise) { _, _ in clearResult() }

            if reduceNoise {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L("Strength")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        Spacer()
                        Text(strengthLabel).font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary)
                    }
                    Slider(value: $strength, in: 0.2...1.0)
                        .tint(HandyColor.accent)
                        .accessibilityIdentifier("audioclean-strength")
                        .onChange(of: strength) { _, _ in clearResult() }
                    Text(L("Gentle keeps it natural; strong cuts more but can sound clipped."))
                        .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
            }

            Toggle(isOn: $highPass) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Cut rumble & hum")).font(HandyFont.body).foregroundStyle(HandyColor.textPrimary)
                    Text(L("Removes low handling noise and mains hum.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
            }
            .tint(HandyColor.accent)
            .accessibilityIdentifier("audioclean-highpass")
            .onChange(of: highPass) { _, _ in clearResult() }

            Toggle(isOn: $normalize) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Even out the volume")).font(HandyFont.body).foregroundStyle(HandyColor.textPrimary)
                    Text(L("Brings a too-quiet clip up to a consistent level.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
            }
            .tint(HandyColor.accent)
            .accessibilityIdentifier("audioclean-normalize")
            .onChange(of: normalize) { _, _ in clearResult() }

            formatPicker
        }
    }

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Save as")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            Picker("", selection: $format) {
                ForEach(outputFormats) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("audioclean-format")
            .onChange(of: format) { _, _ in clearResult() }
            Text(L(format.detail)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private var strengthLabel: String {
        if strength < 0.45 { return L("Gentle") }
        if strength < 0.75 { return L("Medium") }
        return L("Strong")
    }

    // MARK: - Result

    private func result(_ url: URL) -> some View {
        VStack(spacing: HandySpacing.s8) {
            Label(L("Cleaned up — play it below, then save or share."), systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            AudioPlayBar(url: url)
            ShareLink(item: url) {
                Label(L("Save or share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }.primaryButton()
            Button(L("Clean again")) { clearResult() }.textButton().font(HandyFont.caption)
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
        total = 0
        clearResult()
        Task {
            let d = (try? await AVURLAsset(url: local).load(.duration))?.seconds ?? 0
            await MainActor.run {
                total = max(0, d)
                if total <= 0 { errorText = "That file has no audio Tenzy can read." }
            }
        }
    }

    private func reset() {
        sourceURL = nil; fileName = "Audio"; total = 0
        highPass = true; reduceNoise = true; normalize = true; strength = 0.6
        clearResult()
    }

    private func clearResult() {
        resultURL = nil; errorText = nil; progress = 0
    }

    private func run() {
        guard let src = sourceURL, total > 0 else { return }
        working = true; errorText = nil; progress = 0
        let opts = AudioClean.Options(highPass: highPass, reduceNoise: reduceNoise,
                                      normalize: normalize, strength: strength)
        let target = format, name = safeName(fileName)
        Task {
            let outcome = await AudioClean.clean(src, options: opts, format: target) { p in
                Task { @MainActor in progress = p }
            }
            await MainActor.run {
                working = false
                switch outcome {
                case .success(let tmp):
                    let named = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-cleaned.\(target.ext)")
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
        return trimmed.isEmpty ? "Audio" : String(trimmed.prefix(60))
    }
}
