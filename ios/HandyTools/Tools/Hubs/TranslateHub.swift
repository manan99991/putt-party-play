import SwiftUI
import PhotosUI
@preconcurrency import Translation
import AVFoundation

/// Translate hub — From / To + swap, then Text (quick phrases, Speak / Copy / Share), Camera (photo →
/// Vision text blocks → translated lines drawn over the original + list) and Conversation (two mics,
/// each side heard in its own language and spoken back in the other). Apple's Translation framework,
/// on the phone; the language-pack state sits inline and never blocks — Speak and Copy always work.
struct TranslateHub: View {
    @EnvironmentObject var store: StoreManager
    @AppStorage("translate.from") private var fromCode = "en"
    @AppStorage("translate.to") private var toCode = "es"
    @State private var tab = 0   // Text / Camera / Conversation
    // text
    @State private var input = ""
    @State private var output = ""
    @State private var outputFailed: String?
    // translation plumbing
    @State private var config: TranslationSession.Configuration?
    @State private var job: Job?
    @State private var busy = false
    @State private var pack: TranslateEngine.PackState = .checking
    @State private var errorText: String?
    // camera
    @State private var photo: UIImage?
    @State private var blocks: [TextBlock] = []
    @State private var lines: [String] = []
    @State private var shareData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var reading = false
    // conversation
    @StateObject private var speech = SpeechStream()
    @StateObject private var speaker = Speaker()
    @State private var side: Int? = nil
    @State private var log: [Exchange] = []
    private enum PickerSide: Int, Identifiable { case from, to; var id: Int { rawValue } }
    @State private var showPicker: PickerSide? = nil

    private struct Job {
        enum Kind { case text, camera, talk(Int), prepare }
        let kind: Kind; let texts: [String]; let from: String; let to: String
    }
    private struct Exchange: Identifiable { let id = UUID(); let side: Int; let heard: String; let said: String }

    private var overQuota: Bool { !Usage.hasRoom("translate", limit: Limits.freeTranslatePerDay) }
    private var hasCamera: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        PowerToolPage(id: "translate", tabs: ["Text", "Camera", "Conversation"], selected: $tab) {
            languageBar
            packLine
            Group {
                switch tab {
                case 1: cameraPane
                case 2: talkPane
                default: textPane
                }
            }
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if !store.isPremium { QuotaChip(name: "translate", limit: Limits.freeTranslatePerDay).environmentObject(store) }
            if overQuota { LimitReachedBanner(message: "You've used today's \(Limits.freeTranslatePerDay) free translations.") }
            HubNote("Offline once a language is downloaded (Settings › Translate › Downloaded Languages). Nothing leaves your phone.")
        }
        .translationTask(config) { session in
            guard let j = job else { await MainActor.run { busy = false }; return }
            do {
                if case .prepare = j.kind {
                    try await session.prepareTranslation()
                    await MainActor.run { busy = false; job = nil; errorText = nil }
                    let state = await TranslateEngine.packState(from: j.from, to: j.to)
                    await MainActor.run { pack = state }
                    return
                }
                let reqs = j.texts.enumerated().map { TranslationSession.Request(sourceText: $0.element, clientIdentifier: String($0.offset)) }
                let resps = try await session.translations(from: reqs)
                var out = Array(repeating: "", count: j.texts.count)
                for r in resps { if let id = r.clientIdentifier, let i = Int(id), out.indices.contains(i) { out[i] = r.targetText } }
                await MainActor.run { deliver(out, for: j) }
            } catch {
                await MainActor.run { fail(j) }
            }
        }
        .task(id: fromCode + ">" + toCode) {
            pack = .checking
            let state = await TranslateEngine.packState(from: fromCode, to: toCode)
            pack = state
        }
        .onChange(of: speech.running) { was, now in if was, !now, let s = side { heard(s) } }
        .onChange(of: tab) { _, _ in if speech.running { speech.stop() }; errorText = nil }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { analyse(img) }
                else { errorText = "Couldn't open that photo." }
                photoItem = nil
            }
        }
        .onDisappear { speech.stop(); speaker.stop() }
        .sheet(item: $showPicker) { which in TranslateLangList(selected: which == .from ? $fromCode : $toCode) }
        .fullScreenCover(isPresented: $showCamera) { TranslateCamera { img in showCamera = false; if let img { analyse(img) } }.ignoresSafeArea() }
    }

    // MARK: - Languages

    private var languageBar: some View {
        HStack(spacing: HandySpacing.s8) {
            Button { showPicker = .from } label: { Text(TranslateEngine.name(fromCode)).lineLimit(1).frame(maxWidth: .infinity) }.secondaryButton().accessibilityLabel("From language")
            Button { swap() } label: { Image(systemName: "arrow.left.arrow.right").frame(width: 36, height: 36) }.compactButton().accessibilityLabel("Swap languages")
            Button { showPicker = .to } label: { Text(TranslateEngine.name(toCode)).lineLimit(1).frame(maxWidth: .infinity) }.secondaryButton().accessibilityLabel("To language")
        }
    }

    private var packLine: some View {
        FlowLayout(spacing: HandySpacing.s8) {
            switch pack {
            case .checking: HubPill("Checking language packs…")
            case .installed: HubPill("Offline · \(TranslateEngine.name(fromCode)) → \(TranslateEngine.name(toCode)) ready", tone: .ok)
            case .supported:
                HubPill("Language pack not downloaded yet", tone: .native)
                Button { prepare() } label: { Label(busy ? "Downloading…" : "Download", systemImage: "arrow.down.circle") }.textButton().disabled(busy)
            case .unsupported: HubPill("This pair isn't offered by Apple Translation yet", tone: .native)
            }
        }
    }

    private func swap() {
        let f = fromCode; fromCode = toCode; toCode = f
        if !output.isEmpty { input = output; output = ""; outputFailed = nil }
    }

    // MARK: - Text

    private var textPane: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            TextEditor(text: $input).frame(minHeight: 100).padding(HandySpacing.s8).scrollContentBackground(.hidden)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                .overlay(alignment: .topLeading) { if input.isEmpty { Text("Type or paste…").foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false) } }
            FlowLayout(spacing: 6) {
                ForEach(TranslateEngine.phrases) { p in
                    HubChip(p.label, selected: input == p.text) { input = p.text; translateText() }
                }
            }
            HStack(spacing: HandySpacing.s8) {
                Button("Paste") { if let s = UIPasteboard.general.string { input = s } }.compactButton()
                Button { translateText() } label: { HStack { if busy { ProgressView().tint(.white) }; Label("Translate", systemImage: "character.bubble") }.frame(maxWidth: .infinity) }
                    .primaryButton().disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || busy || overQuota)
            }
            if !output.isEmpty || outputFailed != nil { resultCard }
        }
    }

    private var resultCard: some View {
        let text = output.isEmpty ? input : output
        let lang = output.isEmpty ? fromCode : toCode
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            if let outputFailed {
                HubPill("Translation unavailable", tone: .native)
                Text(outputFailed).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            } else {
                Text(output).font(.system(size: 20)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            FlowLayout(spacing: HandySpacing.s8) {
                Button { say(text, lang: lang) } label: { Label("Speak", systemImage: "speaker.wave.2") }.compactButton()
                Button { UIPasteboard.general.string = text; ClipStore.add(text); HandyHaptics.success() } label: { Label("Copy", systemImage: "doc.on.doc") }.compactButton()
                ShareLink(item: text) { Label("Share", systemImage: "square.and.arrow.up") }.compactButton()
            }
        }.cardStyle(padding: HandySpacing.s12)
    }

    private func translateText() {
        output = ""; outputFailed = nil
        translate([input], kind: .text, from: fromCode, to: toCode)
    }

    // MARK: - Camera

    private var cameraPane: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HubPreviewBox(minHeight: 240) {
                if let photo {
                    PhotoOverlay(image: photo, blocks: blocks, lines: lines)
                } else {
                    VStack(spacing: HandySpacing.s8) {
                        Image(systemName: "camera.viewfinder").font(.system(size: 30)).foregroundStyle(HandyColor.accent)
                        Text("Point at a menu, sign or label.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                }
            }
            if reading || (busy && tab == 1) { HStack(spacing: HandySpacing.s8) { ProgressView(); Text(reading ? "Reading the text…" : "Translating \(blocks.count) lines…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }
            HStack(spacing: HandySpacing.s8) {
                Button { if hasCamera { showCamera = true } else { errorText = "No camera on this device — pick a photo from your library instead." } } label: { Label("Take photo", systemImage: "camera").frame(maxWidth: .infinity) }.primaryButton().disabled(overQuota || reading)
                PhotosPicker(selection: $photoItem, matching: .images) { Label("Library", systemImage: "photo") }.secondaryButton().disabled(overQuota || reading)
            }
            if !hasCamera { HubPill("Camera runs on a real phone — Library works everywhere", tone: .native) }
            if !blocks.isEmpty {
                HubSection("Lines")
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    ForEach(blocks.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(blocks[i].text).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                            Text(i < lines.count && !lines[i].isEmpty ? lines[i] : "—").font(HandyFont.body)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.cardStyle(padding: HandySpacing.s12)
                FlowLayout(spacing: HandySpacing.s8) {
                    Button { UIPasteboard.general.string = cameraText; ClipStore.add(cameraText); HandyHaptics.success() } label: { Label("Copy all", systemImage: "doc.on.doc") }.compactButton()
                    ShareLink(item: cameraText) { Label("Share text", systemImage: "square.and.arrow.up") }.compactButton()
                    if let shareData { ShareLink(item: JPEGFile(data: shareData), preview: SharePreview("Translated photo")) { Label("Share image", systemImage: "photo.on.rectangle") }.compactButton() }
                }
            }
            HubNote("Text is recognised and replaced in place on the phone.")
        }
    }

    /// Translated lines, falling back to the originals for any line that couldn't be translated.
    private var cameraText: String {
        blocks.enumerated().map { i, b in i < lines.count && !lines[i].isEmpty ? lines[i] : b.text }.joined(separator: "\n")
    }

    private func analyse(_ img: UIImage) {
        reading = true; errorText = nil; photo = img; blocks = []; lines = []; shareData = nil
        Task { @MainActor in
            let found = await Task.detached(priority: .userInitiated) { TranslateEngine.blocks(img) }.value
            reading = false
            blocks = found
            if found.isEmpty { errorText = "No text found in that photo. Try closer, with more light."; return }
            translate(found.map(\.text), kind: .camera, from: fromCode, to: toCode)
        }
    }

    // MARK: - Conversation

    private var talkPane: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HubPreviewBox(minHeight: 140) {
                VStack(alignment: .leading, spacing: 10) {
                    if log.isEmpty && !speech.running { Text("Tap a mic, speak, and the other side hears it in their language.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                    ForEach(log) { e in
                        VStack(alignment: e.side == 0 ? .leading : .trailing, spacing: 2) {
                            Text(e.side == 0 ? TranslateEngine.name(fromCode) : TranslateEngine.name(toCode)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                            Text(e.heard).font(HandyFont.body)
                            Text(e.said.isEmpty ? "(couldn't translate — see the note below)" : e.said).font(HandyFont.body).foregroundStyle(HandyColor.accent)
                        }.frame(maxWidth: .infinity, alignment: e.side == 0 ? .leading : .trailing)
                    }
                    if speech.running { Text(speech.live.isEmpty ? "Listening…" : speech.live).font(HandyFont.body).foregroundStyle(HandyColor.accent) }
                    if busy && tab == 2 { HStack(spacing: HandySpacing.s8) { ProgressView(); Text("Translating…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: HandySpacing.s8) {
                micButton(0, label: TranslateEngine.name(fromCode))
                micButton(1, label: TranslateEngine.name(toCode))
            }
            if let e = speech.errorText { LimitNote(e) }
            FlowLayout(spacing: HandySpacing.s8) {
                Button { UIPasteboard.general.string = logText; HandyHaptics.success() } label: { Label("Copy", systemImage: "doc.on.doc") }.compactButton().disabled(log.isEmpty)
                ShareLink(item: logText) { Label("Share", systemImage: "square.and.arrow.up") }.compactButton().disabled(log.isEmpty)
                Button(role: .destructive) { log = [] } label: { Label("Clear", systemImage: "trash") }.textButton().disabled(log.isEmpty)
            }
            HubNote("Needs the mic and speech recognition. Each side is recognised on the phone and spoken back in the other language.")
        }
    }

    private var logText: String { log.map { "\($0.heard)\n→ \($0.said)" }.joined(separator: "\n\n") }

    private func micButton(_ s: Int, label: String) -> some View {
        let active = side == s && speech.running
        return Button {
            if active { speech.stop() }
            else {
                guard !overQuota else { return }
                speaker.stop(); speech.stop(); errorText = nil
                side = s
                speech.locale = SpeechStream.bestLocale(forLanguage: s == 0 ? fromCode : toCode)
                speech.clear(); speech.start()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: active ? "stop.fill" : "mic.fill").font(.system(size: 24))
                Text(active ? "Tap when done" : label).font(HandyFont.caption).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .foregroundStyle(active ? .white : HandyColor.textPrimary)
            .background(active ? HandyColor.danger : HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(active ? Color.clear : HandyColor.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled((overQuota || busy) && !active)
        .accessibilityLabel(active ? "Stop listening" : "\(label) speaks")
    }

    private func heard(_ s: Int) {
        let t = speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { side = nil; return }
        translate([t], kind: .talk(s), from: s == 0 ? fromCode : toCode, to: s == 0 ? toCode : fromCode)
    }

    // MARK: - Translation plumbing

    private func translate(_ texts: [String], kind: Job.Kind, from: String, to: String) {
        let clean = texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard clean.contains(where: { !$0.isEmpty }) else { return }
        guard Usage.hasRoom("translate", limit: Limits.freeTranslatePerDay) else { return }
        busy = true; errorText = nil
        job = Job(kind: kind, texts: clean, from: from, to: to)
        start(from: from, to: to)
    }

    private func prepare() {
        busy = true; errorText = nil
        job = Job(kind: .prepare, texts: [], from: fromCode, to: toCode)
        start(from: fromCode, to: toCode)
    }

    private func start(from: String, to: String) {
        let newConfig = TranslationSession.Configuration(source: Locale.Language(identifier: from), target: Locale.Language(identifier: to))
        if config?.source == newConfig.source, config?.target == newConfig.target { config?.invalidate() } else { config = newConfig }
    }

    private func deliver(_ out: [String], for j: Job) {
        busy = false; job = nil
        switch j.kind {
        case .text:
            output = out.first ?? ""; outputFailed = output.isEmpty ? "Nothing came back for that one." : nil
        case .camera:
            lines = out
            if let photo { let b = blocks; Task { @MainActor in shareData = await Task.detached(priority: .userInitiated) { TranslateEngine.render(photo, blocks: b, translations: out) }.value } }
        case .talk(let s):
            let said = out.first ?? ""
            log.append(Exchange(side: s, heard: j.texts.first ?? "", said: said)); side = nil
            if !said.isEmpty { say(said, lang: j.to) }
        case .prepare: break
        }
        if pack != .installed { pack = .installed }
        _ = Usage.use("translate", limit: Limits.freeTranslatePerDay)   // counted only after a result
        HandyHaptics.success()
    }

    private func fail(_ j: Job) {
        busy = false; job = nil
        let msg: String
        switch pack {
        case .unsupported: msg = "Apple Translation doesn't offer \(TranslateEngine.name(j.from)) → \(TranslateEngine.name(j.to)) on this phone yet. Speak and Copy still work on your text."
        case .supported: msg = "The \(TranslateEngine.name(j.to)) language pack isn't downloaded yet — tap Download above (or allow it when iOS asks), then try again."
        default: msg = "Couldn't translate — if this is the first time, iOS is downloading the language. Try again in a moment."
        }
        switch j.kind {
        case .text: outputFailed = msg
        case .camera: lines = []; errorText = msg
        case .talk(let s): log.append(Exchange(side: s, heard: j.texts.first ?? "", said: "")); side = nil; errorText = msg
        case .prepare: errorText = "The download didn't finish — you can try again anytime, or let iOS download it on the first translation."
        }
    }

    private func say(_ s: String, lang: String) {
        guard !s.isEmpty else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers]); try? AVAudioSession.sharedInstance().setActive(true)
        let u = AVSpeechUtterance(string: s); u.voice = Reader.bestVoice(forLanguage: lang); u.rate = speaker.rate
        speaker.speak(u)
    }
}

// MARK: - Pieces

/// The photo with each translated line drawn over its block (dark rounded box, white fitted text).
private struct PhotoOverlay: View {
    let image: UIImage
    let blocks: [TextBlock]
    let lines: [String]
    var body: some View {
        GeometryReader { geo in
            let fit = fitted(image.size, in: geo.size)
            ZStack(alignment: .topLeading) {
                Image(uiImage: image).resizable().scaledToFit().frame(width: geo.size.width, height: geo.size.height)
                ForEach(blocks.indices, id: \.self) { i in
                    if i < lines.count, !lines[i].isEmpty {
                        let b = blocks[i].rect
                        let r = CGRect(x: fit.minX + b.minX * fit.width, y: fit.minY + b.minY * fit.height, width: b.width * fit.width, height: b.height * fit.height)
                        Text(lines[i])
                            .font(.system(size: max(8, r.height * 0.7), weight: .semibold)).foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.3)
                            .padding(.horizontal, 3)
                            .frame(width: max(12, r.width + 6), height: max(12, r.height + 4))
                            .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .position(x: r.midX, y: r.midY)
                    }
                }
            }
        }
        .aspectRatio(image.size.width / max(1, image.size.height), contentMode: .fit)
        .frame(maxHeight: 420)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel("Photo with translated text")
    }
    private func fitted(_ img: CGSize, in box: CGSize) -> CGRect {
        guard img.width > 0, img.height > 0 else { return CGRect(origin: .zero, size: box) }
        let s = min(box.width / img.width, box.height / img.height)
        let w = img.width * s, h = img.height * s
        return CGRect(x: (box.width - w) / 2, y: (box.height - h) / 2, width: w, height: h)
    }
}

/// Camera that hands back the photo (never saved to the camera roll).
private struct TranslateCamera: UIViewControllerRepresentable {
    let done: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) { p.sourceType = .camera }
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(done: done) }
    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(done: @escaping (UIImage?) -> Void) { self.done = done }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done((info[.originalImage] as? UIImage)?.normalizedUp())
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}

/// Pick a language from Apple's supported set (same list the legacy Translate tool offers).
private struct TranslateLangList: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(TranslateView.languages, id: \.code) { l in
                Button { selected = l.code; dismiss() } label: { HStack { Text(l.name); Spacer(); if l.code == selected { Image(systemName: "checkmark").foregroundStyle(HandyColor.accent) } } }.foregroundStyle(HandyColor.textPrimary)
            }
            .navigationTitle("Language").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}
