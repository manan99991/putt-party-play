import SwiftUI

/// The finish for anything read aloud — the same for every ready-made "listen" tool and any built tool that ends in
/// Read it aloud: play it at the speed you like (1× to 2×), skip back or forward, see how long it is, read the words
/// it says, and share it or keep it in Files for later.
struct ListenFinishCard: View {
    let url: URL
    var text: String?
    @State private var showWords = false

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Label(L("Ready to listen"), systemImage: "headphones").font(HandyFont.bodyStrong)
            AudioResultPreview(url: url, speeds: true)
            if let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                let words = t.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
                DisclosureGroup(isExpanded: $showWords) {
                    ScrollView { Text(t).font(HandyFont.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                        .frame(maxHeight: 260)
                } label: {
                    Text("\(L("The words it reads")) · \(words)").font(HandyFont.caption)
                }
                .accessibilityIdentifier("listen-words")
            }
            ShareLink(item: url) { Label(L("Share or save to Files"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("listen-finish")
    }
}
