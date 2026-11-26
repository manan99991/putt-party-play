import Foundation

/// Smart autoruns (Manan, 25 Nov): the jobs a personal assistant would do at the end of the day, on what the person made
/// that day — today's receipts into the expense sheet, heavy videos made smaller without losing quality, the best clips
/// made ready to post, the day's photos as one collage, business cards into contacts. Once or twice a day (every 12
/// hours). Everything is read and made on the phone; nothing leaves it. iPhone decides when background work may run,
/// so the work is done when it allows (usually overnight on the charger), and at the chosen time a notification says
/// it's ready — anything not done yet finishes with a live progress bar when it's tapped. Nothing is ever deleted,
/// sent or added without the person seeing it first.
///
/// This file is the pure part (what to look at, when, and in what order), so it is unit-tested.
enum SmartRuns {
    enum Kind: String, CaseIterable, Codable, Identifiable {
        case receipts, drives, overdueInvoices, heavyVideos, readyToPost, dayCollage, businessCards
        var id: String { rawValue }

        var title: String {
            switch self {
            case .receipts: return "Today's receipts into my expense sheet"
            case .drives: return "Today's drives into my mileage log"
            case .overdueInvoices: return "Nudge me about overdue invoices"
            case .heavyVideos: return "Make today's heavy videos smaller"
            case .readyToPost: return "Get today's best videos ready to post"
            case .dayCollage: return "Today's photos as one collage"
            case .businessCards: return "Business cards into my contacts"
            }
        }
        /// What it does, in one plain line.
        var line: String {
            switch self {
            case .receipts: return "Finds the receipts you photographed or saved as PDFs today and adds each one to your expense sheet — shop, date, total, tax — after you look them over."
            case .overdueInvoices: return "When an invoice passes its pay-by day, a reminder email is ready — the invoice attached, the right tone for how late it is. You read it and tap Send."
            case .drives: return "Lists the drives your phone noticed today — when, from where to where, how far. Tap which were for work and they go into your mileage log with the IRS rate."
            case .heavyVideos: return "Re-saves today's big videos in a smaller format that looks the same, checks every one frame by frame, and shows how much space you'd get back."
            case .readyToPost: return "Picks today's best clips, gives them your look and the tall size Reels, TikTok and Shorts want, ready for you to watch and post."
            case .dayCollage: return "Picks the best photos of the people you took today — sharp, no repeats — and lays them out as one beautiful picture to keep or send."
            case .businessCards: return "Reads the business cards you photographed today and turns each into a contact, skipping anyone you already have."
            }
        }
        var icon: String {
            switch self {
            case .receipts: return "receipt"
            case .drives: return "car.fill"
            case .overdueInvoices: return "doc.text.magnifyingglass"
            case .heavyVideos: return "arrow.down.right.and.arrow.up.left"
            case .readyToPost: return "sparkles.tv"
            case .dayCollage: return "square.grid.3x3.fill"
            case .businessCards: return "person.text.rectangle"
            }
        }
        var hex: UInt32 {
            switch self {
            case .receipts: return 0x10B981
            case .drives: return 0x0EA5E9
            case .overdueInvoices: return 0xEF4444
            case .heavyVideos: return 0x8B5CF6
            case .readyToPost: return 0xEC4899
            case .dayCollage: return 0xF59E0B
            case .businessCards: return 0x3B82F6
            }
        }
        /// What it looks through.
        var looksAt: Media {
            switch self {
            case .receipts: return .photosAndPDFs
            case .drives, .overdueInvoices: return .records
            case .heavyVideos, .readyToPost: return .videos
            case .dayCollage, .businessCards: return .photos
            }
        }
        /// The tools whose use suggests this autorun would help (Habit offers).
        var habitTools: Set<String> {
            switch self {
            case .receipts: return ["receipts", "expense", "warranty", "scan", "datagrab"]
            case .drives: return ["mileage", "gpsdash"]
            case .overdueInvoices: return ["invoice"]
            case .heavyVideos: return ["videoshrink", "shrink", "cleaner", "videofinish"]
            case .readyToPost: return ["celebrate", "videofx", "socialpost", "vertical", "captions"]
            case .dayCollage: return ["collage", "photogrid", "animate"]
            case .businessCards: return ["bizcard", "contacts", "businesscards"]
            }
        }
    }

    enum Media: String, Codable { case photos, videos, photosAndPDFs, records }   // records: Tenzy's own (drives, invoices)

    /// One autorun as the person set it.
    struct Plan: Codable, Equatable {
        var on = false
        /// Once a day, or twice — the second time 12 hours after the first.
        var twice = false
        var hour = 20
        var minute = 0
        /// Receipts only: a folder of PDFs to look in too (a saved bookmark), named for showing.
        var folderName: String?
        /// Ready to post only: the look given to each clip.
        var look: String?

        /// The times of day it comes back, first first.
        var times: [(hour: Int, minute: Int)] {
            let h = min(max(hour, 0), 23), m = min(max(minute, 0), 59)
            return twice ? [(h, m), ((h + 12) % 24, m)].sorted { $0.0 * 60 + $0.1 < $1.0 * 60 + $1.1 } : [(h, m)]
        }
    }

    /// What's looked at: everything made since the last run, but never more than 36 hours back (a phone that sat in a
    /// drawer for a week doesn't get a week of videos re-saved at once), and the last 24 hours on a first run.
    static func window(lastRun: Date?, now: Date) -> DateInterval {
        let floor = now.addingTimeInterval(-36 * 3600)
        let start = max(lastRun ?? now.addingTimeInterval(-24 * 3600), floor)
        return DateInterval(start: min(start, now), end: now)
    }

    /// The next time a plan comes due after `now`, in the phone's calendar.
    static func nextDue(_ p: Plan, after now: Date, cal: Calendar = .current) -> Date? {
        guard p.on else { return nil }
        return p.times.compactMap { t in
            cal.nextDate(after: now, matching: DateComponents(hour: t.hour, minute: t.minute), matchingPolicy: .nextTime)
        }.min()
    }

    /// Whether it's time to prepare a run: a due time has passed since the last one (or there was never one and
    /// the first time today has passed).
    static func isDue(_ p: Plan, lastRun: Date?, now: Date, cal: Calendar = .current) -> Bool {
        guard p.on else { return false }
        let since = lastRun ?? cal.startOfDay(for: now)
        guard let next = nextDue(p, after: since, cal: cal) else { return false }
        return next <= now
    }

    // MARK: picking what to work on

    /// A thing found in the window: a photo, a video or a PDF.
    struct Found: Equatable {
        var id: String
        var created: Date
        var isVideo = false
        var isScreenshot = false
        var bytes: Int = 0
        var seconds: Double = 0
        var width: Int = 0
        var height: Int = 0
        /// What the photo index found in it (photos only).
        var seen: PhotoSeen?
    }

    /// The parts of a photo's reading the picking needs. Mirrors PhotoFinder.Seen, kept separate so this stays pure.
    struct PhotoSeen: Equatable {
        var labels: [String]
        var text: String
        var faces: Int
        var sharpness: Double = 1      // 0 blurry … 1 sharp (from the quick read); 1 when not measured
    }

    /// Heavy videos worth re-saving: at least 60 MB, or at least 25 MB a minute — the size where a smaller format
    /// saves real space. Biggest first.
    static func heavy(_ items: [Found], minBytes: Int = 60_000_000, minPerMinute: Double = 25_000_000) -> [Found] {
        items.filter { $0.isVideo && $0.bytes > 0 }
            .filter { Double($0.bytes) >= Double(minBytes) || ($0.seconds > 0 && Double($0.bytes) / ($0.seconds / 60) >= minPerMinute) }
            .sorted { $0.bytes > $1.bytes }
    }

    /// Photos for the day's collage: people in them, not screenshots, not documents, sharp enough, and only one of each
    /// burst (photos taken within 3 seconds of each other count as the same moment; the sharpest is kept). Babies and
    /// children first, then the rest, newest moments spread across the day. At most `limit`.
    static func collagePicks(_ items: [Found], limit: Int = 10) -> [Found] {
        let people = items.filter { f in
            guard !f.isVideo, !f.isScreenshot, let s = f.seen else { return false }
            let words = s.text.split { $0 == " " || $0 == "\n" }.count
            return s.faces > 0 && words < 20 && s.sharpness >= 0.35
        }.sorted { $0.created < $1.created }
        // One per moment.
        var moments: [Found] = []
        for f in people {
            if let last = moments.last, f.created.timeIntervalSince(last.created) < 3 {
                if (f.seen?.sharpness ?? 0) > (last.seen?.sharpness ?? 0) { moments[moments.count - 1] = f }
            } else { moments.append(f) }
        }
        func little(_ f: Found) -> Bool { f.seen?.labels.contains { ["baby", "child", "toddler", "kid", "infant"].contains($0) } ?? false }
        guard moments.count > limit else { return moments }
        // Little ones first; whatever is taken from a group is spread evenly across the day, not the first ten minutes.
        func spread(_ xs: [Found], _ n: Int) -> [Found] {
            guard n > 0, xs.count > n else { return Array(xs.prefix(max(0, n))) }
            if n == 1 { return [xs[xs.count / 2]] }
            return (0..<n).map { xs[Int((Double($0) * Double(xs.count - 1) / Double(n - 1)).rounded())] }
        }
        let kids = moments.filter(little), rest = moments.filter { !little($0) }
        let keep = spread(kids, min(limit, kids.count)) + spread(rest, limit - min(limit, kids.count))
        return keep.sorted { $0.created < $1.created }
    }

    /// Clips worth making ready to post: 4 s to 3 min, not screen recordings (no way to tell for sure, so very wide or
    /// odd sizes are left out), newest first, at most `limit`.
    static func postPicks(_ items: [Found], limit: Int = 3) -> [Found] {
        items.filter { $0.isVideo && $0.seconds >= 4 && $0.seconds <= 180 && $0.width > 0 && $0.height > 0 }
            .sorted { $0.created > $1.created }
            .prefix(limit).map { $0 }
    }

    // MARK: is the smaller video as good?

    /// Peak signal-to-noise ratio between two same-size grayscale frames, in dB (higher is closer; identical is 99).
    /// About 40 dB and up is indistinguishable to the eye at normal viewing; below ~36 dB softness starts to show.
    static func psnr(_ a: [UInt8], _ b: [UInt8]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var sum = 0.0
        for i in 0..<a.count { let d = Double(a[i]) - Double(b[i]); sum += d * d }
        let mse = sum / Double(a.count)
        guard mse > 0 else { return 99 }
        return 10 * log10(255 * 255 / mse)
    }

    /// The bar a re-saved video must clear on every checked frame to count as "looks the same".
    static let samePictureDB = 38.0

    /// A smaller video is only offered when it saves real space: at least 20% and at least 10 MB.
    static func worthIt(original: Int, smaller: Int) -> Bool {
        smaller > 0 && smaller < original && Double(original - smaller) >= max(10_000_000, Double(original) * 0.2)
    }

    // MARK: habits

    /// The autoruns someone's habits suggest: a matching tool used on 3 or more separate days in the last 14, or what's
    /// on the phone (from the photo index) showing up that often. Strongest first; ones already on or put off are left out.
    static func suggested(toolDays: [String: Set<Int>], found: [Kind: Int], on: Set<Kind>, hidden: Set<Kind>) -> [Kind] {
        Kind.allCases.compactMap { k -> (Kind, Int)? in
            guard !on.contains(k), !hidden.contains(k) else { return nil }
            let days = k.habitTools.reduce(into: Set<Int>()) { $0.formUnion(toolDays[$1] ?? []) }.count
            let seen = found[k] ?? 0
            let score = days * 2 + seen
            return days >= 3 || seen >= threshold(k) ? (k, score) : nil
        }.sorted { $0.1 > $1.1 }.map(\.0)
    }

    /// How many of a thing in the last two weeks makes an autorun worth offering on its own.
    static func threshold(_ k: Kind) -> Int {
        switch k {
        case .receipts: return 8
        case .drives: return 6
        case .overdueInvoices: return 2
        case .heavyVideos: return 4
        case .readyToPost: return 10
        case .dayCollage: return 30
        case .businessCards: return 5
        }
    }
}
