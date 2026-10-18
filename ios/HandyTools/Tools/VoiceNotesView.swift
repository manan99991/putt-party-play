import SwiftUI

/// Voice → Notes — talk, get a transcript as you go, and when you stop: a summary and the to-dos
/// pulled out. Notes are kept on the phone, searchable, shareable. No account, no upload.
struct VoiceNotesView: View {
    @EnvironmentObject var store: StoreManager
    @StateObject private var speech = SpeechStream()
    @StateObject private var notes = VoiceNoteStore()
    @State private var summary: [String] = []
    @State private var todos: [String] = []
    @State private var working = false
    @State private var query = ""
    @State private var showLanguages = false
    @State private var note: String?

    private var overQuota: Bool { !Usage.hasRoom("audio", limit: Limits.freeAudioPerDay) }

    var body: some View {
        ToolPage(title: "Voice → Notes", subtitle: "Talk it out. Get the transcript, a summary and the to-dos — kept on your phone.") {
            VStack(spacing: HandySpacing.s8) {
                ScrollView {
                    Text(speech.transcript.isEmpty ? (speech.running ? "Listening…" : "Tap record and start talking. Meetings, lectures, ideas on a walk.") : speech.transcript)
                        .font(HandyFont.body).foregroundStyle(speech.transcript.isEmpty ? HandyColor.textSecondary : HandyColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }
                .frame(height: 200).padding(HandySpacing.s12)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(speech.running ? HandyColor.danger : HandyColor.border, lineWidth: speech.running ? 2 : 1))
                HStack(spacing: HandySpacing.s8) {
                    Button { toggle() } label: { Label(speech.running ? "Stop" : (speech.transcript.isEmpty ? "Record" : "Continue"), systemImage: speech.running ? "stop.fill" : "mic.fill").frame(maxWidth: .infinity) }
                        .primaryButton().disabled(overQuota && !speech.running)
                    Button { showLanguages = true } label: { Image(systemName: "globe").frame(width: 36, height: 36) }.compactButton()
                    if !speech.transcript.isEmpty && !speech.running { Button(role: .destructive) { speech.clear(); summary = []; todos = [] } label: { Image(systemName: "trash").frame(width: 36, height: 36) }.compactButton() }
                }
                if !store.isPremium { QuotaChip(name: "audio", limit: Limits.freeAudioPerDay).environmentObject(store) }
                if overQuota && !speech.running { LimitReachedBanner(message: "You've used today's \(Limits.freeAudioPerDay) free recordings.") }
                if let e = speech.errorText { LimitNote(e) }
            }

            if !speech.transcript.isEmpty && !speech.running {
                if summary.isEmpty && todos.isEmpty {
                    Button { digest() } label: { HStack { if working { ProgressView().tint(.white) }; Label(working ? "Reading…" : "Summary + to-dos", systemImage: "list.bullet.clipboard") }.frame(maxWidth: .infinity) }.secondaryButton().disabled(working)
                } else {
                    VStack(alignment: .leading, spacing: HandySpacing.s8) {
                        if !summary.isEmpty { Text("Summary").font(HandyFont.bodyStrong); ForEach(summary, id: \.self) { Text("• \($0)").font(HandyFont.body) } }
                        if !todos.isEmpty { Text("To-dos").font(HandyFont.bodyStrong).padding(.top, 4); ForEach(todos, id: \.self) { Label($0, systemImage: "circle").font(HandyFont.body) } }
                        if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                    }.cardStyle(padding: HandySpacing.s12)
                }
                HStack(spacing: HandySpacing.s8) {
                    Button { save() } label: { Label("Save note", systemImage: "tray.and.arrow.down").frame(maxWidth: .infinity) }.primaryButton()
                    ShareLink(item: exportText) { Label("Share", systemImage: "square.and.arrow.up") }.compactButton()
                    Button { UIPasteboard.general.string = exportText; HandyHaptics.success() } label: { Image(systemName: "doc.on.doc").frame(width: 36, height: 36) }.compactButton()
                }
            }

            if !notes.items.isEmpty {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    HStack { Text("Saved notes").font(HandyFont.bodyStrong); Spacer(); Text("\(notes.items.count)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                    TextField("Search notes", text: $query).padding(HandySpacing.s8).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    ForEach(notes.items.filter { query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) || $0.title.localizedCaseInsensitiveContains(query) }) { n in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(n.title).font(HandyFont.bodyStrong).lineLimit(1); Spacer(); Text(n.date.formatted(date: .abbreviated, time: .shortened)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
                            Text(n.summary.isEmpty ? n.text : n.summary.joined(separator: " · ")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(3)
                            HStack(spacing: HandySpacing.s8) {
                                ShareLink(item: n.export) { Label("Share", systemImage: "square.and.arrow.up") }.textButton()
                                Button(role: .destructive) { notes.delete(n) } label: { Label("Delete", systemImage: "trash") }.textButton()
                                Spacer()
                            }
                        }.cardStyle(padding: HandySpacing.s12)
                    }
                }
            }
            Text(speech.onDevice ? "Transcribed on your phone; nothing is uploaded." : "This language is transcribed by Apple's servers on this phone.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .onDisappear { speech.stop() }
        .sheet(isPresented: $showLanguages) { LanguagePicker(selected: $speech.locale) }
    }

    private var exportText: String {
        var s = speech.transcript
        if !summary.isEmpty { s += "\n\nSummary:\n" + summary.map { "• " + $0 }.joined(separator: "\n") }
        if !todos.isEmpty { s += "\n\nTo-dos:\n" + todos.map { "☐ " + $0 }.joined(separator: "\n") }
        return s
    }

    private func toggle() {
        if speech.running { speech.stop(); summary = []; todos = [] }
        else { guard Usage.use("audio", limit: Limits.freeAudioPerDay) else { return }; speech.start() }
    }

    private func digest() {
        working = true; note = nil
        let t = speech.transcript
        Task { @MainActor in
            defer { working = false }
            if AIEngine.isAvailable, Usage.use("ai", limit: Limits.freeAiPerDay), let out = try? await AIEngine.run(instructions: "Read a spoken transcript. Return two sections exactly: 'SUMMARY:' with 3–5 short bullet lines, then 'TODOS:' with every task, commitment or follow-up as one bullet each (or 'none'). No other text.", prompt: t) {
                let parts = out.components(separatedBy: "TODOS:")
                summary = Self.bullets(parts.first?.replacingOccurrences(of: "SUMMARY:", with: "") ?? "")
                todos = Self.bullets(parts.count > 1 ? parts[1] : "").filter { $0.lowercased() != "none" }
                if summary.isEmpty && todos.isEmpty { fallback(t) }
            } else { fallback(t) }
            HandyHaptics.success()
        }
    }
    private func fallback(_ t: String) {
        summary = TextTools.summarize(t, sentences: 3); todos = TextTools.actionItems(t)
        note = AIEngine.isAvailable ? nil : "Key sentences and task-like lines, picked by the built-in engine (Apple Intelligence would write a proper summary)."
    }
    private static func bullets(_ s: String) -> [String] {
        s.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " •-*☐0123456789.)")) }.filter { $0.count > 2 }
    }

    private func save() {
        let title = (summary.first ?? TextTools.sentences(speech.transcript).first ?? "Voice note").prefix(60)
        notes.add(VoiceNote(title: String(title), text: speech.transcript, summary: summary, todos: todos))
        HandyHaptics.success()
    }
}

struct VoiceNote: Identifiable, Codable {
    var id = UUID(); var date = Date(); var title: String; var text: String; var summary: [String]; var todos: [String]
    var export: String { "\(title)\n\(date.formatted())\n\n\(text)" + (summary.isEmpty ? "" : "\n\nSummary:\n" + summary.map { "• " + $0 }.joined(separator: "\n")) + (todos.isEmpty ? "" : "\n\nTo-dos:\n" + todos.map { "☐ " + $0 }.joined(separator: "\n")) }
}

@MainActor final class VoiceNoteStore: ObservableObject {
    @Published var items: [VoiceNote] = VoiceNoteStore.load()
    nonisolated private static var url: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("voice-notes.json") }
    nonisolated private static func load() -> [VoiceNote] { (try? JSONDecoder().decode([VoiceNote].self, from: Data(contentsOf: url))) ?? [] }
    private func persist() { try? JSONEncoder().encode(items).write(to: Self.url) }
    func add(_ n: VoiceNote) { items.insert(n, at: 0); persist() }
    func delete(_ n: VoiceNote) { items.removeAll { $0.id == n.id }; persist() }
}
