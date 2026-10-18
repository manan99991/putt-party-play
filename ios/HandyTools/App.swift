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
    // ── Page 1 · Files, docs & sharing ──────────────────────────────────
    Tool(id: "fitit",      name: "Fit It",           blurb: "Shrink to an exact size limit",     icon: "square.resize.down",                  page: 1, keywords: ["compress","size","mb","kb","limit","upload","email","shrink","reduce","smaller","too big","pdf","photo","video","fit"]),
    Tool(id: "scan",       name: "Scan",             blurb: "Scan, OCR, sign & flatten PDFs",    icon: "doc.viewfinder.fill",                 page: 1, keywords: ["scan","scanner","document","pdf","ocr","sign","signature","fill","form","flatten","merge","split","pages","business card","handwriting"]),
    Tool(id: "studio",     name: "Studio",           blurb: "Cut out, passport, resize, convert", icon: "photo.on.rectangle.angled",           page: 1, keywords: ["photo","image","background","remove","cutout","passport","id photo","resize","convert","heic","jpg","png","crop"]),
    Tool(id: "video",      name: "Video",            blurb: "Shrink, trim, convert, GIF",        icon: "film.stack.fill",                     page: 1, keywords: ["video","compress","shrink","trim","cut","convert","mp4","mov","mute","audio","extract","gif","clip"]),
    Tool(id: "formatfix",  name: "Format Fixer",     blurb: "HEIC/MOV → JPG/MP4, in batch",      icon: "arrow.triangle.2.circlepath",         page: 1, keywords: ["heic","jpg","jpeg","png","mov","mp4","convert","format","batch","won't open","upload","share"]),
    Tool(id: "scrub",      name: "Privacy Scrubber", blurb: "Strip location, redact for good",   icon: "eye.slash.fill",                      page: 1, keywords: ["privacy","metadata","exif","gps","location","strip","redact","blur","face","plate","hide","censor","share safe"]),
    Tool(id: "capture",    name: "Capture",          blurb: "Point: text, codes, translate",     icon: "viewfinder",                          page: 1, keywords: ["camera","text","ocr","copy","qr","barcode","translate","sign","menu","what is this","identify","live text"]),
    Tool(id: "qrwifi",     name: "QR & Wi‑Fi",       blurb: "Scan, make & share Wi‑Fi codes",    icon: "qrcode",                              page: 1, keywords: ["qr","code","barcode","wifi","wi-fi","password","share","guest","generate","make","scan"]),
    Tool(id: "stitch",     name: "Long Screenshot",  blurb: "Stitch shots into one tall image",  icon: "rectangle.split.1x2.fill",            page: 1, keywords: ["screenshot","long","stitch","scroll","combine","merge","tall","chat","thread","full page"]),
    Tool(id: "shareready", name: "Share‑Ready",      blurb: "One tap: convert, strip, shrink",   icon: "square.and.arrow.up.fill",            page: 1, keywords: ["share","upload","ready","convert","strip","metadata","shrink","recipe","one tap","portal","send"]),
    // ── Page 2 · Camera, sensors & everyday ─────────────────────────────
    Tool(id: "light",      name: "Flashlight+",      blurb: "Strobe, SOS, screen light, mirror", icon: "flashlight.on.fill",                  page: 2, keywords: ["flashlight","torch","light","strobe","sos","morse","screen light","mirror","selfie","dark","blink"]),
    Tool(id: "instruments",name: "Instruments",      blurb: "Level, compass, dB, light, more",   icon: "gauge.with.dots.needle.33percent",    page: 2, keywords: ["level","bubble","angle","protractor","compass","north","decibel","sound","noise","light","lux","altimeter","barometer","magnet","metal","sensor"]),
    Tool(id: "measure",    name: "Measure",          blurb: "AR tape: distance, height, area",   icon: "ruler.fill",                          page: 2, keywords: ["measure","tape","ruler","distance","height","area","room","ar","lidar","length","how tall","how far"]),
    Tool(id: "magnify",    name: "Magnifier+",       blurb: "Zoom, freeze, high‑contrast",       icon: "plus.magnifyingglass",                page: 2, keywords: ["magnifier","magnify","zoom","fine print","read","small text","freeze","contrast","loupe","glasses"]),
    Tool(id: "procam",     name: "Pro Camera",       blurb: "Manual ISO, shutter, RAW",          icon: "camera.aperture",                     page: 2, keywords: ["camera","manual","iso","shutter","exposure","raw","dng","focus","long exposure","night","timelapse","histogram"]),
    Tool(id: "gpsdash",    name: "GPS Dashboard",    blurb: "Speed, heading, altitude, HUD",     icon: "speedometer",                         page: 2, keywords: ["speed","speedometer","gps","heading","altitude","hud","trip","drive","bike","mph","kph","dashboard"]),
    Tool(id: "audiolab",   name: "Audio Lab",        blurb: "Tuner, tones, speaker test",        icon: "waveform",                            page: 2, keywords: ["tuner","guitar","pitch","tone","frequency","generator","speaker","test","earbuds","left right","water","eject","sound"]),
    Tool(id: "rest",       name: "Rest",             blurb: "White noise + snore recorder",      icon: "moon.zzz.fill",                       page: 2, keywords: ["sleep","white noise","pink","brown","rain","fan","noise","timer","snore","record","night","relax","focus"]),
    Tool(id: "colorvision",name: "Color Vision",     blurb: "Live color‑blind correction",       icon: "eyeglasses",                          page: 2, keywords: ["color","colour","blind","colorblind","daltonize","correct","name the color","what color","red green","accessibility","eyedropper","hex","paint"]),
    Tool(id: "describe",   name: "Scene Describer",  blurb: "Hear what the camera sees",         icon: "eye.fill",                            page: 2, ai: true, keywords: ["describe","scene","blind","low vision","narrate","speak","what is in front","accessibility","camera","see"]),
    // ── Page 3 · Words, AI & accessibility ──────────────────────────────
    Tool(id: "textstudio", name: "Text Studio",      blurb: "Fix, rewrite, reply, summarize",    icon: "text.badge.checkmark",                page: 3, ai: true, keywords: ["text","grammar","proofread","rewrite","tone","reply","summarize","summary","edit","polish","email","message","ai"]),
    Tool(id: "translate",  name: "Translate",        blurb: "Text, camera, voice — offline",     icon: "character.bubble.fill",               page: 3, keywords: ["translate","translation","language","offline","camera","voice","conversation","spanish","french","menu","sign"]),
    Tool(id: "voicenotes", name: "Voice → Notes",    blurb: "Transcript, summary, to‑dos",       icon: "waveform.badge.mic",                  page: 3, ai: true, keywords: ["voice","record","transcribe","transcript","meeting","notes","summary","action items","dictation","audio","speech","ai"]),
    Tool(id: "livecaptions",name: "Live Captions",   blurb: "Real‑time captions, private",       icon: "captions.bubble.fill",                page: 3, ai: true, keywords: ["captions","live","subtitles","hearing","deaf","hard of hearing","conversation","transcribe","accessibility","real time"]),
    Tool(id: "shield",     name: "Message Shield",   blurb: "Spot scams, see why",               icon: "shield.lefthalf.filled",              page: 3, ai: true, keywords: ["scam","phishing","spam","fraud","suspicious","text","email","link","safe","check","is this real","mom","ai"]),
    Tool(id: "readaloud",  name: "Read Aloud",       blurb: "Any page, spoken naturally",        icon: "speaker.wave.2.bubble.fill",          page: 3, keywords: ["read","aloud","speak","tts","voice","dyslexia","accessibility","page","book","ocr","listen","simplify"]),
    Tool(id: "explain",    name: "Plain‑English Explainer", blurb: "Decode legal & medical jargon", icon: "text.book.closed.fill",             page: 3, ai: true, keywords: ["explain","plain english","simple","jargon","legal","contract","medical","lab results","terms","what does this mean","ai"]),
    Tool(id: "datagrab",   name: "Data Grabber",     blurb: "Receipt → rows, contacts, dates",   icon: "tablecells.fill",                     page: 3, ai: true, keywords: ["receipt","table","data","extract","csv","spreadsheet","contact","business card","calendar","event","expense","ai"]),
    Tool(id: "clips",      name: "Clipboard",        blurb: "Snippets & saved text",             icon: "doc.on.clipboard.fill",               page: 3, keywords: ["clipboard","copy","paste","history","snippets","saved","text","boilerplate","address"]),
    Tool(id: "vault",      name: "Vault",            blurb: "Face ID locker",                    icon: "lock.fill",                           page: 3, keywords: ["vault","secure","private","lock","face id","hidden","photos","notes","files","cards","safe"]),
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
        // ── Page 1 ──
        case "fitit": FitItView()
        case "scan": DocScannerView()            // base — Scan super-tool lands on this
        case "studio": BackgroundRemoverView()   // base — Studio super-tool lands on this
        case "video": VideoCompressorView()      // base — Video super-tool lands on this
        case "formatfix": FormatFixView()
        case "qrwifi": QRWifiView()
        case "stitch": StitchView()
        case "scrub": ScrubView()
        case "shareready": ShareReadyView()
        // ── Page 2 ──
        case "light": FlashlightView()
        case "instruments": MeasureView()
        case "magnify": MagnifierView()
        // ── Page 3 ──
        case "translate": TranslateView()
        case "voicenotes": AudioToTextView()
        case "clips": ClipboardView()
        case "vault": SecureVaultView()
        // Everything else is being built — show an honest placeholder, never a blank screen.
        default: ComingSoonView(id: id)
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

    private let captions = ["Everyday essentials", "Power tools", "AI · on your phone"]

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

/// One page of ten tools — a static 2×5 grid that fills the page, so no page ever scrolls.
struct ToolGridPage: View {
    @EnvironmentObject var store: StoreManager
    let page: Int
    var body: some View {
        let items = tools(onPage: page)
        VStack(spacing: HandySpacing.s12) {
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: HandySpacing.s12) {
                    ForEach(0..<2, id: \.self) { col in
                        let idx = row * 2 + col
                        if idx < items.count {
                            let t = items[idx]
                            NavigationLink(value: t.id) {
                                ToolCard(tool: t).frame(maxWidth: .infinity, maxHeight: .infinity)
                            }.buttonStyle(ToolCardPress())
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, HandySpacing.gutter)
        .padding(.top, HandySpacing.s4)
        .padding(.bottom, HandySpacing.s12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Text(tool.blurb).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
