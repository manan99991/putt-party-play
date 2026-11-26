import AVFoundation
import CoreImage
import NaturalLanguage
import UIKit

/// Movie trailer (26 Nov, Manan: "the most amazing after effects… maximum wow factor"): your clips and photos become a
/// half-minute trailer — black title cards with a deep narrator ("In a world…"), slow-motion shots under the first
/// lines, faster cuts, a montage that builds on a riser, a beat of silence, then the title on a huge hit and
/// "Coming soon". The score, the hits and the narrator are all made on the phone (Synth and the phone's own voices),
/// so the trailer can be posted anywhere.
enum Trailer {
    static let bpm = 96.0
    static var beat: Double { 60 / bpm }
    static var bar: Double { beat * 4 }
    /// How long the last card rings after its final bar.
    static let ringOut = 1.2

    /// One part of the trailer, in order. `cut` is how long each shot lasts (shots only); `line` is which narrator
    /// line goes on a card.
    struct Part: Equatable {
        enum Kind: String { case card, slow, shots, montage, title, end }
        let kind: Kind
        let start: Double
        let length: Double
        var cut: Double = 0
        var line: Int? = nil
        var end: Double { start + length }
        var isCard: Bool { kind == .card || kind == .title || kind == .end }
    }

    /// The shape every trailer follows (12 bars, about half a minute). Pure, so the timings are tested.
    static func parts() -> [Part] {
        var out: [Part] = [], at = 0.0
        func add(_ k: Part.Kind, bars: Double, cut: Double = 0, line: Int? = nil, extra: Double = 0) {
            out.append(Part(kind: k, start: at, length: bars * bar + extra, cut: cut, line: line)); at += bars * bar + extra
        }
        add(.card, bars: 1, line: 0)
        add(.slow, bars: 2, cut: bar)            // slow motion under the first line
        add(.card, bars: 1, line: 1)
        add(.shots, bars: 2, cut: beat * 2)
        add(.card, bars: 1, line: 2)
        add(.montage, bars: 2, cut: beat)        // a cut on every beat, building to…
        add(.title, bars: 2)                      // …the title, on the big hit
        add(.end, bars: 1, extra: ringOut)        // "Coming soon"
        return out
    }

    /// The moments that hit: every card, every montage cut, the title. The picture flashes and punches in on these.
    static func hits(_ parts: [Part]) -> [Double] {
        var h: [Double] = []
        for p in parts {
            switch p.kind {
            case .card, .title, .end: h.append(p.start)
            case .montage: h += stride(from: p.start, to: p.end - 0.001, by: p.cut).map { $0 }
            default: break
            }
        }
        return h
    }

    /// Which clip and which piece of it fills each moment, in order. Cards get a one-frame placeholder (the picture
    /// is drawn over it); slow parts use half as much clip, stretched to slow motion; each clip's turns are spread
    /// through it so no moment repeats.
    static func cuts(_ parts: [Part], lengths: [Double]) -> [BeatReel.Cut] {
        guard !lengths.isEmpty else { return [] }
        let counts = parts.map { $0.isCard ? 0 : max(1, Int(($0.length / $0.cut).rounded())) }
        var uses = [Int](repeating: 0, count: lengths.count)
        for i in 0..<counts.reduce(0, +) { uses[i % lengths.count] += 1 }
        var seen = [Int](repeating: 0, count: lengths.count)
        var out: [BeatReel.Cut] = [], k = 0
        for (p, n) in zip(parts, counts) {
            if p.isCard { out.append(BeatReel.Cut(clip: 0, from: 0, length: 1.0 / 30, lasts: p.length)); continue }
            let lasts = p.length / Double(n)
            for _ in 0..<n {
                let c = k % lengths.count
                let need = p.kind == .slow ? lasts / 2 : lasts
                let len = min(need, max(0.1, lengths[c]))
                let margin = min(0.4, max(0, (lengths[c] - len) / 4))
                let room = max(0, lengths[c] - len - 2 * margin)
                let from = margin + room * (Double(seen[c]) + 0.5) / Double(max(1, uses[c]))
                seen[c] += 1; k += 1
                out.append(BeatReel.Cut(clip: c, from: from, length: len, lasts: lasts))
            }
        }
        return out
    }

    // MARK: the score

    /// The trailer's music, made to its parts: a drone and a braam on every card, slow drums under the slow shots,
    /// quicker drums, a montage that builds on a riser, half a beat of silence, then the biggest hit on the title.
    static func score(_ parts: [Part]) -> [Float] {
        let rate = Synth.rate
        let total = (parts.last?.end ?? 0) + 0.5
        var out = [Float](repeating: 0, count: Int(total * rate))
        let roots = [33, 41, 36, 43], chords = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]   // Am F C G
        let tk = Synth.taiko(), k = Synth.kick(punch: 1.2)
        for p in parts {
            let firstBar = Int((p.start / bar).rounded())
            let bars = max(1, Int((p.length / bar).rounded(.down)))
            for b in 0..<bars {
                let t0 = p.start + Double(b) * bar, j = (firstBar + b) % 4
                let bright: Double = p.kind == .montage ? 2200 : p.isCard ? 800 : 1300
                Synth.mix(Synth.pad(chords[j].map { $0 - 12 }, seconds: bar, brightness: bright), into: &out, at: t0, gain: p.isCard ? 0.6 : 0.8)
                switch p.kind {
                case .slow:
                    Synth.mix(tk, into: &out, at: t0, gain: 0.75); Synth.mix(tk, into: &out, at: t0 + 2 * beat, gain: 0.55)
                case .shots:
                    for q in 0..<4 { Synth.mix(tk, into: &out, at: t0 + Double(q) * beat, gain: q % 2 == 0 ? 0.8 : 0.55) }
                    Synth.mix(k, into: &out, at: t0, gain: 0.7); Synth.mix(k, into: &out, at: t0 + 2 * beat, gain: 0.6)
                case .montage:
                    let lift = Float(0.6 + 0.4 * Double(b) / Double(max(1, bars - 1)))
                    for e in 0..<8 { Synth.mix(tk, into: &out, at: t0 + Double(e) * beat / 2, gain: (e % 2 == 0 ? 0.75 : 0.5) * lift) }
                    for q in 0..<4 { Synth.mix(k, into: &out, at: t0 + Double(q) * beat, gain: 0.7 * lift) }
                default: break
                }
            }
            switch p.kind {
            case .card:
                Synth.mix(Synth.braam(roots[firstBar % 4], seconds: bar * 1.2), into: &out, at: p.start, gain: 0.9)
                Synth.mix(tk, into: &out, at: p.start, gain: 0.8)
            case .montage:
                Synth.mix(Synth.riser(seconds: p.length), into: &out, at: p.start, gain: 0.9)
            case .title:
                Synth.mix(Synth.braam(33, seconds: p.length), into: &out, at: p.start, gain: 1)
                Synth.mix(tk, into: &out, at: p.start, gain: 1); Synth.mix(k, into: &out, at: p.start, gain: 1)
                Synth.mix(tk, into: &out, at: p.start + bar, gain: 0.6)
            case .end:
                Synth.mix(tk, into: &out, at: p.start, gain: 0.55)
                Synth.mix(Synth.pad(chords[0], seconds: p.length, brightness: 1600), into: &out, at: p.start, gain: 0.7)
            default: break
            }
        }
        // The held breath: half a beat of nothing right before the title lands.
        if let title = parts.first(where: { $0.kind == .title }) {
            let a = Int((title.start - beat / 2) * rate), b = Int(title.start * rate)
            for i in max(0, a)..<min(out.count, b) { out[i] = 0 }
        }
        return VoiceFX.level(out)
    }

    // MARK: the narrator

    private final class Sink: @unchecked Sendable { var samples: [Float] = []; var rate = 22_050.0; var done = false }

    /// `text` in a deep trailer voice (the phone's own voice, spoken slowly and low, given a big room), at Synth.rate.
    /// Made on the phone; empty if the phone has no voice for the language.
    static func narrate(_ text: String) async -> [Float] {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return [] }
        let u = AVSpeechUtterance(string: line)
        u.voice = voice(for: line)
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.82
        u.pitchMultiplier = 0.62
        u.volume = 1
        let sink = Sink()
        let synth = AVSpeechSynthesizer()
        _ = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let gate = DispatchQueue(label: "tenzy.trailer.voice")
            func finish(_ v: Bool) { gate.async { if !sink.done { sink.done = true; cont.resume(returning: v) } } }
            synth.write(u) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 { finish(true); return }
                let n = Int(pcm.frameLength), r = pcm.format.sampleRate
                var chunk = [Float](repeating: 0, count: n)
                if let f = pcm.floatChannelData { for i in 0..<n { chunk[i] = f[0][i] } }
                else if let s = pcm.int16ChannelData { for i in 0..<n { chunk[i] = Float(s[0][i]) / 32768 } }
                gate.async { sink.rate = r; sink.samples += chunk }
            }
            gate.asyncAfter(deadline: .now() + 20) { finish(false) }
        }
        withExtendedLifetime(synth) {}
        let raw = sink.samples
        guard raw.count > Int(0.1 * sink.rate) else { return [] }
        // To the music's rate, then the trailer sound: more chest, a little edge, a big hall.
        let ratio = sink.rate / Synth.rate
        let n = Int(Double(raw.count) / ratio)
        var y = (0..<n).map { i -> Float in
            let x = Double(i) * ratio, a = Int(x), f = Float(x - Double(a))
            return a + 1 < raw.count ? raw[a] * (1 - f) + raw[a + 1] * f : raw[min(a, raw.count - 1)]
        }
        y = VoiceFX.filter(y, "lowshelf", f: 140, gainDB: 6, rate: Synth.rate)
        y = VoiceFX.filter(y, "peak", f: 2800, q: 1, gainDB: 3, rate: Synth.rate)
        y = VoiceFX.drive(y, amount: 1.3)
        y = VoiceFX.echoes(y, delays: [0.11, 0.19], decay: 0.22, rate: Synth.rate)
        return VoiceFX.level(y)
    }

    /// A voice in the language the line is written in (a typed English title on a Hindi phone is read in English).
    static func voice(for line: String) -> AVSpeechSynthesisVoice? {
        let phone = Locale.preferredLanguages.first ?? "en-US"
        let r = NLLanguageRecognizer(); r.processString(line)
        // Only a clear reading counts (two words can look like anything); otherwise the phone's own language.
        let written = r.languageHypotheses(withMaximum: 1).first.flatMap { $0.value > 0.6 ? $0.key.rawValue : nil }
        let lang = written.map { w in phone.hasPrefix(w) ? phone : w } ?? phone
        let base = String(lang.prefix(2))
        // The richest voice installed for it (the phone's own accent wins a tie), else the system's choice.
        func rank(_ v: AVSpeechSynthesisVoice) -> Int { v.quality.rawValue * 2 + (v.language == lang ? 1 : 0) }
        return AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(base) }.max { rank($0) < rank($1) }
            ?? AVSpeechSynthesisVoice(language: lang) ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    /// When each spoken line starts: a card's line just after its braam, the title after its hit, "Coming soon" on its card.
    static func cues(_ parts: [Part]) -> [(at: Double, line: Int)] {
        parts.compactMap { p in
            switch p.kind {
            case .card: return p.line.map { (p.start + 0.25, $0) }
            case .title: return (p.start + 0.7, 3)
            case .end: return (p.start + 0.2, 4)
            default: return nil
            }
        }
    }

    /// The narrator over the music, the music dipping under the voice so every word is heard.
    static func mixVoice(_ voice: [Float], into music: inout [Float], at t: Double) {
        let start = Int(t * Synth.rate)
        guard start < music.count, !voice.isEmpty else { return }
        let w = Int(0.04 * Synth.rate)
        var env: Float = 0
        for i in voice.indices where start + i < music.count {
            let v = abs(voice[i]); env = v > env ? v : env * (1 - 1 / Float(w))
            music[start + i] = music[start + i] * (1 - 0.55 * min(1, env * 4)) + voice[i] * 0.9
        }
    }

    // MARK: the cards

    enum CardStyle { case line, title, end }

    /// A card's words, drawn once per text and size: tall serif capitals, spaced wide, softly glowing.
    final class Cards: @unchecked Sendable {
        private var made: [String: CIImage] = [:]
        private let lock = NSLock()
        func image(_ text: String, style: CardStyle, size: CGSize) -> CIImage? {
            let key = "\(text)|\(style)|\(Int(size.width))"
            lock.lock(); defer { lock.unlock() }
            if let m = made[key] { return m }
            guard let ui = Trailer.card(text, style: style, width: size.width), let cg = ui.cgImage else { return nil }
            let img = CIImage(cgImage: cg)
            let placed = img.transformed(by: CGAffineTransform(translationX: (size.width - img.extent.width) / 2, y: (size.height - img.extent.height) / 2))
            made[key] = placed
            return placed
        }
    }

    static func card(_ text: String, style: CardStyle, width: CGFloat) -> UIImage? {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !words.isEmpty, width > 0 else { return nil }
        let size = width * (style == .title ? 0.12 : style == .end ? 0.06 : 0.062)
        let font = UIFont(name: "Didot-Bold", size: size) ?? UIFont(name: "Georgia-Bold", size: size) ?? .boldSystemFont(ofSize: size)
        let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineBreakMode = .byWordWrapping; para.lineSpacing = size * 0.25
        let glow = NSShadow(); glow.shadowColor = UIColor(red: 1, green: 0.85, blue: 0.55, alpha: style == .title ? 0.75 : 0.45)
        glow.shadowBlurRadius = size * 0.5; glow.shadowOffset = .zero
        let color = style == .title ? UIColor(red: 1, green: 0.93, blue: 0.78, alpha: 1) : UIColor(white: 0.95, alpha: 1)
        let s = NSAttributedString(string: words, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: para, .shadow: glow, .kern: size * 0.12])
        let maxW = width * 0.84
        let box = s.boundingRect(with: CGSize(width: maxW, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let pad = size
        let out = CGSize(width: ceil(min(maxW, box.width)) + pad * 2, height: ceil(box.height) + pad * 2)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        return UIGraphicsImageRenderer(size: out, format: fmt).image { _ in
            s.draw(with: CGRect(x: pad, y: pad, width: out.width - pad * 2, height: out.height - pad * 2), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        }
    }

    /// How a card shows `dt` seconds into its `length`: fading in and out, slowly growing. Pure.
    static func cardLook(dt: Double, length: Double, style: CardStyle) -> (alpha: Double, scale: Double) {
        let fadeIn = style == .title ? 0.15 : 0.45, fadeOut = style == .end ? 0.6 : 0.3
        let a = min(1, max(0, dt / fadeIn)) * min(1, max(0, (length - dt) / fadeOut))
        let p = min(1, max(0, dt / max(0.1, length)))
        return (a, 1 + (style == .title ? 0.1 : 0.06) * p)
    }

    /// The flash on a hit, `dt` seconds after it (bigger on the title).
    static func flash(_ t: Double, hits: [Double], title: Double) -> Double {
        var f = 0.0
        for h in hits where t >= h && t - h < 0.2 { f = max(f, (abs(h - title) < 0.01 ? 0.9 : 0.45) * (1 - (t - h) / 0.2)) }
        return f
    }

    // MARK: making it

    /// The default lines, in the person's language. Line 3 is the title, line 4 the ending.
    static var defaultLines: [String] { [L("In a world where anything can happen…"), L("One story was waiting to be told."), L("This year, get ready for…")] }

    /// The trailer from `sources` (videos; photos become clips first), with `lines` on the three cards and `title`.
    static func make(_ sources: [URL], title: String, lines: [String], progress: ((Double) -> Void)? = nil) async -> URL? {
        let srcs = await BeatReel.load(sources)
        guard !srcs.isEmpty else { return nil }
        let ps = parts()
        let cuts = cuts(ps, lengths: srcs.map(\.length))
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L("The Adventure") : title.trimmingCharacters(in: .whitespacesAndNewlines)
        var said = (0..<3).map { i in i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty ? lines[i] : defaultLines[i] }
        said += [name, L("Coming soon")]
        let spoken = said
        progress?(0.02)

        // The sound: the score, with the narrator on top.
        var sound = score(ps)
        for (i, c) in cues(ps).enumerated() {
            mixVoice(await narrate(spoken[c.line]), into: &sound, at: c.at)
            progress?(0.02 + 0.08 * Double(i + 1) / 5)
        }
        sound = VoiceFX.level(sound)

        guard let cut = await BeatReel.assemble(srcs, cuts: cuts, hold: 0, audio: sound, progress: { p in progress?(0.1 + 0.4 * p) }) else { return nil }
        progress?(0.5)

        // The picture: the cards drawn over their moments, the cinema look on the shots, a flash and a punch on hits.
        let asset = AVURLAsset(url: cut.url)
        let duration = cut.seconds
        var recipe = VideoFX.Recipe(look: "cinema", light: "vignette", motion: "pulse", texture: "bars")
        recipe.amount = 0.65
        let kit = VideoFX.Kit(recipe)
        let h = hits(ps)
        let titleAt = ps.first { $0.kind == .title }?.start ?? -1
        let cards = Cards()
        let cardParts = ps.filter(\.isCard)
        guard let vc = try? await AVMutableVideoComposition.videoComposition(with: asset, applyingCIFiltersWithHandler: { request in
            let render = request.renderSize, rect = CGRect(origin: .zero, size: render)
            let t = request.compositionTime.seconds
            var img: CIImage
            if let p = cardParts.first(where: { t >= $0.start && t < $0.end }) {
                let style: CardStyle = p.kind == .title ? .title : p.kind == .end ? .end : .line
                let text = p.kind == .title ? spoken[3] : p.kind == .end ? spoken[4] : spoken[p.line ?? 0]
                img = CIImage(color: .black).cropped(to: rect)
                if let words = cards.image(text, style: style, size: render) {
                    let l = cardLook(dt: t - p.start, length: p.length, style: style)
                    let cx = render.width / 2, cy = render.height / 2
                    let grown = words.transformed(by: CGAffineTransform(translationX: -cx, y: -cy).concatenating(CGAffineTransform(scaleX: l.scale, y: l.scale))
                        .concatenating(CGAffineTransform(translationX: cx, y: cy)))
                    img = grown.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: l.alpha)]).composited(over: img)
                }
            } else {
                var src = request.sourceImage
                if src.extent.origin != .zero { src = src.transformed(by: CGAffineTransform(translationX: -src.extent.minX, y: -src.extent.minY)) }
                img = VideoFX.frame(src, t: t, duration: duration, size: render, kit: kit, beats: h, caption: nil)
            }
            let f = flash(t, hits: h, title: titleAt)
            if f > 0 { img = CIImage(color: CIColor(red: 1, green: 0.97, blue: 0.9, alpha: f)).cropped(to: rect).composited(over: img) }
            request.finish(with: img.cropped(to: rect), context: nil)
        }) else { return nil }

        guard let s = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let out = VideoEngine.tempURL("mp4")
        s.outputURL = out; s.outputFileType = .mp4; s.videoComposition = vc; s.metadata = []
        let poll = Task { while !Task.isCancelled { progress?(0.5 + 0.5 * Double(s.progress)); try? await Task.sleep(nanoseconds: 300_000_000) } }
        let ok = await VideoEngine.run(s, seconds: duration)
        poll.cancel()
        try? FileManager.default.removeItem(at: cut.url)
        progress?(1)
        return ok ? out : nil
    }
}
