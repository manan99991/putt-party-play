import Foundation
import Photos

/// Smart autorun: tidy up photos (25 Nov). Each run gathers what's taking space for no reason and shows it, grouped,
/// with what's kept and why: screenshots over a week old — but never one that's a receipt, ticket, code, card, menu,
/// document or a favourite; near-duplicate photos — the best copy kept (your favourite, else the biggest, else the
/// first); and the hidden extra frames of bursts — the one you or iPhone picked kept. Nothing is deleted until the
/// person taps Delete, and iPhone itself asks; deleted items wait in Recently Deleted for 30 days.
enum SmartTidy {
    struct Group: Codable, Equatable, Identifiable {
        var id: String               // "screenshots", "duplicates", "bursts"
        var ids: [String]            // offered for deleting
        var bytes: Int64
        var kept: Int                // how many were looked at and kept on purpose
        var selected = true
    }

    /// A screenshot worth keeping: something you'd look for again.
    static func usefulScreenshot(_ s: PhotoFinder.Seen) -> Bool {
        s.codes > 0 || [PhotoFinder.Kind.receipt, .card, .menu, .document, .board, .code].contains { PhotoFinder.score(s, for: $0) >= PhotoFinder.threshold }
    }

    /// Of near-duplicates, the one to keep: a favourite, else the largest (most detail), else the earliest. Pure.
    static func keeper(_ items: [(id: String, fav: Bool, bytes: Int64, created: Date)]) -> String? {
        if let f = items.first(where: \.fav) { return f.id }
        return items.max { a, b in a.bytes != b.bytes ? a.bytes < b.bytes : a.created > b.created }?.id
    }

    static func gather(progress: ((Double, String) -> Void)? = nil) async -> [Group] {
        var out: [Group] = []
        // Screenshots older than a week.
        progress?(0.05, L("Looking at your screenshots…"))
        let old = PhotoCleaner.oldScreenshots(days: 7)
        var cache = PhotoFinder.loadCache()
        var drop: [PhotoCleaner.Item] = [], kept = 0
        for it in old.prefix(600) {
            let a = it.asset
            let seen: PhotoFinder.Seen?
            if let s = cache[a.localIdentifier], s.modified == (a.modificationDate?.timeIntervalSince1970 ?? 0) { seen = s }
            else { seen = await PhotoFinder.read(a); if let seen { cache[a.localIdentifier] = seen } }
            if let seen, usefulScreenshot(seen) { kept += 1 } else { drop.append(it) }
        }
        PhotoFinder.saveCache(cache)
        if !drop.isEmpty { out.append(Group(id: "screenshots", ids: drop.map(\.id), bytes: drop.reduce(0) { $0 + $1.bytes }, kept: kept)) }
        // Near-duplicates among the newest photos.
        progress?(0.35, L("Looking for duplicates…"))
        let dup = await PhotoCleaner.duplicates(scanLimit: 600) { p in progress?(0.35 + 0.45 * p, L("Looking for duplicates…")) }
        var extra: [PhotoCleaner.Item] = []
        for g in dup.groups where g.allSatisfy({ $0.asset.mediaType == .image }) {
            let keep = keeper(g.map { (id: $0.id, fav: $0.asset.isFavorite, bytes: $0.bytes, created: $0.asset.creationDate ?? .distantPast) })
            extra += g.filter { $0.id != keep && !$0.asset.isFavorite }
        }
        if !extra.isEmpty { out.append(Group(id: "duplicates", ids: extra.map(\.id), bytes: extra.reduce(0) { $0 + $1.bytes }, kept: dup.groups.count)) }
        // Hidden burst frames.
        progress?(0.85, L("Looking at bursts…"))
        let b = PhotoCleaner.bursts()
        let frames = b.flatMap(\.extras)
        if !frames.isEmpty { out.append(Group(id: "bursts", ids: frames.map(\.id), bytes: frames.reduce(0) { $0 + $1.bytes }, kept: b.count)) }
        progress?(1, L("Done"))
        return out
    }

    static func title(_ g: Group) -> String {
        switch g.id {
        case "screenshots": return "Old screenshots"
        case "duplicates": return "Duplicate photos"
        default: return "Extra burst frames"
        }
    }
    static func why(_ g: Group) -> String {
        switch g.id {
        case "screenshots": return String(format: L("Over a week old. %d kept: receipts, tickets, codes, cards, menus, documents and favourites."), g.kept)
        case "duplicates": return String(format: L("Copies that look the same. The best of each kept (%d sets): your favourite, else the biggest copy."), g.kept)
        default: return String(format: L("The hidden frames behind %d bursts. The one you or iPhone picked is kept."), g.kept)
        }
    }
}
