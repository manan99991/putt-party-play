import SwiftUI

/// One Home shelf ("Camera", "Flashlight & phone", …) opened: every tool on it laid out at once, two across, each
/// with what it's for in plain words. Tap one and it opens. No sideways scrolling, nothing folded away.
struct ShelfSheet: View {
    let shelf: HomeShelves.Shelf
    let open: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var tools: [Tool] { shelf.tools.compactMap { id in TOOLS.first { $0.id == id } } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s12) {
                    Text(L(shelf.line)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: HandySpacing.s8), GridItem(.flexible(), spacing: HandySpacing.s8)],
                              spacing: HandySpacing.s8) {
                        ForEach(tools) { t in
                            Button { open(t.id) } label: { card(t) }
                                .buttonStyle(.plain).accessibilityIdentifier("shelf-tool-\(t.id)")
                        }
                    }
                }
                .padding(.horizontal, HandySpacing.gutter)
                .padding(.vertical, HandySpacing.s12)
            }
            .background(HandyColor.bg)
            .navigationTitle(L(shelf.title)).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func card(_ t: Tool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ToolIconBadge(id: t.id, symbol: t.icon, size: 34)
            Text(L(t.name)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary).lineLimit(1).minimumScaleFactor(0.85)
            Text(L(t.blurb)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(HandySpacing.s12)
        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
