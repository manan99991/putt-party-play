import SwiftUI

/// See & Read — one door for making sense of what's in front of you. Read text (aloud, in plain
/// English, or boiled to the gist), hear a spoken description of a scene, or magnify small print in
/// high contrast. Brings the old Lens, Scene Describer and Magnifier together so there's a single
/// obvious place to go instead of three overlapping ones.
struct SeeReadView: View {
    enum Mode: String, CaseIterable { case read, describe, magnify }
    @State private var mode: Mode = .read

    var body: some View {
        ToolPage(title: "See & Read", subtitle: "Read any text, hear what the camera sees, or magnify small print — whatever helps you make sense of what's in front of you.") {
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(Mode.allCases, id: \.rawValue) { m in HChip(text: title(m), selected: mode == m) { mode = m } }
            }
            // Only the chosen mode is mounted, so its camera/reader starts on switch-in and stops on
            // switch-out — no background capture, no two engines running at once.
            switch mode {
            case .read:     LensView(embedded: true)
            case .describe: SceneDescriberView(embedded: true)
            case .magnify:  MagnifierView(embedded: true)
            }
        }
    }

    private func title(_ m: Mode) -> String {
        switch m {
        case .read:     return "Read text"
        case .describe: return "Describe scene"
        case .magnify:  return "Magnify"
        }
    }
}
