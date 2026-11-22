import SwiftUI
import PhotosUI
@preconcurrency import Translation
import AVFoundation

/// Translate — type it, say it, or photograph it, in any pair of Apple's on-device languages. Talk
/// mode runs a two-way conversation: tap your side, speak, the other person reads and hears theirs.
/// Works offline once the languages are downloaded; nothing is sent to us.
struct TranslateView: View {
    @EnvironmentObject var store: StoreManager
    private enum Mode: Int, CaseIterable { case text, talk, photo, travel; var title: String { ["Text", "Talk", "Photo", "Travel"][rawValue] } }
    /// Shown full screen in big type for the other person, the right way up for them.
    @State private var big: BigText?
    struct BigText: Identifiable { let id = UUID(); let text: String }
    @State private var mode: Mode = .text
    @AppStorage("translate.from") private var fromCode = "en"
    @AppStorage("translate.to") private var toCode = "es"
    @State private var input = ""
    @State private var output = ""
    @State private var config: TranslationSession.Configuration?
    @State private var pending: (text: String, from: String, to: String, speak: Bool)?
    @State private var errorText: String?
    @State private var busy = false
    @StateObject private var speech = SpeechStream()
    @StateObject private var speaker = Speaker()
    @State private var talkingSide: Int? = nil      // 0 = "from" speaks, 1 = "to" speaks
    @State private var exchanges: [(side: Int, heard: String, said: String)] = []
    @State private var photoItem: PhotosPickerItem?
    @State private var photoText = ""
    private enum PickerSide: Int, Identifiable { case from, to; var id: Int { rawValue } }
    @State private var showPicker: PickerSide? = nil
    @State private var travelCat = 0
    /// Face to face: the phone flat between two people, each half facing its reader, big type, one mic each.
    @State private var faceToFace = false
    @AppStorage("translate.favs") private var favsRaw = ""
    private var favs: Set<String> { Set(favsRaw.split(separator: "\n").map(String.init)) }

    private var overQuota: Bool { !Usage.hasRoom("translate", limit: Limits.freeTranslatePerDay) }
    // Translating a language into itself is a no-op — block it (and never spend a free turn on it).
    private var sameLang: Bool { fromCode == toCode }
    static let languages: [(code: String, name: String)] = ["en", "es", "fr", "de", "it", "pt", "zh", "ja", "ko", "ar", "hi", "ru", "nl", "pl", "tr", "th", "vi", "id", "uk", "sv"].map { ($0, Locale.current.localizedString(forLanguageCode: $0) ?? $0) }

    var body: some View {
        ToolPage(title: "Translate", subtitle: "Type, talk, or photograph — on-device translation that works offline and stays private.", working: busy) {
            HowTo("translate", [
                "Pick the languages, then type, paste, or tap the mic to speak.",
                "The translation appears below; tap the speaker to hear it.",
                "Swap the languages with the arrows for a two-way chat.",
            ])
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(Mode.allCases, id: \.rawValue) { m in HChip(text: m.title, selected: mode == m) { mode = m; errorText = nil } }
            }
            languageBar
            switch mode {
            case .text: textPanel
            case .talk: talkPanel
            case .photo: photoPanel
            case .travel: travelPanel
            }
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if !store.isPremium { QuotaChip(name: "translate", limit: Limits.freeTranslatePerDay).environmentObject(store) }
            if overQuota { LimitReachedBanner(message: "You've used today's \(Limits.freeTranslatePerDay) free translations.") }
            Text(L("First use of a language pair downloads it (Settings › Translate › Downloaded Languages). After that it's fully offline.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .translationTask(config) { session in
            guard let p = pending else { await MainActor.run { busy = false }; return }
            do {
                let r = try await session.translate(p.text)
                await MainActor.run { deliver(r.targetText, for: p) }
            } catch {
                await MainActor.run { busy = false; errorText = "Couldn't translate — if this is the first time, iOS is downloading the language. Try again in a moment." }
            }
        }
        .onChange(of: speech.running) { was, now in if was, !now, let side = talkingSide { heard(side) } }
        .fullScreenCover(item: $big) { b in BigTextView(text: b.text) }
        .fullScreenCover(isPresented: $faceToFace) {
            FaceToFaceView(meCode: fromCode, themCode: toCode,
                           forMe: exchanges.last(where: { $0.side == 1 })?.said, forThem: exchanges.last(where: { $0.side == 0 })?.said,
                           live: speech.running ? speech.live : "", activeSide: speech.running ? talkingSide : nil, busy: busy,
                           talk: { startTalk($0) }, close: { speech.stop(); faceToFace = false })
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            busy = true
            Task { if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { let t = await AIEngine.recognizeText(img); await MainActor.run { photoText = t; busy = false; if t.isEmpty { errorText = "No text found in that photo." } else { translate(t, from: fromCode, to: toCode, speak: false) } } } else { await MainActor.run { busy = false } } }
        }
        .onAppear { if Launch.sample, input.isEmpty { input = "Where is the nearest pharmacy? My son has a fever." } }
        .onDisappear { speech.stop(); speaker.stop() }
        .sheet(item: $showPicker) { which in
            LangList(selected: which == .from ? $fromCode : $toCode)
        }
    }

    private var languageBar: some View {
        VStack(spacing: HandySpacing.s8) {
            HStack(spacing: HandySpacing.s8) {
                Button { showPicker = .from } label: { Text(name(fromCode)).frame(maxWidth: .infinity) }.secondaryButton()
                Button { swap() } label: { Image(systemName: "arrow.left.arrow.right").frame(width: 36, height: 36) }.compactButton().accessibilityLabel(L("Swap languages"))
                Button { showPicker = .to } label: { Text(name(toCode)).frame(maxWidth: .infinity) }.secondaryButton()
            }
            if sameLang {
                Text(L("Pick two different languages to translate.")).font(HandyFont.caption).foregroundStyle(HandyColor.accent).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: text

    private var textPanel: some View {
        VStack(spacing: HandySpacing.s8) {
            TextEditor(text: $input).frame(minHeight: 110).padding(HandySpacing.s8).scrollContentBackground(.hidden)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                .overlay(alignment: .topLeading) { if input.isEmpty { Text(L("Type or paste…")).foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false) } }
            HStack(spacing: HandySpacing.s8) {
                PasteTextButton { input = $0 }
                Button { translate(input, from: fromCode, to: toCode, speak: false) } label: { HStack { if busy { BusySpinner().tint(.white) }; Label(L("Translate"), systemImage: "character.bubble") }.frame(maxWidth: .infinity) }
                    .primaryButton().disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || busy || overQuota || sameLang)
            }
            if !output.isEmpty { resultCard(output) }
        }
    }

    private func resultCard(_ s: String) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(s).font(.system(size: 20)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: HandySpacing.s8) {
                Button { Copier.copy(s); ClipStore.add(s) } label: { Label(L("Copy"), systemImage: "doc.on.doc") }.compactButton()
                Button { say(s, lang: toCode) } label: { Label(L("Speak"), systemImage: "speaker.wave.2") }.compactButton()
                Button { big = BigText(text: s) } label: { Label(L("Show"), systemImage: "arrow.up.left.and.arrow.down.right") }.compactButton()
                    .accessibilityHint(L("Shows it big for the other person to read"))
                ShareLink(item: s) { Label(L("Share"), systemImage: "square.and.arrow.up") }.compactButton()
                Spacer()
            }
        }.cardStyle(padding: HandySpacing.s12)
    }

    // MARK: talk

    private var talkPanel: some View {
        VStack(spacing: HandySpacing.s12) {
            ScrollView {
                VStack(spacing: HandySpacing.s8) {
                    if exchanges.isEmpty { Text(L("Hold the phone between you. Tap the button for whoever is speaking, talk, then let go of the conversation — the other side appears translated and is spoken aloud.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center).padding() }
                    ForEach(Array(exchanges.enumerated()), id: \.offset) { _, e in
                        VStack(alignment: e.side == 0 ? .leading : .trailing, spacing: 2) {
                            Text(e.heard).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                            Text(e.said).font(.system(size: 20, weight: .medium))
                            Button { big = BigText(text: e.said) } label: { Label(L("Show"), systemImage: "arrow.up.left.and.arrow.down.right").font(HandyFont.micro) }.buttonStyle(.plain).foregroundStyle(HandyColor.accent)
                        }
                        .padding(HandySpacing.s12).frame(maxWidth: .infinity, alignment: e.side == 0 ? .leading : .trailing)
                        .background(e.side == 0 ? HandyColor.surface : HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    if speech.running, !speech.live.isEmpty { Text(speech.live).font(HandyFont.body).foregroundStyle(HandyColor.accent).frame(maxWidth: .infinity, alignment: talkingSide == 0 ? .leading : .trailing) }
                }
            }.frame(height: 260)
            HStack(spacing: HandySpacing.s8) {
                talkButton(side: 0, label: name(fromCode))
                talkButton(side: 1, label: name(toCode))
            }
            Button { faceToFace = true } label: { Label(L("Face to face"), systemImage: "rectangle.split.1x2") .frame(maxWidth: .infinity) }
                .secondaryButton().disabled(sameLang).accessibilityIdentifier("translate-face")
            Text(L("Lay the phone flat between you: each side reads its own half, in big type, and taps its own mic."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
            if !exchanges.isEmpty { HStack { Button(role: .destructive) { exchanges = [] } label: { Label(L("Clear"), systemImage: "trash") }.textButton(); Spacer(); ShareLink(item: exchanges.map { "\($0.heard)\n→ \($0.said)" }.joined(separator: "\n\n")) { Label(L("Share transcript"), systemImage: "square.and.arrow.up") }.textButton() } }
        }
    }

    private func talkButton(side: Int, label: String) -> some View {
        let active = talkingSide == side && speech.running
        return Button { startTalk(side) } label: {
            VStack(spacing: 4) { Image(systemName: active ? "stop.fill" : "mic.fill").font(.system(size: 22)); Text(active ? "Tap when done" : "\(label) speaks").font(HandyFont.caption) }
                .frame(maxWidth: .infinity, minHeight: 72)
                .foregroundStyle(active ? .white : HandyColor.textPrimary)
                .background(active ? HandyColor.danger : HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(active ? Color.clear : HandyColor.border, lineWidth: 1))
        }.buttonStyle(.plain).disabled((overQuota || sameLang) && !active)
    }

    /// One side starts (or, if it's already listening, stops) talking. Shared by the Talk buttons and Face to face.
    private func startTalk(_ side: Int) {
        if talkingSide == side && speech.running { speech.stop(); return }
        guard !sameLang, Usage.hasRoom("translate", limit: Limits.freeTranslatePerDay) else { return }
        speaker.stop(); speech.stop(); talkingSide = side
        speech.locale = SpeechStream.bestLocale(forLanguage: side == 0 ? fromCode : toCode); speech.clear(); speech.start()
    }

    private func heard(_ side: Int) {
        let t = speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        translate(t, from: side == 0 ? fromCode : toCode, to: side == 0 ? toCode : fromCode, speak: true)
    }

    // MARK: photo

    private var photoPanel: some View {
        VStack(spacing: HandySpacing.s8) {
            PhotosPicker(selection: $photoItem, matching: .images) { Label(L("Choose a photo of a sign, menu, or page"), systemImage: "camera.viewfinder").frame(maxWidth: .infinity) }.secondaryButton().disabled(overQuota)
            if busy { ToolProgressBar(label: "Reading…") }
            if !photoText.isEmpty { DisclosureGroup("Original text") { Text(photoText).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).textSelection(.enabled) }.font(HandyFont.caption) }
            if !output.isEmpty && mode == .photo { resultCard(output) }
            Text(L("For live camera translation, use Capture — tap a line there and choose Translate.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    // MARK: plumbing

    private func translate(_ text: String, from: String, to: String, speak: Bool) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !t.isEmpty else { return }
        guard from != to else { errorText = "Pick two different languages — the From and To are the same."; return }
        if mode != .talk { guard Usage.hasRoom("translate", limit: Limits.freeTranslatePerDay) else { return } }
        busy = true; errorText = nil
        pending = (t, from, to, speak)
        let newConfig = TranslationSession.Configuration(source: Locale.Language(identifier: from), target: Locale.Language(identifier: to))
        if config?.source == newConfig.source, config?.target == newConfig.target { config?.invalidate() } else { config = newConfig }
    }

    private func deliver(_ result: String, for p: (text: String, from: String, to: String, speak: Bool)) {
        busy = false; pending = nil
        if mode == .talk, let side = talkingSide { exchanges.append((side, p.text, result)); talkingSide = nil; _ = Usage.use("translate", limit: Limits.freeTranslatePerDay) } else { output = result; _ = Usage.use("translate", limit: Limits.freeTranslatePerDay) }
        if p.speak { say(result, lang: p.to) }
        HandyHaptics.success()
    }

    private func say(_ s: String, lang: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers]); try? AVAudioSession.sharedInstance().setActive(true)
        let u = AVSpeechUtterance(string: s); u.voice = Reader.bestVoice(forLanguage: lang); u.rate = speaker.rate
        speaker.speak(u)
    }
    private func swap() { let f = fromCode; fromCode = toCode; toCode = f; if !output.isEmpty { input = output; output = "" } }
    private func name(_ code: String) -> String { Locale.current.localizedString(forLanguageCode: code) ?? code }

    // MARK: travel phrasebook

    private var currentPhrases: [String] {
        travelCat == -1 ? Phrasebook.categories.flatMap(\.phrases).filter { favs.contains($0) } : Phrasebook.categories[travelCat].phrases
    }
    private func toggleFav(_ p: String) {
        var s = favs; if s.contains(p) { s.remove(p) } else { s.insert(p) }
        favsRaw = s.sorted().joined(separator: "\n"); HandyHaptics.light()
    }

    private var travelPanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(toCode == "en" ? "Pick a destination language above, then tap a phrase to hear it."
                                : "Tap any phrase to see and hear it in \(name(toCode)). Star the ones you'll need — the phrasebook is fully offline.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HandyFlow(spacing: HandySpacing.s8) {
                HChip(text: "★ Saved", selected: travelCat == -1) { travelCat = -1 }
                ForEach(Array(Phrasebook.categories.enumerated()), id: \.offset) { i, c in HChip(text: c.name, selected: travelCat == i) { travelCat = i } }
            }
            if !output.isEmpty { resultCard(output) }
            if currentPhrases.isEmpty {
                Text(travelCat == -1 ? "No saved phrases yet — tap the star on the ones you want to keep handy." : "")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            VStack(spacing: 0) {
                ForEach(currentPhrases, id: \.self) { phrase in
                    HStack(spacing: HandySpacing.s8) {
                        Text(phrase).font(HandyFont.body).frame(maxWidth: .infinity, alignment: .leading)
                        Button { toggleFav(phrase) } label: { Image(systemName: favs.contains(phrase) ? "star.fill" : "star").accessibilityLabel(L("Favourite")) }
                            .buttonStyle(.plain).foregroundStyle(HandyColor.accent).accessibilityLabel(favs.contains(phrase) ? "Unstar" : "Star")
                        Button { translate(phrase, from: "en", to: toCode, speak: true) } label: { Image(systemName: "character.bubble.fill").accessibilityLabel(L("Speak")) }
                            .buttonStyle(.plain).foregroundStyle(HandyColor.accent).disabled(toCode == "en" || overQuota)
                    }.padding(.vertical, 10)
                    if phrase != currentPhrases.last { Divider() }
                }
            }
        }
    }
}

/// A compact, travel-tested phrasebook (source phrases in English; translated on tap into the chosen
/// language). The point of a travel translator over a generic one: the thing you need is already here.
private struct Phrasebook {
    static let categories: [(name: String, icon: String, phrases: [String])] = [
        ("Essentials", "hand.wave", ["Hello", "Thank you", "Yes", "No", "Please", "Excuse me", "Do you speak English?", "I don't understand", "Can you help me?"]),
        ("Directions", "map", ["Where is the bathroom?", "How do I get to the train station?", "Is it far?", "Can you show me on the map?", "Go left", "Go right", "Straight ahead"]),
        ("Dining", "fork.knife", ["A table for two, please", "The menu, please", "I'm allergic to nuts", "Water, please", "The check, please", "Is this vegetarian?", "It was delicious"]),
        ("Shopping", "bag", ["How much is this?", "That's too expensive", "Do you take cards?", "I'm just looking", "Can I have a receipt?", "Do you have a smaller size?"]),
        ("Emergency", "cross.case", ["Help!", "Call the police", "I need a doctor", "Where is the hospital?", "I lost my passport", "It's an emergency", "I don't feel well"]),
        ("Getting around", "tram", ["One ticket, please", "What time does it leave?", "Does this go to the airport?", "Please take me to this address", "Stop here, please", "How much is the fare?"]),
    ]
}

private struct LangList: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(TranslateView.languages, id: \.code) { l in
                Button { selected = l.code; dismiss() } label: { HStack { Text(l.name); Spacer(); if l.code == selected { Image(systemName: "checkmark").foregroundStyle(HandyColor.accent) } } }.foregroundStyle(HandyColor.textPrimary)
            }
            .navigationTitle(L("Language")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { dismiss() } } }
        }
    }
}


/// A translation shown full screen in big type, for the person across the table; one tap turns it upside down so it
/// faces them without passing the phone over.
struct BigTextView: View {
    let text: String
    @State private var flipped = true
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Text(text)
                .font(.system(size: 64, weight: .bold)).minimumScaleFactor(0.2).foregroundStyle(.black)
                .multilineTextAlignment(.center).padding(24)
                .rotationEffect(.degrees(flipped ? 180 : 0))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("translate-big")
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Button { withAnimation { flipped.toggle() } } label: { Label(L(flipped ? "Face me" : "Face them"), systemImage: "arrow.triangle.2.circlepath") }
                        .buttonStyle(.borderedProminent).tint(.black)
                    Button(L("Done")) { dismiss() }.buttonStyle(.bordered).tint(.black)
                }.padding(.bottom, 24)
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}


/// Face to face: the phone lies flat between two people. The top half is turned to face the other person and shows
/// what you said, in their language, in big type; the bottom half shows their reply in yours. Each half has its own
/// mic, labelled in its own language, so neither of you has to read upside down or pass the phone across.
struct FaceToFaceView: View {
    let meCode: String
    let themCode: String
    let forMe: String?
    let forThem: String?
    let live: String
    let activeSide: Int?          // 0 = me speaking, 1 = them
    let busy: Bool
    let talk: (Int) -> Void
    let close: () -> Void

    private func native(_ code: String) -> String {
        Locale(identifier: code).localizedString(forLanguageCode: code)?.capitalized(with: Locale(identifier: code)) ?? code
    }

    var body: some View {
        VStack(spacing: 0) {
            half(side: 1, text: forThem, lang: themCode)
                .rotationEffect(.degrees(180))
                .background(HandyColor.accentSoft)
            Rectangle().fill(HandyColor.border).frame(height: 1)
            half(side: 0, text: forMe, lang: meCode)
                .background(HandyColor.bg)
        }
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .topLeading) {
            Button(L("Done")) { close() }.buttonStyle(.bordered).padding(.leading, 16).padding(.top, 4)
                .accessibilityIdentifier("face-done")
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    /// One person's half: the latest line for them (or what they're saying right now), and their mic.
    private func half(side: Int, text: String?, lang: String) -> some View {
        let speaking = activeSide == side
        let shown = speaking && !live.isEmpty ? live : (text ?? "")
        return VStack(spacing: 14) {
            Spacer(minLength: 8)
            Text(shown.isEmpty ? "…" : shown)
                .font(.system(size: 34, weight: .bold)).minimumScaleFactor(0.3)
                .foregroundStyle(speaking ? HandyColor.accent : HandyColor.textPrimary)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 20)
            Button { talk(side) } label: {
                Label(speaking ? "■" : native(lang), systemImage: speaking ? "stop.fill" : "mic.fill")
                    .font(.system(size: 20, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(speaking ? .white : HandyColor.onAccent)
                    .background(speaking ? HandyColor.danger : HandyColor.accent, in: Capsule())
            }
            .buttonStyle(.plain).padding(.horizontal, 24).padding(.bottom, 18)
            .disabled(busy && !speaking)
            .accessibilityLabel(speaking ? L("Stop") : "\(L("Speak")) \(native(lang))")
            .accessibilityIdentifier("face-mic-\(side)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
