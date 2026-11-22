import SwiftUI
import PhotosUI
@preconcurrency import Translation

/// Menu Assistant — photograph a menu abroad and get it back as a clean list: each dish with its price
/// (converted to your money at a rate you set once), what's in it (meat, pork, fish, shellfish, dairy,
/// egg, nuts, gluten, spicy — read from the menu's own words in six languages), whether it fits your
/// diet, the dish names translated offline, and a few picks. On device; it can only know what the menu says.
struct MenuView: View {
    @State private var pick: PhotosPickerItem?
    @State private var items: [MenuReader.Item] = []
    @State private var menuCurrency: String?
    @State private var reading = false
    @State private var errorText: String?
    @AppStorage("menu.diets") private var dietsRaw = ""
    @State private var onlyFits = false
    @State private var rateText = ""
    @State private var translated: [UUID: String] = [:]
    @State private var translateConfig: TranslationSession.Configuration?
    @State private var translating = false
    @State private var picks: [String] = []
    @State private var picking = false
    @State private var sectionNames: [String: String] = [:]

    private var diets: Set<MenuReader.Diet> { Set(dietsRaw.split(separator: ",").compactMap { MenuReader.Diet(rawValue: String($0)) }) }
    private var homeCurrency: String { Locale.current.currency?.identifier ?? "USD" }
    private var rate: Double? { Double(rateText.replacingOccurrences(of: ",", with: ".")).flatMap { $0 > 0 ? $0 : nil } }

    var body: some View {
        ToolPage(title: "Menu Assistant", subtitle: "Snap a menu — dishes, prices in your money, what's in each, what fits your diet.",
                 working: reading || translating || picking) {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                dietChips
                if items.isEmpty { pickCard } else { results }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .onChange(of: pick) { _, item in load(item) }
        .handoffPhotos("menu") { imgs in if let img = imgs.first { read(img) } }
        .translationTask(translateConfig) { session in
            let secs = items.map(\.section).reduce(into: [String]()) { if !$1.isEmpty, !$0.contains($1) { $0.append($1) } }
            let reqs = items.map { TranslationSession.Request(sourceText: $0.detail.isEmpty ? $0.name : "\($0.name) — \($0.detail)",
                                                               clientIdentifier: $0.id.uuidString) }
                + secs.enumerated().map { TranslationSession.Request(sourceText: $1, clientIdentifier: "sec-\($0)") }
            do {
                let res = try await session.translations(from: reqs)
                var map: [UUID: String] = [:]
                var names: [String: String] = [:]
                for r in res {
                    if let id = r.clientIdentifier.flatMap(UUID.init(uuidString:)) { map[id] = r.targetText }
                    else if let c = r.clientIdentifier, c.hasPrefix("sec-"), let i = Int(c.dropFirst(4)), i < secs.count { names[secs[i]] = r.targetText }
                }
                await MainActor.run {
                    translated = map; sectionNames = names; translating = false
                    // The translation names what's in a dish too ("…with shredded pork") — add what it says.
                    for i in items.indices where !items[i].note { if let t = map[items[i].id] { items[i].flags.formUnion(MenuReader.flags(t)) } }
                }
            } catch {
                await MainActor.run { translating = false; errorText = "Couldn't translate — the first time, iOS downloads the language. Try again in a moment." }
            }
        }
    }

    private var dietChips: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s4) {
            Text(L("Your diet")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(MenuReader.Diet.allCases) { d in
                    HChip(text: d.title, selected: diets.contains(d)) {
                        var set = diets
                        if set.contains(d) { set.remove(d) } else { set.insert(d) }
                        dietsRaw = set.map(\.rawValue).sorted().joined(separator: ",")
                        picks = []
                    }
                }
            }
        }
    }

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "menucard").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Take or choose a photo of the menu. Hold it flat and fill the frame."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            SmartPhotoButton(kind: .menu, picked: { if let i = $0.first { read(i) } }) {
                Label(L("Choose menu photo"), systemImage: "photo").frame(maxWidth: .infinity)
            }.primaryButton()
            if reading { ToolProgressBar(label: "Reading the menu…", showsTime: false) }
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .cardStyle(padding: HandySpacing.s16)
        .frame(maxWidth: .infinity)
    }

    private var shown: [MenuReader.Item] {
        onlyFits && !diets.isEmpty ? items.filter { $0.note || MenuReader.verdict($0, diets: diets) == .fits } : items
    }
    private var dishCount: Int { items.filter { !$0.note }.count }

    private var results: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if let cur = menuCurrency, cur != homeCurrency {
                HStack(spacing: HandySpacing.s8) {
                    Text("1 \(cur) =").font(HandyFont.caption)
                    TextField("0.00", text: $rateText).keyboardType(.decimalPad).textFieldStyle(.handy).frame(width: 90)
                    Text(homeCurrency).font(HandyFont.caption)
                    Spacer()
                }
                Text(L("Type today's rate once (from your bank or a search) — prices then show in your money too."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            HStack(spacing: HandySpacing.s8) {
                Button { startTranslation() } label: { Label(translated.isEmpty ? L("Translate dishes") : L("Translate again"), systemImage: "character.bubble") }
                    .compactButton().disabled(translating)
                Button { suggest() } label: { Label(L("What should I order?"), systemImage: "sparkles") }
                    .compactButton().disabled(picking)
                Spacer()
            }
            if !picks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label(L("Picks for you"), systemImage: "star.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.accent)
                    ForEach(picks, id: \.self) { Text("• \($0)").font(HandyFont.body) }
                }.cardStyle(padding: HandySpacing.s12)
            }
            if !diets.isEmpty { Toggle(L("Only show what fits my diet"), isOn: $onlyFits).font(HandyFont.caption).tint(HandyColor.accent) }
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            Text("\(dishCount) \(L(dishCount == 1 ? "dish" : "dishes"))\(menuCurrency.map { " · \(L("prices in")) \($0)" } ?? "")")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            let sections = shown.reduce(into: [String]()) { if !$0.contains($1.section) { $0.append($1.section) } }
            ForEach(sections, id: \.self) { sec in
                if !sec.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(sectionTitle(sec)).font(HandyFont.bodyStrong)
                        if sectionTitle(sec) != sec { Text(sec).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                    }.padding(.top, 4)
                }
                ForEach(shown.filter { $0.section == sec && $0.note }) { n in
                    Label(translated[n.id] ?? MenuReader.gloss(n.name.replacingOccurrences(of: "、", with: " ")).map { "\($0) — \(n.name)" } ?? n.name, systemImage: "info.circle").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                ForEach(shown.filter { $0.section == sec && !$0.note }) { item in row(item) }
            }
            Text(L("Read from the menu's own words — dishes can hide ingredients. With an allergy, always ask the staff."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            SmartPhotoButton(kind: .menu, picked: { if let i = $0.first { read(i) } }) { Label(L("Another menu"), systemImage: "photo") }
                .textButton().font(HandyFont.caption).frame(maxWidth: .infinity)
        }
        .onChange(of: rateText) { _, v in
            if let c = menuCurrency { UserDefaults.standard.set(v, forKey: "menu.rate.\(c).\(homeCurrency)") }
        }
    }

    /// A section heading in the reader's language when the menu's was translated.
    private func sectionTitle(_ sec: String) -> String {
        sectionNames[sec] ?? (MenuReader.needsTranslation([sec]) ? sec.components(separatedBy: " · ").map { MenuReader.gloss($0) ?? $0 }.joined(separator: " · ") : sec)
    }

    private func row(_ item: MenuReader.Item) -> some View {
        let clash = MenuReader.conflicts(item, diets: diets)
        let verdict = MenuReader.verdict(item, diets: diets)
        // Apple's translation when it's done; until then (or offline, or with the language not downloaded) a plain
        // English name built from the menu words, so the person always knows what they're looking at.
        let english = translated[item.id] ?? (MenuReader.needsTranslation([item.name]) ? MenuReader.gloss(item.name) : nil)
        let foreign = english != nil && MenuReader.needsTranslation([item.name])
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    // A menu in a script the person can't read leads with the translation; the original stays below to point at.
                    Text(foreign ? (english ?? item.name) : item.name).font(HandyFont.bodyStrong)
                    if foreign { Text(item.name).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    if !item.priceText.isEmpty { Text(item.priceText).font(HandyFont.body).monospacedDigit() }
                    if let p = item.price, let r = rate {
                        Text((p * r).formatted(.currency(code: homeCurrency))).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                }
            }
            if !foreign, let t = translated[item.id] { Text(t).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
            if !item.detail.isEmpty { Text(item.detail).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            HStack(spacing: 6) {
                if !diets.isEmpty {
                    switch verdict {
                    case .fits:
                        Label(L("Fits you"), systemImage: "checkmark.circle.fill").font(HandyFont.micro).foregroundStyle(HandyColor.success)
                    case .clash(let c):
                        Label("\(L("Has")) \(c.map { L($0.title).lowercased() }.joined(separator: ", "))", systemImage: "xmark.circle.fill")
                            .font(HandyFont.micro).foregroundStyle(HandyColor.danger)
                    case .ask:
                        Label(L("Ask first"), systemImage: "questionmark.circle.fill").font(HandyFont.micro).foregroundStyle(HandyColor.amber)
                    }
                }
                ForEach(MenuReader.Flag.allCases.filter { item.flags.contains($0) && !clash.contains($0) }, id: \.self) { f in
                    Text(L(f.title)).font(HandyFont.micro)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(HandyColor.surface, in: Capsule())
                }
            }
            if !diets.isEmpty, case .ask(let why) = verdict {
                Text(L(why)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            } else if let why = item.caution {
                Text(L(why)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private func load(_ item: PhotosPickerItem?) {
        guard let item else { return }
        reading = true; errorText = nil; items = []; translated = [:]; picks = []
        Task {
            guard let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) else {
                await MainActor.run { reading = false; errorText = "Couldn't open that photo." }; return
            }
            await MainActor.run { read(img) }
        }
    }

    /// Read a menu photo (shared by picking here and a hand-off).
    private func read(_ img: UIImage) {
        reading = true; errorText = nil; items = []; translated = [:]; sectionNames = [:]; picks = []
        Task {
            let lines: [String] = await Task.detached(priority: .userInitiated) {
                MenuReader.lines(from: MenuReader.read(img))
            }.value
            let parsed = MenuReader.parse(lines)
            await MainActor.run {
                reading = false
                // A dish has a price, a description, or a real name — never a stray scrap of OCR.
                let kept = parsed.filter { $0.note || $0.price != nil || !$0.detail.isEmpty || $0.name.filter(\.isLetter).count > 3 }
                // A read with almost no priced dishes is a bad read, not a menu: say so plainly instead of showing junk.
                guard kept.filter({ !$0.note && $0.price != nil }).count >= 2 else {
                    errorText = "Tenzy couldn't read this menu clearly. Take the photo straight on, close enough to fill the screen, in good light — one page or column at a time works best."
                    return
                }
                items = kept
                menuCurrency = MenuReader.currency(in: lines)
                if let c = menuCurrency { rateText = UserDefaults.standard.string(forKey: "menu.rate.\(c).\(homeCurrency)") ?? "" }
                // A menu in a script the person can't read is translated straight away.
                if MenuReader.needsTranslation(lines) { startTranslation() }
            }
        }
    }

    private func startTranslation() {
        translating = true; errorText = nil
        let target = Locale.Language(identifier: Localizer.shared.language)
        let source = MenuReader.language(of: items.map(\.name))
        if translateConfig == nil || translateConfig?.source != source { translateConfig = TranslationSession.Configuration(source: source, target: target) } else { translateConfig?.invalidate() }
    }

    private func suggest() {
        if let c = menuCurrency { UserDefaults.standard.set(rateText, forKey: "menu.rate.\(c).\(homeCurrency)") }
        let fitting = items.filter { !$0.note && $0.price != nil && (diets.isEmpty || MenuReader.verdict($0, diets: diets) == .fits) }
        guard !fitting.isEmpty else { picks = [L("Nothing on this menu clearly fits — ask the staff what they can adapt.")]; return }
        if AIEngine.isAvailable {
            picking = true
            let list = fitting.prefix(40).map { "\(translated[$0.id].map { "\($0) / " } ?? "")\($0.name)\($0.detail.isEmpty ? "" : " (\($0.detail))") \($0.priceText)" }.joined(separator: "\n")
            let dietText = diets.isEmpty ? "no restrictions" : diets.map(\.title).joined(separator: ", ")
            Task {
                let out = try? await AIEngine.run(instructions: "You help a traveller choose from a restaurant menu. Reply with exactly 3 lines, each 'Dish — one short reason'. Only use dishes from the list. No preamble.",
                                                  prompt: "Diet: \(dietText)\nMenu:\n\(list)")
                await MainActor.run {
                    picking = false
                    let lines = (out ?? "").split(separator: "\n").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-•* ")) }.filter { !$0.isEmpty }
                    picks = lines.isEmpty ? fallbackPicks(fitting) : Array(lines.prefix(3))
                }
            }
        } else {
            picks = fallbackPicks(fitting)
        }
    }

    /// Without Apple Intelligence: one dish from each of the first sections that fit, mid-priced.
    private func fallbackPicks(_ fitting: [MenuReader.Item]) -> [String] {
        var out: [String] = [], seen = Set<String>()
        for it in fitting where !seen.contains(it.section) { seen.insert(it.section); out.append("\(translated[it.id] ?? it.name) — \(it.priceText)") }
        return Array(out.prefix(3))
    }
}
