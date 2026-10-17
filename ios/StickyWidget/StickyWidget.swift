import WidgetKit
import SwiftUI

struct NoteEntry: TimelineEntry { let date: Date; let text: String }

struct NoteProvider: TimelineProvider {
    func placeholder(in: Context) -> NoteEntry { NoteEntry(date: .now, text: "Your note shows here") }
    func getSnapshot(in: Context, completion: @escaping (NoteEntry) -> Void) { completion(NoteEntry(date: .now, text: NoteStore.text)) }
    func getTimeline(in: Context, completion: @escaping (Timeline<NoteEntry>) -> Void) {
        completion(Timeline(entries: [NoteEntry(date: .now, text: NoteStore.text)], policy: .never))
    }
}

struct StickyWidgetView: View {
    let entry: NoteEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        Text(entry.text.isEmpty ? "Tap to write a note" : entry.text)
            .font(family == .accessoryRectangular ? .caption : .callout)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(Color.yellow.opacity(0.35), for: .widget)
    }
}

@main
struct StickyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StickyWidget", provider: NoteProvider()) { StickyWidgetView(entry: $0) }
            .configurationDisplayName("Sticky Note")
            .description("Your Oddbox note, always visible.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
