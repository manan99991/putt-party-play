import WidgetKit
import SwiftUI

/// My Tools widget: the tools you made in Build your own, one tap from the home screen. Each opens Tenzy with that
/// tool ready to run (tenzy://run/<id>). It shows your first tools in the order of the My tools list; "Move to top"
/// in Tenzy decides which come first.
struct SavedTool: Decodable, Identifiable {
    let id: String
    let name: String
}

struct ToolsEntry: TimelineEntry {
    let date: Date
    let tools: [SavedTool]
}

struct ToolsProvider: TimelineProvider {
    /// The saved tools, read from the same place the app keeps them. Only the id and name are needed here.
    static func load() -> [SavedTool] {
        guard let data = AppGroup.defaults.data(forKey: "builder.chains"), let tools = try? JSONDecoder().decode([SavedTool].self, from: data) else { return [] }
        return tools
    }
    func placeholder(in: Context) -> ToolsEntry { ToolsEntry(date: .now, tools: []) }
    func getSnapshot(in: Context, completion: @escaping (ToolsEntry) -> Void) { completion(ToolsEntry(date: .now, tools: ToolsProvider.load())) }
    func getTimeline(in: Context, completion: @escaping (Timeline<ToolsEntry>) -> Void) {
        completion(Timeline(entries: [ToolsEntry(date: .now, tools: ToolsProvider.load())], policy: .never))
    }
}

struct ToolsWidgetView: View {
    let entry: ToolsEntry
    @Environment(\.widgetFamily) private var family
    private let accent = Color(red: 0.16, green: 0.45, blue: 0.95)

    var body: some View {
        Group {
            if entry.tools.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "wand.and.stars").font(.system(size: 22, weight: .semibold)).foregroundStyle(accent)
                    Text("Make a tool in Tenzy and it appears here.").font(.system(size: 12)).multilineTextAlignment(.center).foregroundStyle(.secondary)
                }
                .widgetURL(URL(string: "tenzy://run/none"))
            } else if family == .systemSmall {
                // A small widget is one button: the whole of it opens your first tool.
                tile(entry.tools[0], size: 26).widgetURL(URL(string: "tenzy://run/\(entry.tools[0].id)"))
            } else {
                HStack(spacing: 8) {
                    ForEach(entry.tools.prefix(4)) { t in
                        Link(destination: URL(string: "tenzy://run/\(t.id)") ?? URL(string: "tenzy://run/none")!) { tile(t, size: 22) }
                    }
                }
            }
        }
        .containerBackground(Color(.systemBackground), for: .widget)
    }

    private func tile(_ t: SavedTool, size: CGFloat) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "wand.and.stars").font(.system(size: size, weight: .semibold)).foregroundStyle(accent)
            Text(t.name).font(.system(size: 11, weight: .medium)).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ToolsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ToolsWidget", provider: ToolsProvider()) { ToolsWidgetView(entry: $0) }
            .configurationDisplayName("My Tools")
            .description("Your own tools from Build your own, one tap away.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TenzyWidgets: WidgetBundle {
    var body: some Widget {
        StickyWidget()
        ToolsWidget()
    }
}
