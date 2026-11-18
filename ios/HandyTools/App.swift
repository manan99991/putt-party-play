import SwiftUI
import UIKit

@main
struct TenzyApp: App {
    @StateObject private var store = StoreManager.shared
    @StateObject private var theme = ThemeManager.shared

    // One-time, post-first-frame startup warmup (background pre-scans), fired once from a
    // .task on the root view below so cold-start work stays off the first-frame path.
    @State private var didWarmup = false

    @State private var showOnboarding = !OnboardingFlag.seen && Launch.route == nil
    @State private var onboardingPage = 0
    @State private var crashReport: String?

    init() {
        Diagnostics.shared.start()
        ToolNotifications.shared.install()   // so a tapped tool reminder opens that tool
    }

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
            .copyToastHost()   // one shared "Copied" confirmation for every tool
            .onAppear {
                if let r = Launch.route, r.hasPrefix("onboarding") { onboardingPage = Int(r.dropFirst("onboarding".count)).map { $0 - 1 } ?? 0; showOnboarding = true }
                if crashReport == nil, !Launch.uitest { crashReport = Diagnostics.shared.takePendingCrash() }
            }
            .onOpenURL { url in
                // tenzy://run/<id> from the My Tools widget: open that Build-your-own tool ready to run.
                if url.scheme == "tenzy", url.host == "run", let id = url.pathComponents.dropFirst().first {
                    showOnboarding = false
                    ToolSchedules.setPending(id)
                    NotificationCenter.default.post(name: .openTool, object: "builder")
                    return
                }
                // tenzy://import?d=... from a shared tool link: save the tool, then open Build your own, where it shows as added.
                if url.scheme == "tenzy", url.host == "import" {
                    guard let tool = ToolLink.chain(from: url.absoluteString) else { return }
                    ChainStore.save(ChainStore.load() + [tool])
                    showOnboarding = false
                    NotificationCenter.default.post(name: .openTool, object: "builder")
                    return
                }
                // tenzy://tool/<id> from the home-screen widget or Shortcuts
                guard url.scheme == "tenzy", url.host == "tool", let id = url.pathComponents.dropFirst().first, TOOLS.contains(where: { $0.id == id }) else { return }
                showOnboarding = false
                NotificationCenter.default.post(name: .openTool, object: id)
            }
            .task {
                if !didWarmup {
                    await MainActor.run {
                        didWarmup = true
                        KeyboardDismiss.shared.install()   // tap anywhere outside a field to dismiss the keyboard, app-wide
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

    /// The everyday basics stay free; everything else is a Pro tool. One place to tune the split.
    static let freeIDs: Set<String> = ["light", "qrwifi", "seeread", "measure", "cleaner", "translate", "vault"]
    var pro: Bool { !Tool.freeIDs.contains(id) }
}

/// The full catalog: 30 tools across 3 pages of 10.
///   Page 1 — Photo, video & sharing: shoot, edit, convert, shrink, redact, share.
///   Page 2 — Scan, read & organize: scan/extract documents, read & translate text, sort admin.
///   Page 3 — Tools, sensors & accessibility: flashlight, measure, GPS, audio, and see/hear helpers.
/// (AI tools run free and private on-device, with a graceful fallback on older phones.)
@MainActor let TOOLS: [Tool] = [
    // ── Page 1 · Photo, video & sharing ──────────────────────────
    Tool(id: "studio",     name: "Studio",           blurb: "Enhance, cut out, passport, resize", icon: "photo.on.rectangle.angled",           page: 1, asset: "tool_studio", keywords: ["photo","image","enhance","upscale","sharpen","denoise","auto","fix","background","remove","cutout","passport","id photo","resize","convert","heic","jpg","png","crop"]),
    Tool(id: "procam",     name: "Pro Camera",       blurb: "Manual ISO, shutter, RAW",          icon: "camera.aperture",                     page: 1, asset: "tool_procam", keywords: ["camera","manual","iso","shutter","exposure","raw","dng","focus","long exposure","night","timelapse","histogram"]),
    Tool(id: "video",      name: "Video",            blurb: "Shrink, trim, convert, GIF",        icon: "film.stack.fill",                     page: 1, asset: "tool_video", keywords: ["video","compress","shrink","trim","cut","convert","mp4","mov","mute","audio","extract","gif","clip"]),
    Tool(id: "formatfix",  name: "Format Fixer",     blurb: "HEIC/MOV → JPG/MP4, in batch",      icon: "arrow.triangle.2.circlepath",         page: 1, asset: "tool_formatfix", keywords: ["heic","jpg","jpeg","png","mov","mp4","convert","format","batch","won't open","upload","share"]),
    Tool(id: "fitit",      name: "Fit It",           blurb: "Shrink to an exact size limit",     icon: "square.resize.down",                  page: 1, asset: "tool_fitit", keywords: ["compress","size","mb","kb","limit","upload","email","shrink","reduce","smaller","too big","pdf","photo","video","fit"]),
    Tool(id: "scrub",      name: "Privacy Scrubber", blurb: "Strip location, redact for good",   icon: "eye.slash.fill",                      page: 1, asset: "tool_scrub", keywords: ["privacy","metadata","exif","gps","location","strip","redact","blur","face","plate","hide","censor","share safe"]),
    Tool(id: "identify",   name: "Identify",         blurb: "What is this? Point and know",      icon: "viewfinder.circle.fill",              page: 1, asset: "tool_describe", keywords: ["identify","what is this","plant","flower","tree","animal","dog","breed","bug","insect","object","landmark","barcode","product","recognize","scan","camera","lookup"]),
    Tool(id: "stitch",     name: "Long Screenshot",  blurb: "Stitch shots into one tall image",  icon: "rectangle.split.1x2.fill",            page: 1, asset: "tool_stitch", keywords: ["screenshot","long","stitch","scroll","combine","merge","tall","chat","thread","full page"]),
    Tool(id: "qrwifi",     name: "QR & Wi‑Fi",       blurb: "Scan, make & share Wi‑Fi codes",    icon: "qrcode",                              page: 1, asset: "tool_qrwifi", keywords: ["qr","code","barcode","wifi","wi-fi","password","share","guest","generate","make","scan"]),
    Tool(id: "cleaner",    name: "Cleaner",          blurb: "Free space: dupes & big files",     icon: "sparkles",                            page: 1, asset: "tool_cleaner", keywords: ["clean","cleaner","storage","space","free up","duplicate","duplicates","screenshots","large","big","videos","photos","photo","images","image","pictures","delete","declutter","full"]),
    // ── Page 2 · Scan, read & organize ────────────────────────
    Tool(id: "scan",       name: "Scan",             blurb: "Scan, OCR, sign & fill PDFs",       icon: "doc.viewfinder.fill",                 page: 2, asset: "tool_scan", keywords: ["scan","scanner","document","pdf","ocr","sign","signature","fill","form","flatten","merge","split","pages","business card","handwriting"]),
    Tool(id: "datagrab",   name: "Data Grabber",     blurb: "Receipt → rows, contacts, dates",   icon: "tablecells.fill",                     page: 2, ai: true, asset: "tool_datagrab", keywords: ["receipt","table","data","extract","csv","spreadsheet","contact","business card","calendar","event","expense","ai"]),
    Tool(id: "pdfredact",  name: "Redact",            blurb: "Black out text so it's truly gone",  icon: "eye.slash.fill",                      page: 2, asset: "tool_scrub", keywords: ["redact","redaction","black out","hide","censor","pdf","private","confidential","remove","text","sign","signature","leak","cover"]),
    Tool(id: "sorted",     name: "Sorted",           blurb: "Snap a bill → calendar it",         icon: "calendar.badge.plus",                 page: 2, ai: true, asset: "tool_sorted", keywords: ["sorted","bill","letter","mail","document","appointment","form","notice","invoice","due","deadline","calendar","remind","reminder","scan","amount","pay","admin","paperwork"]),
    Tool(id: "memory",     name: "Memory",           blurb: "Ask your screenshots anything",     icon: "doc.text.magnifyingglass",            page: 2, ai: true, asset: "tool_memory", keywords: ["memory","find","search","photos","screenshot","screenshots","wifi","password","code","confirmation","parking","remember","where","receipt","ask","my photos","camera roll","saved"]),
    Tool(id: "warranty",   name: "Warranty & Receipts", blurb: "File receipts, never miss a warranty", icon: "shippingbox.fill",                 page: 2, asset: "tool_shareready", keywords: ["warranty","receipt","receipts","proof of purchase","vault","store","shoebox","expiry","expires","return","refund","find receipt","search receipt","appliance","electronics","guarantee"]),
    Tool(id: "textstudio", name: "Text Studio",      blurb: "Fix, rewrite, reply, summarize",    icon: "text.badge.checkmark",                page: 6, ai: true, asset: "tool_textstudio", keywords: ["text","grammar","proofread","rewrite","tone","reply","summarize","summary","edit","polish","email","message","ai"]),
    Tool(id: "thinking",   name: "Thinking tools",   blurb: "Untangle, plan the day, decide, explain, reword", icon: "brain.head.profile",       page: 6, ai: true, asset: "tool_explain", keywords: ["think","thinking","untangle","plan my day","decide","decision","crossroads","explain","plain english","reword","rewrite","tone","brain dump","clear my head","prep","checklist","focus","overwhelmed","steps","to-do","todo","ai"]),
    Tool(id: "medreminder", name: "Medicine Reminders", blurb: "Reminders with a Taken button",   icon: "pills.fill",                          page: 6, asset: "tool_rest", keywords: ["medicine","medication","pill","pills","tablet","dose","reminder","medicine reminder","pill reminder","vitamins","refill","prescription","take my meds"]),
    Tool(id: "pdfannotate", name: "Annotate",        blurb: "Highlight & draw on a PDF, baked in", icon: "highlighter",                        page: 4, asset: "tool_scan", keywords: ["annotate","annotation","highlight","highlighter","marker","markup","mark up","draw","drawing","pen","freehand","note","notes","comment","pdf"]),
    Tool(id: "pdfconvert", name: "Convert",          blurb: "PDF → image pages or text",         icon: "doc.on.doc",                          page: 4, asset: "tool_scan", keywords: ["convert","pdf to image","pdf to text","extract text","pages","image","images","jpg","jpeg","png","picture","export","copy text"]),
    Tool(id: "pdfpages",   name: "Organize Pages",   blurb: "Reorder, rotate or remove pages",   icon: "rectangle.stack",                     page: 4, asset: "tool_scan", keywords: ["organize pages","reorder","rearrange","move pages","page order","rotate pages","turn pages","upside down","sideways","delete pages","remove pages","extract pages","drop a page","keep pages"]),
    Tool(id: "pdfsign",    name: "Sign",             blurb: "Sign any PDF with your signature",  icon: "signature",                           page: 4, asset: "tool_scan", keywords: ["sign","signature","signing","e-sign","esign","sign a document","initial","initials","contract","agreement","lease"]),
    Tool(id: "pdfprotect", name: "Protect",          blurb: "Password-lock or watermark a PDF",  icon: "lock.doc.fill",                       page: 4, asset: "tool_scan", keywords: ["password","protect","lock","unlock","remove password","encrypt","secure","watermark","confidential","draft","private"]),
    Tool(id: "pdfsearchable", name: "Make Searchable", blurb: "Search and copy text from a scan", icon: "text.viewfinder",                     page: 4, asset: "tool_scan", keywords: ["searchable","make searchable","ocr","selectable text","copy text from scan","find text","scanned","text layer"]),
    Tool(id: "pdfform",    name: "Fill a Form",      blurb: "Type into a form, tick its boxes",  icon: "list.bullet.rectangle.portrait",      page: 4, asset: "tool_scan", keywords: ["fill a form","fill in","form filler","application","tax form","checkbox","tick boxes","fillable","questionnaire","enrollment"]),
    Tool(id: "zipmaker",   name: "Make a Zip",       blurb: "Bundle files into one .zip",        icon: "doc.zipper",                          page: 4, asset: "tool_shareready", keywords: ["make a zip","zip files","create zip","bundle files","archive","compress files","send many files","package files","one file"]),
    Tool(id: "animate",    name: "Animate",          blurb: "Photos into a Reel, TikTok or Story", icon: "sparkles.rectangle.stack",          page: 7, asset: "tool_studio", keywords: ["animate","animation","slideshow","reel","reels","tiktok","shorts","story","ken burns","polaroid","film strip","cube","boomerang","photo video","video from photos","montage","collage video"]),
    Tool(id: "collage",    name: "Collage",          blurb: "Photos into one designed picture",   icon: "square.grid.3x3.square",              page: 7, asset: "tool_stitch", keywords: ["collage","photo collage","grid","mosaic","photo strip","layout","combine photos","story collage","photo grid","moodboard"]),
    Tool(id: "audioconvert", name: "Audio Convert",  blurb: "Swap formats: M4A, WAV, AIFF, CAF",  icon: "waveform.path",                       page: 5, asset: "tool_audiolab", keywords: ["audio convert","audio converter","audio format","convert audio","extract audio","audio from video","video to audio","m4a","wav","aiff","caf","aac","mp3 to m4a","change audio format","sound file","audio file","music file"]),
    Tool(id: "audiocompress", name: "Compress Audio", blurb: "Shrink a recording to email it",    icon: "arrow.down.right.and.arrow.up.left.circle", page: 5, asset: "tool_audiolab", keywords: ["compress audio","shrink audio","smaller audio","audio too big","file too large","email a recording","reduce audio size","make smaller","bitrate","voice memo size"]),
    Tool(id: "ringtone",   name: "Ringtone",         blurb: "Trim a clip to a 30s ringtone",     icon: "bell.badge.fill",                     page: 5, asset: "tool_audiolab", keywords: ["ringtone","ring tone","ringtones","m4r","custom ringtone","make a ringtone","phone ringtone","song to ringtone","alarm sound"]),
    Tool(id: "audioedit",  name: "Audio Editor",     blurb: "Trim, fade & cut dead air",         icon: "waveform.badge.minus",                page: 5, asset: "tool_audiolab", keywords: ["audio editor","edit audio","trim audio","cut audio","shorten audio","crop audio","fade","fade in","fade out","silence","remove silence","cut silence","dead air","gap"]),
    Tool(id: "audiomix",   name: "Join & Speed",     blurb: "Join clips, speed up or slow down", icon: "link.circle.fill",                    page: 5, asset: "tool_audiolab", keywords: ["join audio","merge audio","combine audio","join clips","stitch","append","speed up audio","slow down audio","playback speed","faster","slower","2x","lecture speed"]),
    Tool(id: "audiotags",  name: "Song Info & Cover", blurb: "Title, artist, album & cover art",  icon: "music.note.list",                     page: 5, asset: "tool_audiolab", keywords: ["album art","cover art","song info","song title","artist","album","id3","tags","rename song","music tags","metadata","artwork"]),
    Tool(id: "audioclean", name: "Audio Cleanup",    blurb: "Cut noise, even out volume",        icon: "wand.and.stars",                      page: 5, asset: "tool_audiolab", keywords: ["audio cleanup","clean up audio","clean audio","noise reduction","reduce noise","background noise","remove noise","hiss","hum","rumble","clearer","clearer voice","voice clarity","boost volume","normalize audio","even out volume","louder","noisy recording"]),
    Tool(id: "meetingnotes", name: "Meeting Notes",  blurb: "Recording → turns, to-dos, email",  icon: "person.wave.2.fill",                  page: 5, ai: true, asset: "tool_voicenotes", keywords: ["meeting notes","meeting","meeting minutes","minutes","recap","meeting recap","action items","meeting recording","record a meeting","call notes","interview","standup","stand-up","follow-up email","follow up email","turns","who said what"]),
    Tool(id: "soundboard", name: "Soundboard",       blurb: "Robot, alien & more — change a voice", icon: "theatermasks.fill",                 page: 5, asset: "tool_audiolab", keywords: ["soundboard","voice changer","change my voice","change voice","robot voice","alien voice","monster voice","chipmunk","helium","giant","deep voice","funny voice","voice effect","voice fx","disguise","prank"]),
    Tool(id: "translate",  name: "Translate",        blurb: "Text, camera, voice — offline",     icon: "character.bubble.fill",               page: 2, asset: "tool_translate", keywords: ["translate","translation","language","offline","camera","voice","conversation","spanish","french","menu","sign"]),
    Tool(id: "voicenotes", name: "Voice → Notes",    blurb: "Transcript, summary, to‑dos",       icon: "waveform.badge.mic",                  page: 2, ai: true, asset: "tool_voicenotes", keywords: ["voice","record","transcribe","transcript","meeting","notes","summary","action items","dictation","audio","speech","ai"]),
    Tool(id: "shield",     name: "Message Shield",   blurb: "Spot scams, see why",               icon: "shield.lefthalf.filled",              page: 2, ai: true, asset: "tool_shield", keywords: ["scam","phishing","spam","fraud","suspicious","text","email","link","safe","check","is this real","mom","ai"]),
    Tool(id: "contacts",   name: "Contacts",         blurb: "Find duplicates, merge & back up",  icon: "person.2.fill",                       page: 2, asset: "tool_contacts", keywords: ["contacts","duplicate","duplicates","merge","dedupe","de-dupe","backup","back up","vcf","vcard","export","phone","address book","clean up contacts"]),
    // ── Page 3 · Tools, sensors & accessibility ──────────────────
    Tool(id: "light",      name: "Flashlight+",      blurb: "Strobe, SOS, screen light, mirror", icon: "flashlight.on.fill",                  page: 3, asset: "tool_light", keywords: ["flashlight","torch","light","strobe","sos","morse","screen light","mirror","selfie","dark","blink"]),
    Tool(id: "measure",    name: "Measure",          blurb: "AR tape: distance, height, area",   icon: "ruler.fill",                          page: 3, asset: "tool_measure", keywords: ["measure","tape","ruler","distance","height","area","room","ar","lidar","length","how tall","how far"]),
    Tool(id: "gpsdash",    name: "GPS Dashboard",    blurb: "Speed, heading, altitude, HUD",     icon: "speedometer",                         page: 3, asset: "tool_gpsdash", keywords: ["speed","speedometer","gps","heading","altitude","hud","trip","drive","bike","mph","kph","dashboard"]),
    Tool(id: "audiolab",   name: "Audio Lab",        blurb: "Tuner, tones, speaker test",        icon: "waveform",                            page: 3, asset: "tool_audiolab", keywords: ["tuner","guitar","pitch","tone","frequency","generator","speaker","test","earbuds","left right","water","eject","sound"]),
    Tool(id: "rest",       name: "Rest",             blurb: "White noise + snore recorder",      icon: "moon.zzz.fill",                       page: 3, asset: "tool_rest", keywords: ["sleep","white noise","pink","brown","rain","fan","noise","timer","snore","record","night","relax","focus"]),
    Tool(id: "seeread",    name: "See & Read",       blurb: "Read, hear & magnify anything",     icon: "eye.square.fill",                     page: 3, ai: true, asset: "tool_magnify", keywords: ["see","read","magnifier","magnify","zoom","fine print","small text","contrast","loupe","glasses","read aloud","listen","tts","speak","ocr","text","simplify","plain english","describe","scene","blind","low vision","narrate","accessibility","lens"]),
    Tool(id: "colorvision",name: "Color Vision",     blurb: "Live color‑blind correction",       icon: "eyeglasses",                          page: 3, asset: "tool_colorvision", keywords: ["color","colour","blind","colorblind","daltonize","correct","name the color","what color","red green","accessibility","eyedropper","hex","paint"]),
    Tool(id: "fileviewer", name: "File Opener",      blurb: "Open almost any file",              icon: "doc.fill",                            page: 3, asset: "tool_lens", keywords: ["file","open","opener","viewer","docx","pages","keynote","numbers","xls","zip","epub","unknown","won't open","can't open","any file"]),
    Tool(id: "pricecheck", name: "Price Check",      blurb: "Best deal, budget & label decode",  icon: "tag.fill",                            page: 3, asset: "tool_livecaptions", keywords: ["price","unit price","compare","deal","cheaper","per 100g","per unit","budget","cart","shopping","grocery","value","label","ingredients","nutrition","additives","allergens"]),
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
/// Turns OFF the NavigationStack edge swipe-back while a tool is on screen. Tools need horizontal
/// drags of their own (Cleaner's drag-to-select, Scrub's redaction, crop/trim handles, sliders), and
/// the system back-swipe was stealing those gestures — a drag would pop the tool and peek the home
/// grid instead of doing the tool's job. The nav-bar Back button is always present, so back is never
/// lost. The gesture is restored when the tool is dismissed.
private struct NoSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { Holder() }
    func updateUIViewController(_ vc: UIViewController, context: Context) {}
    final class Holder: UIViewController {
        private func nav() -> UINavigationController? {
            var p: UIViewController? = self
            while let cur = p { if let n = cur as? UINavigationController { return n }; p = cur.parent }
            return navigationController
        }
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            nav()?.interactivePopGestureRecognizer?.isEnabled = false
        }
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            nav()?.interactivePopGestureRecognizer?.isEnabled = false
        }
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            nav()?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}
extension View {
    func disablesSwipeBack() -> some View {
        background(NoSwipeBack().frame(width: 0, height: 0).accessibilityHidden(true))
    }
}

struct ToolDestination: View {
    let id: String
    @EnvironmentObject var store: StoreManager
    var body: some View {
        // Pro tools show the unlock screen for free users. Test/screenshot builds bypass the gate so
        // the every-tool smoke suite and the store-screenshot capture still reach the real tools.
        Group {
            if let tool = TOOLS.first(where: { $0.id == id }), tool.pro, !store.isPremium, !Launch.uitest, !Launch.screenshots, !AppEnv.isTestBuild {
                ProLockView(tool: tool)
            } else {
                destination
            }
        }
        // Carry the tool id down into the shared ToolPage scaffold so it can show the right page art.
        .environment(\.toolID, id)
    }

    @ViewBuilder private var destination: some View {
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
        case "contacts": ContactsView()
        case "magnify": MagnifierView()
        // ── Page 3 ──
        case "translate": TranslateView()
        case "voicenotes": VoiceNotesView()
        case "livecaptions": LiveCaptionsView()
        case "cleaner": CleanerView()
        // Everything else is being built — show an honest placeholder, never a blank screen.
        case "lens": LensView()
        case "memory": MemoryView()
        case "sorted": SortedView()
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
        case "thinking": ThinkingHubView()
        case "vault": VaultView()
        case "fileviewer": FileViewerView()
        case "warranty": WarrantyView()
        case "pricecheck": PriceCheckView()
        case "identify": IdentifyView()
        case "seeread": SeeReadView()
        case "pdfredact": PDFRedactView()
        case "pdfannotate": PDFAnnotateView()
        case "pdfconvert": PDFConvertView()
        case "pdfpages": PDFPagesView()
        case "pdfsign": SignPDFView()
        case "pdfprotect": PDFProtectView()
        case "pdfsearchable": PDFSearchableView()
        case "pdfform": PDFFormView()
        case "zipmaker": ZipMakerView()
        case "animate": AnimateView()
        case "collage": CollageView()
        case "medreminder": MedRemindersView()
        case "audioconvert": AudioConvertView()
        case "audiocompress": AudioCompressView()
        case "audiomix": AudioMixView()
        case "audiotags": AudioTagsView()
        case "ringtone": RingtoneView()
        case "audioedit": AudioEditView()
        case "audioclean": AudioCleanView()
        case "meetingnotes": MeetingNotesView()
        case "soundboard": SoundboardView()
        default: ComingSoonView(id: id)
        }
    }
}

enum AppEnv {
    /// True in TestFlight and App Store review (both use a sandbox receipt) and in Debug builds — so
    /// beta testers and reviewers can open every tool without paying. A real App Store install has a
    /// production receipt, so the Pro gate stays on for paying users.
    static var isTestBuild: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
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

/// The three home destinations of the rebuilt interface. Build is the front door (make a tool),
/// Search is the powerful way into any single tool, Settings holds the map, themes and Pro.
enum RootTab { case build, explore, search, settings }

/// The bottom tab bar for the three home destinations.
private struct TenzyTabBar: View {
    @Binding var selection: RootTab
    var body: some View {
        HStack(spacing: 0) {
            item(.build, "square.stack.3d.up.fill", "Build")
            item(.explore, "square.grid.2x2.fill", "Explore")
            item(.search, "magnifyingglass", "Search")
            item(.settings, "gearshape.fill", "Settings")
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(HandyColor.surface)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(HandyColor.border), alignment: .top)
    }
    @ViewBuilder private func item(_ t: RootTab, _ icon: String, _ label: String) -> some View {
        Button { selection = t } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(L(label)).font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(selection == t ? HandyColor.accent : HandyColor.textSecondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(t == .build ? "builder-entry" : label.lowercased() + "-tab")
    }
}

/// Empty state for the Search tab before anything is typed.
private struct SearchPrompt: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 34)).foregroundStyle(HandyColor.textSecondary)
            Text(L("Search every tool")).font(HandyFont.cardTitle)
            Text(L("Type what you want to do — shrink a photo, scan a receipt, make a QR code."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HomeView: View {
    @EnvironmentObject var store: StoreManager
    @ObservedObject private var theme = ThemeManager.shared   // re-skin the home grid live on a theme change
    @State private var showPaywall = false
    @State private var page = 1
    @State private var tab: RootTab = .build
    @State private var search = ""
    @FocusState private var searching: Bool
    @State private var path: [String] = Launch.route.flatMap { $0.hasPrefix("onboarding") || $0 == "paywall" || $0 == "home" || $0 == "homepro" ? nil : [$0] } ?? []

    private let captions = ["Everyday essentials", "Power tools", "AI · on your phone", "Think & plan"]

    /// True while the search box has text — the grid is replaced by results that span every page.
    private var hasSearch: Bool { !search.trimmingCharacters(in: .whitespaces).isEmpty }
    /// Subtitle under the wordmark: a live result count while searching, else the page name.
    private var headerCaption: String {
        if hasSearch { let n = searchTools(search).count; return "\(n) result\(n == 1 ? "" : "s")" }
        return store.isPremium ? "Pro · unlimited" : captions[page - 1]
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Group {
                    switch tab {
                    case .build:
                        // The front door: the Builder's own start screen (Describe it · Start with
                        // what you have · Ready-made) is the home now.
                        BuilderView()
                    case .explore:
                        // The browse home: every tool, one tap away, grouped by what it's for.
                        ExploreView()
                    case .search:
                        VStack(spacing: 0) {
                            SearchField(text: $search, focused: $searching)
                                .padding(.horizontal, HandySpacing.gutter)
                                .padding(.vertical, HandySpacing.s8)
                                .accessibilityIdentifier("tool-search")
                            if hasSearch { SearchResults(query: search) } else { SearchPrompt() }
                        }
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                BannerAd()
                TenzyTabBar(selection: $tab)
            }
            .id(theme.current)   // force a full re-skin of the grid when the theme changes
            .background(Ground())
            .navigationDestination(for: String.self) { id in
                switch id {
                case "settings": SettingsView().toolbarRole(.editor)
                case "alltools": AllToolsView().toolbarRole(.editor)
                case "setup": SetupView(onDone: { path.removeLast() }).toolbarRole(.editor)
                case "privacy": PrivacyView().toolbarRole(.editor)
                case "builder": BuilderView().toolbarRole(.editor)
                default: ToolDestination(id: id).toolbarRole(.editor).disablesSwipeBack()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: path) { _, p in searching = false; if p.last == "paywall" { path.removeLast(); showPaywall = true } }
            .onAppear {
                if Launch.route == "paywall" { showPaywall = true }
                if ToolSchedules.hasPending { path = ["builder"] }   // launched by tapping a tool reminder
            }
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
                    Text(L("Tenzy")).font(HandyFont.display)
                    // Tapping a page tab always leaves search and shows that page — so the tabs are
                    // never dead while a search is up (the "con" bug: tabs changed only the caption).
                    PageTabs(page: $page, active: !hasSearch) { n in
                        withAnimation(.easeOut(duration: HandyMotion.fast)) { page = n; search = "" }
                        searching = false
                    }
                }
                Text(headerCaption)
                    .font(.system(size: 14)).foregroundStyle(HandyColor.textSecondary)
                    .animation(.easeOut(duration: HandyMotion.fast), value: page)
            }
            Spacer()
            HStack(spacing: HandySpacing.s8) {
                if !store.isPremium {
                    Button { showPaywall = true } label: {
                        Image(systemName: "crown.fill").font(.system(size: 18)).foregroundStyle(HandyColor.accent)
                            .frame(width: 40, height: 40).background(HandyColor.accentSoft, in: Circle())
                    }.accessibilityLabel(L("Go Pro"))
                }
                NavigationLink(value: "settings") {
                    Image(systemName: "gearshape").font(.system(size: 18)).foregroundStyle(HandyColor.textSecondary).frame(width: 40, height: 40)
                }.accessibilityLabel(L("Settings"))
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
    /// While a search is showing, no tab reads as "selected" (you're not on a page).
    var active: Bool = true
    var onPick: (Int) -> Void
    var body: some View {
        HStack(spacing: HandySpacing.s4) {
            ForEach(1...3, id: \.self) { n in
                let on = active && page == n
                Button { onPick(n) } label: {
                    Text("\(n)")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(on ? HandyColor.accent : HandyColor.accentSoft, in: Circle())
                        .foregroundStyle(on ? Color.white : HandyColor.accent)
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
            TextField(L("Search 30 tools…"), text: $text)
                .focused(focused)
                .autocorrectionDisabled().textInputAutocapitalization(.never).submitLabel(.search)
                .onSubmit { focused.wrappedValue = false }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(L("Done")) { focused.wrappedValue = false }
                    }
                }
            if !text.isEmpty {
                Button { text = ""; focused.wrappedValue = false } label: { Image(systemName: "xmark.circle.fill").accessibilityLabel(L("Clear")).foregroundStyle(HandyColor.textSecondary) }
                    .accessibilityLabel(L("Clear search"))
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
                    Text(L("Try “photo”, “pdf”, “scan”, or “ai”.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
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

/// One page of ten tools, 2 across. Cards size to their content (icon + title + 2-line blurb) inside a
/// scroll view, so a longer blurb like "White noise + snore recorder" is never clipped. It fills the
/// page without scrolling where there's room, and scrolls a little on shorter phones instead of cutting
/// text off — the earlier fixed 2×5 "fill the screen" grid forced each row too short and clipped blurbs.
struct ToolGridPage: View {
    @EnvironmentObject var store: StoreManager
    let page: Int
    private let cols = [GridItem(.flexible(), spacing: HandySpacing.s12), GridItem(.flexible(), spacing: HandySpacing.s12)]
    var body: some View {
        GeometryReader { geo in
            let items = tools(onPage: page)
            let rows = max(1, Int(ceil(Double(items.count) / 2.0)))   // 2 columns
            let vInsets = HandySpacing.s4 + HandySpacing.s12          // top + bottom padding below
            let gaps = HandySpacing.s12 * CGFloat(rows - 1)
            // Grow the rows to fill the page as equal blocks; never below the readable minimum (then it
            // scrolls on a short phone instead of clipping). This removes the dead space at the bottom.
            let rowH = max(104, (geo.size.height - vInsets - gaps) / CGFloat(rows))
            ScrollView {
                LazyVGrid(columns: cols, spacing: HandySpacing.s12) {
                    ForEach(items) { t in
                        NavigationLink(value: t.id) { ToolCard(tool: t, height: rowH) }.buttonStyle(ToolCardPress())
                    }
                }
                .padding(.horizontal, HandySpacing.gutter)
                .padding(.top, HandySpacing.s4)
                .padding(.bottom, HandySpacing.s12)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// The full catalog on its own page, reached from Settings → "What Tenzy does". Every tool is a visual
/// card (its themed art / gradient), grouped by what each of the three pages is for, tap to open. This
/// is what moved out of Settings so that screen stays short and sharp.
struct AllToolsView: View {
    @EnvironmentObject var store: StoreManager
    @ObservedObject private var theme = ThemeManager.shared
    private let cols = [GridItem(.flexible(), spacing: HandySpacing.s12), GridItem(.flexible(), spacing: HandySpacing.s12)]
    private let groups: [(title: String, page: Int)] = [
        ("Photo, video & sharing", 1), ("Animate & create", 7), ("Scan, read & organize", 2), ("Tools, sensors & accessibility", 3), ("Documents & PDF", 4), ("Audio & voice", 5), ("Plan, health & reminders", 6)
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s24) {
                Text(L("Every tool in one place — tap any to open it. It all runs on your phone."))
                    .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, HandySpacing.gutter)
                ForEach(groups, id: \.page) { group in
                    VStack(alignment: .leading, spacing: HandySpacing.s12) {
                        Text(group.title.uppercased()).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                            .padding(.horizontal, HandySpacing.gutter)
                        LazyVGrid(columns: cols, spacing: HandySpacing.s12) {
                            ForEach(tools(onPage: group.page)) { t in
                                NavigationLink(value: t.id) { ToolCard(tool: t, height: 128) }.buttonStyle(ToolCardPress())
                            }
                        }
                        .padding(.horizontal, HandySpacing.gutter)
                    }
                }
            }
            .padding(.top, HandySpacing.s12)
            .padding(.bottom, HandySpacing.s24)
        }
        .background(Ground())
        .id(theme.current)   // re-skin live if the theme changes while this page is open
        .navigationTitle(L("What Tenzy does"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Tool {
    /// A stable, colourful gradient for the Aurora look — each tool keeps the same pair, spread across C's palette.
    var auroraGradient: [Color] {
        let sets: [[UInt32]] = [[0x7B5CFF, 0xFF4FA3], [0xFF4FA3, 0xFF9A3D], [0x2FD9FF, 0x7B5CFF], [0xD2FF3A, 0x2FD9FF], [0xFFD93D, 0xFF9A3D], [0xFF4FA3, 0x7B5CFF], [0x2FD9FF, 0xD2FF3A]]
        var h = 5381; for b in id.utf8 { h = (h &* 33) &+ Int(b) }
        let s = sets[abs(h) % sets.count]
        return [Color(hex: s[0]), Color(hex: s[1])]
    }
}

/// Home grid card. The tool's themed illustration fills the card as a background LAYER; a scrim
/// fades it into the surface colour toward the bottom; the icon, name and blurb sit on top as the
/// last ZStack layer, so they are always drawn over the art and can never be hidden by it. (The
/// previous "solid header band + 34pt art strip" VStack collapsed on device — the greedy
/// scaledToFill strip art expanded to the whole card and buried the text. A ZStack with the text on
/// top is immune to that.)
struct ToolCard: View {
    @EnvironmentObject var store: StoreManager
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme
    let tool: Tool
    var height: CGFloat = 104   // grid passes a taller value to fill the screen evenly; search keeps the default
    var body: some View {
        let aurora = theme.current == .aurora
        let artName = TenzyArt.name(id: tool.id, theme: theme.current, scheme: scheme, kind: .card)
        ZStack {
            if aurora {
                // Direction C: a flat colourful gradient instead of the per-tool art, with a soft dark foot so the text reads.
                LinearGradient(colors: tool.auroraGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.0), location: 0.42),
                    .init(color: .black.opacity(0.50), location: 1.0)
                ], startPoint: .top, endPoint: .bottom)
            } else {
                HandyColor.surface
                Image(artName).resizable().scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .allowsHitTesting(false)
                // Scrim: art shows through the top, deepening to the surface colour over the bottom third
                // so the title + blurb read clearly in any theme, light or dark.
                LinearGradient(
                    stops: [
                        .init(color: HandyColor.surface.opacity(0.0), location: 0.35),
                        .init(color: HandyColor.surface.opacity(0.70), location: 0.62),
                        .init(color: HandyColor.surface.opacity(0.97), location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .overlay(alignment: .bottomLeading) {
            // Anchored to the bottom as an overlay (sized to its own content), so it can never
            // overflow or be clipped by the card the way a greedy VStack did.
            VStack(alignment: .leading, spacing: 1) {
                Text(L(tool.name)).font(HandyFont.cardTitle).foregroundStyle(aurora ? Color.white : HandyColor.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
                Text(L(tool.blurb)).font(HandyFont.caption).foregroundStyle(aurora ? Color.white.opacity(0.85) : HandyColor.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(.horizontal, HandySpacing.s12)
            .padding(.bottom, HandySpacing.s8)
        }
        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
        .overlay(alignment: .topLeading) {
            ToolIconBadge(id: tool.id, symbol: tool.icon, size: 40)
                .padding(.leading, HandySpacing.s8).padding(.top, HandySpacing.s8)
        }
        .overlay(alignment: .topTrailing) {
            if tool.pro && !store.isPremium {
                Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 3).padding(8)
            } else if tool.ai {
                Image(systemName: "sparkle").font(.system(size: 11)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3).padding(8)
            }
        }
    }
}

/// Shown in place of a Pro tool for free users: what the tool is, and a one-tap path to the trial.
struct ProLockView: View {
    @EnvironmentObject var store: StoreManager
    let tool: Tool
    var body: some View {
        ToolPage(title: L(tool.name), subtitle: L(tool.blurb)) {
            VStack(spacing: HandySpacing.s16) {
                ZStack {
                    Circle().fill(HandyColor.accentSoft).frame(width: 72, height: 72)
                    Image(systemName: "lock.fill").font(.system(size: 30)).foregroundStyle(HandyColor.accent)
                }.padding(.top, HandySpacing.s32)
                Text(L("A Pro tool")).font(.system(size: 22, weight: .bold))
                Text(store.showsFreeTrial
                     ? "\(tool.name) is part of Tenzy Pro. Start a \(store.trialLength) free trial to unlock it and every other Pro tool — unlimited use, no daily limits."
                     : "\(tool.name) is part of Tenzy Pro. Go Pro to unlock it and every other Pro tool — unlimited use, no daily limits.")
                    .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                Button { NotificationCenter.default.post(name: .showPaywall, object: nil) } label: {
                    Label(store.showsFreeTrial ? "Start \(store.trialLength) free trial" : "Go Pro — \(store.yearlyPrice)/year", systemImage: "crown.fill").frame(maxWidth: .infinity)
                }.primaryButton()
                Text(store.showsFreeTrial ? "Then \(store.yearlyPrice)/year · cancel anytime" : "\(store.yearlyPrice)/year · cancel anytime").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }.frame(maxWidth: .infinity).padding(.horizontal, HandySpacing.s8)
        }
    }
}

struct ToolCardPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? HandyMotion.pressScale : 1)
            .animation(.easeOut(duration: HandyMotion.fast), value: configuration.isPressed)
    }
}

/// Paywall sheet. Two honest plans, yearly preselected. No timers, no fake discounts.
struct PaywallView: View {
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: HandySpacing.s16) {
            ZStack {
                Circle().fill(HandyColor.accentSoft).frame(width: 64, height: 64)
                Image(systemName: "crown.fill").font(.system(size: 28)).foregroundStyle(HandyColor.accent)
            }.padding(.top, HandySpacing.s24)
            Text(L("Tenzy Pro")).font(.system(size: 28, weight: .bold))
            Text(L("Every tool and every builder step. No daily limits.")).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)

            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                ForEach(["Unlock all \(TOOLS.count) tools", "Every Build-your-own step, unlimited saved tools", "Every theme unlocked", "No daily limits — build and run freely"], id: \.self) { line in
                    HStack(spacing: HandySpacing.s12) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(HandyColor.accent)
                        Text(line).font(HandyFont.body)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, HandySpacing.s8)

            Spacer()

            // In TestFlight / App Review (sandbox receipt) every tool is already unlocked, but the
            // purchase screen must still show the real price, trial terms and Buy button so a
            // reviewer can find and complete the subscription (Guidelines 2.1(b), 3.1.2).
            if store.isPremium && !AppEnv.isTestBuild {
                Label(L("You're Pro. Thank you."), systemImage: "checkmark.circle.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success)
            } else {
                if store.isPremium && !Launch.screenshots {
                    Text(L("Test build: every tool is already unlocked. You can still try the purchase below with a sandbox account."))
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                }
                PlanRow(selected: true, title: "Yearly", price: store.yearlyPrice, caption: store.showsFreeTrial ? "\(store.trialLength) free trial, then yearly" : "Renews yearly · cancel anytime", badge: nil) { }

                Button {
                    Task { let was = store.isPremium; await store.purchase(store.yearly); if store.isPremium && !was { dismiss() } }
                } label: {
                    Text(store.showsFreeTrial ? "Start \(store.trialLength) free trial" : "Go Pro · \(store.yearlyPrice)/year").frame(maxWidth: .infinity)
                }.primaryButton()

                Text(store.showsFreeTrial
                     ? "\(store.trialLengthWords) free, then \(store.yearlyPrice)/year. Payment is charged to your Apple ID when the trial ends. Renews automatically unless cancelled at least 24 hours before the period ends, in Settings › Apple ID › Subscriptions."
                     : "\(store.yearlyPrice)/year. Payment is charged to your Apple ID. Renews automatically unless cancelled at least 24 hours before the period ends, in Settings › Apple ID › Subscriptions.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                HStack(spacing: HandySpacing.s24) {
                    Button(L("Restore purchases")) { Task { await store.restore() } }.textButton()
                    Button(L("Not now")) { dismiss() }.textButton()
                }
                // Guideline 3.1.2: functional Terms of Use (EULA) + Privacy Policy links at point of purchase.
                HStack(spacing: HandySpacing.s8) {
                    Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    Text(L("·")).foregroundStyle(HandyColor.textSecondary)
                    Link("Privacy Policy", destination: URL(string: "https://manan99991.github.io/tenzy/privacy.html")!)
                }
                .font(HandyFont.caption).foregroundStyle(HandyColor.accent)
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
                Text(L("Tenzy crashed last time")).font(HandyFont.bodyStrong).foregroundStyle(.white)
                Text(summary).font(HandyFont.micro).foregroundStyle(.white.opacity(0.9)).lineLimit(2)
            }
            Spacer(minLength: HandySpacing.s8)
            ShareLink(item: Diagnostics.shared.reportFileURL()) {
                Text(L("Send")).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
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
    /// True while the tool is doing async work. Keeps the job alive if the app is backgrounded and
    /// notifies the user when it finishes off-screen — one place, every tool that passes it.
    var working: Bool = false
    @ViewBuilder let content: () -> Content
    @Environment(\.toolID) private var toolID
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                // Tighter than the app-wide s16: a tool's controls should land on one screen without
                // scrolling, so the header + options stay compact (the ScrollView remains for the few
                // tools whose controls genuinely exceed one screen).
                VStack(alignment: .leading, spacing: HandySpacing.s12) {
                    HStack(spacing: HandySpacing.s12) {
                        if !toolID.isEmpty { ToolIconBadge(id: toolID, symbol: "square.grid.2x2", size: 44) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(HandyFont.title)
                            Text(subtitle).font(.system(size: 15)).foregroundStyle(HandyColor.textSecondary)
                        }
                    }
                    content()
                }
                .padding(.horizontal, HandySpacing.gutter)
                .padding(.vertical, HandySpacing.s8)
                .padding(.bottom, HandySpacing.s24)
            }
            .scrollDismissesKeyboard(.interactively)
            if let footer { footer }
            BannerAd()
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .background { ToolPageArt(id: toolID) }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Diagnostics.shared.currentTool = title }
        .finishes(working, tool: title)
    }
}

extension Notification.Name {
    static let openTool = Notification.Name("handytools.openTool")
    static let showPaywall = Notification.Name("handytools.showPaywall")
    static let showSetup = Notification.Name("handytools.showSetup")
}
