import AVFoundation

/// The sound under a video in the Video Studio (26 Nov, Manan: "we don't give them the option to change the
/// background music"): the video's own sound, no sound, music Tenzy makes itself (Engines/Synth.swift — nothing
/// borrowed, so it can be posted anywhere), or the person's own song from Files — mixed with the video's sound as
/// much or as little as they like, looped to the video's length and faded out at the end.
enum VideoSound {
    struct Choice: Identifiable, Equatable { let id: String, name: String, emoji: String }

    /// "original", "none", then one per kind of music Tenzy makes; "file" is the person's own song.
    static let choices: [Choice] = [Choice(id: "original", name: "As filmed", emoji: "🎙️"), Choice(id: "none", name: "No sound", emoji: "🔇")]
        + Synth.styles.map { Choice(id: "synth:" + $0.id, name: $0.name, emoji: $0.emoji) }

    /// How loud the music and the video's own sound are for a `keep` of 0 (just the music) … 1 (just the video's
    /// sound); both are full in the middle. Pure.
    static func volumes(keep: Double) -> (music: Float, video: Float) {
        let k = min(1, max(0, keep))
        return (Float(min(1, 2 * (1 - k))), Float(min(1, 2 * k)))
    }

    /// Where each copy of a `length`-second song starts and how much of it plays, to cover `seconds` of video. Pure.
    static func loops(song length: Double, video seconds: Double) -> [(at: Double, play: Double)] {
        guard length > 0.2, seconds > 0 else { return [] }
        var out: [(at: Double, play: Double)] = [], t = 0.0
        while t < seconds - 0.01, out.count < 400 {
            let play = min(length, seconds - t)
            out.append((t, play)); t += play
        }
        return out
    }

    private static var made: (key: String, url: URL, beats: [Double])?
    private static let lock = NSLock()

    /// The video ready to play or save with the recipe's sound.
    struct Built {
        let asset: AVAsset
        let mix: AVAudioMix?
        /// The music's beats when Tenzy made it (the picture can pulse on them).
        let beats: [Double]
        /// Why the music couldn't go in (the video then keeps its own sound), for the screen to say.
        let problem: String?
    }

    static func build(_ source: URL, music: String, song: URL?, keep: Double) async -> Built {
        let asset = AVURLAsset(url: source)
        if music == "original" { return Built(asset: asset, mix: nil, beats: [], problem: nil) }
        defer { withExtendedLifetime(asset) {} }
        guard let vt = try? await asset.loadTracks(withMediaType: .video).first,
              let length = try? await asset.load(.duration), length.seconds > 0 else { return Built(asset: asset, mix: nil, beats: [], problem: "The video couldn't be read.") }
        let comp = AVMutableComposition()
        guard let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              (try? cv.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: vt, at: .zero)) != nil else {
            return Built(asset: asset, mix: nil, beats: [], problem: "The video couldn't be read.")
        }
        cv.preferredTransform = (try? await vt.load(.preferredTransform)) ?? .identity
        if music == "none" { return Built(asset: comp, mix: nil, beats: [], problem: nil) }

        let vol = volumes(keep: keep)
        var inputs: [AVMutableAudioMixInputParameters] = []
        // The video's own sound, as loud as asked.
        if vol.video > 0.01, let at = try? await asset.loadTracks(withMediaType: .audio).first,
           let ca = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            if (try? ca.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: at, at: .zero)) != nil {
                let p = AVMutableAudioMixInputParameters(track: ca); p.setVolume(vol.video, at: .zero); inputs.append(p)
            } else { comp.removeTrack(ca) }
        }
        // The music.
        var beats: [Double] = [], songURL = song
        if music.hasPrefix("synth:") {
            let style = String(music.dropFirst(6)), seconds = min(length.seconds, 300)
            // The same music for the same video is made once (the preview is rebuilt on every change).
            let key = "\(style)-\(Int(seconds.rounded()))"
            lock.lock(); let have = made?.key == key && FileManager.default.fileExists(atPath: made?.url.path ?? "") ? made : nil; lock.unlock()
            if let have { songURL = have.url; beats = have.beats } else {
                let track = await Task.detached(priority: .userInitiated) { Synth.track(style, seconds: seconds) }.value
                songURL = Synth.file(track.samples, name: "studio-music")
                beats = track.beats
                if let u = songURL { lock.lock(); made = (key, u, beats); lock.unlock() }
            }
            beats = beats.filter { $0 < length.seconds }
        }
        guard let songURL else { return fallback(asset, "Choose a song first.") }
        let songAsset = AVURLAsset(url: songURL)
        defer { withExtendedLifetime(songAsset) {} }
        guard let st = try? await songAsset.loadTracks(withMediaType: .audio).first, let songLength = try? await songAsset.load(.duration), songLength.seconds > 0.2,
              let cm = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return fallback(asset, "That song can't be used — it may be protected. Try another file.")
        }
        for piece in loops(song: songLength.seconds, video: length.seconds) {
            do {
                try cm.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: piece.play, preferredTimescale: 6000)), of: st, at: CMTime(seconds: piece.at, preferredTimescale: 6000))
            } catch {
                comp.removeTrack(cm)
                return fallback(asset, "That song can't be used — it may be protected. Try another file.")
            }
        }
        if music.hasPrefix("synth:"), songLength.seconds < length.seconds, !beats.isEmpty {
            // The made track repeats under a longer video: so do its beats.
            let one = beats
            var t = songLength.seconds
            while t < length.seconds { beats += one.map { $0 + t }.filter { $0 < length.seconds }; t += songLength.seconds }
        }
        let p = AVMutableAudioMixInputParameters(track: cm)
        let fade = min(1.5, length.seconds / 4)
        p.setVolume(vol.music, at: .zero)
        p.setVolumeRamp(fromStartVolume: vol.music, toEndVolume: 0, timeRange: CMTimeRange(start: CMTime(seconds: length.seconds - fade, preferredTimescale: 6000),
                                                                                         duration: CMTime(seconds: fade, preferredTimescale: 6000)))
        inputs.append(p)
        let mix = AVMutableAudioMix(); mix.inputParameters = inputs
        return Built(asset: comp, mix: mix, beats: beats, problem: nil)
    }

    private static func fallback(_ asset: AVAsset, _ why: String) -> Built { Built(asset: asset, mix: nil, beats: [], problem: why) }

    /// A copy of a song picked in Files, kept in Tenzy's temporary folder so it can still be read later. nil if it
    /// isn't a sound file Tenzy can open.
    static func adopt(_ picked: URL) async -> URL? {
        let scoped = picked.startAccessingSecurityScopedResource()
        defer { if scoped { picked.stopAccessingSecurityScopedResource() } }
        let ext = picked.pathExtension.isEmpty ? "m4a" : picked.pathExtension
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("studio-song-\(UUID().uuidString.prefix(8)).\(ext)")
        guard (try? FileManager.default.copyItem(at: picked, to: dest)) != nil else { return nil }
        let a = AVURLAsset(url: dest)
        guard let t = try? await a.loadTracks(withMediaType: .audio).first, (try? await a.load(.duration).seconds) ?? 0 > 0.2,
              (try? await t.load(.isPlayable)) != false else { try? FileManager.default.removeItem(at: dest); return nil }
        return dest
    }
}
