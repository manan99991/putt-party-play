import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import simd

/// The colour engine behind Color Vision: daltonization (shift the colours a colour-blind eye
/// confuses into channels it can see), deficiency simulation, single-hue highlighting, and colour
/// naming. Everything is a 3×3 matrix or a 32³ colour cube, so it runs on live video at full frame rate.
enum ColorVision {

    enum Deficiency: Int, CaseIterable {
        case protan, deutan, tritan
        var title: String { ["Red-weak (protan)", "Green-weak (deutan)", "Blue-weak (tritan)"][rawValue] }
        var short: String { ["Red-weak", "Green-weak", "Blue-weak"][rawValue] }
    }

    // Viénot/Brettel-style dichromat simulation in linear RGB (rows = output R,G,B).
    private static func sim(_ d: Deficiency) -> simd_float3x3 {
        switch d {
        case .protan: return rows([0.567, 0.433, 0.0], [0.558, 0.442, 0.0], [0.0, 0.242, 0.758])
        case .deutan: return rows([0.625, 0.375, 0.0], [0.700, 0.300, 0.0], [0.0, 0.300, 0.700])
        case .tritan: return rows([0.950, 0.050, 0.0], [0.0, 0.433, 0.567], [0.0, 0.475, 0.525])
        }
    }
    // Where to push the lost information (Fidaner et al.): red/green loss → into blue; blue loss → into red/green.
    private static func shift(_ d: Deficiency) -> simd_float3x3 {
        switch d {
        case .protan, .deutan: return rows([0.0, 0.0, 0.0], [0.7, 1.0, 0.0], [0.7, 0.0, 1.0])
        case .tritan:          return rows([1.0, 0.0, 0.7], [0.0, 1.0, 0.7], [0.0, 0.0, 0.0])
        }
    }
    private static func rows(_ r0: [Float], _ r1: [Float], _ r2: [Float]) -> simd_float3x3 {
        // simd stores columns; build from rows for readability
        simd_float3x3(rows: [SIMD3(r0), SIMD3(r1), SIMD3(r2)])
    }

    /// How a person with `d` (at `severity` 0…1) sees colour.
    static func simulationMatrix(_ d: Deficiency, severity: Float) -> simd_float3x3 {
        let s = max(0, min(1, severity))
        return matrix_identity_float3x3 * (1 - s) + sim(d) * s
    }

    /// Correction = I + strength · shift · (I − simulation). Identity when strength is 0.
    static func correctionMatrix(_ d: Deficiency, severity: Float, strength: Float) -> simd_float3x3 {
        let S = simulationMatrix(d, severity: severity)
        let k = max(0, min(1.5, strength))
        return matrix_identity_float3x3 + (shift(d) * (matrix_identity_float3x3 - S)) * k
    }

    /// Apply a 3×3 colour matrix as a Core Image filter (works in CI's linear working space).
    static func apply(_ m: simd_float3x3, to image: CIImage) -> CIImage {
        let f = CIFilter.colorMatrix()
        f.inputImage = image
        // CIColorMatrix vectors are per *output* channel: outR = dot(rVector, inRGBA)
        f.rVector = CIVector(x: CGFloat(m[0, 0]), y: CGFloat(m[1, 0]), z: CGFloat(m[2, 0]), w: 0)
        f.gVector = CIVector(x: CGFloat(m[0, 1]), y: CGFloat(m[1, 1]), z: CGFloat(m[2, 1]), w: 0)
        f.bVector = CIVector(x: CGFloat(m[0, 2]), y: CGFloat(m[1, 2]), z: CGFloat(m[2, 2]), w: 0)
        f.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        return f.outputImage ?? image
    }

    static func transform(_ v: SIMD3<Float>, by m: simd_float3x3) -> SIMD3<Float> { m * v }

    // MARK: highlight one hue

    enum Highlight: Int, CaseIterable {
        case red, orange, yellow, green, blue, purple
        var title: String { ["Red", "Orange", "Yellow", "Green", "Blue", "Purple"][rawValue] }
        var hue: Float { [0, 30, 55, 120, 220, 285][rawValue] }
        var width: Float { [22, 16, 18, 40, 40, 30][rawValue] }
        var color: UIColor { UIColor(hue: CGFloat(hue) / 360, saturation: 0.85, brightness: 0.9, alpha: 1) }
    }

    /// 32³ colour cube: pixels inside the hue band stay (slightly boosted), everything else goes grey.
    static func highlightCube(_ h: Highlight, size: Int = 32) -> Data {
        var data = [Float](repeating: 0, count: size * size * size * 4)
        var i = 0
        for b in 0..<size { for g in 0..<size { for r in 0..<size {
            let rf = Float(r) / Float(size - 1), gf = Float(g) / Float(size - 1), bf = Float(b) / Float(size - 1)
            let (hue, sat, val) = hsv(rf, gf, bf)
            var d = abs(hue - h.hue); if d > 180 { d = 360 - d }
            let inBand = d <= h.width && sat > 0.28 && val > 0.12
            if inBand {
                let boost: Float = 1.15
                data[i] = min(1, rf * boost); data[i + 1] = min(1, gf * boost); data[i + 2] = min(1, bf * boost)
            } else {
                let y = 0.2126 * rf + 0.7152 * gf + 0.0722 * bf
                data[i] = y; data[i + 1] = y; data[i + 2] = y
            }
            data[i + 3] = 1
            i += 4
        } } }
        return data.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    static func applyCube(_ cube: Data, size: Int = 32, to image: CIImage) -> CIImage {
        let f = CIFilter.colorCube()
        f.inputImage = image
        f.cubeDimension = Float(size)
        f.cubeData = cube
        return f.outputImage ?? image
    }

    static func hsv(_ r: Float, _ g: Float, _ b: Float) -> (Float, Float, Float) {
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        var h: Float = 0
        if d > 0 {
            if mx == r { h = 60 * ((g - b) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == g { h = 60 * ((b - r) / d + 2) }
            else { h = 60 * ((r - g) / d + 4) }
            if h < 0 { h += 360 }
        }
        return (h, mx == 0 ? 0 : d / mx, mx)
    }

    // MARK: naming

    private static let names: [(String, SIMD3<Float>)] = [
        ("Black", [0, 0, 0]), ("Dark grey", [0.25, 0.25, 0.25]), ("Grey", [0.5, 0.5, 0.5]), ("Light grey", [0.75, 0.75, 0.75]), ("White", [1, 1, 1]),
        ("Red", [0.9, 0.1, 0.1]), ("Dark red", [0.5, 0.05, 0.05]), ("Pink", [1, 0.6, 0.75]), ("Hot pink", [1, 0.3, 0.6]), ("Coral", [1, 0.5, 0.4]),
        ("Orange", [1, 0.55, 0.1]), ("Brown", [0.45, 0.28, 0.12]), ("Tan", [0.8, 0.65, 0.45]), ("Beige", [0.93, 0.87, 0.75]), ("Gold", [0.9, 0.75, 0.15]),
        ("Yellow", [1, 0.95, 0.15]), ("Lime", [0.7, 0.95, 0.2]), ("Green", [0.15, 0.65, 0.2]), ("Dark green", [0.05, 0.35, 0.1]), ("Olive", [0.45, 0.5, 0.15]),
        ("Mint", [0.6, 0.95, 0.75]), ("Teal", [0.1, 0.55, 0.55]), ("Cyan", [0.2, 0.9, 0.95]), ("Sky blue", [0.5, 0.75, 1]), ("Blue", [0.15, 0.35, 0.9]),
        ("Navy", [0.05, 0.1, 0.4]), ("Purple", [0.5, 0.2, 0.7]), ("Violet", [0.6, 0.4, 0.95]), ("Lavender", [0.8, 0.7, 0.95]), ("Magenta", [0.9, 0.15, 0.8]),
    ]

    /// Nearest everyday colour name (perceptual-ish: weighted RGB distance), plus the hex code.
    static func name(r: Float, g: Float, b: Float) -> (name: String, hex: String) {
        let p = SIMD3<Float>(r, g, b)
        var best = names[0], bestD = Float.greatestFiniteMagnitude
        for n in names {
            let d = n.1 - p
            let rm = (n.1.x + p.x) / 2
            let dist = (2 + rm) * d.x * d.x + 4 * d.y * d.y + (3 - rm) * d.z * d.z
            if dist < bestD { bestD = dist; best = n }
        }
        let hex = String(format: "#%02X%02X%02X", Int(max(0, min(1, r)) * 255), Int(max(0, min(1, g)) * 255), Int(max(0, min(1, b)) * 255))
        return (best.0, hex)
    }

    /// Average colour of a small region (normalized rect, top-left origin) of a CIImage, in sRGB 0…1.
    static func averageColor(of image: CIImage, region: CGRect, context: CIContext) -> SIMD3<Float>? {
        let e = image.extent
        let r = CGRect(x: e.minX + region.minX * e.width, y: e.minY + (1 - region.maxY) * e.height, width: region.width * e.width, height: region.height * e.height)
        let f = CIFilter.areaAverage(); f.inputImage = image; f.extent = r
        guard let out = f.outputImage else { return nil }
        var px = [UInt8](repeating: 0, count: 4)
        context.render(out, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return SIMD3(Float(px[0]) / 255, Float(px[1]) / 255, Float(px[2]) / 255)
    }
}
