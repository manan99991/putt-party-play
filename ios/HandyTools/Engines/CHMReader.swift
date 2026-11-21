import Foundation

/// Windows help files (.chm): the pages inside are unpacked (Microsoft's LZX compression) and opened as a book,
/// chapter by chapter in the help file's own table of contents, with its pictures.
enum CHMReader {
    static let magic: [UInt8] = Array("ITSF".utf8)
    struct Entry { var section: Int; var offset: Int; var length: Int }

    // MARK: - The container

    private static func u32(_ b: [UInt8], _ o: Int) -> Int {
        guard o >= 0, o + 4 <= b.count else { return 0 }
        return Int(b[o]) | Int(b[o + 1]) << 8 | Int(b[o + 2]) << 16 | Int(b[o + 3]) << 24
    }
    private static func u64(_ b: [UInt8], _ o: Int) -> Int {
        guard o >= 0, o + 8 <= b.count else { return 0 }
        var v: UInt64 = 0
        for i in (0..<8).reversed() { v = v << 8 | UInt64(b[o + i]) }
        return v > UInt64(Int.max) ? Int.max : Int(v)
    }

    /// The file list: name → where it lives (section 0 is stored as-is, section 1 is LZX-compressed).
    static func directory(_ b: [UInt8]) -> (entries: [String: Entry], content: Int)? {
        guard b.count > 0x60, Array(b[0..<4]) == magic else { return nil }
        let version = u32(b, 4)
        let dirOffset = u64(b, 0x48), dirLength = u64(b, 0x50)
        guard dirOffset < b.count, dirLength <= b.count else { return nil }
        let content = version >= 3 ? u64(b, 0x58) : dirOffset + dirLength
        guard content <= b.count else { return nil }
        guard dirOffset + 0x54 <= b.count, Array(b[dirOffset..<dirOffset + 4]) == Array("ITSP".utf8) else { return nil }
        let headerLength = u32(b, dirOffset + 8), chunk = u32(b, dirOffset + 0x10), chunks = u32(b, dirOffset + 0x2C)
        guard chunk >= 0x20, chunk <= 1 << 20, chunks < 1 << 20 else { return nil }
        var entries: [String: Entry] = [:]
        for c in 0..<chunks {
            let s = dirOffset + headerLength + c * chunk
            guard s + chunk <= b.count else { break }
            guard Array(b[s..<s + 4]) == Array("PMGL".utf8) else { continue }
            var p = s + 0x14
            let end = s + chunk - min(chunk - 0x14, u32(b, s + 4))
            func encint() -> Int? {
                var v = 0
                while p < end { let c = b[p]; p += 1; v = v << 7 | Int(c & 0x7F); if c < 0x80 { return v }; if v > 1 << 48 { return nil } }
                return nil
            }
            while p < end {
                guard let n = encint(), p + n <= end else { break }
                let name = String(decoding: b[p..<p + n], as: UTF8.self); p += n
                guard let sec = encint(), let off = encint(), let len = encint() else { break }
                entries[name] = Entry(section: sec, offset: off, length: len)
            }
        }
        return entries.isEmpty ? nil : (entries, content)
    }

    /// Every file in the help file, unpacked. Nil if it isn't a help file or its compressed part can't be read.
    static func files(_ d: Data) -> [String: Data]? {
        let b = [UInt8](d)
        guard let dir = directory(b) else { return nil }
        let entries = dir.entries, content = dir.content
        func stored(_ name: String) -> ArraySlice<UInt8>? {
            guard let e = entries[name], e.section == 0, content + e.offset + e.length <= b.count else { return nil }
            return b[(content + e.offset)..<(content + e.offset + e.length)]
        }
        var unpacked: [UInt8] = []
        if entries.values.contains(where: { $0.section == 1 && $0.length > 0 }) {
            let base = "::DataSpace/Storage/MSCompressed/"
            guard let control = stored(base + "ControlData").map(Array.init), control.count >= 24,
                  Array(control[4..<8]) == Array("LZXC".utf8),
                  let table = stored(base + "Transform/{7FC28940-9D31-11D0-9B27-00A0C91E9C7C}/InstanceData/ResetTable").map(Array.init),
                  table.count >= 0x28,
                  let packed = entries[base + "Content"], content + packed.offset + packed.length <= b.count else { return nil }
            var reset = u32(control, 12), window = u32(control, 16)
            if u32(control, 8) == 2 { reset *= 0x8000; window *= 0x8000 }
            let count = u32(table, 4), headerLength = u32(table, 12)
            let total = u64(table, 16), frame = max(1, u64(table, 32))
            guard total <= 400 << 20, count > 0, headerLength + count * 8 <= table.count, frame == 0x8000 else { return nil }
            let windowBits = Int.bitWidth - window.leadingZeroBitCount - 1
            guard (15...21).contains(windowBits) else { return nil }
            let perReset = max(1, reset / frame)
            let start = content + packed.offset, end = start + packed.length
            unpacked.reserveCapacity(total)
            var g = 0
            while g < count, unpacked.count < total {
                let from = start + u64(table, headerLength + g * 8)
                guard from < end, let part = LZX.decode(b, from: from, to: end, count: min(perReset * frame, total - unpacked.count),
                                                        windowBits: windowBits, streamOffset: unpacked.count) else { return nil }
                unpacked += part
                g += perReset
            }
            guard unpacked.count == total else { return nil }
        }
        var out: [String: Data] = [:]
        for (name, e) in entries where !name.hasSuffix("/") && e.length > 0 {
            if e.section == 0, let s = stored(name) { out[name] = Data(s) }
            else if e.section == 1, e.offset + e.length <= unpacked.count { out[name] = Data(unpacked[e.offset..<(e.offset + e.length)]) }
        }
        return out
    }

    // MARK: - As a book

    static func book(_ url: URL) -> FileReaders.Book? {
        guard let d = try? Data(contentsOf: url, options: .alwaysMapped), let files = files(d) else { return nil }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("chm-\(UUID().uuidString.prefix(8))", isDirectory: true)
        var saved: [String: URL] = [:]   // lower-cased path → file on disk
        for (name, data) in files where name.hasPrefix("/") && !name.hasPrefix("/#") && !name.hasPrefix("/$") {
            let rel = String(name.dropFirst())
            guard !rel.split(separator: "/").contains(".."), !rel.isEmpty else { continue }
            let f = dir.appendingPathComponent(rel)
            try? FileManager.default.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
            if (try? data.write(to: f)) != nil { saved[rel.lowercased()] = f }
        }
        let system = files["/#SYSTEM"].map { [UInt8]($0) } ?? []
        func systemString(_ code: Int) -> String? {
            var p = 4
            while p + 4 <= system.count {
                let c = Int(system[p]) | Int(system[p + 1]) << 8, n = Int(system[p + 2]) | Int(system[p + 3]) << 8
                p += 4
                guard p + n <= system.count else { return nil }
                if c == code {
                    let s = String(decoding: system[p..<p + n].prefix { $0 != 0 }, as: UTF8.self).trimmingCharacters(in: .whitespaces)
                    return s.isEmpty ? nil : s
                }
                p += n
            }
            return nil
        }
        // The table of contents: the .hhc named in #SYSTEM, else any .hhc.
        let tocName = systemString(0).map { $0.lowercased() } ?? saved.keys.first { $0.hasSuffix(".hhc") }
        var order: [(title: String, path: String)] = []
        if let tocName, let tocURL = saved[tocName], let toc = FileReaders.textOf(tocURL) {
            for object in FileReaders.matches(#"<object[\s\S]*?</object>"#, in: toc) {
                guard let local = FileReaders.firstMatch(#"(?i)name="Local"\s+value="([^"]+)""#, in: object) else { continue }
                let title = FileReaders.firstMatch(#"(?i)name="Name"\s+value="([^"]*)""#, in: object) ?? ""
                order.append((title, local))
            }
        }
        if order.isEmpty {
            order = saved.keys.filter { $0.hasSuffix(".htm") || $0.hasSuffix(".html") }.sorted().map { ("", $0) }
        }
        var seen = Set<String>(), chapters: [FileReaders.Chapter] = []
        for (title, local) in order where chapters.count < 3000 {
            var path = (local.components(separatedBy: "#").first ?? local).replacingOccurrences(of: "\\", with: "/")
            if let r = path.range(of: "::/") { path = String(path[r.upperBound...]) }   // "other.chm::/page.htm" style
            path = (path.removingPercentEncoding ?? path).trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
            guard !seen.contains(path), let f = saved[path], let html = FileReaders.textOf(f) else { continue }
            seen.insert(path)
            let heading = title.isEmpty
                ? (FileReaders.firstMatch(#"<title[^>]*>([\s\S]*?)</title>"#, in: html).map(FileReaders.stripTags) ?? "Page \(chapters.count + 1)")
                : title
            let based = html.replacingOccurrences(of: "<head>", with: "<head><base href=\"\(f.deletingLastPathComponent().absoluteString)\">",
                                                  options: .caseInsensitive)
            chapters.append(FileReaders.Chapter(title: String(heading.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines),
                                                html: based.range(of: "<base href", options: .caseInsensitive) == nil
                                                    ? "<base href=\"\(f.deletingLastPathComponent().absoluteString)\">" + based : based))
        }
        guard !chapters.isEmpty else { return nil }
        return FileReaders.Book(title: systemString(3) ?? url.deletingPathExtension().lastPathComponent, author: "", chapters: chapters, baseDir: dir)
    }
}

/// Microsoft LZX, as used inside .chm (and .cab) files: an LZ77 window with Huffman-coded literals and matches,
/// three remembered offsets, verbatim / aligned / stored blocks, 32 KB frames realigned to 16 bits.
enum LZX {
    private static let extraBits: [Int] = (0..<51).map { $0 < 4 ? 0 : min(($0 - 2) / 2, 17) }
    private static let positionBase: [Int] = {
        var b = [0]
        for i in 0..<50 { b.append(b[i] + (1 << extraBits[i])) }
        return b
    }()
    private static let slots: [Int: Int] = [15: 30, 16: 32, 17: 34, 18: 36, 19: 38, 20: 42, 21: 50]

    /// A canonical Huffman code as a lookup table indexed by the next `bits` bits.
    struct Tree {
        var bits = 0
        var table: [UInt32] = []   // symbol << 8 | length; length 0 = no such code
        init?(_ lengths: [Int]) {
            bits = lengths.max() ?? 0
            guard bits > 0 else { return }          // an empty tree is allowed until something is read from it
            guard bits <= 16 else { return nil }
            table = [UInt32](repeating: 0, count: 1 << bits)
            var code = 0
            for len in 1...bits {
                for (sym, l) in lengths.enumerated() where l == len {
                    let lo = code << (bits - len), hi = (code + 1) << (bits - len)
                    guard hi <= table.count else { return nil }       // more codes than fit: not a valid tree
                    for i in lo..<hi { table[i] = UInt32(sym) << 8 | UInt32(len) }
                    code += 1
                }
                code <<= 1
            }
        }
    }

    struct Bits {
        let b: [UInt8]; var p: Int; let end: Int
        var buf: UInt64 = 0, n = 0
        mutating func ensure(_ k: Int) {
            while n < k {
                let lo = p < end ? UInt64(b[p]) : 0, hi = p + 1 < end ? UInt64(b[p + 1]) : 0
                p += 2; buf = buf << 16 | hi << 8 | lo; n += 16
            }
        }
        mutating func peek(_ k: Int) -> Int { ensure(k); return Int((buf >> UInt64(n - k)) & ((1 << UInt64(k)) - 1)) }
        mutating func drop(_ k: Int) { n -= k; buf &= n == 0 ? 0 : (1 << UInt64(n)) - 1 }
        mutating func read(_ k: Int) -> Int { guard k > 0 else { return 0 }; let v = peek(k); drop(k); return v }
        mutating func symbol(_ t: Tree) -> Int? {
            guard t.bits > 0 else { return nil }
            let e = t.table[peek(t.bits)], len = Int(e & 0xFF)
            guard len > 0 else { return nil }
            drop(len)
            return Int(e >> 8)
        }
    }

    /// Decodes `count` bytes starting at a reset point. `streamOffset` is where this part sits in the whole stream
    /// (for the x86 call-address translation some files use).
    static func decode(_ b: [UInt8], from: Int, to end: Int, count: Int, windowBits: Int, streamOffset: Int = 0) -> [UInt8]? {
        guard let positionSlots = slots[windowBits], count >= 0 else { return nil }
        let mainCount = 256 + positionSlots * 8
        var bits = Bits(b: b, p: from, end: end)
        var out: [UInt8] = []
        out.reserveCapacity(count)
        var mainLengths = [Int](repeating: 0, count: mainCount), lengthLengths = [Int](repeating: 0, count: 249)
        var r0 = 1, r1 = 1, r2 = 1
        var intelSize = 0, intelStarted = false
        if bits.read(1) == 1 { intelSize = bits.read(16) << 16 | bits.read(16) }
        var remaining = 0, type = 0, blockLength = 0
        var main = Tree([])!, length = Tree([])!, aligned = Tree([])!
        var frameEnd = 0x8000

        func readLengths(_ lens: inout [Int], _ first: Int, _ last: Int) -> Bool {
            var pre: [Int] = []
            for _ in 0..<20 { pre.append(bits.read(4)) }
            guard let tree = Tree(pre) else { return false }
            var x = first
            while x < last {
                guard let z = bits.symbol(tree) else { return false }
                switch z {
                case 17:
                    let run = bits.read(4) + 4
                    guard x + run <= last else { return false }
                    for _ in 0..<run { lens[x] = 0; x += 1 }
                case 18:
                    let run = bits.read(5) + 20
                    guard x + run <= last else { return false }
                    for _ in 0..<run { lens[x] = 0; x += 1 }
                case 19:
                    let run = bits.read(1) + 4
                    guard x + run <= last, let s = bits.symbol(tree) else { return false }
                    let v = ((lens[x] - s) % 17 + 17) % 17
                    for _ in 0..<run { lens[x] = v; x += 1 }
                default:
                    lens[x] = ((lens[x] - z) % 17 + 17) % 17; x += 1
                }
            }
            return true
        }

        while out.count < count {
            if remaining == 0 {
                if type == 3, blockLength & 1 == 1 { bits.p += 1 }          // stored block of odd length: one pad byte
                type = bits.read(3)
                blockLength = bits.read(16) << 8 | bits.read(8)
                remaining = blockLength
                guard remaining > 0 else { return nil }
                switch type {
                case 1, 2:
                    if type == 2 {
                        var a: [Int] = []
                        for _ in 0..<8 { a.append(bits.read(3)) }
                        guard let t = Tree(a) else { return nil }
                        aligned = t
                    }
                    guard readLengths(&mainLengths, 0, 256), readLengths(&mainLengths, 256, mainCount),
                          let m = Tree(mainLengths) else { return nil }
                    main = m
                    if mainLengths[0xE8] != 0 { intelStarted = true }
                    guard readLengths(&lengthLengths, 0, 249), let l = Tree(lengthLengths) else { return nil }
                    length = l
                case 3:
                    intelStarted = true
                    bits.ensure(16)
                    if bits.n > 16 { bits.p -= 2 }                         // align to the start of the next 16-bit word
                    bits.buf = 0; bits.n = 0
                    guard bits.p + 12 <= end else { return nil }
                    func le(_ o: Int) -> Int { Int(b[o]) | Int(b[o + 1]) << 8 | Int(b[o + 2]) << 16 | Int(b[o + 3]) << 24 }
                    r0 = le(bits.p); r1 = le(bits.p + 4); r2 = le(bits.p + 8); bits.p += 12
                default:
                    return nil
                }
            }
            let stop = min(frameEnd, count)
            while remaining > 0, out.count < stop {
                if type == 3 {
                    let k = min(remaining, stop - out.count)
                    guard bits.p + k <= end else { return nil }
                    out += b[bits.p..<(bits.p + k)]; bits.p += k; remaining -= k
                    continue
                }
                guard var m = bits.symbol(main) else { return nil }
                if m < 256 { out.append(UInt8(m)); remaining -= 1; continue }
                m -= 256
                var matchLength = m & 7
                if matchLength == 7 { guard let extra = bits.symbol(length) else { return nil }; matchLength += extra }
                matchLength += 2
                let slot = m >> 3
                var offset: Int
                switch slot {
                case 0: offset = r0
                case 1: offset = r1; r1 = r0; r0 = offset
                case 2: offset = r2; r2 = r0; r0 = offset
                default:
                    let extra = extraBits[slot]
                    offset = positionBase[slot] - 2
                    if type == 2 {
                        if extra > 3 {
                            offset += bits.read(extra - 3) << 3
                            guard let a = bits.symbol(aligned) else { return nil }
                            offset += a
                        } else if extra == 3 {
                            guard let a = bits.symbol(aligned) else { return nil }
                            offset += a
                        } else if extra > 0 {
                            offset += bits.read(extra)
                        } else {
                            offset = 1
                        }
                    } else {
                        offset = slot == 3 ? 1 : offset + bits.read(extra)
                    }
                    r2 = r1; r1 = r0; r0 = offset
                }
                let from = out.count - offset
                guard offset > 0, from >= 0, matchLength <= remaining else { return nil }
                for i in 0..<matchLength { out.append(out[from + i]) }
                remaining -= matchLength
            }
            if out.count >= stop {
                if type != 3 { bits.drop(bits.n & 15) }                      // each 32 KB frame ends on a 16-bit boundary
                frameEnd += 0x8000
            }
        }
        if out.count > count { out.removeLast(out.count - count) }
        if intelSize != 0, intelStarted { translateCalls(&out, streamOffset: streamOffset, fileSize: intelSize) }
        return out
    }

    /// Undoes the x86 CALL (E8) address rewriting, frame by frame, as the format specifies.
    private static func translateCalls(_ out: inout [UInt8], streamOffset: Int, fileSize: Int) {
        var frameStart = 0
        while frameStart < out.count {
            let frameIndex = (streamOffset + frameStart) / 0x8000
            let size = min(0x8000, out.count - frameStart)
            guard frameIndex < 32768 else { return }
            if size > 10 {
                var i = frameStart, curpos = streamOffset + frameStart
                let last = frameStart + size - 10
                while i < last {
                    if out[i] != 0xE8 { i += 1; curpos += 1; continue }
                    let raw = Int32(bitPattern: UInt32(out[i + 1]) | UInt32(out[i + 2]) << 8 | UInt32(out[i + 3]) << 16 | UInt32(out[i + 4]) << 24)
                    let abs = Int(raw)
                    if abs >= -curpos, abs < fileSize {
                        let rel = UInt32(truncatingIfNeeded: abs >= 0 ? abs - curpos : abs + fileSize)
                        out[i + 1] = UInt8(rel & 0xFF); out[i + 2] = UInt8(rel >> 8 & 0xFF)
                        out[i + 3] = UInt8(rel >> 16 & 0xFF); out[i + 4] = UInt8(rel >> 24)
                    }
                    i += 5; curpos += 5
                }
            }
            frameStart += 0x8000
        }
    }
}
