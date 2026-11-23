import Foundation

/// Home's category tabs (Manan, 23 Nov: "Contacts and other tabs are missing — make sure nothing is missing from the
/// home page"): eight tabs, all on screen at once (no sideways scrolling), and the tab you pick shows every one of its
/// tools as its own tile — at most nine, so a tab always fits without scrolling. Every tool sits in exactly one tab;
/// the only ones not listed are those that live inside another tool (`Tool.homes`), which open from that tool.
/// Pure, so a unit test proves nothing built is ever missing from Home.
enum HomeShelves {
    struct Shelf: Equatable, Identifiable {
        let id: String
        let title: String
        let line: String
        let icon: String
        let hex: UInt32
        let tools: [String]
    }

    /// A tab never holds more than this many tools (three rows of three), so it fits the screen.
    static let maxPerTab = 9

    static let all: [Shelf] = [
        Shelf(id: "camera", title: "Camera", line: "Point your camera: scan, identify, measure, read a menu",
              icon: "camera.fill", hex: 0x0EA5E9,
              tools: ["scan", "identify", "procam", "measure", "qrwifi", "menu", "cards", "datagrab", "colorvision"]),
        Shelf(id: "photos", title: "Photos", line: "Fix, cut out, hide, join and find your photos",
              icon: "photo.on.rectangle.angled", hex: 0xEC4899,
              tools: ["studio", "sticker", "collage", "comicstrip", "scrub", "stitch", "formatfix", "memory"]),
        Shelf(id: "video", title: "Video", line: "Shrink, trim, add effects, post, or make one from photos",
              icon: "film.fill", hex: 0x8B5CF6,
              tools: ["video", "celebrate", "post", "animate", "fitit"]),
        Shelf(id: "pdf", title: "PDF & files", line: "Sign, black out, fill, organize, lock and open files",
              icon: "doc.richtext.fill", hex: 0xEF4444,
              tools: ["pdfsign", "pdfredact", "pdfform", "pdfannotate", "pdfpages", "pdfconvert", "pdfprotect", "zipmaker", "fileviewer"]),
        Shelf(id: "audio", title: "Audio", line: "Edit recordings, ringtones, song info, sounds to sleep to",
              icon: "waveform", hex: 0xF59E0B,
              tools: ["audiostudio", "audioconvert", "audiotags", "soundboard", "audiolab", "rest"]),
        Shelf(id: "words", title: "Words", line: "Write, translate, notes from speech, read aloud, spot scams, think",
              icon: "text.bubble.fill", hex: 0x22C55E,
              tools: ["textstudio", "translate", "speechnotes", "seeread", "shield", "thinking"]),
        Shelf(id: "day", title: "Daily life", line: "Medicine, plans, bills, moods, prices and receipts",
              icon: "calendar", hex: 0xF97316,
              tools: ["medreminder", "untangle", "planner", "brief", "daydiary", "sorted", "warranty", "pricewatch", "pricecheck"]),
        Shelf(id: "phone", title: "Contacts & phone", line: "Your contacts, flashlight, speed, space and a private vault",
              icon: "person.2.fill", hex: 0x14B8A6,
              tools: ["contacts", "light", "cleaner", "gpsdash", "vault"]),
    ]

    /// Tools Home opens straight from their own tile (no shelf needed).
    static let ownTiles: Set<String> = []

    /// The shelf a tool sits on, if any.
    static func shelf(of tool: String) -> Shelf? { all.first { $0.tools.contains(tool) } }

    /// "I run a small business" (Manan, 23 Nov: the Business tab shows only when the person says they're a business,
    /// in Settings or on the welcome screen, and Home adjusts). Off by default.
    static let businessKey = "tenzy.business"
    static var businessOn: Bool { UserDefaults.standard.bool(forKey: businessKey) }

    /// The Business tab. Its tiles are jobs (`businessJobs`), not general tools, so nothing repeats another tab.
    static let business = Shelf(id: "business", title: "Business", line: "Expenses, product photos, customers, contracts and QR codes",
                                icon: "briefcase.fill", hex: 0x0D9488, tools: [])

    /// Home's tabs: the eight for everyone, plus Business for people who run one (then the grid is 3 x 3).
    static func tabs(business: Bool) -> [Shelf] { business ? all + [business] : all }

    /// One Business job: a ready-made chain run straight away, or a tool. Every one has a job name that fits a tile.
    struct BusinessJob: Equatable, Identifiable {
        let id: String
        let title: String
        let icon: String
        let chain: String?     // a ready-made chain id (ChainTemplates)
        let tool: String?      // or a tool id
    }
    static let businessJobs: [BusinessJob] = [
        BusinessJob(id: "expense", title: "Log an expense", icon: "receipt.fill", chain: "receipt-run", tool: nil),
        BusinessJob(id: "product", title: "Product photo to sell", icon: "bag.fill", chain: "photo-sell", tool: nil),
        BusinessJob(id: "customer", title: "Save a customer", icon: "person.crop.rectangle.fill", chain: "card-to-contact", tool: nil),
        BusinessJob(id: "contract", title: "Sign and send back", icon: "signature", chain: "sign-and-send", tool: nil),
        BusinessJob(id: "reviewqr", title: "Review or menu QR code", icon: "qrcode", chain: "text-to-qr", tool: nil),
        BusinessJob(id: "mycard", title: "Share my contact", icon: "person.text.rectangle.fill", chain: "contact-qr", tool: nil),
        BusinessJob(id: "promo", title: "Post a promo video", icon: "megaphone.fill", chain: "video-post", tool: nil),
    ]

    /// What each Home tile says: the job, in the words people search with (Manan, 23 Nov, UX audit decision 1:
    /// "Scan a document", not "Scan"; "Copy a table", not "Data Grabber"). The tool keeps its own name on
    /// its own screen. Every name fits two lines on the narrowest iPhone (a unit test measures it).
    static let jobNames: [String: String] = [
        "scan": "Scan a document", "identify": "What is this?", "procam": "Take better photos", "measure": "Measure a room",
        "qrwifi": "Scan a QR code", "menu": "Read a menu", "cards": "Save a business card",
        "datagrab": "Copy a table", "colorvision": "Tell colors apart",
        "studio": "Fix a photo", "sticker": "Make a sticker", "collage": "Make a collage", "comicstrip": "Make a comic",
        "scrub": "Hide faces and location", "stitch": "Join screenshots", "formatfix": "Fix files that won't open",
        "memory": "Find a photo",
        "video": "Shrink or trim a video", "celebrate": "Add effects to a video", "post": "Size a video for social",
        "animate": "Turn photos into a video", "fitit": "Fit under a size limit",
        "pdfsign": "Sign a PDF", "pdfredact": "Black out text", "pdfform": "Fill in a form", "pdfannotate": "Mark up a PDF",
        "pdfpages": "Reorder PDF pages", "pdfconvert": "PDF to photos or text", "pdfprotect": "Lock a PDF",
        "zipmaker": "Zip files together", "fileviewer": "Open any file",
        "audiostudio": "Edit a recording", "audioconvert": "Change audio format", "audiotags": "Fix song info",
        "soundboard": "Change your voice", "audiolab": "Tune an instrument", "rest": "Sleep sounds",
        "textstudio": "Fix or rewrite text", "translate": "Translate anything", "speechnotes": "Notes from speech",
        "seeread": "Magnify and read aloud", "shield": "Is this a scam?", "thinking": "Think it through",
        "medreminder": "Medicine reminders", "untangle": "Plan my day", "planner": "Photo to checklist",
        "brief": "Morning summary", "daydiary": "Mood diary", "sorted": "Track a bill", "warranty": "Keep receipts",
        "pricewatch": "Watch a price", "pricecheck": "Compare prices",
        "contacts": "Contacts and backup", "light": "Flashlight and SOS", "cleaner": "Free up space",
        "gpsdash": "Find my car", "vault": "Hide private photos",
    ]
    static func jobName(_ id: String) -> String? { jobNames[id] }

    /// Every tool id Home reaches: its shelves, its own tiles, and the tools each "start with what you have" tile
    /// offers. A tool that lives inside another one (`homes`) counts when that one is reached.
    static func reached(handoff: (ChainKind) -> [String], homes: [String: String]) -> Set<String> {
        var ids = Set(all.flatMap(\.tools)).union(ownTiles)
        for kind in [ChainKind.image, .video, .audio, .pdf, .file, .text] { ids.formUnion(handoff(kind)) }
        for (child, parent) in homes where ids.contains(parent) { ids.insert(child) }
        return ids
    }
}
