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

    // MARK: walls, windows and doors: two opposite corners

    /// A wall, window or door from two opposite corners: width along the floor, height straight up.
    static func rectangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> (width: Float, height: Float, area: Float) {
        let w = simd_length(SIMD2<Float>(b.x - a.x, b.z - a.z)), h = abs(b.y - a.y)
        return (w, h, w * h)
    }

    /// The four corners of that rectangle, for drawing it: a, along the floor, b, and back up/down.
    static func rectangleCorners(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> [SIMD3<Float>] {
        [a, SIMD3<Float>(b.x, a.y, b.z), b, SIMD3<Float>(a.x, b.y, a.z)]
    }

    // MARK: floors and tables: corners in order

    /// The plane the corners sit on, and how far the worst corner is off it (metres).
    static func plane(_ pts: [SIMD3<Float>]) -> (normal: SIMD3<Float>, centre: SIMD3<Float>, offBy: Float) {
        let c = pts.reduce(SIMD3<Float>(repeating: 0), +) / Float(max(1, pts.count))
        var n = SIMD3<Float>(repeating: 0)
        for i in 0..<pts.count {
            let a = pts[i] - c, b = pts[(i + 1) % pts.count] - c
            n += simd_cross(a, b)
        }
        if simd_length(n) < 1e-6 { n = SIMD3<Float>(0, 1, 0) }
        n = simd_normalize(n)
        let off = pts.map { abs(simd_dot($0 - c, n)) }.max() ?? 0
        return (n, c, off)
    }

    /// Corners on the plane, as flat 2-D points.
    static func flatten(_ pts: [SIMD3<Float>], normal n: SIMD3<Float>, centre c: SIMD3<Float>) -> [SIMD2<Float>] {
        let helper: SIMD3<Float> = abs(n.y) < 0.9 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
        let u = simd_normalize(simd_cross(helper, n)), v = simd_cross(n, u)
        return pts.map { SIMD2<Float>(simd_dot($0 - c, u), simd_dot($0 - c, v)) }
    }

    /// True when two edges of the shape cross (corners tapped out of order make a bow-tie).
    static func crosses(_ q: [SIMD2<Float>]) -> Bool {
        let n = q.count
        guard n >= 4 else { return false }
        func ccw(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Float { (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) }
        for i in 0..<n {
            let a = q[i], b = q[(i + 1) % n]
            for j in (i + 2)..<(i + n - 1) {
                let c = q[j % n], d = q[(j + 1) % n]
                if ccw(a, b, c) * ccw(a, b, d) < 0 && ccw(c, d, a) * ccw(c, d, b) < 0 { return true }
            }
        }
        return false
    }

    /// The area of a floor or table from its corners, put back in order round the middle if they were tapped
    /// out of order, plus whether the corners really lie on one flat surface (within 4 cm, or 2% of a side on big rooms).
    static func surface(_ pts: [SIMD3<Float>]) -> (area: Float, perimeter: Float, points: [SIMD3<Float>], reordered: Bool, flat: Bool) {
        guard pts.count >= 3 else { return (0, pathLength(pts), pts, false, true) }
        let pl = plane(pts)
        let q = flatten(pts, normal: pl.normal, centre: pl.centre)
        var ordered = pts, reordered = false
        if crosses(q) {
            let idx = q.indices.sorted { atan2(q[$0].y, q[$0].x) < atan2(q[$1].y, q[$1].x) }
            ordered = idx.map { pts[$0] }; reordered = true
        }
        let size = pathLength(ordered + [ordered[0]]) / Float(ordered.count)
        let flat = pl.offBy <= max(0.04, size * 0.02)
        return (polygonArea(ordered), pathLength(ordered + [ordered[0]]), ordered, reordered, flat)
    }

    /// "Will it fit?": the room left (positive) or how much too big (negative), in metres.
    static func spare(space: Float, item: Float) -> Float { space - item }
}
