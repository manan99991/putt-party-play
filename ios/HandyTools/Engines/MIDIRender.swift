import Foundation
import AVFoundation

/// A MIDI file (.mid) turned into sound you can play and share: the notes of every track are read (tempo changes,
/// running status, all channels) and played by a small built-in piano-like voice, with the drum channel as soft
/// percussion. iPhone has no MIDI sounds of its own, so this is the honest way to hear a .mid on the phone.
enum MIDIRender {
    struct Note: Equatable { var start: Double; var end: Double; var key: Int; var velocity: Int; var drum: Bool }
    struct Song { var notes: [Note]; var trackNames: [String]; var length: Double }

    // MARK: - Reading

    static func parse(_ data: Data) -> Song? {
        let b = [UInt8](data)
        guard b.count >= 14, Array(b[0..<4]) == Array("MThd".utf8) else { return nil }
        func u16(_ o: Int) -> Int { Int(b[o]) << 8 | Int(b[o + 1]) }
        func u32(_ o: Int) -> Int { Int(b[o]) << 24 | Int(b[o + 1]) << 16 | Int(b[o + 2]) << 8 | Int(b[o + 3]) }
        let headerLen = u32(4), tracks = u16(10), division = u16(12)
        var p = 8 + headerLen
        // Ticks to seconds: quarter-note ticks with a tempo map, or SMPTE frames.
        let smpte = division & 0x8000 != 0
        let ticksPerSecond = smpte ? Double(256 - (division >> 8)) * Double(division & 0xFF) : 0
        let tpq = smpte ? 1 : max(1, division)

        struct Raw { var tick: Int; var key: Int; var vel: Int; var ch: Int; var on: Bool }
        var events: [Raw] = [], tempos: [(tick: Int, usPerQuarter: Int)] = [(0, 500_000)], names: [String] = []
        var t = 0
        while t < tracks, p + 8 <= b.count {
            let len = u32(p + 4)
            guard Array(b[p..<p + 4]) == Array("MTrk".utf8) else { p += 8 + len; continue }
            var q = p + 8; let end = min(b.count, q + len)
            var tick = 0, status: UInt8 = 0
            func varlen() -> Int { var v = 0; while q < end { let c = b[q]; q += 1; v = v << 7 | Int(c & 0x7F); if c & 0x80 == 0 { break } }; return v }
            while q < end {
                tick += varlen()
                guard q < end else { break }
                var s = b[q]
                if s & 0x80 != 0 { q += 1; if s < 0xF0 { status = s } } else { s = status }   // running status
                switch s {
                case 0xFF:
                    guard q < end else { break }
                    let type = b[q]; q += 1
                    let n = varlen()
                    let v = Array(b[q..<min(end, q + n)])
                    if type == 0x51, v.count == 3 { tempos.append((tick, Int(v[0]) << 16 | Int(v[1]) << 8 | Int(v[2]))) }
                    if type == 0x03, !v.isEmpty { names.append(String(decoding: v, as: UTF8.self)) }
                    q += n
                case 0xF0, 0xF7:
                    q += varlen()
                default:
                    let kind = s & 0xF0, ch = Int(s & 0x0F)
                    let two = kind != 0xC0 && kind != 0xD0
                    guard q + (two ? 2 : 1) <= end else { q = end; break }
                    let d1 = Int(b[q]), d2 = two ? Int(b[q + 1]) : 0
                    q += two ? 2 : 1
                    if kind == 0x90 { events.append(Raw(tick: tick, key: d1, vel: d2, ch: ch, on: d2 > 0)) }
                    else if kind == 0x80 { events.append(Raw(tick: tick, key: d1, vel: 0, ch: ch, on: false)) }
                }
            }
            p += 8 + len; t += 1
        }
        tempos.sort { $0.tick < $1.tick }
        func seconds(_ tick: Int) -> Double {
            if smpte { return Double(tick) / max(1, ticksPerSecond) }
            var s = 0.0, last = 0, us = 500_000
            for tp in tempos where tp.tick <= tick {
                s += Double(tp.tick - last) * Double(us) / 1_000_000 / Double(tpq); last = tp.tick; us = tp.usPerQuarter
            }
            return s + Double(tick - last) * Double(us) / 1_000_000 / Double(tpq)
        }
        events.sort { $0.tick < $1.tick }
        var open: [Int: [(start: Double, vel: Int)]] = [:], notes: [Note] = []
        for e in events {
            let id = e.ch * 128 + e.key, at = seconds(e.tick)
            if e.on { open[id, default: []].append((at, e.vel)) }
            else if var stack = open[id], !stack.isEmpty {
                let s = stack.removeFirst(); open[id] = stack
                notes.append(Note(start: s.start, end: max(at, s.start + 0.03), key: e.key, velocity: s.vel, drum: e.ch == 9))
            }
        }
        for (id, stack) in open { for s in stack { notes.append(Note(start: s.start, end: s.start + 0.5, key: id % 128, velocity: s.vel, drum: id / 128 == 9)) } }
        guard !notes.isEmpty else { return nil }
        notes.sort { $0.start < $1.start }
        return Song(notes: notes, trackNames: names, length: (notes.map(\.end).max() ?? 0) + 0.4)
    }

    // MARK: - Sound

    static let rate = 22_050.0
    /// One cycle of a soft piano-like tone (a few decaying harmonics), looked up instead of computing sines.
    private static let table: [Float] = (0..<2048).map { i in
        let x = Double(i) / 2048 * 2 * .pi
        return Float(sin(x) + 0.45 * sin(2 * x) + 0.2 * sin(3 * x) + 0.08 * sin(4 * x)) / 1.73
    }

    /// The song as samples (mono, 22 kHz), capped at ten minutes.
    static func render(_ song: Song) -> [Float] {
        let total = Int(min(song.length, 600) * rate)
        var out = [Float](repeating: 0, count: max(1, total))
        var noise: UInt32 = 0x2545_F491
        for n in song.notes {
            let start = Int(n.start * rate)
            guard start < total else { continue }
            let amp = Float(n.velocity) / 127 * 0.22
            if n.drum {
                // A short, soft hit: low thump for kicks, filtered noise for the rest.
                let len = min(total - start, Int(0.12 * rate))
                var lp: Float = 0
                for i in 0..<len {
                    let env = expf(-Float(i) / Float(rate) * 30)
                    noise ^= noise << 13; noise ^= noise >> 17; noise ^= noise << 5
                    let r = Float(Int32(bitPattern: noise)) / Float(Int32.max)
                    lp += (r - lp) * 0.3
                    let kick = n.key <= 36 ? sinf(2 * .pi * 60 * Float(i) / Float(rate)) : 0
                    out[start + i] += amp * env * (n.key <= 36 ? kick : lp)
                }
                continue
            }
            let freq = 440 * pow(2, Double(n.key - 69) / 12)
            let step = freq / rate * 2048
            let held = Int((n.end - n.start) * rate), release = Int(0.18 * rate)
            let len = min(total - start, held + release)
            var phase = 0.0
            for i in 0..<len {
                let t = Float(i) / Float(rate)
                var env = min(1, t / 0.005) * expf(-t * 2.2)
                if i > held { env *= max(0, 1 - Float(i - held) / Float(release)) }
                out[start + i] += amp * env * table[Int(phase) & 2047]
                phase += step
            }
        }
        let peak = out.map(abs).max() ?? 0
        if peak > 0.9 { let k = 0.9 / peak; for i in out.indices { out[i] *= k } }
        return out
    }

    /// The .mid as a playable .m4a in a temporary folder, or nil if it isn't a MIDI file with notes.
    static func toM4A(_ url: URL) -> URL? {
        guard let d = try? Data(contentsOf: url), let song = parse(d) else { return nil }
        let samples = render(song)
        let out = FileManager.default.temporaryDirectory.appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".m4a")
        try? FileManager.default.removeItem(at: out)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let file = try? AVAudioFile(forWriting: out, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate,
                                                                      AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 96_000]) else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count) }
        do { try file.write(from: buffer) } catch { return nil }
        return out
    }
}
