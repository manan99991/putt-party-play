import Foundation

/// Kindle's "HUFF/CDIC" dictionary compression (Mobipocket huffdic), used by many AZW3/KF8 and older Kindle books:
/// a Huffman code table (HUFF) plus phrase dictionaries (CDIC) whose phrases can themselves be compressed. A port of
/// the well-known open decoder (calibre's HuffReader), so these books open instead of saying "can't unpack".
final class MobiHuff {
    private var dict1: [(len: Int, term: Bool, max: UInt64)] = []
    private var minCode: [UInt64] = [], maxCode: [UInt64] = []
    private var phrases: [(bytes: [UInt8], done: Bool)?] = []

    init?(huff h: [UInt8], cdics: [[UInt8]]) {
        func u32(_ b: [UInt8], _ o: Int) -> UInt64 { o + 4 <= b.count ? UInt64(b[o]) << 24 | UInt64(b[o + 1]) << 16 | UInt64(b[o + 2]) << 8 | UInt64(b[o + 3]) : 0 }
        guard h.count >= 16, Array(h[0..<8]) == Array("HUFF".utf8) + [0, 0, 0, 0x18] else { return nil }
        let off1 = Int(u32(h, 8)), off2 = Int(u32(h, 12))
        guard off1 + 1024 <= h.count, off2 + 256 <= h.count else { return nil }
        for i in 0..<256 {
            let v = u32(h, off1 + i * 4)
            let len = Int(v & 0x1F), term = v & 0x80 != 0, mc = v >> 8
            guard len > 0 else { return nil }
            dict1.append((len, term, ((mc + 1) << UInt64(32 - len)) &- 1))
        }
        minCode = [0]; maxCode = [0]
        for c in 1...32 {
            minCode.append(u32(h, off2 + (c - 1) * 8) << UInt64(32 - c))
            maxCode.append(((u32(h, off2 + (c - 1) * 8 + 4) + 1) << UInt64(32 - c)) &- 1)
        }
        for c in cdics {
            guard c.count >= 16, Array(c[0..<8]) == Array("CDIC".utf8) + [0, 0, 0, 0x10] else { return nil }
            let total = Int(u32(c, 8)), bits = Int(u32(c, 12))
            let n = min(1 << min(bits, 20), total - phrases.count)
            guard n > 0 else { continue }
            for k in 0..<n {
                guard 16 + k * 2 + 2 <= c.count else { return nil }
                let off = Int(c[16 + k * 2]) << 8 | Int(c[17 + k * 2])
                guard 18 + off <= c.count else { return nil }
                let bl = Int(c[16 + off]) << 8 | Int(c[17 + off])
                let end = min(c.count, 18 + off + (bl & 0x7FFF))
                phrases.append((Array(c[18 + off..<end]), bl & 0x8000 != 0))
            }
        }
        guard !phrases.isEmpty else { return nil }
    }

    func unpack(_ input: [UInt8], depth: Int = 0) -> [UInt8] {
        guard depth < 32 else { return [] }
        var bitsLeft = input.count * 8
        let data = input + [UInt8](repeating: 0, count: 8)
        func q(_ p: Int) -> UInt64 { (0..<8).reduce(UInt64(0)) { $0 << 8 | UInt64(data[p + $1]) } }
        var pos = 0, x = q(0), n = 32
        var out: [UInt8] = []
        while true {
            if n <= 0 { pos += 4; guard pos + 8 <= data.count else { break }; x = q(pos); n += 32 }
            let code = (x >> UInt64(n)) & 0xFFFF_FFFF
            var (len, term, maxc) = dict1[Int(code >> 24)]
            if !term {
                while len < 32, code < minCode[len] { len += 1 }
                maxc = maxCode[len]
            }
            n -= len; bitsLeft -= len
            if bitsLeft < 0 { break }
            let r = Int((maxc &- code) >> UInt64(32 - len))
            guard r >= 0, r < phrases.count, let p = phrases[r] else { break }
            if p.done { out += p.bytes }
            else {
                phrases[r] = nil
                let s = unpack(p.bytes, depth: depth + 1)
                phrases[r] = (s, true)
                out += s
            }
        }
        return out
    }
}
