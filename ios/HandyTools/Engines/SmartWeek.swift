import Foundation
import UIKit
import AVFoundation
import Photos

/// Smart autorun: my week, as one short film (26 Nov). Once a week it looks back over seven days, keeps the best
/// moments — sharp photos of the people in them (one per moment, little ones first, at most three a day) and the
/// liveliest three seconds of the best clips — and cuts them into one tall 9:16 film, day by day in the order they
/// happened, opening on a title card ("My week · Nov 20 – 26"). Photos glide (the whole photo over a soft blur, so no
/// face is cropped); clips keep their sound. It waits to be watched; music can be laid under it from the songs the
/// person has brought into Tenzy; Save puts it in Photos. Nothing is posted.
enum SmartWeek {
    struct Result: Codable, Equatable, Identifiable {
        var id: String                // the week's last day, "2026-11-26"
        var file: String
        var title: String
        var seconds: Double
        var photos: Int
        var clips: Int
        var days: Int
        var saved = false
        var song: String?             // the music laid under it, if any
    }

    static var folder: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SmartRuns/Week", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    // MARK: pure rules

    /// One stretch of the film: a run of photos from one day, or one clip.
    enum Part: Equatable { case photos([String]), clip(String) }

    /// The film's running order: day by day, each day's photos (at most `perDay`, spread across it) then that day's best
    /// clip. Days with nothing are skipped. `day` gives each moment's calendar day.
    static func story(photos: [SmartRuns.Found], clips: [SmartRuns.Found], perDay: Int = 3, cal: Calendar = .current) -> [Part] {
        let days = Set((photos + clips).map { cal.startOfDay(for: $0.created) }).sorted()
        var out: [Part] = []
        for d in days {
            let ps = photos.filter { cal.isDate($0.created, inSameDayAs: d) }.sorted { $0.created < $1.created }
            let pick: [SmartRuns.Found]
            if ps.count <= perDay { pick = ps }
            else if perDay == 1 { pick = [ps[ps.count / 2]] }
            else { pick = (0..<perDay).map { ps[Int((Double($0) * Double(ps.count - 1) / Double(perDay - 1)).rounded())] } }
            if !pick.isEmpty { out.append(.photos(pick.map(\.id))) }
            if let c = clips.filter({ cal.isDate($0.created, inSameDayAs: d) }).first { out.append(.clip(c.id)) }
        }
        return out
    }

    /// Enough to be a film: at least five moments across at least two days.
    static func worthMaking(_ parts: [Part]) -> Bool {
        let moments = parts.reduce(0) { n, p in if case .photos(let ids) = p { return n + ids.count }; return n + 1 }
        return moments >= 5 && parts.count >= 2
    }

    /// "My week · Nov 20 – 26" (or "Nov 28 – Dec 4" across a month), in the phone's language.
    static func title(from start: Date, to end: Date, cal: Calendar = .current) -> String {
        let sameMonth = cal.component(.month, from: start) == cal.component(.month, from: end)
        let a = start.formatted(.dateTime.month(.abbreviated).day())
        let b = sameMonth ? end.formatted(.dateTime.day()) : end.formatted(.dateTime.month(.abbreviated).day())
        return "\(L("My week")) · \(a) – \(b)"
    }

    // MARK: on the phone

    /// The week's film. nil when the week didn't have enough moments (or the phone couldn't make it).
    static func make(in window: DateInterval, progress: ((Double, String) -> Void)? = nil) async -> Result? {
        progress?(0.02, L("Looking back over your week…"))
        let photos = await SmartCollage.found(in: window)
        let picks = SmartRuns.collagePicks(photos.map(\.0), limit: 21)
        progress?(0.15, L("Finding the best clips…"))
        let clipPairs = await SmartPosts.best(in: window, limit: 4)
        let parts = story(photos: picks, clips: clipPairs.map(\.0))
        guard worthMaking(parts) else { return nil }
        let size = VideoFormat.preset("reels")?.size ?? CGSize(width: 1080, height: 1920)
        let title = title(from: window.start, to: window.end)
        var pieces: [URL] = []
        defer { for u in pieces { try? FileManager.default.removeItem(at: u) } }
        // The title card opens the first run of photos, so it glides in with them.
        var titleCard: UIImage? = card(title, size: size)
        var shownPhotos = 0, shownClips = 0
        for (i, part) in parts.enumerated() {
            if Task.isCancelled { return nil }
            progress?(0.2 + 0.7 * Double(i) / Double(parts.count), "\(L("Cutting the film")) \(i + 1)/\(parts.count)")
            switch part {
            case .photos(let ids):
                var images: [UIImage] = []
                for id in ids { if let a = photos.first(where: { $0.0.id == id })?.1, let img = await PhotoFinder.image(a, side: 1600) { images.append(img.normalizedUp()) } }
                guard !images.isEmpty, let u = await glide(images, opening: titleCard) else { continue }
                titleCard = nil; pieces.append(u); shownPhotos += images.count
            case .clip(let id):
                guard let a = clipPairs.first(where: { $0.0.id == id })?.1, let av = await SmartVideos.avAsset(a) as? AVURLAsset,
                      let tall = await moment(av.url) else { continue }
                pieces.append(tall); shownClips += 1
            }
        }
        guard !pieces.isEmpty, shownPhotos + shownClips >= 5 else { return nil }
        progress?(0.92, L("Putting it together…"))
        guard let joined = await VideoJoin.join(pieces) else { return nil }
        let id = DateFormatter.posixDay.string(from: window.end)
        let file = "\(id)-\(UUID().uuidString.prefix(6)).mp4"
        let dest = folder.appendingPathComponent(file)
        do { try FileManager.default.moveItem(at: joined, to: dest) } catch { return nil }
        let seconds = await VideoEngine.duration(dest)
        let days = Set(parts.compactMap { p -> String? in
            switch p {
            case .photos(let ids): return ids.first.flatMap { i in picks.first { $0.id == i } }.map { DateFormatter.posixDay.string(from: $0.created) }
            case .clip(let i): return clipPairs.first { $0.0.id == i }.map { DateFormatter.posixDay.string(from: $0.0.created) }
            }
        }).count
        progress?(1, L("Done"))
        return Result(id: id, file: file, title: title, seconds: seconds, photos: shownPhotos, clips: shownClips, days: days)
    }

    /// A run of photos as a gliding 9:16 stretch — the whole of each photo over a soft blur, so no face is cut —
    /// opening on the title card when there is one.
    static func glide(_ photos: [UIImage], opening: UIImage? = nil) async -> URL? {
        var s = Animate.Settings(); s.style = .kenBurns; s.framing = .fit; s.pace = .normal
        if let f = VideoFormat.preset("reels") { s.format = f }
        return await Animate.render((opening.map { [$0] } ?? []) + photos, settings: s)
    }

    /// A clip's liveliest three seconds, made tall 9:16 with its sound.
    static func moment(_ clip: URL) async -> URL? {
        let length = await VideoEngine.duration(clip)
        guard length > 0 else { return nil }
        let span = await VideoJoin.busiestMoment(clip, length: 3) ?? 0...min(3, length)
        guard let cut = await VideoEngine.trim(clip, start: span.lowerBound, end: span.upperBound), let p = SocialPost.platform("reels") else { return nil }
        let tall = await SocialPost.prepare(cut, for: p).first
        if tall != cut { try? FileManager.default.removeItem(at: cut) }   // an already-tall clip comes back as itself
        return tall
    }

    /// The opening card: the week's title, large and calm, on a warm gradient.
    static func card(_ title: String, size: CGSize) -> UIImage {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: size, format: f).image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 1).cgColor, UIColor(red: 0.86, green: 0.15, blue: 0.47, alpha: 1).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            let parts = title.components(separatedBy: " · ")
            let para = NSMutableParagraphStyle(); para.alignment = .center
            let big: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size.width * 0.12, weight: .heavy), .foregroundColor: UIColor.white, .paragraphStyle: para]
            let small: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size.width * 0.055, weight: .semibold), .foregroundColor: UIColor.white.withAlphaComponent(0.9), .paragraphStyle: para]
            let head = NSAttributedString(string: parts.first ?? title, attributes: big)
            let sub = NSAttributedString(string: parts.count > 1 ? parts[1] : "", attributes: small)
            let w = size.width * 0.84
            let hh = head.boundingRect(with: CGSize(width: w, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).height
            let sh = sub.boundingRect(with: CGSize(width: w, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).height
            let top = (size.height - hh - sh - size.width * 0.04) / 2
            head.draw(with: CGRect(x: (size.width - w) / 2, y: top, width: w, height: hh), options: .usesLineFragmentOrigin, context: nil)
            sub.draw(with: CGRect(x: (size.width - w) / 2, y: top + hh + size.width * 0.04, width: w, height: sh), options: .usesLineFragmentOrigin, context: nil)
        }
    }

    /// Lays a song from the person's own music under the film (it starts at its liveliest part, on a beat, and fades
    /// at the end; the clips' own sound is replaced). Returns the new file's name.
    static func addMusic(_ r: Result, song: MusicTrack.Song) async -> String? {
        let src = folder.appendingPathComponent(r.file)
        guard let pick = await MusicTrack.prepare(song, videoLength: r.seconds), let out = await MusicTrack.addMusic(pick, to: src) else { return nil }
        let file = "\(r.id)-\(UUID().uuidString.prefix(6)).mp4"
        do { try FileManager.default.moveItem(at: out, to: folder.appendingPathComponent(file)) } catch { return nil }
        return file
    }

    /// Saves the film to Photos.
    static func save(_ r: Result) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        let url = folder.appendingPathComponent(r.file)
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCreationRequest.forAsset(); req.addResource(with: .video, fileURL: url, options: nil); req.creationDate = Date()
            }
            return true
        } catch { return false }
    }
}
