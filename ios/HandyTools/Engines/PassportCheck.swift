import UIKit
import Vision

/// A reality check for an ID / passport photo, using Apple's on-device face analysis: one face, looking
/// straight at the camera, eyes open, mouth closed, sharp, evenly lit, enough resolution, and a light
/// plain background. Each check is a plain pass / fail with how to fix it. A helper, not an official
/// verdict — countries add their own rules (glasses, headwear), and the screen says so.
enum PassportCheck {
    struct Item: Identifiable, Equatable {
        let id: String
        let title: String
        let pass: Bool
        let fix: String
    }

    /// `original` is the photo as taken; `finished` is the cropped passport photo (for the background check).
    static func run(original: UIImage, finished: UIImage?) -> [Item] {
        guard let cg = original.normalizedUp().cgImage else { return [] }
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        let rects = VNDetectFaceRectanglesRequest(); rects.revision = VNDetectFaceRectanglesRequestRevision3
        try? handler.perform([rects])
        let faces = rects.results ?? []
        var out: [Item] = []
        out.append(Item(id: "one", title: "One face, clearly visible", pass: faces.count == 1,
                        fix: faces.isEmpty ? "No face found — face the camera with the whole head in view." : "More than one face — only you should be in the photo."))
        guard let face = faces.max(by: { $0.boundingBox.height < $1.boundingBox.height }) else { return out }

        let marks = VNDetectFaceLandmarksRequest(); marks.revision = VNDetectFaceLandmarksRequestRevision3
        marks.inputFaceObservations = [face]
        let quality = VNDetectFaceCaptureQualityRequest(); quality.inputFaceObservations = [face]
        try? handler.perform([marks, quality])
        let lm = marks.results?.first
        let angles = lm ?? face
        func deg(_ n: NSNumber?) -> Double { abs((n?.doubleValue ?? 0) * 180 / .pi) }
        let yaw = deg(angles.yaw), roll = deg(angles.roll), pitch = deg(angles.pitch)
        out.append(Item(id: "straight", title: "Looking straight at the camera", pass: yaw < 10 && roll < 8 && pitch < 14,
                        fix: yaw >= 10 ? "Turn your face to the camera — it's turned to one side."
                             : (roll >= 8 ? "Keep your head level — it's tilted." : "Hold the camera at eye level — chin is up or down.")))

        if let l = lm?.landmarks {
            let eyes = [l.leftEye, l.rightEye].compactMap { $0 }.map(openness)
            out.append(Item(id: "eyes", title: "Eyes open", pass: !eyes.isEmpty && eyes.allSatisfy { $0 > 0.14 },
                            fix: "Eyes look closed or squinting — take another with eyes open."))
            if let lips = l.outerLips {
                out.append(Item(id: "mouth", title: "Neutral face, mouth closed", pass: openness(lips) < 0.45,
                                fix: "Mouth looks open or a big smile — most countries want a neutral expression."))
            }
        }
        if let q = quality.results?.first?.faceCaptureQuality {
            out.append(Item(id: "sharp", title: "Sharp and in focus", pass: q >= 0.35,
                            fix: "The face is soft or blurry — hold steady, use more light, tap to focus."))
        }
        let facePx = face.boundingBox.height * CGFloat(cg.height)
        out.append(Item(id: "resolution", title: "Enough detail to print", pass: facePx >= 240,
                        fix: "The face is small in the photo — step closer or zoom so it fills more of the frame."))
        let box = CGRect(x: face.boundingBox.minX * CGFloat(cg.width), y: (1 - face.boundingBox.maxY) * CGFloat(cg.height),
                         width: face.boundingBox.width * CGFloat(cg.width), height: face.boundingBox.height * CGFloat(cg.height))
        if let (left, right) = halves(cg, box) {
            out.append(Item(id: "light", title: "Even lighting, no harsh shadows", pass: abs(left - right) < 0.16 && min(left, right) > 0.22,
                            fix: min(left, right) <= 0.22 ? "Too dark — face a window or a lamp." : "One side of the face is in shadow — face the light evenly."))
        }
        if let f = finished?.cgImage, let bg = borderStats(f) {
            out.append(Item(id: "background", title: "Light, plain background", pass: bg.mean > 0.72 && bg.spread < 0.12,
                            fix: "Background is dark or busy — stand in front of a plain light wall, or turn on 'Clean white background'."))
        }
        return out
    }

    /// Height / width of a landmark region's bounding box (eye or lips openness).
    static func openness(_ r: VNFaceLandmarkRegion2D) -> Double {
        let pts = r.normalizedPoints
        guard let minX = pts.map(\.x).min(), let maxX = pts.map(\.x).max(),
              let minY = pts.map(\.y).min(), let maxY = pts.map(\.y).max(), maxX > minX else { return 0 }
        return Double((maxY - minY) / (maxX - minX))
    }

    /// Mean brightness (0…1) of the left and right halves of the face box.
    static func halves(_ cg: CGImage, _ box: CGRect) -> (Double, Double)? {
        guard let crop = cg.cropping(to: box.integral), let g = gray(crop, w: 32, h: 32) else { return nil }
        var l = 0.0, r = 0.0
        for y in 0..<32 { for x in 0..<32 { if x < 16 { l += g[y * 32 + x] } else { r += g[y * 32 + x] } } }
        return (l / 512, r / 512)
    }

    /// Mean and spread of the outer border of an image (the background around a passport photo).
    static func borderStats(_ cg: CGImage) -> (mean: Double, spread: Double)? {
        guard let g = gray(cg, w: 40, h: 50) else { return nil }
        var vals: [Double] = []
        for y in 0..<50 { for x in 0..<40 where x < 4 || x >= 36 || y < 4 { vals.append(g[y * 40 + x]) } }
        guard !vals.isEmpty else { return nil }
        let mean = vals.reduce(0, +) / Double(vals.count)
        let sd = (vals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(vals.count)).squareRoot()
        return (mean, sd)
    }

    private static func gray(_ cg: CGImage, w: Int, h: Int) -> [Double]? {
        var px = [UInt8](repeating: 0, count: w * h)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        // A bitmap context stores the top row first, so index 0 is the top-left pixel.
        return px.map { Double($0) / 255 }
    }
}
