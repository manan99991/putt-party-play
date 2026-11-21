import XCTest
@testable import HandyTools

/// "Sign a form and send it" put the signature in a fixed corner of the page; Sign PDF already found the form's own
/// "Signed:" and "Date:" lines. The ready-made signing tools now use the same reading, so the ink lands on the line.
final class SignWhereAskedTests: XCTestCase {
    /// Average darkness (0 white … 1 black) of a box around a normalised, top-left-origin point.
    private func ink(_ img: UIImage, at p: CGPoint, w: CGFloat) -> Double {
        guard let cg = img.cgImage else { return 0 }
        let W = CGFloat(cg.width), H = CGFloat(cg.height)
        let box = CGRect(x: (p.x - w / 2) * W, y: (p.y - 0.015) * H, width: w * W, height: 0.03 * H).integral
        guard let crop = cg.cropping(to: box) else { return 0 }
        let n = 32
        var px = [UInt8](repeating: 0, count: n * n)
        guard let ctx = CGContext(data: &px, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return 0 }
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: n, height: n))
        return 1 - Double(px.reduce(0) { $0 + Int($1) }) / Double(n * n * 255)
    }

    func testTheSignatureAndDateLandOnTheFormsOwnLines() async throws {
        let page = SampleAssets.document()   // "Signed: ______   Date: ______"
        let spots = SignSpots.find(page)
        let sig = try XCTUnwrap(spots.first { $0.kind == .signature }, "the sample's Signed: line wasn't read")
        let date = try XCTUnwrap(spots.first { $0.kind == .date }, "the sample's Date: line wasn't read")

        let hadOne = DocEngine.savedSignature != nil
        if !hadOne {
            let mark = UIGraphicsImageRenderer(size: CGSize(width: 420, height: 140)).image { _ in
                ("Alex Sample" as NSString).draw(at: CGPoint(x: 10, y: 30), withAttributes: [.font: UIFont.italicSystemFont(ofSize: 60), .foregroundColor: UIColor.black])
            }
            XCTAssertNotNil(DocEngine.saveSignature(image: mark))
        }
        defer { if !hadOne { DocEngine.clearSignature() } }

        let step = ChainStep(block: .stamp, settings: ["marks": StampPlan.standard.text])
        guard case .success(.image(let out)) = await ChainRunner.apply(step, to: .image(page)) else { return XCTFail("signing gave no page") }
        XCTAssertGreaterThan(ink(out, at: sig.center, w: sig.width) - ink(page, at: sig.center, w: sig.width), 0.02,
                             "no signature on the Signed: line at \(sig.center)")
        XCTAssertGreaterThan(ink(out, at: date.center, w: date.width) - ink(page, at: date.center, w: date.width), 0.01,
                             "no date on the Date: line at \(date.center)")
    }
}
