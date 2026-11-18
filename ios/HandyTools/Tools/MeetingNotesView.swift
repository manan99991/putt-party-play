import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

/// Meeting Notes: pick a recording of a meeting (an audio file, or a video — its audio is used) and Tenzy gets
/// to work the moment you pick it — transcribing on the phone, then showing the conversation split into turns,
/// a short summary, a clear to-do list, and a follow-up email already addressed to the people who were named.
/// Everything is on-device; nothing is uploaded. You read every part on screen before you copy or share it.
struct MeetingNotesView: View {
    @EnvironmentObject var store: StoreManager
    @State private var sourceURL: URL?
    @State private var fileName = "Meeting"
    @State private var working = false
    @State private var progress: Double = 0
    @State private var transcript = ""
    @State private var summary: [String] = []
    @State private var todos: [String] = []
    @State private var turns: [MeetingNotes.Turn] = []
    @State private var people: [String] = []
    @State private var emailDraft = ""
    @State private var errorText: String?
    @State private var aiNote: String?
    @State private var showFiles = false

    private var hasResult: Bool { !transcript.isEmpty }

    var body: some View {
        ToolPage(title: "Meeting Notes",
                 subtitle: "Pick a meeting recording — get the turns, a summary, the to-dos and a follow-up email, all on your phone.",
                 working: working) {
            HowTo("meetingnotes", [
                "Pick a meeting recording — an audio file, or a video (its sound is used).",
                "Tenzy transcribes it on your phone the moment you pick it; nothing is uploaded.",
                "Read the turns, summary, to-dos and the ready-made follow-up email, then copy or share.",
            ])
            VStack(spacing: HandySpacing.s16) {
                if sourceURL == nil {
                    pickCard
                } else {
                    workspace
                }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.audio, .movie, .mpeg4Movie]) { res in
            if case .success(let url) = res { load(url) }
        }
        .finishes(working, tool: "Meeting Notes")
        .handoff("meetingnotes") { p in if let u = ToolHandoff.fileURL(p) { load(u) } }
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "waveform.badge.mic").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose a recorded meeting, call or interview and Tenzy turns it into notes — on your phone."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Text(L("Works with M4A, MP3, WAV, AIFF, CAF and the audio from a video."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { showFiles = true } label: {
                Label(L("Choose a recording"), systemImage: "folder").frame(maxWidth: .infinity)
            }.primaryButton()
            if !store.isPremium { QuotaChip(name: "ai", limit: Limits.freeAiPerDay).environmentObject(store) }
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    // MARK: - Workspace

    private var workspace: some View {
        VStack(spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s8) {
                Image(systemName: "doc.text").foregroundStyle(HandyColor.accent)
                Text(fileName).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HandySpacing.s12)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))

            if working {
                ToolProgressBar(value: progress, label: "Transcribing on your phone…")
            }

            if let e = errorText {
                Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if hasResult {
                if !summary.isEmpty { section(title: "Summary", systemImage: "list.bullet.clipboard", lines: summary.map { "• " + $0 }, shareText: "Summary\n" + summary.map { "• " + $0 }.joined(separator: "\n")) }
                if !todos.isEmpty { section(title: "To-dos", systemImage: "checklist", lines: todos.map { "☐ " + $0 }, shareText: "To-dos\n" + todos.map { "☐ " + $0 }.joined(separator: "\n")) }
                if !turns.isEmpty { turnsSection }
                emailSection
                transcriptSection
                if let n = aiNote { Text(L(n)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
                ShareLink(item: fullExport) {
                    Label(L("Share all notes"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }.primaryButton()
            }

            Button(L("Choose a different recording")) { reset() }.textButton().font(HandyFont.caption)
            Text(L("Transcribed on your phone; nothing is uploaded."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private func section(title: String, systemImage: String, lines: [String], shareText: String) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack {
                Label(L(title), systemImage: systemImage).font(HandyFont.bodyStrong)
                Spacer()
                SummaryActions(title: L(title), text: shareText, compact: true)
                Button { Copier.copy(shareText) } label: { Image(systemName: "doc.on.doc").accessibilityLabel(L("Copy")).frame(width: 36, height: 36) }.buttonStyle(.plain).foregroundStyle(HandyColor.accent)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(lines, id: \.self) { Text($0).font(HandyFont.body).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                }
            }
            .frame(maxHeight: 160)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private var turnsSection: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Turns"), systemImage: "person.wave.2").font(HandyFont.bodyStrong)
            Text(L("Split where the talking pauses. On-device transcription can't tell voices apart, so turns are timed, not named."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    ForEach(turns) { t in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(L("Turn")) \(t.index) · \(MeetingNotes.clock(t.start))")
                                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).monospacedDigit()
                            Text(t.text).font(HandyFont.body).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                        }
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private var emailSection: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack {
                Label(L("Follow-up email"), systemImage: "envelope").font(HandyFont.bodyStrong)
                Spacer()
                Button { Copier.copy(emailDraft) } label: { Image(systemName: "doc.on.doc").accessibilityLabel(L("Copy")) }.buttonStyle(.plain).foregroundStyle(HandyColor.accent)
            }
            if !people.isEmpty {
                Text("\(L("Addressed to:")) \(people.prefix(4).joined(separator: ", "))")
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            ScrollView {
                Text(emailDraft).font(HandyFont.body).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }
            .frame(maxHeight: 200)
            ShareLink(item: emailDraft) { Label(L("Share email"), systemImage: "square.and.arrow.up") }.textButton().font(HandyFont.caption)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack {
                Label(L("Transcript"), systemImage: "text.alignleft").font(HandyFont.bodyStrong)
                Spacer()
                Button { Copier.copy(transcript) } label: { Image(systemName: "doc.on.doc").accessibilityLabel(L("Copy")) }.buttonStyle(.plain).foregroundStyle(HandyColor.accent)
            }
            ScrollView {
                Text(transcript).font(HandyFont.body).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }
            .frame(maxHeight: 200)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private var fullExport: String {
        var s = "\(fileName) — meeting notes\n"
        if !summary.isEmpty { s += "\nSummary:\n" + summary.map { "• " + $0 }.joined(separator: "\n") + "\n" }
        if !todos.isEmpty { s += "\nTo-dos:\n" + todos.map { "☐ " + $0 }.joined(separator: "\n") + "\n" }
        if !emailDraft.isEmpty { s += "\nFollow-up email:\n" + emailDraft + "\n" }
        s += "\nTranscript:\n" + transcript
        return s
    }

    // MARK: - Processing (starts the moment a file is picked)

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let local = FileManager.default.temporaryDirectory
            .appendingPathComponent("mnote-\(UUID().uuidString.prefix(6)).\(url.pathExtension.isEmpty ? "audio" : url.pathExtension)")
        try? FileManager.default.removeItem(at: local)
        guard (try? FileManager.default.copyItem(at: url, to: local)) != nil else {
            sourceURL = url; errorText = "Couldn't open that file."; return
        }
        sourceURL = local
        fileName = url.deletingPathExtension().lastPathComponent
        clearOutputs()
        working = true
        Task {
            let outcome = await MeetingNotes.transcribe(local) { p in
                Task { @MainActor in progress = p }
            }
            switch outcome {
            case .failure(let problem):
                await MainActor.run { working = false; errorText = message(for: problem) }
            case .success(let heard):
                await derive(from: heard.text, words: heard.words)
            }
        }
    }

    @MainActor private func derive(from text: String, words: [MeetingNotes.Timed]) async {
        transcript = text
        turns = MeetingNotes.turns(from: words)
        people = MeetingNotes.people(in: text)
        // Summary + to-dos: the on-device model when it's available and in quota, else the built-in text engine.
        if AIEngine.isAvailable, Usage.hasRoom("ai", limit: Limits.freeAiPerDay),
           let out = try? await AIEngine.run(instructions: "Read a meeting transcript. Return two sections exactly: 'SUMMARY:' with 3–5 short bullet lines, then 'TODOS:' with every task, decision or follow-up as one bullet each (or 'none'). No other text.", prompt: text) {
            _ = Usage.use("ai", limit: Limits.freeAiPerDay)
            let parts = out.components(separatedBy: "TODOS:")
            summary = Self.bullets(parts.first?.replacingOccurrences(of: "SUMMARY:", with: "") ?? "")
            todos = Self.bullets(parts.count > 1 ? parts[1] : "").filter { $0.lowercased() != "none" }
            aiNote = nil
            if summary.isEmpty && todos.isEmpty { fallbackDigest(text) }
        } else {
            fallbackDigest(text)
        }
        emailDraft = MeetingNotes.followUpEmail(people: people, summary: summary, todos: todos)
        working = false
        HandyHaptics.success()
    }

    private func fallbackDigest(_ text: String) {
        summary = TextTools.summarize(text, sentences: 3)
        todos = TextTools.actionItems(text)
        aiNote = AIEngine.isAvailable ? nil : "Summary and to-dos were picked out by the built-in engine (Apple Intelligence would write a fuller summary)."
    }

    private static func bullets(_ s: String) -> [String] {
        s.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " •-*☐0123456789.)")) }
            .filter { $0.count > 2 }
    }

    private func message(for p: Transcriber.Problem) -> String {
        switch p {
        case .denied: return "Meeting Notes needs permission to recognise speech. Allow Speech Recognition for Tenzy in Settings, then pick the recording again."
        case .unavailable: return "On-device transcription isn't available for this language on this phone right now."
        case .recognizerFailed: return "Couldn't run on-device dictation — your recording is fine. Turn on Dictation in Settings › General › Keyboard, let the language finish downloading, then try again."
        case .nothing: return "Didn't find any speech in that recording. If it has talking in it, make sure Dictation is on in Settings › General › Keyboard and try again."
        }
    }

    private func reset() {
        sourceURL = nil; fileName = "Meeting"; clearOutputs()
    }

    private func clearOutputs() {
        transcript = ""; summary = []; todos = []; turns = []; people = []
        emailDraft = ""; errorText = nil; aiNote = nil; progress = 0
    }
}
