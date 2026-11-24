import SwiftUI
import UIKit
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
    @State private var digest: MeetingDigest.Result?
    @State private var emailSubject = ""
    @State private var phase = "Transcribing on your phone…"
    @State private var copied: String?
    @State private var remindersNote: String?
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
            FromVideosButton { if let u = $0.first { load(u) } }
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
                ToolProgressBar(value: progress, label: phase)
            }

            if let e = errorText {
                Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if hasResult {
                if let d = digest {
                    section(title: "Summary", systemImage: "list.bullet.clipboard", headline: d.headline, lines: summary.map { "• " + $0 },
                            shareText: d.headline + "\n" + summary.map { "• " + $0 }.joined(separator: "\n"),
                            spoken: d.headline + ". " + MeetingDigest.speakable(summary))
                    if !d.decisions.isEmpty {
                        section(title: "Decisions", systemImage: "checkmark.seal", headline: nil, lines: d.decisions.map { "• " + $0 },
                                shareText: "Decisions\n" + d.decisions.map { "• " + $0 }.joined(separator: "\n"), spoken: MeetingDigest.speakable(d.decisions))
                    }
                    if todos.isEmpty {
                        Text(L("No to-dos were agreed in this meeting.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        section(title: "To-dos", systemImage: "checklist", headline: nil, lines: todos.map { "☐ " + $0 },
                                shareText: "To-dos\n" + todos.map { "☐ " + $0 }.joined(separator: "\n"), spoken: MeetingDigest.speakable(todos))
                    }
                }
                if !todos.isEmpty {
                    Button {
                        let list = "Meeting \(Date().formatted(date: .abbreviated, time: .omitted))"
                        let entries = (digest?.actions ?? []).map { a in
                            PlannerStore.Entry(text: a.task, list: list, due: a.due.flatMap { Understand.due(in: "by " + $0, now: Date()) },
                                               person: a.owner == "Me" || a.owner == "Us" ? nil : a.owner, source: "Meeting notes")
                        }
                        Task {
                            let n = (try? await PlannerStore.toReminders(entries)) ?? -1
                            remindersNote = n < 0 ? "Allow Reminders for Tenzy in Settings, then tap again." : "\(n) to-do\(n == 1 ? "" : "s") added to Reminders, with who and when where it was said."
                            if n > 0 { HandyHaptics.success() }
                        }
                    } label: { Label(L("Put the to-dos in Reminders"), systemImage: "checklist").frame(maxWidth: .infinity) }.secondaryButton()
                        .accessibilityIdentifier("meeting-reminders")
                    if let remindersNote { Text(L(remindersNote)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
                }
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

    private func section(title: String, systemImage: String, headline: String?, lines: [String], shareText: String, spoken: String) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack {
                Label(L(title), systemImage: systemImage).font(HandyFont.bodyStrong)
                Spacer()
                SummaryActions(title: L(title), text: shareText, spoken: spoken, compact: true)
                copyButton(shareText, id: title)
            }
            if let headline { Text(headline).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary).fixedSize(horizontal: false, vertical: true) }
            // Short on purpose — every line shows; nothing hidden in a tiny scroll box.
            VStack(alignment: .leading, spacing: 6) {
                ForEach(lines, id: \.self) { Text($0).font(HandyFont.body).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true).textSelection(.enabled) }
            }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    /// Copy, with a tick so you know it worked.
    private func copyButton(_ text: String, id: String) -> some View {
        Button {
            Copier.copy(text); HandyHaptics.success()
            withAnimation { copied = id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { if copied == id { withAnimation { copied = nil } } }
        } label: {
            Image(systemName: copied == id ? "checkmark" : "doc.on.doc").frame(width: 36, height: 36).contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(HandyColor.accent)
        .accessibilityLabel(L(copied == id ? "Copied" : "Copy"))
        .accessibilityIdentifier("copy-\(id)")
    }

    private var turnsSection: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack {
                Label(L("Turns"), systemImage: "person.wave.2").font(HandyFont.bodyStrong)
                Spacer()
                copyButton(turns.map { "\(L("Turn")) \($0.index) · \(MeetingNotes.clock($0.start))\n\($0.text)" }.joined(separator: "\n\n"), id: "turns")
            }
            Text(L("Split where the talking pauses. On-device transcription can't tell voices apart, so turns are timed, not named."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    ForEach(turns) { t in
                        HStack(alignment: .top, spacing: HandySpacing.s4) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(L("Turn")) \(t.index) · \(MeetingNotes.clock(t.start))")
                                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).monospacedDigit()
                                Text(MeetingDigest.clean(t.text)).font(HandyFont.body).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                            }
                            copyButton(MeetingDigest.clean(t.text), id: "turn-\(t.index)")
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
                copyButton("Subject: \(emailSubject)\n\n\(emailDraft)", id: "email")
            }
            if !emailSubject.isEmpty {
                Text("\(L("Subject:")) \(emailSubject)").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary).textSelection(.enabled)
            }
            if !people.isEmpty {
                Text("\(L("Addressed to:")) \(people.prefix(4).joined(separator: ", "))")
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            Text(emailDraft).font(HandyFont.body).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            HStack(spacing: HandySpacing.s8) {
                if let mail = mailURL {
                    Button { UIApplication.shared.open(mail) } label: { Label(L("Open in Mail"), systemImage: "envelope.open").frame(maxWidth: .infinity) }.primaryButton()
                        .accessibilityIdentifier("meeting-mail")
                }
                ShareLink(item: emailDraft, subject: Text(emailSubject)) { Label(L("Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
            }
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

    private var mailURL: URL? {
        var c = URLComponents(string: "mailto:")
        c?.queryItems = [URLQueryItem(name: "subject", value: emailSubject), URLQueryItem(name: "body", value: emailDraft)]
        return c?.url
    }

    private var fullExport: String {
        var s = "\(fileName) — meeting notes\n"
        if let d = digest { s += "\n" + d.headline + "\n" }
        if !summary.isEmpty { s += "\nSummary:\n" + summary.map { "• " + $0 }.joined(separator: "\n") + "\n" }
        if let d = digest, !d.decisions.isEmpty { s += "\nDecisions:\n" + d.decisions.map { "• " + $0 }.joined(separator: "\n") + "\n" }
        if !todos.isEmpty { s += "\nTo-dos:\n" + todos.map { "☐ " + $0 }.joined(separator: "\n") + "\n" }
        if !emailDraft.isEmpty { s += "\nFollow-up email:\nSubject: \(emailSubject)\n\n" + emailDraft + "\n" }
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
        // The best writer this phone has: Apple Intelligence reads the whole meeting part by part and merges it;
        // without it (or over the free daily limit), the stricter built-in engine.
        var result: MeetingDigest.Result?
        if AIEngine.isAvailable, Usage.hasRoom("ai", limit: Limits.freeAiPerDay) {
            progress = 0
            result = await MeetingDigest.onDevice(text) { i, n in
                Task { @MainActor in phase = "Writing the notes · part \(i) of \(n)…"; progress = Double(i - 1) / Double(max(1, n)) }
            }
            if result != nil { _ = Usage.use("ai", limit: Limits.freeAiPerDay) }
        }
        let d = result ?? MeetingDigest.builtIn(text)
        digest = d
        summary = d.points
        todos = d.actions.map(\.line)
        aiNote = d.engine == .onDevice ? "Written by Apple Intelligence, on your phone."
            : (AIEngine.isAvailable ? "Written by Tenzy's built-in engine (today's free Apple Intelligence notes are used up)."
                                    : "Written by Tenzy's built-in engine. On iPhone 15 Pro or newer with Apple Intelligence on, Tenzy writes fuller notes.")
        let mail = MeetingDigest.email(d, people: people, meeting: fileName)
        emailSubject = mail.subject
        emailDraft = mail.body
        working = false
        HandyHaptics.success()
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
        transcript = ""; summary = []; todos = []; turns = []; people = []; digest = nil; emailSubject = ""
        phase = "Transcribing on your phone…"
        emailDraft = ""; errorText = nil; aiNote = nil; progress = 0
    }
}
