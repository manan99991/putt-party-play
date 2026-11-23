import AVFoundation
import MediaPlayer
import UniformTypeIdentifiers

/// Music for a video: find the songs on this phone that can go into one, read where the beats fall, start the song at
/// its liveliest part on a beat, and lay it under the finished video with a soft fade at the end.
///
/// What iOS allows (said plainly in the picker): songs in the Music app that are on the phone and not locked by Apple
/// Music (bought or synced songs), any sound file you pick from Files, iCloud Drive or Downloads, and the music you've
/// already brought into Tenzy (kept in its Music folder so it's there next time). Apps can't search every file on the
/// phone by themselves, and streamed Apple Music songs are copy-protected, so those two can't be offered.
/// Everything happens on the phone. The beat maths is pure, so it's unit-tested.
enum MusicTrack {
    /// One song you can pick.
    struct Song: Identifiable, Equatable {
        let id: String
        let title: String
        let artist: String
        let seconds: Double
        let url: URL
        var fromLibrary = false
    }

    /// The song chosen for a video, and how it's laid under it.
    struct Pick: Equatable {
        let song: Song
        /// Where in the song the video starts — on a beat, in its liveliest part.
        var start: Double = 0
        /// Seconds between beats (nil when no steady beat was found — the photos then keep their own pace).
        var beat: Double?
        /// A copy Tenzy can read (songs from the Music app are copied out once).
        var file: URL
    }

    static let fileTypes: [UTType] = [.mp3, .wav, .mpeg4Audio, .aiff, .audio]
    static let audioExts: Set<String> = ["mp3", "wav", "m4a", "aac", "aif", "aiff", "caf", "flac"]

    // MARK: - Finding songs

    static var libraryAccess: MPMediaLibraryAuthorizationStatus { MPMediaLibrary.authorizationStatus() }
    static func askForLibrary() async -> MPMediaLibraryAuthorizationStatus {
        await withCheckedContinuation { c in MPMediaLibrary.requestAuthorization { c.resume(returning: $0) } }
    }

    /// Songs in the Music app that can go into a video, A–Z, and how many are locked (streamed or protected).
    static func librarySongs() -> (usable: [Song], locked: Int) {
        guard libraryAccess == .authorized, let items = MPMediaQuery.songs().items else { return ([], 0) }
        var usable: [Song] = [], locked = 0
        for it in items {
            guard let u = it.assetURL, !it.hasProtectedAsset, !it.isCloudItem else { locked += 1; continue }
            usable.append(Song(id: "lib-\(it.persistentID)", title: it.title ?? L("Untitled"), artist: it.artist ?? "",
                               seconds: it.playbackDuration, url: u, fromLibrary: true))
        }
        return (usable.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }, locked)
    }

    /// Where music picked from Files is kept, so it's offered again next time.
    static var folder: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// Sound files already in Tenzy (its Music folder, and anything shared or saved into it), newest first.
    static func filesInTenzy() async -> [Song] {
        var out: [Song] = []
        for u in soundFiles() {
            let (t, a, s) = await describe(u)
            if s >= 3 { out.append(Song(id: "file-\(u.path)", title: t, artist: a, seconds: s, url: u)) }
        }
        return out
    }

    /// Every sound file under Tenzy's Documents (not the Vault or receipts), newest first.
    static func soundFiles() -> [URL] {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let skip: Set<String> = ["Vault", "receipts", "Contact Backups"]
        var found: [(URL, Date)] = []
        guard let e = FileManager.default.enumerator(at: docs, includingPropertiesForKeys: [.contentModificationDateKey],
                                                     options: [.skipsHiddenFiles]) else { return [] }
        while let u = e.nextObject() as? URL {
            if skip.contains(u.lastPathComponent) || e.level > 4 { e.skipDescendants(); continue }
            guard audioExts.contains(u.pathExtension.lowercased()) else { continue }
            let d = (try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            found.append((u, d))
        }
        return found.sorted { $0.1 > $1.1 }.prefix(300).map(\.0)
    }

    /// Title, artist and length from the file's own tags (the file name when it has none).
    static func describe(_ u: URL) async -> (String, String, Double) {
        let asset = AVURLAsset(url: u)
        let secs = (try? await asset.load(.duration).seconds) ?? 0
        let meta = (try? await asset.load(.commonMetadata)) ?? []
        func value(_ key: AVMetadataKey) async -> String? {
            guard let item = AVMetadataItem.metadataItems(from: meta, withKey: key, keySpace: .common).first else { return nil }
            return try? await item.load(.stringValue)
        }
        let title = await value(.commonKeyTitle) ?? u.deletingPathExtension().lastPathComponent
        let artist = await value(.commonKeyArtist) ?? ""
        return (title, artist, secs.isFinite ? secs : 0)
    }

    /// A file picked from Files, copied into Tenzy's Music folder (picked files are only lent to the app).
    static func keep(_ picked: URL) -> URL? {
        let scoped = picked.startAccessingSecurityScopedResource()
        defer { if scoped { picked.stopAccessingSecurityScopedResource() } }
        let dest = folder.appendingPathComponent(picked.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) { return dest }
        do { try FileManager.default.copyItem(at: picked, to: dest); return dest } catch { return nil }
    }

    /// A copy Tenzy can read sample by sample: files are used as they are; a Music-app song is copied out once.
    static func readable(_ song: Song) async -> URL? {
        guard song.fromLibrary else { return song.url }
        let cache = FileManager.default.temporaryDirectory.appendingPathComponent("music-\(abs(song.id.hashValue)).m4a")
        if FileManager.default.fileExists(atPath: cache.path) { return cache }
        guard let s = AVAssetExportSession(asset: AVURLAsset(url: song.url), presetName: AVAssetExportPresetAppleM4A) else { return nil }
        s.outputURL = cache; s.outputFileType = .m4a
        await s.export()
        return s.status == .completed ? cache : nil
    }

    // MARK: - Reading the beat

    /// Analysis rate: ~86 looks a second.
    static let hopRate = 86.0

    /// How loud each moment is (`energy`) and how sharply it starts (`onset` — drums, plucks, claps), ~86 a second.
    static func envelope(_ url: URL) -> (energy: [Float], onset: [Float])? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let fmt = file.processingFormat
        let hop = max(64, Int(fmt.sampleRate / hopRate))
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(hop * 256)) else { return nil }
        var energy: [Float] = [], flux: [Float] = []
        var accE: Float = 0, accD: Float = 0, n = 0, last: Float = 0
        let channels = Int(fmt.channelCount)
        while file.framePosition < file.length {
            do { try file.read(into: buf) } catch { break }
            let frames = Int(buf.frameLength)
            guard frames > 0, let data = buf.floatChannelData else { break }
            for i in 0..<frames {
                var x: Float = 0
                for c in 0..<channels { x += data[c][i] }
                x /= Float(max(1, channels))
                let d = x - last; last = x
                accE += x * x; accD += d * d; n += 1
                if n == hop {
                    energy.append(accE / Float(hop)); flux.append(accD / Float(hop))
                    accE = 0; accD = 0; n = 0
                }
            }
            if energy.count > Int(hopRate * 900) { break }          // 15 minutes is plenty
        }
        guard energy.count > Int(hopRate * 2) else { return nil }
        // Onset strength: how much the (log) high-frequency energy jumps from one look to the next.
        var onset = [Float](repeating: 0, count: flux.count)
        var prev = log(flux[0] + 1e-7)
        for i in 1..<flux.count {
            let cur = log(flux[i] + 1e-7)
            onset[i] = max(0, cur - prev); prev = cur
        }
        return (energy, onset)
    }

    /// The steady beat in an onset curve: seconds between beats and when the first beat falls. Looks between 70 and
    /// 180 beats a minute and leans toward ~120, so a song isn't read at half or double its speed.
    static func tempo(onset raw: [Float], rate: Double = hopRate) -> (period: Double, phase: Double)? {
        guard raw.count > Int(rate * 4) else { return nil }
        // Soften each onset over a few looks, so a beat that falls between two looks still lines up with the next.
        let kernel: [Float] = [0.25, 0.6, 1, 0.6, 0.25]
        var sm = [Float](repeating: 0, count: raw.count)
        for i in raw.indices { for (j, w) in kernel.enumerated() { let k = i + j - 2; if k >= 0, k < raw.count { sm[i] += raw[k] * w } } }
        let mean = sm.reduce(0, +) / Float(sm.count)
        let o = sm.map { $0 - mean }
        // A flat curve (silence, steady noise) has no beat: it must actually rise and fall.
        let spread = sqrt(o.reduce(0) { $0 + $1 * $1 } / Float(o.count))
        guard spread > 0.05 * max(abs(mean), 1e-6) else { return nil }
        let minLag = Int(rate * 60 / 180), maxLag = Int(rate * 60 / 70) + 1
        var scores: [Int: Double] = [:]
        for lag in minLag...maxLag {
            var s = 0.0
            for i in lag..<o.count { s += Double(o[i] * o[i - lag]) }
            scores[lag] = s / Double(o.count - lag)
        }
        func lean(_ lag: Int) -> Double { exp(-0.5 * pow(log2(rate * 60 / Double(lag) / 120) / 0.9, 2)) }
        guard var bestLag = scores.max(by: { $0.value * lean($0.key) < $1.value * lean($1.key) })?.key, (scores[bestLag] ?? 0) > 0 else { return nil }
        // Half the beat length also fits nearly as well? Then the song is twice as fast (a steady pulse also repeats
        // every two beats, which would read a 150 bpm song as 75).
        let half = Int((Double(bestLag) / 2).rounded())
        if rate * 60 / Double(half) <= 170, let h = scores[half] ?? scores[half + 1], let b = scores[bestLag], h >= 0.6 * b { bestLag = half }
        // Is it really steady? The beat must stand out from the average lag.
        let all = scores.values.reduce(0, +) / Double(max(1, scores.count))
        guard let peak = scores[bestLag], peak > max(0, all) * 1.15 else { return nil }
        // Fine-tune the beat length and where the first beat falls together, over the whole song, so they don't drift.
        var best = (lag: Double(bestLag), phase: 0.0, sum: -Double.infinity)
        var lag = Double(bestLag) - 1
        while lag <= Double(bestLag) + 1 {
            for p in 0..<Int(lag.rounded(.up)) {
                var sum = 0.0, t = Double(p)
                while Int(t.rounded()) < sm.count { sum += Double(sm[Int(t.rounded())]); t += lag }
                sum /= Double(max(1, Int(Double(sm.count - p) / lag)))
                if sum > best.sum { best = (lag, Double(p), sum) }
            }
            lag += 0.05
        }
        return (best.lag / rate, best.phase / rate)
    }

    /// Where a `length`-second stretch of the song is loudest (its chorus, usually), in seconds from the start.
    static func liveliest(energy: [Float], rate: Double = hopRate, length: Double) -> Double {
        let w = Int(length * rate)
        guard w > 0, energy.count > w else { return 0 }
        var sum = energy[0..<w].reduce(0, +), best = sum, at = 0
        // Never start in the last few seconds or the very first — skip a quiet intro, keep room for the whole video.
        for i in 1...(energy.count - w) {
            sum += energy[i + w - 1] - energy[i - 1]
            if sum > best { best = sum; at = i }
        }
        return Double(at) / rate
    }

    /// The beat at or just before `t`.
    static func snap(_ t: Double, period: Double, phase: Double) -> Double {
        guard period > 0 else { return t }
        let k = ((t - phase) / period).rounded(.down)
        return max(0, phase + k * period)
    }

    /// Get a song ready for a video about `length` seconds long: its beat, and where to start it.
    static func prepare(_ song: Song, videoLength: Double) async -> Pick? {
        guard let file = await readable(song) else { return nil }
        let env = await Task.detached(priority: .userInitiated) { envelope(file) }.value
        guard let env else { return Pick(song: song, file: file) }
        let beat = tempo(onset: env.onset)
        var start = liveliest(energy: env.energy, length: max(5, videoLength))
        if let b = beat { start = snap(start, period: b.period, phase: b.phase) }
        return Pick(song: song, start: start, beat: beat?.period, file: file)
    }

    // MARK: - Laying it under the video

    /// The soundtrack: the song from `start` for `length` seconds (round again from the top if it's shorter), a
    /// quick fade in and a soft fade out, as AAC.
    static func soundtrack(_ pick: Pick, length: Double) -> URL? {
        guard length > 0, let src = try? AVAudioFile(forReading: pick.file) else { return nil }
        let fmt = src.processingFormat
        let rate = fmt.sampleRate
        let out = VideoEngine.tempURL("m4a")
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate,
                                       AVNumberOfChannelsKey: min(2, Int(fmt.channelCount)), AVEncoderBitRateKey: 192_000]
        guard let dst = try? AVAudioFile(forWriting: out, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false),
              let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 32_768) else { return nil }
        let total = AVAudioFramePosition(length * rate)
        let fadeIn = rate * 0.15, fadeOut = rate * min(1.8, length * 0.25)
        var written: AVAudioFramePosition = 0
        src.framePosition = min(src.length - 1, max(0, AVAudioFramePosition(pick.start * rate)))
        let channels = Int(fmt.channelCount)
        while written < total {
            if src.framePosition >= src.length { src.framePosition = 0 }
            do { try src.read(into: buf, frameCount: AVAudioFrameCount(min(Int64(32_768), total - written))) } catch { break }
            let n = Int(buf.frameLength)
            guard n > 0, let data = buf.floatChannelData else { break }
            for i in 0..<n {
                let at = Double(written) + Double(i)
                var g = 1.0
                if at < fadeIn { g = at / fadeIn }
                let left = Double(total) - at
                if left < fadeOut { g = min(g, max(0, left / fadeOut)) }
                if g < 1 { for c in 0..<channels { data[c][i] *= Float(g * g) } }
            }
            do { try dst.write(from: buf) } catch { return nil }
            written += AVAudioFramePosition(n)
        }
        return written > 0 ? out : nil
    }

    /// The video with the song laid under it (the picture is copied as it is).
    static func addMusic(_ pick: Pick, to video: URL) async -> URL? {
        let length = await VideoEngine.duration(video)
        guard length > 0, let audio = await Task.detached(priority: .userInitiated, operation: { soundtrack(pick, length: length) }).value else { return nil }
        defer { try? FileManager.default.removeItem(at: audio) }
        return await VideoEngine.layAudio(audio, under: video)
    }
}
