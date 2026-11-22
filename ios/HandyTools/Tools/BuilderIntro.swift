import SwiftUI

/// The short "how this works" shown at the top of Build your own until the person says Got it. Three ideas, each with
/// a real example, and one button that opens a ready-made tool in the builder so they can watch its steps work on a sample.
enum BuilderIntro {
    struct Page: Equatable { let icon: String; let title: String; let body: String }

    static let pages = [
        Page(icon: "square.and.arrow.down.on.square", title: "1. Start with what you have",
             body: "A photo, a scan, a PDF, a video, a recording, a link, some text, something you say, or a contact."),
        Page(icon: "square.stack.3d.up", title: "2. Stack small steps",
             body: "Hide private details, shrink it, read it, translate it, sign it. The basic steps are free; the rest unlock with Tenzy Pro. You only see steps that fit, and that your phone can run."),
        Page(icon: "paperplane", title: "3. Choose how it ends",
             body: "Share it, open an email ready to send, add a row to a sheet. Add a reminder and it comes back on schedule."),
    ]

    /// The starter opened by "Show me one": three steps, each visible on the sample.
    static let demoID = "share-shield"

    /// Starters for what the person has in hand. nil shows all of them.
    static func starters(for kind: ChainKind?, in all: [Chain] = ChainTemplates.all) -> [Chain] {
        guard let kind else { return all }
        return all.filter { ($0.steps.first?.block.takes ?? .image) == kind }
    }

    /// Start-to-finish jobs (several steps, or a step that ends in an email or message) lead each list,
    /// so the most complete tools are seen first. Stable otherwise.
    static func jobsFirst(_ list: [Chain]) -> [Chain] {
        list.enumerated().sorted { a, b in
            let ja = a.element.steps.count > 1 || a.element.finish != nil, jb = b.element.steps.count > 1 || b.element.finish != nil
            return ja != jb ? ja : a.offset < b.offset
        }.map(\.element)
    }

    /// The template sheet's sections, by what you start with. Every starter is in exactly one.
    static func sections(in all: [Chain] = ChainTemplates.all) -> [(title: String, kind: ChainKind, chains: [Chain])] {
        let order: [(String, ChainKind)] = [("Photos & scans", .image), ("Text, links & messages", .text), ("Video", .video), ("Sound & voice", .audio), ("PDF", .pdf)]
        var out: [(title: String, kind: ChainKind, chains: [Chain])] = []
        for (title, kind) in order {
            var c = jobsFirst(starters(for: kind, in: all))
            if kind == .audio {
                // The fun voices get their own shelf, so they're easy to find and don't bury the useful ones.
                let voices = c.filter { $0.steps.first?.block == .voiceChange }
                c.removeAll { $0.steps.first?.block == .voiceChange }
                if !c.isEmpty { out.append((title, kind, c)) }
                if !voices.isEmpty { out.append(("Funny voices", kind, voices)) }
                continue
            }
            if !c.isEmpty { out.append((title, kind, c)) }
        }
        return out
    }

    /// Bigger jobs that need a whole screen rather than a few steps — each opens a full Tenzy tool.
    struct BigJob: Equatable { let id: String; let name: String; let line: String; let icon: String }
    static let bigJobs = [
        BigJob(id: "cards", name: "Scan a stack of business cards into contacts", line: "Both sides, edit any field, never a duplicate.", icon: "person.text.rectangle"),
        BigJob(id: "untangle", name: "Plan my day around how I feel", line: "Say everything on your plate; get steps, rests and check-ins.", icon: "scribble.variable"),
        BigJob(id: "medreminder", name: "Remind me to take my medicine", line: "Each dose on time, with Taken and Snooze on the alert.", icon: "pills.fill"),
        BigJob(id: "daydiary", name: "Keep a private diary of my days", line: "Good or bad in one tap, say why, look back by month.", icon: "heart.text.square"),
        BigJob(id: "meetingnotes", name: "Turn a meeting into notes and to-dos", line: "Who said what, the to-dos, and an email ready to send.", icon: "person.wave.2.fill"),
        BigJob(id: "sticker", name: "Make a pack of stickers from my photos", line: "Looks, outlines and a printable sheet.", icon: "scissors"),
        BigJob(id: "warranty", name: "Keep receipts and warranties in one place", line: "Never miss a return date or a warranty.", icon: "shippingbox.fill"),
        BigJob(id: "cleaner", name: "Free up space on my phone", line: "Duplicates, big videos and old screenshots, reviewed first.", icon: "sparkles"),
    ]
}

struct BuilderIntroCard: View {
    var onShow: () -> Void
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Text(L("Make a tool that does the whole job")).font(HandyFont.cardTitle)
            ForEach(BuilderIntro.pages, id: \.title) { p in
                HStack(alignment: .top, spacing: HandySpacing.s12) {
                    Image(systemName: p.icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(HandyColor.accent)
                        .frame(width: 34, height: 34).background(HandyColor.accentSoft, in: Circle()).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L(p.title)).font(HandyFont.bodyStrong)
                        Text(L(p.body)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            HStack(spacing: HandySpacing.s12) {
                Button(action: onShow) { Label(L("Show me one"), systemImage: "play.fill").frame(maxWidth: .infinity) }.primaryButton().accessibilityIdentifier("intro-show")
                Button(L("Got it"), action: onDone).secondaryButton().fixedSize().accessibilityIdentifier("intro-done")
            }
        }.cardStyle()
    }
}
