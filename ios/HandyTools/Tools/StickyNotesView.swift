import SwiftUI
import WidgetKit

/// One note, always one tap away: edit here, read it on a home-screen or lock-screen widget.
struct StickyNotesView: View {
    @State private var text = NoteStore.text
    var body: some View {
        ToolPage(title: "Sticky Note", subtitle: "Edit here. Add the “Sticky Note” widget to your home or lock screen to see it everywhere.") {
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .font(HandyFont.body)
                .frame(minHeight: 260)
                .padding(HandySpacing.s12)
                .background(HandyColor.sticky, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
                .rotationEffect(.degrees(-0.5))
                .onChange(of: text) { _, t in NoteStore.text = t; WidgetCenter.shared.reloadTimelines(ofKind: "StickyWidget") }
            LimitNote("Long-press your home screen › Edit › Add Widget › HandyTools.")
        }
    }
}
