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

    /// Every tool id Home reaches: its shelves, its own tiles, and the tools each "start with what you have" tile
    /// offers. A tool that lives inside another one (`homes`) counts when that one is reached.
    static func reached(handoff: (ChainKind) -> [String], homes: [String: String]) -> Set<String> {
        var ids = Set(all.flatMap(\.tools)).union(ownTiles)
        for kind in [ChainKind.image, .video, .audio, .pdf, .file, .text] { ids.formUnion(handoff(kind)) }
        for (child, parent) in homes where ids.contains(parent) { ids.insert(child) }
        return ids
    }
}
