import SwiftUI
import WidgetKit

/// One note, always one tap away: edit here, read it on a home-screen or lock-screen widget.
struct StickyNotesView: View {
    @State private var text = NoteStore.text
    var body: some View {
        ToolPage(title: "Sticky Note", subtitle: "Edit here. Add the “Sticky Note” widget to your home or lock screen to see it everywhere.") {
            TextEditor(text: $text)
                .frame(minHeight: 260)
                .padding(8)
                .background(Color.yellow.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
                .onChange(of: text) { _, t in NoteStore.text = t; WidgetCenter.shared.reloadTimelines(ofKind: "StickyWidget") }
            Text("Long-press your home screen › Edit › Add Widget › HandyTools.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
