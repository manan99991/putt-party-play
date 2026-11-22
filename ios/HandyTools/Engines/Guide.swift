import Foundation
import UIKit
import SwiftUI
import Vision

/// "What to do with it", the guided way: everything a picked item can become is sorted into a few plain
/// goals (never more than six on a screen), Tenzy looks at the item and suggests the likeliest one, and each
/// goal holds only the handful of ways to get there. The sorting and the guess are pure, so they are unit-tested.
enum Guide {
    struct Goal: Equatable, Identifiable {
        let id: String
        let title: String
        let line: String
        let icon: String
    }

    /// What can be on the goal screen. A full tool, a ready-made flow, or the voice picker for a recording.
    enum Option: Identifiable, Equatable {
        case tool(String)
        case chain(Chain)
        case voices
        var id: String {
            switch self {
            case .tool(let t): return "tool-" + t
            case .chain(let c): return "chain-" + c.id
            case .voices: return "voices"
            }
        }
    }

    /// Why Tenzy suggests one goal first, in a few plain words, plus the step that answers it best.
    struct Guess: Equatable {
        let goal: String
        let why: String
        var block: Block? = nil
        var tool: String? = nil
    }

    /// What Tenzy noticed in the photo (read on the phone with Vision).
    struct Clues: Equatable {
        var count = 1
        var faces = 0
        var text = ""
        var barcode = false
        var hasLocation = false
    }

    // MARK: goals

    static func goal(_ id: String, count: Int = 1) -> Goal {
        switch id {
        case "together": return Goal(id: id, title: "Put them together", line: count > 1 ? "A collage, a video or one PDF of all \(count)" : "A collage, a video or one PDF", icon: "square.grid.2x2.fill")
        case "fun":      return Goal(id: id, title: "Have fun with it", line: "Stickers, comics, emoji faces, memes", icon: "face.smiling.inverse")
        case "share":    return Goal(id: id, title: "Send it", line: "Smaller, private, the right format", icon: "paperplane.fill")
        case "read":     return Goal(id: id, title: "Read it", line: "Get the words, translate, hear it", icon: "text.viewfinder")
        case "save":     return Goal(id: id, title: "Save what's in it", line: "Receipts, contacts, dates, lists", icon: "tray.and.arrow.down.fill")
        case "doc":      return Goal(id: id, title: "Make a document", line: "A clean PDF, signed or stamped", icon: "doc.richtext.fill")
        case "clip":     return Goal(id: id, title: "Make a clip", line: "Trim, GIF, slow-mo, a still", icon: "film.stack")
        case "words":    return Goal(id: id, title: "Get the words", line: "Write out what's said, captions, notes", icon: "captions.bubble.fill")
        case "sound":    return Goal(id: id, title: "Get the sound out", line: "Save it as MP3 or M4A, make a ringtone", icon: "waveform")
        case "voice":    return Goal(id: id, title: "Change the voice", line: "Hear it as a chipmunk, robot and more", icon: "waveform.and.person.filled")
        case "edit":     return Goal(id: id, title: "Mix or label it", line: "Join recordings, fix the title and artist", icon: "slider.horizontal.3")
        case "sign":     return Goal(id: id, title: "Sign or fill it in", line: "Your signature, a stamp, form fields", icon: "signature")
        case "pages":    return Goal(id: id, title: "Pick pages", line: "Keep, split, merge or reorder", icon: "doc.on.doc.fill")
        case "check":    return Goal(id: id, title: "Check it", line: "Scams, prices, what a link says", icon: "checkmark.shield.fill")
        default:         return Goal(id: "more", title: "Something else", line: "Every other way to use it", icon: "ellipsis.circle.fill")
        }
    }

    /// The goals for this kind of thing, in the order they're shown. "Something else" is added only if it has anything.
    static func goalIDs(for kind: ChainKind, count: Int) -> [String] {
        switch kind {
        case .image, .photoFile: return count > 1 ? ["together", "fun", "share", "doc", "read", "save"] : ["fun", "share", "read", "save", "doc", "together"]
        case .video: return ["share", "clip", "sound", "words"]
        case .pdf: return ["sign", "share", "pages", "read"]
        case .audio: return ["words", "voice", "share", "edit"]
        case .text: return ["read", "save", "share", "check"]
        case .file: return []
        }
    }

    /// Which goal one step serves, given what it is working on.
    static func goal(of block: Block, kind: ChainKind) -> String {
        switch kind {
        case .video:
            switch block {
            case .videoShrink, .videoMute, .videoRotate, .videoVertical: return "share"
            case .videoTrim, .videoGif, .videoSpeed, .videoLoop, .videoStill, .videoCelebrate: return "clip"
            case .videoAudio, .voiceChange: return "sound"
            case .videoCaptions, .speechText, .summarize, .translate: return "words"
            default: return "more"
            }
        case .pdf:
            switch block {
            case .stamp: return "sign"
            case .pdfShrink, .pdfLock: return "share"
            case .pdfPages: return "pages"
            case .pdfText, .summarize, .translate, .readAloud, .readText: return "read"
            default: return "more"
            }
        case .audio:
            switch block {
            case .speechText, .summarize, .translate, .actionItems: return "words"
            case .voiceChange: return "voice"
            default: return "more"
            }
        case .text:
            switch block {
            case .readAloud, .translate, .summarize, .rewrite: return "read"
            case .calendarEvent, .actionItems, .pullDetails, .makeTable, .addToList, .expenseRow, .businessCard, .returnBy, .pullReceipt: return "save"
            case .cleanText, .makeQr, .textPdf, .chatLink, .cleanLinks, .contactQr, .wifiQr: return "share"
            case .scamCheck, .priceCompare, .pageText: return "check"
            default: return "more"
            }
        case .image, .photoFile:
            switch block {
            case .shrinkImage, .stripLocation, .convertImage, .resizePhoto, .watermark, .hideSensitive, .passportPhoto: return "share"
            case .cutout, .sticker, .emojiFaces, .meme, .emojiMosaic, .artFilter: return "fun"
            case .readText, .translate, .readAloud, .describe, .identify, .readCode, .summarize, .rewrite, .pdfText: return "read"
            case .pullReceipt, .expenseRow, .businessCard, .calendarEvent, .addToList, .returnBy, .pullDetails, .makeTable, .actionItems: return "save"
            case .photoPdf, .stamp, .enhance, .textPdf: return "doc"
            default: return "more"
            }
        case .file: return "more"
        }
    }

    /// The goal a whole flow serves: the most specific of its steps wins (a flow that reads a receipt and
    /// pulls its fields is about saving, not reading). Several-photo flows (collage, GIF) go under "together".
    static func goal(of chain: Chain, kind: ChainKind, count: Int) -> String {
        let start: ChainKind = kind == .photoFile ? .image : kind
        if start == .image, chain.collage == true || chain.gif == true || chain.flipbook == true || chain.versus == true {
            return count > 1 ? "together" : "fun"
        }
        let rank: [String] = {
            switch start {
            case .image: return ["save", "doc", "fun", "read", "share"]
            case .video: return ["words", "clip", "share"]
            case .pdf: return ["sign", "pages", "read", "share"]
            case .audio: return ["voice", "words"]
            case .text: return ["save", "check", "read", "share"]
            default: return []
            }
        }()
        var k = start
        var found: [String] = []
        for s in chain.steps {
            found.append(goal(of: s.block, kind: k == .photoFile ? .image : k))
            k = s.block.gives
        }
        if start == .image, chain.combine == true, count > 1, found.contains("doc") { return "together" }
        return rank.first { found.contains($0) } ?? "more"
    }

    /// The goal a full tool serves.
    static func goal(ofTool id: String, kind: ChainKind, count: Int) -> String {
        if kind == .video {
            switch id {
            case "video", "audiomix", "celebrate": return "clip"
            case "fitit": return "share"
            case "audioconvert", "ringtone", "audioclean", "audioedit", "audiocompress": return "sound"
            case "meetingnotes": return "words"
            default: break
            }
        }
        switch id {
        case "collage", "animate": return count > 1 ? "together" : "fun"
        case "celebrate": return "fun"
        case "comicstrip": return count > 1 ? "together" : "fun"
        case "sticker", "faceemoji": return "fun"
        case "scrub", "fitit": return "share"
        case "menu": return "read"
        case "cards": return "save"
        case "pdfsign", "pdfform": return "sign"
        case "pdfsearchable": return "read"
        case "pdfprotect": return "share"
        case "pdfpages": return "pages"
        case "meetingnotes": return "words"
        case "audiocompress", "audioconvert": return "share"
        case "video": return "edit"
        case "audiomix": return "edit"
        case "audiotags": return kind == .audio ? "edit" : "more"
        case "audioclean", "audioedit": return "edit"
        case "studio": return "share"
        case "zipmaker": return kind == .file ? "more" : "share"
        default: return "more"
        }
    }

    /// Every option sorted under its goal, best first (full tools, then the person's own flows, then ready-made).
    /// Only goals that have something in them are returned, in the order they're shown; "Something else" last.
    /// Ready-made flows that a full tool already does better — shown once, as the tool, so there are never two
    /// choices that do the same job (the flows stay in Build your own for anyone who wants to change them).
    /// Ready-made flows that do exactly what a tool on the same list does: offered once, as the tool,
    /// so the list never shows the same job twice under two names.
    static let coveredBy: [String: String] = ["card-to-contact": "cards", "safe-to-share": "scrub", "photo-under-2mb": "fitit",
                                              "sticker": "sticker", "hide-sensitive": "scrub",
                                              "video-celebrate": "celebrate", "sticker-maker": "sticker",
                                              "emoji-faces": "faceemoji", "what-is-this": "identify"]

    static func sort(kind: ChainKind, count: Int, tools: [String], chains: [Chain], voices: Bool) -> [(goal: String, options: [Option])] {
        var by: [String: [Option]] = [:]
        for t in tools { by[goal(ofTool: t, kind: kind, count: count), default: []].append(.tool(t)) }
        if voices { by["voice", default: []].append(.voices) }
        for c in ChainSame.unique(chains) {
            if let t = coveredBy[c.id], tools.contains(t), ChainTemplates.all.contains(where: { $0.id == c.id }) { continue }
            // Several-photo flows need several photos.
            if count < 2, c.collage == true || c.gif == true || c.flipbook == true || c.versus == true { continue }
            by[goal(of: c, kind: kind, count: count), default: []].append(.chain(c))
        }
        var out: [(goal: String, options: [Option])] = []
        for g in goalIDs(for: kind, count: count) { if let o = by.removeValue(forKey: g), !o.isEmpty { out.append((goal: g, options: o)) } }
        // Anything whose goal isn't on this kind's list goes under "Something else", so nothing is ever lost.
        let rest = by.keys.sorted().flatMap { by[$0] ?? [] }
        if !rest.isEmpty { out.append((goal: "more", options: rest)) }
        return out
    }

    // MARK: the guess

    private static let receiptWords = ["subtotal", "total", "tax", "change due", "visa", "mastercard", "amex", "debit", "cash", "receipt", "qty", "balance due"]

    /// The goal to suggest first for a photo, from what Tenzy noticed in it. nil when there's no photo to look at.
    static func guess(_ c: Clues, kind: ChainKind) -> Guess? {
        guard kind == .image || kind == .photoFile else { return nil }
        if c.count > 1 { return Guess(goal: "together", why: "You picked \(c.count) photos", tool: "collage") }
        if c.barcode { return Guess(goal: "read", why: "There's a code in it", block: .readCode) }
        let low = c.text.lowercased()
        let words = low.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
        if receiptWords.filter({ low.contains($0) }).count >= 2 { return Guess(goal: "save", why: "It looks like a receipt", block: .expenseRow) }
        let d = TextTidy.details(c.text)
        if (!d.phones.isEmpty || !d.emails.isEmpty), words < 70 { return Guess(goal: "save", why: "It looks like a business card", tool: "cards") }
        if words >= 30 { return Guess(goal: "read", why: "There's writing in it", block: .readText) }
        if c.hasLocation { return Guess(goal: "share", why: "It carries where it was taken — clear it before you share", tool: "scrub") }
        if c.faces > 0 { return Guess(goal: "fun", why: c.faces == 1 ? "There's someone in it" : "There are \(c.faces) people in it", tool: "sticker") }
        return Guess(goal: "share", why: "Ready to send", tool: "fitit")
    }

    /// The option to put in the "Suggested" card: the one that answers the guess most directly, else the goal's first.
    static func pick(_ g: Guess, from options: [Option]) -> Option? {
        if let t = g.tool, let o = options.first(where: { $0 == .tool(t) }) { return o }
        if let b = g.block {
            // The shortest flow that has that step — the most direct answer.
            let hits = options.compactMap { o -> (Option, Int)? in
                if case .chain(let c) = o, c.steps.contains(where: { $0.block == b }) { return (o, c.steps.count) }
                return nil
            }
            if let best = hits.min(by: { $0.1 < $1.1 }) { return best.0 }
        }
        return options.first
    }

    // MARK: how a choice is shown

    static func tint(_ goal: String) -> Color {
        switch goal {
        case "together": return Color(hex: 0x6366F1)
        case "fun", "voice", "clip": return Color(hex: 0xEAB308)
        case "share", "edit": return Color(hex: 0x10B981)
        case "read", "words": return Color(hex: 0x3B82F6)
        case "save", "sign": return Color(hex: 0xEC4899)
        case "doc", "pages": return Color(hex: 0xA855F7)
        case "check": return Color(hex: 0xF97316)
        default: return Color(hex: 0x64748B)
        }
    }

    /// The step that says what a flow is for — its icon is that step's, not the first step's (every "read a
    /// photo then…" flow used to show the same text-scanner icon).
    static func keyBlock(_ chain: Chain, kind: ChainKind) -> Block {
        let target = goal(of: chain, kind: kind, count: 1)
        var k = kind == .photoFile ? ChainKind.image : kind
        var hit: Block?
        for s in chain.steps {
            if goal(of: s.block, kind: k == .photoFile ? .image : k) == target { hit = s.block }
            k = s.block.gives
        }
        return hit ?? chain.steps.last?.block ?? .readText
    }

    /// A choice's name, in plain words: a saved request ("I want an image to convert to pdf") becomes what it does.
    /// Audio tools offered for a video are named for what they do to the video, so the Video list reads as video jobs.
    static let videoNames: [String: (name: String, gets: String)] = [
        "audioconvert": ("Save the sound as MP3 or M4A", "Just the audio from your video, in the format you pick"),
        "ringtone": ("Ringtone from this video", "Up to 30 seconds of its sound, with the steps to set it"),
        "audioclean": ("Clean up its sound", "Less background noise and hum, an even volume — as a sound file"),
        "audioedit": ("Trim its sound, cut the silences", "Just the audio, trimmed and faded the way you like"),
        "audiocompress": ("Shrink its sound to email it", "Just the audio, small enough for any email"),
        "meetingnotes": ("Notes from a video call or talk", "Who said what, a summary and the to-dos"),
        "audiomix": ("Join videos or change their speed", "One video, or faster / slower with natural voices"),
        "celebrate": ("Make it stunning", "A whole vibe in one tap, or looks, light, motion, sparkle, words and any festival — as subtle or as wild as you like"),
    ]

    @MainActor static func title(_ o: Option, count: Int, kind: ChainKind? = nil) -> String {
        switch o {
        case .tool(let id) where kind == .video && videoNames[id] != nil: return L(videoNames[id]!.name)
        case .tool(let id): return L(TOOLS.first { $0.id == id }?.name ?? id)
        case .voices: return L("Change the voice")
        case .chain(let c):
            let low = c.name.lowercased()
            let asked = ["i want", "i need", "i'd like", "can you", "could you", "please", "help me", "make me", "how do i", "how to"].contains { low.hasPrefix($0) }
            return asked ? ChainText.sentence(Chain(id: c.id, name: "", steps: c.steps)) : L(c.name)
        }
    }

    /// What you end up with, in one plain line.
    @MainActor static func gets(_ o: Option, kind: ChainKind) -> String {
        switch o {
        case .tool(let id) where kind == .video && videoNames[id] != nil: return videoNames[id]!.gets
        case .tool(let id): return TOOLS.first { $0.id == id }?.blurb ?? ""
        case .voices: return "Hear your recording in each voice, then keep the one you like"
        case .chain(let c):
            if c.collage == true { return "One picture with all your photos laid out" }
            if c.gif == true { return "A looping GIF of your photos" }
            if c.flipbook == true { return "A flip-book video of your photos" }
            if c.versus == true { return "Before and after, side by side" }
            if c.combine == true { return "One PDF with every page" }
            let b = keyBlock(c, kind: kind)
            let does = b.does
            return does.prefix(1).uppercased() + does.dropFirst()
        }
    }

    /// Up to four photos as one small square — the preview for "put them together".
    static func mosaic(_ photos: [UIImage]) -> UIImage {
        let side: CGFloat = 240, n = min(4, photos.count)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: fmt).image { _ in
            UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: side, height: side))
            let cols = n > 1 ? 2 : 1, rows = n > 2 ? 2 : 1
            let w = side / CGFloat(cols), h = side / CGFloat(rows)
            for i in 0..<n {
                let r = CGRect(x: CGFloat(i % cols) * w + 2, y: CGFloat(i / cols) * h + 2, width: w - 4, height: (n == 3 && i == 2 ? side : h) - 4)
                let img = photos[i]
                let k = max(r.width / img.size.width, r.height / img.size.height)
                let d = CGSize(width: img.size.width * k, height: img.size.height * k)
                UIGraphicsGetCurrentContext()?.saveGState()
                UIRectClip(r)
                img.draw(in: CGRect(x: r.midX - d.width / 2, y: r.midY - d.height / 2, width: d.width, height: d.height))
                UIGraphicsGetCurrentContext()?.restoreGState()
            }
        }
    }

    // MARK: previews

    /// Steps quick enough to try on a small copy of the person's own photo while they choose.
    static let quickBlocks: Set<Block> = [.shrinkImage, .stripLocation, .convertImage, .resizePhoto, .watermark, .hideSensitive,
                                           .cutout, .sticker, .emojiFaces, .meme, .emojiMosaic, .artFilter, .enhance,
                                           .readText, .readCode, .pullDetails, .passportPhoto]

    /// A flow whose whole run is quick enough to preview.
    static func previewable(_ chain: Chain) -> Bool {
        !chain.steps.isEmpty && chain.steps.allSatisfy { quickBlocks.contains($0.block) }
    }

    /// Read the photo on the phone: faces, words and codes. Small copy, fast settings; never blocks the screen.
    static func clues(_ image: UIImage, count: Int, file: Data? = nil) async -> Clues {
        await Task.detached(priority: .userInitiated) {
            var c = Clues(count: count)
            if let file { c.hasLocation = Scrubber.metadata(in: file).hasGPS }
            guard let cg = image.resized(maxDimension: 1024).cgImage else { return c }
            let faces = VNDetectFaceRectanglesRequest()
            let text = VNRecognizeTextRequest()
            text.recognitionLevel = .fast
            text.usesLanguageCorrection = false
            let codes = VNDetectBarcodesRequest()
            let h = VNImageRequestHandler(cgImage: cg, orientation: .up)
            try? h.perform([faces, text, codes])
            c.faces = faces.results?.count ?? 0
            c.text = (text.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            c.barcode = !(codes.results ?? []).isEmpty
            return c
        }.value
    }
}
