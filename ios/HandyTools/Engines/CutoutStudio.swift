import UIKit
import Vision
import CoreImage

/// Everything after the cut: which subject (when there are several), what goes behind it, a shadow so it
/// doesn't float, the shape it's going into, and an honest note when the subject runs off the photo's edge.
enum CutoutStudio {
    enum Backdrop: String, CaseIterable, Identifiable {
        case clear, white, black, grey, colour, blur
        var id: String { rawValue }
        var label: String { ["See-through", "White", "Black", "Soft grey", "Your colour", "Blurred photo"][Self.allCases.firstIndex(of: self)!] }
    }
    enum Fit: String, CaseIterable, Identifiable {
        case asIs, tight, square, story
        var id: String { rawValue }
        var label: String { ["As taken", "Close crop", "Square", "Story 9:16"][Self.allCases.firstIndex(of: self)!] }
    }
    struct Edges: OptionSet { let rawValue: Int
        static let left = Edges(rawValue: 1), right = Edges(rawValue: 2), top = Edges(rawValue: 4), bottom = Edges(rawValue: 8) }

    /// Each subject the phone finds, cut out on its own (person, pet, object…), biggest first — so you can keep
    /// just one when there are several. Empty when the model finds none.
    static func subjects(_ image: UIImage) -> [UIImage] {
        guard let cg = image.normalizedUp().cgImage else { return [] }
        let handler = VNImageRequestHandler(cgImage: cg)
        let req = VNGenerateForegroundInstanceMaskRequest()
        guard (try? handler.perform([req])) != nil, let res = req.results?.first, res.allInstances.count > 1 else { return [] }
        var out: [(UIImage, CGFloat)] = []
        for i in res.allInstances {
            guard let m = try? res.generateScaledMaskForImage(forInstances: IndexSet(integer: i), from: handler),
                  let cut = ImageStudio.refinedCutout(cg, mask: CIImage(cvPixelBuffer: m)),
                  let c = cut.cgImage, let box = ImageStudio.opaqueBounds(c) else { continue }
            out.append((cut, box.width * box.height))
        }
        return out.sorted { $0.1 > $1.1 }.map(\.0)
    }

    /// Which sides of the photo the subject is cut off by (it touches the edge, so it ends in a straight line).
    static func cutOffEdges(_ cut: UIImage) -> Edges {
        guard let cg = cut.cgImage, let b = ImageStudio.opaqueBounds(cg) else { return [] }
        let w = CGFloat(cg.width), h = CGFloat(cg.height), m = max(2, min(w, h) * 0.004)
        var e: Edges = []
        if b.minX <= m { e.insert(.left) }; if b.maxX >= w - m { e.insert(.right) }
        if b.minY <= m { e.insert(.top) }; if b.maxY >= h - m { e.insert(.bottom) }
        return e
    }

    /// A plain sentence for the edges, or nil. The bottom edge is normal for a portrait (it's where the body goes on).
    static func edgeNote(_ e: Edges) -> String? {
        guard !e.intersection([.left, .right, .top]).isEmpty else { return nil }
        return "Part of the subject runs off the edge of your photo, so it ends in a straight line there. For a clean edge all round, use a photo with a little space around them."
    }

    /// The finished picture: the subject on the chosen backdrop, with a soft shadow if wanted, in the chosen shape.
    static func render(_ cut: UIImage, original: UIImage?, backdrop: Backdrop, colour: UIColor = .systemTeal, shadow: Bool, fit: Fit) -> UIImage? {
        guard let cg = cut.cgImage else { return nil }
        let full = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
        guard let box = ImageStudio.opaqueBounds(cg) else { return nil }
        // Canvas and where the subject's box lands on it.
        let canvas: CGSize, dest: CGRect
        switch fit {
        case .asIs:
            canvas = full.size; dest = box
        case .tight:
            let pad = max(box.width, box.height) * 0.06
            canvas = CGSize(width: box.width + pad * 2, height: box.height + pad * 2)
            dest = CGRect(x: pad, y: pad, width: box.width, height: box.height)
        case .square, .story:
            let aspect: CGFloat = fit == .square ? 1 : 9.0 / 16.0
            let side = max(box.height / 0.82, box.width / 0.82 / aspect)
            canvas = CGSize(width: (side * aspect).rounded(), height: side.rounded())
            let s = min(canvas.width * 0.86 / box.width, canvas.height * 0.86 / box.height, 1)
            let w = box.width * s, h = box.height * s
            // Sit a person a little low, like a portrait; centre anything else.
            dest = CGRect(x: (canvas.width - w) / 2, y: canvas.height - h - canvas.height * 0.05, width: w, height: h)
        }
        guard let subject = cg.cropping(to: box) else { return nil }
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = backdrop != .clear
        return UIGraphicsImageRenderer(size: canvas, format: fmt).image { ctx in
            let c = ctx.cgContext
            let all = CGRect(origin: .zero, size: canvas)
            switch backdrop {
            case .clear: break
            case .white: UIColor.white.setFill(); c.fill(all)
            case .black: UIColor.black.setFill(); c.fill(all)
            case .grey: UIColor(white: 0.93, alpha: 1).setFill(); c.fill(all)
            case .colour: colour.setFill(); c.fill(all)
            case .blur:
                if let o = original {
                    let b = ImageStudio.blurred(o.normalizedUp(), radius: max(o.size.width, o.size.height) / 60)
                    // Fill the canvas with the blurred photo, keeping its proportions.
                    let s = max(canvas.width / b.size.width, canvas.height / b.size.height)
                    let bw = b.size.width * s, bh = b.size.height * s
                    b.draw(in: CGRect(x: (canvas.width - bw) / 2, y: (canvas.height - bh) / 2, width: bw, height: bh))
                } else { UIColor(white: 0.93, alpha: 1).setFill(); c.fill(all) }
            }
            if shadow {
                c.saveGState()
                c.setShadow(offset: CGSize(width: 0, height: dest.height * 0.015), blur: dest.height * 0.04, color: UIColor(white: 0, alpha: 0.35).cgColor)
                UIImage(cgImage: subject).draw(in: dest)
                c.restoreGState()
            } else {
                UIImage(cgImage: subject).draw(in: dest)
            }
        }
    }
}
