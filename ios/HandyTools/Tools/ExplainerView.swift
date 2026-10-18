import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Plain-English Explainer — paste or photograph the lease, the contract, the insurance letter, the
/// lab report. Get what it says, what it means for you, the clauses to watch, and the questions to
/// ask — in plain words, on your phone. Information, not advice.
struct ExplainerView: View {
    @EnvironmentObject var store: StoreManager
    @State private var text = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var showFiles = false
    @State private var busy = false
    @State private var working = false
    @State private var errorText: String?
    @State private var explanation = ""
    @State private var terms: [Glossary.Term] = []
    @State private var flags: [(String, String)] = []
    @State private var ran = false
    private var overQuota: Bool { !Usage.hasRoom("ai", limit: Limits.freeAiPerDay) }

    var body: some View {
        ToolPage(title: "Plain-English Explainer", subtitle: "Leases, contracts, insurance letters, lab reports — decoded into words you'd use.") {
            VStack(spacing: HandySpacing.s8) {
                TextEditor(text: $text).frame(minHeight: 140).padding(HandySpacing.s8).scrollContentBackground(.hidden)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .overlay(alignment: .topLeading) { if text.isEmpty { Text("Paste the confusing part here…").foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false) } }
                HStack(spacing: HandySpacing.s8) {
                    Button("Paste") { if let s = UIPasteboard.general.string { text = s } }.compactButton()
                    PhotosPicker(selection: $photoItem, matching: .images) { Label("Photo", systemImage: "camera.viewfinder") }.compactButton()
                    Button { showFiles = true } label: { Label("PDF", systemImage: "doc.fill") }.compactButton()
                    if !text.isEmpty { Button("Clear") { text = ""; explanation = ""; terms = []; flags = []; ran = false }.textButton() }
                    Spacer()
                }
                if busy { HStack { ProgressView(); Text("Reading…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }
            }
            if !store.isPremium && AIEngine.isAvailable { QuotaChip(name: "ai", limit: Limits.freeAiPerDay).environmentObject(store) }
            Button { explain() } label: { HStack { if working { ProgressView().tint(.white) }; Label(working ? "Thinking…" : "Explain it", systemImage: "text.book.closed") }.frame(maxWidth: .infinity) }
                .primaryButton().disabled(working || text.trimmingCharacters(in: .whitespaces).count < 20)
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            if ran {
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
                        Text("Clauses to look at twice").font(HandyFont.bodyStrong)
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
                if explanation.isEmpty && terms.isEmpty && flags.isEmpty {
                    Text("No jargon from the built-in glossary and no standard red-flag clauses found. With Apple Intelligence this screen would also give a full plain-English walkthrough.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                HStack { ShareLink(item: shareText) { Label("Share this explanation", systemImage: "square.and.arrow.up") }.textButton(); Spacer() }
            }
            Text("General information to help you read the document — not legal, medical or financial advice. For decisions that matter, ask a professional and bring these notes.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .onAppear { if Launch.sample, text.isEmpty { text = "Tenant shall indemnify and hold harmless the Landlord. This Agreement shall automatically renew for successive twelve-month terms unless either party gives 60 days' notice. All disputes are subject to binding arbitration. Tenants are jointly and severally liable. Late fee of $75 applies after a 5-day grace period." } }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf]) { res in
            if case .success(let url) = res { busy = true; Task.detached { let t = ReadSource.fromPDF(url); await MainActor.run { busy = false; text = String(t.prefix(12_000)) } } }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            busy = true
            Task { if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { let t = await AIEngine.recognizeText(img); await MainActor.run { busy = false; text = t } } else { await MainActor.run { busy = false } } }
        }
    }

    private var shareText: String {
        var s = explanation
        if !flags.isEmpty { s += "\n\nClauses to look at twice:\n" + flags.map { "• \($0.0): \($0.1)" }.joined(separator: "\n") }
        if !terms.isEmpty { s += "\n\nTerms:\n" + terms.map { "• \($0.term.capitalized): \($0.meaning)" }.joined(separator: "\n") }
        return s.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n(Information, not advice — Tenzy)"
    }

    /// Split the model's "HEADING:" blocks for display.
    private func sections(_ s: String) -> [(String, String)] {
        var out: [(String, String)] = [], head = "", body: [String] = []
        for line in s.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasSuffix(":"), t.count < 48, t == t.uppercased() || ["What it says:", "What it means for you:", "Watch out for:", "Questions to ask:"].contains(t) {
                if !body.isEmpty || !head.isEmpty { out.append((head, body.joined(separator: "\n"))) }
                head = String(t.dropLast()).capitalized; body = []
            } else if !t.isEmpty { body.append(t) }
        }
        if !body.isEmpty { out.append((head, body.joined(separator: "\n"))) }
        return out
    }

    private func explain() {
        working = true; errorText = nil; explanation = ""
        let t = text
        terms = Glossary.found(in: t); flags = Glossary.redFlags(in: t); ran = true
        Task { @MainActor in
            defer { working = false }
            guard AIEngine.isAvailable else { HandyHaptics.success(); return }
            guard Usage.use("ai", limit: Limits.freeAiPerDay) else { errorText = "Out of free AI actions today — the glossary and red-flag checks still ran."; return }
            do {
                explanation = try await AIEngine.run(instructions: "You translate legal, medical, insurance and financial documents into plain English for an ordinary adult. Use exactly these four headings on their own lines: 'WHAT IT SAYS:', 'WHAT IT MEANS FOR YOU:', 'WATCH OUT FOR:', 'QUESTIONS TO ASK:'. Short sentences, concrete, no jargon without explaining it, under 220 words total. Never give a diagnosis, legal conclusion or tell them what to decide; point out what to check and who to ask.", prompt: t)
                HandyHaptics.success()
            } catch { errorText = error.localizedDescription }
        }
    }
}
