import Foundation
import Compression

/// Bundle files into one standard .zip on device — opens in Files, Windows, macOS, Gmail and any unzip
/// app. Each file is DEFLATE-compressed (Apple's Compression framework, raw deflate as ZIP method 8), or
/// stored as-is when compressing wouldn't help (photos, videos, already-zipped files). Names are UTF-8
/// and de-duplicated. Classic ZIP limits apply (under 4 GB, under 65,535 files) and are checked up front.
enum ZipWriter {
    struct Item { var name: String; var data: Data }

    enum Failure: Error, Equatable {
        case empty, tooBig, cannotWrite
        var message: String {
            switch self {
            case .empty: return "Add at least one file."
            case .tooBig: return "That's too much for one zip on a phone (keep it under 2 GB)."
            case .cannotWrite: return "Couldn't save the zip — try again."
            }
        }
    }

    static let maxTotalBytes = 2_000_000_000

    /// Build the archive bytes. `progress` reports 0…1 per file.
    /// `keepPaths`: keep "folder/file" names as real folders (Office files need "xl/workbook.xml");
    /// off for user files, where a slash in a name must not create a folder.
    static func zip(_ items: [Item], keepPaths: Bool = false, progress: ((Double) -> Void)? = nil) -> Result<Data, Failure> {
        guard !items.isEmpty else { return .failure(.empty) }
        guard items.count < 65_535, items.reduce(0, { $0 + $1.data.count }) < maxTotalBytes else { return .failure(.tooBig) }
        let names = keepPaths ? items.map(\.name) : uniqueNames(items.map(\.name))
        let (time, date) = dosStamp(Date())
        var out = Data()
        var central = Data()
        for (i, item) in items.enumerated() {
            let nameBytes = Data(names[i].utf8)
            let crc = crc32(item.data)
            let packed = deflate(item.data)
            let method: UInt16 = packed == nil ? 0 : 8
            let body = packed ?? item.data
            let offset = out.count
            guard offset < Int(UInt32.max) else { return .failure(.tooBig) }

            out += le32(0x04034b50); out += le16(20); out += le16(0x0800); out += le16(method)
            out += le16(time); out += le16(date); out += le32(crc)
            out += le32(UInt32(body.count)); out += le32(UInt32(item.data.count))
            out += le16(UInt16(nameBytes.count)); out += le16(0)
            out += nameBytes; out += body

            central += le32(0x02014b50); central += le16(20); central += le16(20); central += le16(0x0800)
            central += le16(method); central += le16(time); central += le16(date); central += le32(crc)
            central += le32(UInt32(body.count)); central += le32(UInt32(item.data.count))
            central += le16(UInt16(nameBytes.count)); central += le16(0); central += le16(0)
            central += le16(0); central += le16(0); central += le32(0); central += le32(UInt32(offset))
            central += nameBytes
            progress?(Double(i + 1) / Double(items.count))
        }
        let cdOffset = out.count
        out += central
        out += le32(0x06054b50); out += le16(0); out += le16(0)
        out += le16(UInt16(items.count)); out += le16(UInt16(items.count))
        out += le32(UInt32(central.count)); out += le32(UInt32(cdOffset)); out += le16(0)
        return .success(out)
    }

    /// "photo.jpg", "photo.jpg" → "photo.jpg", "photo (2).jpg". Slashes become dashes (no folders).
    static func uniqueNames(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        return raw.map { r in
            var base = r.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: "\\", with: "-")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if base.isEmpty { base = "file" }
            var name = base, n = 2
            let ext = (base as NSString).pathExtension, stem = (base as NSString).deletingPathExtension
            while seen.contains(name.lowercased()) {
                name = ext.isEmpty ? "\(stem) (\(n))" : "\(stem) (\(n)).\(ext)"; n += 1
            }
            seen.insert(name.lowercased())
            return name
        }
    }

    // MARK: - Pieces

    /// Raw DEFLATE, or nil when it wouldn't make the file smaller (then it's stored).
    private static func deflate(_ src: Data) -> Data? {
        guard src.count > 64 else { return nil }
        let cap = src.count + 1024
        var dst = [UInt8](repeating: 0, count: cap)
        let n = src.withUnsafeBytes { raw -> Int in
            guard let sp = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return dst.withUnsafeMutableBufferPointer { dp in
                compression_encode_buffer(dp.baseAddress!, cap, sp, src.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard n > 0, n < src.count - src.count / 50 else { return nil }   // must save at least 2%
        return Data(dst[0..<n])
    }

    private static let crcTable: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        data.withUnsafeBytes { raw in
            for b in raw.bindMemory(to: UInt8.self) { c = crcTable[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        }
        return c ^ 0xFFFFFFFF
    }

    private static func dosStamp(_ d: Date) -> (UInt16, UInt16) {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: d)
        let time = UInt16(((c.hour ?? 0) << 11) | ((c.minute ?? 0) << 5) | ((c.second ?? 0) / 2))
        let date = UInt16((max(0, (c.year ?? 1980) - 1980) << 9) | ((c.month ?? 1) << 5) | (c.day ?? 1))
        return (time, date)
    }

    private static func le16(_ v: UInt16) -> Data { Data([UInt8(v & 0xFF), UInt8(v >> 8)]) }
    private static func le32(_ v: UInt32) -> Data {
        Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8(v >> 24)])
    }
}
