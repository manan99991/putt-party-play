import SwiftUI

@main
struct TenzyApp: App {
    @StateObject private var store = StoreManager.shared

    // AdMob init and the interstitial preload are deferred until after the first frame
    // (prompt 1: cold-start work). They fire once, from a .task on the root view below.
    @State private var adsStarted = false

    @State private var showOnboarding = !OnboardingFlag.seen && Launch.route == nil
    @State private var onboardingPage = 0

    var body: some Scene {
        WindowGroup {
            ZStack {
                HomeView().environmentObject(store).tint(HandyColor.accent)
                if showOnboarding {
                    OnboardingView(startPage: onboardingPage,
                                   onDone: { OnboardingFlag.seen = true; withAnimation(.easeOut(duration: HandyMotion.slow)) { showOnboarding = false }; NotificationCenter.default.post(name: .showSetup, object: nil) },
                                   onSeePro: { OnboardingFlag.seen = true; showOnboarding = false; NotificationCenter.default.post(name: .showPaywall, object: nil) })
                        .environmentObject(store)
                        .transition(.opacity)
                }
            }
            .onAppear {
                if let r = Launch.route, r.hasPrefix("onboarding") { onboardingPage = Int(r.dropFirst("onboarding".count)).map { $0 - 1 } ?? 0; showOnboarding = true }
            }
            .task {
                if !adsStarted {
                    await MainActor.run {
                        adsStarted = true
                        AdsBootstrap.start()
                        Interstitials.shared.preload()
                    }
                }
            }
        }
    }
}

@MainActor
struct Tool: Identifiable {
    let id: String
    let name: String
    let blurb: String
    let icon: String
    let page: Int
    var ai: Bool = false
    var keywords: [String] = []   // synonyms that power search
}

/// The full catalog: 30 tools across 3 pages of 10.
///   Page 1 — the ones reached for daily.
///   Page 2 — handy extras.
///   Page 3 — AI, running free and private on-device (with a graceful fallback on older phones).
@MainActor let TOOLS: [Tool] = [
    // ── Page 1 · Everyday ────────────────────────────────────────────────
    Tool(id: "flash",     name: "Flashlight",      blurb: "One-tap patterns, SOS, strobe",        icon: "flashlight.on.fill",                 page: 1, keywords: ["light","torch","flashlight","strobe","sos","lamp","dark","blink"]),
    Tool(id: "timer",     name: "Timers",          blurb: "Countdown + stopwatch",                icon: "timer",                              page: 1, keywords: ["timer","stopwatch","countdown","pomodoro","clock","minutes","lap","interval"]),
    Tool(id: "clips",     name: "Multi-Clipboard", blurb: "Stack copies, paste from keyboard",    icon: "doc.on.clipboard.fill",              page: 1, keywords: ["clipboard","copy","paste","history","clips","snippets","text"]),
    Tool(id: "qr",        name: "QR & Barcode",    blurb: "Scan, or make Wi-Fi / link codes",     icon: "qrcode.viewfinder",                  page: 1, keywords: ["qr","barcode","scan","scanner","code","wifi","link","url"]),
    Tool(id: "sticky",    name: "Sticky Note",     blurb: "One note, home + lock widget",         icon: "note.text",                          page: 1, keywords: ["note","notes","sticky","memo","reminder","widget","text","scratchpad"]),
    Tool(id: "alarm",     name: "Alarm Pro",       blurb: "Your snooze, limits, sounds",          icon: "alarm.fill",                         page: 1, keywords: ["alarm","wake","clock","snooze","ring","morning","timer"]),
    Tool(id: "ocr",       name: "Text from Image", blurb: "Copy every word in a photo",           icon: "text.viewfinder",                    page: 1, keywords: ["text","ocr","photo","image","screenshot","copy","read","scan","words","extract"]),
    Tool(id: "translate", name: "Translate",       blurb: "Any language, offline, private",       icon: "character.bubble.fill",              page: 1, keywords: ["translate","translation","language","spanish","french","german","foreign","words"]),
    Tool(id: "magnifier", name: "Magnifier",       blurb: "Zoom, light up, freeze the fine print",icon: "plus.magnifyingglass",               page: 1, keywords: ["magnifier","magnify","zoom","read","fine print","loupe","camera","photo","light","glasses"]),
    Tool(id: "scan",      name: "Doc Scanner",     blurb: "Scan pages, share as PDF",             icon: "doc.viewfinder.fill",                page: 1, keywords: ["scan","scanner","document","pdf","doc","paper","camera","photo"]),
    // ── Page 2 · Handy ───────────────────────────────────────────────────
    Tool(id: "level",     name: "Level",           blurb: "True level for shelves & frames",      icon: "ruler.fill",                         page: 2, keywords: ["level","bubble","angle","tilt","horizontal","straight","ruler","measure","hang"]),
    Tool(id: "compass",   name: "Compass",         blurb: "Which way am I facing?",               icon: "location.north.line.fill",           page: 2, keywords: ["compass","direction","north","heading","bearing","navigate","map"]),
    Tool(id: "webclip",   name: "Web → Home",      blurb: "Any link becomes an app icon",         icon: "square.and.arrow.down.on.square.fill",page: 2, keywords: ["shortcut","home screen","icon","web","url","link","bookmark","app"]),
    Tool(id: "exif",      name: "Photo Metadata",  blurb: "See it, strip it before sharing",      icon: "photo.badge.exclamationmark",        page: 2, keywords: ["photo","metadata","exif","location","gps","strip","privacy","camera","image"]),
    Tool(id: "imgpdf",    name: "Image → PDF",     blurb: "Photos into one clean PDF",            icon: "doc.richtext.fill",                  page: 2, keywords: ["pdf","image","photo","picture","document","convert","scan"]),
    Tool(id: "vidcompress",name: "Video Compressor",blurb: "Shrink a clip to send",               icon: "film.stack.fill",                    page: 2, keywords: ["video","compress","shrink","size","movie","clip","reduce","film","mp4"]),
    Tool(id: "bgremove",  name: "Background Remover",blurb: "Cut the subject out, no watermark",  icon: "person.crop.rectangle.badge.plus",   page: 2, keywords: ["background","remove","cutout","photo","image","subject","transparent","sticker","erase"]),
    Tool(id: "park",      name: "Where Did I Park",blurb: "Save the spot, walk back",             icon: "car.fill",                           page: 2, keywords: ["park","parking","car","location","find","map","remember","spot"]),
    Tool(id: "wallet",    name: "Card Wallet",     blurb: "Loyalty barcodes, ready to scan",      icon: "creditcard.fill",                    page: 2, keywords: ["wallet","card","loyalty","barcode","membership","store","points","pass"]),
    Tool(id: "db",        name: "Decibel Meter",   blurb: "How loud is it, really?",              icon: "waveform",                           page: 2, keywords: ["decibel","sound","noise","loud","volume","meter","audio","db"]),
    // ── Page 3 · AI (on-device) ──────────────────────────────────────────
    Tool(id: "ai_summarize",  name: "Summarize",        blurb: "Long text in, the gist out",      icon: "text.append",                  page: 3, ai: true, keywords: ["summarize","summary","tldr","shorten","ai","text","article","notes"]),
    Tool(id: "ai_extract",    name: "Extract to Data",  blurb: "Receipt / card → clean fields",   icon: "tablecells.fill",              page: 3, ai: true, keywords: ["extract","data","receipt","card","scan","ai","fields","invoice","photo"]),
    Tool(id: "ai_rewrite",    name: "Rewrite & Tone",   blurb: "Say it clearer, shorter, nicer",  icon: "wand.and.stars",               page: 3, ai: true, keywords: ["rewrite","tone","grammar","improve","ai","text","edit","polish"]),
    Tool(id: "ai_ask",        name: "Ask a Screenshot", blurb: "Confused by a screen? Ask it",    icon: "sparkle.magnifyingglass",      page: 3, ai: true, keywords: ["ask","screenshot","explain","help","ai","photo","understand","question"]),
    Tool(id: "ai_proofread",  name: "Proofread",        blurb: "Catch typos before you send",     icon: "checkmark.bubble.fill",        page: 3, ai: true, keywords: ["proofread","grammar","spelling","typos","check","ai","text","edit"]),
    Tool(id: "ai_describe",   name: "Describe Image",   blurb: "Natural caption / alt-text",      icon: "eye.fill",                     page: 3, ai: true, keywords: ["describe","caption","alt text","accessibility","ai","photo","image","vision"]),
    Tool(id: "ai_handwriting",name: "Handwriting → Text",blurb: "Notes photo into typed text",    icon: "hand.draw.fill",               page: 3, ai: true, keywords: ["handwriting","notes","ocr","ai","text","photo","convert","scan"]),
    Tool(id: "ai_reply",      name: "Draft a Reply",    blurb: "Paste a message, get a reply",    icon: "arrowshape.turn.up.left.fill", page: 3, ai: true, keywords: ["reply","draft","message","respond","ai","text","answer","email"]),
    Tool(id: "ai_identify",   name: "Identify",         blurb: "Plant, object, or landmark",      icon: "viewfinder.circle.fill",       page: 3, ai: true, keywords: ["identify","what is","plant","object","landmark","ai","photo","recognize","vision"]),
    Tool(id: "ai_sticker",    name: "Make a Sticker",   blurb: "Describe it, your phone draws it", icon: "face.smiling.inverse",         page: 3, ai: true, keywords: ["sticker","image","generate","draw","ai","emoji","create","art","playground"]),
]

/// Google-style ranked search across all 30 tools: best matches first, then ok ones.
@MainActor func searchTools(_ raw: String) -> [Tool] {
    let query = raw.lowercased().trimmingCharacters(in: .whitespaces)
    guard !query.isEmpty else { return [] }
    let tokens = query.split(separator: " ").map(String.init)
    func score(_ t: Tool) -> Int {
        let name = t.name.lowercased(), blurb = t.blurb.lowercased(), keys = t.keywords.map { $0.lowercased() }
        var s = 0
        if name == query { s += 1000 }
        if name.hasPrefix(query) { s += 500 }
        if name.contains(query) { s += 250 }
        if keys.contains(query) { s += 200 }
        for tok in tokens where tok.count >= 2 {
            if name.contains(tok) { s += 120 }
            for k in keys {
                if k == tok { s += 90 }
                else if k.contains(tok) || tok.contains(k) { s += 45 }
            }
            if blurb.contains(tok) { s += 25 }
        }
        return s
    }
    return TOOLS.map { ($0, score($0)) }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.map { $0.0 }
}

@MainActor func tools(onPage p: Int) -> [Tool] { TOOLS.filter { $0.page == p } }

/// Tool routing without AnyView: this @ViewBuilder switch is the single destination map.
struct ToolDestination: View {
    let id: String
    var body: some View {
        switch id {
        case "alarm": AlarmProView()
        case "clips": ClipboardView()
        case "flash": FlashlightView()
        case "timer": TimersView()
        case "qr": QRToolsView()
        case "sticky": StickyNotesView()
        case "ocr": TextFromImageView()
        case "translate": TranslateView()
        case "magnifier": MagnifierView()
        case "scan": DocScannerView()
        case "level": LevelView()
        case "compass": CompassView()
        case "webclip": WebClipView()
        case "exif": ExifView()
        case "imgpdf": ImagePDFView()
        case "vidcompress": VideoCompressorView()
        case "bgremove": BackgroundRemoverView()
        case "park": ParkView()
        case "wallet": WalletView()
        case "db": DecibelMeterView()
        default:
            if let spec = aiSpec(for: id) { AIToolView(spec: spec) } else { EmptyView() }
        }
    }
}

enum Launch {
    static var args: [String] { ProcessInfo.processInfo.arguments }
    static var route: String? { args.firstIndex(of: "-route").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } }
    static var screenshots: Bool { args.contains("-screenshots") }
}

struct HomeView: View {
    @EnvironmentObject var store: StoreManager
    @State private var showPaywall = false
    @State private var page = 1
    @State private var search = ""
    @FocusState private var searching: Bool
    @State private var path: [String] = Launch.route.flatMap { $0.hasPrefix("onboarding") || $0 == "paywall" || $0 == "home" || $0 == "homepro" ? nil : [$0] } ?? []

    private let captions = ["Everyday essentials", "Handy extras", "AI · on your phone"]

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                header
                SearchField(text: $search, focused: $searching)
                    .padding(.horizontal, HandySpacing.gutter)
                    .padding(.bottom, HandySpacing.s8)
                if search.trimmingCharacters(in: .whitespaces).isEmpty {
                    TabView(selection: $page) {
                        ForEach(1...3, id: \.self) { p in
                            ToolGridPage(page: p).tag(p)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                } else {
                    SearchResults(query: search)
                }
                BannerAd()
            }
            .background(HandyColor.bg)
            .navigationDestination(for: String.self) { id in
                switch id {
                case "settings": SettingsView().toolbarRole(.editor)
                case "setup": SetupView(onDone: { path.removeLast() }).toolbarRole(.editor)
                case "privacy": PrivacyView().toolbarRole(.editor)
                case "ring": AlarmRingPreviewView()
                default: ToolDestination(id: id).toolbarRole(.editor)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: path) { _, p in if p.last == "paywall" { path.removeLast(); showPaywall = true } }
            .onAppear { if Launch.route == "paywall" { showPaywall = true } }
            .onReceive(NotificationCenter.default.publisher(for: .showPaywall)) { _ in showPaywall = true }
            .onReceive(NotificationCenter.default.publisher(for: .showSetup)) { _ in if !(Launch.route?.hasPrefix("onboarding") ?? false) { path = ["setup"] } }
            .sheet(isPresented: $showPaywall) {
                PaywallView().presentationDetents([.large]).presentationDragIndicator(.visible)
                    .presentationBackground(HandyColor.surfaceRaised).presentationCornerRadius(HandyRadius.sheet)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: HandySpacing.s4) {
                HStack(alignment: .firstTextBaseline, spacing: HandySpacing.s12) {
                    Text("Tenzy").font(HandyFont.display)
                    PageTabs(page: $page)
                }
                Text(store.isPremium ? "Pro · no ads" : captions[page - 1])
                    .font(.system(size: 14)).foregroundStyle(HandyColor.textSecondary)
                    .animation(.easeOut(duration: HandyMotion.fast), value: page)
            }
            Spacer()
            HStack(spacing: HandySpacing.s8) {
                if !store.isPremium {
                    Button { showPaywall = true } label: {
                        Image(systemName: "crown.fill").font(.system(size: 18)).foregroundStyle(HandyColor.accent)
                            .frame(width: 40, height: 40).background(HandyColor.accentSoft, in: Circle())
                    }.accessibilityLabel("Go Pro")
                }
                NavigationLink(value: "settings") {
                    Image(systemName: "gearshape").font(.system(size: 18)).foregroundStyle(HandyColor.textSecondary).frame(width: 40, height: 40)
                }.accessibilityLabel("Settings")
            }
        }
        .padding(.horizontal, HandySpacing.gutter)
        .padding(.top, HandySpacing.s8)
        .padding(.bottom, HandySpacing.s12)
    }
}

/// The 1 · 2 · 3 page selector that sits beside the wordmark.
struct PageTabs: View {
    @Binding var page: Int
    var body: some View {
        HStack(spacing: HandySpacing.s4) {
            ForEach(1...3, id: \.self) { n in
                Button { withAnimation(.easeOut(duration: HandyMotion.fast)) { page = n } } label: {
                    Text("\(n)")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(page == n ? HandyColor.accent : HandyColor.accentSoft, in: Circle())
                        .foregroundStyle(page == n ? Color.white : HandyColor.accent)
                }
                .accessibilityLabel("Page \(n)")
            }
        }
    }
}

/// A rounded search field that filters all 30 tools as you type.
struct SearchField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var body: some View {
        HStack(spacing: HandySpacing.s8) {
            Image(systemName: "magnifyingglass").foregroundStyle(HandyColor.textSecondary)
            TextField("Search 30 tools…", text: $text)
                .focused(focused)
                .autocorrectionDisabled().textInputAutocapitalization(.never).submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(HandyColor.textSecondary) }
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, HandySpacing.s12).padding(.vertical, HandySpacing.s8)
        .background(HandyColor.surface, in: Capsule())
        .overlay(Capsule().stroke(HandyColor.border, lineWidth: 1))
    }
}

/// Ranked results across every page, best match first.
struct SearchResults: View {
    let query: String
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    var body: some View {
        let results = searchTools(query)
        ScrollView {
            if results.isEmpty {
                VStack(spacing: HandySpacing.s8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 36)).foregroundStyle(HandyColor.textSecondary)
                    Text("No tools match “\(query)”").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                    Text("Try “photo”, “pdf”, “scan”, or “ai”.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }.frame(maxWidth: .infinity).padding(.top, HandySpacing.s48)
            } else {
                LazyVGrid(columns: cols, spacing: HandySpacing.s12) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { _, t in
                        NavigationLink(value: t.id) { ToolCard(tool: t) }.buttonStyle(ToolCardPress())
                    }
                }
                .padding(.horizontal, HandySpacing.gutter).padding(.top, HandySpacing.s4).padding(.bottom, HandySpacing.s16)
            }
        }
    }
}

/// One page of ten tools. Page 3 shows a short on-device-AI note at the top.
struct ToolGridPage: View {
    @EnvironmentObject var store: StoreManager
    let page: Int
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                if page == 3 { aiNote }
                LazyVGrid(columns: cols, spacing: HandySpacing.s12) {
                    ForEach(Array(tools(onPage: page).enumerated()), id: \.element.id) { idx, t in
                        NavigationLink(value: t.id) { ToolCard(tool: t).handyListEntrance(index: idx) }.buttonStyle(ToolCardPress())
                    }
                }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.top, HandySpacing.s4)
            .padding(.bottom, HandySpacing.s16)
        }
    }

    private var aiNote: some View {
        HStack(spacing: HandySpacing.s8) {
            Image(systemName: AIEngine.isAvailable ? "sparkles" : "sparkles.slash").foregroundStyle(HandyColor.accent)
            Text(AIEngine.isAvailable ? "Runs free and private on your iPhone — nothing is uploaded."
                                      : "AI needs a newer iPhone. Each tool explains what it does and offers what it can.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .padding(HandySpacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HandyColor.accentSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
    }
}

/// Home grid card. AI tools get a gradient icon + a sparkle to signal the premium, on-device page.
struct ToolCard: View {
    let tool: Tool
    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            ZStack {
                if tool.ai {
                    Circle().fill(LinearGradient(colors: [HandyColor.accent, Color(red: 0.55, green: 0.35, blue: 0.95)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 34, height: 34)
                    Image(systemName: tool.icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                } else {
                    Circle().fill(HandyColor.accentSoft).frame(width: 34, height: 34)
                    Image(systemName: tool.icon).font(.system(size: 16, weight: .medium)).foregroundStyle(HandyColor.accent)
                }
            }
            Text(tool.name).font(HandyFont.cardTitle).foregroundStyle(HandyColor.textPrimary).lineLimit(1).minimumScaleFactor(0.75)
            Text(tool.blurb).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(1).minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .cardStyle(padding: HandySpacing.s12)
        .overlay(alignment: .topTrailing) {
            if tool.ai { Image(systemName: "sparkle").font(.system(size: 10)).foregroundStyle(HandyColor.accent).padding(8) }
        }
    }
}

struct ToolCardPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? HandyMotion.pressScale : 1)
            .animation(.easeOut(duration: HandyMotion.fast), value: configuration.isPressed)
    }
}

/// Paywall sheet. Two honest plans, yearly preselected as best value. No timers, no fake discounts.
struct PaywallView: View {
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var yearlySelected = true

    var body: some View {
        VStack(spacing: HandySpacing.s16) {
            ZStack {
                Circle().fill(HandyColor.accentSoft).frame(width: 64, height: 64)
                Image(systemName: "crown.fill").font(.system(size: 28)).foregroundStyle(HandyColor.accent)
            }.padding(.top, HandySpacing.s24)
            Text("Tenzy Pro").font(.system(size: 28, weight: .bold))
            Text("Every tool, unlimited. Ads gone for good.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)

            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                ForEach(["No banner or full-screen ads", "Unlimited clips, scans, PDFs & AI actions", "Unlimited alarms and wallet cards", "Support one indie developer"], id: \.self) { line in
                    HStack(spacing: HandySpacing.s12) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(HandyColor.accent)
                        Text(line).font(HandyFont.body)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, HandySpacing.s8)

            Spacer()

            if store.isPremium {
                Label("You're Pro. Thank you.", systemImage: "checkmark.circle.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success)
            } else {
                PlanRow(selected: yearlySelected, title: "Yearly", price: store.yearlyPrice, caption: "Best value · save \(store.yearlySavingsPercent)%", badge: "POPULAR") { yearlySelected = true }
                PlanRow(selected: !yearlySelected, title: "Monthly", price: store.monthlyPrice, caption: "Flexible, cancel anytime", badge: nil) { yearlySelected = false }

                Button {
                    Task { await store.purchase(yearlySelected ? store.yearly : store.monthly); if store.isPremium { dismiss() } }
                } label: {
                    Text(yearlySelected ? "Go Pro · \(store.yearlyPrice) / year" : "Go Pro · \(store.monthlyPrice) / month").frame(maxWidth: .infinity)
                }.primaryButton()

                Text("Auto-renews until cancelled in Settings › Apple ID › Subscriptions. Price shown in your currency at checkout.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                HStack(spacing: HandySpacing.s24) {
                    Button("Restore purchases") { Task { await store.restore() } }.textButton()
                    Button("Not now") { dismiss() }.textButton()
                }
            }
            if let e = store.purchaseError { Text(e).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .padding(.horizontal, HandySpacing.s24)
        .padding(.bottom, HandySpacing.s24)
    }
}

/// A selectable plan row in the paywall.
private struct PlanRow: View {
    let selected: Bool
    let title: String
    let price: String
    let caption: String
    let badge: String?
    let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            HStack(spacing: HandySpacing.s12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle").foregroundStyle(selected ? HandyColor.accent : HandyColor.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: HandySpacing.s8) {
                        Text(title).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                        if let badge { Text(badge).font(.system(size: 10, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2).background(HandyColor.accent, in: Capsule()).foregroundStyle(.white) }
                    }
                    Text(caption).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                Spacer()
                Text(price).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
            }
            .padding(HandySpacing.s16)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(selected ? HandyColor.accent : HandyColor.border, lineWidth: selected ? 2 : 1))
        }.buttonStyle(.plain)
    }
}

/// Shared chrome for every tool page.
struct ToolPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s16) {
                    Text(title).font(HandyFont.display)
                    Text(subtitle).font(.system(size: 15)).foregroundStyle(HandyColor.textSecondary).padding(.top, -HandySpacing.s8)
                    content()
                }
                .padding(.horizontal, HandySpacing.gutter)
                .padding(.vertical, HandySpacing.s8)
                .padding(.bottom, HandySpacing.s48)
            }
            .scrollDismissesKeyboard(.interactively)
            BannerAd()
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .background(HandyColor.bg)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Notification.Name {
    static let showPaywall = Notification.Name("handytools.showPaywall")
    static let showSetup = Notification.Name("handytools.showSetup")
}
