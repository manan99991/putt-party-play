import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

/// Compress Audio — make a recording small enough to email or message. Pick a quality level (each
/// shows the size it will make) or a size to fit under ("under 10 MB for email"), see live progress,
/// then play the result and compare sizes before Save or Share. Takes a video's sound too. On device.
struct AudioCompressView: View {
    enum Mode: Hashable { case quality, fit }

    @State private var sourceURL: URL?
    @State private var fileName = "Audio"
    @State private var sourceBytes = 0
    @State private var seconds: Double = 0
    @State private var mode: Mode = .quality
    @State private var level: AudioConvert.Level = .balanced
    @State private var targetMB: Double = 10
    @State private var progress: Double = 0
    @State private var working = false
    @State private var resultURL: URL?
    @State private var resultBytes = 0
    @State private var resultLevel: AudioConvert.Level = .balanced
    @State private var errorText: String?
    @State private var showFiles = false

    private let targets: [Double] = [1, 5, 10, 20, 25]

    var body: some View {
        ToolPage(title: "Compress Audio",
                 subtitle: "Make a recording small enough to email or message.",
                 working: working) {
            VStack(spacing: HandySpacing.s16) {
                if sourceURL == nil { pickCard }
                else if let url = resultURL { result(url) }
                else { editor }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.audio, .movie]) { res in
            if case .success(let url) = res { load(url) }
        }
        .finishes(working, tool: "Compress Audio")
        .handoff("audiocompress") { p in if let u = ToolHandoff.fileURL(p) { load(u) } }
    }

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "arrow.down.right.and.arrow.up.left.circle").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose a recording, song or video — Tenzy shrinks its sound to the size you need."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { showFiles = true } label: {
                Label(L("Choose a file"), systemImage: "folder").frame(maxWidth: .infinity)
            }.primaryButton()
            FromVideosButton { if let u = $0.first { load(u) } }
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    private var chosen: (level: AudioConvert.Level, fits: Bool) {
        mode == .quality ? (level, true) : AudioConvert.level(fitting: Int(targetMB * 1_000_000), seconds: seconds)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack {
                Image(systemName: "waveform").foregroundStyle(HandyColor.accent)
                Text(fileName).font(HandyFont.bodyStrong).lineLimit(1)
                Spacer()
                Text("\(Self.size(sourceBytes)) · \(Self.duration(seconds))")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            .cardStyle(padding: HandySpacing.s12)

            Picker("", selection: $mode) {
                Text(L("Pick quality")).tag(Mode.quality)
                Text(L("Fit under a size")).tag(Mode.fit)
            }.pickerStyle(.segmented)

            if mode == .quality {
                ForEach(AudioConvert.Level.allCases) { l in levelRow(l) }
            } else {
                HStack(spacing: HandySpacing.s8) {
                    ForEach(targets, id: \.self) { mb in
                        Button("\(Int(mb)) MB") { targetMB = mb }
                            .font(HandyFont.caption)
                            .buttonStyle(.bordered)
                            .tint(targetMB == mb ? HandyColor.accent : HandyColor.textSecondary)
                    }
                }
                let c = chosen
                Text(c.fits
                     ? "\(L("Will use")) \(L(c.level.title)) — \(L("about")) \(Self.size(c.level.estimatedBytes(seconds: seconds)))"
                     : "\(L("Even the smallest setting makes about")) \(Self.size(c.level.estimatedBytes(seconds: seconds))) — \(L("it's a long recording. Trim it first in Audio Edit to go smaller."))")
                    .font(HandyFont.caption)
                    .foregroundStyle(c.fits ? HandyColor.textSecondary : HandyColor.danger)
                Text(L("25 MB fits Gmail and most email · 16 MB fits WhatsApp"))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }

            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            Button { run() } label: {
                Label(L("Compress"), systemImage: "arrow.down.right.and.arrow.up.left").frame(maxWidth: .infinity)
            }.primaryButton().disabled(working)
            if working { ToolProgressBar(value: progress, label: "Compressing…") }
            Button(L("Choose a different file")) { reset() }.textButton().font(HandyFont.caption)
                .frame(maxWidth: .infinity)
        }
    }

    private func levelRow(_ l: AudioConvert.Level) -> some View {
        Button { level = l } label: {
            HStack(spacing: HandySpacing.s12) {
                Image(systemName: level == l ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(level == l ? HandyColor.accent : HandyColor.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L(l.title)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                    Text(L(l.detail)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
                Spacer()
                Text("≈ \(Self.size(l.estimatedBytes(seconds: seconds)))")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardStyle(padding: HandySpacing.s12)
    }

    private func result(_ url: URL) -> some View {
        let saved = sourceBytes > 0 ? max(0, 100 - Int((Double(resultBytes) / Double(sourceBytes) * 100).rounded())) : 0
        return VStack(spacing: HandySpacing.s8) {
            Label(saved > 0 ? "\(Self.size(sourceBytes)) → \(Self.size(resultBytes)) · \(saved)% \(L("smaller"))"
                            : "\(L("Done")) — \(Self.size(resultBytes)). \(L("It was already well compressed."))",
                  systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(L(resultLevel.title)) · \(L(resultLevel.detail))")
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            AudioPlayBar(url: url)
            KeepShare(url, lead: .share, tool: "Shrink audio")
            Button(L("Try another size")) { resultURL = nil; errorText = nil; progress = 0 }.textButton().font(HandyFont.caption)
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
        sourceBytes = (try? local.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        resultURL = nil; errorText = nil; progress = 0; seconds = 0
        Task {
            let d = (try? await AVURLAsset(url: local).load(.duration))?.seconds ?? 0
            await MainActor.run { seconds = d.isFinite ? d : 0 }
        }
    }

    private func reset() {
        sourceURL = nil; fileName = "Audio"; sourceBytes = 0; seconds = 0; resultURL = nil; errorText = nil; progress = 0
    }

    private func run() {
        guard let src = sourceURL else { return }
        working = true; errorText = nil; progress = 0
        let pick = chosen.level
        let name = fileName.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        Task {
            let outcome = await AudioConvert.compress(src, level: pick) { p in Task { @MainActor in progress = p } }
            await MainActor.run {
                working = false
                switch outcome {
                case .success(let made):
                    let named = FileManager.default.temporaryDirectory
                        .appendingPathComponent("\(name.isEmpty ? "Audio" : String(name.prefix(50))) (compressed).m4a")
                    try? FileManager.default.removeItem(at: named)
                    let final = (try? FileManager.default.moveItem(at: made.url, to: named)) != nil ? named : made.url
                    resultBytes = (try? final.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    resultLevel = made.level
                    resultURL = final
                    HandyHaptics.success()
                case .failure(let f):
                    errorText = f.message
                }
            }
        }
    }

    static func size(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    static func duration(_ s: Double) -> String {
        guard s > 0 else { return "…" }
        let t = Int(s.rounded())
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, (t / 60) % 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60)
    }
}
