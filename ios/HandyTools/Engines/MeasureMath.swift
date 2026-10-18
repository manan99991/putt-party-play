import Foundation
import simd

/// Geometry for the AR tape measure, kept pure for tests.
enum MeasureMath {
    static func distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float { simd_distance(a, b) }

    /// Total length of a polyline.
    static func pathLength(_ pts: [SIMD3<Float>]) -> Float {
        guard pts.count > 1 else { return 0 }
        return zip(pts.dropFirst(), pts).reduce(0) { $0 + simd_distance($1.0, $1.1) }
    }

    /// Area of a (roughly planar) 3-D polygon via Newell's method — robust to points not being perfectly coplanar.
    static func polygonArea(_ pts: [SIMD3<Float>]) -> Float {
        guard pts.count >= 3 else { return 0 }
        var n = SIMD3<Float>(repeating: 0)
        for i in 0..<pts.count {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            n.x += (a.y - b.y) * (a.z + b.z)
            n.y += (a.z - b.z) * (a.x + b.x)
            n.z += (a.x - b.x) * (a.y + b.y)
        }
        return simd_length(n) / 2
    }

    /// Height = vertical separation between two points (gravity-aligned world: y is up).
    static func height(from base: SIMD3<Float>, to top: SIMD3<Float>) -> Float { abs(top.y - base.y) }

    static func length(_ m: Float, metric: Bool) -> String {
        if metric { return m < 1 ? String(format: "%.1f cm", m * 100) : String(format: "%.2f m", m) }
        let inches = Double(m) * 39.3701
        if inches < 12 { return String(format: "%.1f in", inches) }
        let ft = Int(inches / 12), rem = inches - Double(ft) * 12
        return String(format: "%d′ %.1f″", ft, rem)
    }
    static func area(_ m2: Float, metric: Bool) -> String { metric ? String(format: "%.2f m²", m2) : String(format: "%.1f sq ft", Double(m2) * 10.7639) }
}
