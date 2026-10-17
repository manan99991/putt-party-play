import SwiftUI
import WidgetKit

/// One note, always one tap away: edit here, read it on a home-screen or lock-screen widget.
struct StickyNotesView: View {
    @State private var text = NoteStore.text
    @FocusState private var editing: Bool

    var body: some View {
        ToolPage(title: "Sticky Note", subtitle: "Edit here. Add the “Sticky Note” widget to your home or lock screen to see it everywhere.") {
            TextEditor(text: $text)
                .focused($editing)
                .scrollContentBackground(.hidden)
                .font(HandyFont.body)
                .frame(minHeight: 200, maxHeight: 420)
                .padding(HandySpacing.s12)
                .background(HandyColor.sticky, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
                .onChange(of: text) { _, t in NoteStore.text = t; WidgetCenter.shared.reloadTimelines(ofKind: "StickyWidget") }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { editing = false }.fontWeight(.semibold)
                    }
                }
            HStack(spacing: HandySpacing.s12) {
                if !text.isEmpty {
                    Button { UIPasteboard.general.string = text; HandyHaptics.light() } label: { Label("Copy", systemImage: "doc.on.doc") }.compactButton()
                    Button { text = ""; NoteStore.text = ""; WidgetCenter.shared.reloadTimelines(ofKind: "StickyWidget") } label: { Label("Clear", systemImage: "trash") }.textButton()
                }
            }
            LimitNote("Long-press your home screen › Edit › Add Widget › Tenzy.")
        }
    }
}
