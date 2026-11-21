import Foundation

/// Outlook's own mail files, read on the phone: a saved message (.msg — a Microsoft "compound file") and the
/// winmail.dat that Outlook attaches instead of the real attachments (TNEF). Both come back as an ordinary email:
/// from, to, subject, date, the text (or HTML) and every attachment, each one openable.
enum OfficeMail {

    // MARK: - Compound file (the container .msg, old .doc/.xls and Thumbs.db all use)

    struct Compound {
        struct Entry { let name: String; let type: UInt8; let left: Int; let right: Int; let child: Int; let start: Int; let size: Int }
        let bytes: [UInt8]
        let sectorSize: Int
        let miniSectorSize: Int
        let miniCutoff: Int
        let fat: [UInt32]
        let miniFAT: [UInt32]
        let entries: [Entry]
        let miniStream: [UInt8]

        static let magic: [UInt8] = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]
        private static let end: UInt32 = 0xFFFF_FFFE

        init?(_ data: Data) {
            let b = [UInt8](data)
            guard b.count >= 512, Array(b[0..<8]) == Self.magic else { return nil }
            func u16(_ o: Int) -> Int { Int(b[o]) | Int(b[o + 1]) << 8 }
            func u32(_ o: Int) -> UInt32 { UInt32(b[o]) | UInt32(b[o + 1]) << 8 | UInt32(b[o + 2]) << 16 | UInt32(b[o + 3]) << 24 }
            let shift = u16(0x1E), miniShift = u16(0x20)
            guard (9...12).contains(shift), miniShift < shift else { return nil }
            let ss = 1 << shift
            bytes = b; sectorSize = ss; miniSectorSize = 1 << miniShift; miniCutoff = Int(u32(0x38))
            func sector(_ n: UInt32) -> ArraySlice<UInt8>? {
                let o = (Int(n) + 1) * ss
                guard n < 0xFFFF_FFFA, o >= 0, o + ss <= b.count else { return nil }
                return b[o..<o + ss]
            }
            func words(_ s: ArraySlice<UInt8>) -> [UInt32] {
                stride(from: s.startIndex, to: s.endIndex, by: 4).map { UInt32(b[$0]) | UInt32(b[$0 + 1]) << 8 | UInt32(b[$0 + 2]) << 16 | UInt32(b[$0 + 3]) << 24 }
            }
            // The FAT's own sectors: 109 listed in the header, the rest in a chain of DIFAT sectors.
            var fatSectors = (0..<109).map { u32(0x4C + $0 * 4) }.filter { $0 < 0xFFFF_FFFA }
            var difat = u32(0x44), guardCount = 0
            while difat < 0xFFFF_FFFA, let s = sector(difat), guardCount < 10_000 {
                let w = words(s); fatSectors += w.dropLast().filter { $0 < 0xFFFF_FFFA }; difat = w.last ?? Self.end; guardCount += 1
            }
            var fat: [UInt32] = []
            for n in fatSectors { guard let s = sector(n) else { return nil }; fat += words(s) }
            self.fat = fat
            func chain(_ start: UInt32, in table: [UInt32]) -> [UInt32] {
                var out: [UInt32] = [], n = start, seen = Set<UInt32>()
                while n < 0xFFFF_FFFA, Int(n) < table.count, !seen.contains(n) { out.append(n); seen.insert(n); n = table[Int(n)] }
                return out
            }
            func read(_ start: UInt32) -> [UInt8] { chain(start, in: fat).flatMap { sector($0).map(Array.init) ?? [] } }
            // Directory: 128-byte entries.
            let dir = read(u32(0x30))
            var entries: [Entry] = []
            for o in stride(from: 0, to: dir.count - 127, by: 128) {
                let nameLen = max(0, min(64, Int(dir[o + 64]) | Int(dir[o + 65]) << 8) - 2)
                let name = String(decoding: stride(from: o, to: o + nameLen, by: 2).map { UInt16(dir[$0]) | UInt16(dir[$0 + 1]) << 8 }, as: UTF16.self)
                func d32(_ p: Int) -> Int { Int(UInt32(dir[o + p]) | UInt32(dir[o + p + 1]) << 8 | UInt32(dir[o + p + 2]) << 16 | UInt32(dir[o + p + 3]) << 24) }
                entries.append(Entry(name: name, type: dir[o + 66], left: d32(68), right: d32(72), child: d32(76), start: d32(116), size: d32(120)))
            }
            guard let root = entries.first, root.type == 5 else { return nil }
            self.entries = entries
            miniFAT = chain(u32(0x3C), in: fat).flatMap { sector($0).map(words) ?? [] }
            miniStream = Array(read(UInt32(truncatingIfNeeded: root.start)).prefix(root.size))
        }

        /// The entries directly inside a storage (walks its red-black tree of children).
        func children(of index: Int) -> [Int] {
            var out: [Int] = [], stack = [entries[index].child], seen = Set<Int>()
            while let i = stack.popLast() {
                guard i >= 0, i < entries.count, i != 0xFFFF_FFFF, !seen.contains(i) else { continue }
                seen.insert(i); out.append(i); stack.append(entries[i].left); stack.append(entries[i].right)
            }
            return out
        }
        func child(_ name: String, of index: Int) -> Int? { children(of: index).first { entries[$0].name.lowercased() == name.lowercased() } }

        /// A stream's bytes: small ones live in the mini stream, the rest in ordinary sectors.
        func stream(_ index: Int) -> Data {
            let e = entries[index]
            guard e.type == 2, e.size > 0 else { return Data() }
            var out: [UInt8] = []
            if e.size < miniCutoff {
                var n = UInt32(truncatingIfNeeded: e.start), seen = Set<UInt32>()
                while n < 0xFFFF_FFFA, Int(n) < miniFAT.count, !seen.contains(n), out.count < e.size {
                    seen.insert(n)
                    let o = Int(n) * miniSectorSize
                    if o + miniSectorSize <= miniStream.count { out += miniStream[o..<o + miniSectorSize] } else if o < miniStream.count { out += miniStream[o...] }
                    n = miniFAT[Int(n)]
                }
            } else {
                var n = UInt32(truncatingIfNeeded: e.start), seen = Set<UInt32>()
                while n < 0xFFFF_FFFA, Int(n) < fat.count, !seen.contains(n), out.count < e.size {
                    seen.insert(n)
                    let o = (Int(n) + 1) * sectorSize
                    if o + sectorSize <= bytes.count { out += bytes[o..<o + sectorSize] }
                    n = fat[Int(n)]
                }
            }
            return Data(out.prefix(e.size))
        }
    }

    // MARK: - .msg

    /// A saved Outlook message, or nil if it isn't one.
    static func msg(_ data: Data) -> FileReaders.Email? {
        guard let cf = Compound(data), cf.child("__substg1.0_0037001F", of: 0) != nil || cf.child("__substg1.0_0037001E", of: 0) != nil
                || cf.child("__substg1.0_1000001F", of: 0) != nil || cf.child("__substg1.0_1000001E", of: 0) != nil else { return nil }
        func prop(_ tag: String, in storage: Int = 0) -> String? {
            if let i = cf.child("__substg1.0_\(tag)001F", of: storage) {
                let s = String(data: cf.stream(i), encoding: .utf16LittleEndian)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
                if let s, !s.isEmpty { return s }
            }
            if let i = cf.child("__substg1.0_\(tag)001E", of: storage) {
                let d = cf.stream(i)
                let s = (String(data: d, encoding: .utf8) ?? String(data: d, encoding: .windowsCP1252))?.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
                if let s, !s.isEmpty { return s }
            }
            return nil
        }
        func binary(_ tag: String, in storage: Int = 0) -> Data? { cf.child("__substg1.0_\(tag)0102", of: storage).map(cf.stream) }

        let fromName = prop("0C1A") ?? prop("0042") ?? ""
        let fromAddr = prop("5D01") ?? prop("0C1F") ?? prop("0065") ?? ""
        let from = fromAddr.isEmpty || fromAddr == fromName ? fromName : (fromName.isEmpty ? fromAddr : "\(fromName) <\(fromAddr)>")
        var html = prop("1013")
        if html == nil, let d = binary("1013") { html = String(data: d, encoding: .utf8) ?? String(data: d, encoding: .windowsCP1252) }
        let text = prop("1000") ?? html.map(FileReaders.stripTags) ?? ""

        var attachments: [(name: String, data: Data)] = []
        for i in cf.children(of: 0) where cf.entries[i].type == 1 && cf.entries[i].name.hasPrefix("__attach_version1.0_") {
            guard let d = binary("3701", in: i) else {
                // An attached email is a storage of its own; say so rather than drop it.
                if cf.child("__substg1.0_3701000D", of: i) != nil { attachments.append(("\(prop("3001", in: i) ?? "Attached message").txt", Data("This attachment is another email inside the message.".utf8))) }
                continue
            }
            let name = prop("3707", in: i) ?? prop("3704", in: i) ?? prop("3001", in: i) ?? "Attachment \(attachments.count + 1)"
            attachments.append((name, d))
        }
        return FileReaders.Email(from: from, to: prop("0E04") ?? "", cc: prop("0E03") ?? "", subject: prop("0037") ?? "",
                                 date: submitTime(cf).map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "",
                                 html: html, text: text, attachments: attachments)
    }

    /// When it was sent, from the message's fixed-size property table (PR_CLIENT_SUBMIT_TIME, else delivery time).
    static func submitTime(_ cf: Compound) -> Date? {
        guard let i = cf.child("__properties_version1.0", of: 0) else { return nil }
        let b = [UInt8](cf.stream(i))
        var found: [UInt32: UInt64] = [:]
        var o = 32   // the top-level header
        while o + 16 <= b.count {
            let tag = UInt32(b[o]) | UInt32(b[o + 1]) << 8 | UInt32(b[o + 2]) << 16 | UInt32(b[o + 3]) << 24
            var v: UInt64 = 0
            for k in 0..<8 { v |= UInt64(b[o + 8 + k]) << (8 * k) }
            found[tag] = v
            o += 16
        }
        guard let ft = found[0x0039_0040] ?? found[0x0E06_0040], ft > 0 else { return nil }
        return fileTime(ft)
    }

    static func fileTime(_ v: UInt64) -> Date { Date(timeIntervalSince1970: Double(v) / 10_000_000 - 11_644_473_600) }

    // MARK: - winmail.dat (TNEF)

    static let tnefMagic: [UInt8] = [0x78, 0x9F, 0x3E, 0x22]

    /// What Outlook packed into winmail.dat: its subject and text when present, and every attachment with its name.
    static func tnef(_ data: Data) -> FileReaders.Email? {
        let b = [UInt8](data)
        guard b.count > 6, Array(b[0..<4]) == tnefMagic else { return nil }
        func u32(_ o: Int) -> Int { Int(UInt32(b[o]) | UInt32(b[o + 1]) << 8 | UInt32(b[o + 2]) << 16 | UInt32(b[o + 3]) << 24) }
        var p = 6, subject = "", body = "", attachments: [(name: String, data: Data)] = []
        var name: String?, payload: Data?
        func flush() { if let payload { attachments.append((name ?? "Attachment \(attachments.count + 1)", payload)) }; name = nil; payload = nil }
        func cstr(_ s: ArraySlice<UInt8>) -> String {
            let raw = Array(s.prefix { $0 != 0 })
            return String(bytes: raw, encoding: .utf8) ?? String(bytes: raw, encoding: .windowsCP1252) ?? ""
        }
        while p + 9 <= b.count {
            let level = b[p], id = u32(p + 1), len = u32(p + 5)
            let start = p + 9, end = start + len
            guard len >= 0, end + 2 <= b.count else { break }
            let value = b[start..<end]
            switch (level, id) {
            case (1, 0x0001_8004): subject = cstr(value)                         // attSubject
            case (1, 0x0002_800C): body = cstr(value)                            // attBody
            case (2, 0x0006_9002): flush(); payload = nil                        // attAttachRendData: a new attachment starts
            case (2, 0x0001_8010): name = cstr(value)                            // attAttachTitle (8.3 or full name)
            case (2, 0x0006_800F): payload = Data(value)                         // attAttachData
            case (2, 0x0006_9005): if let long = longName(Array(value)) { name = long }   // attAttachment: MAPI props, the long file name
            default: break
            }
            p = end + 2   // the 2-byte checksum
        }
        flush()
        guard !attachments.isEmpty || !subject.isEmpty || !body.isEmpty else { return nil }
        return FileReaders.Email(from: "", to: "", cc: "", subject: subject.isEmpty ? "Outlook attachments (winmail.dat)" : subject,
                                 date: "", html: nil, text: body.isEmpty ? "Outlook sent these as winmail.dat. Here they are, one by one." : body,
                                 attachments: attachments)
    }

    /// PR_ATTACH_LONG_FILENAME (0x3707) from a TNEF MAPI property block.
    static func longName(_ b: [UInt8]) -> String? {
        func u32(_ o: Int) -> Int { o + 4 <= b.count ? Int(UInt32(b[o]) | UInt32(b[o + 1]) << 8 | UInt32(b[o + 2]) << 16 | UInt32(b[o + 3]) << 24) : -1 }
        func pad(_ n: Int) -> Int { (n + 3) & ~3 }
        let count = u32(0); var p = 4
        guard count > 0, count < 10_000 else { return nil }
        for _ in 0..<count {
            guard p + 4 <= b.count else { return nil }
            let type = Int(b[p]) | Int(b[p + 1]) << 8, id = Int(b[p + 2]) | Int(b[p + 3]) << 8
            p += 4
            if id >= 0x8000 {   // a named property: GUID, kind, then an id or a name
                p += 16; let kind = u32(p); p += 4
                if kind == 0 { p += 4 } else { let n = u32(p); p += 4 + pad(max(0, n)) }
            }
            let multi = type & 0x1000 != 0, base = type & 0x0FFF
            let values = multi ? max(0, u32(p)) : 1
            if multi { p += 4 }
            for _ in 0..<values {
                switch base {
                case 0x1E, 0x1F, 0x0102, 0x0D:
                    if !multi { p += 4 }   // a value count of 1 precedes single variable-length values
                    let n = u32(p); p += 4
                    guard n >= 0, p + n <= b.count else { return nil }
                    if id == 0x3707, base == 0x1F { return String(bytes: b[p..<p + n], encoding: .utf16LittleEndian)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0")) }
                    if id == 0x3707, base == 0x1E { return String(bytes: b[p..<p + n].prefix { $0 != 0 }, encoding: .windowsCP1252) }
                    p += pad(n)
                case 0x02, 0x03, 0x04, 0x0A, 0x0B: p += 4
                case 0x05, 0x06, 0x07, 0x14, 0x40: p += 8
                case 0x48: p += 16
                default: return nil
                }
            }
        }
        return nil
    }
}
