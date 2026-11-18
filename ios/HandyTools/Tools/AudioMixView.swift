import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

/// Join & Speed — two everyday audio jobs in one tool. Join: pick several clips (or videos), put them
/// in order, add an optional pause between them → one file. Speed: play a lecture or voice memo faster
/// or slower without the chipmunk effect. Live progress, then play the result before Save or Share.
struct AudioMixView: View {
    enum Mode: Hashable { case join, speed }
    struct Clip: Identifiable, Equatable { let id = UUID(); let url: URL; let name: String; var seconds: Double = 0 }

    @State private var mode: Mode = .join
    @State private var clips: [Clip] = []
    @State private var gap: Double = 0
    @State private var rate: Double = 1.5
    @State private var progress: Double = 0
    @State private var working = false
    @State private var resultURL: URL?
    @State private var resultSeconds: Double = 0
    @State private var errorText: String?
    @State private var showFiles = false

    private let gaps: [Double] = [0, 0.5, 1, 2]

    var body: some View {
        ToolPage(title: "Join & Speed",
                 subtitle: "Join clips into one, or speed up / slow down without chipmunk voices.",
                 working: working) {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                if let url = resultURL { result(url) }
                else {
                    Picker("", selection: $mode) {
                        Text(L("Join clips")).tag(Mode.join)
                        Text(L("Change speed")).tag(Mode.speed)
                    }.pickerStyle(.segmented)
                    if mode == .join { joinEditor } else { speedEditor }
                    if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
                    if working { ToolProgressBar(value: progress, label: mode == .join ? "Joining…" : "Changing speed…") }
                }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.audio, .movie],
                      allowsMultipleSelection: mode == .join) { res in
            if case .success(let urls) = res { add(urls) }
        }
        .onChange(of: mode) { _, m in
            errorText = nil
            if m == .speed, clips.count > 1 { clips = Array(clips.prefix(1)) }
        }
        .finishes(working, tool: "Join & Speed")
        .handoff("audiomix") { p in if let u = ToolHandoff.fileURL(p) { add([u]) } }
    }

    // MARK: - Join

    private var joinEditor: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if clips.isEmpty {
                Text(L("Pick two or more recordings, songs or videos. They play one after another in the order shown."))
                    .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
            }
            ForEach(Array(clips.enumerated()), id: \.element.id) { i, c in
                HStack(spacing: HandySpacing.s8) {
                    Text("\(i + 1)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.name).font(HandyFont.bodyStrong).lineLimit(1)
                        Text(AudioCompressView.duration(c.seconds)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    }
                    Spacer()
                    iconButton("arrow.up", L("Move up"), disabled: i == 0) { clips.swapAt(i, i - 1) }
                    iconButton("arrow.down", L("Move down"), disabled: i == clips.count - 1) { clips.swapAt(i, i + 1) }
                    iconButton("trash", L("Remove"), disabled: false) { clips.remove(at: i) }
                }
                .cardStyle(padding: HandySpacing.s12)
            }
            Button { showFiles = true } label: {
                Label(clips.isEmpty ? L("Choose clips") : L("Add more"), systemImage: "plus").frame(maxWidth: .infinity)
            }.secondaryButton()
            if clips.count >= 2 {
                Text(L("Pause between clips")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Picker("", selection: $gap) {
                    ForEach(gaps, id: \.self) { g in Text(g == 0 ? L("None") : "\(g.formatted()) s").tag(g) }
                }.pickerStyle(.segmented)
                let total = clips.reduce(0) { $0 + $1.seconds } + gap * Double(clips.count - 1)
                Text("\(L("Total")) \(AudioCompressView.duration(total))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Button { runJoin() } label: {
                    Label(L("Join into one"), systemImage: "link").frame(maxWidth: .infinity)
                }.primaryButton().disabled(working)
            }
        }
    }

    // MARK: - Speed

    private var speedEditor: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if let c = clips.first {
                HStack {
                    Image(systemName: "waveform").foregroundStyle(HandyColor.accent)
                    Text(c.name).font(HandyFont.bodyStrong).lineLimit(1)
                    Spacer()
                    Text(AudioCompressView.duration(c.seconds)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                .cardStyle(padding: HandySpacing.s12)
                HStack(spacing: HandySpacing.s8) {
                    ForEach(AudioMix.speeds, id: \.self) { s in
                        Button("\(s.formatted())×") { rate = s }
                            .font(HandyFont.caption).buttonStyle(.bordered)
                            .tint(rate == s ? HandyColor.accent : HandyColor.textSecondary)
                    }
                }
                Text("\(rate > 1 ? L("Faster") : L("Slower")) — \(L("new length")) \(AudioCompressView.duration(c.seconds / rate)). \(L("Voices keep their natural pitch."))")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Button { runSpeed() } label: {
                    Label(L("Change speed"), systemImage: "speedometer").frame(maxWidth: .infinity)
                }.primaryButton().disabled(working)
                Button(L("Choose a different file")) { clips = [] }.textButton().font(HandyFont.caption)
                    .frame(maxWidth: .infinity)
            } else {
                Text(L("Pick a lecture, podcast or voice memo to play faster or slower."))
                    .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                Button { showFiles = true } label: {
                    Label(L("Choose a file"), systemImage: "folder").frame(maxWidth: .infinity)
                }.primaryButton()
            }
        }
    }

    private func iconButton(_ icon: String, _ label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? HandyColor.textSecondary.opacity(0.4) : HandyColor.accent)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    // MARK: - Result

    private func result(_ url: URL) -> some View {
        VStack(spacing: HandySpacing.s8) {
            Label("\(mode == .join ? L("Joined") : L("Speed changed")) — \(AudioCompressView.duration(resultSeconds))",
                  systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            AudioPlayBar(url: url)
            ShareLink(item: url) {
                Label(L("Save or share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }.primaryButton()
            Button(L("Back to editing")) { resultURL = nil; progress = 0 }.textButton().font(HandyFont.caption)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    // MARK: - Actions

    private func add(_ urls: [URL]) {
        errorText = nil
        var added: [Clip] = []
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let local = FileManager.default.temporaryDirectory
                .appendingPathComponent("amix-\(UUID().uuidString.prefix(6)).\(url.pathExtension.isEmpty ? "audio" : url.pathExtension)")
            guard (try? FileManager.default.copyItem(at: url, to: local)) != nil else { continue }
            added.append(Clip(url: local, name: url.deletingPathExtension().lastPathComponent))
        }
        if added.count < urls.count { errorText = "Some files couldn't be opened." }
        if mode == .speed { clips = Array(added.prefix(1)) } else { clips += added }
        for c in added {
            Task {
                let d = (try? await AVURLAsset(url: c.url).load(.duration))?.seconds ?? 0
                await MainActor.run {
                    if let i = clips.firstIndex(where: { $0.id == c.id }) { clips[i].seconds = d.isFinite ? d : 0 }
                }
            }
        }
    }

    private func runJoin() {
        let urls = clips.map(\.url), g = gap
        start { p in await AudioMix.merge(urls, gap: g, progress: p) }
    }

    private func runSpeed() {
        guard let src = clips.first?.url else { return }
        let r = rate
        start { p in await AudioMix.speed(src, rate: r, progress: p) }
    }

    private func start(_ job: @escaping (@escaping (Double) -> Void) async -> Result<URL, AudioMix.Failure>) {
        working = true; errorText = nil; progress = 0
        let base = mode == .join ? "Joined" : "\(clips.first?.name ?? "Audio") (\(rate.formatted())x)"
        let name = base.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        Task {
            let outcome = await job { p in Task { @MainActor in progress = p } }
            var secs = 0.0
            if case .success(let u) = outcome { secs = (try? await AVURLAsset(url: u).load(.duration))?.seconds ?? 0 }
            await MainActor.run {
                working = false
                switch outcome {
                case .success(let tmp):
                    let named = FileManager.default.temporaryDirectory.appendingPathComponent("\(String(name.prefix(60))).m4a")
                    try? FileManager.default.removeItem(at: named)
                    resultURL = (try? FileManager.default.moveItem(at: tmp, to: named)) != nil ? named : tmp
                    resultSeconds = secs
                    HandyHaptics.success()
                case .failure(let f):
                    errorText = f.message
                }
            }
        }
    }
}
