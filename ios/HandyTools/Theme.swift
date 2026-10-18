import SwiftUI

// ---------------------------------------------------------------------------------------------
// Tokens. One accent, two modes. Views reference these — never a raw hex.
// ---------------------------------------------------------------------------------------------

enum HandyColor {
    static let accent = Color(hex: 0x1F5EFF)
    static let accentPressed = Color(hex: 0x1649D6)
    static let danger = Color(hex: 0xE53935)
    static let success = Color(hex: 0x2E7D32)
    static let amber = Color(hex: 0xB26A00)

    static let accentSoft = Color.adaptive(light: 0xE8EEFF, dark: 0x16224A)
    static let warningSoft = Color.adaptive(light: 0xFFF4E5, dark: 0x2A2214)
    static let sticky = Color.adaptive(light: 0xFFF6B3, dark: 0x3A3418)
    static let bg = Color.adaptive(light: 0xF6F7FB, dark: 0x0E0E12)
    static let surface = Color.adaptive(light: 0xFFFFFF, dark: 0x16161C)
    static let surfaceRaised = Color.adaptive(light: 0xFFFFFF, dark: 0x1C1C24)
    static let textPrimary = Color.adaptive(light: 0x0E0E12, dark: 0xF2F2F5)
    static let textSecondary = Color.adaptive(light: 0x5C5F6E, dark: 0xA3A6B5)
    static let border = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.10) : UIColor.black.withAlphaComponent(0.08) })
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

extension View {
    func cardStyle(padding: CGFloat = HandySpacing.s16) -> some View { modifier(HandyCardStyle(padding: padding)) }
    func primaryButton() -> some View { buttonStyle(HandyPrimaryButtonStyle()) }
    func secondaryButton() -> some View { buttonStyle(HandySecondaryButtonStyle()) }
    func textButton() -> some View { buttonStyle(HandyTextButtonStyle()) }
    func compactButton() -> some View { buttonStyle(HandyCompactButtonStyle()) }
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
