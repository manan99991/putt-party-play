import Foundation

/// Home's "…or open a tool" shelves: every tool that doesn't start from a file you already have — the flashlight,
/// the camera helpers, your day — grouped by the job people think in. Together with the "start with what you have"
/// tiles (each lists the tools for that kind of file) they reach every tool Tenzy has, and each tool sits on one shelf
/// only. Pure, so a unit test proves nothing built is ever missing from Home.
enum HomeShelves {
    struct Shelf: Equatable, Identifiable {
        let id: String
        let title: String
        let line: String
        let icon: String
        let hex: UInt32
        let tools: [String]
    }

    static let all: [Shelf] = [
        Shelf(id: "camera", title: "Camera", line: "Point your camera: scan, identify, measure, read",
              icon: "camera.fill", hex: 0x0EA5E9,
              tools: ["scan", "identify", "procam", "measure", "qrwifi", "menu", "cards", "datagrab", "seeread", "colorvision"]),
        Shelf(id: "phone", title: "Flashlight & phone", line: "Light, speed, sound checks, space and privacy",
              icon: "flashlight.on.fill", hex: 0xEAB308,
              tools: ["light", "gpsdash", "audiolab", "rest", "cleaner", "vault", "fileviewer", "formatfix", "stitch", "zipmaker"]),
        Shelf(id: "create", title: "Create", line: "Make something: stickers, collages, effects, posts",
              icon: "wand.and.stars", hex: 0xEC4899,
              tools: ["studio", "sticker", "collage", "comicstrip", "animate", "scrub", "celebrate", "post", "video", "audiostudio", "soundboard"]),
        Shelf(id: "words", title: "Words & voice", line: "Write, translate, take notes, spot scams",
              icon: "text.bubble.fill", hex: 0x22C55E,
              tools: ["textstudio", "translate", "speechnotes", "shield", "memory"]),
        Shelf(id: "day", title: "Daily life", line: "Medicine, plans, moods, bills, prices and receipts",
              icon: "calendar", hex: 0xF97316,
              tools: ["medreminder", "untangle", "planner", "brief", "daydiary", "sorted", "warranty", "pricewatch", "pricecheck"]),
    ]

    /// Tools Home opens straight from their own tile (no shelf needed).
    static let ownTiles: Set<String> = ["contacts", "thinking"]

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
