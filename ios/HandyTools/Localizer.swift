import Foundation

/// App-wide localization. Every user-facing string is written in English in the code and looked up here by
/// its English text, so a translation is pure data in `translations.json` (English → { lang: translation })
/// and adding a language or a string never touches a call site. The device language is read directly from
/// the user's preferred languages, so the app follows the phone without any in-app switch. Anything missing
/// — a string with no entry, a language we don't ship, a malformed file — falls back to the English text,
/// so the UI is never blank or broken. Usage: `Text(L("Add to Reminders"))`, `Text(L(tool.name))`.
func L(_ english: String) -> String { Localizer.shared.translate(english) }

final class Localizer {
    static let shared = Localizer()

    /// The two-letter device language (es, fr, de, pt, it, hi, ja, zh…), or "en".
    let language: String
    private let table: [String: [String: String]]

    private init() {
        // The user's top preferred language, independent of which localizations the bundle declares.
        let pref = Locale.preferredLanguages.first ?? "en"
        language = String(pref.split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? "en").lowercased()

        if let url = Bundle.main.url(forResource: "translations", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: [String: String]] {
            table = obj
        } else {
            table = [:]
        }
    }

    func translate(_ english: String) -> String {
        guard language != "en" else { return english }
        return table[english]?[language] ?? english
    }
}
