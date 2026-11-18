import UIKit
import AVFoundation

/// Read and write a song's title, artist, album and cover art, on device.
/// - MP3: rewrites the ID3v2.3 tag at the front of the file; the audio bytes are copied untouched.
/// - M4A / M4R / AAC / MP4 audio: re-wraps the audio (no re-encode, no quality loss) with iTunes tags.
/// - Anything else (WAV, AIFF, CAF): converted to M4A first, since those formats carry no standard tags.
enum AudioTags {
    struct Tags: Equatable {
        var title = ""
        var artist = ""
        var album = ""
        var artwork: Data?      // JPEG
    }

    enum Failure: Error, Equatable {
        case cannotRead, cannotWrite
        var message: String {
            switch self {
            case .cannotRead: return "Tenzy couldn't read that audio file."
            case .cannotWrite: return "This phone couldn't save the tagged file — try again."
            }
        }
    }

    /// Which way a file will be written — so the screen can be honest before saving.
    enum Route { case id3, mp4, convert }
    static func route(for url: URL) -> Route {
        switch url.pathExtension.lowercased() {
        case "mp3": return .id3
        case "m4a", "m4r", "m4b", "aac": return .mp4
        default: return .convert
        }
    }

    // MARK: - Read

    static func read(_ url: URL) async -> Tags {
        if route(for: url) == .id3, let data = try? Data(contentsOf: url), let t = ID3.parse(data) { return t }
        var t = Tags()
        let items = (try? await AVURLAsset(url: url).load(.commonMetadata)) ?? []
        for item in items {
            switch item.commonKey {
            case .commonKeyTitle?: t.title = (try? await item.load(.stringValue)) ?? t.title
            case .commonKeyArtist?: t.artist = (try? await item.load(.stringValue)) ?? t.artist
            case .commonKeyAlbumName?: t.album = (try? await item.load(.stringValue)) ?? t.album
            case .commonKeyArtwork?: t.artwork = (try? await item.load(.dataValue)) ?? t.artwork
            default: break
            }
        }
        return t
    }

    // MARK: - Write

    static func write(_ src: URL, tags: Tags) async -> Result<URL, Failure> {
        switch route(for: src) {
        case .id3:
            guard let data = try? Data(contentsOf: src) else { return .failure(.cannotRead) }
            let out = VideoEngine.tempURL("mp3")
            guard (try? ID3.retag(data, with: tags).write(to: out)) != nil else { return .failure(.cannotWrite) }
            return .success(out)
        case .mp4:
            return await wrapMP4(src, tags: tags)
        case .convert:
            guard case .success(let m4a) = await AudioConvert.convert(src, to: .m4a) else { return .failure(.cannotRead) }
            defer { try? FileManager.default.removeItem(at: m4a) }
            return await wrapMP4(m4a, tags: tags)
        }
    }

    private static func wrapMP4(_ src: URL, tags: Tags) async -> Result<URL, Failure> {
        let asset = AVURLAsset(url: src)
        guard (try? await asset.loadTracks(withMediaType: .audio).first) != nil else { return .failure(.cannotRead) }
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            return .failure(.cannotWrite)
        }
        let out = VideoEngine.tempURL("m4a")
        session.outputURL = out
        session.outputFileType = .m4a
        session.metadata = metadataItems(tags)
        await session.export()
        guard session.status == .completed else {
            try? FileManager.default.removeItem(at: out)
            return .failure(.cannotWrite)
        }
        return .success(out)
    }

    static func metadataItems(_ t: Tags) -> [AVMetadataItem] {
        var items: [AVMetadataItem] = []
        func add(_ id: AVMetadataIdentifier, _ value: (NSCopying & NSObjectProtocol)?, dataType: String? = nil) {
            guard let value else { return }
            let m = AVMutableMetadataItem()
            m.identifier = id
            m.value = value
            if let dataType { m.dataType = dataType }
            m.extendedLanguageTag = "und"
            items.append(m)
        }
        if !t.title.isEmpty { add(.commonIdentifierTitle, t.title as NSString) }
        if !t.artist.isEmpty { add(.commonIdentifierArtist, t.artist as NSString) }
        if !t.album.isEmpty { add(.commonIdentifierAlbumName, t.album as NSString) }
        if let art = t.artwork { add(.commonIdentifierArtwork, art as NSData, dataType: kCMMetadataBaseDataType_JPEG as String) }
        return items
    }

    /// Square, JPEG cover art at a size every player accepts (max 1000 px).
    static func coverJPEG(from image: UIImage) -> Data? {
        let side = min(1000, min(image.size.width, image.size.height) * image.scale)
        guard side > 1 else { return nil }
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        let square = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: f).image { _ in
            let s = image.size, k = max(side / s.width, side / s.height)
            let w = s.width * k, h = s.height * k
            image.draw(in: CGRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h))
        }
        return square.jpegData(compressionQuality: 0.85)
    }
}

/// A small, dependency-free ID3v2.3 writer/reader for MP3 title, artist, album and cover art.
enum ID3 {
    /// Bytes of an existing ID3v2 tag at the front of `data` (0 if none).
    static func tagLength(_ data: Data) -> Int {
        let b = [UInt8](data.prefix(10))
        guard b.count == 10, b[0] == 0x49, b[1] == 0x44, b[2] == 0x33 else { return 0 }   // "ID3"
        let size = (Int(b[6] & 0x7F) << 21) | (Int(b[7] & 0x7F) << 14) | (Int(b[8] & 0x7F) << 7) | Int(b[9] & 0x7F)
        let footer = (b[5] & 0x10) != 0 ? 10 : 0
        return min(data.count, 10 + size + footer)
    }

    /// A new tag for `tags` followed by `data`'s audio, with any old ID3v2 tag removed.
    static func retag(_ data: Data, with tags: AudioTags.Tags) -> Data {
        let audio = data.subdata(in: tagLength(data)..<data.count)
        var frames = Data()
        frames += textFrame("TIT2", tags.title)
        frames += textFrame("TPE1", tags.artist)
        frames += textFrame("TALB", tags.album)
        if let art = tags.artwork, !art.isEmpty {
            var body = Data([0x00])                                   // ISO-8859-1 strings below
            body += Data("image/jpeg".utf8) + Data([0x00])
            body += Data([0x03])                                      // front cover
            body += Data([0x00])                                      // empty description
            body += art
            frames += frame("APIC", body)
        }
        guard !frames.isEmpty else { return audio }
        var out = Data([0x49, 0x44, 0x33, 0x03, 0x00, 0x00])          // "ID3" v2.3, no flags
        out += syncsafe(frames.count)
        out += frames
        out += audio
        return out
    }

    /// Read back title / artist / album / cover from an ID3v2.3 or v2.4 tag.
    static func parse(_ data: Data) -> AudioTags.Tags? {
        let total = tagLength(data)
        guard total > 10 else { return nil }
        let b = [UInt8](data.prefix(total))
        let v4 = b[3] == 4
        var t = AudioTags.Tags()
        var i = 10
        while i + 10 <= total {
            let id = String(bytes: b[i..<i + 4], encoding: .ascii) ?? ""
            guard id.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }), id != "\0\0\0\0" else { break }
            let raw = (Int(b[i + 4]) << 24) | (Int(b[i + 5]) << 16) | (Int(b[i + 6]) << 8) | Int(b[i + 7])
            let size = v4 ? ((raw & 0x7F000000) >> 3 | (raw & 0x7F0000) >> 2 | (raw & 0x7F00) >> 1 | (raw & 0x7F)) : raw
            let start = i + 10, end = min(total, start + size)
            guard size > 0, start < end else { break }
            let body = Data(b[start..<end])
            switch id {
            case "TIT2": t.title = text(body)
            case "TPE1": t.artist = text(body)
            case "TALB": t.album = text(body)
            case "APIC": t.artwork = picture(body)
            default: break
            }
            i = end
        }
        return t
    }

    // MARK: helpers

    private static func frame(_ id: String, _ body: Data) -> Data {
        var d = Data(id.utf8)
        let n = body.count
        d += Data([UInt8((n >> 24) & 0xFF), UInt8((n >> 16) & 0xFF), UInt8((n >> 8) & 0xFF), UInt8(n & 0xFF)])
        d += Data([0x00, 0x00])
        d += body
        return d
    }

    private static func textFrame(_ id: String, _ s: String) -> Data {
        let v = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty else { return Data() }
        var body = Data([0x01, 0xFF, 0xFE])                            // UTF-16 with little-endian BOM
        for u in v.utf16 { body += Data([UInt8(u & 0xFF), UInt8(u >> 8)]) }
        body += Data([0x00, 0x00])
        return frame(id, body)
    }

    private static func syncsafe(_ n: Int) -> Data {
        Data([UInt8((n >> 21) & 0x7F), UInt8((n >> 14) & 0x7F), UInt8((n >> 7) & 0x7F), UInt8(n & 0x7F)])
    }

    private static func text(_ body: Data) -> String {
        guard let enc = body.first else { return "" }
        var rest = body.dropFirst()
        let s: String?
        switch enc {
        case 0x01, 0x02:
            if enc == 0x01, rest.count >= 2 {
                let bom = (rest[rest.startIndex], rest[rest.startIndex + 1])
                rest = rest.dropFirst(2)
                s = String(data: Data(rest), encoding: bom == (0xFE, 0xFF) ? .utf16BigEndian : .utf16LittleEndian)
            } else {
                s = String(data: Data(rest), encoding: .utf16BigEndian)
            }
        case 0x03: s = String(data: Data(rest), encoding: .utf8)
        default: s = String(data: Data(rest), encoding: .isoLatin1)
        }
        return (s ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "\0").union(.whitespacesAndNewlines))
    }

    private static func picture(_ body: Data) -> Data? {
        let b = [UInt8](body)
        guard b.count > 4 else { return nil }
        let utf16 = b[0] == 0x01 || b[0] == 0x02
        var i = 1
        while i < b.count, b[i] != 0 { i += 1 }                         // MIME (always Latin-1)
        i += 2                                                          // NUL + picture type
        if utf16 {                                                      // description, double-NUL ended
            while i + 1 < b.count, !(b[i] == 0 && b[i + 1] == 0) { i += 2 }
            i += 2
        } else {
            while i < b.count, b[i] != 0 { i += 1 }
            i += 1
        }
        return i < b.count ? Data(b[i...]) : nil
    }
}
