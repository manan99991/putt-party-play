import SwiftUI

/// Text Studio — one box for everything you do to words before sending them: fix, rewrite in a
/// tone, shorten, expand, bullet, summarize, or draft a reply. Results chain back into the box.
/// On-device Apple Intelligence when the phone has it; real spelling/summary engines when it doesn't.
struct TextStudioView: View {
    @EnvironmentObject var store: StoreManager
    private enum Action: Int, CaseIterable { case fix, rewrite, shorten, expand, bullets, summarize, reply, subject
        var title: String { ["Fix", "Rewrite", "Shorten", "Expand", "Bullets", "Summarize", "Reply", "Subject line"][rawValue] }
        var icon: String { ["checkmark", "arrow.triangle.2.circlepath", "arrow.down.right.and.arrow.up.left", "arrow.up.left.and.arrow.down.right", "list.bullet", "text.alignleft", "arrowshape.turn.up.left", "envelope"][rawValue] }
        var needsAI: Bool { [.rewrite, .expand, .reply, .subject].contains(self) } }
    private let tones = ["Clearer", "Friendlier", "More formal", "More casual", "Confident", "Apologetic", "Neutral"]

    @State private var text = ""
    @State private var output = ""
    @State private var note = ""
    @State private var action: Action = .fix
    @State private var tone = "Clearer"
    @State private var working = false
    @State private var errorText: String?
    @FocusState private var focused: Bool

    private var overQuota: Bool { !Usage.hasRoom("ai", limit: Limits.freeAiPerDay) }
    private var stats: TextTools.Stats { TextTools.stats(text) }

    var body: some View {
        ToolPage(title: "Text Studio", subtitle: "Fix, rewrite, shorten, bullet, summarize, or draft a reply — then send it on.") {
            VStack(spacing: HandySpacing.s8) {
                TextEditor(text: $text).focused($focused)
                    .frame(minHeight: 150).padding(HandySpacing.s8).scrollContentBackground(.hidden)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(focused ? HandyColor.accent : HandyColor.border, lineWidth: 1))
                    .overlay(alignment: .topLeading) { if text.isEmpty { Text("Type or paste your text, email, or the message you're replying to…").foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false) } }
                HStack {
                    Button("Paste") { if let s = UIPasteboard.general.string { text = s } }.compactButton()
                    if !text.isEmpty { Button("Clear") { text = ""; output = "" }.textButton() }
                    Spacer()
                    if !text.isEmpty { Text("\(stats.words) words · \(stats.readingSeconds)s read · grade \(String(format: "%.0f", stats.grade))").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HandySpacing.s8) { ForEach(Action.allCases, id: \.rawValue) { a in HChip(text: a.title, selected: action == a) { action = a } } }
            }
            if action == .rewrite || action == .reply {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HandySpacing.s8) { ForEach(tones, id: \.self) { t in HChip(text: t, selected: tone == t) { tone = t } } }
                }
            }
            if action.needsAI && !AIEngine.isAvailable {
                LimitNote("\(action.title) needs Apple Intelligence (iPhone 15 Pro or newer). Fix, Shorten, Bullets and Summarize work on every phone.")
            } else {
                if !store.isPremium && (action.needsAI || AIEngine.isAvailable) { QuotaChip(name: "ai", limit: Limits.freeAiPerDay).environmentObject(store) }
                if overQuota && action.needsAI { LimitReachedBanner(message: "You've used today's \(Limits.freeAiPerDay) free AI actions.") }
                Button { run() } label: { HStack { if working { ProgressView().tint(.white) }; Label(working ? "Working…" : label, systemImage: action.icon) }.frame(maxWidth: .infinity) }
                    .primaryButton().disabled(working || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (overQuota && action.needsAI))
            }
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            if !output.isEmpty {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text(output).font(HandyFont.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    if !note.isEmpty { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                    HStack(spacing: HandySpacing.s8) {
                        Button { UIPasteboard.general.string = output; ClipStore.add(output); HandyHaptics.success() } label: { Label("Copy", systemImage: "doc.on.doc").frame(maxWidth: .infinity) }.primaryButton()
                        ShareLink(item: output) { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
                    }
                    Button { text = output; output = ""; note = "" } label: { Label("Keep working on this version", systemImage: "arrow.uturn.down") }.textButton()
                }.cardStyle()
            }
        }
    }

    private var label: String {
        switch action {
        case .fix: return "Fix spelling & grammar"
        case .rewrite: return "Rewrite — \(tone.lowercased())"
        case .shorten: return "Make it shorter"
        case .expand: return "Expand it"
        case .bullets: return "Turn into bullet points"
        case .summarize: return "Summarize"
        case .reply: return "Draft a \(tone.lowercased()) reply"
        case .subject: return "Suggest subject lines"
        }
    }

    private func run() {
        focused = false; working = true; errorText = nil; output = ""; note = ""
        let input = text, a = action, t = tone
        Task { @MainActor in
            defer { working = false }
            if AIEngine.isAvailable {
                guard Usage.use("ai", limit: Limits.freeAiPerDay) else { if a.needsAI { errorText = "Out of free AI actions for today." ; return }; fallback(input, a); return }
                do { output = try await AIEngine.run(instructions: instructions(a, t), prompt: input).trimmingCharacters(in: .whitespacesAndNewlines); HandyHaptics.success(); return }
                catch { note = "On-device AI was busy — used the built-in engine instead." }
            }
            fallback(input, a)
        }
    }

    private func fallback(_ input: String, _ a: Action) {
        switch a {
        case .fix:
            let r = TextTools.fixSpelling(input); output = r.text; note = r.fixes == 0 ? "No misspellings found; tidied spacing and capitals." : "Fixed \(r.fixes) misspelling\(r.fixes == 1 ? "" : "s") and tidied spacing and capitals."
        case .shorten:
            let n = max(1, TextTools.sentences(input).count / 2); output = TextTools.summarize(input, sentences: n).joined(separator: " "); note = "Kept the \(n) most informative sentence\(n == 1 ? "" : "s")."
        case .bullets: output = TextTools.bullets(input)
        case .summarize: output = TextTools.summarize(input, sentences: 3).map { "• " + $0 }.joined(separator: "\n"); note = "Key sentences, picked by what the text talks about most."
        default: errorText = "\(a.title) needs Apple Intelligence on this phone."
        }
        if !output.isEmpty { HandyHaptics.success() }
    }

    private func instructions(_ a: Action, _ t: String) -> String {
        switch a {
        case .fix: return "Correct spelling, grammar and punctuation. Keep the author's words, tone and formatting. Return only the corrected text."
        case .rewrite: return "Rewrite the text to be \(t.lowercased()) while keeping its meaning and the author's voice. Return only the rewritten text."
        case .shorten: return "Cut the text to about half its length without losing any fact, name, number or request. Return only the shorter text."
        case .expand: return "Expand the text into a fuller, well-structured version with natural transitions — no filler, no invented facts. Return only the text."
        case .bullets: return "Turn the text into concise bullet points, one idea each, in the original order. Return only the bullets."
        case .summarize: return "Summarize in 3–5 tight bullet points: key facts, decisions, dates and action items. No preamble."
        case .reply: return "The user pastes a message they received. Draft a \(t.lowercased()) reply they could send as-is: matches the sender's formality, answers every question asked, under 120 words unless the message demands more. Return only the reply."
        case .subject: return "Suggest 5 subject lines for this email, each under 8 words, from most to least formal. One per line, no numbering."
        }
    }
}
