import XCTest
@testable import HandyTools

final class LanguageTests: XCTestCase {
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
