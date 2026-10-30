import Foundation
import Compression

/// Minimal, tolerant ZIP reader for the Office containers Word Finder indexes (docx / xlsx / pptx).
/// Walks the central directory (falls back to scanning local headers), inflates stored (0) and
/// deflate (8) entries with the Compression framework, and strips XML down to readable text.
/// Everything is bounds-checked and capped; a bad file yields an empty string, never a crash.
enum ZipText {

    // MARK: text from Office files

    /// Readable text for a .docx / .xlsx / .pptx (by extension), or "" when nothing is readable.
    static func text(of url: URL) -> String {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), data.count > 30 else { return "" }
        let entries = ZipText.entries(in: data)
        func file(_ name: String) -> String { entries.first { $0.name == name }.flatMap { inflate($0, in: data) }.flatMap { String(data: $0, encoding: .utf8) } ?? "" }
        switch url.pathExtension.lowercased() {
        case "docx":
            let xml = file("word/document.xml")
            let body = xml.replacingOccurrences(of: "</w:p>", with: "\n").replacingOccurrences(of: "<w:tab/>", with: "\t")
            return clean(strip(body))
        case "xlsx":
            var shared: [String] = []
            let ss = file("xl/sharedStrings.xml")
            for m in matches(#"<si>(.*?)</si>"#, in: ss) { shared.append(strip(m)) }
            var out = ""
            for e in entries where e.name.hasPrefix("xl/worksheets/") && e.name.hasSuffix(".xml") {
                guard let d = inflate(e, in: data), let sheet = String(data: d, encoding: .utf8) else { continue }
                for row in matches(#"<row[^>]*>(.*?)</row>"#, in: sheet) {
                    var cells: [String] = []
                    for cell in matches(#"(<c\b[^>]*?(?:/>|>.*?</c>))"#, in: row) {
                        if cell.contains("t=\"s\""), let v = matches(#"<v>(.*?)</v>"#, in: cell).first, let i = Int(v), shared.indices.contains(i) { cells.append(shared[i]) }
                        else if let t = matches(#"<t[^>]*>(.*?)</t>"#, in: cell).first { cells.append(unescape(t)) }
                        else if let v = matches(#"<v>(.*?)</v>"#, in: cell).first { cells.append(unescape(v)) }
                    }
                    if !cells.isEmpty { out += cells.joined(separator: "  ") + "\n" }
                }
                if out.count > 2_000_000 { break }
            }
            return clean(out)
        case "pptx":
            var out = ""
            for e in entries.sorted(by: { $0.name < $1.name }) where e.name.hasPrefix("ppt/slides/slide") && e.name.hasSuffix(".xml") {
                guard let d = inflate(e, in: data), let xml = String(data: d, encoding: .utf8) else { continue }
                out += clean(strip(xml.replacingOccurrences(of: "</a:p>", with: "\n"))) + "\n\n"
            }
            return clean(out)
        default:
            return ""
        }
    }

    // MARK: container

    struct Entry { let name: String; let method: Int; let compressedSize: Int; let uncompressedSize: Int; let localHeaderOffset: Int }

    private static func u16(_ d: Data, _ i: Int) -> Int { i + 2 <= d.count ? Int(d[d.startIndex + i]) | Int(d[d.startIndex + i + 1]) << 8 : 0 }
    private static func u32(_ d: Data, _ i: Int) -> Int { i + 4 <= d.count ? u16(d, i) | u16(d, i + 2) << 16 : 0 }

    static func entries(in d: Data) -> [Entry] {
        var out: [Entry] = []
        // End of central directory: signature 0x06054b50 within the last 64 KB.
        let n = d.count
        var eocd = -1
        var i = n - 22
        while i >= max(0, n - 66_000) { if u32(d, i) == 0x06054b50 { eocd = i; break }; i -= 1 }
        if eocd >= 0 {
            let count = u16(d, eocd + 10), cdOff = u32(d, eocd + 16)
            var p = cdOff
            for _ in 0..<min(count, 20_000) {
                guard p + 46 <= n, u32(d, p) == 0x02014b50 else { break }
                let method = u16(d, p + 10), csize = u32(d, p + 20), usize = u32(d, p + 24)
                let nameLen = u16(d, p + 28), extraLen = u16(d, p + 30), commentLen = u16(d, p + 32), lho = u32(d, p + 42)
                guard p + 46 + nameLen <= n else { break }
                let name = String(data: d.subdata(in: (d.startIndex + p + 46)..<(d.startIndex + p + 46 + nameLen)), encoding: .utf8) ?? ""
                out.append(Entry(name: name, method: method, compressedSize: csize, uncompressedSize: usize, localHeaderOffset: lho))
                p += 46 + nameLen + extraLen + commentLen
            }
            if !out.isEmpty { return out }
        }
        // Fallback: walk local headers from the start (only works when sizes are in the header).
        var p = 0
        while p + 30 <= n, u32(d, p) == 0x04034b50, out.count < 20_000 {
            let method = u16(d, p + 8), csize = u32(d, p + 18), usize = u32(d, p + 22), nameLen = u16(d, p + 26), extraLen = u16(d, p + 28)
            guard p + 30 + nameLen <= n else { break }
            let name = String(data: d.subdata(in: (d.startIndex + p + 30)..<(d.startIndex + p + 30 + nameLen)), encoding: .utf8) ?? ""
            out.append(Entry(name: name, method: method, compressedSize: csize, uncompressedSize: usize, localHeaderOffset: p))
            if csize == 0 { break }   // data descriptor in use — sizes unknown, stop safely
            p += 30 + nameLen + extraLen + csize
        }
        return out
    }

    /// Bytes of one entry (stored or deflate). Capped at 64 MB uncompressed.
    static func inflate(_ e: Entry, in d: Data) -> Data? {
        let p = e.localHeaderOffset, n = d.count
        guard p + 30 <= n, u32(d, p) == 0x04034b50 else { return nil }
        let nameLen = u16(d, p + 26), extraLen = u16(d, p + 28)
        let start = p + 30 + nameLen + extraLen
        guard start >= 0, start <= n, e.compressedSize >= 0, start + e.compressedSize <= n else { return nil }
        let src = d.subdata(in: (d.startIndex + start)..<(d.startIndex + start + e.compressedSize))
        switch e.method {
        case 0: return src
        case 8:
            let cap = min(64 * 1024 * 1024, max(e.uncompressedSize, src.count * 6 + 1024))
            guard cap > 0, !src.isEmpty else { return Data() }
            let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: cap); defer { dst.deallocate() }
            let got = src.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Int in
                guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(dst, cap, base, src.count, nil, COMPRESSION_ZLIB)   // raw deflate
            }
            return got > 0 ? Data(bytes: dst, count: got) : nil
        default: return nil
        }
    }

    // MARK: XML → text

    static func strip(_ xml: String) -> String {
        var s = xml.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        s = unescape(s)
        return s
    }
    static func unescape(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&apos;", with: "'")
        if t.contains("&#") {
            var guardCount = 0
            while let r = t.range(of: #"&#[xX]?[0-9A-Fa-f]{1,7};"#, options: .regularExpression), guardCount < 100_000 {
                guardCount += 1
                let body = t[r].dropFirst(2).dropLast()
                let isHex = body.first == "x" || body.first == "X"
                let num = isHex ? UInt32(body.dropFirst(), radix: 16) : UInt32(body, radix: 10)
                let ch = num.flatMap { UnicodeScalar($0) }.map { String(Character($0)) } ?? " "
                t.replaceSubrange(r, with: ch)
            }
        }
        return t.replacingOccurrences(of: "&amp;", with: "&")
    }
    /// Collapse runs of spaces/tabs, keep paragraph breaks, trim.
    static func clean(_ s: String) -> String {
        s.replacingOccurrences(of: #"[ \t\u{00A0}]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #" *\n *"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private static func matches(_ pattern: String, in s: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).prefix(50_000).compactMap { m in
            m.numberOfRanges > 1 && m.range(at: 1).location != NSNotFound ? ns.substring(with: m.range(at: 1)) : nil
        }
    }
}
