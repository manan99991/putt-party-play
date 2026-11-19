import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Protect a PDF — lock it with a password, take a password off, or stamp a see-through watermark
/// ("CONFIDENTIAL", "DRAFT", your name) across every page. A locked file is spotted on open and goes
/// straight to unlocking. Every result is checked by reopening it before you Save or Share. On device.
struct PDFProtectView: View {
    enum Mode: String, CaseIterable, Hashable { case lock, watermark, unlock
        var title: String {
            switch self {
            case .lock: return "Password"
            case .watermark: return "Watermark"
            case .unlock: return "Remove password"
            }
        }
    }

    @State private var sourceData: Data?
    @State private var preview: UIImage?
    @State private var sourceLocked = false
    @State private var fileName = "Document"
    @State private var mode: Mode = .lock
    @State private var password = ""
    @State private var confirm = ""
    @State private var madePassword: String?
    @State private var lockedWith: String?
    @State private var stampText = "CONFIDENTIAL"
    @State private var opacity: Double = 0.18
    @State private var resultURL: URL?
    @State private var resultPreview: UIImage?
    @State private var resultNote = ""
    @State private var working = false
    @State private var errorText: String?
    @State private var showFiles = false

    var body: some View {
        ToolPage(title: "Protect PDF",
                 subtitle: "Add or remove a password, or watermark every page.",
                 working: working) {
            VStack(spacing: HandySpacing.s16) {
                if sourceData == nil { pickCard }
                else if let url = resultURL { result(url) }
                else { editor }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf]) { res in
            if case .success(let url) = res { load(url) }
        }
        .onChange(of: mode) { _, _ in errorText = nil }
        .onAppear { if Launch.sample, sourceData == nil { loadSample() } }
        .handoff("pdfprotect") { p in if let u = ToolHandoff.fileURL(p) { load(u) } }
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "lock.doc").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose a PDF to lock with a password, unlock, or watermark."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { showFiles = true } label: {
                Label(L("Choose a PDF"), systemImage: "folder").frame(maxWidth: .infinity)
            }.primaryButton()
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    // MARK: - Editor

    private var modes: [Mode] { sourceLocked ? [.unlock] : [.lock, .watermark] }

    private var editor: some View {
        VStack(spacing: HandySpacing.s12) {
            if modes.count > 1 {
                Picker("", selection: $mode) { ForEach(modes, id: \.self) { Text(L($0.title)).tag($0) } }
                    .pickerStyle(.segmented)
            }
            pagePreview

            switch mode {
            case .lock:
                VStack(spacing: HandySpacing.s8) {
                    SecureField(L("Password"), text: $password).textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                    SecureField(L("Type it again"), text: $confirm).textFieldStyle(.roundedBorder)
                    Button {
                        let p = Self.strongPassword(); password = p; confirm = p; madePassword = p
                    } label: { Label(L("Make a strong one for me"), systemImage: "key.fill").frame(maxWidth: .infinity) }.secondaryButton()
                        .accessibilityIdentifier("protect-make")
                    if let madePassword, madePassword == password {
                        HStack {
                            Text(madePassword).font(.system(.title3, design: .monospaced).weight(.semibold)).textSelection(.enabled)
                            Spacer()
                            Button { Copier.copy(madePassword) } label: { Image(systemName: "doc.on.doc") }.compactButton().accessibilityLabel(L("Copy"))
                        }
                        Text(L("Easy to read out or type, hard to guess.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text(L("Anyone opening the file will need this password. Tenzy doesn't keep it — note it somewhere safe."))
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            case .unlock:
                VStack(spacing: HandySpacing.s8) {
                    Label(L("This PDF is locked."), systemImage: "lock.fill")
                        .font(HandyFont.bodyStrong).frame(maxWidth: .infinity, alignment: .leading)
                    SecureField(L("Its current password"), text: $password).textFieldStyle(.roundedBorder)
                    Text(L("Tenzy saves a copy that opens without a password. You need the current password — this doesn't crack files."))
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            case .watermark:
                VStack(spacing: HandySpacing.s8) {
                    TextField(L("Watermark text"), text: $stampText).textFieldStyle(.roundedBorder)
                    HStack(spacing: HandySpacing.s8) {
                        ForEach(["CONFIDENTIAL", "DRAFT", "COPY", "SAMPLE"], id: \.self) { s in
                            Button(L(s)) { stampText = s }.font(HandyFont.caption).buttonStyle(.bordered)
                        }
                    }
                    HStack {
                        Text(L("Strength")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        Slider(value: $opacity, in: 0.08...0.45).tint(HandyColor.accent)
                    }
                }
            }

            if let e = errorText {
                Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { run() } label: {
                Label(actionTitle, systemImage: mode == .watermark ? "drop.fill" : (mode == .lock ? "lock.fill" : "lock.open.fill"))
                    .frame(maxWidth: .infinity)
            }.primaryButton().disabled(!ready || working)
            if working { ToolProgressBar(label: "Working on your PDF…") }
            Button(L("Choose a different PDF")) { reset() }.textButton().font(HandyFont.caption)
        }
    }

    @ViewBuilder private var pagePreview: some View {
        if let img = preview {
            ZStack {
                Image(uiImage: img).resizable().scaledToFit()
                if mode == .watermark && !stampText.trimmingCharacters(in: .whitespaces).isEmpty {
                    GeometryReader { g in
                        Text(stampText).font(.system(size: 200, weight: .bold)).minimumScaleFactor(0.05).lineLimit(1)
                            .foregroundStyle(Color.gray.opacity(opacity))
                            .frame(width: g.size.width * 0.85)
                            .rotationEffect(.radians(-atan2(g.size.height, g.size.width)))
                            .position(x: g.size.width / 2, y: g.size.height / 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
        }
    }

    private var actionTitle: String {
        switch mode {
        case .lock: return L("Lock with password")
        case .unlock: return L("Remove password")
        case .watermark: return L("Add watermark")
        }
    }

    private var ready: Bool {
        switch mode {
        case .lock: return password.count >= 4 && password == confirm
        case .unlock: return !password.isEmpty
        case .watermark: return !stampText.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: - Result

    private func result(_ url: URL) -> some View {
        VStack(spacing: HandySpacing.s12) {
            Label(resultNote, systemImage: "checkmark.shield.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let img = resultPreview {
                Image(uiImage: img).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            }
            ShareLink(item: url) {
                Label(L("Save or share PDF"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }.primaryButton()
            if let pw = lockedWith {
                ShareLink(item: "\(L("Password for")) \(fileName).pdf: \(pw)") {
                    Label(L("Send the password separately"), systemImage: "key.horizontal").frame(maxWidth: .infinity)
                }.secondaryButton()
                Text(L("Send it a different way from the file — if you emailed the PDF, text the password. Then anyone who gets one without the other can't open it."))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            }
            Button(L("Start over")) { resultURL = nil; resultPreview = nil }.textButton().font(HandyFont.caption)
        }
    }

    /// Four everyday words and four digits, e.g. "Maple-Tiger-Harbor-Ember-4827": about 37 bits from the system's secure
    /// random source — beyond guessing by hand, still easy to read down a phone line.
    static let words = ["Maple", "Tiger", "Harbor", "Cactus", "Velvet", "Orbit", "Pepper", "Canyon", "Willow", "Falcon", "Lemon", "Glacier", "Comet", "Saddle", "Meadow", "Pebble",
                        "Rocket", "Thistle", "Lantern", "Bamboo", "Copper", "Dolphin", "Ember", "Juniper", "Marble", "Nectar", "Otter", "Prairie", "Quartz", "Raven", "Summit", "Tulip",
                        "Umber", "Violet", "Walnut", "Yonder", "Zephyr", "Anchor", "Biscuit", "Cobalt", "Dune", "Fern", "Garnet", "Hazel", "Iris", "Jasper", "Kettle", "Lagoon",
                        "Mango", "Nimbus", "Olive", "Parrot", "Ripple", "Sparrow", "Timber", "Valley", "Wren", "Amber", "Breeze", "Cedar", "Delta", "Echo", "Fable", "Grove"]
    static func strongPassword() -> String {
        var g = SystemRandomNumberGenerator()
        let picked = (0..<4).map { _ in words.randomElement(using: &g)! }
        return picked.joined(separator: "-") + "-" + String(format: "%04d", Int.random(in: 0...9999, using: &g))
    }

    // MARK: - Actions

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let doc = PDFDocument(data: data) else {
            errorText = "Couldn't open that PDF."; return
        }
        sourceData = data
        fileName = url.deletingPathExtension().lastPathComponent
        sourceLocked = doc.isLocked
        mode = doc.isLocked ? .unlock : .lock
        preview = doc.isLocked ? nil : doc.page(at: 0)?.thumbnail(of: CGSize(width: 900, height: 1200), for: .mediaBox)
        password = ""; confirm = ""; resultURL = nil; resultPreview = nil; errorText = nil
    }

    private func loadSample() {
        let img = SampleAssets.document()
        var opts = DocEngine.PDFOptions(); opts.searchable = false
        guard let data = DocEngine.pdf(images: [img], ocr: [nil], options: opts) else { return }
        sourceData = data; preview = img; sourceLocked = false; mode = .lock; fileName = "Sample"
    }

    private func reset() {
        sourceData = nil; preview = nil; sourceLocked = false; mode = .lock
        password = ""; confirm = ""; resultURL = nil; resultPreview = nil; errorText = nil
    }

    private func run() {
        guard let data = sourceData else { return }
        working = true; errorText = nil
        let m = mode, pw = password, text = stampText, op = CGFloat(opacity)
        let base = fileName.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        let suffix = m == .lock ? "locked" : (m == .unlock ? "unlocked" : "watermarked")
        Task { @MainActor in
            let out: URL? = await Task.detached(priority: .userInitiated) {
                let made: Data?
                switch m {
                case .lock: made = PDFSecure.protect(data, password: pw)
                case .unlock: made = PDFSecure.unlock(data, password: pw)
                case .watermark: made = PDFOverlay.watermark(data, text: text, opacity: op)
                }
                guard let d = made else { return nil }
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(base.isEmpty ? "Document" : String(base.prefix(50))) (\(suffix)).pdf")
                try? FileManager.default.removeItem(at: url)
                guard (try? d.write(to: url)) != nil else { return nil }
                return url
            }.value
            working = false
            // Check the REAL output by reopening it.
            guard let url = out, let doc = PDFDocument(url: url) else {
                errorText = m == .unlock ? "That password didn't open it — check it and try again." : "Couldn't save the PDF — try again."
                return
            }
            switch m {
            case .lock:
                guard doc.isLocked else { errorText = "The lock didn't take — try again."; return }
                resultNote = L("Locked — it now asks for your password to open.")
                lockedWith = pw
                resultPreview = preview
            case .unlock:
                guard !doc.isLocked else { errorText = "Still locked — try again."; return }
                resultNote = L("Password removed — this copy opens freely.")
                lockedWith = nil
                resultPreview = doc.page(at: 0)?.thumbnail(of: CGSize(width: 900, height: 1200), for: .mediaBox)
            case .watermark:
                resultNote = L("Watermarked on every page — check it below.")
                resultPreview = doc.page(at: 0)?.thumbnail(of: CGSize(width: 900, height: 1200), for: .mediaBox)
            }
            resultURL = url
            HandyHaptics.success()
        }
    }
}
