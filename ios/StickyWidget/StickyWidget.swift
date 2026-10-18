import WidgetKit
import SwiftUI

/// Quick Tools widget: the four things people reach for in a hurry, one tap from the home screen
/// or lock screen (tenzy://tool/<id> deep links). Replaces the old sticky-note widget.
struct QuickEntry: TimelineEntry { let date: Date }

struct QuickProvider: TimelineProvider {
    func placeholder(in: Context) -> QuickEntry { QuickEntry(date: .now) }
    func getSnapshot(in: Context, completion: @escaping (QuickEntry) -> Void) { completion(QuickEntry(date: .now)) }
    func getTimeline(in: Context, completion: @escaping (Timeline<QuickEntry>) -> Void) { completion(Timeline(entries: [QuickEntry(date: .now)], policy: .never)) }
}

private struct Quick: Identifiable { let id: String; let name: String; let icon: String }
private let quickTools: [Quick] = [
    Quick(id: "capture", name: "Capture", icon: "viewfinder"),
    Quick(id: "scan", name: "Scan", icon: "doc.viewfinder.fill"),
    Quick(id: "light", name: "Flashlight+", icon: "flashlight.on.fill"),
    Quick(id: "fitit", name: "Fit It", icon: "arrow.down.right.and.arrow.up.left"),
]

struct QuickToolsView: View {
    let entry: QuickEntry
    @Environment(\.widgetFamily) private var family
    private let accent = Color(red: 0.16, green: 0.45, blue: 0.95)

    var body: some View {
        switch family {
        case .accessoryRectangular:
            HStack(spacing: 10) {
                ForEach(quickTools.prefix(3)) { t in
                    Link(destination: URL(string: "tenzy://tool/\(t.id)")!) {
                        VStack(spacing: 2) { Image(systemName: t.icon).font(.system(size: 16, weight: .semibold)); Text(t.name).font(.system(size: 9)).lineLimit(1) }.frame(maxWidth: .infinity)
                    }
                }
            }
            .containerBackground(.clear, for: .widget)
        case .systemSmall:
            grid(columns: 2, size: 22).containerBackground(Color(.systemBackground), for: .widget)
        default:
            HStack(spacing: 8) { ForEach(quickTools) { t in tile(t, size: 24) } }
                .containerBackground(Color(.systemBackground), for: .widget)
        }
    }

    private func grid(columns: Int, size: CGFloat) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
            ForEach(quickTools) { t in tile(t, size: size) }
        }
    }

    private func tile(_ t: Quick, size: CGFloat) -> some View {
        Link(destination: URL(string: "tenzy://tool/\(t.id)")!) {
            VStack(spacing: 4) {
                Image(systemName: t.icon).font(.system(size: size, weight: .semibold)).foregroundStyle(accent)
                Text(t.name).font(.system(size: 11, weight: .medium)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

@main
struct StickyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StickyWidget", provider: QuickProvider()) { QuickToolsView(entry: $0) }
            .configurationDisplayName("Quick Tools")
            .description("Capture, Scan, Flashlight+ and Fit It — one tap away.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
