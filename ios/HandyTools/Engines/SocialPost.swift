import AVFoundation
import CoreImage
import Photos
import UIKit

/// Post it — a video made right for where it's going (TikTok, Instagram Reels and Stories, YouTube Shorts and
/// YouTube, Facebook Reels, Snapchat, X, WhatsApp Status): the right shape (tall with soft blurred sides, nothing cut
/// off), the best part when it's longer than the platform takes, small enough when there's a size limit. Then it's
/// saved to Photos, the caption (with that platform's tags) is copied, and the app opens on it — Instagram straight
/// to the new post with the video picked. The apps don't let anyone publish for you without signing in to them, so
/// the last tap — Post — is theirs. Deciding what to do is pure, so it's unit-tested.
enum SocialPost {
    enum Shape: Equatable { case tall, wide, any }

    struct Platform: Identifiable, Equatable {
        let id: String
        let name: String
        let icon: String
        let tint: UInt32
        let shape: Shape
        /// Longest it takes, in seconds (nil = no practical limit). Kept a little under the platform's own, so it never refuses.
        let maxSeconds: Double?
        let maxBytes: Int?
        let tags: [String]
        /// The app's own link, and where to get it if it isn't installed.
        let app: String
        let store: String
    }

    static let platforms: [Platform] = [
        Platform(id: "tiktok", name: "TikTok", icon: "music.note", tint: 0x111111, shape: .tall, maxSeconds: 595, maxBytes: 270_000_000,
                 tags: ["#fyp", "#foryou"], app: "tiktok://", store: "https://apps.apple.com/app/id835599320"),
        Platform(id: "reels", name: "Instagram Reels", icon: "play.rectangle.on.rectangle", tint: 0xE1306C, shape: .tall, maxSeconds: 178, maxBytes: nil,
                 tags: ["#reels"], app: "instagram://", store: "https://apps.apple.com/app/id389801252"),
        Platform(id: "stories", name: "Instagram Stories", icon: "circle.dashed", tint: 0xF77737, shape: .tall, maxSeconds: 59, maxBytes: nil,
                 tags: [], app: "instagram://story-camera", store: "https://apps.apple.com/app/id389801252"),
        Platform(id: "shorts", name: "YouTube Shorts", icon: "bolt.fill", tint: 0xFF0000, shape: .tall, maxSeconds: 178, maxBytes: nil,
                 tags: ["#shorts"], app: "youtube://", store: "https://apps.apple.com/app/id544007664"),
        Platform(id: "youtube", name: "YouTube", icon: "play.rectangle.fill", tint: 0xCC0000, shape: .wide, maxSeconds: nil, maxBytes: nil,
                 tags: [], app: "youtube://", store: "https://apps.apple.com/app/id544007664"),
        Platform(id: "facebook", name: "Facebook Reels", icon: "f.square.fill", tint: 0x1877F2, shape: .tall, maxSeconds: 88, maxBytes: nil,
                 tags: ["#reels"], app: "fb://", store: "https://apps.apple.com/app/id284882215"),
        Platform(id: "snapchat", name: "Snapchat", icon: "camera.fill", tint: 0xFFC800, shape: .tall, maxSeconds: 59, maxBytes: nil,
                 tags: [], app: "snapchat://", store: "https://apps.apple.com/app/id447188370"),
        Platform(id: "x", name: "X", icon: "xmark", tint: 0x000000, shape: .any, maxSeconds: 138, maxBytes: 500_000_000,
                 tags: [], app: "twitter://", store: "https://apps.apple.com/app/id333903271"),
        Platform(id: "whatsapp", name: "WhatsApp Status", icon: "circle.circle.fill", tint: 0x25D366, shape: .tall, maxSeconds: 59, maxBytes: 16_000_000,
                 tags: [], app: "whatsapp://", store: "https://apps.apple.com/app/id310633997"),
    ]
    static func platform(_ id: String) -> Platform? { platforms.first { $0.id == id } }

    /// What getting a video ready for a platform involves.
    struct Plan: Equatable {
        var makeTall = false
        /// Keep this many seconds (the liveliest part) when it's longer than the platform takes.
        var keepSeconds: Double?
        var underBytes: Int?
        /// Each step, in plain words, for the checklist.
        var steps: [String] = []
        var nothingToChange: Bool { !makeTall && keepSeconds == nil && underBytes == nil }
    }

    static func plan(_ p: Platform, seconds: Double, bytes: Int, size: CGSize) -> Plan {
        var plan = Plan()
        let tall = size.height > size.width * 1.5
        if p.shape == .tall, !tall, size != .zero {
            plan.makeTall = true
            plan.steps.append(L("Made tall (9:16) — soft blurred sides, nothing cut off"))
        }
        if let m = p.maxSeconds, seconds > m + 0.5 {
            plan.keepSeconds = m
            plan.steps.append("\(L("Keeps the liveliest")) \(clock(m)) · \(L("it's")) \(clock(seconds)), \(L(p.name)) \(L("takes up to")) \(clock(m))")
        }
        if let b = p.maxBytes {
            // Shortening shrinks it about in proportion; only shrink when it would still be over.
            let after = plan.keepSeconds.map { Double(bytes) * $0 / max(1, seconds) } ?? Double(bytes)
            if after > Double(b) * 0.97 {
                plan.underBytes = Int(Double(b) * 0.95)
                plan.steps.append("\(L("Made small enough for")) \(L(p.name))")
            }
        }
        if plan.nothingToChange { plan.steps.append("\(L("Already the right shape, length and size for")) \(L(p.name))") }
        return plan
    }

    static func clock(_ s: Double) -> String { let t = Int(s.rounded()); return t < 60 ? "\(t) s" : String(format: "%d:%02d", t / 60, t % 60) }

    /// The words to paste: the person's caption, then the platform's tags that aren't already in it.
    static func caption(_ text: String, for p: Platform) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let have = Set(t.lowercased().split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init))
        let tags = p.tags.filter { !have.contains($0.lowercased()) }
        return ([t] + (tags.isEmpty ? [] : [tags.joined(separator: " ")])).filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    /// Where to send the person: Instagram opens on the saved video, ready to post; the rest open the app.
    static func openURL(_ p: Platform, assetID: String?) -> URL? {
        if p.id == "reels", let id = assetID?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: "instagram://library?LocalIdentifier=\(id)")
        }
        return URL(string: p.app)
    }

    // MARK: - Making it

    /// The video ready for `p`: the best part, tall, small enough. nil if the phone couldn't make it.
    static func prepare(_ url: URL, for p: Platform, progress: ((String) -> Void)? = nil) async -> URL? {
        guard let f = await VideoFacts.read(url) else { return nil }
        let plan = plan(p, seconds: f.seconds, bytes: f.bytes, size: f.size)
        var cur = url
        if let keep = plan.keepSeconds {
            progress?(L("Finding the liveliest part…"))
            let start = await VideoJoin.busiestMoment(url, length: keep)?.lowerBound ?? 0
            guard let t = await VideoEngine.trim(cur, start: start, end: min(f.seconds, start + keep)) else { return nil }
            cur = t
        }
        if plan.makeTall {
            progress?(L("Making it tall…"))
            guard let t = await tall(cur) else { return nil }
            cur = t
        }
        if let b = plan.underBytes, (SizeTarget.fileSize(cur) ?? 0) > b {
            progress?(L("Making it small enough…"))
            guard let s = await SizeTarget.video(url: cur, targetBytes: b) else { return nil }
            cur = s
        }
        return cur
    }

    /// Where the picture sits in a tall frame: as wide as the frame, in the middle; behind it, the same picture
    /// filling the frame, blurred and a little darker. Pure.
    static func tallLayout(_ src: CGSize) -> (out: CGSize, fit: CGRect, fill: CGRect) {
        func even(_ v: CGFloat) -> CGFloat { max(2, (v / 2).rounded() * 2) }
        let w = even(min(1080, src.width))
        let h = even(w * 16 / 9)
        let k = w / max(1, src.width)
        let fit = CGRect(x: 0, y: (h - src.height * k) / 2, width: w, height: src.height * k)
        let c = max(w / max(1, src.width), h / max(1, src.height))
        let fill = CGRect(x: (w - src.width * c) / 2, y: (h - src.height * c) / 2, width: src.width * c, height: src.height * c)
        return (CGSize(width: w, height: h), fit, fill)
    }

    /// A sideways or square video made tall, nothing cut off: the soft blurred fill behind, the whole picture in front.
    static func tall(_ url: URL) async -> URL? {
        let asset = AVURLAsset(url: url)
        guard let f = await VideoFacts.read(url), f.size.width > 0 else { return nil }
        let lay = tallLayout(f.size)
        let tr = (try? await asset.loadTracks(withMediaType: .video).first?.load(.preferredTransform)) ?? .identity
        let orient: CGImagePropertyOrientation = {
            switch (tr.a, tr.b, tr.c, tr.d) {
            case (0, 1, -1, 0): return .right
            case (0, -1, 1, 0): return .left
            case (-1, 0, 0, -1): return .down
            default: return .up
            }
        }()
        guard let comp = try? await AVMutableVideoComposition.videoComposition(with: asset, applyingCIFiltersWithHandler: { request in
            var src = request.sourceImage
            if abs(src.extent.width - f.size.width) > 2 || abs(src.extent.height - f.size.height) > 2, orient != .up { src = src.oriented(orient) }
            src = src.transformed(by: CGAffineTransform(translationX: -src.extent.minX, y: -src.extent.minY))
            let s = src.extent.size
            func place(_ r: CGRect) -> CGAffineTransform {
                CGAffineTransform(scaleX: r.width / s.width, y: r.height / s.height).concatenating(CGAffineTransform(translationX: r.minX, y: r.minY))
            }
            let out = CGRect(origin: .zero, size: lay.out)
            let back = src.clampedToExtent().transformed(by: place(lay.fill))
                .applyingGaussianBlur(sigma: Double(lay.out.width) * 0.045)
                .applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey: -0.12, kCIInputSaturationKey: 1.1])
                .cropped(to: out)
            let front = src.transformed(by: place(lay.fit))
            request.finish(with: front.composited(over: back).cropped(to: out), context: nil)
        }) else { return nil }
        comp.renderSize = lay.out
        guard let s = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let out = VideoEngine.tempURL("mp4")
        s.outputURL = out; s.outputFileType = .mp4; s.videoComposition = comp; s.metadata = []
        return await VideoEngine.run(s, seconds: f.seconds) ? out : nil
    }

    /// Into Photos (the apps pick from there); returns the new item's id, for Instagram.
    static func saveToPhotos(_ url: URL) async -> (ok: Bool, id: String?) {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return (false, nil) }
        var id: String?
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let r = PHAssetCreationRequest.forAsset()
                r.addResource(with: .video, fileURL: url, options: nil)
                id = r.placeholderForCreatedAsset?.localIdentifier
            }
            return (true, id)
        } catch { return (false, nil) }
    }
}
