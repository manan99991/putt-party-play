import SwiftUI
import UIKit

/// The "For you now" cards at the top of Home (UX audit decision 2). Each says why it's there, does one thing in one
/// tap, and can be put off (Not now, a week) or turned off (press and hold › Don't suggest this).
struct ForYouCards: View {
    let cards: [ForYou.Card]
    /// Called after a card was acted on or put away, so Home re-reads what's left.
    let changed: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { i, c in card(c, primary: i == 0) }
        }
        .accessibilityElement(children: .contain)
    }

    private func card(_ c: ForYou.Card, primary: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: c.icon).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color(hex: c.hex), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L(c.title)).font(.system(size: 15, weight: .semibold)).foregroundStyle(HandyColor.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.85)
                Text(L(c.why)).font(.system(size: 12)).foregroundStyle(HandyColor.textSecondary).lineLimit(1).minimumScaleFactor(0.85)
            }
            Spacer(minLength: 4)
            Button { act(c) } label: {
                Text(L(c.button)).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primary ? HandyColor.onAccent : HandyColor.accent)
                    .padding(.horizontal, 12).frame(minHeight: 34)
                    .background(primary ? AnyShapeStyle(HandyColor.accent) : AnyShapeStyle(Color.clear), in: Capsule())
                    .overlay(Capsule().stroke(HandyColor.accent, lineWidth: primary ? 0 : 1.25))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("foryou-action-\(c.kind.rawValue)")
            Button { withAnimation(.easeOut(duration: HandyMotion.fast)) { ForYou.notNow(c); changed() } } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(HandyColor.textSecondary)
                    .frame(width: 28, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("Not now"))
            .accessibilityIdentifier("foryou-notnow-\(c.kind.rawValue)")
        }
        .padding(.leading, 12).padding(.trailing, 4).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
        .contextMenu {
            Button(role: .destructive) { ForYou.turnOff(c.kind); changed() } label: { Label(L("Don't suggest this"), systemImage: "hand.raised") }
        }
        // A card with a context menu reads as one element unless told otherwise, which hid its two buttons from
        // VoiceOver (and from the 23 Nov UI test): keep the card a container so each button is reachable.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("foryou-\(c.kind.rawValue)")
    }

    private func act(_ c: ForYou.Card) {
        switch c.action {
        case .open(let tool):
            NotificationCenter.default.post(name: .openTool, object: tool, userInfo: ["from": "builder"])
        case .directions(let lat, let lng):
            if let u = URL(string: String(format: "https://maps.apple.com/?daddr=%.6f,%.6f&dirflg=w", lat, lng)) { UIApplication.shared.open(u) }
        case .markTaken(let id, let at):
            let store = MedStore.shared
            if let m = store.meds.first(where: { $0.id == id }) { store.setTaken(m, at: at, true); HandyHaptics.success() }
            changed()
        }
    }
}
