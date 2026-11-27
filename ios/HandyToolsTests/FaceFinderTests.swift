import XCTest
import CoreImage
import UIKit
import Vision
@testable import HandyTools

/// 27 Nov: on the build machine the face finder hands back different landmarks each time it's asked about the same
/// picture (the face box stays put; the points inside it drift outward). This asks six times in each of several ways
/// and prints how far the points spread (numbers only), so the steady way is chosen from facts.
final class FaceFinderTests: XCTestCase {
    func testWhichWayOfAskingGivesTheSameFaceEveryTime() throws {
        guard let root = ProcessInfo.processInfo.environment["REAL_PHOTOS"] else { throw XCTSkip("private photos not decrypted") }
        let files = (FileManager.default.enumerator(atPath: root)?.allObjects as? [String] ?? []).filter { ["jpg", "jpeg", "png", "heic"].contains(($0 as NSString).pathExtension.lowercased()) }.sorted()
        let ctx = CIContext()
        var tried = 0
        for file in files {
            guard tried < 3, let ui = UIImage(contentsOfFile: (root as NSString).appendingPathComponent(file))?.normalizedUp(), let cg0 = ui.cgImage else { continue }
            var src = CIImage(cgImage: cg0)
            let k = min(1, 900 / max(src.extent.width, src.extent.height))
            src = src.transformed(by: CGAffineTransform(scaleX: k, y: k))
            guard let cg = ctx.createCGImage(src, from: src.extent) else { continue }
            let img = CIImage(cgImage: cg)
            let rect = VNDetectFaceRectanglesRequest()
            try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([rect])
            guard let firstBox = rect.results?.first, firstBox.boundingBox.width > 0.12 else { continue }
            tried += 1
            /// The contour's spread across, as a share of the face box (should be about 0.9 and the same every time).
            func spread(_ o: VNFaceObservation?) -> String {
                guard let p = o?.landmarks?.faceContour?.normalizedPoints, !p.isEmpty else { return "none" }
                let xs = p.map(\.x), ys = p.map(\.y)
                return String(format: "%.2f×%.2f [%.2f…%.2f]", (xs.max()! - xs.min()!), (ys.max()! - ys.min()!), xs.min()!, xs.max()!)
            }
            var ways: [(String, () -> VNFaceObservation?)] = []
            ways.append(("default-ciimage", {
                let r = VNDetectFaceLandmarksRequest(); try? VNImageRequestHandler(ciImage: img, options: [:]).perform([r]); return r.results?.first }))
            ways.append(("default-cgimage", {
                let r = VNDetectFaceLandmarksRequest(); try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([r]); return r.results?.first }))
            for rev in VNDetectFaceLandmarksRequest.supportedRevisions.sorted() {
                ways.append(("revision\(rev)", {
                    let r = VNDetectFaceLandmarksRequest(); r.revision = rev; try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([r]); return r.results?.first }))
            }
            ways.append(("given-box", {
                let r = VNDetectFaceLandmarksRequest(); r.inputFaceObservations = [firstBox]
                try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([r]); return r.results?.first }))
            ways.append(("cpu-only", {
                let r = VNDetectFaceLandmarksRequest(); r.usesCPUOnly = true
                try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([r]); return r.results?.first }))
            for (name, ask) in ways {
                let seen = (0..<6).map { _ in spread(ask()) }
                print("VIDEOFX|finder|photo\(tried)|\(name)|" + seen.joined(separator: " | "))
            }
            let f = FaceFun.faces(in: img).first
            print("VIDEOFX|finder|photo\(tried)|default revision \(VNDetectFaceLandmarksRequest.defaultRevision) supported \(VNDetectFaceLandmarksRequest.supportedRevisions.sorted())|face width \(Int(f?.width ?? -1))")
        }
        if tried == 0 { throw XCTSkip("no real photo with a clear face") }
    }
}
