import SwiftUI
import UIKit

/// On-screen (global) frames of selectable cells, keyed by a stable string id. Published by
/// `.paintCell(id)` on each cell and read by the paint-to-select gesture so a drag knows which
/// thumbnail or row the finger is currently over.
struct PaintCellFrames: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, b in b }
    }
}

extension View {
    /// Publish this cell's on-screen frame so a paint-drag can hit-test it.
    func paintCell(_ id: String) -> some View {
        background(GeometryReader { p in
            Color.clear.preference(key: PaintCellFrames.self, value: [id: p.frame(in: .global)])
        })
    }
}

/// Apple Photos-style drag-to-select. Only while `active` (a "Select" mode the user turns on) does a
/// one-finger drag paint a run of cells — adding them, or removing if the sweep starts on an already
/// selected one — and auto-scroll when the finger nears the top or bottom edge. When inactive it adds
/// no gesture at all, so ordinary scrolling and taps behave exactly as before.
struct PaintSelect: ViewModifier {
    let active: Bool
    let frames: [String: CGRect]
    @Binding var selected: Set<String>
    let proxy: ScrollViewProxy

    @State private var adding: Bool? = nil          // nil until the first cell decides add vs remove
    @State private var painted: Set<String> = []    // cells already handled this sweep (no flicker)
    @State private var lastScroll = Date.distantPast

    @ViewBuilder
    func body(content: Content) -> some View {
        if active {
            content.highPriorityGesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .onChanged { paint(at: $0.location) }
                    .onEnded { _ in adding = nil; painted = [] }
            )
        } else {
            content
        }
    }

    private func paint(at loc: CGPoint) {
        if let id = frames.first(where: { $0.value.contains(loc) })?.key {
            if adding == nil { adding = !selected.contains(id) }
            if !painted.contains(id) {
                painted.insert(id)
                if adding == true { selected.insert(id) } else { selected.remove(id) }
                HandyHaptics.light()
            }
            // Edge auto-scroll so a sweep can run past what's on screen, throttled so it glides.
            let screenH = UIScreen.main.bounds.height
            let now = Date()
            if (loc.y > screenH - 150 || loc.y < 170), now.timeIntervalSince(lastScroll) > 0.1 {
                lastScroll = now
                let edge: UnitPoint = loc.y < 170 ? .top : .bottom
                withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo(id, anchor: edge) }
            }
        }
    }
}

extension View {
    /// Attach to the container that holds the cells (each tagged with `.paintCell(id)`).
    func paintSelect(active: Bool, frames: [String: CGRect], selected: Binding<Set<String>>, proxy: ScrollViewProxy) -> some View {
        modifier(PaintSelect(active: active, frames: frames, selected: selected, proxy: proxy))
    }
}
