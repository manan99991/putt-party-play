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
