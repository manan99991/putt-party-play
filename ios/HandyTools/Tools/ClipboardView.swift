import SwiftUI
import UIKit

struct ClipboardView: View {
    @State private var clips = ClipStore.all()
    @State private var toast: String?
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ToolPage(title: "Multi-Clipboard", subtitle: "Apple won't let apps watch the clipboard, so you feed the stack three ways. Paste from the keyboard anywhere.") {
            Button { grab() } label: { Label("Grab what's on the clipboard now", systemImage: "arrow.down.doc").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large)

            GroupBox("Set up once") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Settings › General › Keyboard › Keyboards › Add “HandyTools Clips”, then Allow Full Access.", systemImage: "keyboard")
                    Label("Share Sheet › “Save to Clips” works from any app (Safari, Notes, Messages).", systemImage: "square.and.arrow.up")
                    Label("In any text field, tap 🌐 to switch to the Clips keyboard and tap a clip to paste it.", systemImage: "hand.tap")
                }.font(.footnote)
                Button("Open keyboard settings") { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }.font(.footnote)
            }

            HStack {
                Text("Stack (\(clips.count))").font(.headline); Spacer()
                Button("Copy all") { UIPasteboard.general.string = clips.map(\.text).joined(separator: "\n"); toast = "Copied \(clips.count) items" }
                Button("Clear") { ClipStore.clearUnpinned(); reload() }
            }.font(.subheadline)

            ForEach(clips) { c in
                HStack {
                    Text((c.pinned ? "📌 " : "") + c.text).lineLimit(3)
                    Spacer()
                }
                .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .onTapGesture { UIPasteboard.general.string = c.text; toast = "Ready to paste" }
                .contextMenu {
                    Button(c.pinned ? "Unpin" : "Pin") { ClipStore.togglePin(c.id); reload() }
                    Button("Delete", role: .destructive) { ClipStore.remove(c.id); reload() }
                }
            }
            if let t = toast { Text(t).font(.caption).foregroundStyle(.tint) }
        }
        .onChange(of: phase) { _, p in if p == .active { grab() } } // auto-grab whenever the app comes to front
        .onAppear(perform: reload)
    }

    private func grab() {
        if UIPasteboard.general.hasStrings, let s = UIPasteboard.general.string, ClipStore.add(s) { toast = "Added to stack" }
        reload()
    }
    private func reload() { clips = ClipStore.all() }
}
