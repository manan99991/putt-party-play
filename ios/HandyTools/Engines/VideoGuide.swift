import Foundation

/// "What to do with it" for a video, in the words people actually think in: post it, make it stunning, cut it
/// shorter, send it, make it funny, slow it down, keep just the sound, get the words, grab a photo. Every way Tenzy
/// has to work on a video lands in exactly one of these, so the whole choice fits on one screen and nothing shows
/// twice. Pure, so it's unit-tested.
extension Guide {
    /// The order the jobs are shown in. "stunning" is the big card at the top; the rest are the grid.
    static let videoGoalIDs = ["stunning", "post", "cut", "send", "fun", "speed", "sound", "words", "photo"]

    static func videoGoal(_ id: String) -> Goal {
        switch id {
        case "stunning": return Goal(id: id, title: "Make it stunning", line: "Effects, filters, light and festive magic", icon: "wand.and.stars")
        case "post":     return Goal(id: id, title: "Post it", line: "TikTok, Reels, Shorts and more", icon: "play.square.stack.fill")
        case "cut":      return Goal(id: id, title: "Cut it shorter", line: "Keep just the best part", icon: "scissors")
        case "send":     return Goal(id: id, title: "Send it", line: "Small enough for any chat or email", icon: "paperplane.fill")
        case "fun":      return Goal(id: id, title: "Make it funny", line: "Boomerang, GIF, silly voices", icon: "face.smiling.inverse")
        case "speed":    return Goal(id: id, title: "Slow-mo or fast", line: "Voices stay natural", icon: "gauge.with.dots.needle.67percent")
        case "sound":    return Goal(id: id, title: "Sound only, or none", line: "MP3, ringtone, or mute it", icon: "waveform")
        case "words":    return Goal(id: id, title: "Get the words", line: "Captions and notes", icon: "captions.bubble.fill")
        case "photo":    return Goal(id: id, title: "Grab a photo", line: "Any moment as a picture", icon: "camera.viewfinder")
        default:         return Goal(id: "more", title: "Something else", line: "Every other way to use it", icon: "ellipsis.circle.fill")
        }
    }

    /// Which job one way of working on a video does.
    static func videoGoal(of o: Option) -> String {
        switch o {
        case .voices: return "fun"
        case .tool(let t):
            switch t {
            case "video": return "cut"
            case "fitit": return "send"
            case "post": return "post"
            case "celebrate", "videofx": return "stunning"
            case "audiomix": return "speed"
            case "audioconvert", "ringtone", "audioclean", "audioedit", "audiocompress": return "sound"
            case "meetingnotes": return "words"
            default: return "more"
            }
        case .chain(let c):
            let blocks = Set(c.steps.map(\.block))
            if blocks.contains(.postTo) { return "post" }
            if c.finish?.kind == .mail || blocks.contains(.videoShrink) || blocks.contains(.chatLink) { return "send" }
            if blocks.contains(.videoVertical) || (blocks.contains(.videoCaptions) && blocks.contains(.videoTrim)) { return "post" }
            if blocks.contains(.videoCelebrate) { return "stunning" }
            if blocks.contains(.videoLoop) || blocks.contains(.videoGif) || blocks.contains(.voiceChange) { return "fun" }
            if blocks.contains(.videoSpeed) { return "speed" }
            if blocks.contains(.videoStill) { return "photo" }
            if blocks.contains(.videoCaptions) || blocks.contains(.speechText) || blocks.contains(.summarize) || blocks.contains(.translate) { return "words" }
            if blocks.contains(.videoMute) || blocks.contains(.videoAudio) { return "sound" }
            if blocks.contains(.videoTrim) { return "cut" }
            if blocks.contains(.videoRotate) { return "post" }
            return "more"
        }
    }

    /// Ways listed first in their job: the one most people mean.
    private static let videoFirst = ["tool-post", "tool-videofx", "chain-reel-captions", "tool-video", "chain-video-chat", "chain-video-boomerang", "chain-video-slowmo", "tool-audioconvert", "chain-video-quiet", "tool-audioclean", "chain-video-words", "chain-video-still"]

    /// Every way to work on this video, sorted into the jobs (in `videoGoalIDs` order, empty jobs left out).
    /// Anything that fits no job goes in "Something else" at the end, so nothing is ever lost.
    static func videoJobs(_ options: [Option]) -> [(goal: String, options: [Option])] {
        var by: [String: [Option]] = [:], seen = Set<String>()
        for o in options where seen.insert(o.id).inserted { by[videoGoal(of: o), default: []].append(o) }
        var out: [(goal: String, options: [Option])] = []
        for g in videoGoalIDs {
            guard let list = by.removeValue(forKey: g), !list.isEmpty else { continue }
            let sorted = list.enumerated().sorted { a, b in
                let ra = videoFirst.firstIndex(of: a.element.id) ?? Int.max, rb = videoFirst.firstIndex(of: b.element.id) ?? Int.max
                return ra != rb ? ra < rb : a.offset < b.offset
            }.map(\.element)
            out.append((goal: g, options: sorted))
        }
        let rest = by.values.flatMap { $0 }
        if !rest.isEmpty { out.append((goal: "more", options: rest)) }
        return out
    }

    /// What Tenzy noticed about the video, and the job that fits it best, in one plain line.
    static func videoHint(bytes: Int, seconds: Double, tall: Bool) -> (goal: String, why: String) {
        if bytes > 16_000_000 { return ("send", "Too big for WhatsApp — Send it makes it fit") }
        if !tall, seconds > 0, seconds <= 90 { return ("post", "It's sideways — Post it makes it tall") }
        if seconds > 60 { return ("cut", "It's long — Cut it shorter keeps the best part") }
        return ("stunning", "Ready to shine — try Make it stunning")
    }
}
