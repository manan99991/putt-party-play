import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

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

    private var maxLen: Double { min(AudioConvert.maxRingtoneSeconds, max(0.5, total - start)) }

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
        .finishes(working, tool: "Ringtone")
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "bell.badge.fill").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose a song or clip, then trim up to 30 seconds for your ringtone."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
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
                    Label(L("Make ringtone"), systemImage: "bell").frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || total <= 0)
            }

            if working { ToolProgressBar(label: "Making your ringtone…", showsTime: false) }

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
                    Text("\(clock(length)) / 0:30 max").font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary).monospacedDigit()
                }
                Slider(value: $length, in: 0.5...max(1.0, maxLen))
                    .tint(HandyColor.accent)
                    .onChange(of: length) { _, _ in clearResult() }
            }
            Text("\(L("Ringtone:")) \(clock(start)) – \(clock(min(start + length, total)))")
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).monospacedDigit()
        }
    }

    // MARK: - Result

    private func result(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Ringtone ready — play it, then save or share."), systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            AudioPlayBar(url: url)
            ShareLink(item: url) {
                Label(L("Save or share .m4r"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }.primaryButton()
            Text(L("iPhone won't let an app set a ringtone for you. Save the .m4r to Files, open it in GarageBand → Share → Ringtone to install it — or drop it into Finder on a Mac."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(L("Make another")) { clearResult() }.textButton().font(HandyFont.caption)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    // MARK: - Actions

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let local = FileManager.default.temporaryDirectory
            .appendingPathComponent("rtin-\(UUID().uuidString.prefix(6)).\(url.pathExtension.isEmpty ? "audio" : url.pathExtension)")
        try? FileManager.default.removeItem(at: local)
        guard (try? FileManager.default.copyItem(at: url, to: local)) != nil else {
            errorText = "Couldn't open that file."; return
        }
        sourceURL = local
        fileName = url.deletingPathExtension().lastPathComponent
        start = 0; length = AudioConvert.maxRingtoneSeconds
        clearResult()
        Task {
            let d = (try? await AVURLAsset(url: local).load(.duration))?.seconds ?? 0
            await MainActor.run {
                total = max(0, d)
                if total > 0 { length = min(AudioConvert.maxRingtoneSeconds, total) }
                if total <= 0 { errorText = "That file has no audio Tenzy can read." }
            }
        }
    }

    private func reset() {
        sourceURL = nil; fileName = "Clip"; total = 0; start = 0; length = 30; clearResult()
    }

    private func clearResult() {
        resultURL = nil; errorText = nil
    }

    private func run() {
        guard let src = sourceURL, total > 0 else { return }
        working = true; errorText = nil
        let s = start, len = length, name = safeName(fileName)
        Task {
            let outcome = await AudioConvert.ringtone(src, start: s, length: len)
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
