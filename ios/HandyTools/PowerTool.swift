import SwiftUI

// MARK: - The approved power-tool page (HTML prototype v5)
//
// Every one of the 10 hubs uses this scaffold so they look identical: a hero band with the kit's card
// art (always dark, in every theme) carrying the clay icon + name + blurb, a WRAPPING strip of tab
// chips (never clipped at the right edge — ToolControlsReachableTests enforces that), then the hub's
// content over the themed page art. The system navigation bar stays (Back is never lost) but is
// transparent over the hero.

struct PowerToolPage<Content: View>: View {
    let id: String
    var tabs: [String] = []
    @Binding var selected: Int
    /// Optional bar pinned above the ad (e.g. a primary action) — stays put while content scrolls.
    var footer: AnyView? = nil
    @ViewBuilder let content: () -> Content

    init(id: String, tabs: [String] = [], selected: Binding<Int> = .constant(0), footer: AnyView? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.id = id; self.tabs = tabs; self._selected = selected; self.footer = footer; self.content = content
    }

    private var tool: Tool? { TOOLS.first { $0.id == id } }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    if !tabs.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(Array(tabs.enumerated()), id: \.offset) { i, t in
                                HubChip(t, selected: i == selected) { withAnimation(.easeOut(duration: 0.15)) { selected = i } }
                            }
                        }
                        .padding(.horizontal, HandySpacing.gutter)
                        .padding(.vertical, 10)
                    } else {
                        Spacer().frame(height: 10)
                    }
                    VStack(alignment: .leading, spacing: HandySpacing.s16) { content() }
                        .padding(.horizontal, HandySpacing.gutter)
                        .padding(.bottom, HandySpacing.s48)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            if let footer { footer }
            BannerAd().ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .background { ToolPageArt(id: id) }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { Diagnostics.shared.currentTool = tool?.name ?? id }
    }

    private var hero: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                Color(red: 0.03, green: 0.03, blue: 0.06)
                if let card = tool?.card {
                    Image(card).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                }
                LinearGradient(stops: [.init(color: Color(red: 0.03, green: 0.03, blue: 0.06).opacity(0.15), location: 0),
                                       .init(color: Color(red: 0.03, green: 0.03, blue: 0.06).opacity(0.25), location: 0.6),
                                       .init(color: Color(red: 0.03, green: 0.03, blue: 0.06).opacity(0.95), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                HStack(spacing: 12) {
                    if let asset = tool?.asset {
                        Image(asset).resizable().scaledToFit().frame(width: 50, height: 50)
                            .shadow(color: .black.opacity(0.55), radius: 8, y: 6)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tool?.name ?? id).font(.system(size: 23, weight: .heavy)).foregroundStyle(.white)
                        Text(tool?.blurb ?? "").font(.system(size: 13)).foregroundStyle(Color(white: 0.68))
                    }
                }
                .padding(.leading, HandySpacing.gutter).padding(.bottom, 12)
            }
        }
        .aspectRatio(1290.0 / 480.0, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tool?.name ?? id)
    }
}

/// Tab / option chip, same look as the home search pill: surface, hairline, accent when selected.
struct HubChip: View {
    let text: String
    let selected: Bool
    let action: () -> Void
    init(_ text: String, selected: Bool, action: @escaping () -> Void) { self.text = text; self.selected = selected; self.action = action }
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13.5, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? HandyColor.accent : HandyColor.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(selected ? HandyColor.accentSoft : HandyColor.surface, in: Capsule())
                .overlay(Capsule().stroke(selected ? HandyColor.accent : HandyColor.border, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// Small uppercase section label (prototype .lbl)
struct HubSection: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased()).font(.system(size: 12, weight: .medium)).foregroundStyle(HandyColor.textSecondary)
            .tracking(0.4).padding(.top, 4)
    }
}

/// Muted footnote (prototype .note)
struct HubNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.system(size: 12)).foregroundStyle(HandyColor.textSecondary).lineSpacing(3) }
}

/// Status pill (prototype .tag): accent by default, amber for "runs on a real device", green for ✓.
struct HubPill: View {
    enum Tone { case accent, native, ok }
    let text: String; let tone: Tone
    init(_ text: String, tone: Tone = .accent) { self.text = text; self.tone = tone }
    private var color: Color {
        switch tone { case .accent: return HandyColor.accent; case .native: return Color(red: 1.0, green: 0.81, blue: 0.54); case .ok: return Color(red: 0.56, green: 0.89, blue: 0.71) }
    }
    var body: some View {
        Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 3).background(color.opacity(0.16), in: Capsule())
    }
}

/// The empty "pick something" box (prototype .preview)
struct HubPreviewBox<Content: View>: View {
    var minHeight: CGFloat = 170
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(HandyColor.border, style: StrokeStyle(lineWidth: 1, dash: [6, 5])))
    }
}

/// Wraps subviews onto new lines (chips never clip at the screen edge).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0, x + sz.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
        return CGSize(width: maxW == .infinity ? x : maxW, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
    }
}
