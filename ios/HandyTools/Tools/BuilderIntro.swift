import SwiftUI

/// The short "how this works" shown at the top of Build your own until the person says Got it. Three ideas, each with
/// a real example, and one button that opens a ready-made tool in the builder so they can watch its steps work on a sample.
enum BuilderIntro {
    struct Page: Equatable { let icon: String; let title: String; let body: String }

    static let pages = [
        Page(icon: "square.and.arrow.down.on.square", title: "1. Start with what you have",
             body: "A photo, a scan, a PDF, a video, a recording, a link, some text, something you say, or a contact."),
        Page(icon: "square.stack.3d.up", title: "2. Stack small steps",
             body: "Hide private details, shrink it, read it, translate it, sign it. You only see steps that fit, and that your phone can run."),
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
}

struct BuilderIntroCard: View {
    var onShow: () -> Void
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Text("Make a tool that does the whole job").font(HandyFont.cardTitle)
            ForEach(BuilderIntro.pages, id: \.title) { p in
                HStack(alignment: .top, spacing: HandySpacing.s12) {
                    Image(systemName: p.icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(HandyColor.accent)
                        .frame(width: 34, height: 34).background(HandyColor.accentSoft, in: Circle()).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.title).font(HandyFont.bodyStrong)
                        Text(p.body).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            HStack(spacing: HandySpacing.s12) {
                Button(action: onShow) { Label("Show me one", systemImage: "play.fill").frame(maxWidth: .infinity) }.primaryButton().accessibilityIdentifier("intro-show")
                Button("Got it", action: onDone).secondaryButton().fixedSize().accessibilityIdentifier("intro-done")
            }
        }.cardStyle()
    }
}
