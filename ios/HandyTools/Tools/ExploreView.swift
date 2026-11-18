import SwiftUI

/// The browse home: every tool Tenzy has, one tap away, grouped by what it's for — with a "New &
/// notable" strip spotlighting the hero tools up top. This is the fix for tools that used to be
/// reachable only by searching or digging into Settings (relaxing music, the AI helpers, the
/// sensors): nothing is orphaned anymore. It reuses the same themed ToolCard as the rest of the app,
/// and every card pushes straight into that tool through the home NavigationStack.
struct ExploreView: View {
    @EnvironmentObject var store: StoreManager
    @ObservedObject private var theme = ThemeManager.shared   // re-skin live on a theme change
    private let cols = [GridItem(.flexible(), spacing: HandySpacing.s12), GridItem(.flexible(), spacing: HandySpacing.s12)]

    /// The catalog, grouped the way the three pages already divide it, plus Think & plan.
    private let groups: [(title: String, page: Int)] = [
        ("Photo, video & sharing", 1),
        ("Scan, read & organize", 2),
        ("Everyday, sensors & accessibility", 3),
        ("Documents & PDF", 4),
        ("Audio & voice", 5),
        ("Think & plan", 6),
    ]

    /// Hero tools spotlighted at the top — each is a real, full tool that shows Tenzy at its best.
    private let featuredIDs = ["identify", "video", "scan", "voicenotes", "translate", "seeread"]
    private var featured: [Tool] { featuredIDs.compactMap { id in TOOLS.first { $0.id == id } } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s24) {
                // Intro
                VStack(alignment: .leading, spacing: HandySpacing.s4) {
                    Text(L("Explore")).font(HandyFont.display)
                    Text(L("Every tool Tenzy has — tap any to open it. It all runs on your phone."))
                        .font(.system(size: 14)).foregroundStyle(HandyColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, HandySpacing.gutter)

                // New & notable — a horizontal strip of hero tools
                if !featured.isEmpty {
                    VStack(alignment: .leading, spacing: HandySpacing.s12) {
                        Text(L("NEW & NOTABLE")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                            .padding(.horizontal, HandySpacing.gutter)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: HandySpacing.s12) {
                                ForEach(featured) { t in
                                    NavigationLink(value: t.id) { ToolCard(tool: t, height: 128) }
                                        .buttonStyle(ToolCardPress())
                                        .frame(width: 150)
                                }
                            }
                            .padding(.horizontal, HandySpacing.gutter)
                        }
                    }
                }

                // The full catalog, by category
                ForEach(groups, id: \.page) { group in
                    VStack(alignment: .leading, spacing: HandySpacing.s12) {
                        Text(group.title.uppercased()).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                            .padding(.horizontal, HandySpacing.gutter)
                        LazyVGrid(columns: cols, spacing: HandySpacing.s12) {
                            ForEach(tools(onPage: group.page)) { t in
                                NavigationLink(value: t.id) { ToolCard(tool: t, height: 128) }.buttonStyle(ToolCardPress())
                            }
                        }
                        .padding(.horizontal, HandySpacing.gutter)
                    }
                }
            }
            .padding(.top, HandySpacing.s12)
            .padding(.bottom, HandySpacing.s24)
        }
        .background(Ground())
        .id(theme.current)   // re-skin live if the theme changes while this page is open
    }
}
