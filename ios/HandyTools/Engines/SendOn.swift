import Foundation

/// "Send on…": say where the video is going and it's cut and sized for that place — split into Story or Status
/// pieces, trimmed to the length a post allows, and shrunk just under the app's file limit, as sharp as fits.
/// Limits as each app published them (checked Nov 2026); the size target leaves a 5% margin.
enum SendOn {
    struct Place: Identifiable, Equatable {
        let id: String; let name: String; let icon: String
        let maxBytes: Int?; let maxSeconds: Double?
        let splits: Bool          // longer clips become several pieces in order (Stories, Status)
    }

    static let places: [Place] = [
        Place(id: "wa", name: "WhatsApp chat", icon: "message.fill", maxBytes: 16_000_000, maxSeconds: nil, splits: false),
        Place(id: "email", name: "Email", icon: "envelope.fill", maxBytes: 20_000_000, maxSeconds: nil, splits: false),
        Place(id: "discord", name: "Discord", icon: "bubble.left.and.bubble.right.fill", maxBytes: 10_000_000, maxSeconds: nil, splits: false),
        Place(id: "imessage", name: "iMessage", icon: "message.badge.filled.fill", maxBytes: 100_000_000, maxSeconds: nil, splits: false),
    ]

    struct Plan: Equatable {
        var pieces: [ClosedRange<Double>]
        var targetBytes: Int?            // per piece; nil = no shrink needed
        var lines: [String]              // what will happen, in plain words
    }

    /// Pure: how a clip of `duration` seconds and `bytes` becomes right for `place`.
    static func plan(duration: Double, bytes: Int, place: Place) -> Plan {
        var pieces: [ClosedRange<Double>] = [0...max(0, duration)]
        var lines: [String] = []
        if let maxS = place.maxSeconds, duration > maxS + 0.2 {
            if place.splits {
                let n = Int((duration / maxS).rounded(.up))
                let each = duration / Double(n)
                pieces = (0..<n).map { Double($0) * each...min(duration, Double($0 + 1) * each) }
                lines.append("Split into \(n) parts of \(Int(each.rounded())) s, in order")
            } else {
                pieces = [0...maxS]
                lines.append("\(place.name) takes up to \(clock(maxS)) — keeps the first \(clock(maxS)) (trim first to choose another part)")
            }
        } else {
            lines.append("Length \(clock(duration)) fits")
        }
        var target: Int?
        if let maxB = place.maxBytes {
            let longest = pieces.map { $0.upperBound - $0.lowerBound }.max() ?? duration
            let estimate = Int(Double(bytes) * longest / max(0.1, duration))
            let limit = Int(Double(maxB) * 0.95)
            if estimate > limit {
                target = limit
                lines.append("Shrunk to just under \(mb(maxB)) — as sharp as fits")
            } else {
                lines.append("Already under \(mb(maxB)) — original quality kept")
            }
        } else {
            lines.append("Original quality kept")
        }
        return Plan(pieces: pieces, targetBytes: target, lines: lines)
    }

    static func clock(_ s: Double) -> String { let t = Int(s.rounded()); return t >= 60 ? "\(t / 60):\(String(format: "%02d", t % 60))" : "\(t) s" }
    static func mb(_ b: Int) -> String { "\(b / 1_000_000) MB" }

    /// Do it: cut each piece, shrink it if the plan says so. Returns the files in order.
    static func make(_ src: URL, plan: Plan, duration: Double, progress: @escaping (Double) -> Void) async -> [URL] {
        var out: [URL] = []
        for (i, r) in plan.pieces.enumerated() {
            let whole = plan.pieces.count == 1 && r.lowerBound < 0.05 && r.upperBound > duration - 0.05
            var piece: URL? = whole ? src : await VideoEngine.trim(src, start: r.lowerBound, end: r.upperBound)
            if let t = plan.targetBytes, let p = piece, (SizeTarget.fileSize(p) ?? .max) > t {
                let base = Double(i) / Double(plan.pieces.count), span = 1 / Double(plan.pieces.count)
                piece = await SizeTarget.videoBestEffort(url: p, targetBytes: t, progress: { progress(base + $0 * span) })?.url
            }
            if let piece { out.append(piece) }
            progress(Double(i + 1) / Double(plan.pieces.count))
        }
        return out
    }
}
