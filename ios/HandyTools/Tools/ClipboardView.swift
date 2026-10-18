import SwiftUI
import UIKit

/// Clipboard — a stack of everything you've copied (fed by the keyboard, the share sheet, or a tap),
/// searchable, pinnable, with one-tap actions on what's inside: clean a tracking-laden link, call the
/// number, open the address. Plus Snippets: the addresses, replies and codes you type every week.
struct ClipboardView: View {
    @State private var clips = ClipStore.all()
    @State private var snippets = SnippetStore.all()
    @State private var toast: String?
    @State private var ghost = ""
    @State private var query = ""
    @State private var tab = 0
    @State private var newSnippetTitle = ""
    @State private var newSnippetText = ""
    @State private var addingSnippet = false
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ToolPage(title: "Clipboard", subtitle: "Everything you copy, kept and searchable — with the link cleaned and the number callable. Plus your snippets.") {
            Picker("", selection: $tab) { Text("Stack (\(clips.count))").tag(0); Text("Snippets (\(snippets.count))").tag(1) }.pickerStyle(.segmented)
            if tab == 0 { stackPanel } else { snippetPanel }
            if let t = toast { Text(t).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
        }
        .onChange(of: phase) { _, p in if p == .active { grab() } }
        .onAppear(perform: reload)
    }

    // MARK: stack

    private var stackPanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Button { grab() } label: { Label("Grab what's on the clipboard now", systemImage: "arrow.down.doc").frame(maxWidth: .infinity) }.primaryButton()
            if !ghost.isEmpty { Text(ghost).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2) }
            DisclosureGroup {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Label("Settings › General › Keyboard › Keyboards › Add “Tenzy Clips”, then Allow Full Access.", systemImage: "keyboard")
                    Label("Share Sheet › “Save to Clips” works from any app.", systemImage: "square.and.arrow.up")
                    Label("In any text field, tap 🌐 to switch to the Clips keyboard and tap a clip to paste it.", systemImage: "hand.tap")
                    Text("Full Access is only used to read the clipboard when you tap Grab. Nothing leaves your phone.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Button("Open keyboard settings") { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }.compactButton()
                }.font(.system(size: 14)).padding(.top, 4)
            } label: { Label("Feed the stack from any app (2-minute setup)", systemImage: "info.circle").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }

            if clips.count > 3 {
                TextField("Search clips", text: $query).padding(HandySpacing.s8).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            HStack {
                Spacer()
                Button("Copy all") { UIPasteboard.general.string = clips.map(\.text).joined(separator: "\n"); toast = "Copied \(clips.count) items" }.textButton()
                Button("Clear unpinned") { ClipStore.clearUnpinned(); reload() }.textButton()
            }
            if clips.isEmpty { EmptyState(icon: "doc.on.clipboard", line: "Copy something in any app, then tap Grab — it shows up here.") }
            ForEach(clips.filter { query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) }) { c in clipRow(c) }
        }
    }

    private func clipRow(_ c: Clip) -> some View {
        let isLink = LinkCleaner.isURL(c.text)
        let cleaned = isLink ? LinkCleaner.clean(c.text) : c.text
        let actions = isLink ? [] : Array(Detected.scan(c.text).prefix(3))
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(alignment: .top) {
                Text((c.pinned ? "📌 " : "") + c.text).font(HandyFont.body).lineLimit(4).textSelection(.enabled)
                Spacer()
                Text(c.createdAt.formatted(.relative(presentation: .named))).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            HStack(spacing: HandySpacing.s8) {
                Button { UIPasteboard.general.string = c.text; toast = "Ready to paste"; HandyHaptics.light() } label: { Label("Copy", systemImage: "doc.on.doc") }.compactButton()
                if isLink {
                    if cleaned != c.text {
                        Button { UIPasteboard.general.string = cleaned; toast = "Copied the clean link (tracking removed)"; HandyHaptics.success() } label: { Label("Clean link", systemImage: "sparkles") }.compactButton()
                    }
                    if let u = URL(string: cleaned) { Link(destination: u) { Label("Open", systemImage: "safari") }.compactButton() }
                }
                ForEach(actions) { a in Link(destination: a.url) { Label(a.label, systemImage: a.icon).lineLimit(1) }.compactButton() }
                Spacer()
                Menu {
                    Button(c.pinned ? "Unpin" : "Pin") { ClipStore.togglePin(c.id); reload() }
                    Button { addingSnippet = true; newSnippetText = c.text; newSnippetTitle = String(c.text.prefix(24)); tab = 1 } label: { Text("Save as snippet") }
                    ShareLink(item: c.text) { Text("Share") }
                    Button("Delete", role: .destructive) { ClipStore.remove(c.id); reload() }
                } label: { Image(systemName: "ellipsis.circle").font(.system(size: 20)).foregroundStyle(HandyColor.textSecondary) }
            }
            if isLink, cleaned != c.text { Text(cleaned).font(HandyFont.micro).foregroundStyle(HandyColor.success).lineLimit(2) }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    // MARK: snippets

    private var snippetPanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Text("Things you type every week — your address, an email sign-off, a Wi-Fi password, a canned reply. One tap copies; the Clips keyboard pastes them anywhere.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            if addingSnippet {
                VStack(spacing: HandySpacing.s8) {
                    TextField("Title (e.g. Home address)", text: $newSnippetTitle).padding(HandySpacing.s8).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    TextEditor(text: $newSnippetText).frame(minHeight: 80).padding(4).scrollContentBackground(.hidden).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    HStack {
                        Button("Cancel") { addingSnippet = false; newSnippetText = ""; newSnippetTitle = "" }.textButton()
                        Spacer()
                        Button { SnippetStore.add(title: newSnippetTitle, text: newSnippetText); snippets = SnippetStore.all(); addingSnippet = false; newSnippetText = ""; newSnippetTitle = ""; HandyHaptics.success() } label: { Text("Save snippet") }.compactButton().disabled(newSnippetText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }.cardStyle(padding: HandySpacing.s12)
            } else {
                Button { addingSnippet = true } label: { Label("New snippet", systemImage: "plus").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if snippets.isEmpty && !addingSnippet { EmptyState(icon: "text.badge.plus", line: "No snippets yet. Save your address, signature or a canned reply.") }
            ForEach(snippets) { s in
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text(s.title.isEmpty ? String(s.text.prefix(30)) : s.title).font(HandyFont.bodyStrong); Spacer()
                        Button(role: .destructive) { SnippetStore.remove(s.id); snippets = SnippetStore.all() } label: { Image(systemName: "trash").foregroundStyle(HandyColor.textSecondary) }.buttonStyle(.plain) }
                    Text(s.text).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(3)
                }
                .cardStyle(padding: HandySpacing.s12)
                .onTapGesture { UIPasteboard.general.string = s.text; toast = "“\(s.title.isEmpty ? "Snippet" : s.title)” ready to paste"; HandyHaptics.light() }
            }
        }
    }

    private func grab() {
        if UIPasteboard.general.hasStrings, let s = UIPasteboard.general.string, ClipStore.add(s) { toast = "Added to stack"; HandyHaptics.medium() }
        reload()
    }
    private func reload() {
        clips = ClipStore.all(); snippets = SnippetStore.all()
        ghost = String((UIPasteboard.general.string ?? "").prefix(40))
    }
}
