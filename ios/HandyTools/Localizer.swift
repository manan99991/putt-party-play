import Foundation
import SwiftUI

/// App-wide localization. Every user-facing string is written in English in the code and looked up here by
/// its English text, so a translation is pure data in `translations.json` (English → { lang: translation })
/// and adding a language or a string never touches a call site. The device language is read directly from
/// the user's preferred languages, unless they picked one in Settings or on the welcome screen. Anything missing
/// — a string with no entry, a language we don't ship, a malformed file — falls back to the English text,
/// so the UI is never blank or broken. Usage: `Text(L("Add to Reminders"))`, `Text(L(tool.name))`.
func L(_ english: String) -> String { Localizer.shared.translate(english) }

final class Localizer {
    static let shared = Localizer()

    /// Where the person's own choice is kept ("" or missing = follow the phone).
    static let key = "tenzy.language"
    /// The languages Tenzy speaks, each in its own name, after "Phone language".
    static let choices: [(code: String, name: String)] = [
        ("", "Phone language"), ("en", "English"), ("es", "Español"), ("fr", "Français"), ("de", "Deutsch"),
        ("it", "Italiano"), ("pt", "Português"), ("hi", "हिन्दी"), ("ja", "日本語"), ("zh", "中文"),
    ]

    /// The phone's own top language, two letters.
    static var phoneLanguage: String {
        let pref = Locale.preferredLanguages.first ?? "en"
        return String(pref.split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? "en").lowercased()
    }

    /// The person's choice in Settings ("" = the phone's language).
    static var chosen: String {
        let c = UserDefaults.standard.string(forKey: key) ?? ""
        return choices.contains { $0.code == c } ? c : ""
    }

    /// The two-letter language the app is showing (es, fr, de, pt, it, hi, ja, zh…), or "en".
    var language: String { lock.lock(); defer { lock.unlock() }; return current }
    private var current: String
    private let lock = NSLock()
    private let table: [String: [String: String]]

    private init() {
        let c = Self.chosen
        current = c.isEmpty ? Self.phoneLanguage : c
        if let url = Bundle.main.url(forResource: "translations", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: [String: String]] {
            table = obj
        } else {
            table = [:]
        }
    }

    /// Switch language now ("" = follow the phone). The app's root redraws itself from the saved choice.
    func use(_ code: String) {
        let c = Self.choices.contains { $0.code == code } ? code : ""
        lock.lock(); current = c.isEmpty ? Self.phoneLanguage : c; lock.unlock()
        UserDefaults.standard.set(c, forKey: Self.key)
    }

    /// The chosen language's own name, for Settings and the welcome screen.
    static var chosenName: String {
        let c = chosen
        return c.isEmpty ? L("Phone language") : (choices.first { $0.code == c }?.name ?? "English")
    }

    func translate(_ english: String) -> String {
        let lang = language
        guard lang != "en" else { return english }
        // An empty entry counts as missing, so a gap in the file shows English, never a blank label.
        guard let t = table[english]?[lang], !t.isEmpty else { return english }
        return t
    }
}

/// The language choice as a menu: in Settings and on the welcome screen. Picking one switches the whole app at once.
struct LanguageMenu<Label: View>: View {
    /// Runs after the switch (Settings reopens itself once the app has redrawn).
    var picked: () -> Void = {}
    @ViewBuilder var label: () -> Label
    var body: some View {
        Menu {
            ForEach(Localizer.choices, id: \.code) { c in
                Button {
                    Localizer.shared.use(c.code)
                    picked()
                } label: {
                    if Localizer.chosen == c.code { SwiftUI.Label(c.code.isEmpty ? L(c.name) : c.name, systemImage: "checkmark") }
                    else { Text(c.code.isEmpty ? L(c.name) : c.name) }
                }
            }
        } label: { label() }
        .accessibilityIdentifier("language-menu")
    }
}
