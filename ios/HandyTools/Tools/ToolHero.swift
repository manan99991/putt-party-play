import SwiftUI

/// The top of every tool page: the tool's mark on its glowing tile, its name, one line on what it does and,
/// for a flow, the steps it runs as small chips — on a raised card washed in the tool's own colour, so each
/// page opens with a clear face instead of a bare title over buttons.
struct ToolHero<Mark: View>: View {
    let title: String
    let subtitle: String
    var tint: Color
    /// The steps a flow runs, in order (icon, name). Shown only when there are two or more.
    var steps: [(icon: String, title: String)] = []
    /// What good input looks like, shown as a soft line under the steps.
    var hint: String? = nil
    @ViewBuilder var mark: () -> Mark
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack(alignment: .center, spacing: 14) {
                mark()
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 22, weight: .bold)).foregroundStyle(HandyColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.system(size: 15)).foregroundStyle(HandyColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            if steps.count > 1 {
                HandyFlow(spacing: 6, lineSpacing: 6) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                        HStack(spacing: 5) {
                            if i > 0 { Image(systemName: "arrow.right").font(.system(size: 9, weight: .bold)).foregroundStyle(HandyColor.textSecondary) }
                            Label(s.title, systemImage: s.icon).font(HandyFont.micro).foregroundStyle(HandyColor.textPrimary)
                                .labelStyle(.titleAndIcon)
                                .padding(.horizontal, 9).padding(.vertical, 5)
                                .background(tint.opacity(scheme == .dark ? 0.20 : 0.12), in: Capsule())
                        }
                    }
                }
            }
            if let hint {
                Label(hint, systemImage: "lightbulb.max").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(HandySpacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(HandyColor.surfaceRaised)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(scheme == .dark ? 0.26 : 0.14), tint.opacity(0.02)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(tint.opacity(0.28), lineWidth: 1))
        .shadow(color: .black.opacity(scheme == .dark ? 0.32 : 0.08), radius: 14, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// While a tool works: one card, not a banner per button. A softly breathing mark in the tool's colour, what is
/// happening now, the real progress, a line on what waits, and Stop.
struct WorkingCard: View {
    var tint: Color
    var icon: String
    var value: Double?
    var label: String
    var note: String? = nil
    var stop: (() -> Void)? = nil
    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(tint.opacity(0.16)).frame(width: 48, height: 48)
                        .scaleEffect(breathe ? 1.12 : 0.92).opacity(breathe ? 0.55 : 1)
                    Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(tint)
                }
                .frame(width: 52, height: 52)
                .animation(reduceMotion ? nil : .easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: breathe)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Working on it")).font(HandyFont.cardTitle).foregroundStyle(HandyColor.textPrimary)
                    if let note { Text(L(note)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
                }
                Spacer(minLength: 0)
            }
            ToolProgressBar(value: value, label: label)
            if let stop {
                Button(role: .cancel, action: stop) { Label(L("Stop"), systemImage: "stop.fill").frame(maxWidth: .infinity) }
                    .secondaryButton().accessibilityIdentifier("run-stop")
            }
        }
        .padding(HandySpacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HandyColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(tint.opacity(0.35), lineWidth: 1))
        .shadow(color: tint.opacity(scheme == .dark ? 0.25 : 0.12), radius: 16, x: 0, y: 6)
        .accessibilityIdentifier("run-busy-note")
        .onAppear { breathe = true }
    }
}

/// A small label over a group of controls ("START WITH"), so a page reads in steps.
struct SectionLabel: View {
    let text: String
    var icon: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon).font(.system(size: 11, weight: .bold)) }
            Text(L(text).uppercased()).font(.system(size: 12, weight: .semibold)).tracking(0.8)
        }
        .foregroundStyle(HandyColor.textSecondary)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The line that sits on top of a finished result: it worked, and here it is.
struct ResultBanner: View {
    var title: String = "Your result"
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(HandyColor.success).accessibilityHidden(true)
            Text(L(title)).font(HandyFont.cardTitle).foregroundStyle(HandyColor.textPrimary)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
