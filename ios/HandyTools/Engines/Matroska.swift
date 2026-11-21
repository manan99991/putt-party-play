import Foundation
import AVFoundation
import CoreMedia

/// Matroska (.mkv / .mka) and WebM (.webm) made playable on iPhone, without re-encoding anything:
/// - H.264 / HEVC video with AAC, MP3, AC-3 or E-AC-3 sound is moved, frame for frame, into an MP4 the phone's own
///   player opens (same picture, same sound, seconds even for a long film).
/// - VP8 / VP9 / AV1 video with Opus or Vorbis sound is what WebM is made of, so the file is played by the system web
///   engine, which decodes those; an .mkv holding them only needs its label changed from "matroska" to "webm".
enum Matroska {
    struct Track {
        var number = 0, type = 0, codec = "", priv = Data(), width = 0, height = 0
        var rate = 8000.0, channels = 1, defaultDuration: UInt64 = 0, encoded = false
    }
    /// One coded frame: where its bytes are in the file and when it shows (nanoseconds).
    struct Frame { var track: Int; var ns: Int64; var key: Bool; var offset: Int; var size: Int }
    struct Movie { var docType: String; var docTypeAt: Int?; var docTypeLen: Int; var tracks: [Track]; var frames: [Frame] }

    static let magic: [UInt8] = [0x1A, 0x45, 0xDF, 0xA3]
    static let webVideo: Set<String> = ["V_VP8", "V_VP9", "V_AV1"]
    static let webAudio: Set<String> = ["A_OPUS", "A_VORBIS"]
    static let mp4Video: [String: CMVideoCodecType] = ["V_MPEG4/ISO/AVC": kCMVideoCodecType_H264, "V_MPEGH/ISO/HEVC": kCMVideoCodecType_HEVC]
    static let mp4Audio: [String: AudioFormatID] = ["A_MPEG/L3": kAudioFormatMPEGLayer3, "A_AC3": kAudioFormatAC3, "A_EAC3": kAudioFormatEnhancedAC3]

    // MARK: - Reading the container

    static func parse(_ d: Data) -> Movie? {
        d.withUnsafeBytes { (b: UnsafeRawBufferPointer) -> Movie? in
            let n = b.count
            guard n > 8, b[0] == 0x1A, b[1] == 0x45, b[2] == 0xDF, b[3] == 0xA3 else { return nil }
            // EBML numbers: an element ID keeps its length marker; a size drops it, and all ones means "unknown".
            func vint(_ p: Int, id: Bool) -> (value: UInt64, len: Int)? {
                guard p >= 0, p < n, b[p] != 0 else { return nil }
                let first = b[p], len = first.leadingZeroBitCount + 1
                guard p + len <= n else { return nil }
                var v = UInt64(id ? first : first & (0xFF >> len))
                if len > 1 { for i in 1..<len { v = v << 8 | UInt64(b[p + i]) } }
                if !id, v == (UInt64(1) << (7 * len)) - 1 { return (.max, len) }
                return (v, len)
            }
            struct El { let id: UInt64; let start: Int; let end: Int; let unknown: Bool }
            func element(_ p: Int, limit: Int) -> El? {
                guard let i = vint(p, id: true), let s = vint(p + i.len, id: false) else { return nil }
                let start = p + i.len + s.len
                guard start <= limit else { return nil }
                let unknown = s.value == .max
                let end = unknown || s.value > UInt64(limit - start) ? limit : start + Int(s.value)
                return El(id: i.value, start: start, end: end, unknown: unknown)
            }
            func children(_ s: Int, _ e: Int, _ body: (El) -> Void) {
                var p = s
                while p < e, let el = element(p, limit: e) { body(el); if el.unknown { return }; p = el.end }
            }
            func uint(_ el: El) -> UInt64 {
                var v: UInt64 = 0
                for i in el.start..<min(el.end, el.start + 8) { v = v << 8 | UInt64(b[i]) }
                return v
            }
            func float(_ el: El) -> Double {
                let u = uint(el)
                return el.end - el.start == 4 ? Double(Float(bitPattern: UInt32(truncatingIfNeeded: u))) : Double(bitPattern: u)
            }
            func string(_ el: El) -> String {
                String(decoding: UnsafeRawBufferPointer(rebasing: b[el.start..<el.end]), as: UTF8.self)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
            }

            guard let header = element(0, limit: n) else { return nil }
            var docType = "matroska", docTypeAt: Int?, docTypeLen = 0
            children(header.start, header.end) { el in
                if el.id == 0x4282 { docType = string(el); docTypeAt = el.start; docTypeLen = el.end - el.start }
            }
            var p = header.end
            var segment: El?
            while p < n, let el = element(p, limit: n) {
                if el.id == 0x18538067 { segment = el; break }
                if el.unknown { break }
                p = el.end
            }
            guard let seg = segment else { return nil }

            var scale: Int64 = 1_000_000, tracks: [Track] = [], frames: [Frame] = []
            var step: [Int: Int64] = [:], clusterTime: Int64 = 0

            func block(_ s: Int, _ e: Int, key: Bool?) {
                guard let tn = vint(s, id: false), tn.value != .max, s + tn.len + 3 <= e else { return }
                var h = s + tn.len
                let rel = Int16(bitPattern: UInt16(b[h]) << 8 | UInt16(b[h + 1]))
                let flags = b[h + 2]; h += 3
                let isKey = key ?? (flags & 0x80 != 0)
                let track = Int(truncatingIfNeeded: tn.value)
                let t0 = (clusterTime &+ Int64(rel)) &* scale
                var sizes: [Int] = []
                let lacing = (flags >> 1) & 3
                if lacing == 0 {
                    sizes = [e - h]
                } else {
                    guard h < e else { return }
                    let count = Int(b[h]) + 1; h += 1
                    switch lacing {
                    case 1:   // Xiph: sizes as runs of 255s
                        for _ in 0..<(count - 1) {
                            var size = 0
                            while h < e { let v = Int(b[h]); h += 1; size += v; if v != 255 { break } }
                            sizes.append(size)
                        }
                    case 2:   // fixed: all the same size
                        sizes = Array(repeating: (e - h) / count, count: count - 1)
                    default:  // EBML: first size, then signed differences
                        guard count > 1, let first = vint(h, id: false), first.value != .max else { return }
                        h += first.len
                        var last = Int(truncatingIfNeeded: first.value)
                        sizes.append(last)
                        var k = 2
                        while k < count {
                            guard let r = vint(h, id: false), r.value != .max else { return }
                            h += r.len
                            last += Int(truncatingIfNeeded: r.value) - ((1 << (7 * r.len - 1)) - 1)
                            sizes.append(last); k += 1
                        }
                    }
                    sizes.append(e - h - sizes.reduce(0, +))
                }
                guard sizes.allSatisfy({ $0 >= 0 }), h + sizes.reduce(0, +) <= e else { return }
                let each = step[track] ?? 0
                var off = h
                for (i, size) in sizes.enumerated() {
                    frames.append(Frame(track: track, ns: t0 &+ Int64(i) &* each, key: isKey, offset: off, size: size))
                    off += size
                }
            }

            var q = seg.start
            while q < seg.end, let el = element(q, limit: seg.end) {
                switch el.id {
                case 0x1F43B675:                                  // Cluster: walk into it (its size may be unknown)
                    clusterTime = 0; q = el.start; continue
                case 0xE7:                                        // cluster time
                    clusterTime = Int64(truncatingIfNeeded: uint(el))
                case 0xA3:                                        // SimpleBlock
                    block(el.start, el.end, key: nil)
                case 0xA0:                                        // BlockGroup: a key frame unless it refers back
                    var inner: El?, refers = false
                    children(el.start, el.end) { c in if c.id == 0xA1 { inner = c }; if c.id == 0xFB { refers = true } }
                    if let inner { block(inner.start, inner.end, key: !refers) }
                case 0x1549A966:                                  // Info
                    children(el.start, el.end) { c in if c.id == 0x2AD7B1 { scale = max(1, Int64(truncatingIfNeeded: uint(c))) } }
                case 0x1654AE6B:                                  // Tracks
                    children(el.start, el.end) { te in
                        guard te.id == 0xAE else { return }
                        var t = Track()
                        children(te.start, te.end) { f in
                            switch f.id {
                            case 0xD7: t.number = Int(truncatingIfNeeded: uint(f))
                            case 0x83: t.type = Int(truncatingIfNeeded: uint(f))
                            case 0x86: t.codec = string(f)
                            case 0x63A2: t.priv = Data(b[f.start..<f.end])
                            case 0x23E383: t.defaultDuration = uint(f)
                            case 0x6D80: t.encoded = true
                            case 0xE0:
                                children(f.start, f.end) { v in
                                    if v.id == 0xB0 { t.width = Int(truncatingIfNeeded: uint(v)) }
                                    if v.id == 0xBA { t.height = Int(truncatingIfNeeded: uint(v)) }
                                }
                            case 0xE1:
                                children(f.start, f.end) { a in
                                    if a.id == 0xB5 { t.rate = float(a) }
                                    if a.id == 0x9F { t.channels = max(1, Int(truncatingIfNeeded: uint(a))) }
                                }
                            default: break
                            }
                        }
                        tracks.append(t)
                        step[t.number] = Int64(truncatingIfNeeded: t.defaultDuration)
                    }
                default: break
                }
                if el.unknown { break }   // an unknown-size element that isn't a cluster: nothing after it can be found
                q = el.end
            }
            guard !tracks.isEmpty else { return nil }
            return Movie(docType: docType, docTypeAt: docTypeAt, docTypeLen: docTypeLen, tracks: tracks, frames: frames)
        }
    }

    // MARK: - Making it playable

    enum Opened: Equatable { case web(URL), mp4(URL, soundDropped: Bool), problem(String) }

    static func open(_ url: URL) -> Opened {
        guard let d = try? Data(contentsOf: url, options: .alwaysMapped) else {
            return .problem("This file couldn't be read.")
        }
        guard let m = parse(d) else {
            return .problem("This Matroska file couldn't be read — it may be damaged or only partly downloaded.")
        }
        let video = m.tracks.first { $0.type == 1 }, audio = m.tracks.first { $0.type == 2 }
        guard video != nil || audio != nil else { return .problem("This file has no picture or sound in it.") }
        if [video, audio].contains(where: { $0?.encoded == true }) {
            return .problem("This file's frames are packed in an extra layer Tenzy can't unpack yet.")
        }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mkv-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let base = url.deletingPathExtension().lastPathComponent

        let webPicture = video.map { webVideo.contains($0.codec) } ?? true
        let webSound = audio.map { webAudio.contains($0.codec) } ?? true
        let mp4Picture = video.map { mp4Video[$0.codec] != nil } ?? true
        let mp4Sound = audio.map { $0.codec.hasPrefix("A_AAC") || mp4Audio[$0.codec] != nil } ?? true

        if webPicture && (webSound || !mp4Picture) {
            return webCopy(url, m, into: dir).map(Opened.web) ?? .problem("This video couldn't be prepared for playing.")
        }
        if mp4Picture {
            let keepSound = mp4Sound && audio != nil
            let out = dir.appendingPathComponent(base + (audio != nil && !keepSound ? " (no sound)" : "") + (video == nil ? ".m4a" : ".mp4"))
            if remux(d, m, video: video, audio: keepSound ? audio : nil, to: out) { return .mp4(out, soundDropped: audio != nil && !keepSound) }
            // Some sound formats can't go into MP4 as they are; the picture alone still can.
            if keepSound, video != nil {
                let silent = dir.appendingPathComponent(base + " (no sound).mp4")
                if remux(d, m, video: video, audio: nil, to: silent) { return .mp4(silent, soundDropped: true) }
            }
            return .problem("This video couldn't be prepared for playing.")
        }
        let codec = video?.codec ?? audio?.codec ?? "?"
        return .problem("The picture is in a format iPhone can't play (\(codec)). You can still share it to a video player app.")
    }

    /// A copy the web engine accepts as WebM: same bytes, with the "matroska" label changed to "webm".
    static func webCopy(_ url: URL, _ m: Movie, into dir: URL) -> URL? {
        let out = dir.appendingPathComponent("video.webm")
        guard (try? FileManager.default.copyItem(at: url, to: out)) != nil else { return nil }
        if m.docType != "webm" {
            guard let at = m.docTypeAt, m.docTypeLen >= 4, let h = try? FileHandle(forWritingTo: out) else { return nil }
            defer { try? h.close() }
            var label = Data("webm".utf8); label.append(Data(count: m.docTypeLen - 4))
            guard (try? h.seek(toOffset: UInt64(at))) != nil, (try? h.write(contentsOf: label)) != nil else { return nil }
        }
        return out
    }

    /// Moves the frames into an MP4 as they are (no re-encoding).
    static func remux(_ d: Data, _ m: Movie, video: Track?, audio: Track?, to out: URL) -> Bool {
        try? FileManager.default.removeItem(at: out)
        guard let w = try? AVAssetWriter(outputURL: out, fileType: out.pathExtension == "m4a" ? .m4a : .mp4) else { return false }
        var inputs: [Int: (input: AVAssetWriterInput, format: CMFormatDescription)] = [:]
        for (t, media) in [(video, AVMediaType.video), (audio, AVMediaType.audio)] {
            guard let t else { continue }
            guard let f = media == .video ? videoFormat(t) : audioFormat(t) else { return false }
            let i = AVAssetWriterInput(mediaType: media, outputSettings: nil, sourceFormatHint: f)
            i.expectsMediaDataInRealTime = false
            guard w.canAdd(i) else { return false }
            w.add(i); inputs[t.number] = (i, f)
        }
        let frames = m.frames.filter { inputs[$0.track] != nil && $0.size > 0 }
        guard !inputs.isEmpty, !frames.isEmpty else { return false }

        // Frames are stored in decode order with their show times. Decode times are the show times in order, moved
        // back just enough that no frame is decoded after it shows; everything is then shifted so nothing is negative.
        let vn = video?.number ?? -1
        let showV = frames.filter { $0.track == vn }.map(\.ns)
        let sortedV = showV.sorted()
        var shift: Int64 = 0
        for (i, t) in showV.enumerated() { shift = max(shift, sortedV[i] - t) }
        let firstShow = frames.map(\.ns).min() ?? 0
        func time(_ ns: Int64) -> CMTime { CMTime(value: ns + shift - firstShow, timescale: 1_000_000_000) }

        let an = audio?.number ?? -2
        let audioStep: Int64 = {
            guard let a = audio else { return 0 }
            if a.defaultDuration > 0 { return Int64(a.defaultDuration) }
            let samples: Double = a.codec.hasPrefix("A_AAC") ? 1024 : a.codec == "A_MPEG/L3" ? 1152 : 1536
            return Int64(samples / max(1, a.rate) * 1e9)
        }()
        var lastIndex: [Int: Int] = [:]
        for (i, f) in frames.enumerated() { lastIndex[f.track] = i }

        guard w.startWriting() else { return false }
        w.startSession(atSourceTime: CMTime(value: shift, timescale: 1_000_000_000))   // the first frame shown
        var vi = 0, lastAudio: Int64 = .min
        for (i, f) in frames.enumerated() {
            guard let entry = inputs[f.track] else { continue }
            let input = entry.input, format = entry.format
            var pts = time(f.ns), dts = CMTime.invalid, dur = CMTime.invalid
            if f.track == vn {
                dts = CMTime(value: sortedV[vi] - firstShow, timescale: 1_000_000_000)
                vi += 1
            } else if f.track == an {
                var ns = f.ns
                if ns <= lastAudio { ns = lastAudio + audioStep }   // laced frames share one time stamp
                lastAudio = ns
                pts = time(ns); dur = CMTime(value: audioStep, timescale: 1_000_000_000)
            }
            guard let sb = sample(d, f, format, pts: pts, dts: dts, duration: dur) else { continue }
            var waited = 0
            while !input.isReadyForMoreMediaData {
                if w.status != .writing || waited > 3000 { w.cancelWriting(); return false }
                Thread.sleep(forTimeInterval: 0.003); waited += 1
            }
            guard input.append(sb) else { w.cancelWriting(); return false }
            if lastIndex[f.track] == i { input.markAsFinished() }   // lets the other track run on past this one's end
        }
        let done = DispatchSemaphore(value: 0)
        w.finishWriting { done.signal() }
        done.wait()
        return w.status == .completed
    }

    static func sample(_ d: Data, _ f: Frame, _ format: CMFormatDescription, pts: CMTime, dts: CMTime, duration: CMTime) -> CMSampleBuffer? {
        guard f.offset >= 0, f.offset + f.size <= d.count else { return nil }
        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: f.size,
                                                 blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0,
                                                 dataLength: f.size, flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block) == noErr,
              let block else { return nil }
        let copied = d.withUnsafeBytes { raw in
            CMBlockBufferReplaceDataBytes(with: raw.baseAddress! + f.offset, blockBuffer: block, offsetIntoDestination: 0, dataLength: f.size)
        }
        guard copied == noErr else { return nil }
        var timing = CMSampleTimingInfo(duration: duration, presentationTimeStamp: pts, decodeTimeStamp: dts)
        var size = f.size
        var sb: CMSampleBuffer?
        guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: format, sampleCount: 1,
                                        sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 1,
                                        sampleSizeArray: &size, sampleBufferOut: &sb) == noErr, let sb else { return nil }
        if !f.key, let list = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: true), CFArrayGetCount(list) > 0 {
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(list, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        return sb
    }

    // MARK: - Track descriptions

    static func videoFormat(_ t: Track) -> CMFormatDescription? {
        guard let codec = mp4Video[t.codec], !t.priv.isEmpty, t.width > 0, t.height > 0 else { return nil }
        let atom = codec == kCMVideoCodecType_HEVC ? "hvcC" : "avcC"
        let ext = [kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: [atom: t.priv]] as CFDictionary
        var fd: CMFormatDescription?
        guard CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: codec, width: Int32(t.width), height: Int32(t.height),
                                             extensions: ext, formatDescriptionOut: &fd) == noErr else { return nil }
        return fd
    }

    static func audioFormat(_ t: Track) -> CMFormatDescription? {
        let id: AudioFormatID
        if t.codec.hasPrefix("A_AAC") { id = kAudioFormatMPEG4AAC } else if let x = mp4Audio[t.codec] { id = x } else { return nil }
        let rate = t.rate > 0 ? t.rate : 8000
        let perPacket: UInt32 = id == kAudioFormatMPEG4AAC ? 1024 : id == kAudioFormatMPEGLayer3 ? 1152 : 1536
        var asbd = AudioStreamBasicDescription(mSampleRate: rate, mFormatID: id, mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: perPacket,
                                               mBytesPerFrame: 0, mChannelsPerFrame: UInt32(t.channels), mBitsPerChannel: 0, mReserved: 0)
        let cookie = id == kAudioFormatMPEG4AAC ? esds(t.priv.isEmpty ? audioSpecificConfig(rate: rate, channels: t.channels) : t.priv) : Data()
        var fd: CMFormatDescription?
        let status = cookie.withUnsafeBytes { c in
            CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil,
                                           magicCookieSize: c.count, magicCookie: c.count > 0 ? c.baseAddress : nil,
                                           extensions: nil, formatDescriptionOut: &fd)
        }
        return status == noErr ? fd : nil
    }

    /// The MPEG-4 ES descriptor Apple uses as an AAC "magic cookie", wrapped around the stream's AudioSpecificConfig.
    static func esds(_ asc: Data) -> Data {
        func descriptor(_ tag: UInt8, _ body: Data) -> Data {
            let n = body.count
            return Data([tag, UInt8(0x80 | (n >> 21) & 0x7F), UInt8(0x80 | (n >> 14) & 0x7F), UInt8(0x80 | (n >> 7) & 0x7F), UInt8(n & 0x7F)]) + body
        }
        // DecoderConfig: AAC (0x40), audio stream (0x15), buffer size and bit rates left at zero.
        let config = descriptor(0x04, Data([0x40, 0x15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]) + descriptor(0x05, asc))
        return descriptor(0x03, Data([0, 0, 0]) + config + descriptor(0x06, Data([0x02])))
    }

    /// For old files that name AAC in the codec ID but carry no config: plain AAC-LC at the track's rate.
    static func audioSpecificConfig(rate: Double, channels: Int) -> Data {
        let rates = [96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350]
        let i = rates.firstIndex(of: Int(rate)) ?? 4
        let v = 2 << 11 | i << 7 | (channels & 0xF) << 3
        return Data([UInt8(v >> 8), UInt8(v & 0xFF)])
    }
}
