import XCTest
import Vision
@testable import HandyTools

/// Today's collage (25 Nov): every photo is cropped around its faces so nobody is cut off, the collage is the full
/// shareable size, and the date sits underneath. Proven on the encrypted real photos when they're decrypted for the
/// run; the cropping rule itself on drawn shapes everywhere.
final class SmartCollageTests: XCTestCase {
    func testAFaceNearTheEdgeIsBroughtIntoTheFrame() {
        // A tall photo filled into a square frame: centred, a face near the top would be cut; focused, it's in.
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let size = CGSize(width: 100, height: 300)
        let centred = CollageLayout.placed(size, in: frame, focus: nil)
        let focused = CollageLayout.placed(size, in: frame, focus: CGPoint(x: 0.5, y: 0.08))
        let faceY = { (r: CGRect) in r.minY + 0.08 * r.height }
        XCTAssertFalse(frame.contains(CGPoint(x: 50, y: faceY(centred))), "centred cropping cuts the face off")
        XCTAssertTrue(frame.contains(CGPoint(x: 50, y: faceY(focused))))
        XCTAssertLessThanOrEqual(focused.minY, frame.minY); XCTAssertGreaterThanOrEqual(focused.maxY, frame.maxY, "never a gap")
    }

    func testTheCollageIsFullSizeWithTheDateUnderneath() {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        let shots = (0..<5).map { k in UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800), format: f).image { c in
            UIColor(hue: CGFloat(k) / 5, saturation: 0.7, brightness: 0.8, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: 600, height: 800)) } }
        let out = CollageLayout.render(shots, layout: .hero, canvas: CGSize(width: 2160, height: 2700), gapRatio: 0.012, cornerRatio: 0.018,
                                       background: .white, focus: nil, footer: "Wednesday, November 25")
        XCTAssertEqual(out.size, CGSize(width: 2160, height: 2700))
        // The footer band is the background with dark text in it: some dark pixels in the bottom band, none of the photos.
        let g = Stitcher.grayscale(out, width: 216)
        let bottom = g.px[(g.rows - 17) * g.width ..< (g.rows - 2) * g.width]
        XCTAssertTrue(bottom.contains { $0 < 120 }, "the date isn't written under the photos")
    }

    func testRealPhotosKeepEveryFaceInItsTile() throws {
        guard let root = ProcessInfo.processInfo.environment["REAL_PHOTOS"] else { throw XCTSkip("private photos not decrypted") }
        let dir = URL(fileURLWithPath: root).appendingPathComponent("private")
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        var people: [(UIImage, CGRect)] = []
        for u in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where ["jpg", "jpeg", "png", "heic"].contains(u.pathExtension.lowercased()) {
            guard let img = UIImage(contentsOfFile: u.path)?.normalizedUp().resized(maxDimension: 1400), let cg = img.cgImage else { continue }
            let req = VNDetectFaceRectanglesRequest()
            try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req])
            guard let faces = req.results, !faces.isEmpty else { continue }
            let u = faces.map(\.boundingBox).reduce(faces[0].boundingBox) { $0.union($1) }
            people.append((img, CGRect(x: u.minX, y: 1 - u.maxY, width: u.width, height: u.height)))   // top-left, 0…1
            if people.count == 10 { break }
        }
        guard people.count >= 3 else { throw XCTSkip("fewer than three real photos with faces") }
        let canvas = CGSize(width: 2160, height: 2700)
        let short = min(canvas.width, canvas.height), gap = (short * 0.012).rounded(), band = (short * 0.085).rounded()
        for layout in [CollageLayout.hero, .grid, .mosaic] {
            let frames = layout.frames(count: people.count, canvas: CGSize(width: canvas.width, height: canvas.height - band), gap: gap)
            var checked = 0, fits = 0
            for ((img, face), fr) in zip(people, frames) {
                let k = max(fr.width / img.size.width, fr.height / img.size.height)
                let sz = CGSize(width: img.size.width * k, height: img.size.height * k)
                let focus = SmartCollage.faceFocus(img)
                let at = CollageLayout.placed(sz, in: fr, focus: focus)
                let faceRect = CGRect(x: at.minX + face.minX * at.width, y: at.minY + face.minY * at.height, width: face.width * at.width, height: face.height * at.height)
                // Only faces that can fit the tile at all are judged (a crowd filling a wide photo can't fit a narrow tile).
                guard faceRect.width <= fr.width, faceRect.height <= fr.height else { continue }
                checked += 1
                if fr.insetBy(dx: -2, dy: -2).contains(faceRect) { fits += 1 }
            }
            print("COLLAGE| \(layout.rawValue): \(fits)/\(checked) faces fully in their tile")
            XCTAssertEqual(fits, checked, "\(layout.title): a face was cut off at a tile's edge")
        }
        let out = CollageLayout.render(people.map(\.0), layout: .hero, canvas: canvas, gapRatio: 0.012, cornerRatio: 0.018, background: .white,
                                       focus: people.map { SmartCollage.faceFocus($0.0) }, footer: "Wednesday, November 25")
        XCTAssertEqual(out.size, canvas)
    }
}
