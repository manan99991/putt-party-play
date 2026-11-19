import XCTest
import UIKit
@testable import HandyTools

/// Passport photos: the country rules are internally consistent, the print sheet holds the right number
/// of true-size copies, the head measurement stays believable, and a photo with no face is turned away
/// honestly. (Real faces are checked on a phone: the simulator can't be given a real portrait here.)
final class PassportPhotoTests: XCTestCase {

    func testEveryCountryRuleFitsItsPhoto() {
        for s in PassportPhoto.specs {
            XCTAssertLessThan(s.head.upperBound, Double(s.mm.height), s.id)
            XCTAssertGreaterThan(s.head.lowerBound, Double(s.mm.height) * 0.4, s.id)
            // The file has the same shape as the printed photo, so millimetres map straight onto pixels.
            XCTAssertEqual(Double(s.px.width / s.px.height), Double(s.mm.width / s.mm.height), accuracy: 0.005, s.id)
            if let e = s.eyes { XCTAssertLessThan(e.upperBound, Double(s.mm.height), s.id) }
            XCTAssertFalse(s.rules.isEmpty, s.id)
        }
        let us = PassportPhoto.spec("us")
        XCTAssertEqual(us.head, 25...35)                  // travel.state.gov: 1 to 1⅜ in, chin to top of head
        XCTAssertEqual(PassportPhoto.spec("uk").head, 29...34)
        XCTAssertEqual(PassportPhoto.spec("ca").head, 31...36)
        XCTAssertEqual(PassportPhoto.spec("uk").background, .lightGrey)
        XCTAssertTrue(PassportPhoto.spec("in").unaltered)
        XCTAssertFalse(PassportPhoto.Options.defaults(for: PassportPhoto.spec("in")).background, "India: no software edits by default")
        XCTAssertTrue(PassportPhoto.Options.defaults(for: us).background)
        XCTAssertEqual(PassportPhoto.spec("nope").id, "us", "an unknown setting falls back to the US")
        XCTAssertEqual(PassportPhoto.spec("ca-online").headText, "45–50% of the height")
        XCTAssertEqual(us.headText, "25–35 mm")
    }

    private func made(_ id: String) -> PassportPhoto.Made {
        let s = PassportPhoto.spec(id)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        let img = UIGraphicsImageRenderer(size: s.px, format: fmt).image { c in UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: s.px)) }
        let g = PassportPhoto.Guides(crownY: 40, chinY: 400, eyeY: 220, headBand: 10...100, eyeBand: nil, centreX: s.px.width / 2)
        return PassportPhoto.Made(image: img, spec: s, options: .defaults(for: s), checks: [], fixes: [], guides: g, headMM: 30, eyesMM: 30, score: 100)
    }

    func testPrintSheetHoldsTrueSizeCopies() throws {
        let us = try XCTUnwrap(PassportPhoto.printSheet(made("us")))
        XCTAssertEqual(us.copies, 2, "two 2×2 in photos fit a 4×6 in print with margins")
        let uk = try XCTUnwrap(PassportPhoto.printSheet(made("uk")))
        XCTAssertEqual(uk.copies, 6, "six 35×45 mm photos fit a 4×6 in print")
        let india = try XCTUnwrap(PassportPhoto.printSheet(made("in")))
        XCTAssertEqual(india.copies, 6, "India's 630×810 file still prints at 35×45 mm")
        let ca = try XCTUnwrap(PassportPhoto.printSheet(made("ca")))
        XCTAssertEqual(ca.copies, 2, "Canada asks for two prints")
        let sheet = try XCTUnwrap(UIImage(data: us.data))
        XCTAssertEqual(sheet.size.width * sheet.scale, 1200, accuracy: 1)
        XCTAssertEqual(sheet.size.height * sheet.scale, 1800, accuracy: 1)
    }

    func testOnlineFileMeetsCanadasLimits() throws {
        let d = try XCTUnwrap(PassportPhoto.file(made("ca-online")))
        let img = try XCTUnwrap(UIImage(data: d))
        XCTAssertEqual(img.size.width * img.scale, 1200, accuracy: 1)
        XCTAssertEqual(img.size.height * img.scale, 1800, accuracy: 1)
        XCTAssertLessThan(d.count, 5_000_000)
    }

    func testHeadTopStaysBelievable() {
        func face(crownY: CGFloat) -> PassportPhoto.Face {
            PassportPhoto.Face(box: CGRect(x: 100, y: 100, width: 200, height: 260), chin: CGPoint(x: 200, y: 400), crown: CGPoint(x: 200, y: crownY),
                               eyes: (CGPoint(x: 160, y: 250), CGPoint(x: 240, y: 250)), crownMeasured: true, roll: 0, yaw: 0, pitch: 0,
                               eyeOpen: [0.3, 0.3], mouth: 0.3, quality: 0.6, count: 1)
        }
        // Eye to chin is 150 px: a normal head is ~1.8–2.7× that.
        var normal = face(crownY: 400 - 150 * 2.2)
        XCTAssertFalse(PassportPhoto.clampCrown(&normal))
        XCTAssertEqual(normal.crown.y, 400 - 150 * 2.2, accuracy: 0.5)
        var tallHat = face(crownY: 0)                       // a hat or big hair reads far too tall
        XCTAssertTrue(PassportPhoto.clampCrown(&tallHat))
        XCTAssertEqual(tallHat.crown.y, 400 - 150 * 2.7, accuracy: 0.5)
        var cutOff = face(crownY: 300)                      // the outline stopped at the forehead
        XCTAssertTrue(PassportPhoto.clampCrown(&cutOff))
        XCTAssertFalse(cutOff.crownMeasured)
    }

    func testNoFaceIsTurnedAwayNotFaked() {
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 1000), format: fmt).image { c in
            UIColor(red: 0.4, green: 0.6, blue: 0.8, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: 800, height: 1000))
        }
        XCTAssertNil(PassportPhoto.make(blank, spec: PassportPhoto.spec("us")))
    }

    @MainActor func testPassportStepUsesTheSharedEngine() async {
        // The Builder step and Studio both make passport photos with PassportPhoto: no face → an honest failure.
        let chain = Chain(id: "t", name: "t", steps: [ChainStep(block: .passportPhoto, settings: ["country": "uk"])])
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 500), format: fmt).image { c in UIColor.gray.setFill(); c.fill(CGRect(x: 0, y: 0, width: 400, height: 500)) }
        let out = await ChainRunner.run(chain, input: .image(blank))
        if case .success = out { XCTFail("a photo with no face must not come back as a passport photo") }
    }
}
