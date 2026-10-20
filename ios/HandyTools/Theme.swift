import SwiftUI

// ---------------------------------------------------------------------------------------------
// Tokens. One accent, two modes. Views reference these — never a raw hex.
// ---------------------------------------------------------------------------------------------

/// Colour tokens now resolve through the active theme (see TenzyTheme / ThemeManager). Every view
/// already reads `HandyColor.*`, so switching the theme re-skins the whole app with no call-site
/// changes. Status colours (danger/success/amber) and the sticky-note/warning tints stay constant.
enum HandyColor {
    static let danger = Color(hex: 0xE53935)
    static let success = Color(hex: 0x2E7D32)
    static let amber = Color(hex: 0xB26A00)
    static let warningSoft = Color.adaptive(light: 0xFFF4E5, dark: 0x2A2214)
    static let sticky = Color.adaptive(light: 0xFFF6B3, dark: 0x3A3418)

    private static var t: ThemeTokens { ActiveTheme.shared.tokens }
    static var accent: Color { t.accent }
    static var accentPressed: Color { t.accentPressed }
    static var accentSoft: Color { t.accentSoft }
    static var bg: Color { t.bg }
    static var surface: Color { t.surface }
    static var surfaceRaised: Color { t.surfaceRaised }
    static var textPrimary: Color { t.textPrimary }
    static var textSecondary: Color { t.textSecondary }
    static var border: Color { t.border }
}

/// The five Tenzy looks. Daylight is free and keeps the app's existing light/dark behaviour; the
/// other four are fixed-look Pro themes with the exact tokens from the design handoff.
enum TenzyTheme: String, CaseIterable, Identifiable {
    case daylight, midnight, warmPaper, neoPop, mono
    var id: String { rawValue }
    var isPro: Bool { self != .daylight }
    var isDark: Bool { self == .midnight }
    var title: String {
        switch self {
        case .daylight: return "Daylight"; case .midnight: return "Midnight"
        case .warmPaper: return "Warm Paper"; case .neoPop: return "Neo Pop"; case .mono: return "Mono"
        }
    }
    var blurb: String {
        switch self {
        case .daylight: return "Clean, bright — the default"
        case .midnight: return "Dark glass, neon glow"
        case .warmPaper: return "Editorial, warm, matte"
        case .neoPop: return "Bold, playful, punchy"
        case .mono: return "Minimal, stealth"
        }
    }
    /// A small swatch gradient for the picker — the theme's tile gradient.
    var swatch: [Color] {
        switch self {
        case .daylight: return [Color(hex: 0x1F5EFF), Color(hex: 0x1649D6)]
        case .midnight: return [Color(hex: 0x1E3A8A), Color(hex: 0x3DE1FF)]
        case .warmPaper: return [Color(hex: 0xC2502E), Color(hex: 0xE0795A)]
        case .neoPop: return [Color(hex: 0xFF2D87), Color(hex: 0xFF8A00)]
        case .mono: return [Color(hex: 0x1A1A1A), Color(hex: 0x000000)]
        }
    }
    var tokens: ThemeTokens {
        switch self {
        case .daylight:
            return ThemeTokens(
                accent: Color(hex: 0x1F5EFF), accentPressed: Color(hex: 0x1649D6),
                accentSoft: .adaptive(light: 0xE8EEFF, dark: 0x16224A),
                bg: .adaptive(light: 0xF6F7FB, dark: 0x0E0E12),
                surface: .adaptive(light: 0xFFFFFF, dark: 0x16161C),
                surfaceRaised: .adaptive(light: 0xFFFFFF, dark: 0x1C1C24),
                textPrimary: .adaptive(light: 0x0E0E12, dark: 0xF2F2F5),
                textSecondary: .adaptive(light: 0x5C5F6E, dark: 0xA3A6B5),
                border: Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.10) : UIColor.black.withAlphaComponent(0.08) }))
        case .midnight:  return .fixed(accent: 0x3DE1FF, pressed: 0x16B6D6, bg: 0x0B0E14, surface: 0x141925, raised: 0x1C2230, text: 0xEAF2FF)
        case .warmPaper: return .fixed(accent: 0xC2502E, pressed: 0x9E3F22, bg: 0xF6F1E7, surface: 0xEFE8D8, raised: 0xFFFFFF, text: 0x1C1A17)
        case .neoPop:    return .fixed(accent: 0xFF2D87, pressed: 0xD81B6C, bg: 0xFBF7F2, surface: 0xFFFFFF, raised: 0xFFFFFF, text: 0x141414)
        case .mono:      return .fixed(accent: 0xFF5A1F, pressed: 0xE04715, bg: 0xFFFFFF, surface: 0xF2F2F2, raised: 0xFFFFFF, text: 0x0A0A0A)
        }
    }
}

struct ThemeTokens {
    let accent, accentPressed, accentSoft, bg, surface, surfaceRaised, textPrimary, textSecondary, border: Color
    /// Fixed-look theme: derive the soft/secondary/border tints from the base tokens.
    static func fixed(accent: UInt32, pressed: UInt32, bg: UInt32, surface: UInt32, raised: UInt32, text: UInt32) -> ThemeTokens {
        let txt = Color(hex: text)
        return ThemeTokens(
            accent: Color(hex: accent), accentPressed: Color(hex: pressed),
            accentSoft: Color(hex: accent).opacity(0.16),
            bg: Color(hex: bg), surface: Color(hex: surface), surfaceRaised: Color(hex: raised),
            textPrimary: txt, textSecondary: txt.opacity(0.62), border: txt.opacity(0.12))
    }
}

/// Holds the active theme, persists it, and gates the Pro themes: a non-Pro user always renders as
/// Daylight even if a Pro theme is stored (e.g. their subscription lapsed).
/// Non-isolated snapshot the colour tokens read from — so HandyColor stays reachable from any context
/// (it isn't tied to the main actor). ThemeManager writes `theme` on the main actor; the resolved
/// tokens are cached so a colour read never rebuilds them.
final class ActiveTheme {
    static let shared = ActiveTheme()
    var theme: TenzyTheme { didSet { tokens = theme.tokens } }
    private(set) var tokens: ThemeTokens
    private init() {
        let t = TenzyTheme(rawValue: UserDefaults.standard.string(forKey: "tenzyTheme") ?? "") ?? .daylight
        theme = t; tokens = t.tokens
    }
}

/// Holds the user's chosen theme, persists it, and is observed by the UI so a switch re-skins live.
/// Pro themes are gated at selection time (the Settings picker checks Pro), so a free user can't pick
/// one — no gating is needed in the render path.
@MainActor final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    private static let key = "tenzyTheme"
    @Published var current: TenzyTheme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: Self.key); ActiveTheme.shared.theme = current }
    }
    private init() {
        current = TenzyTheme(rawValue: UserDefaults.standard.string(forKey: Self.key) ?? "") ?? .daylight
        ActiveTheme.shared.theme = current
    }
}

enum HandySpacing {
    static let s4: CGFloat = 4, s8: CGFloat = 8, s12: CGFloat = 12, s16: CGFloat = 16
    static let s20: CGFloat = 20, s24: CGFloat = 24, s32: CGFloat = 32, s48: CGFloat = 48
    static let gutter: CGFloat = 20
    static let touchTarget: CGFloat = 48
    static let primaryButtonHeight: CGFloat = 52
    static let compactButtonHeight: CGFloat = 40
    static let chipHeight: CGFloat = 36
    static let adReservedHeight: CGFloat = 60
}

enum HandyRadius {
    static let small: CGFloat = 8, input: CGFloat = 12, card: CGFloat = 16, sheet: CGFloat = 24
}

enum HandyFont {
    static let display = Font.system(size: 34, weight: .bold)
    static let title = Font.system(size: 22, weight: .semibold)
    static let cardTitle = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 16)
    static let bodyStrong = Font.system(size: 16, weight: .semibold)
    static let caption = Font.system(size: 13)
    static let micro = Font.system(size: 12, weight: .medium)
}

enum HandyMotion {
    static let fast: Double = 0.12, base: Double = 0.20, slow: Double = 0.28
    static let pressScale: CGFloat = 0.98
}

// Motion additions (prompt 1): enter/exit curves, sheet timing, bubble spring spec,
// list-item stagger timing, reduce-motion crossfade, haptics. No existing token values changed.
extension HandyMotion {
    /// Ease-out for enter, ease-in for exit. Things slide and fade; they never bounce.
    static var enter: Animation { .easeOut(duration: base) }
    static var exit: Animation { .easeIn(duration: base) }
    static var sheet: Animation { .easeOut(duration: slow) }
    static var crossfade: Animation { .easeOut(duration: fast) }
    /// List items: fade + 8pt slide, staggered 30ms, max 6 staggered.
    static func listDelay(index: Int) -> Double { Double(min(index, 5)) * 0.03 }
    /// Floating-bubble snap spring: damping ratio 0.8 (stiffness 100 / damping 16 ≈ ζ 0.8).
    /// Overshoot is capped at 2pt at the call site; the bubble dims to 70% after 3s idle.
    static let bubbleSpring: Animation = .interpolatingSpring(stiffness: 100, damping: 16)
    static let bubbleIdleDimDelay: Double = 3.0
    static let bubbleDimOpacity: Double = 0.7
    static let listSlide: CGFloat = 8
}

/** Haptics: light on chip select/toggle, medium on clip saved, success on "Added to home screen". */
enum HandyHaptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

// ---------------------------------------------------------------------------------------------
// Components
// ---------------------------------------------------------------------------------------------

/** Level-1 card: surface + hairline. */
struct HandyCardStyle: ViewModifier {
    var padding: CGFloat = HandySpacing.s16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }
}

/** Primary: pill, accent, 52pt, full width. Scales 0.98 while pressed. */
struct HandyPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HandyFont.bodyStrong)
            .foregroundStyle(isEnabled ? Color.white : HandyColor.accent.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: HandySpacing.primaryButtonHeight)
            .background(isEnabled ? (configuration.isPressed ? HandyColor.accentPressed : HandyColor.accent) : HandyColor.accentSoft, in: Capsule())
            .scaleEffect(configuration.isPressed ? HandyMotion.pressScale : 1)
            .animation(.easeOut(duration: HandyMotion.fast), value: configuration.isPressed)
    }
}

/** Secondary: pill, transparent, 1.5pt hairline, primary text. */
struct HandySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HandyFont.bodyStrong)
            .foregroundStyle(HandyColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: HandySpacing.primaryButtonHeight)
            .overlay(Capsule().stroke(HandyColor.border, lineWidth: 1.5))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? HandyMotion.pressScale : 1)
            .animation(.easeOut(duration: HandyMotion.fast), value: configuration.isPressed)
    }
}

/** Text: no chrome, accent label, 44pt. */
struct HandyTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HandyFont.bodyStrong)
            .foregroundStyle(HandyColor.accent.opacity(configuration.isPressed ? 0.7 : 1))
            .frame(minHeight: 44)
    }
}

/** Compact primary used inside cards (40pt). */
struct HandyCompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, HandySpacing.s16)
            .frame(minHeight: HandySpacing.compactButtonHeight)
            .background(configuration.isPressed ? HandyColor.accentPressed : HandyColor.accent, in: Capsule())
    }
}

/** Pill chip, 36pt. Selected = accentSoft fill + accent text + accent border. */
struct HChip: View {
    let text: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text).font(.system(size: 14, weight: .medium))
                .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(selected ? HandyColor.accent : HandyColor.textPrimary)
                .padding(.horizontal, HandySpacing.s16)
                .frame(minHeight: HandySpacing.chipHeight)
                .background(selected ? HandyColor.accentSoft : HandyColor.surface, in: Capsule())
                .overlay(Capsule().stroke(selected ? HandyColor.accent : HandyColor.border, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
    }
}

/** Amber permission / setup card. */
struct SetupCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(alignment: .top, spacing: HandySpacing.s12) {
            Image(systemName: "shield").font(.system(size: 22)).foregroundStyle(HandyColor.amber)
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Text(title).font(HandyFont.bodyStrong)
                content()
            }
        }
        .padding(HandySpacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HandyColor.warningSoft, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
    }
}

/** Label + live value, slider under. Monospaced digits so the value doesn't jitter. */
struct SliderRow: View {
    let label: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var body: some View {
        VStack(spacing: HandySpacing.s8) {
            HStack { Text(label).font(HandyFont.body); Spacer(); Text(valueText).font(HandyFont.bodyStrong).monospacedDigit() }
            Slider(value: $value, in: range, step: step).tint(HandyColor.accent)
        }
        .padding(.vertical, HandySpacing.s8)
    }
}

/** Empty state: icon in accentSoft circle, one line, optional second line. */
struct EmptyState: View {
    let icon: String
    let line: String
    var sub: String? = nil
    var body: some View {
        VStack(spacing: HandySpacing.s16) {
            ZStack {
                Circle().fill(HandyColor.accentSoft).frame(width: 64, height: 64)
                Image(systemName: icon).font(.system(size: 26)).foregroundStyle(HandyColor.accent)
            }
            Text(line).font(HandyFont.body)
            if let sub { Text(sub).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, HandySpacing.s48)
    }
}

/** Secondary line under a control: the honest-limit note. */
struct LimitNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
}

/// Lays its children out left-to-right and WRAPS to a new line when the next one wouldn't fit,
/// instead of running off the right edge. This is the fix for the "controls are cut off / I have to
/// scroll sideways to find a chip" class of bug: a row of mode chips becomes two or three short rows,
/// every one visible on the same page. Drop-in replacement for `ScrollView(.horizontal){ HStack{…} }`
/// around a set of chips — same spacing, no scrolling.
struct HandyFlow: Layout {
    var spacing: CGFloat = HandySpacing.s8
    var lineSpacing: CGFloat = HandySpacing.s8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        let rows = layout(subviews, maxW: maxW)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = proposal.width ?? rows.map { $0.width }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = layout(subviews, maxW: bounds.width)
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let s = subviews[item.index].sizeThatFits(.unspecified)
                subviews[item.index].place(at: CGPoint(x: x, y: bounds.minY + row.y), anchor: .topLeading, proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
        }
    }

    private struct Row { var items: [(index: Int, width: CGFloat)] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func layout(_ subviews: Subviews, maxW: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        var x: CGFloat = 0
        for (i, v) in subviews.enumerated() {
            let s = v.sizeThatFits(.unspecified)
            if !row.items.isEmpty, x + s.width > maxW {
                rows.append(row)
                let nextY = row.y + row.height + lineSpacing
                row = Row(); row.y = nextY; x = 0
            }
            row.items.append((i, s.width))
            x += s.width + spacing
            row.width = max(row.width, x - spacing)
            row.height = max(row.height, s.height)
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}

extension View {
    func cardStyle(padding: CGFloat = HandySpacing.s16) -> some View { modifier(HandyCardStyle(padding: padding)) }
    func primaryButton() -> some View { buttonStyle(HandyPrimaryButtonStyle()) }
    func secondaryButton() -> some View { buttonStyle(HandySecondaryButtonStyle()) }
    func textButton() -> some View { buttonStyle(HandyTextButtonStyle()) }
    func compactButton() -> some View { buttonStyle(HandyCompactButtonStyle()) }
}

/// Collapsible "How to use" helper pinned at the top of a tool: a few plain steps so someone opening
/// the tool for the first time knows exactly what to do. Expanded the first time, then remembers per
/// tool (by `id`) whether the user collapsed it, so it never nags on repeat visits.
struct HowTo: View {
    let steps: [String]
    @AppStorage private var open: Bool
    init(_ id: String, _ steps: [String]) {
        self.steps = steps
        _open = AppStorage(wrappedValue: true, "howto.\(id)")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { open.toggle() } } label: {
                HStack(spacing: HandySpacing.s8) {
                    Image(systemName: "lightbulb.fill").font(.system(size: 13)).foregroundStyle(HandyColor.accent)
                    Text("How to use").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                    Spacer()
                    Image(systemName: open ? "chevron.up" : "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(HandyColor.textSecondary)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                        HStack(alignment: .top, spacing: HandySpacing.s8) {
                            Text("\(i + 1)").font(HandyFont.micro).monospacedDigit().foregroundStyle(.white)
                                .frame(width: 18, height: 18).background(HandyColor.accent, in: Circle())
                            Text(s).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(HandySpacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HandyColor.accentSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            let h = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255, blue: CGFloat(h & 0xFF) / 255, alpha: 1)
        })
    }
}
