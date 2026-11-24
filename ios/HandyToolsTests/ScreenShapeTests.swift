import XCTest
import UIKit
@testable import HandyTools

/// Identify finds a TV by its shape (24 Nov): a big, wide, TV-proportioned rectangle with a dark bezel, in a room.
/// Drawn pictures, so it runs everywhere: a TV on a wall is found whatever it shows; a light-framed painting, a
/// square picture and a photo that's all screen are not called a TV.
final class ScreenShapeTests: XCTestCase {
    private func room(_ draw: (CGContext) -> Void) -> CGImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 900, height: 1200), format: fmt).image { c in
            UIColor(red: 0.82, green: 0.86, blue: 0.84, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: 900, height: 1200))      // wall
            UIColor(red: 0.45, green: 0.3, blue: 0.2, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 820, width: 900, height: 380))        // floor
            UIColor(white: 0.4, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 960, width: 900, height: 240))                               // sofa
            draw(c.cgContext)
        }.cgImage!
    }
    private func tv(_ ctx: CGContext, screen: UIColor) {
        ctx.setFillColor(UIColor(white: 0.04, alpha: 1).cgColor); ctx.fill(CGRect(x: 170, y: 360, width: 560, height: 315))
        ctx.setFillColor(screen.cgColor); ctx.fill(CGRect(x: 178, y: 368, width: 544, height: 299))
    }

    func testATVOnTheWallIsATVWhateverItShows() {
        for (name, colour) in [("dark blue menu", UIColor(red: 0.05, green: 0.1, blue: 0.45, alpha: 1)),
                               ("bright show", UIColor(red: 0.95, green: 0.75, blue: 0.3, alpha: 1)),
                               ("switched off", UIColor(white: 0.06, alpha: 1))] {
            let s = Identifier.screenIn(room { tv($0, screen: colour) })
            XCTAssertEqual(s?.label, "Television", "a TV showing \(name) wasn't found")
        }
    }

    func testAPaintingIsNotATV() {
        let painting = room { ctx in
            ctx.setFillColor(UIColor(red: 0.93, green: 0.9, blue: 0.82, alpha: 1).cgColor); ctx.fill(CGRect(x: 170, y: 360, width: 560, height: 315))  // light frame
            ctx.setFillColor(UIColor(red: 0.9, green: 0.5, blue: 0.3, alpha: 1).cgColor); ctx.fill(CGRect(x: 200, y: 390, width: 500, height: 255))
        }
        XCTAssertNil(Identifier.screenIn(painting), "a light-framed painting was called a TV")
        let square = room { ctx in
            ctx.setFillColor(UIColor(white: 0.04, alpha: 1).cgColor); ctx.fill(CGRect(x: 250, y: 300, width: 400, height: 400))
        }
        XCTAssertNil(Identifier.screenIn(square), "a square picture was called a TV")
    }

    func testAPhotoThatIsAllScreenIsNotCalledATVInARoom() {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let shot = UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 900), format: fmt).image { c in
            UIColor(white: 0.04, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: 1600, height: 900))
            UIColor.systemBlue.setFill(); c.fill(CGRect(x: 10, y: 10, width: 1580, height: 880))
        }.cgImage!
        XCTAssertNil(Identifier.screenIn(shot), "a photo that is all screen is a screenshot, not a TV in a room")
    }
}
