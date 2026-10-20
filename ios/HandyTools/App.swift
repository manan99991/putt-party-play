import SwiftUI

@main
struct TenzyApp: App {
    @StateObject private var store = StoreManager.shared
    @StateObject private var theme = ThemeManager.shared

    // AdMob init and the interstitial preload are deferred until after the first frame
    // (prompt 1: cold-start work). They fire once, from a .task on the root view below.
    @State private var adsStarted = false

    @State private var showOnboarding = !OnboardingFlag.seen && Launch.route == nil
    @State private var onboardingPage = 0
    @State private var crashReport: String?

    init() { Diagnostics.shared.start() }

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
            .overlay(alignment: .top) {
                if let r = crashReport { CrashBanner(summary: r) { crashReport = nil } }
            }
            .onAppear {
                if let r = Launch.route, r.hasPrefix("onboarding") { onboardingPage = Int(r.dropFirst("onboarding".count)).map { $0 - 1 } ?? 0; showOnboarding = true }
                if crashReport == nil, !Launch.uitest { crashReport = Diagnostics.shared.takePendingCrash() }
            }
            .onOpenURL { url in
                // tenzy://tool/<id> from the home-screen widget or Shortcuts
                guard url.scheme == "tenzy", url.host == "tool", let id = url.pathComponents.dropFirst().first, TOOLS.contains(where: { $0.id == id }) else { return }
                showOnboarding = false
                NotificationCenter.default.post(name: .openTool, object: id)
            }
            .task {
                if !adsStarted {
                    await MainActor.run {
                        adsStarted = true
                        AdsBootstrap.start()
                        Interstitials.shared.preload()
                        // Pre-scan photo duplicates in the background so Cleaner's Duplicates tab is
                        // ready the moment it's opened, instead of making the user wait on a scan.
                        if !Launch.uitest { CleanerIndex.shared.prewarm() }
                    }
                }
            }
            .environmentObject(theme)
            // Daylight follows the system (keeps light/dark); a Pro theme pins its own look.
            .preferredColorScheme(theme.current == .daylight ? nil : (theme.current.isDark ? .dark : .light))
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
    var asset: String? = nil      // custom icon image in the asset catalog; nil → the SF Symbol `icon`
    var keywords: [String] = []   // synonyms that power search
}

/// The full catalog: 30 tools across 3 pages of 10.
///   Page 1 — the ones reached for daily.
///   Page 2 — handy extras.
///   Page 3 — AI, running free and private on-device (with a graceful fallback on older phones).
@MainActor let TOOLS: [Tool] = [
    // ── Page 1 · Files, photos & docs ───────────────────────────────────
    Tool(id: "fitit",      name: "Fit It",           blurb: "Shrink to an exact size limit",     icon: "square.resize.down",                  page: 1, asset: "tool_fitit", keywords: ["compress","size","mb","kb","limit","upload","email","shrink","reduce","smaller","too big","pdf","photo","video","fit"]),
    Tool(id: "scan",       name: "Scan",             blurb: "Scan, OCR, sign & fill PDFs",       icon: "doc.viewfinder.fill",                 page: 1, asset: "tool_scan", keywords: ["scan","scanner","document","pdf","ocr","sign","signature","fill","form","flatten","merge","split","pages","business card","handwriting"]),
    Tool(id: "studio",     name: "Studio",           blurb: "Enhance, cut out, passport, resize", icon: "photo.on.rectangle.angled",           page: 1, asset: "tool_studio", keywords: ["photo","image","enhance","upscale","sharpen","denoise","auto","fix","background","remove","cutout","passport","id photo","resize","convert","heic","jpg","png","crop"]),
    Tool(id: "video",      name: "Video",            blurb: "Shrink, trim, convert, GIF",        icon: "film.stack.fill",                     page: 1, asset: "tool_video", keywords: ["video","compress","shrink","trim","cut","convert","mp4","mov","mute","audio","extract","gif","clip"]),
    Tool(id: "formatfix",  name: "Format Fixer",     blurb: "HEIC/MOV → JPG/MP4, in batch",      icon: "arrow.triangle.2.circlepath",         page: 1, asset: "tool_formatfix", keywords: ["heic","jpg","jpeg","png","mov","mp4","convert","format","batch","won't open","upload","share"]),
    Tool(id: "scrub",      name: "Privacy Scrubber", blurb: "Strip location, redact for good",   icon: "eye.slash.fill",                      page: 1, asset: "tool_scrub", keywords: ["privacy","metadata","exif","gps","location","strip","redact","blur","face","plate","hide","censor","share safe"]),
    Tool(id: "cleaner",    name: "Cleaner",          blurb: "Free space: dupes & big files",     icon: "sparkles",                            page: 1, asset: "tool_cleaner", keywords: ["clean","cleaner","storage","space","free up","duplicate","duplicates","screenshots","large","big","videos","photos","photo","images","image","pictures","delete","declutter","full"]),
    Tool(id: "qrwifi",     name: "QR & Wi‑Fi",       blurb: "Scan, make & share Wi‑Fi codes",    icon: "qrcode",                              page: 1, asset: "tool_qrwifi", keywords: ["qr","code","barcode","wifi","wi-fi","password","share","guest","generate","make","scan"]),
    Tool(id: "stitch",     name: "Long Screenshot",  blurb: "Stitch shots into one tall image",  icon: "rectangle.split.1x2.fill",            page: 1, asset: "tool_stitch", keywords: ["screenshot","long","stitch","scroll","combine","merge","tall","chat","thread","full page"]),
    Tool(id: "shareready", name: "Share‑Ready",      blurb: "One tap: convert, strip, shrink",   icon: "square.and.arrow.up.fill",            page: 1, asset: "tool_shareready", keywords: ["share","upload","ready","convert","strip","metadata","shrink","recipe","one tap","portal","send"]),
    // ── Page 2 · Camera, sensors & everyday ─────────────────────────────
    Tool(id: "light",      name: "Flashlight+",      blurb: "Strobe, SOS, screen light, mirror", icon: "flashlight.on.fill",                  page: 2, asset: "tool_light", keywords: ["flashlight","torch","light","strobe","sos","morse","screen light","mirror","selfie","dark","blink"]),
    Tool(id: "instruments",name: "Instruments",      blurb: "Level, compass, dB, light, more",   icon: "gauge.with.dots.needle.33percent",    page: 2, asset: "tool_instruments", keywords: ["level","bubble","angle","protractor","compass","north","decibel","sound","noise","light","lux","altimeter","barometer","magnet","metal","sensor"]),
    Tool(id: "measure",    name: "Measure",          blurb: "AR tape: distance, height, area",   icon: "ruler.fill",                          page: 2, asset: "tool_measure", keywords: ["measure","tape","ruler","distance","height","area","room","ar","lidar","length","how tall","how far"]),
    Tool(id: "magnify",    name: "Magnifier+",       blurb: "Zoom, freeze, high‑contrast",       icon: "plus.magnifyingglass",                page: 2, asset: "tool_magnify", keywords: ["magnifier","magnify","zoom","fine print","read","small text","freeze","contrast","loupe","glasses"]),
    Tool(id: "procam",     name: "Pro Camera",       blurb: "Manual ISO, shutter, RAW",          icon: "camera.aperture",                     page: 2, asset: "tool_procam", keywords: ["camera","manual","iso","shutter","exposure","raw","dng","focus","long exposure","night","timelapse","histogram"]),
    Tool(id: "gpsdash",    name: "GPS Dashboard",    blurb: "Speed, heading, altitude, HUD",     icon: "speedometer",                         page: 2, asset: "tool_gpsdash", keywords: ["speed","speedometer","gps","heading","altitude","hud","trip","drive","bike","mph","kph","dashboard"]),
    Tool(id: "audiolab",   name: "Audio Lab",        blurb: "Tuner, tones, speaker test",        icon: "waveform",                            page: 2, asset: "tool_audiolab", keywords: ["tuner","guitar","pitch","tone","frequency","generator","speaker","test","earbuds","left right","water","eject","sound"]),
    Tool(id: "rest",       name: "Rest",             blurb: "White noise + snore recorder",      icon: "moon.zzz.fill",                       page: 2, asset: "tool_rest", keywords: ["sleep","white noise","pink","brown","rain","fan","noise","timer","snore","record","night","relax","focus"]),
    Tool(id: "colorvision",name: "Color Vision",     blurb: "Live color‑blind correction",       icon: "eyeglasses",                          page: 2, asset: "tool_colorvision", keywords: ["color","colour","blind","colorblind","daltonize","correct","name the color","what color","red green","accessibility","eyedropper","hex","paint"]),
    Tool(id: "capture",    name: "Capture",          blurb: "Point: text, codes, translate",     icon: "viewfinder",                          page: 2, asset: "tool_capture", keywords: ["camera","text","ocr","copy","qr","barcode","translate","sign","menu","what is this","identify","live text"]),
    // ── Page 3 · Words, AI & accessibility ──────────────────────────────
    Tool(id: "textstudio", name: "Text Studio",      blurb: "Fix, rewrite, reply, summarize",    icon: "text.badge.checkmark",                page: 3, ai: true, asset: "tool_textstudio", keywords: ["text","grammar","proofread","rewrite","tone","reply","summarize","summary","edit","polish","email","message","ai"]),
    Tool(id: "translate",  name: "Translate",        blurb: "Text, camera, voice — offline",     icon: "character.bubble.fill",               page: 3, asset: "tool_translate", keywords: ["translate","translation","language","offline","camera","voice","conversation","spanish","french","menu","sign"]),
    Tool(id: "voicenotes", name: "Voice → Notes",    blurb: "Transcript, summary, to‑dos",       icon: "waveform.badge.mic",                  page: 3, ai: true, asset: "tool_voicenotes", keywords: ["voice","record","transcribe","transcript","meeting","notes","summary","action items","dictation","audio","speech","ai"]),
    Tool(id: "livecaptions",name: "Live Captions",   blurb: "Real‑time captions, private",       icon: "captions.bubble.fill",                page: 3, ai: true, asset: "tool_livecaptions", keywords: ["captions","live","subtitles","hearing","deaf","hard of hearing","conversation","transcribe","accessibility","real time"]),
    Tool(id: "shield",     name: "Message Shield",   blurb: "Spot scams, see why",               icon: "shield.lefthalf.filled",              page: 3, ai: true, asset: "tool_shield", keywords: ["scam","phishing","spam","fraud","suspicious","text","email","link","safe","check","is this real","mom","ai"]),
    Tool(id: "readaloud",  name: "Read Aloud",       blurb: "Any page, spoken naturally",        icon: "speaker.wave.2.bubble.fill",          page: 3, asset: "tool_readaloud", keywords: ["read","aloud","speak","tts","voice","dyslexia","accessibility","page","book","ocr","listen","simplify"]),
    Tool(id: "explain",    name: "Plain‑English Explainer", blurb: "Decode legal & medical jargon", icon: "text.book.closed.fill",             page: 3, ai: true, asset: "tool_explain", keywords: ["explain","plain english","simple","jargon","legal","contract","medical","lab results","terms","what does this mean","ai"]),
    Tool(id: "datagrab",   name: "Data Grabber",     blurb: "Receipt → rows, contacts, dates",   icon: "tablecells.fill",                     page: 3, ai: true, asset: "tool_datagrab", keywords: ["receipt","table","data","extract","csv","spreadsheet","contact","business card","calendar","event","expense","ai"]),
    Tool(id: "describe",   name: "Scene Describer",  blurb: "Hear what the camera sees",         icon: "eye.fill",                            page: 3, ai: true, asset: "tool_describe", keywords: ["describe","scene","blind","low vision","narrate","speak","what is in front","accessibility","camera","see"]),
    Tool(id: "vault",      name: "Vault",            blurb: "Face ID locker",                    icon: "lock.fill",                           page: 3, asset: "tool_vault", keywords: ["vault","secure","private","lock","face id","hidden","photos","notes","files","cards","safe"]),
]

/// Words that mean the same thing to a user. A query token is expanded to its whole group before
/// matching, so "image" finds photo/picture tools, "movie" finds Video, "declutter" finds Cleaner,
/// and so on — the thing that makes the search feel smart rather than literal.
enum SearchSynonyms {
    static let groups: [[String]] = [
        ["image", "images", "img", "photo", "photos", "picture", "pictures", "pic", "pics", "snapshot", "snap"],
        ["video", "videos", "movie", "movies", "clip", "clips", "film", "footage", "recording", "reel"],
        ["pdf", "document", "documents", "doc", "docs", "paper", "page", "pages", "form", "forms"],
        ["compress", "compressed", "shrink", "reduce", "smaller", "size", "downsize", "fit", "mb", "kb", "too big"],
        ["scan", "scanner", "scanning", "ocr", "recognize", "sign", "signature"],
        ["qr", "barcode", "code", "codes"],
        ["wifi", "wi-fi", "wireless", "network", "hotspot", "password"],
        ["translate", "translation", "translator", "language", "languages", "spanish", "french"],
        ["text", "words", "writing", "grammar", "rewrite", "proofread", "summarize", "reply"],
        ["voice", "audio", "sound", "mic", "microphone", "record", "speech", "dictation", "transcribe", "transcript"],
        ["clean", "cleaner", "cleanup", "clear", "storage", "space", "declutter", "free", "free up", "delete", "remove", "trash", "junk", "full"],
        ["duplicate", "duplicates", "dupe", "dupes", "similar", "copy", "copies", "same", "look-alike", "lookalike"],
        ["screenshot", "screenshots", "screen", "stitch", "long", "tall", "scroll"],
        ["flashlight", "torch", "light", "lamp", "strobe", "sos", "mirror"],
        ["measure", "measurement", "ruler", "tape", "distance", "length", "area", "height", "ar"],
        ["magnify", "magnifier", "magnifying", "zoom", "enlarge", "loupe", "fine print", "read small"],
        ["speed", "speedometer", "gps", "location", "heading", "altitude", "hud", "dashboard"],
        ["color", "colour", "colors", "colours", "colorblind", "colourblind", "hex", "eyedropper"],
        ["sleep", "rest", "noise", "white noise", "relax", "snore", "night", "focus", "calm"],
        ["caption", "captions", "subtitle", "subtitles", "hearing", "deaf"],
        ["scam", "spam", "phishing", "fraud", "suspicious", "shield", "safe"],
        ["read", "aloud", "speak", "tts", "narrate", "listen", "spoken"],
        ["metadata", "exif", "privacy", "strip", "redact", "scrub", "blur", "censor"],
        ["vault", "lock", "secure", "private", "hidden", "safe", "face id", "passcode"],
        ["enhance", "upscale", "sharpen", "denoise", "improve", "fix", "quality", "restore"],
        ["cutout", "cut out", "background", "remove background", "passport", "id photo", "headshot"],
        ["convert", "format", "heic", "jpg", "jpeg", "png", "mp4", "mov", "gif"],
        ["receipt", "receipts", "table", "data", "extract", "spreadsheet", "csv", "contact", "contacts"],
        ["level", "compass", "altimeter", "barometer", "magnet", "metal", "decibel", "db", "sensor", "instruments", "bubble"],
        ["camera", "capture", "viewfinder", "describe", "scene", "iso", "shutter", "raw", "exposure"],
        ["share", "upload", "send", "export", "ready"],
    ]
    /// All forms a token stands for (itself plus any group it belongs to).
    static func expand(_ token: String) -> Set<String> {
        var out: Set<String> = [token]
        for g in groups where g.contains(token) { out.formUnion(g) }
        return out
    }
}

/// Google-style ranked search across all 30 tools: best matches first, then ok ones. Query tokens are
/// expanded through SearchSynonyms, so related words ("image"→photo, "movie"→video) still find the tool.
@MainActor func searchTools(_ raw: String) -> [Tool] {
    let query = raw.lowercased().trimmingCharacters(in: .whitespaces)
    guard !query.isEmpty else { return [] }
    let tokens = query.split(separator: " ").map(String.init).filter { $0.count >= 2 }
    let expanded = tokens.map { SearchSynonyms.expand($0) }
    func score(_ t: Tool) -> Int {
        let name = t.name.lowercased(), blurb = t.blurb.lowercased(), keys = t.keywords.map { $0.lowercased() }
        var s = 0
        if name == query { s += 1000 }
        if name.hasPrefix(query) { s += 500 }
        if name.contains(query) { s += 250 }
        if keys.contains(query) { s += 200 }
        for (i, tok) in tokens.enumerated() {
            let forms = expanded[i]
            if name.contains(tok) { s += 120 }
            else if forms.contains(where: { name.contains($0) }) { s += 70 }
            for k in keys {
                if k == tok { s += 90 }
                else if forms.contains(k) { s += 70 }                               // synonym hits a keyword exactly
                else if k.contains(tok) || tok.contains(k) { s += 45 }
                else if forms.contains(where: { k.contains($0) || $0.contains(k) }) { s += 28 }
            }
            if blurb.contains(tok) { s += 25 }
            else if forms.contains(where: { blurb.contains($0) }) { s += 15 }
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
        case "scan": ScanView()
        case "studio": StudioView()
        case "video": VideoView()
        case "formatfix": FormatFixView()
        case "qrwifi": QRWifiView()
        case "stitch": StitchView()
        case "scrub": ScrubView()
        case "shareready": ShareReadyView()
        // ── Page 2 ──
        case "light": FlashlightView()
        case "instruments": InstrumentsView()
        case "magnify": MagnifierView()
        // ── Page 3 ──
        case "translate": TranslateView()
        case "voicenotes": VoiceNotesView()
        case "livecaptions": LiveCaptionsView()
        case "cleaner": CleanerView()
        // Everything else is being built — show an honest placeholder, never a blank screen.
        case "capture": CaptureView()
        case "colorvision": ColorVisionView()
        case "gpsdash": GPSDashboardView()
        case "audiolab": AudioLabView()
        case "rest": RestView()
        case "describe": SceneDescriberView()
        case "procam": ProCameraView()
        case "measure": MeasureARView()
        case "shield": ShieldView()
        case "datagrab": DataGrabView()
        case "textstudio": TextStudioView()
        case "readaloud": ReadAloudView()
        case "explain": ExplainerView()
        case "vault": VaultView()
        default: ComingSoonView(id: id)
        }
    }
}

enum Launch {
    static var args: [String] { ProcessInfo.processInfo.arguments }
    static var route: String? { args.firstIndex(of: "-route").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } }
    static var screenshots: Bool { args.contains("-screenshots") }
    static var uitest: Bool { args.contains("-uitest") }
    static var live: Bool { args.contains("-live") }
    /// Whether camera / mic / audio should auto-start: normally yes; in the `-live` UI test that
    /// deliberately drives those paths yes; in the ordinary `-uitest` smoke run no.
    static var startHardware: Bool { !uitest || live }
    /// UI tests can't drive the system photo picker reliably, so with `-sample` each tool preloads
    /// a generated sample (photo, screenshots, receipt, movie) and the flow runs like a user's would.
    static var sample: Bool { args.contains("-sample") }
}

struct HomeView: View {
    @EnvironmentObject var store: StoreManager
    @ObservedObject private var theme = ThemeManager.shared   // re-skin the home grid live on a theme change
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
            .id(theme.current)   // force a full re-skin of the grid when the theme changes
            .background(HandyColor.bg)
            .navigationDestination(for: String.self) { id in
                switch id {
                case "settings": SettingsView().toolbarRole(.editor)
                case "setup": SetupView(onDone: { path.removeLast() }).toolbarRole(.editor)
                case "privacy": PrivacyView().toolbarRole(.editor)
                default: ToolDestination(id: id).toolbarRole(.editor)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: path) { _, p in searching = false; if p.last == "paywall" { path.removeLast(); showPaywall = true } }
            .onAppear { if Launch.route == "paywall" { showPaywall = true } }
            .onReceive(NotificationCenter.default.publisher(for: .showPaywall)) { _ in showPaywall = true }
            .onReceive(NotificationCenter.default.publisher(for: .openTool)) { n in if let id = n.object as? String { path = [id] } }
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
                .onSubmit { focused.wrappedValue = false }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { focused.wrappedValue = false }
                    }
                }
            if !text.isEmpty {
                Button { text = ""; focused.wrappedValue = false } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(HandyColor.textSecondary) }
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
        .scrollDismissesKeyboard(.immediately)
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
                if let asset = tool.asset {
                    // Custom designed icon — a complete squircle tile, shown edge-to-edge.
                    Image(asset).resizable().scaledToFill().frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                } else if tool.ai {
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
        .padding(HandySpacing.s12)
        .background {
            // Surface + the tool's relevant motif, tinted by the theme accent at a whisper so text stays
            // readable. Template-rendered, so one motif set re-skins across every theme.
            ZStack {
                HandyColor.surface
                Image("bg_" + tool.id)
                    .resizable().renderingMode(.template).scaledToFill()
                    .foregroundStyle(HandyColor.accent).opacity(0.10)
            }
            .clipShape(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
            .allowsHitTesting(false)
        }
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
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
                ForEach(["No banner or full-screen ads", "Unlimited fits, scans, exports & AI actions", "Unlimited video, voice and translation jobs", "Support one indie developer"], id: \.self) { line in
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
/// Shown once on the launch after a crash: tells the user what died and lets them send the captured
/// report (stack + tool) in one tap, so I get the diagnosis without them hunting through a menu.
struct CrashBanner: View {
    let summary: String
    let onDismiss: () -> Void
    var body: some View {
        HStack(spacing: HandySpacing.s12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tenzy crashed last time").font(HandyFont.bodyStrong).foregroundStyle(.white)
                Text(summary).font(HandyFont.micro).foregroundStyle(.white.opacity(0.9)).lineLimit(2)
            }
            Spacer(minLength: HandySpacing.s8)
            ShareLink(item: Diagnostics.shared.reportFileURL()) {
                Text("Send").font(HandyFont.caption).foregroundStyle(HandyColor.danger)
                    .padding(.horizontal, 12).padding(.vertical, 6).background(.white, in: Capsule())
            }
            Button(action: onDismiss) { Image(systemName: "xmark").foregroundStyle(.white.opacity(0.9)) }.buttonStyle(.plain)
        }
        .padding(HandySpacing.s12)
        .background(HandyColor.danger, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
        .padding(.horizontal, HandySpacing.gutter)
        .padding(.top, HandySpacing.s8)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct ToolPage<Content: View>: View {
    let title: String
    let subtitle: String
    /// Optional bar pinned at the bottom, above the ad — stays put while the content scrolls.
    var footer: AnyView? = nil
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
            if let footer { footer }
            BannerAd()
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .background(HandyColor.bg)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Diagnostics.shared.currentTool = title }
    }
}

extension Notification.Name {
    static let openTool = Notification.Name("handytools.openTool")
    static let showPaywall = Notification.Name("handytools.showPaywall")
    static let showSetup = Notification.Name("handytools.showSetup")
}
