import SwiftUI
import UIKit

/// Reading what the person copied, the same way at every Paste button.
enum Clipboard {
    /// What was copied, as text. A link copied from Safari, Photos or a share sheet often arrives as a URL with
    /// no plain-text copy, so `UIPasteboard.string` alone came back empty while the app said "Link copied".
    static var text: String? {
        let pb = UIPasteboard.general
        let s = pb.string ?? pb.url?.absoluteString ?? pb.urls?.first?.absoluteString
        guard let s, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return s
    }
}

extension Clipboard {
    /// Text (or a link) from what the system paste control handed over.
    static func load(_ providers: [NSItemProvider], _ done: @escaping (String) -> Void) {
        func give(_ s: String?) {
            guard let s, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            DispatchQueue.main.async { done(s) }
        }
        if let p = providers.first(where: { $0.canLoadObject(ofClass: String.self) }) {
            _ = p.loadObject(ofClass: String.self) { o, _ in give(o as? String) }
        } else if let p = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) {
            _ = p.loadObject(ofClass: URL.self) { o, _ in give((o as? URL)?.absoluteString) }
        }
    }
}

/// Paste, the iOS way: the system's own control reads what was copied with no "Allow Paste?" question, and it
/// can't be refused. Every Paste in the app is this button, so pasting never asks for permission anywhere.
struct PasteTextButton: View {
    var wide = false
    let onText: (String) -> Void
    var body: some View {
        PasteButton(supportedContentTypes: [.plainText, .url]) { providers in Clipboard.load(providers, onText) }
            .labelStyle(.titleAndIcon)
            .buttonBorderShape(.capsule)
            .tint(HandyColor.accent)
            .frame(maxWidth: wide ? .infinity : nil)
    }
}
