import Foundation
#if canImport(SWCompression)
import SWCompression   // 7-Zip, BZip2
#endif
import UIKit
import ImageIO
import Compression
import SQLite3
import AVFoundation
import UniformTypeIdentifiers

/// File Opener's readers: every common file people get sent — books, comics, emails, tables, code, archives,
/// databases, pictures in odd formats — read on the phone into something you can actually go through, not just
/// "no app can open this". Each reader works from the file's own bytes (the name can lie), and anything it can't
/// read still gets its real type, size and a peek at the bytes — never a dead end.
enum FileReaders {

    enum Reading {
        case quickLook(URL)                                  // Apple's own viewer handles it (PDF, Office, iWork, media…)
        case table([[String]], note: String?)                // CSV / TSV / pipe / semicolon
        case text(String, title: String)                     // code, logs, config, pretty JSON/XML, Markdown
        case book(Book)                                      // EPUB, FB2, MOBI/AZW3/PRC/PDB
        case comic([Data])                                   // CBZ (and CBR that's really a ZIP)
        case email(Email)                                    // EML / EMLX
        case database([(table: String, rows: [[String]])])   // SQLite
        case archive([ArchiveEntry], kind: String)           // ZIP/JAR/APK/TAR/TGZ/GZ/XZ listings, entries openable
        case image(UIImage)                                  // anything ImageIO decodes + Netpbm
        case info(kind: String, detail: String, hex: String) // the rest: real type, details, first bytes
    }

    struct Chapter { var title: String; var html: String }
    struct Book { var title: String; var author: String; var chapters: [Chapter]; var baseDir: URL? }
    struct Email { var from, to, cc, subject, date: String; var html: String?; var text: String; var attachments: [(name: String, data: Data)] }
    struct ArchiveEntry: Identifiable { let id = UUID(); let name: String; let size: Int; let data: () -> Data? }

    // MARK: - what is it

    static let tableExts: Set<String> = ["csv", "tsv", "psv", "ssv", "tab"]
    static let codeExts: Set<String> = [
        "txt", "text", "log", "md", "markdown", "conf", "cfg", "ini", "properties", "yml", "yaml", "toml", "env", "htaccess",
        "c", "h", "cpp", "cxx", "cppm", "hpp", "cs", "java", "kt", "kts", "swift", "m", "mm", "go", "rs", "rb", "py", "pl", "php", "lua",
        "js", "mjs", "ts", "tsx", "jsx", "css", "scss", "sass", "less", "haml", "dart", "groovy", "gradle", "scala", "r", "jl", "nim",
        "sh", "bash", "zsh", "ps1", "bat", "cmd", "vb", "bas", "pas", "f", "for", "f90", "ada", "lisp", "clj", "ex", "exs", "erl",
        "sql", "tcl", "ahk", "as", "aspx", "bicep", "coffee", "nsi", "rbp", "wat", "xq", "xquery", "mk", "makefile", "cmake", "dockerfile",
        "json", "geojson", "xml", "plist", "svg", "srt", "vtt", "ass", "lrc", "tex", "bib", "rst", "adoc", "org", "diff", "patch",
    ]
    /// Office files Apple's viewer reads once they carry the base type's ending (macro/template variants are the same inside).
    static let officeAlias: [String: String] = [
        "docm": "docx", "dotx": "docx", "dotm": "docx", "dot": "doc",
        "xlsm": "xlsx", "xltx": "xlsx", "xltm": "xlsx", "xlt": "xls", "xlsb": "xlsx",
        "pptm": "pptx", "potx": "pptx", "potm": "pptx", "ppsx": "pptx", "ppsm": "pptx", "pps": "ppt", "pot": "ppt",
    ]
    static let quickLookExts: Set<String> = [
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key", "rtf", "rtfd", "html", "htm", "xhtml",
        "mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac", "amr", "3ga", "3gpa", "mp4", "m4v", "mov", "3gp", "3g2",
        "usdz", "reality", "vcf", "ics", "odt", "ods", "odp", "svg",
    ]
    static let bookExts: Set<String> = ["epub", "fb2", "mobi", "azw", "azw3", "prc", "pdb"]
    static let archiveExts: Set<String> = ["7z", "bz2", "tbz", "tbz2", "zip", "zipx", "jar", "apk", "aab", "ipa", "xpi", "war", "tar", "tgz", "gz", "gzip", "taz", "xz", "txz", "lzma", "tlzma", "lz4", "xps", "oxps", "cbz"]

    /// The reading for a file — by what's inside first, the ending second.
    static func read(_ url: URL) -> Reading {
        let ext = url.pathExtension.lowercased()
        let head = firstBytes(url, 16)
        // Office variants → the base type, so Apple's viewer shows the real document.
        if let base = officeAlias[ext], let copy = renamed(url, to: base) { return .quickLook(copy) }
        if ext == "cbz" || ext == "cbr" || ext == "cb7" {
            if head.starts(with: [0x50, 0x4B]), let pages = comicPages(url) { return .comic(pages) }
            if head.starts(with: sevenZipMagic), let a = archive(url) {
                let pages = a.entries.filter { ["jpg", "jpeg", "png", "webp", "gif", "heic"].contains(($0.name as NSString).pathExtension.lowercased()) }
                    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }.compactMap { $0.data() }
                if !pages.isEmpty { return .comic(pages) }
            }
            return info(url, kind: ext == "cbr" ? "Comic book (RAR)" : "Comic book",
                        "This comic is packed with RAR or 7-Zip, which Tenzy can't unpack yet. Most comic apps can — or ask the sender for a CBZ.")
        }
        if ext == "epub", let b = epub(url) { return .book(b) }
        if ext == "fb2", let b = fb2(url) { return .book(b) }
        if ["mobi", "azw", "azw3", "prc", "pdb"].contains(ext) {
            switch mobi(url) {
            case .success(let b): return .book(b)
            case .failure(let why): return info(url, kind: "eBook (\(ext.uppercased()))", why.message)
            }
        }
        if ext == "eml" || ext == "emlx" || ext == "mht" || ext == "mhtml", let e = email(url) { return .email(e) }
        // Outlook's own files: a saved message (.msg / .oft) and the winmail.dat it sends instead of attachments.
        if ext == "msg" || ext == "oft" || head.starts(with: OfficeMail.Compound.magic) && ext.isEmpty,
           let d = try? Data(contentsOf: url), let e = OfficeMail.msg(d) { return .email(e) }
        if ext == "dat" || ext == "tnef" || head.starts(with: OfficeMail.tnefMagic), let d = try? Data(contentsOf: url), let e = OfficeMail.tnef(d) { return .email(e) }
        if tableExts.contains(ext), let t = textOf(url) { let rows = table(t, ext: ext); return .table(rows, note: rows.count > 2000 ? "Showing the first 2,000 rows." : nil) }
        if ["db", "sqlite", "sqlite3", "db3"].contains(ext) || head.starts(with: Array("SQLite format 3".utf8)), let d = sqlite(url) { return .database(d) }
        if ["pbm", "pgm", "ppm", "pnm", "pam"].contains(ext), let img = netpbm(url) { return .image(img) }
        if ext == "xps" || ext == "oxps", let t = xpsText(url) { return .text(t, title: "Text of this XPS document") }
        // Voice notes and Ogg audio (WhatsApp, Telegram, podcasts): decoded so they play like any recording.
        if AudioIntake.isOggOpus(url) {
            if let m4a = Transcriber.oggOpusToM4A(url) { return .quickLook(m4a) }
            return info(url, kind: "Ogg audio", "This Ogg file uses Vorbis, which Tenzy can't play yet — Opus voice notes play fine.")
        }
        // MIDI: iPhone has no MIDI sounds, so the notes are played into a normal audio file you can hear and share.
        if ["mid", "midi", "kar", "smf"].contains(ext) || head.starts(with: Array("MThd".utf8)) {
            if let m4a = MIDIRender.toM4A(url) { return .quickLook(m4a) }
            return info(url, kind: "MIDI music", "This MIDI file has no notes Tenzy can play.")
        }
        if quickLookExts.contains(ext) { return .quickLook(url) }
        if let img = imageIO(url) { return .image(img) }                                       // PSD, TGA, EXR, JP2, AVIF, RAW, ICO, DDS…
        if archiveExts.contains(ext) || head.starts(with: sevenZipMagic) || head.starts(with: Array("BZh".utf8)) || head.starts(with: [0x50, 0x4B, 0x03, 0x04]) || head.starts(with: [0x1F, 0x8B]) || head.starts(with: [0xFD, 0x37, 0x7A, 0x58, 0x5A]) {
            if let a = archive(url) { return .archive(a.entries, kind: a.kind) }
        }
        if ext == "json" || ext == "geojson", let t = prettyJSON(url) { return .text(t, title: "JSON") }
        if codeExts.contains(ext) || ext.isEmpty || looksLikeText(url), let t = textOf(url) { return .text(String(t.prefix(400_000)), title: ext.isEmpty ? "Text" : ext.uppercased()) }
        if let t = UTType(filenameExtension: ext), t.conforms(to: .audiovisualContent) || t.conforms(to: .image) || t.conforms(to: .pdf) { return .quickLook(url) }
        return info(url, kind: typeName(url, head: head), nil)
    }

    // MARK: - tables

    /// A delimited table: the separator from the ending, or — for a .csv that's really ';' or tab separated — from the first line.
    static func table(_ text: String, ext: String) -> [[String]] {
        let firstLine = text.prefix(while: { $0 != "\n" })
        var sep: Character = ext == "tsv" || ext == "tab" ? "\t" : ext == "psv" ? "|" : ext == "ssv" ? ";" : ","
        if ext == "csv" {
            let counts: [(Character, Int)] = [(",", firstLine.filter { $0 == "," }.count), (";", firstLine.filter { $0 == ";" }.count), ("\t", firstLine.filter { $0 == "\t" }.count), ("|", firstLine.filter { $0 == "|" }.count)]
            if let best = counts.max(by: { $0.1 < $1.1 }), best.1 > 0 { sep = best.0 }
        }
        var rows: [[String]] = [], row: [String] = [], cell = "", quoted = false
        let chars = Array(text)
        var i = 0
        while i < chars.count, rows.count < 2000 {
            let c = chars[i]
            if quoted {
                if c == "\"" { if i + 1 < chars.count, chars[i + 1] == "\"" { cell.append("\""); i += 1 } else { quoted = false } } else { cell.append(c) }
            } else if c == "\"" && cell.isEmpty { quoted = true }
            else if c == sep { row.append(cell); cell = "" }
            else if c == "\n" || c == "\r\n" { row.append(cell); rows.append(row); row = []; cell = "" }
            else if c != "\r" { cell.append(c) }
            i += 1
        }
        if !cell.isEmpty || !row.isEmpty { row.append(cell); rows.append(row) }
        return rows.filter { !($0.count == 1 && $0[0].isEmpty) }
    }

    // MARK: - books

    static func epub(_ url: URL) -> Book? {
        guard let dir = unzipAll(url) else { return nil }
        guard let container = try? String(contentsOf: dir.appendingPathComponent("META-INF/container.xml"), encoding: .utf8),
              let opfPath = firstMatch(#"full-path="([^"]+)""#, in: container) else { return nil }
        let opfURL = dir.appendingPathComponent(opfPath)
        guard let opf = try? String(contentsOf: opfURL, encoding: .utf8) else { return nil }
        let base = opfURL.deletingLastPathComponent()
        var manifest: [String: String] = [:]
        for m in matches(#"<(?:\w+:)?item\b[^>]*>"#, in: opf) {
            if let id = firstMatch(#"\bid="([^"]+)""#, in: m), let href = firstMatch(#"\bhref="([^"]+)""#, in: m) { manifest[id] = href.removingPercentEncoding ?? href }
        }
        let spine = matches(#"<(?:\w+:)?itemref\b[^>]*>"#, in: opf).compactMap { firstMatch(#"idref="([^"]+)""#, in: $0) }
        var chapters: [Chapter] = []
        for id in spine {
            guard let href = manifest[id] else { continue }
            let f = base.appendingPathComponent(href)
            guard let html = textOf(f) else { continue }
            let title = firstMatch(#"<h[1-3][^>]*>([\s\S]*?)</h[1-3]>"#, in: html).map(stripTags) ?? "Chapter \(chapters.count + 1)"
            // Keep each chapter's own folder for its pictures: <base href> to where the file lives.
            let withBase = html.replacingOccurrences(of: "<head>", with: "<head><base href=\"\(f.deletingLastPathComponent().absoluteString)\">", options: .caseInsensitive)
            chapters.append(Chapter(title: String(title.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines), html: withBase))
        }
        guard !chapters.isEmpty else { return nil }
        let title = firstMatch(#"<dc:title[^>]*>([\s\S]*?)</dc:title>"#, in: opf).map(stripTags) ?? url.deletingPathExtension().lastPathComponent
        let author = firstMatch(#"<dc:creator[^>]*>([\s\S]*?)</dc:creator>"#, in: opf).map(stripTags) ?? ""
        return Book(title: title, author: author, chapters: chapters, baseDir: dir)
    }

    static func fb2(_ url: URL) -> Book? {
        guard let x = textOf(url) else { return nil }
        var images: [String: String] = [:]
        for b in matches(#"<binary\b[^>]*>[\s\S]*?</binary>"#, in: x) {
            if let id = firstMatch(#"id="([^"]+)""#, in: b), let type = firstMatch(#"content-type="([^"]+)""#, in: b),
               let body = firstMatch(#">([\s\S]*?)</binary>"#, in: b) { images[id] = "data:\(type);base64,\(body.filter { !$0.isWhitespace })" }
        }
        func html(_ s: String) -> String {
            var h = s
            for (from, to) in [("<p>", "<p>"), ("<title>", "<h2>"), ("</title>", "</h2>"), ("<subtitle>", "<h3>"), ("</subtitle>", "</h3>"), ("<emphasis>", "<em>"), ("</emphasis>", "</em>"), ("<strong>", "<b>"), ("</strong>", "</b>"), ("<empty-line/>", "<br>"), ("<poem>", "<blockquote>"), ("</poem>", "</blockquote>")] {
                h = h.replacingOccurrences(of: from, with: to)
            }
            for (id, src) in images { h = h.replacingOccurrences(of: "<image l:href=\"#\(id)\"/>", with: "<img src=\"\(src)\">").replacingOccurrences(of: "<image xlink:href=\"#\(id)\"/>", with: "<img src=\"\(src)\">") }
            return h
        }
        guard let body = firstMatch(#"<body\b[^>]*>([\s\S]*?)</body>"#, in: x) else { return nil }
        var sections = matches(#"<section\b[^>]*>[\s\S]*?</section>"#, in: body)
        if sections.isEmpty { sections = [body] }
        let chapters = sections.enumerated().map { i, s in
            Chapter(title: firstMatch(#"<title>([\s\S]*?)</title>"#, in: s).map(stripTags)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Part \(i + 1)", html: "<html><body>\(html(s))</body></html>")
        }
        let title = firstMatch(#"<book-title>([\s\S]*?)</book-title>"#, in: x).map(stripTags) ?? url.deletingPathExtension().lastPathComponent
        let author = [firstMatch(#"<first-name>([\s\S]*?)</first-name>"#, in: x), firstMatch(#"<last-name>([\s\S]*?)</last-name>"#, in: x)].compactMap { $0 }.joined(separator: " ")
        return Book(title: title, author: author, chapters: chapters, baseDir: nil)
    }

    enum MobiProblem: Error { case notMobi, drm, kf8Huffman
        var message: String {
            switch self {
            case .notMobi: return "This doesn't look like a Kindle or Mobipocket book inside."
            case .drm: return "This book is locked to a Kindle account (DRM), so only the Kindle app can open it."
            case .kf8Huffman: return "This book uses Kindle's dictionary compression, which Tenzy can't unpack yet. The Kindle app opens it."
            }
        }
    }

    /// Mobipocket / Kindle (MOBI, AZW, AZW3, PRC) and plain Palm eBooks (PDB, PalmDOC): the text records, decompressed,
    /// with their pictures. Kindle books bought from Amazon are DRM-locked and say so.
    static func mobi(_ url: URL) -> Result<Book, MobiProblem> {
        guard let d = try? Data(contentsOf: url), d.count > 78 else { return .failure(.notMobi) }
        let b = [UInt8](d)
        func u16(_ o: Int) -> Int { o + 2 <= b.count ? Int(b[o]) << 8 | Int(b[o + 1]) : 0 }
        func u32(_ o: Int) -> Int { o + 4 <= b.count ? Int(b[o]) << 24 | Int(b[o + 1]) << 16 | Int(b[o + 2]) << 8 | Int(b[o + 3]) : 0 }
        let type = String(decoding: b[60..<68], as: UTF8.self)
        guard type == "BOOKMOBI" || type == "TEXtREAd" else { return .failure(.notMobi) }
        let n = u16(76)
        let offsets = (0..<n).map { u32(78 + $0 * 8) } + [b.count]
        func record(_ i: Int) -> ArraySlice<UInt8> { i < n ? b[offsets[i]..<min(offsets[i + 1], b.count)] : [] }
        let r0 = Array(record(0))
        func r0u16(_ o: Int) -> Int { o + 2 <= r0.count ? Int(r0[o]) << 8 | Int(r0[o + 1]) : 0 }
        func r0u32(_ o: Int) -> Int { o + 4 <= r0.count ? Int(r0[o]) << 24 | Int(r0[o + 1]) << 16 | Int(r0[o + 2]) << 8 | Int(r0[o + 3]) : 0 }
        let compression = r0u16(0), textCount = r0u16(8)
        if r0u16(12) != 0 { return .failure(.drm) }
        if compression == 17480 { return .failure(.kf8Huffman) }
        var title = url.deletingPathExtension().lastPathComponent, firstImage = -1, extraFlags = 0, encoding = String.Encoding.windowsCP1252
        if r0.count > 20, String(decoding: r0[16..<20], as: UTF8.self) == "MOBI" {
            let headerLen = r0u32(20)
            if r0u32(28) == 65001 { encoding = .utf8 }
            let nameOff = r0u32(84), nameLen = r0u32(88)
            if nameOff + nameLen <= r0.count, nameLen > 0 { title = String(data: Data(r0[nameOff..<nameOff + nameLen]), encoding: encoding) ?? title }
            firstImage = r0u32(108)
            if headerLen >= 0xE4 { extraFlags = r0u16(0xF2) }
        }
        var text = Data()
        for i in 1...max(1, textCount) where i < n {
            var rec = Array(record(i))
            // Trailing entries some files append to each text record: strip them before decompressing.
            if extraFlags != 0 { rec = stripTrailing(rec, flags: extraFlags) }
            text.append(contentsOf: compression == 2 ? palmDOC(rec) : rec)
        }
        var html = String(data: text, encoding: encoding) ?? String(decoding: text, as: UTF8.self)
        if firstImage > 0 {
            html = html.replacingOccurrences(of: #"recindex="(\d+)""#, with: "IMGREF$1", options: .regularExpression)
            for m in matches(#"IMGREF\d+"#, in: html) {
                let idx = (Int(m.dropFirst(6)) ?? 0) - 1 + firstImage
                guard idx < n else { continue }
                html = html.replacingOccurrences(of: m, with: "src=\"data:image/jpeg;base64,\(Data(record(idx)).base64EncodedString())\"")
            }
        }
        if type == "TEXtREAd" { html = "<pre style='white-space:pre-wrap;font-family:-apple-system'>" + html.replacingOccurrences(of: "<", with: "&lt;") + "</pre>" }
        // Split into chapters at Mobipocket page breaks so long books can be moved through.
        let parts = html.components(separatedBy: "<mbp:pagebreak/>").filter { stripTags($0).trimmingCharacters(in: .whitespacesAndNewlines).count > 20 }
        let chapters = (parts.isEmpty ? [html] : parts).enumerated().map { i, p in
            Chapter(title: firstMatch(#"<h[1-3][^>]*>([\s\S]*?)</h[1-3]>"#, in: p).map(stripTags)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Part \(i + 1)", html: "<html><body>\(p)</body></html>")
        }
        return .success(Book(title: title, author: "", chapters: chapters, baseDir: nil))
    }

    /// PalmDOC LZ77, as used by Mobipocket and Palm eBooks.
    static func palmDOC(_ src: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []; out.reserveCapacity(src.count * 2)
        var i = 0
        while i < src.count {
            let c = src[i]; i += 1
            switch c {
            case 0, 0x09...0x7F: out.append(c)
            case 0x01...0x08:
                let end = min(src.count, i + Int(c)); out.append(contentsOf: src[i..<end]); i = end
            case 0x80...0xBF:
                guard i < src.count else { break }
                let pair = Int(c) << 8 | Int(src[i]); i += 1
                let dist = (pair >> 3) & 0x07FF, len = (pair & 7) + 3
                guard dist > 0, dist <= out.count else { break }
                for _ in 0..<len { out.append(out[out.count - dist]) }
            default: out.append(0x20); out.append(c ^ 0x80)
            }
        }
        return out
    }

    private static func stripTrailing(_ rec: [UInt8], flags: Int) -> [UInt8] {
        var size = rec.count
        func backwardVarint(_ end: Int) -> Int {
            var v = 0, shift = 0, p = end - 1
            while p >= 0 { let b = Int(rec[p]); v |= (b & 0x7F) << shift; shift += 7; if b & 0x80 != 0 || shift > 28 { break }; p -= 1 }
            return v
        }
        var f = flags >> 1
        while f != 0 { if f & 1 != 0, size > 0 { size -= min(size, backwardVarint(size)) }; f >>= 1 }
        if flags & 1 != 0, size > 0 { size -= Int(rec[size - 1] & 3) + 1 }
        return Array(rec[0..<max(0, size)])
    }

    // MARK: - comics

    static func comicPages(_ url: URL) -> [Data]? {
        let names = Given.Zip.names(in: url).filter { ["jpg", "jpeg", "png", "gif", "webp", "heic", "bmp"].contains(($0 as NSString).pathExtension.lowercased()) && !$0.hasPrefix("__MACOSX") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let pages = names.compactMap { Given.Zip.entryData(in: url, named: $0) }
        return pages.isEmpty ? nil : pages
    }

    // MARK: - email

    static func email(_ url: URL) -> Email? {
        guard var raw = textOf(url) else { return nil }
        if url.pathExtension.lowercased() == "emlx", let nl = raw.firstIndex(of: "\n") { raw = String(raw[raw.index(after: nl)...]) }
        let (headers, body) = splitHeaders(raw)
        func h(_ k: String) -> String { decodeHeader(headers[k.lowercased()] ?? "") }
        var e = Email(from: h("From"), to: h("To"), cc: h("Cc"), subject: h("Subject"), date: h("Date"), html: nil, text: "", attachments: [])
        walk(headers: headers, body: body, into: &e)
        if e.text.isEmpty, e.html == nil { e.text = body }
        return e
    }

    private static func walk(headers: [String: String], body: String, into e: inout Email) {
        let ct = headers["content-type"] ?? "text/plain"
        let low = ct.lowercased()
        if low.hasPrefix("multipart/"), let boundary = firstMatch(#"boundary="?([^";]+)"?"#, in: ct) {
            for part in body.components(separatedBy: "--" + boundary).dropFirst() where !part.hasPrefix("--") {
                let (ph, pb) = splitHeaders(part.trimmingCharacters(in: CharacterSet(charactersIn: "\r\n")))
                walk(headers: ph, body: pb, into: &e)
            }
            return
        }
        let data = decodeBody(body, encoding: headers["content-transfer-encoding"] ?? "")
        let disposition = headers["content-disposition"] ?? ""
        let name = firstMatch(#"(?:file)?name\*?="?([^";\r\n]+)"?"#, in: disposition + ";" + ct).map(decodeHeader)
        let charset = firstMatch(#"charset="?([\w-]+)"?"#, in: ct)?.lowercased() ?? "utf-8"
        let enc: String.Encoding = charset.contains("8859") || charset.contains("1252") ? .windowsCP1252 : .utf8
        if disposition.lowercased().hasPrefix("attachment") || (name != nil && !low.hasPrefix("text/")) {
            e.attachments.append((name ?? "attachment", data))
        } else if low.hasPrefix("text/html") {
            e.html = (e.html ?? "") + (String(data: data, encoding: enc) ?? String(decoding: data, as: UTF8.self))
        } else if low.hasPrefix("text/") {
            e.text += String(data: data, encoding: enc) ?? String(decoding: data, as: UTF8.self)
        } else if low.hasPrefix("message/rfc822") {
            e.attachments.append(("Forwarded message.eml", data))
        }
    }

    private static func splitHeaders(_ s: String) -> ([String: String], String) {
        let norm = s.replacingOccurrences(of: "\r\n", with: "\n")
        guard let r = norm.range(of: "\n\n") else { return ([:], norm) }
        var headers: [String: String] = [:], last = ""
        for line in norm[..<r.lowerBound].split(separator: "\n", omittingEmptySubsequences: false) {
            if line.first == " " || line.first == "\t" { headers[last, default: ""] += " " + line.trimmingCharacters(in: .whitespaces); continue }
            guard let c = line.firstIndex(of: ":") else { continue }
            last = line[..<c].lowercased(); headers[last] = line[line.index(after: c)...].trimmingCharacters(in: .whitespaces)
        }
        return (headers, String(norm[r.upperBound...]))
    }

    private static func decodeBody(_ body: String, encoding: String) -> Data {
        switch encoding.lowercased().trimmingCharacters(in: .whitespaces) {
        case "base64": return Data(base64Encoded: body.filter { !$0.isWhitespace }) ?? Data()
        case "quoted-printable": return quotedPrintable(body)
        default: return Data(body.utf8)
        }
    }

    static func quotedPrintable(_ s: String) -> Data {
        var out = [UInt8](), bytes = Array(s.replacingOccurrences(of: "=\n", with: "").replacingOccurrences(of: "=\r\n", with: "").utf8), i = 0
        while i < bytes.count {
            if bytes[i] == UInt8(ascii: "="), i + 2 < bytes.count, let v = UInt8(String(decoding: bytes[i + 1...i + 2], as: UTF8.self), radix: 16) { out.append(v); i += 3 }
            else { out.append(bytes[i]); i += 1 }
        }
        return Data(out)
    }

    /// "=?UTF-8?B?…?=" / "=?utf-8?Q?…?=" in subjects and names.
    static func decodeHeader(_ s: String) -> String {
        var out = s
        for m in matches(#"=\?([^?]+)\?([BbQq])\?([^?]*)\?="#, in: s) {
            let parts = m.dropFirst(2).dropLast(2).split(separator: "?", omittingEmptySubsequences: false)
            guard parts.count == 3 else { continue }
            let data = parts[1].uppercased() == "B" ? Data(base64Encoded: String(parts[2])) : quotedPrintable(parts[2].replacingOccurrences(of: "_", with: " "))
            if let d = data, let t = String(data: d, encoding: .utf8) ?? String(data: d, encoding: .windowsCP1252) { out = out.replacingOccurrences(of: m, with: t) }
        }
        return out.replacingOccurrences(of: "?= =?", with: "?==?")
    }

    // MARK: - databases

    static func sqlite(_ url: URL) -> [(table: String, rows: [[String]])]? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_close(db) }
        func query(_ sql: String, limit: Int) -> [[String]] {
            var st: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(st) }
            let cols = Int(sqlite3_column_count(st))
            var rows = [(0..<cols).map { sqlite3_column_name(st, Int32($0)).map { String(cString: $0) } ?? "" }]
            while rows.count <= limit, sqlite3_step(st) == SQLITE_ROW {
                rows.append((0..<cols).map { c in sqlite3_column_text(st, Int32(c)).map { String(cString: $0) } ?? "" })
            }
            return rows
        }
        let tables = query("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name", limit: 200).dropFirst().map { $0[0] }
        guard !tables.isEmpty else { return nil }
        return tables.map { t in
            let quoted = "\"" + t.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            return (t, query("SELECT * FROM " + quoted, limit: 200))
        }
    }

    // MARK: - archives

    static let sevenZipMagic: [UInt8] = [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]

    static func archive(_ url: URL) -> (entries: [ArchiveEntry], kind: String)? {
        let head = firstBytes(url, 6)
        #if canImport(SWCompression)
        if head.starts(with: sevenZipMagic), let raw = try? Data(contentsOf: url) {
            guard let all = try? SevenZipContainer.open(container: raw) else { return nil }
            let files = all.filter { $0.info.type == .regular }
            return (files.map { e in ArchiveEntry(name: e.info.name, size: e.info.size ?? e.data?.count ?? 0, data: { e.data }) }, "7-Zip")
        }
        if head.starts(with: Array("BZh".utf8)), let raw = try? Data(contentsOf: url), let d = try? BZip2.decompress(data: raw) {
            if let entries = tar(d), !entries.isEmpty { return (entries, "TAR (BZip2)") }
            return ([ArchiveEntry(name: url.deletingPathExtension().lastPathComponent, size: d.count, data: { d })], "BZip2")
        }
        #endif
        if head.starts(with: [0x50, 0x4B]) {
            let names = Given.Zip.names(in: url).filter { !$0.hasPrefix("__MACOSX") }
            guard !names.isEmpty else { return nil }
            let ext = url.pathExtension.lowercased()
            let kind = ext == "apk" || ext == "aab" ? "Android app" : ext == "ipa" ? "iPhone app" : ext == "jar" ? "Java archive" : "ZIP"
            return (names.map { n in ArchiveEntry(name: n, size: 0, data: { Given.Zip.entryData(in: url, named: n) }) }, kind)
        }
        guard let raw = try? Data(contentsOf: url) else { return nil }
        var data = raw, kind = "TAR"
        if head.starts(with: [0x1F, 0x8B]), let g = gunzip(raw) { data = g; kind = "GZip" }
        else if head.starts(with: [0xFD, 0x37, 0x7A, 0x58, 0x5A]), let x = decompress(raw, algorithm: COMPRESSION_LZMA) { data = x; kind = "XZ" }
        if let entries = tar(data), !entries.isEmpty { return (entries, kind == "TAR" ? "TAR" : "TAR (\(kind))") }
        if kind != "TAR" {
            // A single compressed file (log.gz): the file itself.
            let inner = url.deletingPathExtension().lastPathComponent
            return ([ArchiveEntry(name: inner, size: data.count, data: { data })], kind)
        }
        return nil
    }

    static func tar(_ d: Data) -> [ArchiveEntry]? {
        let b = [UInt8](d)
        var p = 0, out: [ArchiveEntry] = [], longName: String?
        while p + 512 <= b.count {
            let header = b[p..<p + 512]
            if header.allSatisfy({ $0 == 0 }) { break }
            func str(_ o: Int, _ l: Int) -> String { String(decoding: b[p + o..<p + o + l].prefix { $0 != 0 }, as: UTF8.self) }
            guard let size = Int(str(124, 12).trimmingCharacters(in: .whitespaces), radix: 8) else { return out.isEmpty ? nil : out }
            let type = b[p + 156], prefix = str(345, 155)
            var name = longName ?? ((prefix.isEmpty ? "" : prefix + "/") + str(0, 100)); longName = nil
            let start = p + 512, end = min(b.count, start + size)
            if type == UInt8(ascii: "L") { longName = String(decoding: b[start..<end].prefix { $0 != 0 }, as: UTF8.self) }
            else if type == 0 || type == UInt8(ascii: "0") {
                if name.hasPrefix("./") { name.removeFirst(2) }
                let slice = Data(b[start..<end])
                out.append(ArchiveEntry(name: name, size: size, data: { slice }))
            }
            p = start + ((size + 511) / 512) * 512
        }
        return out
    }

    static func gunzip(_ d: Data) -> Data? {
        let b = [UInt8](d)
        guard b.count > 18, b[0] == 0x1F, b[1] == 0x8B, b[2] == 8 else { return nil }
        let flags = b[3]; var p = 10
        if flags & 4 != 0 { p += 2 + (Int(b[p]) | Int(b[p + 1]) << 8) }
        if flags & 8 != 0 { while p < b.count, b[p] != 0 { p += 1 }; p += 1 }
        if flags & 16 != 0 { while p < b.count, b[p] != 0 { p += 1 }; p += 1 }
        if flags & 2 != 0 { p += 2 }
        guard p < b.count - 8 else { return nil }
        let isize = Int(b[b.count - 4]) | Int(b[b.count - 3]) << 8 | Int(b[b.count - 2]) << 16 | Int(b[b.count - 1]) << 24
        return decompress(Data(b[p..<b.count - 8]), algorithm: COMPRESSION_ZLIB, expected: isize)
    }

    static func decompress(_ src: Data, algorithm: compression_algorithm, expected: Int = 0) -> Data? {
        var cap = max(expected, src.count * 6) + 4096
        for _ in 0..<4 {
            var dst = [UInt8](repeating: 0, count: cap)
            let n = src.withUnsafeBytes { s in dst.withUnsafeMutableBufferPointer { compression_decode_buffer($0.baseAddress!, cap, s.bindMemory(to: UInt8.self).baseAddress!, src.count, nil, algorithm) } }
            if n > 0, n < cap { return Data(dst[0..<n]) }
            cap *= 4
            if cap > 400_000_000 { break }
        }
        return nil
    }

    // MARK: - pictures

    static func imageIO(_ url: URL) -> UIImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(src) > 0 else { return nil }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 3000, kCGImageSourceCreateThumbnailWithTransform: true]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// Netpbm (PBM/PGM/PPM, text P1–P3 and binary P4–P6).
    static func netpbm(_ url: URL) -> UIImage? {
        guard let d = try? Data(contentsOf: url), d.count > 3 else { return nil }
        let b = [UInt8](d)
        var p = 0
        func token() -> String? {
            while p < b.count {
                if b[p] == UInt8(ascii: "#") { while p < b.count, b[p] != 10 { p += 1 } }
                else if b[p] == 32 || b[p] == 9 || b[p] == 10 || b[p] == 13 { p += 1 } else { break }
            }
            let s = p; while p < b.count, !(b[p] == 32 || b[p] == 9 || b[p] == 10 || b[p] == 13) { p += 1 }
            return s < p ? String(decoding: b[s..<p], as: UTF8.self) : nil
        }
        guard let magic = token(), magic.count == 2, magic.first == "P", let kind = Int(String(magic.last!)), (1...6).contains(kind),
              let w = token().flatMap(Int.init), let h = token().flatMap(Int.init), w > 0, h > 0, w * h < 50_000_000 else { return nil }
        let maxv = (kind == 1 || kind == 4) ? 1 : (token().flatMap(Int.init) ?? 255)
        var rgba = [UInt8](repeating: 255, count: w * h * 4)
        if kind >= 4 { p += 1 }
        for i in 0..<(w * h) {
            var r = 0, g = 0, bl = 0
            switch kind {
            case 1: let v = token() == "1" ? 0 : 255; r = v; g = v; bl = v
            case 2: let v = (Int(token() ?? "0") ?? 0) * 255 / maxv; r = v; g = v; bl = v
            case 3: r = (Int(token() ?? "0") ?? 0) * 255 / maxv; g = (Int(token() ?? "0") ?? 0) * 255 / maxv; bl = (Int(token() ?? "0") ?? 0) * 255 / maxv
            case 4:
                let row = i / w, col = i % w, byte = p + row * ((w + 7) / 8) + col / 8
                let v = byte < b.count && (b[byte] >> (7 - UInt8(col % 8))) & 1 == 1 ? 0 : 255; r = v; g = v; bl = v
            case 5: let v = p + i < b.count ? Int(b[p + i]) * 255 / maxv : 0; r = v; g = v; bl = v
            default:
                let o = p + i * 3
                if o + 2 < b.count { r = Int(b[o]) * 255 / maxv; g = Int(b[o + 1]) * 255 / maxv; bl = Int(b[o + 2]) * 255 / maxv }
            }
            rgba[i * 4] = UInt8(clamping: r); rgba[i * 4 + 1] = UInt8(clamping: g); rgba[i * 4 + 2] = UInt8(clamping: bl)
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let cg = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: - XPS

    static func xpsText(_ url: URL) -> String? {
        let pages = Given.Zip.names(in: url).filter { $0.lowercased().hasSuffix(".fpage") }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let text = pages.enumerated().compactMap { i, p -> String? in
            guard let x = Given.Zip.entryText(in: url, named: p) else { return nil }
            let words = matches(#"UnicodeString="([^"]*)""#, in: x).compactMap { firstMatch(#"UnicodeString="([^"]*)""#, in: $0) }
            return "— Page \(i + 1) —\n" + words.joined(separator: "\n")
        }.joined(separator: "\n\n")
        return text.isEmpty ? nil : text.replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&quot;", with: "\"")
    }

    // MARK: - JSON / text helpers

    static func prettyJSON(_ url: URL) -> String? {
        guard let d = try? Data(contentsOf: url), let o = try? JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed]),
              let p = try? JSONSerialization.data(withJSONObject: o, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else { return nil }
        return String(data: p, encoding: .utf8)
    }

    /// Text in any common encoding: UTF-8, UTF-16 (with a byte-order mark), then Windows Latin.
    static func looksLikeText(_ url: URL) -> Bool {
        let head = firstBytes(url, 2048)
        guard !head.isEmpty else { return false }
        if head.starts(with: [0xFF, 0xFE]) || head.starts(with: [0xFE, 0xFF]) { return true }
        let control = head.filter { $0 < 9 || ($0 > 13 && $0 < 32) }.count
        return control == 0 && String(data: Data(head), encoding: .utf8) != nil
    }

    // MARK: - everything else

    static func info(_ url: URL, kind: String, _ note: String?) -> Reading {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let hex = firstBytes(url, 96).enumerated().map { i, b in String(format: "%02X", b) + (i % 16 == 15 ? "\n" : " ") }.joined()
        let detail = [note, "\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)) · \(url.pathExtension.uppercased())"].compactMap { $0 }.joined(separator: "\n")
        return .info(kind: kind, detail: detail, hex: hex)
    }

    /// The real type from the first bytes, for files whose name says nothing useful.
    static func typeName(_ url: URL, head: [UInt8]) -> String {
        let sigs: [([UInt8], String)] = [
            ([0x52, 0x61, 0x72, 0x21], "RAR archive"), ([0x37, 0x7A, 0xBC, 0xAF], "7-Zip archive"), ([0x42, 0x5A, 0x68], "Bzip2 archive"),
            ([0x28, 0xB5, 0x2F, 0xFD], "Zstandard archive"), ([0x7F, 0x45, 0x4C, 0x46], "Linux program (ELF)"), ([0x4D, 0x5A], "Windows program (EXE/DLL)"),
            ([0xCF, 0xFA, 0xED, 0xFE], "Mac/iPhone program (Mach-O)"), ([0xD0, 0xCF, 0x11, 0xE0], "Outlook message or old Office file"),
            ([0x1A, 0x45, 0xDF, 0xA3], "Matroska / WebM video"), ([0x4F, 0x67, 0x67, 0x53], "Ogg audio"), ([0x4D, 0x54, 0x68, 0x64], "MIDI music"),
            ([0x23, 0x21, 0x41, 0x4D, 0x52], "AMR voice recording"), ([0x49, 0x54, 0x53, 0x46], "Compiled HTML help (CHM)"), ([0x78, 0x9F, 0x3E, 0x22], "Winmail.dat (TNEF)"),
            ([0x6B, 0x6F, 0x6C, 0x79], "macOS disk image"), ([0x21, 0x3C, 0x61, 0x72, 0x63, 0x68, 0x3E], "Unix archive (deb/ar)"),
        ]
        if let s = sigs.first(where: { head.starts(with: $0.0) }) { return s.1 }
        if let t = UTType(filenameExtension: url.pathExtension) { return t.localizedDescription ?? url.pathExtension.uppercased() }
        return url.pathExtension.isEmpty ? "Unknown file" : "\(url.pathExtension.uppercased()) file"
    }

    static func firstBytes(_ url: URL, _ n: Int) -> [UInt8] {
        guard let h = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? h.close() }
        return [UInt8]((try? h.read(upToCount: n)) ?? Data())
    }

    static func unzipAll(_ url: URL) -> URL? {
        let names = Given.Zip.names(in: url)
        guard !names.isEmpty else { return nil }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("open-\(UUID().uuidString.prefix(8))", isDirectory: true)
        for n in names where !n.contains("..") {
            guard let d = Given.Zip.entryData(in: url, named: n) else { continue }
            let f = dir.appendingPathComponent(n)
            try? FileManager.default.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? d.write(to: f)
        }
        return dir
    }

    static func renamed(_ url: URL, to ext: String) -> URL? {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(url.deletingPathExtension().lastPathComponent + "-\(UUID().uuidString.prefix(4)).\(ext)")
        return (try? FileManager.default.copyItem(at: url, to: u)) != nil ? u : nil
    }

    static func stripTags(_ s: String) -> String {
        s.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&nbsp;", with: " ").replacingOccurrences(of: "&#160;", with: " ")
    }
    static func firstMatch(_ p: String, in s: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)), m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[r])
    }
    static func matches(_ p: String, in s: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) else { return [] }
        return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap { Range($0.range, in: s).map { String(s[$0]) } }
    }
}

extension FileReaders {
    /// Text from a file in UTF-8, UTF-16 (BOM) or Windows Latin — whichever it really is.
    static func textOf(_ url: URL) -> String? {
        guard let d = try? Data(contentsOf: url) else { return nil }
        if let s = String(data: d, encoding: .utf8) { return s }
        if d.starts(with: [0xFF, 0xFE]) || d.starts(with: [0xFE, 0xFF]), let s = String(data: d, encoding: .utf16) { return s }
        return String(data: d, encoding: .windowsCP1252)
    }
}

// MARK: - what File Opener promises, format by format

extension FileReaders {
    enum Support: Equatable { case reads, apple, notYet(String) }

    /// Formats File Opener does NOT read yet, each with the honest reason shown to the person. A format leaves this
    /// list only when its reader is built (the coverage test fails if one is both here and readable).
    static let notYet: [String: String] = {
        var m: [String: String] = [:]
        func add(_ exts: [String], _ why: String) { for e in exts { m[e] = why } }
        add(["msg", "oft"], "Outlook message — reader being built.")
        add(["dat"], "Winmail.dat from Outlook — reader being built.")
        add(["7z", "rar", "r00", "cbr", "cab", "arj", "lzh", "lha", "wim", "xar", "zipx"], "Packed with a method Tenzy can't unpack yet (RAR / 7-Zip family).")
        add(["bz2", "bzip2", "tbz", "tbz2", "zst", "zstd", "tzst", "lz4", "lz5", "z", "taz"], "Compressed with a method Tenzy can't unpack yet.")
        add(["cpio", "ar", "deb", "udeb", "rpm"], "Software package — listing its files is being built.")
        add(["apfs", "cramfs", "dmg", "ext4", "fat", "hfs", "iso", "ntfs", "qcow", "qcow2", "simg", "squashfs", "udf", "vdi", "vhd", "vhdx", "avhdx", "vmdk"],
            "Disk image — Tenzy shows its type and size; browsing what's inside isn't built yet.")
        add(["dylib", "elf", "sys"], "A computer program — Tenzy shows what kind and its details; programs can't run on a phone.")
        add(["chm"], "Windows help file — reader being built.")
        add(["mid", "midi", "imy", "ota"], "Music notes (MIDI / ringtone code) — player being built.")
        add(["mkv", "mka", "webm"], "Matroska / WebM — player being built.")
        add(["ogg", "oga"], "Ogg Vorbis music — player being built (Opus voice notes already play).")
        add(["lzma", "tlzma"], "Compressed with LZMA — unpacking being built.")
        // Pictures the iPhone's own decoder doesn't know (it knows PSD, TGA, EXR, JP2, AVIF, ICO, BMP, TIFF, HEIC, WebP and most RAW).
        add(["dds", "iff", "jng", "mng", "pcd", "pcx", "ras", "rgb", "rgba", "sgi", "wbmp", "xbm", "xpm", "avifs", "exr", "jp2", "tga", "targa", "psd", "ico", "avif", "heif", "bmp", "tif", "tiff"],
            "Picture format — decoder being built.")
        add(["3fr", "arw", "bay", "cr2", "cr3", "crw", "dcr", "dng", "erf", "kdc", "mos", "mrw", "nef", "nrw", "orf", "pef", "raf", "raw", "rw2", "rwl", "sr2", "srf", "srw", "x3f"],
            "This camera's RAW format isn't one the iPhone decodes yet.")
        return m
    }()

    /// What File Opener does with a file ending — the same tables `read` uses, plus what this phone's own image and
    /// media frameworks decode, so the answer can't drift from what actually happens.
    static func support(_ raw: String) -> Support {
        let ext = (raw as NSString).pathExtension.isEmpty ? raw.lowercased() : (raw as NSString).pathExtension.lowercased()
        if tableExts.contains(ext) || codeExts.contains(ext) || bookExts.contains(ext) || officeAlias[ext] != nil
            || ["eml", "emlx", "mht", "mhtml", "db", "sqlite", "sqlite3", "db3", "pbm", "pgm", "ppm", "pnm", "pam", "xps", "oxps", "opus", "cbz",
                "zip", "jar", "apk", "aab", "ipa", "tar", "tgz", "gz", "gzip", "xz", "txz", "html", "htm", "xhtml", "text"].contains(ext) { return .reads }
        if quickLookExts.contains(ext) { return .apple }
        if let t = UTType(filenameExtension: ext) {
            let images = (CGImageSourceCopyTypeIdentifiers() as? [String]) ?? []
            if images.contains(where: { UTType($0).map { t.conforms(to: $0) } ?? false }) { return .reads }
            if AVURLAssetTypes.all.contains(where: { t.conforms(to: $0) }) { return .apple }
        }
        if let why = notYet[ext] { return .notYet(why) }
        return .notYet("Not supported yet.")
    }
}

enum AVURLAssetTypes { static let all: [UTType] = AVURLAsset.audiovisualTypes().compactMap { UTType($0.rawValue) } }
