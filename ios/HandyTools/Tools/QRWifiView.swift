import SwiftUI
import PhotosUI
import VisionKit
import Vision
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers
import UIKit

/// QR & Wi‑Fi — scan anything (camera or a photo) and get the *right* action for what it is;
/// make codes for links, Wi‑Fi, contacts, phone/SMS, or a whole batch; and print a
/// "scan to join our Wi‑Fi" card for guests.
struct QRWifiView: View {
    @State private var tab = 0

    // scan
    @State private var scanned: String?
    @State private var showScanner = false
    @State private var photoItem: PhotosPickerItem?
    @State private var scanError: String?

    // make
    @State private var kind = 0        // 0 link/text, 1 wifi, 2 contact, 3 phone/sms, 4 batch
    @State private var text = ""
    @State private var ssid = ""
    @State private var password = ""
    @State private var security = 0    // 0 WPA, 1 WEP, 2 none
    @State private var hidden = false
    @State private var cName = ""
    @State private var cPhone = ""
    @State private var cEmail = ""
    @State private var cOrg = ""
    @State private var phone = ""
    @State private var sms = ""
    @State private var batch = ""
    @State private var sizeIdx = 1
    @State private var qrImage: UIImage?
    @State private var batchImages: [UIImage] = []
    @State private var cardImage: UIImage?

    var body: some View {
        ToolPage(title: "QR & Wi‑Fi", subtitle: "Scan any code and act on it, make your own, or print a Wi‑Fi card for guests.") {
            HStack(spacing: HandySpacing.s8) {
                HChip(text: "Scan", selected: tab == 0) { tab = 0 }
                HChip(text: "Make", selected: tab == 1) { tab = 1 }
                HChip(text: "Wi‑Fi card", selected: tab == 2) { tab = 2 }
            }
            switch tab {
            case 0: scanTab
            case 1: makeTab
            default: wifiCardTab
            }
        }
        .fullScreenCover(isPresented: $showScanner) { ScanSheet { scanned = $0; showScanner = false } }
        .onChange(of: photoItem) { _, item in scanPhoto(item) }
    }

    // MARK: Scan

    private var scanTab: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Button { showScanner = true } label: { Label("Open scanner", systemImage: "qrcode.viewfinder").frame(maxWidth: .infinity) }
                .primaryButton().disabled(!DataScannerViewController.isSupported)
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Scan a code in a photo or screenshot", systemImage: "photo").frame(maxWidth: .infinity)
            }.secondaryButton()
            if let scanError { Text(scanError).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let s = scanned { resultCard(for: s) }
        }
    }

    private func resultCard(for s: String) -> some View { QRResultCard(raw: s) }

    private func scanPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        scanError = nil
        Task {
            guard let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) else { return }
            let found = CaptureView.barcode(in: img)
            await MainActor.run {
                if let found { scanned = found; HandyHaptics.success() }
                else { scanError = "No QR or barcode found in that image." }
            }
        }
    }

    // MARK: Make

    private var makeTab: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HandySpacing.s8) {
                    ForEach(Array(["Link / text", "Wi‑Fi", "Contact", "Phone / SMS", "Batch"].enumerated()), id: \.offset) { i, name in
                        HChip(text: name, selected: kind == i) { kind = i; qrImage = nil; batchImages = [] }
                    }
                }
            }
            switch kind {
            case 0: field("https://… or any text", $text)
            case 1:
                field("Network name (SSID)", $ssid)
                secureField("Password", $password)
                Picker("Security", selection: $security) { Text("WPA/WPA2/3").tag(0); Text("WEP").tag(1); Text("Open").tag(2) }.pickerStyle(.segmented)
                Toggle("Hidden network", isOn: $hidden).tint(HandyColor.accent).font(HandyFont.body)
            case 2:
                field("Full name", $cName); field("Phone", $cPhone); field("Email", $cEmail); field("Company (optional)", $cOrg)
            case 3:
                field("Phone number", $phone); field("Pre‑filled message (optional)", $sms)
            default:
                TextEditor(text: $batch).frame(minHeight: 120).padding(HandySpacing.s8).scrollContentBackground(.hidden)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .overlay(alignment: .topLeading) { if batch.isEmpty { Text("One link or text per line — one QR each").foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false) } }
            }
            Picker("Size", selection: $sizeIdx) { Text("Small").tag(0); Text("Medium").tag(1); Text("Large").tag(2) }.pickerStyle(.segmented)

            Button { generate() } label: { Label(kind == 4 ? "Make all" : "Make QR code", systemImage: "qrcode").frame(maxWidth: .infinity) }.primaryButton()

            if let qrImage {
                Image(uiImage: qrImage).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 260).frame(maxWidth: .infinity)
                    .padding(HandySpacing.s24).background(.white, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
                if let png = qrImage.pngData() {
                    ShareLink(item: PNGFile(data: png), preview: SharePreview("QR code")) { Label("Save or share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
                }
            }
            if !batchImages.isEmpty {
                Text("\(batchImages.count) codes made").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HandySpacing.s8) { ForEach(Array(batchImages.enumerated()), id: \.offset) { _, im in Image(uiImage: im).interpolation(.none).resizable().frame(width: 96, height: 96).background(.white) } }
                }
                ShareLink(items: batchImages.compactMap { $0.pngData() }.map { PNGFile(data: $0) }, preview: { _ in SharePreview("QR code") }) { Label("Share all", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
            }
        }
    }

    private func field(_ ph: String, _ b: Binding<String>) -> some View {
        TextField(ph, text: b).autocorrectionDisabled().textInputAutocapitalization(.never)
            .padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }
    private func secureField(_ ph: String, _ b: Binding<String>) -> some View {
        SecureField(ph, text: b)
            .padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }

    private var scale: CGFloat { [8, 12, 18][sizeIdx] }

    private func generate() {
        qrImage = nil; batchImages = []
        switch kind {
        case 0: qrImage = QRGen.make(text, scale: scale)
        case 1: qrImage = QRGen.make(QRPayload.wifi(ssid: ssid, password: password, security: ["WPA", "WEP", "nopass"][security], hidden: hidden), scale: scale)
        case 2: qrImage = QRGen.make(QRPayload.vcard(name: cName, phone: cPhone, email: cEmail, org: cOrg), scale: scale)
        case 3: qrImage = QRGen.make(sms.isEmpty ? "tel:\(phone)" : "SMSTO:\(phone):\(sms)", scale: scale)
        default:
            batchImages = batch.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.compactMap { QRGen.make($0, scale: 10) }
        }
        if qrImage != nil || !batchImages.isEmpty { HandyHaptics.success() }
    }

    // MARK: Wi‑Fi card

    private var wifiCardTab: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Text("A printable card for the fridge or guest room — people scan it and join, no typing.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            field("Network name (SSID)", $ssid)
            secureField("Password", $password)
            Picker("Security", selection: $security) { Text("WPA/WPA2/3").tag(0); Text("WEP").tag(1); Text("Open").tag(2) }.pickerStyle(.segmented)
            Button { cardImage = QRGen.wifiCard(ssid: ssid, password: password, security: ["WPA", "WEP", "nopass"][security]) ; if cardImage != nil { HandyHaptics.success() } } label: {
                Label("Make the card", systemImage: "wifi").frame(maxWidth: .infinity)
            }.primaryButton().disabled(ssid.isEmpty)
            if let cardImage, let png = cardImage.pngData() {
                Image(uiImage: cardImage).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                ShareLink(item: PNGFile(data: png), preview: SharePreview("Wi‑Fi card")) { Label("Save, share or print", systemImage: "printer").frame(maxWidth: .infinity) }.secondaryButton()
            }
        }
    }
}

// MARK: - Payload parsing / generation


/// What a scanned code *is* and what you can do with it — shared by QR & Wi‑Fi and Capture.
struct QRResultCard: View {
    let raw: String
    @State private var revealPassword = false

    var body: some View {
        let parsed = QRPayload.parse(raw)
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Label(parsed.title, systemImage: parsed.icon).font(HandyFont.bodyStrong)
            switch parsed {
            case .wifi(let n, let p, let sec):
                row("Network", n)
                row("Security", sec)
                HStack {
                    Text("Password").foregroundStyle(HandyColor.textSecondary).frame(width: 90, alignment: .leading)
                    Text(revealPassword ? p : String(repeating: "•", count: max(6, p.count))).font(.system(.body, design: .monospaced))
                    Spacer()
                    Button(revealPassword ? "Hide" : "Show") { revealPassword.toggle() }.textButton().font(HandyFont.caption)
                }.font(HandyFont.body)
                Text("To join: Settings › Wi‑Fi › \(n), then paste the password.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                HStack { Button { UIPasteboard.general.string = p; HandyHaptics.success() } label: { Label("Copy password", systemImage: "doc.on.doc") }.compactButton(); Spacer() }
            case .url(let u):
                Text(u.absoluteString).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(3)
                HStack { Link(destination: u) { Label("Open", systemImage: "safari") }.compactButton(); copyButton(u.absoluteString); Spacer() }
            case .contact(let vcf, let summary):
                Text(summary).font(HandyFont.body)
                HStack {
                    ShareLink(item: VCardFile(data: Data(vcf.utf8)), preview: SharePreview("Contact")) { Label("Add to Contacts", systemImage: "person.crop.circle.badge.plus") }.compactButton()
                    Spacer()
                }
            case .phone(let number, let message):
                Text(number).font(HandyFont.body)
                HStack {
                    if let tel = URL(string: "tel:\(number.filter { !$0.isWhitespace })") { Link(destination: tel) { Label("Call", systemImage: "phone") }.compactButton() }
                    if let smsURL = URL(string: "sms:\(number.filter { !$0.isWhitespace })" + (message.isEmpty ? "" : "&body=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")) {
                        Link(destination: smsURL) { Label("Message", systemImage: "message") }.compactButton()
                    }
                    Spacer()
                }
            case .email(let addr):
                Text(addr).font(HandyFont.body)
                HStack { if let m = URL(string: "mailto:\(addr)") { Link(destination: m) { Label("Email", systemImage: "envelope") }.compactButton() }; copyButton(addr); Spacer() }
            case .location(let lat, let lon):
                Text(String(format: "%.5f, %.5f", lat, lon)).font(HandyFont.body)
                HStack { if let m = URL(string: "maps://?ll=\(lat),\(lon)") { Link(destination: m) { Label("Open in Maps", systemImage: "map") }.compactButton() }; Spacer() }
            case .text(let t):
                Text(t).font(HandyFont.body).textSelection(.enabled)
                HStack { copyButton(t); ShareLink(item: t) { Label("Share", systemImage: "square.and.arrow.up") }.compactButton(); Spacer() }
            }
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(HandyColor.textSecondary).frame(width: 90, alignment: .leading); Text(v); Spacer() }.font(HandyFont.body)
    }
    private func copyButton(_ s: String) -> some View {
        Button { UIPasteboard.general.string = s; ClipStore.add(s); HandyHaptics.success() } label: { Label("Copy", systemImage: "doc.on.doc") }.compactButton()
    }
}

enum QRPayload {
    case wifi(ssid: String, password: String, security: String)
    case url(URL)
    case contact(vcf: String, summary: String)
    case phone(number: String, message: String)
    case email(String)
    case location(lat: Double, lon: Double)
    case text(String)

    var title: String {
        switch self {
        case .wifi: return "Wi‑Fi network"; case .url: return "Link"; case .contact: return "Contact"
        case .phone: return "Phone number"; case .email: return "Email address"; case .location: return "Location"; case .text: return "Text"
        }
    }
    var icon: String {
        switch self {
        case .wifi: return "wifi"; case .url: return "link"; case .contact: return "person.crop.circle"
        case .phone: return "phone"; case .email: return "envelope"; case .location: return "mappin"; case .text: return "text.quote"
        }
    }

    static func parse(_ s: String) -> QRPayload {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let up = t.uppercased()
        if up.hasPrefix("WIFI:") {
            var ssid = "", pass = "", sec = "Open"
            for part in splitUnescaped(String(t.dropFirst(5)), on: ";") {
                if part.hasPrefix("S:") { ssid = unescape(String(part.dropFirst(2))) }
                else if part.hasPrefix("P:") { pass = unescape(String(part.dropFirst(2))) }
                else if part.hasPrefix("T:") { let v = String(part.dropFirst(2)); sec = v.lowercased() == "nopass" ? "Open" : v }
            }
            return .wifi(ssid: ssid, password: pass, security: sec)
        }
        if up.hasPrefix("BEGIN:VCARD") {
            var name = "", tel = "", mail = ""
            for line in t.components(separatedBy: .newlines) {
                let u = line.uppercased()
                if u.hasPrefix("FN:") { name = String(line.dropFirst(3)) }
                else if u.hasPrefix("TEL") , let v = line.split(separator: ":", maxSplits: 1).last { tel = String(v) }
                else if u.hasPrefix("EMAIL"), let v = line.split(separator: ":", maxSplits: 1).last { mail = String(v) }
            }
            return .contact(vcf: t, summary: [name, tel, mail].filter { !$0.isEmpty }.joined(separator: " · "))
        }
        if up.hasPrefix("MAILTO:") { return .email(String(t.dropFirst(7)).components(separatedBy: "?").first ?? "") }
        if up.hasPrefix("TEL:") { return .phone(number: String(t.dropFirst(4)), message: "") }
        if up.hasPrefix("SMSTO:") { let p = t.dropFirst(6).split(separator: ":", maxSplits: 1); return .phone(number: String(p.first ?? ""), message: p.count > 1 ? String(p[1]) : "") }
        if up.hasPrefix("SMS:") { return .phone(number: String(t.dropFirst(4)).components(separatedBy: "?").first ?? "", message: "") }
        if up.hasPrefix("GEO:") {
            let nums = t.dropFirst(4).components(separatedBy: "?").first?.components(separatedBy: ",").compactMap { Double($0) } ?? []
            if nums.count >= 2 { return .location(lat: nums[0], lon: nums[1]) }
        }
        if let u = URL(string: t), let sch = u.scheme?.lowercased(), sch == "http" || sch == "https" { return .url(u) }
        if t.contains("@"), !t.contains(" "), t.split(separator: "@").count == 2 { return .email(t) }
        return .text(t)
    }

    static func wifi(ssid: String, password: String, security: String, hidden: Bool) -> String {
        "WIFI:T:\(security);S:\(escape(ssid));P:\(escape(password));\(hidden ? "H:true;" : "");"
    }
    static func vcard(name: String, phone: String, email: String, org: String) -> String {
        var l = ["BEGIN:VCARD", "VERSION:3.0", "FN:\(name)", "N:\(name);;;;"]
        if !phone.isEmpty { l.append("TEL;TYPE=CELL:\(phone)") }
        if !email.isEmpty { l.append("EMAIL:\(email)") }
        if !org.isEmpty { l.append("ORG:\(org)") }
        l.append("END:VCARD")
        return l.joined(separator: "\n")
    }
    /// Split on `sep` while honouring backslash escapes (so an SSID like `Home\;Net` survives).
    static func splitUnescaped(_ s: String, on sep: Character) -> [String] {
        var out: [String] = [], cur = "", esc = false
        for ch in s {
            if esc { cur.append("\\"); cur.append(ch); esc = false }
            else if ch == "\\" { esc = true }
            else if ch == sep { out.append(cur); cur = "" }
            else { cur.append(ch) }
        }
        if esc { cur.append("\\") }
        if !cur.isEmpty { out.append(cur) }
        return out
    }
    static func escape(_ s: String) -> String { s.replacingOccurrences(of: #"([\\;,":])"#, with: #"\\$1"#, options: .regularExpression) }
    static func unescape(_ s: String) -> String { s.replacingOccurrences(of: #"\\([\\;,":])"#, with: "$1", options: .regularExpression) }
}

enum QRGen {
    static func make(_ payload: String, scale: CGFloat, correction: String = "M") -> UIImage? {
        let p = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty else { return nil }
        let f = CIFilter.qrCodeGenerator(); f.message = Data(p.utf8); f.correctionLevel = correction
        guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// 1200×800 printable card: title, QR, network name, and a one-line how-to.
    static func wifiCard(ssid: String, password: String, security: String) -> UIImage? {
        guard let qr = make(QRPayload.wifi(ssid: ssid, password: password, security: security, hidden: false), scale: 14, correction: "H") else { return nil }
        let size = CGSize(width: 1200, height: 800)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            let para = NSMutableParagraphStyle(); para.alignment = .center
            ("Scan to join our Wi‑Fi" as NSString).draw(in: CGRect(x: 0, y: 56, width: size.width, height: 80),
                withAttributes: [.font: UIFont.systemFont(ofSize: 58, weight: .bold), .foregroundColor: UIColor.black, .paragraphStyle: para])
            let q: CGFloat = 440
            qr.draw(in: CGRect(x: (size.width - q) / 2, y: 160, width: q, height: q))
            (ssid as NSString).draw(in: CGRect(x: 0, y: 620, width: size.width, height: 60),
                withAttributes: [.font: UIFont.systemFont(ofSize: 40, weight: .semibold), .foregroundColor: UIColor.black, .paragraphStyle: para])
            ("Open your camera, point it here, tap the banner." as NSString).draw(in: CGRect(x: 0, y: 690, width: size.width, height: 50),
                withAttributes: [.font: UIFont.systemFont(ofSize: 28), .foregroundColor: UIColor.darkGray, .paragraphStyle: para])
        }
    }
}


// MARK: - Live scanner

private struct ScanSheet: View {
    let onResult: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack(alignment: .topTrailing) {
            LiveScanner(onResult: onResult).ignoresSafeArea()
            Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.largeTitle).foregroundStyle(.white).padding() }
                .accessibilityLabel("Close scanner")
        }
    }
}

private struct LiveScanner: UIViewControllerRepresentable {
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
