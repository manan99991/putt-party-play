import SwiftUI

/// Pocket — one tile that holds the little everyday helpers that don't each need their own spot
/// on the home grid: the magnifier, a quick note, loyalty cards, and alarms. Each row opens the
/// full tool. (A holding place for now; these may move as the catalog settles.)
struct PocketView: View {
    private struct Item: Identifiable {
        let id: String
        let name: String
        let blurb: String
        let icon: String
    }

    private let items: [Item] = [
        Item(id: "magnifier", name: "Magnifier",  blurb: "Zoom in on fine print, with light", icon: "plus.magnifyingglass"),
        Item(id: "sticky",    name: "Quick Note",  blurb: "A note on your home & lock screen", icon: "note.text"),
        Item(id: "wallet",    name: "Cards",       blurb: "Loyalty barcodes, ready to scan",  icon: "creditcard.fill"),
        Item(id: "alarm",     name: "Alarm",       blurb: "Alarms your way — sounds, snooze", icon: "alarm.fill"),
    ]

    var body: some View {
        ToolPage(title: "Pocket", subtitle: "The little everyday helpers, together in one place.") {
            VStack(spacing: HandySpacing.s12) {
                ForEach(items) { item in
                    NavigationLink(value: item.id) {
                        HStack(spacing: HandySpacing.s16) {
                            ZStack {
                                Circle().fill(HandyColor.accentSoft).frame(width: 44, height: 44)
                                Image(systemName: item.icon).font(.system(size: 18, weight: .medium)).foregroundStyle(HandyColor.accent)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(HandyFont.cardTitle).foregroundStyle(HandyColor.textPrimary)
                                Text(item.blurb).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(HandyColor.textSecondary)
                        }
                        .cardStyle(padding: HandySpacing.s16)
                    }
                    .buttonStyle(ToolCardPress())
                }
            }
        }
    }
}
