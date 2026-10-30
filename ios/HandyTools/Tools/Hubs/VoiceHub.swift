import SwiftUI
import UniformTypeIdentifiers

/// Voice Notes hub — record (live waveform + transcript), import a file, then Transcript / Summary /
/// To-dos / Trim, playback with a seek bar, a searchable saved-notes library, and Live Captions as a
/// second tab. Everything runs on the phone: SpeechStream (SFSpeechRecognizer + the mic tap also
/// writes the audio), SFSpeechURLRecognitionRequest for files, AVAssetExportSession for trims.
struct VoiceHub: View {
    @EnvironmentObject var store: StoreManager
    @StateObject private var speech = SpeechStream()
    @StateObject private var player = AudioPlayback()
    @StateObject private var notes = VoiceNoteStore()
    @State private var tab = 0        // Voice notes / Live captions
    @State private var pane = 0       // Transcript / Summary / To-dos / Trim
    @State private var levels: [Float] = Array(repeating: 0.05, count: 48)
    @State private var peaks: [Float] = []
    @State private var started: Date?
    @State private var elapsed = 0.0
    @State private var audioURL: URL?
    @State private var duration = 0.0
    @State private var transcript = ""
    @State private var summary: [String] = []
    @State private var todos: [String] = []
    @State private var done: Set<Int> = []
    @State private var aiDone = false
    @State private var working = false
    @State private var importing = false
    @State private var trimming = false
    @State private var trimA = 0.0
    @State private var trimB = 1.0
    @State private var query = ""
    @State private var showFiles = false
    @State private var showLanguages = false
    @State private var status: String?
    private let clock = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var overQuota: Bool { !Usage.hasRoom("audio", limit: Limits.freeAudioPerDay) }
    private var hasResult: Bool { !transcript.isEmpty || audioURL != nil }

    var body: some View {
        PowerToolPage(id: "voice", tabs: ["Voice notes", "Live captions"], selected: $tab) {
            Group {
                if tab == 0 { recorderPane } else { LiveCaptionsView().environment(\.embeddedInHub, true) }
            }
        }
        .onReceive(clock) { _ in if speech.running, let s = started { elapsed = Date().timeIntervalSince(s) } }
        .onChange(of: speech.level) { _, v in guard speech.running else { return }; levels.removeFirst(); levels.append(max(0.05, v)) }
        .onChange(of: speech.running) { was, now in if was, !now { finishedRecording() } }
        .onChange(of: tab) { _, t in if t == 1, speech.running { speech.stop() } }
        .onDisappear { speech.stop(); player.stop() }
        .sheet(isPresented: $showLanguages) { LanguagePicker(selected: $speech.locale) }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.audio]) { res in
            if case .success(let url) = res { importFile(url) }
        }
    }

    // MARK: - Recorder

    @ViewBuilder private var recorderPane: some View {
        preview
        HStack(spacing: HandySpacing.s8) {
            Button { toggleRecord() } label: { Label(speech.running ? "Stop" : "Record", systemImage: speech.running ? "stop.fill" : "record.circle").frame(maxWidth: .infinity) }
                .primaryButton().disabled((overQuota && !speech.running) || importing)
            Button { showFiles = true } label: { Label("Import", systemImage: "folder") }.secondaryButton().disabled(speech.running || importing || overQuota)
            Button { showLanguages = true } label: { Image(systemName: "globe").frame(width: 36, height: 36) }.compactButton().accessibilityLabel("Transcription language")
        }
        if !store.isPremium { QuotaChip(name: "audio", limit: Limits.freeAudioPerDay).environmentObject(store) }
        if overQuota && !speech.running { LimitReachedBanner(message: "You've used today's \(Limits.freeAudioPerDay) free recordings.") }
        if let e = speech.errorText { LimitNote(e) }
        if let status { LimitNote(status) }
        HubNote(speech.onDevice ? "Needs the mic and speech recognition. Transcribed on your phone — nothing is uploaded." : "Needs the mic and speech recognition. This language is transcribed by Apple's servers.")
        if hasResult && !speech.running && !importing { result }
        library
    }

    private var preview: some View {
        HubPreviewBox(minHeight: 170) {
            VStack(spacing: HandySpacing.s8) {
                Waveform(values: speech.running || peaks.isEmpty ? levels : peaks, active: speech.running, keep: pane == 3 && hasResult ? trimA...trimB : nil)
                    .frame(height: 64)
                Text(timeLabel).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).monospacedDigit()
                if speech.running {
                    Text(speech.transcript.isEmpty ? "Listening…" : tail(speech.transcript)).font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                } else if importing {
                    HStack(spacing: HandySpacing.s8) { ProgressView(); Text("Transcribing on your phone…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                    if !transcript.isEmpty { Text(tail(transcript)).font(HandyFont.caption).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading) }
                } else if !hasResult {
                    Text("Tap Record and talk — meetings, lectures, ideas on a walk. Or import a recording.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                }
            }
            .padding(14)
        }
    }

    private var timeLabel: String {
        if speech.running { return "\(VoiceAudio.clock(elapsed)) · recording" }
        if audioURL != nil { return "\(VoiceAudio.clock(player.url == audioURL ? player.time : 0)) / \(VoiceAudio.clock(duration))" }
        return VoiceAudio.clock(0)
    }

    private func tail(_ s: String) -> String { s.count > 220 ? "…" + String(s.suffix(220)) : s }

    // MARK: - Result

    @ViewBuilder private var result: some View {
        FlowLayout(spacing: 6) {
            HubChip("Transcript", selected: pane == 0) { pane = 0 }
            HubChip("Summary", selected: pane == 1) { pane = 1 }
            HubChip("To-dos (\(todos.count))", selected: pane == 2) { pane = 2 }
            if audioURL != nil { HubChip("Trim", selected: pane == 3) { pane = 3 } }
        }
        Group {
            switch pane {
            case 1: summaryPane
            case 2: todosPane
            case 3: trimPane
            default: transcriptPane
            }
        }
        if let url = audioURL { playerBar(url) }
        FlowLayout(spacing: HandySpacing.s8) {
            Button { save() } label: { Label("Save note", systemImage: "tray.and.arrow.down") }.compactButton()
            Button { UIPasteboard.general.string = exportText; HandyHaptics.success(); status = "Copied." } label: { Label("Copy text", systemImage: "doc.on.doc") }.compactButton().disabled(transcript.isEmpty)
            ShareLink(item: exportText) { Label("Share", systemImage: "square.and.arrow.up") }.compactButton().disabled(transcript.isEmpty)
            if let url = audioURL { ShareLink(item: url) { Label("Share audio", systemImage: "waveform") }.compactButton() }
            Button(role: .destructive) { resetResult() } label: { Label("Discard", systemImage: "trash") }.textButton()
        }
    }

    private var transcriptPane: some View {
        ScrollView {
            Text(transcript.isEmpty ? "No speech recognised — the audio is still here to play, trim and save." : transcript)
                .font(HandyFont.body).foregroundStyle(transcript.isEmpty ? HandyColor.textSecondary : HandyColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
        }
        .frame(maxHeight: 260).padding(HandySpacing.s12)
        .cardStyle(padding: 0)
    }

    private var summaryPane: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            if summary.isEmpty { Text("Nothing to summarise yet.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary) }
            ForEach(summary, id: \.self) { Text("• \($0)").font(HandyFont.body).frame(maxWidth: .infinity, alignment: .leading) }
            if !aiDone, !transcript.isEmpty {
                Button { aiDigest() } label: { HStack { if working { ProgressView().tint(.white) }; Label(working ? "Reading…" : "Better summary", systemImage: "sparkles") } }.compactButton().disabled(working)
                HubNote(AIEngine.isAvailable ? "Key sentences picked by the built-in engine — tap for an Apple Intelligence summary, on your phone." : "Key sentences picked by the built-in engine (Apple Intelligence would write a proper summary).")
            }
        }.cardStyle(padding: HandySpacing.s12)
    }

    private var todosPane: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            if todos.isEmpty { Text("No action items found.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary) }
            ForEach(Array(todos.enumerated()), id: \.offset) { i, t in
                Button { if done.contains(i) { done.remove(i) } else { done.insert(i) }; HandyHaptics.light() } label: {
                    HStack(alignment: .top, spacing: HandySpacing.s8) {
                        Image(systemName: done.contains(i) ? "checkmark.circle.fill" : "circle").foregroundStyle(done.contains(i) ? HandyColor.success : HandyColor.textSecondary)
                        Text(t).font(HandyFont.body).strikethrough(done.contains(i)).foregroundStyle(done.contains(i) ? HandyColor.textSecondary : HandyColor.textPrimary).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                }.buttonStyle(.plain)
            }
        }.cardStyle(padding: HandySpacing.s12)
    }

    private var trimPane: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HubSection("Keep from · to")
            HStack { Text(VoiceAudio.clock(trimA * duration)).monospacedDigit(); Spacer(); Text(VoiceAudio.clock(trimB * duration)).monospacedDigit() }.font(HandyFont.bodyStrong)
            Slider(value: $trimA, in: 0...1).tint(HandyColor.accent).accessibilityLabel("Start")
                .onChange(of: trimA) { _, v in if v > trimB - 0.02 { trimA = max(0, trimB - 0.02) } }
            Slider(value: $trimB, in: 0...1).tint(HandyColor.accent).accessibilityLabel("End")
                .onChange(of: trimB) { _, v in if v < trimA + 0.02 { trimB = min(1, trimA + 0.02) } }
            Button { trimSave() } label: { HStack { if trimming { ProgressView() }; Label(trimming ? "Trimming…" : "Trim & save copy", systemImage: "scissors") }.frame(maxWidth: .infinity) }.secondaryButton().disabled(trimming)
            HubNote("The original stays as it is; the trimmed copy lands in your saved notes.")
        }.cardStyle(padding: HandySpacing.s12)
    }

    private func playerBar(_ url: URL) -> some View {
        HStack(spacing: HandySpacing.s8) {
            Button { player.toggle(url) } label: { Image(systemName: player.playing && player.url == url ? "pause.fill" : "play.fill").frame(width: 36, height: 36) }.compactButton().accessibilityLabel("Play")
            Slider(value: Binding(get: { player.url == url ? player.time : 0 }, set: { if player.url != url { player.load(url) }; player.seek($0) }), in: 0...max(1, duration)).tint(HandyColor.accent).accessibilityLabel("Position")
            Text(VoiceAudio.clock(player.url == url ? player.time : 0)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).monospacedDigit()
        }
    }

    // MARK: - Library

    @ViewBuilder private var library: some View {
        HubSection("Saved notes")
        if notes.items.isEmpty {
            HubNote("No notes yet.")
        } else {
            TextField("Search notes", text: $query).padding(HandySpacing.s8).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.small, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.small, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            ForEach(notes.items.filter { query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) || $0.title.localizedCaseInsensitiveContains(query) }) { n in
                VStack(alignment: .leading, spacing: 4) {
                    Button { open(n) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(n.title).font(HandyFont.bodyStrong).lineLimit(1).foregroundStyle(HandyColor.textPrimary)
                            Text(meta(n)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                            Text(n.summary.isEmpty ? n.text : n.summary.joined(separator: " · ")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2).multilineTextAlignment(.leading)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain)
                    FlowLayout(spacing: HandySpacing.s8) {
                        if let u = n.audioURL { Button { player.toggle(u) } label: { Label(player.playing && player.url == u ? "Pause" : "Play", systemImage: player.playing && player.url == u ? "pause.fill" : "play.fill") }.textButton() }
                        ShareLink(item: n.export) { Label("Share", systemImage: "square.and.arrow.up") }.textButton()
                        Button(role: .destructive) { if player.url == n.audioURL { player.stop() }; notes.delete(n) } label: { Label("Delete", systemImage: "trash") }.textButton()
                    }
                }.cardStyle(padding: HandySpacing.s12)
            }
        }
    }

    private func meta(_ n: VoiceNote) -> String {
        let when = n.date.formatted(date: .abbreviated, time: .shortened)
        if let d = n.duration { return VoiceAudio.clock(d) + " · " + when }
        return when
    }

    // MARK: - Actions

    private var exportText: String {
        var s = transcript
        if !summary.isEmpty { s += "\n\nSummary:\n" + summary.map { "• " + $0 }.joined(separator: "\n") }
        if !todos.isEmpty { s += "\n\nTo-dos:\n" + todos.enumerated().map { (done.contains($0.offset) ? "☑ " : "☐ ") + $0.element }.joined(separator: "\n") }
        return s
    }

    private func toggleRecord() {
        if speech.running { speech.stop(); return }
        guard !overQuota else { return }
        resetResult()
        speech.clear(); status = nil
        speech.recordURL = VideoEngine.tempURL("caf")
        started = Date(); elapsed = 0
        levels = Array(repeating: 0.05, count: 48)
        speech.start()
    }

    private func finishedRecording() {
        transcript = speech.transcript
        quickDigest()
        guard let raw = speech.recordedURL else {
            if !transcript.isEmpty { _ = Usage.use("audio", limit: Limits.freeAudioPerDay) }
            return
        }
        Task { @MainActor in
            let url = await VoiceAudio.compact(raw)
            audioURL = url; duration = VoiceAudio.duration(url); player.load(url)
            peaks = await Task.detached(priority: .userInitiated) { VoiceAudio.peaks(url) }.value
            _ = Usage.use("audio", limit: Limits.freeAudioPerDay)   // counted only once there's something to keep
            HandyHaptics.success()
        }
    }

    private func importFile(_ url: URL) {
        guard !overQuota else { return }
        guard let local = VoiceAudio.importCopy(url) else { status = "Couldn't read that file."; return }
        resetResult()
        audioURL = local; duration = VoiceAudio.duration(local); player.load(local)
        importing = true; status = nil
        let locale = speech.locale
        Task { @MainActor in
            peaks = await Task.detached(priority: .userInitiated) { VoiceAudio.peaks(local) }.value
            let r = await VoiceAudio.transcribe(local, locale: locale) { t in Task { @MainActor in transcript = t } }
            transcript = r.text; status = r.error; importing = false
            quickDigest()
            _ = Usage.use("audio", limit: Limits.freeAudioPerDay)
            HandyHaptics.success()
        }
    }

    private func quickDigest() {
        summary = TextTools.summarize(transcript, sentences: 3); todos = TextTools.actionItems(transcript); done = []; aiDone = false
    }

    private func aiDigest() {
        guard AIEngine.isAvailable, Usage.hasRoom("ai", limit: Limits.freeAiPerDay) else { aiDone = true; return }
        working = true
        let t = transcript
        Task { @MainActor in
            defer { working = false }
            if let out = try? await AIEngine.run(instructions: "Read a spoken transcript. Return two sections exactly: 'SUMMARY:' with 3–5 short bullet lines, then 'TODOS:' with every task, commitment or follow-up as one bullet each (or 'none'). No other text.", prompt: t) {
                let parts = out.components(separatedBy: "TODOS:")
                let s = Self.bullets(parts.first?.replacingOccurrences(of: "SUMMARY:", with: "") ?? "")
                let d = Self.bullets(parts.count > 1 ? parts[1] : "").filter { $0.lowercased() != "none" }
                if !s.isEmpty || !d.isEmpty {
                    _ = Usage.use("ai", limit: Limits.freeAiPerDay)
                    if !s.isEmpty { summary = s }
                    if !d.isEmpty { todos = d; done = [] }
                    aiDone = true
                }
            }
            HandyHaptics.success()
        }
    }
    private static func bullets(_ s: String) -> [String] {
        s.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " •-*☐0123456789.)")) }.filter { $0.count > 2 }
    }

    private var noteTitle: String { String((summary.first ?? TextTools.sentences(transcript).first ?? "Voice note").prefix(60)) }

    private func save() {
        var name: String?
        if let src = audioURL {
            let n = "\(UUID().uuidString).\(src.pathExtension.isEmpty ? "m4a" : src.pathExtension)"
            if (try? FileManager.default.copyItem(at: src, to: VoiceNoteStore.audioDir.appendingPathComponent(n))) != nil { name = n }
        }
        notes.add(VoiceNote(title: noteTitle, text: transcript, summary: summary, todos: todos, audio: name, duration: audioURL == nil ? nil : duration))
        status = "Saved."; HandyHaptics.success()
    }

    private func trimSave() {
        guard let src = audioURL else { return }
        trimming = true; status = nil
        let d = duration, a = trimA, b = trimB
        Task { @MainActor in
            if let out = await VoiceAudio.trim(src, start: a * d, end: b * d) {
                let n = "\(UUID().uuidString).m4a"
                let dst = VoiceNoteStore.audioDir.appendingPathComponent(n)
                try? FileManager.default.moveItem(at: out, to: dst)
                notes.add(VoiceNote(title: "\(noteTitle) (trimmed)", text: transcript, summary: summary, todos: todos, audio: n, duration: VoiceAudio.duration(dst)))
                status = "Trimmed copy saved to your notes."; HandyHaptics.success()
            } else { status = "Couldn't trim that one. Try a smaller range." }
            trimming = false
        }
    }

    private func open(_ n: VoiceNote) {
        resetResult()
        transcript = n.text; summary = n.summary; todos = n.todos; aiDone = !n.summary.isEmpty
        if let u = n.audioURL, FileManager.default.fileExists(atPath: u.path) {
            audioURL = u; duration = n.duration ?? VoiceAudio.duration(u); player.load(u)
            Task { @MainActor in peaks = await Task.detached(priority: .userInitiated) { VoiceAudio.peaks(u) }.value }
        }
        status = "Opened “\(n.title)”."
    }

    private func resetResult() {
        if player.url == audioURL { player.stop() }
        audioURL = nil; duration = 0; peaks = []; transcript = ""; summary = []; todos = []; done = []
        aiDone = false; pane = 0; trimA = 0; trimB = 1; status = nil; speech.clear()
    }
}

/// 48 capsules whose heights follow the level history (live) or the file's RMS peaks (after stop).
/// With `keep` set, bars outside the trim range are dimmed.
private struct Waveform: View {
    let values: [Float]
    let active: Bool
    var keep: ClosedRange<Double>? = nil
    var body: some View {
        GeometryReader { geo in
            let n = max(1, values.count)
            let w = max(1, (geo.size.width - CGFloat(n - 1) * 2) / CGFloat(n))
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                    let inRange = keep.map { $0.contains(Double(i) / Double(n)) } ?? true
                    Capsule()
                        .fill(active ? HandyColor.danger : HandyColor.accent)
                        .opacity(inRange ? 1 : 0.25)
                        .frame(width: w, height: max(4, CGFloat(v) * geo.size.height))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(.linear(duration: 0.08), value: values)
        .accessibilityHidden(true)
    }
}
