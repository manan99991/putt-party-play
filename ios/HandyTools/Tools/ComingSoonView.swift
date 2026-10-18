import SwiftUI

/// Honest placeholder for a tool that's in the catalog but not built yet in this staging build.
/// Keeps every tile tappable (and the every-tool smoke test meaningful) without a dead screen.
struct ComingSoonView: View {
    let id: String
    var body: some View {
        let tool = TOOLS.first { $0.id == id }
        ToolPage(title: tool?.name ?? "Coming soon", subtitle: tool?.blurb ?? "") {
            EmptyState(icon: tool?.icon ?? "hammer.fill",
                       line: "Being built right now",
                       sub: "This tool is part of the new Tenzy lineup and lands in an upcoming build.")
        }
    }
}
