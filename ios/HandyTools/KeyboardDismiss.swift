import UIKit

/// App-wide "tap anywhere outside a text field to put the keyboard away." Installs one tap gesture on
/// the key window with `cancelsTouchesInView = false`, so it dismisses the keyboard without swallowing
/// button taps, scrolls or other controls. Installed once, after the first frame.
@MainActor
final class KeyboardDismiss {
    static let shared = KeyboardDismiss()
    private var installed = false

    @objc private func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func install() {
        guard !installed,
              let window = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first
        else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        tap.cancelsTouchesInView = false          // don't eat button/scroll taps
        tap.requiresExclusiveTouchType = false
        window.addGestureRecognizer(tap)
        installed = true
    }
}
