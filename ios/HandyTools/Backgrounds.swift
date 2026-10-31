import SwiftUI

// MARK: - Per-tool background art
//
// The delivered art set ships as asset-catalog imagesets named
//   bg_<id>_<theme>_<variant>_<card|page>
// where <theme> is the lowercased TenzyTheme raw value, and <variant> is the light/dark cut that
// actually exists for that theme (daylight ships both and follows the system; midnight is dark; the
// paper / pop / mono themes ship light only). This file centralises the name-building, the
// light/dark selection, and the two on-screen treatments: the home-grid card hero and the full
// tool-page background. One environment value carries the active tool id into the shared ToolPage
// scaffold, so no per-tool view has to be touched.

enum TenzyArt {
    enum Kind: String { case card, page }

    static func themeToken(_ t: TenzyTheme) -> String {
        switch t {
        case .daylight: return "daylight"
        case .midnight: return "midnight"
        case .warmPaper: return "warmpaper"
        case .neoPop: return "neopop"
        case .mono: return "mono"
        }
    }

    static func variant(_ t: TenzyTheme, _ scheme: ColorScheme) -> String {
        switch t {
        case .daylight: return scheme == .dark ? "dark" : "light"
        case .midnight: return "dark"
        default: return "light"
        }
    }

    /// New tools reuse the claymorphic art of the tools they replaced, so the set stays visually
    /// consistent with no new imagesets: See & Read inherits Magnifier's art, Identify the Scene
    /// Describer's, File Opener the Lens's, Warranty the Share-Ready's, Price Check the Live Captions'.
    private static let artAlias: [String: String] = [
        "seeread": "magnify",
        "identify": "describe",
        "fileviewer": "lens",
        "warranty": "shareready",
        "pricecheck": "livecaptions",
    ]

    static func name(id: String, theme: TenzyTheme, scheme: ColorScheme, kind: Kind) -> String {
        let art = artAlias[id] ?? id
        return "bg_\(art)_\(themeToken(theme))_\(variant(theme, scheme))_\(kind.rawValue)"
    }
}

// Active tool id, threaded from ToolDestination down into the shared ToolPage scaffold.
private struct ToolIDKey: EnvironmentKey { static let defaultValue: String = "" }
extension EnvironmentValues {
    var toolID: String {
        get { self[ToolIDKey.self] }
        set { self[ToolIDKey.self] = newValue }
    }
}

/// The tool's themed hero illustration shown as an accent strip along the bottom of a home-grid
/// card. The card's icon/title/blurb sit in a solid surface band above this, so text is always
/// fully crisp; the strip's top edge fades into that band so the join reads as one tile.
struct ToolCardStripArt: View {
    let id: String
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let name = TenzyArt.name(id: id, theme: theme.current, scheme: scheme, kind: .card)
        ZStack {
            HandyColor.surface
            Image(name)
                .resizable()
                .scaledToFill()
            LinearGradient(
                stops: [
                    .init(color: HandyColor.surface, location: 0.0),
                    .init(color: HandyColor.surface.opacity(0.0), location: 0.65)
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
        .clipped()
        .allowsHitTesting(false)
    }
}

/// Full tool-page background. The art is composed with a clear upper area for the tool's controls;
/// a soft scrim that deepens toward the bottom keeps scrolled content legible without reducing the
/// illustration to a whisper.
struct ToolPageArt: View {
    let id: String
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let name = TenzyArt.name(id: id, theme: theme.current, scheme: scheme, kind: .page)
        ZStack {
            HandyColor.bg
            Image(name)
                .resizable()
                .scaledToFill()
            LinearGradient(
                colors: [
                    HandyColor.bg.opacity(0.10),
                    HandyColor.bg.opacity(0.45),
                    HandyColor.bg.opacity(0.84)
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
