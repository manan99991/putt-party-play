import SwiftUI
import UIKit

struct ClipboardView: View {
    @State private var clips = ClipStore.all()
    @State private var toast: String?
    @State private var ghost = ""
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ToolPage(title: "Multi-Clipboard", subtitle: "Apple won't let apps watch the clipboard, so you feed the stack three ways. Paste from the keyboard anywhere.") {
            Button { grab() } label: { Label("Grab what's on the clipboard now", systemImage: "arrow.down.doc").frame(maxWidth: .infinity) }
                .primaryButton()
            // Ghost preview: the first 40 characters of the current clipboard under the Grab button.
            if !ghost.isEmpty {
                Text(ghost).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
            }

            SetupCard(title: "Set up once (2 minutes)") {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Label("Settings › General › Keyboard › Keyboards › Add “HandyTools Clips”, then Allow Full Access.", systemImage: "keyboard")
                    Label("Share Sheet › “Save to Clips” works from any app (Safari, Notes, Messages).", systemImage: "square.and.arrow.up")
                    Label("In any text field, tap 🌐 to switch to the Clips keyboard and tap a clip to paste it.", systemImage: "hand.tap")
                }
                .font(.system(size: 14)).foregroundStyle(HandyColor.textPrimary)
                Text("Full Access is used only to read the clipboard when you tap Grab. Nothing leaves your phone.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Button("Open keyboard settings") { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }.compactButton()
            }

            // Hero: 3-step illustrated row (keyboard → share → globe key), step numbers in accent circles.
            HStack(spacing: HandySpacing.s8) {
                ForEach(Array([("keyboard", "Add the keyboard"), ("square.and.arrow.up", "Save via Share"), ("globe", "Tap the globe key")].enumerated()), id: \.offset) { i, s in
                    VStack(spacing: HandySpacing.s4) {
                        ZStack {
                            Circle().fill(HandyColor.accent).frame(width: 28, height: 28)
                            Text("\(i + 1)").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        }
                        Image(systemName: s.0).font(.system(size: 22)).foregroundStyle(HandyColor.accent)
                        Text(s.1).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture { HandyHaptics.light() }
                }
            }

            HStack {
                Text("Stack (\(clips.count))").font(HandyFont.cardTitle); Spacer()
                Button("Copy all") { UIPasteboard.general.string = clips.map(\.text).joined(separator: "\n"); toast = "Copied \(clips.count) items" }.textButton()
                Button("Clear") { ClipStore.clearUnpinned(); reload() }.textButton()
            }
            if clips.isEmpty { EmptyState(icon: "doc.on.clipboard", line: "Copy something in any app — it shows up here.") }
            ForEach(Array(clips.enumerated()), id: \.element.id) { i, c in
                HStack {
                    Text((c.pinned ? "📌 " : "") + c.text).font(HandyFont.body).lineLimit(3)
                    Spacer()
                }
                .cardStyle(padding: HandySpacing.s12)
                .rotationEffect(.degrees(i < 3 ? (i % 2 == 0 ? -1 : 1) : 0), anchor: .center)
                .handyListEntrance(index: i)
                .onTapGesture { UIPasteboard.general.string = c.text; toast = "Ready to paste" }
                .contextMenu {
                    Button(c.pinned ? "Unpin" : "Pin") { ClipStore.togglePin(c.id); reload() }
                    Button("Delete", role: .destructive) { ClipStore.remove(c.id); reload() }
                }
            }
            if let t = toast { Text(t).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
        }
        .onChange(of: phase) { _, p in if p == .active { grab() } } // auto-grab whenever the app comes to front
        .onAppear(perform: reload)
    }

    private func grab() {
        if UIPasteboard.general.hasStrings, let s = UIPasteboard.general.string, ClipStore.add(s) {
            toast = "Added to stack"
            HandyHaptics.medium()
        }
        reload()
    }
    private func reload() {
        clips = ClipStore.all()
        ghost = String((UIPasteboard.general.string ?? "").prefix(40))
    }
}
