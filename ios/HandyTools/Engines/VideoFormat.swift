import CoreGraphics
import Foundation

/// The "real format" layer: the exact canvas sizes the big platforms expect, plus the math to fit any
/// source into one without distorting it. Shared by the Animate tool and the Video tool so an export
/// lands ready to post. 1080-tall is the deliberate choice — crisp on every feed, light enough to
/// encode on any phone (4K would choke older devices and buys nothing on social). H.264 + AAC so it
/// plays and uploads everywhere, in any country.
enum VideoFormat {
    struct Spec: Identifiable, Equatable {
        let id: String
        let name: String       // what the user taps ("Reels / TikTok")
        let size: CGSize       // exact export canvas
        var ratio: String      // "9:16"
    }

    /// The platforms worth a one-tap preset. Order = how they're shown.
    static let presets: [Spec] = [
        Spec(id: "reels",   name: "Reels · TikTok · Shorts", size: CGSize(width: 1080, height: 1920), ratio: "9:16"),
        Spec(id: "story",   name: "Story / Status",          size: CGSize(width: 1080, height: 1920), ratio: "9:16"),
        Spec(id: "square",  name: "Square post",             size: CGSize(width: 1080, height: 1080), ratio: "1:1"),
        Spec(id: "portrait",name: "Portrait post",           size: CGSize(width: 1080, height: 1350), ratio: "4:5"),
        Spec(id: "youtube", name: "YouTube (wide)",          size: CGSize(width: 1920, height: 1080), ratio: "16:9"),
    ]

    static func preset(_ id: String) -> Spec? { presets.first { $0.id == id } }

    /// Aspect-FILL: the crop of `source` (in source pixels) that exactly fills `target` with no bars,
    /// centered — subjects stay centered, edges are trimmed. This is the default for social.
    static func fillCrop(source: CGSize, target: CGSize) -> CGRect {
        guard source.width > 0, source.height > 0, target.width > 0, target.height > 0 else { return CGRect(origin: .zero, size: source) }
        let scale = max(target.width / source.width, target.height / source.height)
        let w = target.width / scale, h = target.height / scale
        return CGRect(x: (source.width - w) / 2, y: (source.height - h) / 2, width: w, height: h)
    }

    /// Aspect-FIT: where `source` sits inside `target` (in target pixels) when letter/pillar-boxed,
    /// centered — nothing is cut, bars fill the rest. Offered when the user would rather keep the whole frame.
    static func fitRect(source: CGSize, target: CGSize) -> CGRect {
        guard source.width > 0, source.height > 0, target.width > 0, target.height > 0 else { return CGRect(origin: .zero, size: target) }
        let scale = min(target.width / source.width, target.height / source.height)
        let w = source.width * scale, h = source.height * scale
        return CGRect(x: (target.width - w) / 2, y: (target.height - h) / 2, width: w, height: h)
    }
}
