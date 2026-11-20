import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Protect a PDF — everything at once, on one screen: a watermark (across the page, repeated, or along the
/// bottom; any colour; "For Priya · 20 Nov" on every page so a leaked copy says whose it was), a password to open,
/// printing and copying blocked, and the watermark burned in so it can't be edited out. Hidden details (author,
/// app) are dropped. The preview is the real first page with the real watermark. Every result is read back from the
/// saved file — locked? watermark there? printing blocked? — before you Save or Share. A locked file is spotted on
/// open and goes straight to unlocking. On device.
struct PDFProtectView: View {
    enum Mode: String, CaseIterable, Hashable { case protect, unlock }

    @State private var sourceData: Data?
    @State private var preview: UIImage?
    @State private var sourceLocked = false
    @State private var fileName = "Document"
    @State private var mode: Mode = .protect
    @State private var useMark = true
    @State private var useLock = true
    @State private var prot = PDFSecure.Protection(watermark: "CONFIDENTIAL")
    @State private var livePreview: UIImage?
    @State private var check: PDFSecure.Check?
    @State private var password = ""
    @State private var confirm = ""
    @State private var madePassword: String?
    @State private var lockedWith: String?
    @State private var resultURL: URL?
    @State private var resultPreview: UIImage?
    @State private var resultNote = ""
    @State private var working = false
    @State private var errorText: String?
    @State private var showFiles = false
    @State private var shownMark: String?
    @State private var burned = false
    @State private var blockedPrint = false
    @State private var blockedCopy = false

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
        .onChange(of: prot) { _, _ in refreshPreview() }
        .onChange(of: useMark) { _, _ in refreshPreview() }
        .onAppear { if Launch.sample, sourceData == nil { loadSample() } }
        .handoff("pdfprotect") { p in if let u = ToolHandoff.fileURL(p) { load(u) } }
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "lock.doc").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose a PDF to watermark, lock with a password, block printing and copying — all at once — or unlock."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { showFiles = true } label: {
                Label(L("Choose a PDF"), systemImage: "folder").frame(maxWidth: .infinity)
            }.primaryButton()
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            pagePreview
            if mode == .unlock { unlockCard } else {
                markCard
                lockCard
                limitsCard
                summary
            }
            if let e = errorText {
                Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger).frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { run() } label: {
                Label(actionTitle, systemImage: mode == .unlock ? "lock.open.fill" : "checkmark.shield.fill").frame(maxWidth: .infinity)
            }.primaryButton().disabled(!ready || working).accessibilityIdentifier("protect-run")
            if working { ToolProgressBar(label: "Protecting every page…") }
            Button(L("Choose a different PDF")) { reset() }.textButton().font(HandyFont.caption).frame(maxWidth: .infinity)
        }
    }

    /// A text box that reads clearly on the dark screen: a label above, the app's own field look.
    private func field(_ title: String, _ text: Binding<String>, secure: Bool = false, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L(title)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            Group {
                if secure { SecureField("", text: text, prompt: Text(L(title)).foregroundStyle(HandyColor.textSecondary)) }
                else { TextField("", text: text, prompt: Text(L(title)).foregroundStyle(HandyColor.textSecondary)) }
            }
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .foregroundStyle(HandyColor.textPrimary)
            .padding(HandySpacing.s12)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            .accessibilityIdentifier(id)
        }
    }

    private func section<C: View>(_ title: String, icon: String, on: Binding<Bool>?, id: String, @ViewBuilder _ body: () -> C) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            if let on {
                Toggle(isOn: on) { Label(L(title), systemImage: icon).font(HandyFont.bodyStrong) }
                    .tint(HandyColor.accent).accessibilityIdentifier(id)
                if on.wrappedValue { body() }
            } else {
                Label(L(title), systemImage: icon).font(HandyFont.bodyStrong)
                body()
            }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private var markCard: some View {
        section("Watermark every page", icon: "drop.fill", on: $useMark, id: "protect-mark") {
            field("Watermark words", $prot.watermark, id: "protect-mark-text")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["CONFIDENTIAL", "DRAFT", "COPY", "SAMPLE", "DO NOT SHARE", "PAID", "VOID"], id: \.self) { w in
                        Button { prot.watermark = w } label: {
                            Text(L(w)).font(HandyFont.caption).padding(.horizontal, 10).padding(.vertical, 6)
                                .background(prot.watermark == w ? HandyColor.accent : HandyColor.surface, in: Capsule())
                                .foregroundStyle(prot.watermark == w ? Color.white : HandyColor.textPrimary)
                        }.buttonStyle(.plain)
                    }
                }
            }
            Picker("", selection: $prot.style) { ForEach(PDFSecure.Protection.Style.allCases) { Text(L($0.title)).tag($0) } }
                .pickerStyle(.segmented)
            HStack(spacing: 12) {
                ForEach(PDFSecure.markColors, id: \.self) { c in
                    Button { prot.color = c } label: {
                        Circle().fill(Color(hex: c)).frame(width: 26, height: 26)
                            .overlay(Circle().stroke(prot.color == c ? HandyColor.accent : HandyColor.border, lineWidth: prot.color == c ? 3 : 1).padding(-3))
                    }.buttonStyle(.plain).accessibilityLabel(L("Colour"))
                }
                Text(L("Strength")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Slider(value: Binding(get: { Double(prot.opacity) }, set: { prot.opacity = CGFloat($0) }), in: 0.08...0.45).tint(HandyColor.accent)
            }
            field("Who is this copy for? (optional)", $prot.recipient, id: "protect-recipient")
            if !prot.recipient.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("“\(PDFSecure.traceLine(prot.recipient))” \(L("goes on every page — if it's passed on, it says whose copy it was."))")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Toggle(isOn: $prot.burnIn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Burn it in")).font(HandyFont.body)
                    Text(L("Nobody can delete the watermark in a PDF editor. The words on the pages stop being selectable.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }.tint(HandyColor.accent)
        }
    }

    private var lockCard: some View {
        section("Password to open", icon: "lock.fill", on: $useLock, id: "protect-lock") {
            field("Password", $password, secure: true, id: "protect-password")
            field("Type it again", $confirm, secure: true, id: "protect-confirm")
            if !confirm.isEmpty && confirm != password {
                Text(L("The two don't match yet.")).font(HandyFont.caption).foregroundStyle(HandyColor.amber)
            }
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
                Text(L("Easy to read out or type, hard to guess.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Text(L("Anyone opening the file will need this password. Tenzy doesn't keep it — note it somewhere safe."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var limitsCard: some View {
        section("What they can do with it", icon: "hand.raised.fill", on: nil, id: "protect-limits") {
            Toggle(L("Block printing"), isOn: Binding(get: { !prot.allowPrinting }, set: { prot.allowPrinting = !$0 }))
                .tint(HandyColor.accent).accessibilityIdentifier("protect-noprint")
            Toggle(L("Block copying the words"), isOn: Binding(get: { !prot.allowCopying }, set: { prot.allowCopying = !$0 }))
                .tint(HandyColor.accent).accessibilityIdentifier("protect-nocopy")
            Text(L("Honoured by Apple, Adobe, Chrome and other standard PDF apps. Nobody can switch these back on — keep your original."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One line saying exactly what the saved file will do.
    private var summary: some View {
        let parts = plan
        return Label(parts.isEmpty ? L("Turn something on above.") : parts.joined(separator: " · "), systemImage: "shield.lefthalf.filled")
            .font(HandyFont.caption).foregroundStyle(parts.isEmpty ? HandyColor.amber : HandyColor.textPrimary)
            .accessibilityIdentifier("protect-summary")
    }
    private var plan: [String] {
        var p: [String] = []
        if useMark && current.hasWatermark { p.append(L(prot.burnIn ? "Watermark burned in" : "Watermark on every page")) }
        if useLock { p.append(L("Password to open")) }
        if !prot.allowPrinting { p.append(L("No printing")) }
        if !prot.allowCopying { p.append(L("No copying")) }
        if !p.isEmpty { p.append(L("Hidden details removed")) }
        return p
    }

    /// The settings as they'll be applied (switched-off parts left out).
    private var current: PDFSecure.Protection {
        var p = prot
        if !useMark { p.watermark = ""; p.recipient = "" }
        p.openPassword = useLock ? password : ""
        return p
    }

    private var unlockCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("This PDF is locked."), systemImage: "lock.fill").font(HandyFont.bodyStrong)
            field("Its current password", $password, secure: true, id: "protect-current")
            Text(L("Tenzy saves a copy that opens without a password. You need the current password — this doesn't crack files."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }.cardStyle(padding: HandySpacing.s12)
    }

    @ViewBuilder private var pagePreview: some View {
        if let img = livePreview ?? preview {
            Image(uiImage: img).resizable().scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                .accessibilityLabel(L("Page 1 as it will look"))
        }
    }

    private func refreshPreview() {
        guard let d = sourceData, mode == .protect else { return }
        let p = current
        Task.detached(priority: .userInitiated) {
            let img = PDFSecure.preview(d, p, width: 700)
            await MainActor.run { livePreview = img }
        }
    }

    private var actionTitle: String {
        mode == .unlock ? L("Remove password") : L("Protect PDF")
    }

    private var ready: Bool {
        switch mode {
        case .unlock: return !password.isEmpty
        case .protect:
            if useLock && (password.count < 4 || password != confirm) { return false }
            return !plan.isEmpty
        }
    }

    // MARK: - Result

    private func result(_ url: URL) -> some View {
        VStack(spacing: HandySpacing.s12) {
            Label(resultNote, systemImage: "checkmark.shield.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let d = try? Data(contentsOf: url) { PDFFactsRows(data: d, source: sourceData, expectLocked: lockedWith != nil).frame(maxWidth: .infinity, alignment: .leading) }
            if let c = check { checkRows(c) }
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

    /// What the saved file really does, read back from it — each line a fact about the file, not a promise.
    private func checkRows(_ c: PDFSecure.Check) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if lockedWith != nil { fact(!c.opensWithoutPassword && c.passwordOpens, "Asks for your password, and your password opens it") }
            if let w = shownMark, !w.isEmpty, !burned { fact(c.watermarkFound, "“\(w)” is on the pages (\(c.pages))") }
            if burned { fact(true, "Watermark burned into all \(c.pages) pages") }
            if blockedPrint { fact(!c.printingAllowed, "Printing is blocked") }
            if blockedCopy { fact(!c.copyingAllowed, "Copying the words is blocked") }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain).accessibilityIdentifier("protect-checks")
    }
    private func fact(_ ok: Bool, _ text: String) -> some View {
        Label(L(text), systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(HandyFont.caption).foregroundStyle(ok ? HandyColor.success : HandyColor.danger)
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
        mode = doc.isLocked ? .unlock : .protect
        preview = doc.isLocked ? nil : doc.page(at: 0)?.thumbnail(of: CGSize(width: 900, height: 1200), for: .mediaBox)
        password = ""; confirm = ""; resultURL = nil; resultPreview = nil; errorText = nil; livePreview = nil; check = nil
        refreshPreview()
    }

    private func loadSample() {
        let img = SampleAssets.document()
        var opts = DocEngine.PDFOptions(); opts.searchable = false
        guard let data = DocEngine.pdf(images: [img], ocr: [nil], options: opts) else { return }
        sourceData = data; preview = img; sourceLocked = false; mode = .protect; fileName = "Sample"
        refreshPreview()
    }

    private func reset() {
        sourceData = nil; preview = nil; sourceLocked = false; mode = .protect; livePreview = nil; check = nil
        password = ""; confirm = ""; resultURL = nil; resultPreview = nil; errorText = nil
    }

    private func run() {
        guard let data = sourceData else { return }
        working = true; errorText = nil
        let m = mode, pw = password, p = current
        let base = fileName.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        let suffix = m == .unlock ? "unlocked" : "protected"
        Task { @MainActor in
            let out: URL? = await Task.detached(priority: .userInitiated) {
                let made = m == .unlock ? PDFSecure.unlock(data, password: pw) : PDFSecure.apply(data, p)
                guard let d = made else { return nil }
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(base.isEmpty ? "Document" : String(base.prefix(50))) (\(suffix)).pdf")
                try? FileManager.default.removeItem(at: url)
                guard (try? d.write(to: url)) != nil else { return nil }
                return url
            }.value
            working = false
            // Check the REAL output by reopening it.
            guard let url = out, let d = try? Data(contentsOf: url), let doc = PDFDocument(data: d) else {
                errorText = m == .unlock ? "That password didn't open it — check it and try again." : "Couldn't save the PDF — try again."
                return
            }
            if m == .unlock {
                guard !doc.isLocked else { errorText = "Still locked — try again."; return }
                resultNote = L("Password removed — this copy opens freely.")
                lockedWith = nil; check = nil
                resultPreview = doc.page(at: 0)?.thumbnail(of: CGSize(width: 900, height: 1200), for: .mediaBox)
            } else {
                let c = PDFSecure.check(d, password: p.openPassword, watermark: p.watermark)
                if !p.openPassword.isEmpty && (c?.opensWithoutPassword ?? true) { errorText = "The lock didn't take — try again."; return }
                check = c
                lockedWith = p.openPassword.isEmpty ? nil : p.openPassword
                shownMark = p.watermark; burned = p.burnIn && p.hasWatermark
                blockedPrint = !p.allowPrinting; blockedCopy = !p.allowCopying
                resultNote = L(plan.isEmpty ? "Protected." : "Protected — checked on the saved file below.")
                resultPreview = livePreview ?? preview
            }
            resultURL = url
            HandyHaptics.success()
        }
    }
}
