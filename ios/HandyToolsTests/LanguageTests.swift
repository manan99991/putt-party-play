import XCTest
@testable import HandyTools

final class LanguageTests: XCTestCase {
    /// 24 Nov: the Home tab read "Privat" / "Casa" / "自宅" (the address label). The tab has its own word now, and
    /// Contacts keeps the address one.
    func testHomeTabIsTheScreenNotAnAddress() {
        let before = UserDefaults.standard.string(forKey: Localizer.key)
        defer { Localizer.shared.use(before ?? "") }
        let want = ["de": "Start", "es": "Inicio", "fr": "Accueil", "it": "Home", "pt": "Início", "ja": "ホーム", "zh": "首页", "hi": "होम", "en": "Home"]
        for (lang, word) in want {
            Localizer.shared.use(lang)
            XCTAssertEqual(RootTab.home.shown, word, "Home tab in \(lang)")
        }
        Localizer.shared.use("de")
        XCTAssertEqual(L("Home"), "Privat", "the address label in Contacts keeps its meaning")
        XCTAssertNotEqual(RootTab.settings.shown, "Settings", "the other tabs are translated too")
    }

    /// Picking a language in Settings switches every L() at once, and "Phone language" goes back to the phone's.
    func testChoosingALanguageSwitchesAtOnce() {
        let before = UserDefaults.standard.string(forKey: Localizer.key)
        defer { Localizer.shared.use(before ?? "") }
        Localizer.shared.use("fr")
        XCTAssertEqual(Localizer.shared.language, "fr")
        XCTAssertEqual(L("Show me"), "Montre-moi")
        XCTAssertEqual(Localizer.chosenName, "Français")
        Localizer.shared.use("ja")
        XCTAssertEqual(L("Phone language"), "端末の言語")
        Localizer.shared.use("en")
        XCTAssertEqual(L("Show me"), "Show me")
        Localizer.shared.use("")
        XCTAssertEqual(Localizer.shared.language, Localizer.phoneLanguage)
        XCTAssertEqual(Localizer.chosen, "")
        // Something it doesn't speak is the phone's language, never a blank app.
        Localizer.shared.use("xx")
        XCTAssertEqual(Localizer.chosen, "")
    }

    func testEveryChoiceIsTranslated() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "translations", withExtension: "json"))
        let table = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: [String: String]])
        for c in Localizer.choices where !c.code.isEmpty && c.code != "en" {
            XCTAssertNotNil(table["Language"]?[c.code], c.code)
            XCTAssertNotNil(table["Phone language"]?[c.code], c.code)
        }
    }
}
