import SwiftUI

// ---------------------------------------------------------------------------------------------
// Motion helpers (prompt 1). Everything funnels through HandyMotion tokens; no hard-coded times.
// ---------------------------------------------------------------------------------------------

/**
 * List-item entrance: fade + 8pt slide over base, staggered 30ms, max 6 staggered.
 * Under Reduce Motion this is a crossfade only.
 *
 * Call site for the home grid (App.swift HomeView): `.handyListEntrance(index:)`
 * on each grid cell — the modifier lives here so App.swift needs only that one line.
 */
struct HandyListEntrance: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : (reduceMotion ? 0 : HandyMotion.listSlide))
            .task {
                try? await Task.sleep(for: .milliseconds(Int(HandyMotion.listDelay(index: index) * 1000)))
                withAnimation(reduceMotion ? HandyMotion.crossfade : .easeOut(duration: HandyMotion.base)) {
                    shown = true
                }
            }
    }
}

extension View {
    func handyListEntrance(index: Int) -> some View {
        modifier(HandyListEntrance(index: index))
    }
}
