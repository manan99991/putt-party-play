import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

/// Lens — one place for "I have some words, help me deal with them." Bring text in from the camera,
/// a photo, a PDF, a pasted block or a web link, then act on it: listen to it read aloud, get it in
/// plain English, or boil it down to the gist. Merges what used to be Capture, Read Aloud and the
/// Plain-English Explainer into a single tool, so there's one obvious door instead of three thin ones.
struct LensView: View {
    @EnvironmentObject var store: StoreManager
    @StateObject private var reader = Reader()

    private enum Action: String, CaseIterable { case listen, simplify, gist
        var title: String { ["Listen", "Plain English", "Gist"][index] }
        var icon: String { ["speaker.wave.2", "text.book.closed", "list.bullet.rectangle"][index] }
        private var index: Int { Action.allCases.firstIndex(of: self)! }
    }

    @State private var text = ""
    @State private var action: Action = .listen
    @State private var photoItem: PhotosPickerItem?
    @State private var showFiles = false
    @State private var urlText = ""
    @State private var busy = false
    @State private var working = false
    @State private var errorText: String?
    // simplify output
    @State private var explanation = ""
    @State private var terms: [Glossary.Term] = []
    @State private var flags: [(String, String)] = []
    // gist output
    @State private var gist = ""
    @State private var exported: URL?
    @AppStorage("lens.rate") private var rate = Double(AVSpeechUtteranceDefaultSpeechRate)

    private var overQuota: Bool { !Usage.hasRoom("ai", limit: Limits.freeAiPerDay) }
    private var hasText: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 }

    var embedded = false
    var body: some View {
        content
        .onAppear { reader.rate = Float(rate); if Launch.sample, text.isEmpty { text = "Tenant shall indemnify and hold harmless the Landlord. This Agreement shall automatically renew for successive twelve-month terms unless either party gives 60 days' notice. All disputes are subject to binding arbitration. Late fee of $75 applies after a 5-day grace period." } }
        .onDisappear { reader.pause() }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf]) { res in
            if case .success(let url) = res { busy = true; Task.detached { let t = ReadSource.fromPDF(url); await MainActor.run { busy = false; setText(String(t.prefix(12_000))) } } }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            busy = true
            Task { if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { let t = await AIEngine.recognizeText(img); await MainActor.run { busy = false; setText(t) } } else { await MainActor.run { busy = false } } }
        }
    }
    @ViewBuilder private var content: some View {
        if embedded { VStack(alignment: .leading, spacing: HandySpacing.s12) { panel } }
        else { ToolPage(title: "Lens", subtitle: "Grab text from the camera, a photo, a PDF or a link — then listen to it, simplify it, or get the gist.") { panel } }
    }
    @ViewBuilder private var panel: some View {
            HowTo("lens", [
                "Bring text in: paste it, snap a photo, open a PDF, or drop in a link.",
                "Pick what to do — Listen reads it aloud, Plain English rewrites it simply, Gist boils it down.",
                "Copy or share the result.",
            ])

            inputCard
            if busy { HStack { ProgressView(); Text("Reading the text…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }

            if hasText {
                HandyFlow(spacing: HandySpacing.s8) {
                    ForEach(Action.allCases, id: \.rawValue) { a in
                        HChip(text: a.title, selected: action == a) { action = a }
                    }
                }
                switch action {
                case .listen:   listenPanel
                case .simplify: simplifyPanel
                case .gist:     gistPanel
                }
            }
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
    }

    // MARK: input

    private var inputCard: some View {
        VStack(spacing: HandySpacing.s8) {
            TextEditor(text: $text).frame(minHeight: 130).padding(HandySpacing.s8).scrollContentBackground(.hidden)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                .overlay(alignment: .topLeading) { if text.isEmpty { Text("Paste text, or bring it in below…").foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false) } }
            HandyFlow(spacing: HandySpacing.s8) {
                Button("Paste") { if let s = UIPasteboard.general.string { setText(s) } }.compactButton()
                PhotosPicker(selection: $photoItem, matching: .images) { Label("Photo", systemImage: "camera.viewfinder") }.compactButton()
                Button { showFiles = true } label: { Label("PDF", systemImage: "doc.fill") }.compactButton()
                if hasText { Button("Clear") { clearAll() }.textButton() }
            }
            HStack(spacing: HandySpacing.s8) {
                TextField("https://… article link", text: $urlText).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .onSubmit { loadWeb() }
                Button { loadWeb() } label: { Image(systemName: "arrow.down.doc").frame(width: 36, height: 36) }.compactButton().disabled(URL(string: urlText)?.host == nil)
            }
        }
    }

    // MARK: Listen

    private var listenPanel: some View {
        VStack(spacing: HandySpacing.s12) {
            if reader.sentences.isEmpty {
                Button { reader.load(text); reader.play() } label: { Label("Read it aloud", systemImage: "play.fill").frame(maxWidth: .infinity) }.primaryButton()
            } else {
                ProgressView(value: reader.progress).tint(HandyColor.accent)
                HStack { Text("\(reader.index + 1) / \(reader.sentences.count)").font(HandyFont.caption).monospacedDigit(); Spacer(); Text("~\(reader.remainingMinutes) min left").font(HandyFont.caption) }.foregroundStyle(HandyColor.textSecondary)
                HStack(spacing: HandySpacing.s16) {
                    Button { reader.previous() } label: { Image(systemName: "backward.fill").font(.system(size: 22)) }.buttonStyle(.plain).accessibilityLabel("Previous sentence")
                    Button { reader.playing ? reader.pause() : reader.play() } label: {
                        Image(systemName: reader.playing ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 60)).foregroundStyle(HandyColor.accent)
                    }.buttonStyle(.plain).accessibilityLabel(reader.playing ? "Pause" : "Play")
                    Button { reader.next() } label: { Image(systemName: "forward.fill").font(.system(size: 22)) }.buttonStyle(.plain).accessibilityLabel("Next sentence")
                }.foregroundStyle(HandyColor.textPrimary).frame(maxWidth: .infinity)
                HStack { Image(systemName: "tortoise"); Slider(value: $rate, in: 0.3...0.7).tint(HandyColor.accent).onChange(of: rate) { _, r in reader.rate = Float(r) }; Image(systemName: "hare"); Text(String(format: "%.1f×", rate / Double(AVSpeechUtteranceDefaultSpeechRate))).font(HandyFont.caption).monospacedDigit().frame(width: 40) }.foregroundStyle(HandyColor.textSecondary)
                HStack(spacing: HandySpacing.s8) {
                    Button { export() } label: { HStack { if reader.exporting { ProgressView() }; Label("Save as audio", systemImage: "waveform.badge.plus") } }.compactButton().disabled(reader.exporting)
                    if let exported { ShareLink(item: exported) { Label("Share audio", systemImage: "square.and.arrow.up") }.compactButton() }
                    Spacer()
                    Button { reader.stop(); reader.sentences = []; exported = nil } label: { Image(systemName: "xmark").frame(width: 36, height: 36) }.compactButton()
                }
            }
            Text("Keeps reading with the screen locked. For a more natural voice, add an Enhanced voice in Settings › Accessibility › Spoken Content.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    // MARK: Plain English

    private var simplifyPanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if !store.isPremium && AIEngine.isAvailable { QuotaChip(name: "ai", limit: Limits.freeAiPerDay).environmentObject(store) }
            Button { simplify() } label: { HStack { if working { ProgressView().tint(.white) }; Label(working ? "Thinking…" : "Put it in plain English", systemImage: "text.book.closed") }.frame(maxWidth: .infinity) }
                .primaryButton().disabled(working)
            if !AIEngine.isAvailable {
                LimitNote("Full plain-English rewriting needs Apple Intelligence (iPhone 15 Pro or newer). The glossary and red-flag checks below still run on every phone.")
            }
            if !explanation.isEmpty {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    ForEach(Array(sections(explanation).enumerated()), id: \.offset) { _, sec in
                        if !sec.0.isEmpty { Text(sec.0).font(HandyFont.bodyStrong).padding(.top, 4) }
                        Text(sec.1).font(HandyFont.body).textSelection(.enabled)
                    }
                }.cardStyle()
            }
            if !flags.isEmpty {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text("Worth a second look").font(HandyFont.bodyStrong)
                    ForEach(Array(flags.enumerated()), id: \.offset) { _, f in
                        HStack(alignment: .top, spacing: HandySpacing.s8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(HandyColor.accent).frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) { Text(f.0).font(HandyFont.bodyStrong); Text(f.1).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                        }
                    }
                }.cardStyle()
            }
            if !terms.isEmpty {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text("Terms in this text").font(HandyFont.bodyStrong)
                    ForEach(terms) { t in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack { Text(t.term.capitalized).font(HandyFont.bodyStrong); Text(t.domain).font(HandyFont.micro).foregroundStyle(HandyColor.accent).padding(.horizontal, 6).padding(.vertical, 2).background(HandyColor.accentSoft, in: Capsule()) }
                            Text(t.meaning).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        }
                    }
                }.cardStyle()
            }
            if !explanation.isEmpty || !flags.isEmpty || !terms.isEmpty {
                HStack { ShareLink(item: simplifyShare) { Label("Share", systemImage: "square.and.arrow.up") }.textButton(); Spacer() }
                Text("General information to help you read the document — not legal, medical or financial advice.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        }
    }

    // MARK: Gist

    private var gistPanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Button { makeGist() } label: { Label("Boil it down", systemImage: "list.bullet.rectangle").frame(maxWidth: .infinity) }.primaryButton().disabled(working)
            if !gist.isEmpty {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text(gist).font(HandyFont.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: HandySpacing.s8) {
                        Button { UIPasteboard.general.string = gist; ClipStore.add(gist); HandyHaptics.success() } label: { Label("Copy", systemImage: "doc.on.doc").frame(maxWidth: .infinity) }.primaryButton()
                        ShareLink(item: gist) { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
                    }
                }.cardStyle()
            }
        }
    }

    // MARK: actions

    private func setText(_ t: String) {
        let clean = t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { errorText = "Couldn't find any text there."; return }
        errorText = nil; text = clean
        reader.stop(); reader.sentences = []; explanation = ""; terms = []; flags = []; gist = ""; exported = nil
    }

    private func clearAll() { text = ""; reader.stop(); reader.sentences = []; explanation = ""; terms = []; flags = []; gist = ""; exported = nil; errorText = nil }

    private func loadWeb() {
        var s = urlText.trimmingCharacters(in: .whitespaces)
        if !s.lowercased().hasPrefix("http") { s = "https://" + s }
        guard let u = URL(string: s) else { return }
        busy = true; errorText = nil
        Task { let t = await ReadSource.fromWeb(u); await MainActor.run { busy = false; if t.count < 80 { errorText = "That page didn't give up readable text. Try pasting the article instead." } else { setText(t); urlText = "" } } }
    }

    private func export() {
        if reader.sentences.isEmpty { reader.load(text) }
        Task { @MainActor in
            if let url = await reader.exportAudio() { exported = url; HandyHaptics.success() } else { errorText = "Couldn't render the audio." }
        }
    }

    private func simplify() {
        working = true; errorText = nil; explanation = ""
        let t = text
        terms = Glossary.found(in: t); flags = Glossary.redFlags(in: t)
        Task { @MainActor in
            defer { working = false }
            guard AIEngine.isAvailable else { HandyHaptics.success(); return }
            guard Usage.hasRoom("ai", limit: Limits.freeAiPerDay) else { errorText = "Out of free AI actions today — the glossary and red-flag checks still ran."; return }
            do {
                explanation = try await AIEngine.run(instructions: "You translate legal, medical, insurance and financial documents into plain English for an ordinary adult. Use exactly these four headings on their own lines: 'WHAT IT SAYS:', 'WHAT IT MEANS FOR YOU:', 'WATCH OUT FOR:', 'QUESTIONS TO ASK:'. Short sentences, concrete, no jargon without explaining it, under 220 words total. Never give a diagnosis, legal conclusion or tell them what to decide; point out what to check and who to ask.", prompt: t)
                _ = Usage.use("ai", limit: Limits.freeAiPerDay)
                HandyHaptics.success()
            } catch { errorText = error.localizedDescription }
        }
    }

    private func makeGist() {
        let t = text
        let n = max(3, TextTools.sentences(t).count / 4)
        gist = TextTools.summarize(t, sentences: n).map { "• " + $0 }.joined(separator: "\n")
        HandyHaptics.success()
    }

    private var simplifyShare: String {
        var s = explanation
        if !flags.isEmpty { s += "\n\nWorth a second look:\n" + flags.map { "• \($0.0): \($0.1)" }.joined(separator: "\n") }
        if !terms.isEmpty { s += "\n\nTerms:\n" + terms.map { "• \($0.term.capitalized): \($0.meaning)" }.joined(separator: "\n") }
        return s.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n(Information, not advice — Tenzy)"
    }

    private func sections(_ s: String) -> [(String, String)] {
        var out: [(String, String)] = [], head = "", body: [String] = []
        for line in s.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasSuffix(":"), t.count < 48, t == t.uppercased() {
                if !body.isEmpty || !head.isEmpty { out.append((head, body.joined(separator: "\n"))) }
                head = String(t.dropLast()).capitalized; body = []
            } else if !t.isEmpty { body.append(t) }
        }
        if !body.isEmpty { out.append((head, body.joined(separator: "\n"))) }
        return out
    }
}
