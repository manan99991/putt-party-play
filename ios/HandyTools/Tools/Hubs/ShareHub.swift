import SwiftUI
import PhotosUI
import Photos
import VisionKit
import Network
import Contacts
import UniformTypeIdentifiers

/// Share & Connect — send a file over the local Wi-Fi (LocalShareServer), make QR codes, scan them
/// and act on what they are (QRPayload / ScamAnalyzer), and see your Wi-Fi details with a speed test.
struct ShareHub: View {
    @State private var tab = 0

    // send a file
    @StateObject private var server = LocalShareServer()
    @State private var sendFile: URL?
    @State private var sendQR: UIImage?
    @State private var showFilePicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var sendError: String?

    // make QR
    @State private var kind = 0            // 0 text/link, 1 wifi, 2 contact
    @State private var text = ""
    @State private var ssid = ""
    @State private var password = ""
    @State private var security = 0        // 0 WPA/WPA2, 1 WEP, 2 open
    @State private var cName = ""
    @State private var cPhone = ""
    @State private var cEmail = ""
    @State private var qrImage: UIImage?
    @State private var makeNote: String?

    // scan
    @State private var showScanner = false
    @State private var scanPhoto: PhotosPickerItem?
    @State private var scanImage: UIImage?
    @State private var scanned: String?
    @State private var scanError: String?
    @State private var revealPassword = false
    @State private var contactNote: String?

    // wi-fi
    @State private var monitor: NWPathMonitor?
    @State private var onWifi = false
    @State private var ip: String?
    @State private var speed = "—"
    @State private var testing = false

    var body: some View {
        PowerToolPage(id: "share", tabs: ["Send a file", "Make QR", "Scan", "Wi-Fi"], selected: $tab) {
            Group {
                switch tab {
                case 0: sendTab
                case 1: makeTab
                case 2: scanTab
                default: wifiTab
                }
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item], allowsMultipleSelection: false) { res in
            if case .success(let urls) = res, let u = urls.first { stage(u) }
        }
        .onChange(of: photoItem) { _, item in loadPhoto(item) }
        .onChange(of: scanPhoto) { _, item in scanFromPhoto(item) }
        .onChange(of: server.port) { _, _ in sendQR = server.url.flatMap { QRGen.make($0, scale: 10) } }
        .fullScreenCover(isPresented: $showScanner) { ScanSheet { scanned = $0; scanImage = nil; scanError = nil; showScanner = false } }
        .onAppear {
            let m = NWPathMonitor()
            m.pathUpdateHandler = { path in let w = path.usesInterfaceType(.wifi); DispatchQueue.main.async { onWifi = w; ip = LocalNet.wifiIPv4() } }
            m.start(queue: DispatchQueue(label: "tenzy.share.path"))
            monitor = m
            ip = LocalNet.wifiIPv4()
            if let f = sendFile, server.state == .idle { server.start(file: f) }   // back from a cover: resume
        }
        .onDisappear { server.stop(); monitor?.cancel(); monitor = nil }
    }

    // MARK: - Send a file

    private var sendTab: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if let f = sendFile {
                fileCard(f)
                if let qr = sendQR, let u = server.url {
                    Image(uiImage: qr).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 200).frame(maxWidth: .infinity)
                        .padding(HandySpacing.s16).background(.white, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
                        .accessibilityLabel("QR code for \(u)")
                    VStack(spacing: 4) {
                        Text("Scan on the other device, or open").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        Text(u).font(.system(size: 14, design: .monospaced)).fontWeight(.semibold).textSelection(.enabled)
                    }.frame(maxWidth: .infinity)
                    ProgressView(value: progressValue).tint(HandyColor.accent)
                    HStack(spacing: HandySpacing.s8) {
                        if case .sending = server.state { ProgressView().tint(HandyColor.accent) }
                        Text(server.state.label).font(HandyFont.body).foregroundStyle(server.state == .delivered ? HandyColor.success : HandyColor.textPrimary)
                    }.frame(maxWidth: .infinity)
                    HStack(spacing: HandySpacing.s8) {
                        Button { stopSending() } label: { Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity) }.secondaryButton()
                        ShareLink(item: f) { Label("Send another way", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
                    }
                    HubNote("Both devices must be on the same Wi-Fi. The file streams straight from this phone — nothing is uploaded.")
                } else {
                    HubPill(onWifi ? "Setting up…" : "Needs Wi-Fi — both devices on the same network", tone: .native)
                    if case .failed(let m) = server.state, m != "Not on Wi-Fi" { Text(m).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
                    ShareLink(item: f) { Label("Send another way (AirDrop, Messages…)", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
                    HStack(spacing: HandySpacing.s8) {
                        Button { retry(f) } label: { Label("Try Wi-Fi again", systemImage: "arrow.clockwise").frame(maxWidth: .infinity) }.secondaryButton()
                        Button { stopSending() } label: { Text("Pick a different file").frame(maxWidth: .infinity) }.secondaryButton()
                    }
                }
            } else {
                HubPreviewBox(minHeight: 150) {
                    VStack(spacing: HandySpacing.s8) {
                        Image(systemName: "wifi").font(.system(size: 28)).foregroundStyle(HandyColor.accent)
                        Text("Pick any file. The other device scans the code or opens the address — same Wi-Fi, no cable, no cloud.")
                            .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                    }.padding(HandySpacing.s16)
                }
                HStack(spacing: HandySpacing.s8) {
                    Button { showFilePicker = true } label: { Label("Choose file", systemImage: "paperclip").frame(maxWidth: .infinity) }.primaryButton()
                    PhotosPicker(selection: $photoItem, matching: .any(of: [.images, .videos])) { Label("Photo", systemImage: "photo").frame(maxWidth: .infinity) }.secondaryButton()
                }
            }
            if let sendError { Text(sendError).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
    }

    private var progressValue: Double {
        switch server.state { case .sending(let p): return p; case .delivered: return 1; default: return 0 }
    }

    private func fileCard(_ f: URL) -> some View {
        let size = (try? FileManager.default.attributesOfItem(atPath: f.path)[.size] as? Int) ?? 0
        let ext = f.pathExtension.lowercased()
        let icon = ["jpg", "jpeg", "png", "heic", "gif", "webp"].contains(ext) ? "photo" : ["mp4", "mov", "m4v"].contains(ext) ? "film" : ext == "pdf" ? "doc.richtext" : "doc"
        return HStack(spacing: HandySpacing.s12) {
            Image(systemName: icon).font(.system(size: 24)).foregroundStyle(HandyColor.accent).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(f.lastPathComponent).font(HandyFont.bodyStrong).lineLimit(2)
                Text(SizeTarget.format(size)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Spacer(minLength: 0)
        }.cardStyle(padding: HandySpacing.s12)
    }

    private func stage(_ picked: URL) {
        let ok = picked.startAccessingSecurityScopedResource(); defer { if ok { picked.stopAccessingSecurityScopedResource() } }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Send", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(picked.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        guard (try? FileManager.default.copyItem(at: picked, to: dest)) != nil else { sendError = "Couldn't read that file."; return }
        begin(dest)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let d = try? await item.loadTransferable(type: Data.self) else { sendError = "Couldn't load that photo."; photoItem = nil; return }
            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Send", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent("Photo-\(Int(Date().timeIntervalSince1970)).\(ext)")
            if (try? d.write(to: dest)) != nil { begin(dest) } else { sendError = "Couldn't save that photo." }
            photoItem = nil
        }
    }

    private func begin(_ url: URL) {
        sendError = nil; sendFile = url; sendQR = nil
        server.start(file: url)
        HandyHaptics.light()
    }
    private func retry(_ url: URL) { ip = LocalNet.wifiIPv4(); server.start(file: url) }
    private func stopSending() { server.stop(); sendFile = nil; sendQR = nil }

    // MARK: - Make QR

    private var makeTab: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if let qrImage {
                Image(uiImage: qrImage).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 220).frame(maxWidth: .infinity)
                    .padding(HandySpacing.s20).background(.white, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
                    .accessibilityLabel("Your QR code")
            } else {
                HubPreviewBox(minHeight: 120) {
                    Text("Your code shows here.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s16)
                }
            }
            FlowLayout(spacing: 6) {
                ForEach(Array(["Text / link", "Wi-Fi login", "Contact"].enumerated()), id: \.offset) { i, name in
                    HubChip(name, selected: kind == i) { kind = i; qrImage = nil; makeNote = nil }
                }
            }
            switch kind {
            case 0:
                field("Text or URL…", $text).keyboardType(.URL)
            case 1:
                field("Network name", $ssid)
                SecureField("Password", text: $password).padding(HandySpacing.s12)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                FlowLayout(spacing: 6) {
                    ForEach(Array(["WPA/WPA2", "WEP", "Open"].enumerated()), id: \.offset) { i, name in HubChip(name, selected: security == i) { security = i } }
                }
            default:
                field("Name", $cName)
                field("Phone", $cPhone).keyboardType(.phonePad)
                field("Email", $cEmail).keyboardType(.emailAddress)
            }
            Button { makeQR() } label: { Label("Make QR", systemImage: "qrcode").frame(maxWidth: .infinity) }.primaryButton()
            if let qrImage, let png = qrImage.pngData() {
                HStack(spacing: HandySpacing.s8) {
                    Button { saveToPhotos(qrImage) } label: { Label("Save image", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity) }.secondaryButton()
                    ShareLink(item: PNGFile(data: png), preview: SharePreview("QR code")) { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
                }
            }
            if let makeNote { Text(makeNote).font(HandyFont.caption).foregroundStyle(makeNote.hasPrefix("Saved") ? HandyColor.success : HandyColor.textSecondary) }
            HubNote(kind == 1 ? "Anyone who scans it joins your Wi-Fi without typing the password. Made on this phone; nothing is sent anywhere." : "Made on this phone; nothing is sent anywhere.")
        }
    }

    private func field(_ ph: String, _ b: Binding<String>) -> some View {
        TextField(ph, text: b).autocorrectionDisabled().textInputAutocapitalization(.never)
            .padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }

    private func makeQR() {
        makeNote = nil
        let payload: String
        switch kind {
        case 0: payload = text
        case 1:
            guard !ssid.trimmingCharacters(in: .whitespaces).isEmpty else { makeNote = "Enter the network name."; return }
            payload = QRPayload.wifi(ssid: ssid, password: security == 2 ? "" : password, security: ["WPA", "WEP", "nopass"][security], hidden: false)
        default:
            guard !cName.trimmingCharacters(in: .whitespaces).isEmpty else { makeNote = "Enter a name."; return }
            payload = QRPayload.vcard(name: cName, phone: cPhone, email: cEmail, org: "")
        }
        qrImage = QRGen.make(payload, scale: 12)
        if qrImage == nil { makeNote = "Nothing to encode yet." } else { HandyHaptics.success() }
    }

    private func saveToPhotos(_ img: UIImage) {
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else { makeNote = "Photos access is off — use Share to save it instead."; return }
            do {
                try await PHPhotoLibrary.shared().performChanges { _ = PHAssetChangeRequest.creationRequestForAsset(from: img) }
                makeNote = "Saved to Photos"; HandyHaptics.success()
            } catch { makeNote = "Couldn't save — use Share instead." }
        }
    }

    // MARK: - Scan

    private var scanTab: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HubPreviewBox(minHeight: 150) {
                if let scanImage {
                    Image(uiImage: scanImage).resizable().scaledToFit().frame(maxHeight: 260).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Text("Scan any QR or barcode.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s16)
                }
            }
            HStack(spacing: HandySpacing.s8) {
                Button { showScanner = true } label: { Label("Scan", systemImage: "camera").frame(maxWidth: .infinity) }.primaryButton().disabled(!DataScannerViewController.isSupported)
                PhotosPicker(selection: $scanPhoto, matching: .images) { Label("From image", systemImage: "photo").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if !DataScannerViewController.isSupported { HubPill("Live scanning runs on a real phone — From image works here", tone: .native) }
            if let scanError { Text(scanError).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let scanned { resultCard(scanned) }
        }
    }

    private func scanFromPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        scanError = nil
        Task {
            guard let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) else { scanError = "Couldn't load that image."; scanPhoto = nil; return }
            let found = CaptureView.barcode(in: img)
            scanImage = img.resized(maxDimension: 1200)
            if let found { scanned = found; HandyHaptics.success() } else { scanned = nil; scanError = "No code found — try a clearer, closer shot." }
            scanPhoto = nil
        }
    }

    private func resultCard(_ raw: String) -> some View {
        let parsed = QRPayload.parse(raw)
        return VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack { HubPill("✓ " + pillName(parsed), tone: .ok); Spacer() }
            Group {
                switch parsed {
                case .url(let u): linkResult(u)
                case .wifi(let n, let p, let sec): wifiResult(ssid: n, password: p, security: sec)
                case .text(let t):
                    Text(t).font(HandyFont.body).textSelection(.enabled)
                    HStack(spacing: HandySpacing.s8) { copyButton(t); ShareLink(item: t) { Label("Share", systemImage: "square.and.arrow.up") }.compactButton(); Spacer() }
                case .contact(let vcf, let summary): contactResult(vcf: vcf, summary: summary)
                default: QRResultCard(raw: raw)
                }
            }
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    private func pillName(_ p: QRPayload) -> String {
        switch p { case .url: return "Link"; case .wifi: return "Wi-Fi login"; case .contact: return "Contact"; case .text: return "Text"; default: return p.title }
    }

    private func linkResult(_ u: URL) -> some View {
        let report = ScamAnalyzer.analyze(u.absoluteString)
        let issues = report.links.flatMap(\.issues)
        let color: Color = report.verdict == .lowRisk && issues.isEmpty ? HandyColor.success : report.verdict == .likelyScam ? HandyColor.danger : HandyColor.amber
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(u.absoluteString).font(.system(size: 14, design: .monospaced)).lineLimit(4).textSelection(.enabled)
            HStack(spacing: HandySpacing.s8) {
                Image(systemName: issues.isEmpty && report.verdict == .lowRisk ? "checkmark.shield.fill" : "exclamationmark.shield.fill").foregroundStyle(color)
                Text(issues.isEmpty && report.verdict == .lowRisk ? "Looks low-risk" : report.verdict == .lowRisk ? "Worth a second look" : report.verdict.rawValue).font(HandyFont.bodyStrong).foregroundStyle(color)
            }
            ForEach(Array(issues.prefix(3).enumerated()), id: \.offset) { _, s in Text("• " + s).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            HStack(spacing: HandySpacing.s8) {
                Link(destination: u) { Label("Open", systemImage: "safari") }.compactButton()
                copyButton(u.absoluteString)
                Spacer()
            }
        }
    }

    private func wifiResult(ssid: String, password: String, security: String) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack { Text("Network").foregroundStyle(HandyColor.textSecondary).frame(width: 90, alignment: .leading); Text(ssid); Spacer() }.font(HandyFont.body)
            HStack { Text("Security").foregroundStyle(HandyColor.textSecondary).frame(width: 90, alignment: .leading); Text(security); Spacer() }.font(HandyFont.body)
            HStack {
                Text("Password").foregroundStyle(HandyColor.textSecondary).frame(width: 90, alignment: .leading)
                Text(password.isEmpty ? "none" : revealPassword ? password : String(repeating: "•", count: max(6, password.count))).font(.system(.body, design: .monospaced))
                Spacer()
                if !password.isEmpty { Button(revealPassword ? "Hide" : "Show") { revealPassword.toggle() }.textButton().font(HandyFont.caption) }
            }.font(HandyFont.body)
            HStack(spacing: HandySpacing.s8) {
                Button { UIPasteboard.general.string = password; HandyHaptics.success(); if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } } label: { Label("Join", systemImage: "wifi") }.compactButton()
                copyButton(password)
                Spacer()
            }
            HubNote("iOS doesn't let apps join a network for you: Join copies the password and opens Settings — go to Wi-Fi › \(ssid) and paste it.")
        }
    }

    private func contactResult(vcf: String, summary: String) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(summary.isEmpty ? "Contact card" : summary).font(HandyFont.body)
            HStack(spacing: HandySpacing.s8) {
                Button { addContact(vcf) } label: { Label("Add to Contacts", systemImage: "person.crop.circle.badge.plus") }.compactButton()
                ShareLink(item: VCardFile(data: Data(vcf.utf8)), preview: SharePreview("Contact")) { Label("Share", systemImage: "square.and.arrow.up") }.compactButton()
                Spacer()
            }
            if let contactNote { Text(contactNote).font(HandyFont.caption).foregroundStyle(contactNote.hasPrefix("Added") ? HandyColor.success : HandyColor.textSecondary) }
        }
    }

    private func addContact(_ vcf: String) {
        Task {
            guard await ContactsEngine.requestAccess() else { contactNote = "Contacts access is off — use Share › Contacts instead."; return }
            do {
                let found = try CNContactVCardSerialization.contacts(with: Data(vcf.utf8))
                let req = CNSaveRequest()
                var n = 0
                for c in found { if let m = c.mutableCopy() as? CNMutableContact { req.add(m, toContainerWithIdentifier: nil); n += 1 } }
                guard n > 0 else { contactNote = "Couldn't read that contact card — use Share instead."; return }
                try CNContactStore().execute(req)
                contactNote = "Added to Contacts"; HandyHaptics.success()
            } catch { contactNote = "Couldn't add it — use Share › Contacts instead." }
        }
    }

    private func copyButton(_ s: String) -> some View {
        Button { UIPasteboard.general.string = s; HandyHaptics.success() } label: { Label("Copy", systemImage: "doc.on.doc") }.compactButton()
    }

    // MARK: - Wi-Fi

    private var wifiTab: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HubPill("Reads the current network on your phone", tone: .native)
            VStack(spacing: 0) {
                infoRow("Network", onWifi ? "Connected · name hidden by iOS" : "Not on Wi-Fi")
                Divider()
                infoRow("Your IP", ip ?? "—")
                Divider()
                infoRow("Speed", speed)
            }.cardStyle(padding: HandySpacing.s4)
            Button { speedTest() } label: {
                HStack { if testing { ProgressView().tint(.white) }; Label(testing ? "Testing…" : speed == "—" ? "Speed test" : "Speed test again", systemImage: "bolt.fill") }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(testing)
            Button { ssid = ""; kind = 1; qrImage = nil; makeNote = "Type the network name and password, then Make QR."; tab = 1 } label: {
                Label("Share this Wi-Fi as QR", systemImage: "qrcode").frame(maxWidth: .infinity)
            }.secondaryButton()
            HubNote("iOS only shows the network name and router to apps with a special entitlement, so those stay hidden here. Your IP and the speed test are real. The speed test downloads 10 MB once from Cloudflare.")
        }
    }

    private func infoRow(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(HandyColor.textSecondary); Spacer(); Text(v).font(HandyFont.bodyStrong).multilineTextAlignment(.trailing) }
            .font(HandyFont.body).padding(.horizontal, HandySpacing.s12).padding(.vertical, HandySpacing.s12)
    }

    private func speedTest() {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=10000000") else { return }
        testing = true; speed = "Testing…"
        Task {
            var req = URLRequest(url: url); req.timeoutInterval = 25; req.cachePolicy = .reloadIgnoringLocalCacheData
            let t0 = Date()
            do {
                let (d, _) = try await URLSession.shared.data(for: req)
                let secs = max(0.05, Date().timeIntervalSince(t0))
                speed = String(format: "%.1f Mbps ↓", Double(d.count) * 8 / 1_000_000 / secs)
                HandyHaptics.success()
            } catch { speed = "Couldn't measure — check the connection" }
            testing = false
        }
    }
}
