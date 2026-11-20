import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

/// Join & Speed — two everyday audio jobs in one tool. Join: pick several clips (or videos), put them
/// in order, add an optional pause between them → one file. Speed: play a lecture or voice memo faster
/// or slower without the chipmunk effect. Live progress, then play the result before Save or Share.
struct AudioMixView: View {
    enum Mode: Hashable { case join, speed }
    struct Clip: Identifiable, Equatable { let id = UUID(); let url: URL; let name: String; var seconds: Double = 0; var unreadable = false; var why: String? = nil }

    @State private var mode: Mode = .join
    @State private var clips: [Clip] = []
    @State private var gap: Double = 0
    @State private var rate: Double = 1.5
    @State private var progress: Double = 0
    @State private var working = false
    @State private var resultURL: URL?
    @State private var resultSeconds: Double = 0
    /// Speed results, one per clip, in the same order — every clip you picked is kept.
    @State private var speedResults: [(name: String, url: URL, seconds: Double)] = []
    @State private var alsoJoin = false
    @State private var errorText: String?
    @State private var showFiles = false

    private let gaps: [Double] = [0, 0.5, 1, 2]

    var body: some View {
        ToolPage(title: "Join & Speed",
                 subtitle: "Join clips into one, or speed up / slow down without chipmunk voices.",
                 working: working) {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                if let url = resultURL { result(url) }
                else if !speedResults.isEmpty { speedResultList }
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
                      allowsMultipleSelection: true) { res in
            if case .success(let urls) = res { add(urls) }
        }
        // The clips you picked stay picked on both sides — switching to Change speed never drops any.
        .onChange(of: mode) { _, _ in errorText = nil }
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
                        if c.unreadable {
                            Text(c.why ?? L("No sound Tenzy can read in this file — remove it")).font(HandyFont.micro).foregroundStyle(HandyColor.danger)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(AudioCompressView.duration(c.seconds)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                        }
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
            if clips.isEmpty {
                Text(L("Pick lectures, podcasts or voice memos — one or several — to play faster or slower."))
                    .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                Button { showFiles = true } label: {
                    Label(L("Choose files"), systemImage: "folder").frame(maxWidth: .infinity)
                }.primaryButton()
            } else {
                ForEach(clips) { c in
                    HStack {
                        Image(systemName: "waveform").foregroundStyle(HandyColor.accent)
                        Text(c.name).font(HandyFont.bodyStrong).lineLimit(1)
                        Spacer()
                        Text("\(AudioCompressView.duration(c.seconds)) → \(AudioCompressView.duration(c.seconds / rate))")
                            .font(HandyFont.caption).monospacedDigit().foregroundStyle(HandyColor.textSecondary)
                        Button { clips.removeAll { $0.id == c.id } } label: { Image(systemName: "trash").frame(width: 32, height: 32) }
                            .buttonStyle(.plain).foregroundStyle(HandyColor.accent).accessibilityLabel(L("Remove"))
                    }
                    .cardStyle(padding: HandySpacing.s12)
                }
                Button { showFiles = true } label: { Label(L("Add more"), systemImage: "plus").frame(maxWidth: .infinity) }.secondaryButton()
                HStack(spacing: HandySpacing.s8) {
                    ForEach(AudioMix.speeds, id: \.self) { s in
                        Button("\(s.formatted())×") { rate = s }
                            .font(HandyFont.caption).buttonStyle(.bordered)
                            .tint(rate == s ? HandyColor.accent : HandyColor.textSecondary)
                    }
                }
                let total = clips.reduce(0) { $0 + $1.seconds }
                Text("\(rate > 1 ? L("Faster") : L("Slower")) — \(clips.count == 1 ? L("new length") : L("all together")) \(AudioCompressView.duration(total / rate)). \(L("Voices keep their natural pitch."))")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                if clips.count > 1 {
                    Toggle(L("Also join them into one file"), isOn: $alsoJoin).font(HandyFont.body).tint(HandyColor.accent)
                }
                Button { runSpeed() } label: {
                    Label(clips.count == 1 ? L("Change speed") : "\(L("Change speed of all")) \(clips.count)", systemImage: "speedometer").frame(maxWidth: .infinity)
                }.primaryButton().disabled(working)
            }
        }
    }

    /// Every sped-up clip, each playable and shareable, plus Save all — the same number of files you picked.
    private var speedResultList: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label("\(speedResults.count) \(L(speedResults.count == 1 ? "file" : "files")) \(L("at")) \(rate.formatted())×", systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
            ForEach(speedResults, id: \.url) { r in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(r.name).font(HandyFont.bodyStrong).lineLimit(1)
                        Spacer()
                        Text(AudioCompressView.duration(r.seconds)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        ShareLink(item: r.url) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel(L("Share"))
                    }
                    AudioPlayBar(url: r.url)
                }
                .cardStyle(padding: HandySpacing.s12)
            }
            ShareLink(items: speedResults.map(\.url)) {
                Label(speedResults.count == 1 ? L("Save or share") : "\(L("Save or share all")) (\(speedResults.count))", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }.primaryButton()
            Button(L("Back to editing")) { speedResults = []; progress = 0 }.textButton().font(HandyFont.caption)
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
            guard let took = AudioIntake.local(url) else { continue }
            added.append(Clip(url: took.url, name: took.name))
        }
        if added.count < urls.count { errorText = "Some files couldn't be opened." }
        clips += added
        for c in added {
            Task {
                let asset = AVURLAsset(url: c.url)
                let d = (try? await asset.load(.duration))?.seconds ?? 0
                let hasSound = !((try? await asset.loadTracks(withMediaType: .audio)) ?? []).isEmpty
                await MainActor.run {
                    if let i = clips.firstIndex(where: { $0.id == c.id }) {
                        clips[i].seconds = d.isFinite ? d : 0; clips[i].unreadable = !hasSound
                        if !hasSound, let t = AudioIntake.textInstead(c.url) {
                            clips[i].why = "\(L("This isn't a recording — the file only holds text, so the download probably failed. It says:")) \(t)"
                        }
                    }
                }
            }
        }
    }

    private func runJoin() {
        if let bad = clips.first(where: \.unreadable) {
            errorText = "“\(bad.name)” has no sound Tenzy can read — remove it to join the others."; return
        }
        let urls = clips.map(\.url), g = gap
        start { p in await AudioMix.merge(urls, gap: g, progress: p) }
    }

    private func runSpeed() {
        let items = clips.filter { !$0.unreadable }, r = rate, join = alsoJoin && clips.count > 1
        guard !items.isEmpty else { errorText = "None of these files has sound Tenzy can read."; return }
        working = true; errorText = nil; progress = 0
        Task {
            var out: [(name: String, url: URL, seconds: Double)] = []
            var failed = 0
            for (i, c) in items.enumerated() {
                let outcome = await AudioMix.speed(c.url, rate: r) { p in
                    Task { @MainActor in progress = (Double(i) + p) / Double(items.count + (join ? 1 : 0)) }
                }
                guard case .success(let tmp) = outcome else { failed += 1; continue }
                let name = "\(c.name) (\(r.formatted())x)".components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
                let named = FileManager.default.temporaryDirectory.appendingPathComponent("\(String(name.prefix(60))).m4a")
                try? FileManager.default.removeItem(at: named)
                let u = (try? FileManager.default.moveItem(at: tmp, to: named)) != nil ? named : tmp
                let d = (try? await AVURLAsset(url: u).load(.duration))?.seconds ?? 0
                out.append((name, u, d))
            }
            if join, out.count > 1, case .success(let j) = await AudioMix.merge(out.map(\.url), gap: 0, progress: { p in Task { @MainActor in progress = (Double(items.count) + p) / Double(items.count + 1) } }) {
                let d = (try? await AVURLAsset(url: j).load(.duration))?.seconds ?? 0
                out.append(("All joined (\(r.formatted())x)", j, d))
            }
            await MainActor.run {
                working = false
                speedResults = out
                if failed > 0 { errorText = "\(failed) of \(items.count) couldn't be changed — the others are ready." }
                if !out.isEmpty { HandyHaptics.success() }
            }
        }
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
