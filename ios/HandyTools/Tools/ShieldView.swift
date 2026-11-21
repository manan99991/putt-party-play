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
    @State private var errorText: String?
    @State private var checked = ""   // the text the shown verdict is about

    var body: some View {
        ToolPage(title: "Message Shield", subtitle: "Paste a message or drop in a screenshot. See exactly why it's a scam — or why it's fine.", working: busy) {
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
                    .overlay(alignment: .topLeading) { if text.isEmpty { Text(L("Paste the text, email or DM here…")).foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false) } }
                HStack(spacing: HandySpacing.s8) {
                    PasteTextButton { text = $0; analyze() }
                    PhotosPicker(selection: $photoItem, matching: .images) { Label(L("Screenshot"), systemImage: "photo") }.compactButton()
                    if !text.isEmpty { Button(L("Clear")) { text = ""; report = nil }.textButton() }
                    Spacer()
                }
            }
            Button { analyze() } label: { HStack { if busy { BusySpinner().tint(.white) }; Label(L("Check it"), systemImage: "shield.lefthalf.filled") }.frame(maxWidth: .infinity) }
                .primaryButton().disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || busy)
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let r = report { ScamVerdictCard(text: checked, report: r).id(checked) }
            Text(L("Runs entirely on your phone; the message is never sent anywhere. A clean result isn't a guarantee — when money or codes are involved, verify through an official channel."))
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
        errorText = nil; checked = text
        report = ScamAnalyzer.analyze(text)
        HandyHaptics.light()
    }

    /// Messages, already addressed to 7726 with the scam text, ready for you to press Send.
    static func forwardURL(_ text: String) -> URL? {
        let body = String(text.prefix(600)).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "sms:7726&body=\(body)")
    }

    static func officialReport(_ region: String) -> (name: String, url: URL)? {
        switch region {
        case "US": return ("the FTC", URL(string: "https://reportfraud.ftc.gov/")!)
        case "GB": return ("Action Fraud", URL(string: "https://www.actionfraud.police.uk/")!)
        case "CA": return ("the Canadian Anti-Fraud Centre", URL(string: "https://antifraudcentre-centreantifraude.ca/")!)
        case "AU": return ("Scamwatch", URL(string: "https://www.scamwatch.gov.au/report-a-scam")!)
        case "IN": return ("the cybercrime portal", URL(string: "https://cybercrime.gov.in/")!)
        default: return nil
        }
    }

    static func warning(_ text: String, findings: [String]) -> String {
        let quote = text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160)
        return "Heads up — this scam is going round. If you get it, don't tap the link or reply:\n\n“\(quote)\(text.count > 160 ? "…" : "")”\n\n"
            + "How to spot it: " + findings.prefix(3).joined(separator: "; ") + ".\n\nIf it says it's from your bank or a delivery company, open their app or type their website yourself."
    }
}

/// The verdict for a message: the score, each warning sign explained, every link checked, what to do, an optional
/// on-device AI second opinion, and Report / Block / Warn my family. One card for every door — Message Shield, the
/// ready-made scam checks (message, chat screenshot, QR code) and any tool built to check for scams.
struct ScamVerdictCard: View {
    let text: String
    let report: ScamAnalyzer.Report
    @State private var aiOpinion = ""
    @State private var aiVerdict: ScamAnalyzer.Verdict?
    @State private var aiBusy = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            reportView(report)
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scam-verdict")
    }

    // The headline must never contradict the AI second opinion. When the on-device AI judges the
    // message more harshly than the rules did, the gauge, label and advice follow the AI — so a real
    // scam the rules missed can't still read as a green "low-risk".
    private func sev(_ v: ScamAnalyzer.Verdict) -> Int { v == .likelyScam ? 2 : v == .suspicious ? 1 : 0 }
    private func combinedVerdict(_ r: ScamAnalyzer.Report) -> ScamAnalyzer.Verdict {
        guard let ai = aiVerdict else { return r.verdict }
        return sev(ai) > sev(r.verdict) ? ai : r.verdict
    }
    private func combinedScore(_ r: ScamAnalyzer.Report) -> Int {
        let floor = combinedVerdict(r) == .likelyScam ? 75 : combinedVerdict(r) == .suspicious ? 45 : 0
        return max(r.score, floor)
    }
    private func aiUpgraded(_ r: ScamAnalyzer.Report) -> Bool {
        if let ai = aiVerdict { return sev(ai) > sev(r.verdict) }
        return false
    }
    private func subtitleText(_ r: ScamAnalyzer.Report) -> String {
        if aiUpgraded(r) { return "On-device AI flagged this — see the note below" }
        return r.findings.isEmpty ? "No scam patterns found" : "\(r.findings.count) warning sign\(r.findings.count == 1 ? "" : "s")"
    }
    private func adviceList(_ r: ScamAnalyzer.Report) -> [String] {
        if aiUpgraded(r) {
            return ["The on-device AI thinks this is \(combinedVerdict(r).rawValue.lowercased()). Treat it with caution — don't reply, don't tap any links, and never send money or codes. Verify through an official channel first.",
                    "Reply nothing. Block and report the sender."]
        }
        return ScamAnalyzer.advice(for: r)
    }
    /// Read the AI's own verdict out of its free-text answer, so we can compare it with the rules.
    private func parseAIVerdict(_ s: String) -> ScamAnalyzer.Verdict {
        let l = s.lowercased()
        let negated = l.contains("not a scam") || l.contains("isn't a scam") || l.contains("is not a scam")
            || l.contains("not suspicious") || l.contains("looks ordinary") || l.contains("appears ordinary") || l.contains("seems ordinary")
        if !negated && (l.contains("likely scam") || l.contains("likely a scam")) { return .likelyScam }
        if !negated && l.contains("suspicious") { return .suspicious }
        return .lowRisk
    }

    @ViewBuilder private func reportView(_ r: ScamAnalyzer.Report) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s12) {
                ZStack {
                    Circle().stroke(HandyColor.border, lineWidth: 8).frame(width: 72, height: 72)
                    Circle().trim(from: 0, to: CGFloat(combinedScore(r)) / 100).stroke(color(combinedVerdict(r)), style: StrokeStyle(lineWidth: 8, lineCap: .round)).frame(width: 72, height: 72).rotationEffect(.degrees(-90))
                    Text("\(combinedScore(r))").font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(combinedVerdict(r).rawValue).font(.system(size: 22, weight: .bold)).foregroundStyle(color(combinedVerdict(r)))
                    Text(subtitleText(r)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
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
                Text(L("Links")).font(HandyFont.bodyStrong)
                ForEach(r.links) { l in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.host).font(.system(.body, design: .monospaced)).foregroundStyle(l.issues.isEmpty ? HandyColor.textPrimary : HandyColor.danger)
                        Text(l.issues.isEmpty ? "No obvious tricks in the address." : l.issues.joined(separator: " ")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                }
            }
            Divider()
            Text(L("What to do")).font(HandyFont.bodyStrong)
            ForEach(adviceList(r), id: \.self) { a in HStack(alignment: .top, spacing: 6) { Text(L("•")); Text(a) }.font(HandyFont.body) }
            if AIEngine.isAvailable {
                if aiOpinion.isEmpty {
                    Button { secondOpinion() } label: { HStack { if aiBusy { BusySpinner() }; Label(L("Second opinion (on-device AI)"), systemImage: "sparkles") } }.compactButton().disabled(aiBusy)
                } else {
                    Text(aiOpinion).font(HandyFont.body).padding(HandySpacing.s12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                }
            }
            ShareLink(item: shareText(r)) { Label(L("Share this check with someone"), systemImage: "square.and.arrow.up") }.textButton()
        }.cardStyle()
        if combinedVerdict(r) != .lowRisk { reportCard(r) }
    }

    /// Report it where it counts, block it, and warn the people it'll go to next. Nothing is sent without you.
    @ViewBuilder private func reportCard(_ r: ScamAnalyzer.Report) -> some View {
        let region = Locale.current.region?.identifier ?? ""
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Report and block it"), systemImage: "hand.raised.fill").font(HandyFont.bodyStrong)
            if ["US", "GB", "CA", "IE"].contains(region), let u = ShieldView.forwardURL(text) {
                Button { UIApplication.shared.open(u) } label: {
                    Label(L("Forward it to 7726 (free) — your carrier blocks the sender"), systemImage: "arrowshape.turn.up.right.fill").frame(maxWidth: .infinity)
                }.secondaryButton().accessibilityIdentifier("shield-7726")
            }
            if let site = ShieldView.officialReport(region) {
                Link(destination: site.url) { Label("\(L("Report it to")) \(site.name)", systemImage: "building.columns").frame(maxWidth: .infinity) }.secondaryButton()
            }
            Text(L("To block it: open the message, tap the sender's name at the top, then Block Caller. Then delete the message."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            ShareLink(item: ShieldView.warning(text, findings: r.findings.map(\.title))) {
                Label(L("Warn my family — they may get the same one"), systemImage: "person.2.wave.2.fill").frame(maxWidth: .infinity)
            }.primaryButton()
        }.cardStyle(padding: HandySpacing.s12)
    }

    private func color(_ v: ScamAnalyzer.Verdict) -> Color { v == .likelyScam ? HandyColor.danger : v == .suspicious ? HandyColor.accent : HandyColor.success }

    private func shareText(_ r: ScamAnalyzer.Report) -> String {
        "Message Shield: \(combinedVerdict(r).rawValue) (\(combinedScore(r))/100)\n" + r.findings.map { "• \($0.title)" }.joined(separator: "\n") + "\n\nChecked with Tenzy."
    }

    private func secondOpinion() {
        guard Usage.hasRoom("ai", limit: Limits.freeAiPerDay) else { errorText = "You've used today's \(Limits.freeAiPerDay) free AI actions."; return }
        aiBusy = true
        Task { @MainActor in
            defer { aiBusy = false }
            do {
                aiOpinion = try await AIEngine.run(instructions: "You help an ordinary person judge whether a text message or email is a scam. Weigh it fairly: most everyday messages — appointment reminders, delivery updates, a one-time code that is simply sent to the person, notes from someone they know — are NOT scams, and you should say so plainly when that is the case. Only call something suspicious or a scam when it actually pressures the person, demands money, asks them to hand over a code, password or personal details, pushes a link to 'verify' or 'confirm' an account, or dangles an unrealistic job or payout and tells them to apply by texting a keyword to a number. In 2–4 plain sentences give: your verdict (ordinary / suspicious / likely scam), the single strongest reason, and what to do. Never ask the person for more details. Never promise it is definitely safe.", prompt: text)
                aiVerdict = parseAIVerdict(aiOpinion)
                _ = Usage.use("ai", limit: Limits.freeAiPerDay)
            } catch { errorText = error.localizedDescription }
        }
    }
}
