import SwiftUI
import PhotosUI
import VisionKit
import UIKit

/// Safety — spot scams and bad links. Message / Link / Phone / QR code run the on-device ScamAnalyzer
/// and show one result card (score ring, verdict, findings, what to do, Report + Block). Vault embeds
/// the Face ID locker. History keeps the last 20 checks. Nothing is uploaded.
struct SafetyHub: View {
    @EnvironmentObject var store: StoreManager
    @State private var tab = 0
    @State private var message = SafetySamples.scam
    @State private var link = "http://chase-secure-verify.xyz/login"
    @State private var phone = "+1 900 555 0123"
    @State private var report: ScamAnalyzer.Report?
    @State private var checked = ""              // the text the current result is about
    @State private var checkedLabel: String?     // nil = message, "link", "phone", "qr"
    @State private var history: [SafetyHistory.Item] = SafetyHistory.load()
    @State private var photoItem: PhotosPickerItem?
    @State private var qrPhotoItem: PhotosPickerItem?
    @State private var showScanner = false
    @State private var qrPayload: String?
    @State private var busy = false
    @State private var errorText: String?
    @State private var blockNote: String?

    private let tabs = ["Message", "Link", "Phone", "QR code", "Vault", "History"]
    private var scannerOK: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    var body: some View {
        PowerToolPage(id: "safety", tabs: tabs, selected: $tab) {
            switch tab {
            case 0: messageTab
            case 1: linkTab
            case 2: phoneTab
            case 3: qrTab
            case 4: VaultView().environment(\.embeddedInHub, true)
            default: historyTab
            }
            if tab != 4 {
                if busy { HStack { ProgressView(); Text("Reading…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }
                if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
                if let r = report { resultCard(r) }
                HubNote("Runs entirely on the phone — nothing is uploaded. A clean result isn't a guarantee: when money or codes are involved, verify through an official channel.")
            }
        }
        .onAppear { if Launch.sample, report == nil { check(message, label: nil) } }
        .onChange(of: photoItem) { _, item in readScreenshot(item) }
        .onChange(of: qrPhotoItem) { _, item in readQRImage(item) }
        .fullScreenCover(isPresented: $showScanner) { SafetyScanSheet { code in showScanner = false; handleQR(code) } }
    }

    // MARK: Message

    @ViewBuilder private var messageTab: some View {
        TextEditor(text: $message).frame(minHeight: 120).padding(HandySpacing.s8).scrollContentBackground(.hidden)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            .overlay(alignment: .topLeading) { if message.isEmpty { Text("Paste a suspicious text, email, link or number…").foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false) } }
        FlowLayout(spacing: 8) {
            ForEach(Array(SafetySamples.chips.enumerated()), id: \.offset) { _, c in
                HubChip(c.0, selected: checkedLabel == nil && checked == c.1) { message = c.1; check(c.1, label: nil) }
            }
        }
        HandyFlow(spacing: HandySpacing.s8) {
            Button("Paste") { if let s = UIPasteboard.general.string { message = s; check(s, label: nil) } }.compactButton()
            PhotosPicker(selection: $photoItem, matching: .images) { Label("Screenshot", systemImage: "photo") }.compactButton()
            if !message.isEmpty { Button("Clear") { message = ""; if checkedLabel == nil { report = nil } }.textButton() }
        }
        Button { check(message, label: nil) } label: { Label("Check it", systemImage: "shield.lefthalf.filled").frame(maxWidth: .infinity) }
            .primaryButton().disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: Link

    @ViewBuilder private var linkTab: some View {
        field("Paste a link…", $link, keyboard: .URL)
        Button { check(link, label: "link") } label: { Label("Check link", systemImage: "link").frame(maxWidth: .infinity) }
            .primaryButton().disabled(link.trimmingCharacters(in: .whitespaces).isEmpty)
        HubNote("Checks the address itself — look-alike brands, risky endings, shorteners, raw IPs, hyphen-heavy names. Nothing is opened.")
    }

    // MARK: Phone

    @ViewBuilder private var phoneTab: some View {
        field("Phone number…", $phone, keyboard: .phonePad)
        Button { check(phone, label: "phone") } label: { Label("Check number", systemImage: "phone").frame(maxWidth: .infinity) }
            .primaryButton().disabled(phone.filter(\.isNumber).isEmpty)
        HubNote("Spots premium-rate, one-ring and spoof-pattern numbers. iOS can't look up a number's spam reputation inside an app — Settings › Phone › Silence Unknown Callers covers the rest.")
    }

    // MARK: QR

    @ViewBuilder private var qrTab: some View {
        HubPreviewBox(minHeight: 150) {
            VStack(spacing: HandySpacing.s8) {
                Image(systemName: "qrcode.viewfinder").font(.system(size: 34)).foregroundStyle(HandyColor.accent)
                Text(qrPayload ?? "Scan a QR code before you open it — the link inside is checked first.").font(HandyFont.body).multilineTextAlignment(.center).textSelection(.enabled)
            }.padding(HandySpacing.s16)
        }
        if scannerOK {
            HStack(spacing: HandySpacing.s8) {
                Button { showScanner = true } label: { Label("Scan QR", systemImage: "camera").frame(maxWidth: .infinity) }.primaryButton()
                PhotosPicker(selection: $qrPhotoItem, matching: .images) { Label("From image", systemImage: "photo").frame(maxWidth: .infinity) }.secondaryButton()
            }
        } else {
            PhotosPicker(selection: $qrPhotoItem, matching: .images) { Label("From image", systemImage: "photo").frame(maxWidth: .infinity) }.primaryButton()
            HubPill("Camera scanning runs on a real iPhone — an image works here", tone: .native)
        }
        if let p = qrPayload, !isURL(p) { QRResultCard(raw: p) }
        if let p = qrPayload, isURL(p) {
            HStack { Button { UIPasteboard.general.string = p; HandyHaptics.success() } label: { Label("Copy link", systemImage: "doc.on.doc") }.compactButton(); Spacer() }
        }
    }

    // MARK: History

    @ViewBuilder private var historyTab: some View {
        if history.isEmpty {
            HubPreviewBox(minHeight: 120) { Text("Checks you run appear here.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary) }
        } else {
            ForEach(history) { h in
                Button { rerun(h) } label: {
                    HStack(spacing: HandySpacing.s12) {
                        Image(systemName: h.verdict == ScamAnalyzer.Verdict.likelyScam.rawValue ? "exclamationmark.triangle.fill" : h.verdict == ScamAnalyzer.Verdict.suspicious.rawValue ? "questionmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(.white).frame(width: 40, height: 40)
                            .background(verdictColor(h.verdict), in: RoundedRectangle(cornerRadius: HandyRadius.small, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(h.text).font(HandyFont.bodyStrong).lineLimit(2).foregroundStyle(HandyColor.textPrimary).multilineTextAlignment(.leading)
                            Text("\(h.verdict) · \(h.score)/100" + (h.label.map { " · \($0)" } ?? "")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.counterclockwise").foregroundStyle(HandyColor.textSecondary)
                    }
                    .padding(HandySpacing.s12).frame(maxWidth: .infinity)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                }.buttonStyle(.plain)
            }
            HStack { Button { history = []; SafetyHistory.clear() } label: { Label("Clear history", systemImage: "trash") }.textButton(); Spacer() }
        }
    }

    // MARK: result card

    private func resultCard(_ r: ScamAnalyzer.Report) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s12) {
                ZStack {
                    Circle().stroke(HandyColor.border, lineWidth: 8).frame(width: 72, height: 72)
                    Circle().trim(from: 0, to: max(0.02, CGFloat(r.score) / 100)).stroke(color(r.verdict), style: StrokeStyle(lineWidth: 8, lineCap: .round)).frame(width: 72, height: 72).rotationEffect(.degrees(-90))
                    Text("\(r.score)").font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.verdict.rawValue).font(.system(size: 22, weight: .bold)).foregroundStyle(color(r.verdict))
                    Text((r.findings.isEmpty ? "No warning signs" : "\(r.findings.count) warning sign\(r.findings.count == 1 ? "" : "s")") + (checkedLabel.map { " · \($0)" } ?? "")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                Spacer()
            }
            ForEach(r.findings) { f in
                HStack(alignment: .top, spacing: HandySpacing.s8) {
                    Image(systemName: f.weight >= 3 ? "exclamationmark.triangle.fill" : "exclamationmark.circle").foregroundStyle(f.weight >= 3 ? HandyColor.danger : HandyColor.amber).frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) { Text(f.title).font(HandyFont.bodyStrong); Text(f.detail).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                }
            }
            if !r.links.isEmpty {
                ForEach(r.links) { l in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.host).font(.system(.body, design: .monospaced)).foregroundStyle(l.issues.isEmpty ? HandyColor.textPrimary : HandyColor.danger)
                        Text(l.issues.isEmpty ? "No obvious tricks in the address." : l.issues.joined(separator: " ")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                }
            }
            Divider()
            Text("What to do").font(HandyFont.bodyStrong)
            ForEach(adviceFor(r), id: \.self) { a in HStack(alignment: .top, spacing: 6) { Text("•"); Text(a) }.font(HandyFont.body) }
            HStack(spacing: HandySpacing.s8) {
                ShareLink(item: shareText(r)) { Label("Report", systemImage: "flag").frame(maxWidth: .infinity) }.secondaryButton()
                Button { block() } label: { Label("Block", systemImage: "nosign").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if let blockNote { Text(blockNote).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
            if checkedLabel != "phone", checkedLabel != "link", let sms = URL(string: "sms:7726&body=" + (checked.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")) {
                Link(destination: sms) { Label("Forward to your carrier (7726)", systemImage: "paperplane") }.textButton()
            }
        }.cardStyle()
    }

    private func adviceFor(_ r: ScamAnalyzer.Report) -> [String] {
        if checkedLabel == "link" { return r.verdict == .lowRisk ? ["Nothing obviously wrong with the address. Still, only open it if you know who sent it."] : ["Don't open it. If it claims to be a company, type their address yourself or use their app."] }
        if checkedLabel == "phone" { return r.verdict == .lowRisk ? ["Nothing obviously wrong with the number. If a call from it asks for money or codes, hang up and ring the organisation back on a number you trust."] : ["Don't call or text back. If it keeps calling, block it below."] }
        if r.verdict != .lowRisk, r.findings.isEmpty { return ["Reply nothing. Do not tap links or send money or codes. Verify through an official channel."] }
        return ScamAnalyzer.advice(for: r)
    }

    // MARK: checks

    private func check(_ raw: String, label: String?) {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        errorText = nil; blockNote = nil
        let r: ScamAnalyzer.Report
        if label == "phone" { r = ScamAnalyzer.phoneReport(t) }
        else {
            r = ScamAnalyzer.analyze(t)
            if label == "link", r.links.isEmpty { errorText = "Couldn't read that as a link — paste the full address, e.g. https://example.com/page."; return }
        }
        report = r; checked = t; checkedLabel = label
        history = SafetyHistory.adding(SafetyHistory.Item(text: t, label: label, verdict: r.verdict.rawValue, score: r.score, date: Date()), to: history)
        HandyHaptics.light()
    }

    private func rerun(_ h: SafetyHistory.Item) {
        switch h.label ?? "" {
        case "link": link = h.text; tab = 1; check(h.text, label: "link")
        case "phone": phone = h.text; tab = 2; check(h.text, label: "phone")
        case "qr": qrPayload = h.text; tab = 3; check(h.text, label: "qr")
        default: message = h.text; tab = 0; check(h.text, label: nil)
        }
    }

    private func handleQR(_ code: String) {
        qrPayload = code; errorText = nil
        if isURL(code) { check(code, label: "qr") } else { report = nil }
        HandyHaptics.success()
    }

    private func isURL(_ s: String) -> Bool {
        if case .url = QRPayload.parse(s) { return true }
        return false
    }

    private func readScreenshot(_ item: PhotosPickerItem?) {
        guard let item else { return }
        busy = true; errorText = nil
        Task {
            guard let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) else { await MainActor.run { busy = false; photoItem = nil }; return }
            let s = await AIEngine.recognizeText(img)
            await MainActor.run {
                busy = false; photoItem = nil
                if s.isEmpty { errorText = "Couldn't read text in that screenshot." } else { message = s; tab = 0; check(s, label: nil) }
            }
        }
    }

    private func readQRImage(_ item: PhotosPickerItem?) {
        guard let item else { return }
        busy = true; errorText = nil
        Task {
            guard let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) else { await MainActor.run { busy = false; qrPhotoItem = nil }; return }
            let found = CaptureView.barcode(in: img)
            await MainActor.run {
                busy = false; qrPhotoItem = nil
                if let found { handleQR(found) } else { errorText = "No QR code found in that image — try a clearer shot." }
            }
        }
    }

    /// iOS can't block a number from inside an app. Copy it and point at the exact switch.
    private func block() {
        let numbers = checkedLabel == "phone" ? [checked] : ScamAnalyzer.phoneNumbers(in: checked)
        if let n = numbers.first {
            UIPasteboard.general.string = n
            blockNote = "Copied \(n). Settings › Phone › Blocked Contacts › Add New… and pick it — or in Messages tap the sender › info › Block Caller."
        } else if checkedLabel == "link" {
            blockNote = "Links can't be blocked on iOS — just don't open it. In Messages tap the sender › info › Block Caller."
        } else {
            blockNote = "No number in this message. In Messages tap the sender's name › info › Block Caller; in Mail tap the sender › Block Contact."
        }
        HandyHaptics.success()
    }

    // MARK: bits

    private func field(_ ph: String, _ b: Binding<String>, keyboard: UIKeyboardType) -> some View {
        TextField(ph, text: b).keyboardType(keyboard).autocorrectionDisabled().textInputAutocapitalization(.never)
            .padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }
    private func color(_ v: ScamAnalyzer.Verdict) -> Color { v == .likelyScam ? HandyColor.danger : v == .suspicious ? HandyColor.amber : HandyColor.success }
    private func verdictColor(_ raw: String) -> Color { color(ScamAnalyzer.Verdict(rawValue: raw) ?? .lowRisk) }
    private func shareText(_ r: ScamAnalyzer.Report) -> String {
        "Tenzy Safety check: \(r.verdict.rawValue) (\(r.score)/100)\n" + r.findings.map { "• \($0.title) — \($0.detail)" }.joined(separator: "\n") + "\n\nChecked: \(checked.prefix(300))\n\nRun on the phone with Tenzy — nothing was uploaded."
    }
}

// MARK: - helpers (file-private so other hubs can name theirs freely)

private struct SafetyScanSheet: View {
    let onResult: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack(alignment: .topTrailing) {
            SafetyLiveScanner(onResult: onResult).ignoresSafeArea()
            Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.largeTitle).foregroundStyle(.white).padding() }
                .accessibilityLabel("Close scanner")
        }
    }
}

private struct SafetyLiveScanner: UIViewControllerRepresentable {
    let onResult: (String) -> Void
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let v = DataScannerViewController(recognizedDataTypes: [.barcode()], qualityLevel: .balanced, isHighlightingEnabled: true)
        v.delegate = context.coordinator
        try? v.startScanning()
        return v
    }
    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(onResult: onResult) }
    final class Coord: NSObject, DataScannerViewControllerDelegate {
        let onResult: (String) -> Void
        init(onResult: @escaping (String) -> Void) { self.onResult = onResult }
        func dataScanner(_ s: DataScannerViewController, didAdd added: [RecognizedItem], allItems: [RecognizedItem]) {
            if case .barcode(let b) = added.first, let v = b.payloadStringValue { s.stopScanning(); onResult(v) }
        }
    }
}
