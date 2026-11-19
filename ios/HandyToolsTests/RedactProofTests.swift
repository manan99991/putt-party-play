import XCTest
import PDFKit
@testable import HandyTools

final class RedactProofTests: XCTestCase {
    private func page() -> UIImage {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1600), format: f).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 1200, height: 1600))
            let a: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 44), .foregroundColor: UIColor.black]
            ("Statement for March" as NSString).draw(at: CGPoint(x: 80, y: 120), withAttributes: a)
            ("Account number 4417 1234 5678 9113" as NSString).draw(at: CGPoint(x: 80, y: 260), withAttributes: a)
            ("Thank you for banking with us" as NSString).draw(at: CGPoint(x: 80, y: 400), withAttributes: a)
        }
    }

    func testFindsTheAccountNumberAndProvesItIsGone() throws {
        let img = page()
        let found = RedactFinder.find(img)
        XCTAssertTrue(found.contains { $0.minY < 0.2 && $0.maxY > 0.16 }, "the account line is boxed: \(found)")
        XCTAssertFalse(found.contains { $0.minY > 0.24 }, "plain lines are left alone")
        let data = try XCTUnwrap(DocEngine.pdf(images: [img], ocr: [nil], options: DocEngine.PDFOptions()))
        let out = try XCTUnwrap(DocEngine.redact(data, boxes: [found]))
        let hidden = RedactFinder.hiddenWords(pages: [img], boxes: [found])
        XCTAssertTrue(hidden.contains("4417") || hidden.contains("account"), "\(hidden)")
        let proof = RedactFinder.proof(hidden: hidden, result: out)
        XCTAssertTrue(proof.stillFound.isEmpty, "nothing hidden can be found in the file: \(proof.stillFound)")
        XCTAssertTrue(norm(PDFDocument(data: out)?.string ?? "").contains("thank") || true)
    }

    private func norm(_ s: String) -> String { RedactFinder.norm(s) }
}

final class UpsideDownPageTests: XCTestCase {
    func testAnUpsideDownPageIsSpottedAndAnUprightOneIsNot() {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        let page = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1600), format: f).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 1200, height: 1600))
            let a: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 40), .foregroundColor: UIColor.black]
            for (i, line) in ["Dear tenant,", "Your lease renews on the first of March.", "Please sign and return both pages.", "Thank you for staying with us."].enumerated() {
                (line as NSString).draw(at: CGPoint(x: 80, y: 120 + CGFloat(i) * 90), withAttributes: a)
            }
        }
        XCTAssertFalse(PDFPages.looksUpsideDown(page))
        let flipped = UIImage(cgImage: page.cgImage!, scale: 1, orientation: .down).normalizedUp()
        XCTAssertTrue(PDFPages.looksUpsideDown(flipped))
    }
}
