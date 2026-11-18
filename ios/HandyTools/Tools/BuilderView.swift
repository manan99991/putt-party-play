import SwiftUI
import UIKit
import PhotosUI
import VisionKit
import UniformTypeIdentifiers
import WidgetKit
import PDFKit
import AVKit

/// Audio types the recording pickers accept. `.audio` covers m4a/mp3/wav/caf and friends; the explicit
/// opus/ogg extensions also admit WhatsApp & Telegram voice notes (Ogg-Opus), which iOS does not map to
/// public.audio — so a plain `[.audio]` filter greys them out in the Files browser.
private let audioImportTypes: [UTType] = [.audio] + ["opus", "ogg", "oga"].compactMap { UTType(filenameExtension: $0) }
import AVFoundation
import Compression

/// Something handed over before a tool was chosen: "here is what I have, what can you do with it?"
struct Given: Identifiable {
    let id = UUID()
    let payload: ChainPayload
    /// A few words for the top of the list: "A photo", "A PDF · 2 pages"...
    let label: String

    /// Markup (HTML/XML) stripped down to its readable words, so a tool — and the chooser preview —
    /// gets the text a person would read, never a wall of tags. Plain text passes straight through.
    static func readable(_ raw: String, ext: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let looksMarkup = ["html", "htm", "xml", "xhtml", "svg"].contains(ext) || trimmed.hasPrefix("<")
        guard looksMarkup else { return raw }
        var s = raw
        for tag in ["script", "style", "head"] {   // drop the non-visible blocks whole
            s = s.replacingOccurrences(of: "(?is)<\(tag)\\b.*?</\(tag)>", with: " ", options: .regularExpression)
        }
        s = s.replacingOccurrences(of: "(?s)<[^>]+>", with: " ", options: .regularExpression)   // then every tag
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'"]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        s = s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n\\s*\\n\\s*\\n+", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// What a file from the Files app is, by its name. nil for a kind of file no tool takes.
    static func from(file url: URL) -> Given? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        let type = UTType(filenameExtension: ext)
        if ext == "pdf" || type?.conforms(to: .pdf) == true {
            return (try? Data(contentsOf: url)).map { Given(payload: .file($0, ext: "pdf"), label: "A PDF") }
        }
        if ChainPayload.isAudio(ext) || type?.conforms(to: .audio) == true {
            return (try? Data(contentsOf: url)).map { Given(payload: .file($0, ext: ChainPayload.isAudio(ext) ? ext : "m4a"), label: "A recording") }
        }
        if type?.conforms(to: .movie) == true {
            // A video stays a file: copy it somewhere it can still be read after the picker closes.
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("tenzy-given-\(UUID().uuidString).\(ext.isEmpty ? "mov" : ext)")
            return (try? FileManager.default.copyItem(at: url, to: copy)) != nil ? Given(payload: .video(copy), label: "A video") : nil
        }
        if type?.conforms(to: .image) == true {
            return (try? Data(contentsOf: url)).flatMap(UIImage.init).map { Given(payload: .image($0), label: "A photo") }
        }
        // Rich documents (Word, RTF, OpenDocument) read via the system's own document reader, so a .docx
        // or .rtf opens into its real words — ready to summarise, translate, turn into a PDF and share —
        // instead of a dead "no tool for that file". Done before the plain-text branch so RTF/Word markup
        // is never dumped raw. (HTML stays in the text branch, where readable() already strips its tags.)
        if let words = richDocumentText(url, ext: ext), !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Given(payload: .text(words), label: url.lastPathComponent)
        }
        if type?.conforms(to: .text) == true, let words = try? String(contentsOf: url, encoding: .utf8) {
            let clean = readable(words, ext: ext)
            guard !clean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            // Name it by the file so the chooser reads "report.html", not a vague "Some text".
            return Given(payload: .text(clean), label: url.lastPathComponent)
        }
        // A saved link (.webloc, .url, or a plist/bookmark that just holds a URL) isn't a dead end: pull the
        // link out and hand it to the link tools (open, scam-check, clean tracking, QR), labelled "A link".
        if let link = linkFromFile(url) {
            return Given(payload: .text(link), label: "A link")
        }
        return nil
    }

    /// Extract the URL from a saved-link file: a .webloc/.fileloc plist with a "URL" key, a .url INI shortcut,
    /// or any small file whose bytes contain a single http(s) link (the binary-plist share files the OS makes).
    static func linkFromFile(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url), data.count < 200_000 else { return nil }
        if let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
            if let dict = obj as? [String: Any] {
                if let s = dict["URL"] as? String, s.hasPrefix("http") { return s }
                for v in dict.values { if let s = v as? String, s.hasPrefix("http") { return s } }
            }
            if let s = obj as? String, s.hasPrefix("http") { return s }
        }
        if let text = String(data: data, encoding: .utf8),
           let r = text.range(of: #"https?://[^\s"'<>]+"#, options: .regularExpression) {
            return String(text[r])
        }
        return nil
    }

    /// The plain words of a rich-text document, read with Foundation's own document reader — no
    /// third-party dependency. On iOS that reader supports RTF (the Office/OpenDocument document types
    /// are macOS-only), so Word .docx / OpenDocument .odt are handled by unzipping instead (richOfficeText).
    /// Nil for anything it can't read, so the caller falls back to the honest message.
    static func richDocumentText(_ url: URL, ext: String) -> String? {
        let types: [String: NSAttributedString.DocumentType] = ["rtf": .rtf, "rtfd": .rtfd]
        if let dt = types[ext], let data = try? Data(contentsOf: url),
           let att = try? NSAttributedString(data: data, options: [.documentType: dt], documentAttributes: nil) {
            return att.string
        }
        return richOfficeText(url, ext: ext)
    }

    /// Word .docx, OpenDocument .odt and Excel .xlsx are ZIP packages; read the entry that holds the body
    /// with Foundation's own zip reader and turn it into text. Dependency-free. Nil if it isn't one of
    /// those or can't be read.
    static func richOfficeText(_ url: URL, ext: String) -> String? {
        if ext == "xlsx" {
            // The first worksheet's rows, with text cells resolved through the shared-strings table.
            guard let sheet = Zip.entryText(in: url, named: "xl/worksheets/sheet1.xml") else { return nil }
            let out = sheetText(sharedStrings: Zip.entryText(in: url, named: "xl/sharedStrings.xml"), sheet: sheet)
            return out.isEmpty ? nil : out
        }
        if ext == "pptx" {
            // Each slide's text, slide after slide (ppt/slides/slide1.xml, slide2.xml, …).
            var slides: [String] = []; var i = 1
            while i <= 300, let xml = Zip.entryText(in: url, named: "ppt/slides/slide\(i).xml") {
                let text = slideText(xml); if !text.isEmpty { slides.append(text) }
                i += 1
            }
            let out = slides.joined(separator: "\n\n")
            return out.isEmpty ? nil : out
        }
        let entry: String
        switch ext { case "docx": entry = "word/document.xml"; case "odt": entry = "content.xml"; default: return nil }
        guard let xml = Zip.entryText(in: url, named: entry) else { return nil }
        var s = xml
        s = s.replacingOccurrences(of: "<w:tab[^>]*/?>", with: "\t", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "</w:p>|<w:br[^>]*/?>|</text:p>|<text:line-break[^>]*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (e, c) in ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'"] { s = s.replacingOccurrences(of: e, with: c) }
        return s.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// Turn an .xlsx worksheet's XML (plus the shared-strings table) into tab/newline text — pure and
    /// testable, so the off-device tests cover it without a real workbook. Cells with t="s" reference a
    /// shared string by index; inline and numeric cells are read directly. Reads a sheet's rows, not formulas.
    static func sheetText(sharedStrings sstXml: String?, sheet sheetXml: String) -> String {
        let shared = Self.sharedStrings(sstXml)
        var rows: [String] = []
        for rowXml in Self.allMatches("<row\\b[^>]*>(.*?)</row>", in: sheetXml, group: 1) {
            let cells = Self.allMatches("<c\\b[^>]*>.*?</c>|<c\\b[^>]*/>", in: rowXml).map { Self.cellValue($0, shared: shared) }
            rows.append(cells.joined(separator: "\t"))
        }
        while rows.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { rows.removeLast() }
        return rows.joined(separator: "\n")
    }

    /// One PowerPoint slide's XML → its readable text: a paragraph (`</a:p>`) becomes a newline, a text run
    /// (`</a:t>`) a space, every tag is dropped and entities decoded. Same rule as the Word Finder's reader.
    static func slideText(_ xml: String) -> String {
        var s = xml.replacingOccurrences(of: "</a:p>", with: "\n").replacingOccurrences(of: "</a:t>", with: " ")
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        s = decodeEntities(s)
        return s.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private static func sharedStrings(_ xml: String?) -> [String] {
        guard let xml else { return [] }
        return allMatches("<si\\b[^>]*>(.*?)</si>", in: xml, group: 1).map { si in
            decodeEntities(allMatches("<t\\b[^>]*>(.*?)</t>", in: si, group: 1).joined())
        }
    }

    private static func cellValue(_ c: String, shared: [String]) -> String {
        let type = allMatches("<c\\b[^>]*\\bt=\"([a-z]+)\"", in: c, group: 1).first
        if type == "inlineStr" {
            return decodeEntities(allMatches("<t\\b[^>]*>(.*?)</t>", in: c, group: 1).joined())
        }
        guard let v = allMatches("<v\\b[^>]*>(.*?)</v>", in: c, group: 1).first else { return "" }
        if type == "s", let idx = Int(v.trimmingCharacters(in: .whitespaces)), shared.indices.contains(idx) { return shared[idx] }
        return decodeEntities(v)
    }

    private static func decodeEntities(_ s: String) -> String {
        var r = s
        for (e, c) in ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'"] { r = r.replacingOccurrences(of: e, with: c) }
        return r
    }

    private static func allMatches(_ pattern: String, in s: String, group: Int = 0) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let r = m.range(at: group)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
    }

    static func from(text: String) -> Given? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return Given(payload: .text(t), label: TextTidy.details(t).links.isEmpty ? "Some text" : "A link")
    }

    /// A tiny, dependency-free ZIP reader: pulls one entry's bytes out of a ZIP package (a .docx/.odt is
    /// one) by parsing the central directory and inflating the entry with Foundation's Compression
    /// framework. Enough for reading an Office/OpenDocument body; not a general archive extractor.
    enum Zip {
        /// One file inside the archive, as the central directory describes it.
        struct Entry: Identifiable { let id = UUID(); let name: String; let method: Int; let compSize: Int; let uncompSize: Int; let localOff: Int }

        /// Parse the central directory once: the raw bytes plus every entry. nil if it isn't a readable ZIP.
        private static func catalog(_ url: URL) -> (bytes: [UInt8], entries: [Entry])? {
            guard let raw = try? Data(contentsOf: url), raw.count > 22 else { return nil }
            let d = [UInt8](raw); let n = d.count
            func u16(_ o: Int) -> Int { Int(d[o]) | (Int(d[o + 1]) << 8) }
            func u32(_ o: Int) -> Int { Int(d[o]) | (Int(d[o + 1]) << 8) | (Int(d[o + 2]) << 16) | (Int(d[o + 3]) << 24) }
            // End of central directory (0x06054b50), scanned from the end (a trailing comment is allowed).
            var eocd = -1, i = n - 22, minI = max(0, n - 22 - 65_535)
            while i >= minI { if u32(i) == 0x06054b50 { eocd = i; break }; i -= 1 }
            guard eocd >= 0 else { return nil }
            let count = u16(eocd + 10); var p = u32(eocd + 16)
            var entries: [Entry] = []
            for _ in 0..<count {
                guard p + 46 <= n, u32(p) == 0x02014b50 else { break }
                let method = u16(p + 10), compSize = u32(p + 20), uncompSize = u32(p + 24)
                let nameLen = u16(p + 28), extraLen = u16(p + 30), commentLen = u16(p + 32), localOff = u32(p + 42)
                let nameStart = p + 46
                guard nameStart + nameLen <= n else { break }
                let name = String(decoding: d[nameStart..<nameStart + nameLen], as: UTF8.self)
                entries.append(Entry(name: name, method: method, compSize: compSize, uncompSize: uncompSize, localOff: localOff))
                p = nameStart + nameLen + extraLen + commentLen
            }
            return (d, entries)
        }

        /// Every file path inside the archive, skipping directory entries.
        static func names(in url: URL) -> [String] {
            (catalog(url)?.entries ?? []).map(\.name).filter { !$0.hasSuffix("/") }
        }

        /// Extract one entry's raw bytes (any file type). nil if missing or stored with an unsupported method.
        static func entryData(in url: URL, named wanted: String) -> Data? {
            guard let (d, entries) = catalog(url), let e = entries.first(where: { $0.name == wanted }) else { return nil }
            let n = d.count
            func u16(_ o: Int) -> Int { Int(d[o]) | (Int(d[o + 1]) << 8) }
            func u32(_ o: Int) -> Int { Int(d[o]) | (Int(d[o + 1]) << 8) | (Int(d[o + 2]) << 16) | (Int(d[o + 3]) << 24) }
            guard e.localOff + 30 <= n, u32(e.localOff) == 0x04034b50 else { return nil }
            let dataStart = e.localOff + 30 + u16(e.localOff + 26) + u16(e.localOff + 28)
            guard dataStart + e.compSize <= n else { return nil }
            let comp = Data(d[dataStart..<dataStart + e.compSize])
            if e.method == 0 { return comp }
            if e.method == 8 { return inflate(comp, expected: e.uncompSize) }
            return nil
        }

        /// One entry's bytes decoded as UTF-8 text (how the Office/OpenDocument readers use it).
        static func entryText(in url: URL, named wanted: String) -> String? {
            entryData(in: url, named: wanted).flatMap { String(data: $0, encoding: .utf8) }
        }

        /// Raw DEFLATE inflate (ZIP method 8 stores a headerless deflate stream → COMPRESSION_ZLIB).
        private static func inflate(_ src: Data, expected: Int) -> Data? {
            let cap = (expected > 0 ? expected : src.count * 8) + 1024
            var dst = [UInt8](repeating: 0, count: cap)
            let produced = src.withUnsafeBytes { srcRaw -> Int in
                guard let sp = srcRaw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return dst.withUnsafeMutableBufferPointer { dp in
                    compression_decode_buffer(dp.baseAddress!, cap, sp, src.count, nil, COMPRESSION_ZLIB)
                }
            }
            guard produced > 0 else { return nil }
            return Data(dst[0..<produced])
        }
    }

    /// Archive endings — a ZIP (or similar) holds other files; Tenzy works on what's inside, not the box.
    private static let archiveExts: Set<String> = ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "zipx", "iso"]

    /// A ZIP we can open in-app (the reader handles ZIP, not rar/7z/tar). Drives the Unzip screen.
    static func isZip(_ url: URL) -> Bool { ["zip", "zipx"].contains(url.pathExtension.lowercased()) }

    /// Copy a security-scoped ZIP into a temp file the Unzip screen can read after the picker closes. nil if unreadable.
    static func stageZip(_ url: URL) -> URL? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("tenzy-zip-\(UUID().uuidString).zip")
        return (try? data.write(to: tmp)) != nil ? tmp : nil
    }

    /// A specific, non-dead-end message when a file can't be opened — so a ZIP isn't a vague "couldn't open"
    /// (the app handles files, but an archive is a container of files, not a file to work on).
    static func unsupportedNote(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if archiveExts.contains(ext) {
            return "That's a \(ext.uppercased()) archive — a bundle of other files. Tenzy works on the files inside it, not the box. Open it in the Files app to unzip, then share one of the files from it back here."
        }
        return "Tenzy couldn't open that file, or has no tool for that kind of file yet."
    }
}

/// Inline player for a video result — so a sped-up / trimmed / converted clip is watched in the app
/// before Save or share, the same way photos and PDFs already preview. The player is built once.
private struct VideoResultPreview: View {
    let url: URL
    @State private var player: AVPlayer?
    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity).frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            } else {
                Color.clear.frame(height: 1)
            }
        }
        .onAppear { if player == nil { player = AVPlayer(url: url) } }
        .onDisappear { player?.pause() }
    }
}

/// A full audio player for a result — so a transcribed-to-voice / funny-voice / extracted-audio clip can be
/// heard, scrubbed and skipped before Save or share, instead of a bare "2.8 MB · WAV" or a play-only button.
/// A draggable progress bar, current/total time, and 15-second skip either way. Works on every phone.
private final class AudioScrubModel: ObservableObject {
    @Published var current: Double = 0
    @Published var duration: Double = 0
    @Published var playing = false
    var dragging = false
    private var player: AVPlayer?
    private var token: Any?

    func start(_ url: URL) {
        guard player == nil else { return }
        let p = AVPlayer(url: url); player = p
        // Periodic observer fires on the main queue, so updating @Published here is safe for SwiftUI.
        token = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main) { [weak self] t in
            guard let self else { return }
            if !self.dragging { self.current = t.seconds }
            if let d = self.player?.currentItem?.duration.seconds, d.isFinite, d > 0 { self.duration = d }
        }
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main) { [weak self] _ in
            self?.playing = false; self?.current = 0; self?.player?.seek(to: .zero)
        }
    }
    func toggle() {
        guard let player else { return }
        if playing { player.pause() } else { if duration > 0, current >= duration - 0.1 { seek(0) }; player.play() }
        playing.toggle()
    }
    func skip(_ by: Double) { seek(min(max(current + by, 0), max(duration, 0))) }
    func seek(_ to: Double) { current = to; player?.seek(to: CMTime(seconds: to, preferredTimescale: 600)) }
    func stop() { player?.pause(); if let token { player?.removeTimeObserver(token); self.token = nil } }
}

private struct AudioResultPreview: View {
    let url: URL
    @StateObject private var m = AudioScrubModel()
    var body: some View {
        VStack(spacing: HandySpacing.s8) {
            HStack(spacing: HandySpacing.s24) {
                Button { m.skip(-15) } label: { Image(systemName: "gobackward.15").font(.system(size: 24)) }.buttonStyle(.plain).foregroundStyle(HandyColor.textSecondary)
                Button { m.toggle() } label: { Image(systemName: m.playing ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 44)) }.buttonStyle(.plain).foregroundStyle(HandyColor.accent)
                Button { m.skip(15) } label: { Image(systemName: "goforward.15").font(.system(size: 24)) }.buttonStyle(.plain).foregroundStyle(HandyColor.textSecondary)
            }
            Slider(value: Binding(get: { m.current }, set: { m.current = $0 }), in: 0...max(m.duration, 0.1)) { editing in
                m.dragging = editing
                if !editing { m.seek(m.current) }
            }.tint(HandyColor.accent)
            HStack {
                Text(clock(m.current)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Spacer()
                Text(clock(m.duration)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .onAppear { m.start(url) }
        .onDisappear { m.stop() }
    }
    private func clock(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        return String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }
}

/// Runs `work`, but gives up after `seconds` and returns nil instead of hanging forever — so a video
/// that stalls while downloading from iCloud (or a huge import) can never freeze the picker on an endless
/// "Getting it ready…". A generous limit, so a genuinely large local video still finishes and loads.
fileprivate func loadWithinTimeout<T: Sendable>(_ seconds: Double, _ work: @escaping @Sendable () async -> T?) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { await work() }
        group.addTask { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)); return nil }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
}

/// Tenzy Builder (M2): run a starter or saved tool, or build your own by stacking blocks.
/// Everything here is data over built-in blocks (see ChainRunner), nothing is downloaded or generated as code.
struct BuilderView: View {
    @State private var mine: [Chain] = ChainStore.load()
    @State private var editing: Chain?
    @State private var running: Chain?
    @State private var note: String?
    /// Feedback shown inside the Templates sheet itself (the main `note` sits behind the sheet, unseen).
    @State private var pasteNote: String?
    /// What's on the clipboard right now (Text / Link / Image) for the Paste tile's subtitle, read with
    /// the prompt-free hasStrings/hasImages/hasURLs checks so showing it never triggers the iOS paste prompt.
    @State private var clipKind: String?
    @Environment(\.scenePhase) private var scenePhase
    @State private var ask = ""
    @State private var planning = false
    @State private var sheets: [RunningList.Sheet] = RunningList.all()
    @State private var showSheets = false
    @State private var history = RunHistory.all()
    @State private var showHistory = false
    /// The tool being handed on as a link and a QR code.
    @State private var linking: Chain?
    /// The how-it-works card, until Got it. Never shown to automated runs, which expect the plain screen.
    @AppStorage("builder.introSeen") private var introSeen = false
    /// "What do you have?": narrows the starters to ones that begin with it. nil shows all.
    @State private var have: ChainKind?
    /// Shown at the top of the editor after Describe it, when the request was only half said.
    @State private var editHint: String?
    /// What the request asked for that the built tool does, and doesn't, cover (Describe it only).
    @State private var editGood: [String] = []
    @State private var editGaps: [String] = []
    @State private var editAsk = ""
    /// Describe it found a full Tenzy tool that already does the job; the plan waits behind it.
    @State private var builtIn: PlanCheck.BuiltIn?
    @State private var pendingPlan: ChainPlanner.Plan?
    @State private var renaming: Chain?
    @State private var newName = ""
    /// "Start with what you have": the thing picked, waiting for a tool to be chosen for it.
    @State private var given: Given?
    @State private var unzipping: UnzipTarget?
    @State private var anyPick: PhotosPickerItem?
    @State private var pickingAny = false
    @State private var pickTypes: [UTType] = [.item]
    @State private var gettingReady = false
    // Everything past the two front-door actions lives one tap away, so the start stays one clean page.
    @State private var showMine = false
    @State private var showTemplates = false
    @State private var showGuide = false

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s16) {
            Text(L("Build your own")).font(HandyFont.display).frame(maxWidth: .infinity, alignment: .leading)
            Text(L("Make a tool that does the whole job — it runs on your phone."))
                .font(.system(size: 14)).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
            hero
            if let b = builtIn { builtInCard(b) }
            anythingTiles
            if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            Spacer(minLength: 0)
            HStack(spacing: HandySpacing.s8) {
                footBtn(mine.isEmpty ? "My tools" : "My tools · \(mine.count)") { showMine = true }
                footBtn("Templates") { showTemplates = true }
                footBtn("Guide") { showGuide = true }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, HandySpacing.gutter)
        .padding(.vertical, HandySpacing.s8)
        .sheet(item: $editing) { c in
            NavigationStack {
                ChainEditor(chain: c, hint: editHint, good: editGood, gaps: editGaps, ask: editAsk) { saved in
                    if let i = mine.firstIndex(where: { $0.id == saved.id }) { mine[i] = saved; persist(); editing = nil; editHint = nil }
                    else if BuilderLimits.canSave(savedCount: mine.count, isPremium: StoreManager.shared.isPremium) { mine.append(saved); persist(); editing = nil; editHint = nil }
                    else { proForSave() }   // keep the editor open so the built tool isn't lost; Save works again after upgrading
                }
            }
        }
        .sheet(item: $running) { c in NavigationStack { ChainRunView(chain: c) } }
        .sheet(item: $given) { g in NavigationStack { ToolPickView(given: g, mine: mine) } }
        .sheet(item: $unzipping) { t in
            UnzipView(url: t.url) { g in
                // A file opened from inside the archive → close Unzip, then hand it to the tools.
                unzipping = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { given = g }
            }
        }
        .alert(L("Name this tool"), isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField(L("Name"), text: $newName)
            Button(L("Save")) {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if let r = renaming, !name.isEmpty, let i = mine.firstIndex(where: { $0.id == r.id }) { mine[i].name = name; persist() }
                renaming = nil
            }
            Button(L("Cancel"), role: .cancel) { renaming = nil }
        }
        .fileImporter(isPresented: $pickingAny, allowedContentTypes: pickTypes) { r in
            guard case .success(let url) = r else { return }
            if Given.isZip(url), let staged = Given.stageZip(url) { note = nil; unzipping = UnzipTarget(url: staged); return }
            if let g = Given.from(file: url) { note = nil; given = g } else { note = Given.unsupportedNote(for: url) }
        }
        .onChange(of: anyPick) { _, item in
            guard let item else { return }
            anyPick = nil; gettingReady = true; note = nil
            Task {
                var g: Given?
                let isMovie = item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) })
                if isMovie {
                    // Never hang on a large or still-in-iCloud video: give it room, but always resolve.
                    if let movie = await loadWithinTimeout(180) { try? await item.loadTransferable(type: MovieImport.self) } {
                        g = Given(payload: .video(movie.url), label: "A video")
                    }
                } else if let img = await loadWithinTimeout(120, { (try? await item.loadTransferable(type: Data.self)).flatMap(UIImage.init) }) {
                    g = Given(payload: .image(img), label: "A photo")
                }
                await MainActor.run {
                    gettingReady = false
                    if let g { given = g }
                    else if isMovie { note = "That video didn't load. If it's a large iCloud video, open it once in Photos to download it to this phone, then pick it again." }
                    else { note = "That photo didn't load. If it's a large iCloud photo, open it once in Photos to download it, then pick it again." }
                }
            }
        }
        .sheet(isPresented: $showSheets, onDismiss: { sheets = RunningList.all() }) { NavigationStack { SheetsView() } }
        .sheet(isPresented: $showHistory, onDismiss: { history = RunHistory.all() }) { NavigationStack { HistoryView() } }
        .sheet(item: $linking) { c in NavigationStack { ToolLinkSheet(chain: c) } }
        .sheet(isPresented: $showMine) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: HandySpacing.s12) {
                        if mine.isEmpty {
                            Text(L("Nothing saved yet. Build one from the start screen and it lands here."))
                                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        }
                        ForEach(mine) { c in row(c, mine: true) }
                        if !sheets.isEmpty {
                            NavigationLink { SheetsView() } label: { subLinkRow("My sheets", sheets.count == 1 ? "1 sheet your tools add to" : "\(sheets.count) sheets your tools add to", "tablecells") }.buttonStyle(.plain)
                        }
                        if !history.isEmpty {
                            NavigationLink { HistoryView() } label: { subLinkRow("Recent results", history.count == 1 ? "The last thing a tool made" : "The last \(history.count) things your tools made", "clock.arrow.circlepath") }.buttonStyle(.plain)
                        }
                    }.padding(HandySpacing.gutter)
                }
                .navigationTitle(L("My tools")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { showMine = false } } }
            }
        }
        .sheet(isPresented: $showTemplates, onDismiss: { pasteNote = nil }) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: HandySpacing.s12) {
                        HStack {
                            Button { editHint = nil; editing = Chain(id: UUID().uuidString, name: "", steps: []); showTemplates = false } label: { Label(L("Blank"), systemImage: "plus") }.font(HandyFont.caption)
                            Spacer()
                            Button {
                                let clip = UIPasteboard.general.string ?? ""
                                if let c = ToolLink.chain(from: clip) {
                                    if BuilderLimits.canSave(savedCount: mine.count, isPremium: StoreManager.shared.isPremium) {
                                        mine.append(c); persist(); pasteNote = nil; note = "Added \(c.name)."; showTemplates = false
                                    } else {
                                        pasteNote = "You've saved the \(BuilderLimits.freeSaved) tools the free plan keeps. Go Pro to add more."
                                    }
                                } else {
                                    pasteNote = clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? "Nothing's copied yet. On another Tenzy, open a tool and tap “Copy to share”, then come back and tap Paste."
                                        : "That's not a Tenzy tool link. Use a tool's “Copy to share” button, then tap Paste here."
                                }
                            } label: { Label(L("Paste a tool"), systemImage: "doc.on.clipboard") }.font(HandyFont.caption)
                        }
                        if let pasteNote {
                            Text(pasteNote).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity)
                        }
                        Picker(L("What do you have?"), selection: $have) {
                            Text(L("All")).tag(ChainKind?.none)
                            Text(L("Photo")).tag(ChainKind?.some(.image))
                            Text(L("Text")).tag(ChainKind?.some(.text))
                            Text(L("Video")).tag(ChainKind?.some(.video))
                            Text(L("Sound")).tag(ChainKind?.some(.audio))
                            Text(L("PDF")).tag(ChainKind?.some(.pdf))
                        }.pickerStyle(.segmented).accessibilityIdentifier("starter-filter")
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: HandySpacing.s12), GridItem(.flexible(), spacing: HandySpacing.s12)], spacing: HandySpacing.s12) {
                            ForEach(BuilderIntro.starters(for: have).filter { $0.unavailable == nil }) { c in templateCard(c) }
                        }
                    }.padding(HandySpacing.gutter)
                }
                .navigationTitle(L("Templates")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { showTemplates = false } } }
            }
        }
        .sheet(isPresented: $showGuide) {
            NavigationStack {
                ScrollView {
                    BuilderIntroCard(onShow: {
                        if var demo = ChainTemplates.all.first(where: { $0.id == BuilderIntro.demoID }) {
                            demo.id = UUID().uuidString; demo.name += " (mine)"; editing = demo; showGuide = false
                        }
                    }, onDone: { showGuide = false })
                    .padding(HandySpacing.gutter)
                }
                .navigationTitle(L("How building works")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { showGuide = false } } }
            }
        }
        .onChange(of: running?.id) { _, now in if now == nil { sheets = RunningList.all(); history = RunHistory.all() } }   // a run may have added to a sheet, and to the recent results
        .onChange(of: given?.id) { _, now in if now == nil { history = RunHistory.all() } }
        .onAppear { openReminded() }
        .onReceive(NotificationCenter.default.publisher(for: .openTool)) { _ in
            // A tool opened from a link was saved before this arrived, so pick it up.
            let saved = ChainStore.load()
            if saved.count > mine.count, let added = saved.last { mine = saved; note = "Added \(added.name)." }
            openReminded()
        }
    }

    /// Saves the tools and keeps the phone's reminders and the home-screen widget in step with them.
    private func persist() { ChainStore.save(mine); ToolSchedules.sync(mine); WidgetCenter.shared.reloadTimelines(ofKind: "ToolsWidget") }

    /// Free keeps a couple of your own tools; Pro lifts the cap. Shown when a free user tries to save past it.
    private func proForSave() {
        note = "Free keeps \(BuilderLimits.freeSaved) of your own tools. Go Pro to save as many as you like."
        NotificationCenter.default.post(name: .showPaywall, object: nil)
    }

    /// "Start with what you have": six objects on one page, nothing to scroll — pick the thing and
    /// Tenzy lists the tools that fit it.
    private var anythingTiles: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("…or start with what you have")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: HandySpacing.s8) {
                PhotosPicker(selection: $anyPick, matching: .images) { objTile("Photo") }.accessibilityIdentifier("have-photo")
                PhotosPicker(selection: $anyPick, matching: .videos) { objTile("Video") }.accessibilityIdentifier("have-video")
                Button { pickTypes = audioImportTypes; pickingAny = true } label: { objTile("Audio") }.accessibilityIdentifier("have-audio")
            }
            HStack(spacing: HandySpacing.s8) {
                Button { pickTypes = [.pdf]; pickingAny = true } label: { objTile("PDF") }.accessibilityIdentifier("have-pdf")
                Button { pickTypes = [.item]; pickingAny = true } label: { objTile("File") }.accessibilityIdentifier("have-file")
                Button {
                    let pb = UIPasteboard.general
                    // Prefer an image when the clipboard reports one, reading it robustly — plain
                    // `pb.image` returns nil for HEIC / file-backed / multi-representation items that
                    // still set `hasImages`, which used to dead-end the tile that said "Image copied".
                    if pb.hasImages, let img = pasteboardImage() { note = nil; given = Given(payload: .image(img), label: "A photo") }
                    else if let g = Given.from(text: pb.string ?? "") { note = nil; given = g }
                    else if let img = pasteboardImage() { note = nil; given = Given(payload: .image(img), label: "A photo") }
                    else { note = "There is nothing copied to paste. Copy some text, a link or a picture first." }
                } label: { objTile("Paste", sub: clipKind.map { "\($0) copied" } ?? "Nothing copied") }.accessibilityIdentifier("have-paste")
            }
            if gettingReady {
                HStack(spacing: HandySpacing.s8) {
                    ProgressView()
                    Text(L("Got it — getting your file ready. A large or iCloud video can take a moment.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(HandySpacing.s12)
                .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .onAppear { refreshClipKind() }
        .onChange(of: scenePhase) { _, p in if p == .active { refreshClipKind() } }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in refreshClipKind() }
    }
    /// What's on the clipboard, read prompt-free — hasImages/hasURLs/hasStrings return the type without
    /// exposing the contents, so only the Paste tap (which reads it) ever triggers the iOS paste prompt.
    private func refreshClipKind() {
        let pb = UIPasteboard.general
        clipKind = pb.hasImages ? "Image" : pb.hasURLs ? "Link" : pb.hasStrings ? "Text" : nil
    }
    /// Reads an image from the clipboard even when `UIPasteboard.image` returns nil — HEIC, file-backed
    /// or multi-representation items that still report `hasImages`. Falls back to decoding the raw data
    /// for each known image type, then any item carrying an image-conforming representation.
    private func pasteboardImage() -> UIImage? {
        let pb = UIPasteboard.general
        if let img = pb.image { return img }
        for t in [UTType.png, .jpeg, .heic, .tiff, .gif, .bmp, .webP, .image] {
            if let d = pb.data(forPasteboardType: t.identifier), let im = UIImage(data: d) { return im }
        }
        for item in pb.items {
            for (type, value) in item where (UTType(type)?.conforms(to: .image) ?? false) {
                if let im = value as? UIImage { return im }
                if let d = value as? Data, let im = UIImage(data: d) { return im }
            }
        }
        return nil
    }
    private func objTile(_ title: String, sub: String? = nil) -> some View {
        VStack(spacing: 2) {
            Text(L(title)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
            if let sub { Text(L(sub)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).lineLimit(1) }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .cardStyle(padding: HandySpacing.s12)
    }
    private func footBtn(_ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(HandyFont.caption).lineLimit(1).frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(.bordered).tint(HandyColor.accent)
    }
    private func subLinkRow(_ title: String, _ sub: String, _ icon: String) -> some View {
        HStack(spacing: HandySpacing.s12) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(HandyColor.accent).frame(width: 38, height: 38).background(HandyColor.accent.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                Text(sub).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(HandyColor.textSecondary)
        }.cardStyle(padding: HandySpacing.s12)
    }

    /// A tapped reminder lands here: open that tool ready to run.
    private func openReminded() {
        guard let id = ToolSchedules.takePending(), let c = mine.first(where: { $0.id == id }) else { return }
        editing = nil; running = c
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Label(L("Describe it"), systemImage: "sparkles").font(HandyFont.cardTitle)
            TextField(L("e.g. shrink a photo under 1 MB and hide where it was taken"), text: $ask, axis: .vertical)
                .lineLimit(3...8).textFieldStyle(.roundedBorder).accessibilityIdentifier("describe-field")
            Button {
                planning = true; builtIn = nil; note = nil
                let request = ask
                Task {
                    let p = await ChainPlanner.plan(request)
                    await MainActor.run {
                        planning = false
                        pendingPlan = p
                        if let b = PlanCheck.builtIn(request) { withAnimation { builtIn = b }; return }
                        if let p { openPlanned(p, ask: request) }
                        else { note = "I couldn't tell what you'd like done. Say what you have (a photo, a PDF, a video, a recording, a link or some text) and what should happen to it." }
                    }
                }
            } label: { Label(planning ? "Working…" : "Build it for me", systemImage: "wand.and.stars").frame(maxWidth: .infinity) }
                .primaryButton().disabled(planning || ask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }.cardStyle()
    }

    /// Open the editor on a planned tool, with an honest note of what it covers and what it can't do.
    private func openPlanned(_ p: ChainPlanner.Plan, ask request: String) {
        let r = PlanCheck.report(request, p.chain)
        editGood = r.good; editGaps = r.gaps; editAsk = request
        editHint = p.guessed ? "That wasn't much to go on, so this is my best guess. Change, add or remove any step before you save." : nil
        builtIn = nil
        editing = p.chain
    }

    /// "Tenzy already has this": the full tool first, building a custom one second.
    private func builtInCard(_ b: PlanCheck.BuiltIn) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Tenzy already has a tool for this"), systemImage: "checkmark.seal.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.accent)
            Text(L(b.name)).font(HandyFont.cardTitle)
            Text(L(b.why)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            Button { let id = b.id; builtIn = nil; NotificationCenter.default.post(name: .openTool, object: id) } label: {
                Label("\(L("Open")) \(L(b.name))", systemImage: "arrow.right.circle.fill").frame(maxWidth: .infinity)
            }.primaryButton()
            if let p = pendingPlan {
                Button(L("Build my own tool anyway")) { openPlanned(p, ask: ask) }.textButton().font(HandyFont.caption).frame(maxWidth: .infinity)
            }
        }
        .cardStyle(padding: HandySpacing.s16)
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous).stroke(HandyColor.accent, lineWidth: 1.5))
    }

    private func templateCard(_ c: Chain) -> some View {
        // A faint gradient drawn from the tool's own step colours, so each card reads at a glance as
        // "the photo one", "the receipt one" — and the WHOLE card runs the tool, not just a small link.
        let tints = c.steps.map(\.block.tint)
        let g = [(tints.first ?? HandyColor.accent).opacity(0.18), (tints.last ?? tints.first ?? HandyColor.accent).opacity(0.10)]
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(spacing: -8) {
                ForEach(Array(c.steps.prefix(3).enumerated()), id: \.offset) { _, s in BlockBadge(block: s.block, size: 30) }
            }
            Text(c.name).font(HandyFont.bodyStrong).lineLimit(2).multilineTextAlignment(.leading)
            Text(c.about).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).lineLimit(2).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            HStack {
                Label(L("Use"), systemImage: "play.circle.fill").font(HandyFont.micro).foregroundStyle(HandyColor.accent)
                Spacer()
                // Stays its own tap target (a Button inside the card), so only the rest of the card runs it.
                Button(L("Edit copy")) { var k = c; k.id = UUID().uuidString; k.name += " (mine)"; editHint = nil; editing = k }
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .padding(HandySpacing.s12)
        .background {
            ZStack {
                HandyColor.surface
                LinearGradient(colors: g, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { running = c }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(c.name). \(c.about) Opens the tool.")
    }

    private func row(_ c: Chain, mine isMine: Bool) -> some View {
        HStack(spacing: HandySpacing.s12) {
            if let f = c.steps.first { BlockBadge(block: f.block) }
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name).font(HandyFont.bodyStrong).lineLimit(2)
                Text(c.steps.map(\.block.title).joined(separator: "  ›  ")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
                if let when = c.schedule {
                    Label(when.label(uses24h: ToolSchedules.uses24h), systemImage: "bell").font(HandyFont.caption).foregroundStyle(HandyColor.accent)
                }
                if c.unavailable != nil {
                    Label(L("Has a step this phone can't run"), systemImage: "exclamationmark.triangle").font(HandyFont.caption).foregroundStyle(HandyColor.amber)
                }
            }
            Spacer(minLength: 0)
            Menu {
                Button(L("Edit")) { editHint = nil; editing = c }
                Button(L("Rename")) { newName = c.name; renaming = c }
                if mine.first?.id != c.id {
                    Button(L("Move to top")) { mine.removeAll { $0.id == c.id }; mine.insert(c, at: 0); persist(); note = "\(c.name) is now first, here and on the My Tools widget." }
                }
                Button(L("Put on Home Screen")) {
                    note = "Add the My Tools widget: touch and hold the Home Screen, tap Edit, then Add Widget, choose Tenzy, then My Tools. Your first tools appear on it, one tap each. Use Move to top to choose which."
                }
                Button(L("Duplicate")) {
                    guard BuilderLimits.canSave(savedCount: mine.count, isPremium: StoreManager.shared.isPremium) else { proForSave(); return }
                    var k = c; k.id = UUID().uuidString; k.name += " copy"; k.schedule = nil
                    mine.append(k); persist(); note = "Duplicated as \(k.name)."
                }
                Button(L("Copy to share")) { UIPasteboard.general.string = c.shareText; note = "Copied. Paste it into Tenzy on another phone." }
                if ToolLink.live { Button(L("Share as a link or QR code")) { linking = c } }
                Button(L("Delete"), role: .destructive) { mine.removeAll { $0.id == c.id }; persist() }
            } label: { Image(systemName: "ellipsis.circle").accessibilityLabel(L("More")).font(.system(size: 20)).frame(width: 44, height: 44) }
            // A compact button with room around its word, so it never looks squeezed beside a long name.
            Button { running = c } label: {
                Text(L("Run")).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.accent)
                    .padding(.horizontal, HandySpacing.s16).frame(minHeight: 44)
                    .background(HandyColor.accentSoft, in: Capsule())
            }.buttonStyle(.plain).fixedSize().accessibilityLabel("Run \(c.name)")
        }.cardStyle(padding: HandySpacing.s12)
    }
}

/// The builder: a vertical flow from what you give, through each step, to what you get. Each step shows what it
/// does to a sample while you build, so you see the tool working before you save it.
private struct ChainEditor: View {
    @State var chain: Chain
    /// A line from Describe it shown above the steps, e.g. that the tool is a best guess.
    var hint: String? = nil
    /// From Describe it: what was asked for that this tool covers, what it can't do, and the request itself.
    var good: [String] = []
    var gaps: [String] = []
    var ask: String = ""
    var onSave: (Chain) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = StoreManager.shared
    @State private var showPro = false
    @State private var previews: [StepPreview?] = []
    @State private var inputPreview: StepPreview?

    private var startKind: ChainKind { chain.steps.first?.block.takes ?? .image }
    private var endKind: ChainKind? { chain.steps.last?.block.gives }
    /// What the person said they start with, before there is a first step to tell us.
    @State private var startChoice: ChainKind?
    private var fitting: [Block] {
        guard let end = endKind else { return startChoice.map(Block.starting(with:)) ?? [] }
        return Block.allCases.filter { end.feeds($0.takes) }
    }
    /// Steps that fit here and that this phone can run, and the ones that fit but it can't.
    private var options: [Block] { fitting.filter { $0.unavailable == nil } }
    private var missing: [Block] { fitting.filter { $0.unavailable != nil } }

    static func icon(for k: ChainKind) -> String {
        switch k {
        case .text: return "text.alignleft"; case .video: return "film"; case .audio: return "waveform"; case .pdf: return "doc.richtext"
        case .image, .photoFile, .file: return "photo"
        }
    }
    /// A name is optional: a tool saved without one is named for what it does.
    private var valid: Bool { chain.problem(starting: startKind) == nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TextField(L("Name your tool"), text: $chain.name).font(HandyFont.title).accessibilityIdentifier("tool-name")
                Text(chain.name.trimmingCharacters(in: .whitespaces).isEmpty && !chain.steps.isEmpty ? "No name yet. It will be saved as \u{201C}\(ChainText.autoName(chain))\u{201D}." : "Tap the name to change it.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, HandySpacing.s16)
                if let hint {
                    Label(hint, systemImage: "sparkles").font(HandyFont.caption).foregroundStyle(HandyColor.accent)
                        .frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12).padding(.bottom, HandySpacing.s12)
                }
                if !good.isEmpty || !gaps.isEmpty { coverage.padding(.bottom, HandySpacing.s12) }
                if chain.steps.isEmpty, startChoice == nil {
                    startPicker
                } else {
                    let k = chain.steps.isEmpty ? (startChoice ?? .image) : startKind
                    node(icon: Self.icon(for: k), title: "You give it \(k.label)", sub: chain.steps.isEmpty ? "Now add a first step. You only see steps that work with \(k.label)." : "Preview uses a sample so you can see each step work.")
                    if chain.steps.isEmpty {
                        Button(L("Start with something else")) { startChoice = nil }.font(HandyFont.caption).padding(.top, HandySpacing.s8)
                    }
                }
                ForEach(Array(chain.steps.enumerated()), id: \.offset) { i, s in
                    connector
                    stepCard(i, s)
                }
                if !(chain.steps.isEmpty && startChoice == nil) {
                    connector
                    addMenu
                    if !store.isPremium {
                        Text(L("Free tools use the basic steps. The ones marked Pro unlock with Tenzy Pro — tap one to see what you get."))
                            .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).padding(.top, HandySpacing.s8)
                    }
                    if let first = missing.first, let why = first.unavailable {
                        Text(missing.count == 1 ? "\(first.title) is greyed out on this phone. \(why)" : "\(missing.count) steps are greyed out because this phone can't run them. Everything else works.")
                            .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).padding(.top, HandySpacing.s8)
                    }
                }
                if let end = endKind {
                    connector
                    node(icon: "checkmark.circle.fill", title: "You get \(end.label)", sub: "Then copy it, save it or share it.", tint: HandyColor.success)
                }
                if endKind != nil { finishCard.padding(.top, HandySpacing.s12) }
                if endKind != nil { ScheduleCard(schedule: $chain.schedule).padding(.top, HandySpacing.s12) }
                if let p = chain.problem(starting: startKind), !chain.steps.isEmpty {
                    Text(p).font(HandyFont.caption).foregroundStyle(HandyColor.danger).padding(.top, HandySpacing.s12)
                }
            }.padding(HandySpacing.gutter)
        }
        .background(Ground())
        .navigationTitle(L("Build a tool")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button(L("Save")) { if !store.isPremium && chain.needsPro { showPro = true } else { var c = chain; c.name = ChainText.savedName(c); onSave(c) } }.disabled(!valid) }
        }
        .task(id: chain.steps) { await refreshPreviews() }
        .sheet(isPresented: $showPro) { PaywallView().environmentObject(StoreManager.shared) }
    }

    /// "Then": where the result goes. Email and Message open already filled in, so sending is one tap.
    private var finishCard: some View {
        let kind = Binding<ChainFinish.Kind>(
            get: { chain.finish?.kind ?? .share },
            set: { k in var f = chain.finish ?? ChainFinish(); f.kind = k; chain.finish = f })
        let to = Binding<String>(
            get: { chain.finish?.to ?? "" },
            set: { t in var f = chain.finish ?? ChainFinish(); f.to = t; chain.finish = f })
        let onePdf = Binding<Bool>(get: { chain.combine == true }, set: { chain.combine = $0 ? true : nil; if !$0 { chain.onePage = nil } })
        let onePage = Binding<Bool>(get: { chain.onePage == true }, set: { chain.onePage = $0 ? true : nil })
        let collage = Binding<Bool>(get: { chain.collage == true }, set: { chain.collage = $0 ? true : nil; if $0 { chain.combine = nil; chain.onePage = nil; chain.gif = nil; chain.versus = nil } })
        let oneGif = Binding<Bool>(get: { chain.gif == true }, set: { chain.gif = $0 ? true : nil; if $0 { chain.combine = nil; chain.onePage = nil; chain.collage = nil; chain.versus = nil } })
        let versus = Binding<Bool>(get: { chain.versus == true }, set: { chain.versus = $0 ? true : nil; if $0 { chain.combine = nil; chain.onePage = nil; chain.collage = nil; chain.gif = nil } })
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            if startKind == .image, endKind != .text {
                Toggle(L("Put all pages or photos into one PDF"), isOn: Binding(get: { onePdf.wrappedValue }, set: { onePdf.wrappedValue = $0; if $0 { chain.collage = nil; chain.gif = nil; chain.versus = nil } })).font(HandyFont.caption).accessibilityIdentifier("finish-one-pdf")
                if chain.combine == true {
                    Toggle(L("All on a single page (both sides of an ID)"), isOn: onePage).font(HandyFont.caption).accessibilityIdentifier("finish-one-page")
                }
                if endKind == .image || endKind == .photoFile {
                    Toggle(L("Put all photos into one picture (a collage)"), isOn: collage).font(HandyFont.caption).accessibilityIdentifier("finish-collage")
                    Toggle(L("Play all photos as one GIF"), isOn: oneGif).font(HandyFont.caption).accessibilityIdentifier("finish-gif")
                    Toggle(L("Before and after: two photos side by side"), isOn: versus).font(HandyFont.caption).accessibilityIdentifier("finish-versus")
                }
            }
            if startKind == .pdf, endKind == .pdf {
                Toggle(L("Join several PDFs into one"), isOn: onePdf).font(HandyFont.caption).accessibilityIdentifier("finish-join-pdf")
            }
            if endKind != .text {
                TextField(L("File name (optional), e.g. Signed form {date}"), text: Binding(get: { chain.fileName ?? "" }, set: { chain.fileName = $0.isEmpty ? nil : $0 }))
                    .font(HandyFont.caption).autocorrectionDisabled()
                    .padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("finish-file-name")
                Text(L("Write {date} where today's date should go.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Text(L("Then")).font(HandyFont.bodyStrong)
            Picker(L("Then"), selection: kind) {
                Text(L("Share")).tag(ChainFinish.Kind.share)
                Text(L("Email")).tag(ChainFinish.Kind.mail)
                Text(L("Message")).tag(ChainFinish.Kind.message)
                if endKind == .text { Text(L("Open")).tag(ChainFinish.Kind.open) }
            }.pickerStyle(.segmented).accessibilityIdentifier("finish-kind")
            if kind.wrappedValue == .open {
                Text(L("When the tool finishes, the link it made opens.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            if kind.wrappedValue == .mail || kind.wrappedValue == .message {
                TextField(kind.wrappedValue == .mail ? "Email address (optional)" : "Phone number (optional)", text: to)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .keyboardType(kind.wrappedValue == .mail ? .emailAddress : .phonePad)
                    .padding(HandySpacing.s12).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("finish-to")
                Text(kind.wrappedValue == .mail
                     ? "When the tool finishes, an email opens with the result attached. You tap Send."
                     : "When the tool finishes, a message opens with the result attached. You tap Send.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        }.cardStyle(padding: HandySpacing.s12)
    }

    private var connector: some View {
        Image(systemName: "arrow.down").font(.system(size: 14, weight: .bold)).foregroundStyle(HandyColor.textSecondary).frame(height: 28).accessibilityHidden(true)
    }

    private func node(icon: String, title: String, sub: String, tint: Color = HandyColor.accent) -> some View {
        HStack(spacing: HandySpacing.s12) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint).frame(width: 38, height: 38).background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(HandyFont.bodyStrong)
                Text(sub).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
    }

    private var addMenu: some View {
        Menu {
            // Grouped by what you want to get done, and only steps that fit what the tool has at this point.
            ForEach(Block.grouped(options), id: \.goal) { g in
                Section(g.goal) {
                    ForEach(g.blocks) { b in
                        if b.isProStep, !store.isPremium {
                            Button { showPro = true } label: { Label("\(b.title) — Pro", systemImage: "lock.fill") }
                        } else {
                            Button { chain.steps.append(ChainStep(block: b, settings: defaults(b))) } label: { Label(b.title, systemImage: b.icon) }
                        }
                    }
                }
            }
            if !missing.isEmpty {
                Section(L("Not on this phone")) {
                    ForEach(missing) { b in Button {} label: { Label(b.title, systemImage: b.icon) }.disabled(true) }
                }
            }
        } label: {
            Label(chain.steps.isEmpty ? "Add the first step" : "Add a step", systemImage: "plus.circle.fill").font(HandyFont.bodyStrong).frame(maxWidth: .infinity, minHeight: 48)
                .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
        }.accessibilityIdentifier("add-step")
    }

    /// First question of a new tool: what do you have? Everything offered after this fits the answer.
    /// What you asked for vs. what this tool does — honest, so nothing is quietly left out.
    private var coverage: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !ask.isEmpty {
                Text("\u{201C}\(ask)\u{201D}").font(HandyFont.caption.italic()).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(good, id: \.self) { g in
                Label { Text("\(L("Does")): \(L(g))").font(HandyFont.caption) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.green) }
            }
            ForEach(gaps, id: \.self) { g in
                Label { Text("\(L("Can't do yet")): \(L(g))").font(HandyFont.caption) } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(HandyColor.amber) }
            }
            if !gaps.isEmpty {
                Text(L("This tool does the rest. Tell us what's missing and we'll add it in a coming update.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                if let u = Self.requestURL(ask: ask, gaps: gaps) {
                    Link(destination: u) { Label(L("Ask for it"), systemImage: "envelope") }.font(HandyFont.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: HandySpacing.s12)
    }

    static func requestURL(ask: String, gaps: [String]) -> URL? {
        var c = URLComponents(); c.scheme = "mailto"; c.path = SUPPORT_EMAIL
        c.queryItems = [URLQueryItem(name: "subject", value: "Tenzy: please add to Build your own"),
                        URLQueryItem(name: "body", value: "I asked for: \(ask)\n\nMissing: \(gaps.joined(separator: ", "))\n")]
        return c.url
    }

    private var startPicker: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Text(L("What do you start with?")).font(HandyFont.cardTitle)
            HStack(spacing: HandySpacing.s12) {
                startButton(.image, "A photo", "photo")
                startButton(.text, "Text, link or file", "text.alignleft")
                startButton(.video, "A video", "film")
            }
            HStack(spacing: HandySpacing.s12) {
                startButton(.audio, "A recording", "waveform")
                startButton(.pdf, "A PDF", "doc.richtext")
            }
            Text(L("“Text, link or file” also reads a file for its words — a CSV, a contact card (.vcf), a calendar file (.ics), .txt, .json or a web page. Photos and scans start with “A photo”; documents with “A PDF”; a recording writes out what was said. Tenzy handles each file as what it really is.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func startButton(_ kind: ChainKind, _ title: String, _ icon: String) -> some View {
        Button { startChoice = kind } label: {
            VStack(spacing: HandySpacing.s8) {
                Image(systemName: icon).font(.title2)
                Text(title).font(HandyFont.bodyStrong).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
        }
        .accessibilityIdentifier(kind == .text ? "start-text" : kind == .video ? "start-video" : kind == .audio ? "start-audio" : kind == .pdf ? "start-pdf" : "start-photo")
    }

    private func stepCard(_ i: Int, _ s: ChainStep) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s12) {
                BlockBadge(block: s.block)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: HandySpacing.s8) {
                        Text("\(i + 1). \(s.block.title)").font(HandyFont.bodyStrong)
                        if s.block.isProStep, !store.isPremium { ProTag() }
                    }
                    Text(s.block.blurb).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                Spacer(minLength: 0)
                Menu {
                    if i > 0 { Button { chain.steps.swapAt(i, i - 1) } label: { Label(L("Move up"), systemImage: "arrow.up") } }
                    if i < chain.steps.count - 1 { Button { chain.steps.swapAt(i, i + 1) } label: { Label(L("Move down"), systemImage: "arrow.down") } }
                    Button(role: .destructive) { chain.steps.remove(at: i) } label: { Label(L("Remove step"), systemImage: "trash") }
                } label: { Image(systemName: "ellipsis").accessibilityLabel(L("More")).frame(width: 44, height: 44) }
            }
            settings(i)
            previewView(i < previews.count ? previews[i] : nil)
        }.cardStyle(padding: HandySpacing.s12)
    }

    @ViewBuilder private func previewView(_ p: StepPreview?) -> some View {
        Group {
            switch p {
            case .none: HStack { ProgressView().controlSize(.small); Text(L("Trying it on a sample…")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            case .text(let t): Text(t).font(.system(.caption, design: .monospaced)).lineLimit(6).frame(maxWidth: .infinity, alignment: .leading)
            case .image(let i): Image(uiImage: i).resizable().scaledToFit().frame(maxHeight: 120).clipShape(RoundedRectangle(cornerRadius: 8))
            case .file(let d): Label(d, systemImage: "doc.fill").font(HandyFont.caption)
            case .failed(let w): Label(w, systemImage: "exclamationmark.triangle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.amber)
            }
        }
        .padding(HandySpacing.s8).frame(maxWidth: .infinity, alignment: .leading)
        .background(HandyColor.bg, in: RoundedRectangle(cornerRadius: HandyRadius.small, style: .continuous))
    }

    /// Runs the chain on a sample one step at a time, keeping every step's result for the strips above.
    /// The sample page as it looks just before step `i`, for placing stamps on.
    private func pageBefore(_ i: Int) -> UIImage? {
        if i == 0 { return SampleAssets.receipt() }
        if i - 1 < previews.count, case .image(let img)? = previews[i - 1] { return img }
        return nil
    }

    private func refreshPreviews() async {
        let steps = chain.steps
        previews = Array(repeating: nil, count: steps.count)
        guard let first = steps.first else { return }
        if [.video, .audio, .pdf].contains(first.block.takes) {
            // There is no sample video, recording or PDF to try steps on, so say what each one will do instead of showing a result.
            previews = steps.map { s in s.block.unavailable.map { StepPreview.failed($0) } ?? StepPreview.file(s.block.blurb) }
            return
        }
        try? await Task.sleep(nanoseconds: 250_000_000)   // let a stepper settle before re-running
        if Task.isCancelled { return }
        var value: ChainPayload
        switch first.block {
        case .readText, .stamp, .photoPdf: value = .image(SampleAssets.receipt())   // paperwork steps preview on a document
        case .readCode: value = ChainText.qr("https://example.com/sale?utm_source=poster").map { .image($0) } ?? .image(SampleAssets.photo())
        case .pageText: value = .text("https://example.com/article")
        case _ where first.block.takes == .text: value = .text(Self.sampleText)
        default: value = .image(SampleAssets.photo())
        }
        for (i, step) in steps.enumerated() {
            if Task.isCancelled { return }
            if !value.kind.feeds(step.block.takes) { previews[i] = .failed("Needs \(step.block.takes.label) from the step above."); continue }
            if let why = step.block.unavailable { previews[i] = .failed("Not available on this phone. " + why); return }
            if ChainExtras.noPreview.contains(step.block), step.block != .pageText {
                // These need a voice, a translator or the writing model, so the sample isn't run through them.
                previews[i] = .file(step.block.blurb)
                if step.block.gives == .text { continue }      // the steps below still preview, on the text as it was
                for j in (i + 1)..<steps.count { previews[j] = .file(steps[j].block.blurb) }
                return
            }
            switch await ChainRunner.apply(step, to: value, dryRun: true) {   // a preview never saves anything
            case .success(let next):
                value = next
                if Task.isCancelled { return }
                previews[i] = Self.preview(next)
            case .failure(let f):
                let isLast = i == steps.count - 1
                if case .nothingFound = f, !isLast, step.block.takes == step.block.gives {
                    // An optional same-type find/extract step found nothing in the sample. At run time it's
                    // skipped, not an error — show that and keep previewing the rest on the text as-is,
                    // instead of stopping and leaving the steps below spinning on "Trying it…" forever.
                    previews[i] = .file("Nothing to pull from the sample — skipped when there's none; the steps below still run.")
                    continue
                }
                previews[i] = .failed(ChainRunView.words(f))
                for j in (i + 1)..<steps.count { previews[j] = .file(steps[j].block.blurb) }   // never leave a perpetual spinner
                return
            }
        }
    }

    static let sampleText = "Team sync Friday at 3pm in Room 4. Please send the budget to Ana by Thursday. Call the vendor about the invoice. Review the launch checklist before noon. Priya Rao, Design Lead, priya@studio.example, 555 010 2030."

    private static func preview(_ p: ChainPayload) -> StepPreview {
        switch p {
        case .text(let t): return .text(t)
        case .image(let i): return .image(i)
        case .file(let d, let ext):
            if ChainPayload.isPhoto(ext), let i = UIImage(data: d) { return .image(i) }
            if ["csv", "vcf", "ics"].contains(ext), let t = String(data: d, encoding: .utf8) { return .text(t) }
            return .file("\(ext.uppercased()) file · \(SizeTarget.format(d.count))")
        case .video(let u): return .file("Video · " + (SizeTarget.fileSize(u).map(SizeTarget.format) ?? "ready"))
        }
    }

    private func defaults(_ b: Block) -> [String: String] {
        switch b { case .shrinkImage: return ["mb": "2"]; case .summarize: return ["sentences": "3"]; case .convertImage: return ["format": "JPG"]; case .passportPhoto: return ["country": "us"]
        case .watermark: return ["text": "For verification only"]; case .resizePhoto: return ["size": "413x531"]
        case .stamp: return ["marks": StampPlan.standard.text]; case .addToList: return ["list": RunningList.defaultName]
        case .chatLink: return ["cc": ChainText.callingCode(region: Locale.current.region?.identifier)]
        case .videoTrim: return ["side": "first", "secs": "30"]; case .videoRotate: return ["turn": "right"]; case .videoShrink: return ["mb": "25"]
        case .translate: return ["to": "en"]; case .rewrite: return ["style": "clear"]
        case .pdfShrink: return ["mb": "5"]; case .pdfLock: return ["password": ""]; case .pdfPages: return ["pages": ""]
        case .emojiFaces: return ["emoji": ChainText.faceEmojis[0]]; case .meme: return ["top": "", "bottom": ""]
        case .videoSpeed: return ["speed": "slow"]; case .videoLoop: return ["style": "boomerang"]
        case .artFilter: return ["style": "sketch"]; case .voiceChange: return ["voice": "chipmunk"]
        default: return [:] }
    }

    @ViewBuilder private func settings(_ i: Int) -> some View {
        switch chain.steps[i].block {
        case .shrinkImage:
            // A short list of limits, down to the 20-50 KB that government and bank upload forms ask for.
            let mb = Double(chain.steps[i].settings["mb"] ?? "2") ?? 2
            Picker(L("Size limit"), selection: Binding(get: { mb }, set: { chain.steps[i].settings["mb"] = String($0) })) {
                ForEach((ChainImage.limits.contains(mb) ? ChainImage.limits : (ChainImage.limits + [mb]).sorted()), id: \.self) { v in Text(L("Under ") + ChainImage.limitLabel(v)).tag(v) }
            }.pickerStyle(.menu).font(HandyFont.caption)
        case .chatLink:
            HStack {
                Text(L("Country code  +")).font(HandyFont.caption)
                TextField(L("1"), text: Binding(get: { chain.steps[i].settings["cc"] ?? "1" }, set: { chain.steps[i].settings["cc"] = $0.filter(\.isNumber) }))
                    .keyboardType(.numberPad).font(HandyFont.caption).frame(width: 60)
                    .padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8))
            }
            Text(L("Used when the number is written without one.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        case .addToList:
            TextField(L("Sheet name"), text: Binding(get: { chain.steps[i].settings["list"] ?? RunningList.defaultName }, set: { chain.steps[i].settings["list"] = $0 }))
                .font(HandyFont.caption).autocorrectionDisabled().padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8))
            Text(L("Write {month} to start a fresh sheet each month. The sample shown here is not saved.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        case .stamp:
            StampEditor(marks: Binding(get: { chain.steps[i].settings["marks"] ?? StampPlan.standard.text }, set: { chain.steps[i].settings["marks"] = $0 }), page: pageBefore(i))
        case .watermark:
            TextField(L("Words to write across it"), text: Binding(get: { chain.steps[i].settings["text"] ?? "" }, set: { chain.steps[i].settings["text"] = $0 }))
                .font(HandyFont.caption).padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8))
            Text(L("Today's date is added each time it runs.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        case .resizePhoto:
            Picker(L("Size"), selection: Binding(get: { chain.steps[i].settings["size"] ?? "413x531" }, set: { chain.steps[i].settings["size"] = $0 })) {
                ForEach(ChainImage.sizes, id: \.value) { s in Text(s.label).tag(s.value) }
            }.pickerStyle(.menu).font(HandyFont.caption)
        case .cleanText:
            Picker(L("Keep as"), selection: Binding(get: { chain.steps[i].settings["shape"] ?? "lines" }, set: { chain.steps[i].settings["shape"] = $0 })) {
                Text(L("Keep lines")).tag("lines"); Text(L("One paragraph")).tag("paragraph")
            }.pickerStyle(.segmented)
        case .summarize:
            let n = Int(chain.steps[i].settings["sentences"] ?? "3") ?? 3
            Stepper("\(n) sentences", value: Binding(get: { n }, set: { chain.steps[i].settings["sentences"] = String($0) }), in: 1...8).font(HandyFont.caption)
            Picker(L("As"), selection: Binding(get: { chain.steps[i].settings["format"] ?? "paragraph" }, set: { chain.steps[i].settings["format"] = $0 })) {
                Text(L("Paragraph")).tag("paragraph"); Text(L("Bullets")).tag("bullets")
            }.pickerStyle(.segmented)
        case .videoShrink:
            Picker(L("Size limit"), selection: Binding(get: { ChainText.videoLimit(chain.steps[i].settings["mb"]) }, set: { chain.steps[i].settings["mb"] = String($0) })) {
                ForEach(ChainText.videoLimits, id: \.self) { Text("\($0) MB").tag($0) }
            }.pickerStyle(.segmented)
        case .returnBy:
            Picker(L("Return window"), selection: Binding(get: { ChainText.returnDays(chain.steps[i].settings["days"]) }, set: { chain.steps[i].settings["days"] = String($0) })) {
                ForEach(ChainText.returnWindows, id: \.self) { Text("\($0) days").tag($0) }
            }.pickerStyle(.segmented)
        case .videoTrim:
            Picker(L("Which part"), selection: Binding(get: { chain.steps[i].settings["side"] == "last" ? "last" : "first" }, set: { chain.steps[i].settings["side"] = $0 })) {
                Text(L("The start")).tag("first"); Text(L("The end")).tag("last")
            }.pickerStyle(.segmented)
            let secs = Int(chain.steps[i].settings["secs"] ?? "") ?? 30
            Picker(L("How long"), selection: Binding(get: { secs }, set: { chain.steps[i].settings["secs"] = String($0) })) {
                ForEach(ChainText.trimLengths.contains(secs) ? ChainText.trimLengths : (ChainText.trimLengths + [secs]).sorted(), id: \.self) { Text("\($0) sec").tag($0) }
            }.pickerStyle(.segmented)
        case .videoRotate:
            Picker(L("Turn"), selection: Binding(get: { chain.steps[i].settings["turn"] ?? "right" }, set: { chain.steps[i].settings["turn"] = $0 })) {
                Text(L("Right")).tag("right"); Text(L("Left")).tag("left"); Text(L("Upside down")).tag("flip")
            }.pickerStyle(.segmented)
        case .translate:
            Picker(L("Into"), selection: Binding(get: { ChainText.languageCode(chain.steps[i].settings["to"]) }, set: { chain.steps[i].settings["to"] = $0 })) {
                ForEach(ChainText.languages, id: \.code) { Text($0.name).tag($0.code) }
            }.pickerStyle(.menu).font(HandyFont.caption)
            Text(L("The first time you use a language, the phone may ask to download it.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        case .speechText:
            let langs: [(code: String, name: String)] = [(code: "auto", name: "Auto (phone language)")] + ChainText.languages.map { (code: $0.code, name: $0.name) }
            Picker(L("Spoken language"), selection: Binding(get: { chain.steps[i].settings["lang"] ?? "auto" }, set: { chain.steps[i].settings["lang"] = $0 })) {
                ForEach(langs, id: \.code) { Text($0.name).tag($0.code) }
            }.pickerStyle(.menu).font(HandyFont.caption)
            Text(L("Set this to the language spoken in the recording. The first time, the phone may ask to download it.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        case .rewrite:
            Picker(L("Make it"), selection: Binding(get: { ChainText.rewriteStyle(chain.steps[i].settings["style"]) }, set: { chain.steps[i].settings["style"] = $0 })) {
                ForEach(ChainText.rewriteStyles, id: \.id) { Text($0.name).tag($0.id) }
            }.pickerStyle(.menu).font(HandyFont.caption)
        case .pdfShrink:
            let limit = ChainText.pdfLimit(chain.steps[i].settings["mb"])
            Picker(L("Size limit"), selection: Binding(get: { limit }, set: { chain.steps[i].settings["mb"] = String($0) })) {
                ForEach(ChainText.pdfLimits.contains(limit) ? ChainText.pdfLimits : (ChainText.pdfLimits + [limit]).sorted(), id: \.self) { Text("\($0) MB").tag($0) }
            }.pickerStyle(.segmented)
        case .pdfLock:
            SecureField(L("Password"), text: Binding(get: { chain.steps[i].settings["password"] ?? "" }, set: { chain.steps[i].settings["password"] = $0 }))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .font(HandyFont.caption).padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8))
            Text(L("Kept on this phone with the tool. It is left out when you copy the tool to share.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        case .pdfPages:
            TextField(L("Pages, e.g. 1-3, 5 (empty keeps all)"), text: Binding(get: { chain.steps[i].settings["pages"] ?? "" }, set: { chain.steps[i].settings["pages"] = $0 }))
                .keyboardType(.numbersAndPunctuation).autocorrectionDisabled()
                .font(HandyFont.caption).padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8))
        case .emojiFaces:
            Picker(L("Emoji"), selection: Binding(get: { ChainText.faceEmoji(chain.steps[i].settings["emoji"]) }, set: { chain.steps[i].settings["emoji"] = $0 })) {
                ForEach(ChainText.faceEmojis, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented)
        case .meme:
            TextField(L("Top line"), text: Binding(get: { chain.steps[i].settings["top"] ?? "" }, set: { chain.steps[i].settings["top"] = $0 }))
                .font(HandyFont.caption).padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8)).accessibilityIdentifier("meme-top")
            TextField(L("Bottom line"), text: Binding(get: { chain.steps[i].settings["bottom"] ?? "" }, set: { chain.steps[i].settings["bottom"] = $0 }))
                .font(HandyFont.caption).padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8)).accessibilityIdentifier("meme-bottom")
            Text(L("Leave them empty to type new words every time you run the tool.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        case .videoSpeed:
            Picker(L("Speed"), selection: Binding(get: { ChainText.speeds.first { $0.id == chain.steps[i].settings["speed"] }?.id ?? "slow" }, set: { chain.steps[i].settings["speed"] = $0 })) {
                ForEach(ChainText.speeds, id: \.id) { Text($0.name).tag($0.id) }
            }.pickerStyle(.segmented)
        case .artFilter:
            Picker(L("Style"), selection: Binding(get: { PixelArt.style(chain.steps[i].settings["style"]) }, set: { chain.steps[i].settings["style"] = $0 })) {
                ForEach(PixelArt.styles, id: \.id) { Text($0.name).tag($0.id) }
            }.pickerStyle(.menu).font(HandyFont.caption)
        case .voiceChange:
            Picker(L("Voice"), selection: Binding(get: { ChainText.voices.first { $0.id == chain.steps[i].settings["voice"] }?.id ?? "chipmunk" }, set: { chain.steps[i].settings["voice"] = $0 })) {
                ForEach(ChainText.voices, id: \.id) { Text(L($0.name)).tag($0.id) }
            }.pickerStyle(.segmented)
        case .videoLoop:
            Picker(L("Plays"), selection: Binding(get: { chain.steps[i].settings["style"] == "reverse" ? "reverse" : "boomerang" }, set: { chain.steps[i].settings["style"] = $0 })) {
                Text(L("Forwards and back")).tag("boomerang"); Text(L("Backwards")).tag("reverse")
            }.pickerStyle(.segmented)
        case .convertImage:
            Picker(L("Format"), selection: Binding(get: { chain.steps[i].settings["format"] ?? "JPG" }, set: { chain.steps[i].settings["format"] = $0 })) {
                ForEach(ImageStudio.Format.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
            }.pickerStyle(.segmented)
        case .photoPdf:
            Picker(L("Page size"), selection: Binding(get: { chain.steps[i].settings["pagesize"] ?? "auto" }, set: { chain.steps[i].settings["pagesize"] = $0 })) {
                Text(L("Fit the photo")).tag("auto"); Text(L("A4")).tag("a4"); Text(L("US Letter")).tag("letter")
            }.pickerStyle(.segmented)
            Toggle(L("Searchable text (find & copy)"), isOn: Binding(get: { chain.steps[i].settings["searchable"] != "false" }, set: { chain.steps[i].settings["searchable"] = $0 ? "true" : "false" })).font(HandyFont.caption)
        case .readAloud:
            Picker(L("Speed"), selection: Binding(get: { chain.steps[i].settings["speed"] ?? "normal" }, set: { chain.steps[i].settings["speed"] = $0 })) {
                Text(L("Slow")).tag("slow"); Text(L("Normal")).tag("normal"); Text(L("Fast")).tag("fast")
            }.pickerStyle(.segmented)
        case .makeQr:
            Picker(L("Sturdiness"), selection: Binding(get: { chain.steps[i].settings["sturdiness"] ?? "normal" }, set: { chain.steps[i].settings["sturdiness"] = $0 })) {
                Text(L("Normal")).tag("normal"); Text(L("High")).tag("high")
            }.pickerStyle(.segmented)
            Text(L("High survives scuffs and a logo in the middle.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        case .passportPhoto:
            Picker(L("Country"), selection: Binding(get: { chain.steps[i].settings["country"] ?? "us" }, set: { chain.steps[i].settings["country"] = $0 })) {
                ForEach(ImageStudio.passportSpecs) { Text($0.name).tag($0.id) }
            }.font(HandyFont.caption)
        default: EmptyView()
        }
    }
}

/// One photo's outcome in a batch run. Files and pictures are written to a temporary folder straight away,
/// so twenty full-size results never sit in memory together.
struct BatchItem: Identifiable {
    let id = UUID()
    let n: Int
    var url: URL?
    var text: String?
    var summary = ""
    var note: String?
    /// A gentle best-effort note (not an error): the flow still delivered this, but a later step couldn't
    /// finish, so this says what it would take to get the full result. The row still counts as done.
    var hint: String?

    static func make(n: Int, payload: ChainPayload, in dir: URL, named: String? = nil, tool: String = "", hint: String? = nil) -> BatchItem {
        var b = BatchItem(n: n)
        b.hint = hint
        func write(_ d: Data, _ ext: String) {
            let u = dir.appendingPathComponent(ChainName.file(pattern: named, tool: tool, index: n, ext: ext))
            if (try? d.write(to: u)) != nil { b.url = u; b.summary = "\(SizeTarget.format(d.count)) · \(ext.uppercased())" } else { b.note = "Couldn't save this result." }
        }
        switch payload {
        case .text(let t): b.text = t; b.summary = "\(t.count) characters"
        case .image(let i): if let d = i.jpegData(compressionQuality: 0.92) { write(d, "jpg") } else { b.note = "Couldn't save this result." }
        case .file(let d, let ext): write(d, ext)
        case .video(let u): b.url = u; b.summary = (SizeTarget.fileSize(u).map(SizeTarget.format) ?? "") + " · VIDEO"
        }
        return b
    }
}

/// Give it a photo or some text, see the result, copy or share it.
struct ChainRunView: View {   // internal (not private) so the test target can reach ChainRunView.words(_:)
    let chain: Chain
    /// Handed over already ("Start with what you have"): the tool runs on it straight away.
    var initial: ChainPayload? = nil
    @State private var started = false
    @State private var picks: [PhotosPickerItem] = []
    @State private var batch: [BatchItem] = []
    @State private var progress = ""
    @State private var progressValue: Double = 0   // 0 = indeterminate
    @ObservedObject private var runProgress = RunProgress.shared   // live fraction from deep engine work (transcription)
    @State private var outbox: Outbox?
    @State private var sending = false
    @State private var scanning = false
    @State private var signing = false
    @State private var hasSignature = DocEngine.savedSignature != nil
    @State private var myName = StampBook.name
    /// Decided once when the screen opens, so the field doesn't vanish while the name is being typed.
    @State private var askName = StampBook.name.trimmingCharacters(in: .whitespaces).isEmpty
    @State private var text = ""
    @StateObject private var speech = SpeechStream()
    @State private var pickingContact = false
    @State private var pickingPDF = false
    @State private var videoPick: PhotosPickerItem?
    @State private var livePick: PhotosPickerItem?
    /// A meme's words can be typed fresh for each run.
    @State private var memeTop = ""
    @State private var memeBottom = ""
    @State private var memeLoaded = false
    /// The photos picked for a meme are held so the caption can be typed in any order and re-applied
    /// without picking again — pick first or type first, then tap Make meme as many times as you like.
    @State private var memePhotos: [UIImage] = []
    @StateObject private var here = WhereAmI()
    @StateObject private var recorder = QuickRecorder()
    /// What each result of a many-at-once run is called in the list: a photo, or a file.
    @State private var noun = "Photo"
    @State private var busy = false
    @State private var result: ChainPayload?
    @State private var message: String?
    @State private var report: ChainRunner.RunReport?   // the per-step "what went through" story, for multi-step flows
    @ObservedObject private var store = StoreManager.shared
    @State private var showPro = false
    @Environment(\.dismiss) private var dismiss

    private var start: ChainKind { chain.steps.first?.block.takes ?? .image }
    private var hasMeme: Bool { chain.steps.contains { $0.block == .meme } }
    /// A QR-making result gets the long-press "what's inside this code" preview; ordinary photos don't.
    private var isQRResult: Bool { chain.steps.contains { [.makeQr, .contactQr, .wifiQr].contains($0.block) } }
    /// A free user can't run a tool that uses a Pro step; they see the lock card instead of the inputs.
    private var locked: Bool { !store.isPremium && chain.needsPro }

    /// The tool as it runs this time: a meme step takes the words typed on this screen.
    private var runChain: Chain {
        guard hasMeme else { return chain }
        var c = chain
        for i in c.steps.indices where c.steps[i].block == .meme {
            c.steps[i].settings["top"] = memeTop; c.steps[i].settings["bottom"] = memeBottom
        }
        return c
    }

    /// Draw the meme onto the photos held from the last pick, using whatever caption is typed right now.
    /// Lets the order be either way round and lets the caption be changed and re-applied with one tap.
    private func makeMeme() {
        guard !memePhotos.isEmpty else { return }
        if memePhotos.count == 1 { go(.image(memePhotos[0])) }
        else { let imgs = memePhotos; runBatch(count: imgs.count) { i in imgs[i] } }
    }

    var body: some View {
        if locked { lockCard } else { runBody }
    }

    /// Shown when a free user opens a tool that uses a Pro step: what it needs, and a one-tap path to Pro.
    private var lockCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                Text(chain.name).font(HandyFont.title)
                VStack(spacing: HandySpacing.s12) {
                    ZStack { Circle().fill(HandyColor.accentSoft).frame(width: 72, height: 72); Image(systemName: "lock.fill").font(.system(size: 30)).foregroundStyle(HandyColor.accent) }
                    Text(L("A Pro tool")).font(.system(size: 22, weight: .bold))
                    Text("This tool uses \(chain.proSteps.count == 1 ? "a Pro step" : "Pro steps") (\(chain.proSteps.map(\.title).joined(separator: ", "))). Go Pro to run it — plus every Pro step, all \(TOOLS.count) tools, and no daily limits.")
                        .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                    Button { showPro = true } label: { Label(store.showsFreeTrial ? "Start \(store.trialLength) free trial" : "Go Pro — \(store.yearlyPrice)/year", systemImage: "crown.fill").frame(maxWidth: .infinity) }.primaryButton()
                }.frame(maxWidth: .infinity).padding(.top, HandySpacing.s24)
            }.padding(HandySpacing.gutter)
        }
        .background(Ground())
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { dismiss() } } }
        .sheet(isPresented: $showPro) { PaywallView().environmentObject(StoreManager.shared) }
    }

    private var runBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                Text(chain.name).font(HandyFont.title)
                // Tell the person what this flow does and what good input looks like, the moment it opens —
                // instead of a bare title over three file buttons with no clue what they're for.
                VStack(alignment: .leading, spacing: HandySpacing.s4) {
                    Text(chain.about).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let w = chain.wants {
                        Label("Works best with \(w).", systemImage: "lightbulb")
                            .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                stampSetup
                if hasMeme {
                    TextField(L("Top line"), text: $memeTop).padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier("run-meme-top")
                    TextField(L("Bottom line"), text: $memeBottom).padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier("run-meme-bottom")
                    if !memePhotos.isEmpty {
                        // The photos are already picked and held — one tap draws the current caption onto them,
                        // and tapping again after editing the words re-draws, with no need to pick again.
                        Button { makeMeme() } label: { Label(L("Make meme"), systemImage: "wand.and.stars").frame(maxWidth: .infinity) }
                            .primaryButton().disabled(busy || (memeTop.isEmpty && memeBottom.isEmpty)).accessibilityIdentifier("run-meme-make")
                        Text("\(memePhotos.count) photo\(memePhotos.count == 1 ? "" : "s") ready. Change the words above and tap Make meme again any time.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                }
                if let why = chain.unavailable {
                    Label(why, systemImage: "exclamationmark.triangle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.amber).cardStyle(padding: HandySpacing.s12)
                }
                if start == .audio {
                    audioInputs
                } else if start == .pdf {
                    pdfInputs
                } else if start == .video {
                    PhotosPicker(selection: $videoPick, matching: .videos) { Label(L("Choose a video"), systemImage: "film").frame(maxWidth: .infinity) }
                        .primaryButton().accessibilityIdentifier("run-video")
                    PhotosPicker(selection: $livePick, matching: .livePhotos) { Label(L("Choose a Live Photo"), systemImage: "livephoto").frame(maxWidth: .infinity) }
                        .secondaryButton().accessibilityIdentifier("run-live-photo")
                    Text(L("Long videos take a little while. Keep Tenzy open until it finishes. A Live Photo is used as its short video.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                } else if start != .text {
                    PhotosPicker(selection: $picks, maxSelectionCount: 20, matching: .images) { Label(L("Choose photos"), systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }.primaryButton()
                    if VNDocumentCameraViewController.isSupported {
                        Button { scanning = true } label: { Label(L("Scan a document"), systemImage: "doc.viewfinder").frame(maxWidth: .infinity) }
                            .secondaryButton().accessibilityIdentifier("run-scan")
                    }
                    Button { pickingPDF = true } label: { Label(L("Choose a PDF"), systemImage: "doc.richtext").frame(maxWidth: .infinity) }
                        .secondaryButton().accessibilityIdentifier("run-pdf")
                    Text(chain.combine == true ? "Pick or scan as many pages as you need. They all go into one PDF." : chain.collage == true ? "Pick up to 20 photos. They are laid out as one picture." : chain.gif == true ? "Pick up to 20 photos. They play one after another as a GIF." : chain.flipbook == true ? "Pick 2–20 photos. They flip like the pages of a book." : chain.versus == true ? "Pick two photos: the before, then the after." : "Pick one, or up to 20 at once. Each one gets the same steps.")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                } else {
                    // Ways to get the words in without typing them.
                    // System paste control: one tap, no recurring "Allow Paste" prompt. The old custom
                    // button read UIPasteboard directly, so iOS asked for permission on every single paste.
                    PasteButton(supportedContentTypes: [.plainText, .image]) { providers in pasteInto(providers) }
                        .labelStyle(.titleAndIcon)
                        .buttonBorderShape(.roundedRectangle(radius: 12))
                        .tint(HandyColor.accentSoft)
                        .foregroundStyle(HandyColor.accent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("in-paste")
                    HStack(spacing: HandySpacing.s8) {
                        fill(speech.running ? "Stop" : "Speak", speech.running ? "stop.circle.fill" : "mic", id: "in-speak") { toggleSpeech() }
                        fill("Contact", "person.crop.circle", id: "in-contact") { pickingContact = true }
                        fill("PDF", "doc.richtext", id: "in-pdf") { pickingPDF = true }
                        fill(here.looking ? "Finding…" : "Location", "location", id: "in-location") { addLocation() }
                    }
                    if speech.running { Text(speech.live.isEmpty ? "Listening… tap Stop when you're done." : speech.live).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
                    if let e = speech.errorText { Text(e).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
                    // Capped so a long paste or a whole file scrolls *inside* this box instead of
                    // stretching down the page — the Run button and everything after it stay reachable.
                    TextEditor(text: $text).frame(minHeight: 140, maxHeight: 260).cardStyle(padding: HandySpacing.s8)
                    if text.count > 400 {
                        Text("\(text.count) characters — scroll inside the box to read it all.").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    }
                    Button(L("Run")) { go(.text(text)) }.primaryButton().disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if busy { ToolProgressBar(value: runProgress.fraction ?? (progressValue > 0 ? progressValue : nil), label: progress.isEmpty ? "Working…" : progress) }
                if let report { stepLog(report) }
                if let message { Text(message).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                if let result { output(result) }
                if !batch.isEmpty { batchView }
                sendOn
            }.padding(HandySpacing.gutter)
        }
        .background(Ground())
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { dismiss() } } }
        .sheet(isPresented: $sending) {
            if let f = chain.finish, let box = outbox { SendSheet(finish: f, subject: chain.name, box: box).ignoresSafeArea() }
        }
        .onChange(of: picks) { _, items in
            guard !items.isEmpty else { return }
            picks = []
            // A meme keeps its photos so the caption can be typed before or after picking, then applied
            // (and re-applied) with the Make meme button — picking no longer runs it with empty words.
            if hasMeme {
                busy = true; result = nil; message = nil; batch = []; progress = "Getting your photos ready…"; progressValue = 0
                Task {
                    var imgs: [UIImage] = []
                    for it in items {
                        if let img = await loadWithinTimeout(120, { (try? await it.loadTransferable(type: Data.self)).flatMap(UIImage.init) }) { imgs.append(img) }
                    }
                    await MainActor.run {
                        busy = false; progress = ""
                        memePhotos = imgs
                        if imgs.isEmpty { message = "Those photos didn't load. If they're large iCloud photos, open them once in Photos, then pick again." }
                        else if memeTop.isEmpty, memeBottom.isEmpty { message = "Added \(imgs.count) photo\(imgs.count == 1 ? "" : "s"). Now type a top or bottom line above, then tap Make meme." }
                        else { makeMeme() }
                    }
                }
                return
            }
            if items.count == 1, chain.gif != true, chain.versus != true, chain.flipbook != true, let item = items.first {
                busy = true; result = nil; message = nil; progress = "Getting the photo ready…"; progressValue = 0
                Task {
                    let img = await loadWithinTimeout(120) { (try? await item.loadTransferable(type: Data.self)).flatMap(UIImage.init) }
                    await MainActor.run {
                        if let img { go(.image(img)) }
                        else { busy = false; progress = ""; message = "That photo didn't load. If it's a large iCloud photo, open it once in Photos to download it, then pick it again." }
                    }
                }
            } else { runBatch(count: items.count) { i in (try? await items[i].loadTransferable(type: Data.self)).flatMap(UIImage.init) } }
        }
        .sheet(isPresented: $signing) { SignaturePadSheet { _ in hasSignature = true } }
        .sheet(isPresented: $pickingContact) {
            ContactPickerSheet { picked in
                pickingContact = false
                if let picked { text = InputText.joined(text, picked) }
            }.ignoresSafeArea()
        }
        .fileImporter(isPresented: $pickingPDF, allowedContentTypes: start == .audio ? audioImportTypes : [.pdf], allowsMultipleSelection: start == .pdf) { r in
            guard case .success(let urls) = r, let url = urls.first else { return }
            if start == .audio {
                if let d = Self.read(url) { go(.file(d, ext: url.pathExtension.isEmpty ? "m4a" : url.pathExtension.lowercased())) }
                else { message = "That recording couldn't be opened. Try another." }
            } else if start == .pdf {
                // One PDF runs straight away; several each get the tool's steps (and are joined if the tool says so).
                if urls.count == 1 {
                    if let d = Self.read(url) { go(.file(d, ext: "pdf")) } else { message = "That PDF couldn't be opened. Try another." }
                } else {
                    runMany(count: urls.count, noun: "File") { i in Self.read(urls[i]).map { ChainPayload.file($0, ext: "pdf") } }
                }
            } else if start == .text {
                // The words in the PDF become the text the tool works on.
                if let words = PDFInput.text(from: url), !words.isEmpty { text = InputText.joined(text, words); message = nil }
                else { message = "That PDF has no words Tenzy can read (it may be a scan). Use a photo tool with Read text, and choose the PDF there." }
            } else {
                // Each page becomes a picture and gets the tool's steps, like scanned pages.
                let pages = PDFInput.pages(from: url)
                if pages.isEmpty { message = "That PDF couldn't be opened. Try another." }
                else if pages.count == 1 { go(.image(pages[0])) }
                else { runBatch(count: pages.count) { i in pages[i] } }
            }
        }
        .onDisappear { if speech.running { speech.stop() }; if recorder.running { _ = recorder.stop() } }
        .onAppear {
            if !memeLoaded, let words = chain.steps.first(where: { $0.block == .meme })?.settings {
                memeLoaded = true
                memeTop = words["top"] ?? ""; memeBottom = words["bottom"] ?? ""
            }
            // Fresh launch = clean slate. If the screen re-appears with no input queued and nothing
            // running, clear any previous run's result so a tool never opens showing an old image. (A
            // child picker/sheet doesn't fire onAppear, so a result you're actively viewing is safe.)
            if initial == nil, !started, !busy {
                result = nil; batch = []; outbox = nil; report = nil; message = nil; picks = []; memePhotos = []
            }
            guard let initial, !started else { return }
            started = true
            if case .text(let t) = initial { text = t }
            go(initial)
        }
        .onChange(of: videoPick) { _, item in
            guard let item else { return }
            videoPick = nil
            busy = true; result = nil; message = nil; batch = []; outbox = nil; progress = "Getting the video ready…"; progressValue = 0
            Task {
                let movie = await loadWithinTimeout(180) { try? await item.loadTransferable(type: MovieImport.self) }
                await MainActor.run {
                    if let movie { go(.video(movie.url)) }
                    else { busy = false; progress = ""; message = "That video didn't load. If it's a large iCloud video, open it once in Photos to download it to this phone, then pick it again." }
                }
            }
        }
        .onChange(of: livePick) { _, item in
            guard let item else { return }
            livePick = nil
            busy = true; result = nil; message = nil; batch = []; outbox = nil; progress = "Getting the Live Photo ready…"; progressValue = 0
            Task {
                let movie = await loadWithinTimeout(180) { await LivePhotoVideo.movie(from: item) }
                await MainActor.run {
                    if let movie { go(.video(movie)) } else { busy = false; progress = ""; message = "That Live Photo didn't load. If it's a large iCloud item, open it once in Photos to download it, then try again — or choose a video." }
                }
            }
        }
        .fullScreenCover(isPresented: $scanning) {
            // Apple's document camera: finds the page edges, straightens it, and takes several pages in one go.
            DocCameraSheet { pages in
                scanning = false
                if pages.count == 1 { go(.image(pages[0])) } else if pages.count > 1 { runBatch(count: pages.count) { i in pages[i] } }
            }.ignoresSafeArea()
        }
    }

    /// A tool that starts with a recording: make one here, or pick one.
    @ViewBuilder private var audioInputs: some View {
            Button { toggleRecording() } label: { Label(recorder.running ? "Stop and run" : "Record", systemImage: recorder.running ? "stop.circle.fill" : "mic").frame(maxWidth: .infinity) }
                .primaryButton().accessibilityIdentifier("run-record")
            Button { pickingPDF = true } label: { Label(L("Choose a recording"), systemImage: "waveform").frame(maxWidth: .infinity) }
                .secondaryButton().disabled(recorder.running).accessibilityIdentifier("run-audio")
            Text(recorder.running ? "Recording… tap Stop when you're done." : "Record now, or pick a voice memo or any sound file. It never leaves this phone.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
    }

    /// A tool that starts with a PDF.
    @ViewBuilder private var pdfInputs: some View {
            Button { pickingPDF = true } label: { Label(chain.combine == true ? "Choose PDFs" : "Choose a PDF", systemImage: "doc.richtext").frame(maxWidth: .infinity) }
                .primaryButton().accessibilityIdentifier("run-pdf-file")
            Text(chain.combine == true ? "Pick them in the order you want. They are joined into one PDF." : "Pick one, or several at once. Each one gets the same steps.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
    }

    private func fill(_ title: String, _ icon: String, id: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            VStack(spacing: 4) { Image(systemName: icon).font(.system(size: 18, weight: .semibold)); Text(title).font(HandyFont.micro).lineLimit(1).minimumScaleFactor(0.7) }
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }.buttonStyle(.plain).foregroundStyle(HandyColor.accent).accessibilityIdentifier(id)
    }

    /// Handle what the system paste control handed over: text first (joined in), otherwise an image, whose
    /// words are read out with OCR so a pasted screenshot isn't a dead end. No clipboard prompt is involved.
    private func pasteInto(_ providers: [NSItemProvider]) {
        if let p = providers.first(where: { $0.canLoadObject(ofClass: String.self) }) {
            _ = p.loadObject(ofClass: String.self) { obj, _ in
                guard let s = obj as? String, !s.isEmpty else { return }
                DispatchQueue.main.async { text = InputText.joined(text, s) }
            }
            return
        }
        if let p = providers.first(where: { $0.canLoadObject(ofClass: UIImage.self) }) {
            DispatchQueue.main.async { message = "Reading the words from your image…" }
            _ = p.loadObject(ofClass: UIImage.self) { obj, _ in
                guard let img = obj as? UIImage else {
                    DispatchQueue.main.async { message = "Couldn't read that paste. Copy some text or a screenshot and try again." }
                    return
                }
                let words = DocEngine.text(DocEngine.recognize(img.normalizedUp()))
                DispatchQueue.main.async {
                    if words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        message = "That image has no readable text. Copy some text, or use a photo tool to work on the picture itself."
                    } else {
                        text = InputText.joined(text, words); message = nil
                    }
                }
            }
            return
        }
        DispatchQueue.main.async { message = "Nothing's copied yet. Copy some text or a screenshot first, then tap Paste." }
    }

    /// A picked file's bytes. Files chosen from the Files app need their access opened first.
    private static func read(_ url: URL) -> Data? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try? Data(contentsOf: url)
    }

    /// Record: starts a recording, and on Stop runs the tool on it.
    private func toggleRecording() {
        if recorder.running {
            if let url = recorder.stop(), let d = try? Data(contentsOf: url), !d.isEmpty { go(.file(d, ext: "m4a")) }
            else { message = "Nothing was recorded. Try again." }
        } else {
            message = nil; result = nil
            recorder.start { message = "Tenzy needs the microphone to record. Allow it in Settings, or choose a recording instead." }
        }
    }

    /// Location: adds where the phone is (an address and a map link) to the text box.
    private func addLocation() {
        guard !here.looking else { return }
        message = nil
        here.find { found in
            if let found { text = InputText.joined(text, found) }
            else { message = "Tenzy couldn't find where you are. Check that Location is allowed for Tenzy in Settings, or type the place in." }
        }
    }

    /// Speak: starts listening, and on Stop adds what was said to the text box.
    private func toggleSpeech() {
        if speech.running {
            speech.stop()
            text = InputText.joined(text, speech.committed.joined(separator: " "))
            speech.clear()
        } else {
            message = nil; speech.clear(); speech.start()
        }
    }

    /// One result per photo. A photo that can't be processed never stops the others; it just gets its own note.
    private func runBatch(count: Int, load: @escaping (Int) async -> UIImage?) {
        runMany(count: count, noun: "Photo") { i in await load(i).map { ChainPayload.image($0) } }
    }

    /// The same for anything a tool can start with: photos, pages, or several PDFs.
    private func runMany(count: Int, noun name: String, load: @escaping (Int) async -> ChainPayload?) {
        busy = true; result = nil; message = nil; batch = []; outbox = nil; noun = name; progressValue = 0
        let combine = chain.combine == true
        let collage = chain.collage == true
        let gif = chain.gif == true
        let versus = chain.versus == true
        let flipbook = chain.flipbook == true
        let tool = runChain
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tenzy-batch-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        Task {
            var out: [BatchItem] = []
            var kept: [ChainPayload] = []      // only held when everything is going into one PDF
            for i in 0..<count {
                await MainActor.run { progress = "Working… \(i + 1) of \(count)"; progressValue = Double(i) / Double(count) }
                guard let item = await load(i) else {
                    out.append(BatchItem(n: i + 1, note: "Couldn't open this \(name.lowercased()).")); continue
                }
                switch await ChainRunner.runKeepingBest(tool, input: item) {
                case .done(let p):
                    if combine || collage || gif || versus || flipbook { kept.append(p) }
                    out.append(BatchItem.make(n: i + 1, payload: p, in: dir, named: chain.fileName, tool: chain.name))
                case .partial(let p, let f):
                    // Best-effort: deliver how far it got (e.g. the text it read) and say what the last
                    // step needs, instead of throwing it all away with a dead-end error.
                    if combine || collage || gif || versus || flipbook { kept.append(p) }
                    out.append(BatchItem.make(n: i + 1, payload: p, in: dir, named: chain.fileName, tool: chain.name, hint: ChainRunView.bestEffortNote(f)))
                case .failed(let f): out.append(BatchItem(n: i + 1, note: ChainRunView.words(f)))
                }
            }
            // One PDF for everything, when the tool asks for it and the results can be joined.
            if versus, kept.count < 2 {
                await MainActor.run { busy = false; progress = ""; message = "Before and after needs two photos: pick the before and the after together." }
                return
            }
            // Before & after lands as a share-ready swipe-reveal video — the way people actually post a
            // transformation — with the static side-by-side as a fallback if the phone can't encode it.
            if versus {
                let imgs: [UIImage] = kept.compactMap { p in
                    if case .image(let i) = p { return i }
                    if case .file(let d, let e) = p, ChainPayload.isPhoto(e) { return UIImage(data: d) }
                    return nil
                }
                if imgs.count >= 2, let before = imgs.first, let after = imgs.last,
                   let data = await ChainMotion.revealVideo(before: before, after: after) {
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent(ChainName.file(pattern: chain.fileName, tool: chain.name, ext: "mp4"))
                    if (try? data.write(to: url)) != nil {
                        await MainActor.run {
                            busy = false; progress = ""; result = .video(url)
                            finished(Outbox.make(.video(url), named: chain.fileName, tool: chain.name))
                        }
                        return
                    }
                }
                if let one = ChainCombine.beforeAfter(kept) {
                    await MainActor.run { busy = false; progress = ""; result = one; finished(Outbox.make(one, named: chain.fileName, tool: chain.name)) }
                    return
                }
                await MainActor.run { busy = false; progress = ""; message = "Couldn't build the before and after from those two photos." }
                return
            }
            // A flipbook plays the photos as a page-turning riffle video.
            if flipbook {
                let imgs: [UIImage] = kept.compactMap { p in
                    if case .image(let i) = p { return i }
                    if case .file(let d, let e) = p, ChainPayload.isPhoto(e) { return UIImage(data: d) }
                    return nil
                }
                if imgs.count >= 2, let data = await ChainMotion.flipbookVideo(images: imgs) {
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent(ChainName.file(pattern: chain.fileName, tool: chain.name, ext: "mp4"))
                    if (try? data.write(to: url)) != nil {
                        await MainActor.run {
                            busy = false; progress = ""; result = .video(url)
                            finished(Outbox.make(.video(url), named: chain.fileName, tool: chain.name))
                        }
                        return
                    }
                }
                await MainActor.run { busy = false; progress = ""; message = "A flipbook needs at least two photos." }
                return
            }
            let pdfSize: DocEngine.PageSize = { switch chain.steps.first(where: { $0.block == .photoPdf })?.settings["pagesize"] { case "a4": return .a4; case "letter": return .letter; default: return .auto } }()
            if let one = gif ? ChainCombine.oneGif(kept) : collage ? ChainCombine.onePicture(kept) : combine ? ChainCombine.onePDF(kept, onePage: chain.onePage == true, pageSize: pdfSize) : nil {
                let skipped = out.filter { $0.note != nil }.count
                await MainActor.run {
                    busy = false; progress = ""; result = one
                    if skipped > 0 { message = "\(skipped) of \(count) couldn't be used and were left out." }
                    finished(Outbox.make(one, named: chain.fileName, tool: chain.name))
                }
                return
            }
            await MainActor.run {
                batch = out; busy = false; progress = ""
                let ok = out.filter { $0.note == nil }
                finished(ok.isEmpty ? nil : Outbox(text: ok.compactMap(\.text).isEmpty ? nil : ok.compactMap(\.text).joined(separator: "\n\n"), files: ok.compactMap(\.url)))
            }
        }
    }

    /// A tool that signs needs your signature (and one that stamps your name needs the name). Ask for them right
    /// here, once, instead of failing after the scan.
    @ViewBuilder private var stampSetup: some View {
        let plans = chain.steps.filter { $0.block == .stamp }.map { StampPlan($0.settings["marks"] ?? StampPlan.standard.text) }
        if plans.contains(where: { $0.has(.signature) }), !hasSignature {
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Text(L("This tool signs for you. Draw your signature once; it stays on this phone.")).font(HandyFont.caption)
                Button { signing = true } label: { Label(L("Draw my signature"), systemImage: "signature").frame(maxWidth: .infinity) }
                    .secondaryButton().accessibilityIdentifier("run-draw-signature")
            }.cardStyle(padding: HandySpacing.s12)
        }
        if plans.contains(where: { $0.has(.name) }), askName {
            TextField(L("Your name as it should appear"), text: $myName)
                .padding(HandySpacing.s12).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 10))
                .onChange(of: myName) { _, v in StampBook.name = v }
        }
    }

    /// The tool's own ending: "Email it to..." or "Message it to...". If this phone can't do that, say so and leave
    /// Save or share above as the way out, never a dead button.
    @ViewBuilder private var sendOn: some View {
        if let f = chain.finish, f.kind == .open, outbox != nil {
            Button { openLink() } label: { Label(f.label, systemImage: "arrow.up.forward.app").frame(maxWidth: .infinity) }
                .primaryButton().accessibilityIdentifier("open-link")
        } else if let f = chain.finish, f.kind != .share, outbox != nil {
            if SendSheet.canSend(f.kind) {
                Button { sending = true } label: { Label(f.label, systemImage: f.kind == .mail ? "envelope" : "message").frame(maxWidth: .infinity) }
                    .primaryButton().accessibilityIdentifier("send-on")
            } else {
                Text(f.kind == .mail ? "This phone has no Mail account set up, so use Save or share." : "This device can't send messages, so use Save or share.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        }
    }

    /// "Open it": follows the link the tool made (a WhatsApp chat, a cleaned link). If the result holds no link, say
    /// so; the result is still on screen to copy.
    private func openLink(_ box: Outbox? = nil) {
        let text = (box ?? outbox)?.text ?? ""
        let found = TextTidy.details(text).links.first ?? text.trimmingCharacters(in: .whitespacesAndNewlines)
        let full = found.lowercased().hasPrefix("http") ? found : "https://" + found
        guard !found.isEmpty, !found.contains(" "), let url = URL(string: full) else { message = "There was no link to open. The result is shown below to copy."; return }
        UIApplication.shared.open(url)
    }

    /// Called when a run finishes: get the result ready to send and, if the tool ends in an email or a message, open it.
    private func finished(_ box: Outbox?) {
        outbox = box
        // Kept so the result is still there after this screen is closed. Copied off the main thread: a video can be large.
        if let box { let name = chain.name; Task.detached(priority: .utility) { RunHistory.add(box, tool: name) } }
        if let f = chain.finish, f.kind == .open, box != nil { openLink(box) }
        else if let f = chain.finish, f.kind == .mail || f.kind == .message, box != nil, SendSheet.canSend(f.kind) { sending = true }
    }

    @ViewBuilder private var batchView: some View {
        let ok = batch.filter { $0.note == nil }
        let urls = ok.compactMap(\.url)
        let texts = ok.compactMap { b in b.text.map { "\(noun) \(b.n)\n\($0)" } }
        Text("\(ok.count) of \(batch.count) done").font(HandyFont.cardTitle)
        // Thumbnails of every result, so a batch is checked at a glance before saving or sharing.
        OutputPreviewStrip(urls: urls)
        ForEach(batch) { b in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: b.note == nil ? "checkmark.circle.fill" : "exclamationmark.circle").foregroundStyle(b.note == nil ? Color.green : HandyColor.textSecondary)
                    Text("\(noun) \(b.n)").font(HandyFont.bodyStrong)
                    Spacer()
                    // For a text result, the character count isn't the answer — show it below instead.
                    Text(b.note ?? (b.text == nil ? b.summary : "")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.trailing)
                }
                // The actual text each item produced (what "What is this?" found, the words read, …), so a
                // batch shows its answers in-app instead of a row of "49 characters".
                if let t = b.text, !t.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(t).font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                // Best-effort: this one still delivered (it's in the count and the copy/share), but a later
                // step couldn't finish — say what it would take, without marking the row as failed.
                if let h = b.hint { Text(h).font(HandyFont.micro).foregroundStyle(HandyColor.amber).fixedSize(horizontal: false, vertical: true) }
            }.cardStyle(padding: HandySpacing.s12)
        }
        if !urls.isEmpty {
            ShareLink(items: urls) { Label("Save or share all (\(urls.count))", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        }
        if !texts.isEmpty {
            CopyButton(text: texts.joined(separator: "\n\n"), title: "Copy all text")
        }
    }

    @ViewBuilder private func output(_ r: ChainPayload) -> some View {
        switch r {
        case .text(let t):
            if chain.steps.last?.block == .actionItems {
                RemindersResult(planText: t)
            } else if chain.steps.last?.block == .identify {
                IdentifyResult(text: t)
            } else if chain.steps.last?.block == .pullDetails {
                PullDetailsResult(text: t)
            } else {
            // A planned task list carries tappable Maps links as markdown; render those so the links work.
            // Everything else stays plain monospaced so no stray character gets misread as formatting.
            // Capped in a scroll box so a long result scrolls inside it — Copy and the next options stay
            // in reach instead of being pushed a whole screen down.
            ScrollView {
                if (t.contains("maps.apple.com") || t.contains("google.com/maps") || t.contains("mailto:") || t.contains("tel:")),
                   let md = try? AttributedString(markdown: t, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(md).font(.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(t).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxHeight: 300)
            .scrollBounceBehavior(.basedOnSize)
            .cardStyle(padding: HandySpacing.s12)
            CopyButton(text: t)
            }
        case .image(let i):
            Image(uiImage: i).resizable().scaledToFit().frame(maxHeight: 320)
                .modifier(QRPeekIfCode(enabled: isQRResult, image: i))
            if isQRResult {
                Text(L("Press and hold the code to see what's inside it, without opening it."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            ShareLink(item: Image(uiImage: i), preview: SharePreview("Result")) { Label(L("Save or share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        case .file(let d, let ext):
            let lext = ext.lowercased()
            if lext == "ics", let icsText = String(data: d, encoding: .utf8) {
                CalendarEventResult(ics: icsText, shareURL: tempURL(d, ext))
            } else if lext == "vcf" {
                ContactResult(vcf: d, shareURL: tempURL(d, ext))
            } else {
            // Always show the result before Save or share — a photo, or a PDF's first page — so the person
            // can check it (faces covered, the right pages) and never shares something they haven't seen.
            if lext == "gif" {
                AnimatedGIFView(data: d).frame(maxWidth: .infinity).frame(maxHeight: 360).cardStyle(padding: HandySpacing.s8)
            } else if ChainPayload.isPhoto(ext), let img = UIImage(data: d) {
                Image(uiImage: img).resizable().scaledToFit().frame(maxWidth: .infinity).frame(maxHeight: 360)
                    .cardStyle(padding: HandySpacing.s8)
            } else if ext.lowercased() == "pdf", let page = PDFDocument(data: d)?.page(at: 0) {
                Image(uiImage: page.thumbnail(of: CGSize(width: 360, height: 480), for: .cropBox))
                    .resizable().scaledToFit().frame(maxWidth: .infinity).frame(maxHeight: 360)
                    .cardStyle(padding: HandySpacing.s8)
            } else if ["csv", "vcf", "ics", "txt", "json", "md", "rtf", "html", "xml"].contains(ext.lowercased()),
                      let s = String(data: d, encoding: .utf8), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // A CSV / contact / calendar / text file is its text — show it so an expense sheet, a vCard
                // or an .ics is read in the app before saving, not handed over as an opaque "77 bytes".
                ScrollView { Text(s).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 260).cardStyle(padding: HandySpacing.s12)
            } else if ChainPayload.isAudio(ext), let au = tempURL(d, ext) {
                AudioResultPreview(url: au)   // hear an audio result before saving
            }
            if let u = tempURL(d, ext) {
                Text("\(SizeTarget.format(d.count)) · \(ext.uppercased())").font(HandyFont.caption)
                ShareLink(item: u) { Label(L("Save or share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
            }
            }
        case .video(let u):
            Label(L("Your video is ready") + (SizeTarget.fileSize(u).map { " · " + SizeTarget.format($0) } ?? ""), systemImage: "film").font(HandyFont.bodyStrong)
            VideoResultPreview(url: u)   // watch it before saving, like photos and PDFs
            ShareLink(item: u) { Label(L("Save or share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        }
    }

    private func tempURL(_ d: Data, _ ext: String) -> URL? {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(ChainName.file(pattern: chain.fileName, tool: chain.name, ext: ext))
        return (try? d.write(to: u)) != nil ? u : nil
    }

    private func go(_ input: ChainPayload) {
        busy = true; result = nil; message = nil; report = nil; batch = []; outbox = nil; progressValue = 0
        // A spoken recording is transcribed on the phone — that takes roughly as long as the clip, so
        // say what's happening rather than showing a bare spinner on a long meeting recording.
        if case let .file(_, ext) = input, ["m4a", "mp3", "wav", "aiff", "aifc", "caf", "aac", "m4b", "flac", "ogg"].contains(ext.lowercased()) {
            progress = "Transcribing on your phone… about as long as the recording. It never leaves your phone."
        } else { progress = "" }
        let tool = runChain
        let multiStep = tool.steps.count > 1
        let name = chain.name
        Task {
            // Completion keeps the job alive if the user switches away and notifies them when it's done.
            let rep = await Completion.run(name, ok: { $0.completed || $0.result != nil }) {
                await ChainRunner.runReport(tool, input: input)
            }
            await MainActor.run {
                busy = false
                // Show the step-by-step story for a multi-step flow, so the person sees exactly what ran,
                // what was skipped and why, and what (if anything) couldn't finish.
                report = multiStep ? rep : nil
                if let p = rep.result {
                    result = p
                    message = rep.stopper.map(ChainRunView.bestEffortNote)   // best-effort note if a step couldn't finish
                    finished(Outbox.make(p, named: chain.fileName, tool: chain.name))
                } else if let f = rep.stopper {
                    message = ChainRunView.words(f)
                }
            }
        }
    }

    /// The end-to-end confirmation: every step with a tick (ran), a dash (nothing to find, skipped) or a
    /// warning (couldn't finish, with what it needs). So the person always knows exactly what went through.
    @ViewBuilder private func stepLog(_ r: ChainRunner.RunReport) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(r.completed ? "Here's what it did" : "Here's how far it got", systemImage: "checklist")
                .font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
            ForEach(r.lines) { line in
                HStack(alignment: .top, spacing: HandySpacing.s8) {
                    switch line.mark {
                    case .ran: Image(systemName: "checkmark.circle.fill").foregroundStyle(HandyColor.success)
                    case .skipped: Image(systemName: "minus.circle.fill").foregroundStyle(HandyColor.textSecondary)
                    case .stopped: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(HandyColor.amber)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(line.block.title) — \(line.block.does)").font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary)
                        switch line.mark {
                        case .ran: EmptyView()
                        case .skipped: Text(L("Found nothing here, so it was skipped — the next steps still ran.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                        case .stopped(let f): Text(ChainRunView.words(f)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
    }

    static func words(_ f: ChainRunner.Failure) -> String {
        switch f {
        case .invalid(let s): return s
        case .wrongInput(let b): return "\(b.title) can't use that — it needs \(b.needs)."
        case .nothingFound(let b):
            let tail = b.takes == .image ? " Try a clearer or closer photo." : ""
            return "\(b.title) works best with \(b.needs).\(tail)"
        case .failed(let b): return "\(b.title) couldn't finish. Give it another go."
        }
    }

    /// Shown when the flow still delivered a best-effort result (e.g. the text it read) even though a later
    /// step couldn't finish — so the person knows why they got the earlier result and how to get the full one.
    static func bestEffortNote(_ f: ChainRunner.Failure) -> String {
        switch f {
        case .invalid(let s): return s
        case .wrongInput, .nothingFound, .failed:
            // The step card above ("Here's how far it got") already explains why the last step
            // stopped — don't repeat that reason here, just introduce the result it still produced.
            return "Here's what it got so far, so you still have it:"
        }
    }
}

/// "Start with what you have", step two: the tools that fit the thing that was picked. The person's own first.
private struct ToolPickView: View {
    let given: Given
    let mine: [Chain]
    @Environment(\.dismiss) private var dismiss

    /// The app's own full tools that open this kind of thing, already loaded (see ToolHandoff).
    private var direct: [Tool] {
        ToolHandoff.tools(for: given.payload.kind).compactMap { id in TOOLS.first { $0.id == id } }
    }

    /// Hand the item to a full tool: close this sheet, then open the tool with the item waiting.
    private func openIn(_ id: String) {
        ToolHandoff.shared.put(given.payload, for: id)
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { NotificationCenter.default.post(name: .openTool, object: id) }
    }

    private var tools: [Chain] {
        let kind = given.payload.kind == .photoFile ? ChainKind.image : given.payload.kind
        let text: String? = { if case .text(let t) = given.payload { return t } else { return nil } }()
        let offers = ChainStore.offers(for: kind, mine: mine, last: nil, text: text)
        // A pasted URL is its own object, not plain text: offer link actions — read/summarize the page,
        // strip tracking, QR, check it's safe — and drop the text-only tools (tidy, task list, pull
        // entities, WhatsApp-a-number) that make no sense on a bare link. First block picks relevance:
        // anything starting with "read the page" also covers summarize/translate/read-aloud of the page.
        if given.label == "A link" {
            let linkStart: Set<Block> = [.pageText, .cleanLinks, .makeQr, .scamCheck]
            let picked = offers.filter { linkStart.contains($0.steps.first?.block ?? .readText) }
            return picked.isEmpty ? offers : picked
        }
        return offers
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                Text(given.label).font(HandyFont.title).lineLimit(2).truncationMode(.middle)
                if case .text(let t) = given.payload, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(t).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(3)
                }
                if !direct.isEmpty {
                    Text(L("Open in a tool")).font(HandyFont.bodyStrong)
                    ForEach(direct, id: \.id) { t in
                        Button { openIn(t.id) } label: {
                            HStack(spacing: HandySpacing.s12) {
                                Image(systemName: t.icon).font(.system(size: 20)).foregroundStyle(HandyColor.accent).frame(width: 32, height: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L(t.name)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                                    Text(L(t.blurb)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(HandyColor.textSecondary)
                            }
                            .padding(HandySpacing.s12)
                            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("open-in-\(t.id)")
                    }
                    if !tools.isEmpty { Text(L("Or run a quick shortcut")).font(HandyFont.bodyStrong).padding(.top, HandySpacing.s8) }
                }
                if tools.isEmpty {
                    if direct.isEmpty {
                        Text("No tool takes this yet. Close this, tap Blank, and build one that starts with \(given.payload.kind.label).").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                } else {
                    Text(L("Pick what to do with it. It runs straight away.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                ForEach(tools) { c in
                    NavigationLink { ChainRunView(chain: c, initial: given.payload) } label: {
                        HStack(spacing: HandySpacing.s12) {
                            if let f = c.steps.first { BlockBadge(block: f.block) }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
                                Text(c.steps.map(\.block.title).joined(separator: "  ›  ")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2).multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(HandyColor.textSecondary)
                        }.cardStyle(padding: HandySpacing.s12)
                    }.buttonStyle(.plain).accessibilityIdentifier("pick-tool-\(c.id)")
                }
            }.padding(HandySpacing.gutter)
        }
        .background(Ground())
        .navigationTitle(L("What to do with it")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Close")) { dismiss() } } }
    }
}

/// A small "PRO" badge for a premium step a free user can see but not use yet.
struct ProTag: View {
    var body: some View {
        Text(L("PRO")).font(.system(size: 10, weight: .heavy)).foregroundStyle(HandyColor.onAccent)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(HandyColor.accent, in: Capsule())
            .accessibilityLabel(L("Pro step"))
    }
}
