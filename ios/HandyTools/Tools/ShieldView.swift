import SwiftUI
import PhotosUI

/// Message Shield — paste a text, email or DM (or a screenshot of one) and see, line by line, why it
/// is or isn't a scam: the pressure tactics, the payment rail, the look-alike link. Teaches the
/// pattern so the next one gets caught without the app. Nothing is uploaded.
struct ShieldView: View {
    @State private var text = ""
    @State private var report: ScamAnalyzer.Report?
    @State private var photoItem: PhotosPickerItem?
    @State private var busy = false
    @State private var aiOpinion = ""
    @State private var aiBusy = false
    @State private var errorText: String?

    var body: some View {
        ToolPage(title: "Message Shield", subtitle: "Paste a message or drop in a screenshot. See exactly why it's a scam — or why it's fine.") {
            HowTo("shield", [
                "Paste a suspicious text, email or DM.",
                "It flags scam signs — pressure, odd links, money asks — and explains them.",
                "When in doubt, do not tap links; verify with the company directly.",
            ])
            VStack(spacing: HandySpacing.s8) {
                TextEditor(text: $text)
                    .frame(minHeight: 140).padding(HandySpacing.s8).scrollContentBackground(.hidden)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .overlay(alignment: .topLeading) { if text.isEmpty { Text("Paste the text, email or DM here…").foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false) } }
                HStack(spacing: HandySpacing.s8) {
                    Button("Paste") { if let s = UIPasteboard.general.string { text = s; analyze() } }.compactButton()
                    PhotosPicker(selection: $photoItem, matching: .images) { Label("Screenshot", systemImage: "photo") }.compactButton()
                    if !text.isEmpty { Button("Clear") { text = ""; report = nil; aiOpinion = "" }.textButton() }
                    Spacer()
                }
            }
            Button { analyze() } label: { HStack { if busy { ProgressView().tint(.white) }; Label("Check it", systemImage: "shield.lefthalf.filled") }.frame(maxWidth: .infinity) }
                .primaryButton().disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || busy)
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let r = report { reportView(r) }
            Text("Runs entirely on your phone; the message is never sent anywhere. A clean result isn't a guarantee — when money or codes are involved, verify through an official channel.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .onAppear { if Launch.sample, text.isEmpty { text = "URGENT: Your account will be suspended within 24 hours. Verify your identity at http://paypal.secure-login.top/verify and pay the fee in Apple gift cards. Do not tell anyone."; analyze() } }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            busy = true
            Task {
                if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    let s = await AIEngine.recognizeText(img)
                    await MainActor.run { text = s; busy = false; if s.isEmpty { errorText = "Couldn't read text in that screenshot." } else { analyze() } }
                } else { await MainActor.run { busy = false } }
            }
        }
    }

    private func analyze() {
        errorText = nil; aiOpinion = ""
        report = ScamAnalyzer.analyze(text)
        HandyHaptics.light()
    }

    @ViewBuilder private func reportView(_ r: ScamAnalyzer.Report) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s12) {
                ZStack {
                    Circle().stroke(HandyColor.border, lineWidth: 8).frame(width: 72, height: 72)
                    Circle().trim(from: 0, to: CGFloat(r.score) / 100).stroke(color(r.verdict), style: StrokeStyle(lineWidth: 8, lineCap: .round)).frame(width: 72, height: 72).rotationEffect(.degrees(-90))
                    Text("\(r.score)").font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.verdict.rawValue).font(.system(size: 22, weight: .bold)).foregroundStyle(color(r.verdict))
                    Text(r.findings.isEmpty ? "No scam patterns found" : "\(r.findings.count) warning sign\(r.findings.count == 1 ? "" : "s")").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                Spacer()
            }
            ForEach(r.findings) { f in
                HStack(alignment: .top, spacing: HandySpacing.s8) {
                    Image(systemName: f.weight >= 3 ? "exclamationmark.triangle.fill" : "exclamationmark.circle").foregroundStyle(f.weight >= 3 ? HandyColor.danger : HandyColor.accent).frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) { Text(f.title).font(HandyFont.bodyStrong); Text(f.detail).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                }
            }
            if !r.links.isEmpty {
                Text("Links").font(HandyFont.bodyStrong)
                ForEach(r.links) { l in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.host).font(.system(.body, design: .monospaced)).foregroundStyle(l.issues.isEmpty ? HandyColor.textPrimary : HandyColor.danger)
                        Text(l.issues.isEmpty ? "No obvious tricks in the address." : l.issues.joined(separator: " ")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                }
            }
            Divider()
            Text("What to do").font(HandyFont.bodyStrong)
            ForEach(ScamAnalyzer.advice(for: r), id: \.self) { a in HStack(alignment: .top, spacing: 6) { Text("•"); Text(a) }.font(HandyFont.body) }
            if AIEngine.isAvailable {
                if aiOpinion.isEmpty {
                    Button { secondOpinion() } label: { HStack { if aiBusy { ProgressView() }; Label("Second opinion (on-device AI)", systemImage: "sparkles") } }.compactButton().disabled(aiBusy)
                } else {
                    Text(aiOpinion).font(HandyFont.body).padding(HandySpacing.s12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                }
            }
            ShareLink(item: shareText(r)) { Label("Share this check with someone", systemImage: "square.and.arrow.up") }.textButton()
        }.cardStyle()
    }

    private func color(_ v: ScamAnalyzer.Verdict) -> Color { v == .likelyScam ? HandyColor.danger : v == .suspicious ? HandyColor.accent : HandyColor.success }

    private func shareText(_ r: ScamAnalyzer.Report) -> String {
        "Message Shield: \(r.verdict.rawValue) (\(r.score)/100)\n" + r.findings.map { "• \($0.title)" }.joined(separator: "\n") + "\n\nChecked with Tenzy."
    }

    private func secondOpinion() {
        guard Usage.use("ai", limit: Limits.freeAiPerDay) else { errorText = "You've used today's \(Limits.freeAiPerDay) free AI actions."; return }
        aiBusy = true
        Task { @MainActor in
            defer { aiBusy = false }
            do {
                aiOpinion = try await AIEngine.run(instructions: "You help an ordinary person judge whether a message is a scam. In 2–4 plain sentences: your verdict, the single strongest reason, and what they should do. Never ask them for details. Never say it is definitely safe.", prompt: text)
            } catch { errorText = error.localizedDescription }
        }
    }
}
