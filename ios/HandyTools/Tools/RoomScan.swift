import SwiftUI
import RoomPlan
import simd

/// Whole room, on iPhones with LiDAR: walk round once with Apple's RoomPlan and get every wall, door and
/// window measured, a floor plan, the floor area, and paint and flooring worked out from the real walls
/// (with the real doors and windows taken off, not guesses).
struct RoomScanScreen: View {
    let done: (CapturedRoom?) -> Void
    @StateObject private var model = RoomScanModel()

    var body: some View {
        ZStack {
            RoomCaptureBox(model: model).ignoresSafeArea()
            VStack {
                HStack {
                    Button(L("Cancel")) { model.stop(); done(nil) }.buttonStyle(.borderedProminent).tint(.black.opacity(0.6))
                    Spacer()
                    if model.result != nil {
                        Button(L("Use this room")) { done(model.result) }.buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("room-use")
                    } else {
                        Button(model.finishing ? L("Drawing…") : L("Done scanning")) { model.finish() }
                            .buttonStyle(.borderedProminent).disabled(model.finishing)
                            .accessibilityIdentifier("room-done")
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8)
                Spacer()
                Text(L(model.result != nil ? "Here's your room. Tap Use this room for the sizes and floor plan."
                       : "Walk slowly round the room with the camera on the walls. Get the corners, doors and windows in view. Tap Done scanning when the outline is complete."))
                    .font(HandyFont.body).foregroundStyle(.white).multilineTextAlignment(.center)
                    .padding(12).background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(16)
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

final class RoomScanModel: NSObject, ObservableObject, RoomCaptureViewDelegate {
    @Published var result: CapturedRoom?
    @Published var finishing = false
    weak var view: RoomCaptureView?
    private var started = false

    override init() { super.init() }
    required init?(coder: NSCoder) { super.init() }
    func encode(with coder: NSCoder) {}

    func start() {
        guard let view, !started else { return }
        started = true
        view.captureSession.run(configuration: RoomCaptureSession.Configuration())
    }
    func finish() { finishing = true; view?.captureSession.stop() }
    func stop() { if started { view?.captureSession.stop(); started = false } }

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool { true }
    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        DispatchQueue.main.async { self.result = processedResult; self.finishing = false }
    }
}

private struct RoomCaptureBox: UIViewRepresentable {
    let model: RoomScanModel
    func makeUIView(context: Context) -> RoomCaptureView {
        let v = RoomCaptureView(frame: .zero)
        v.delegate = model
        model.view = v
        DispatchQueue.main.async { model.start() }
        return v
    }
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}

/// The measured room, ready to show, share and save.
struct RoomSummary {
    struct Piece { let start: SIMD2<Float>; let end: SIMD2<Float>; let width: Float; let height: Float }
    let walls: [Piece]
    let doors: [Piece]
    let windows: [Piece]
    let floorArea: Float
    let ceiling: Float

    init(_ room: CapturedRoom) {
        func piece(_ s: CapturedRoom.Surface) -> Piece {
            let t = s.transform
            let c = SIMD2<Float>(t.columns.3.x, t.columns.3.z)
            var d = SIMD2<Float>(t.columns.0.x, t.columns.0.z)
            d = simd_length(d) > 0 ? simd_normalize(d) : SIMD2<Float>(1, 0)
            let half = s.dimensions.x / 2
            return Piece(start: c - d * half, end: c + d * half, width: s.dimensions.x, height: s.dimensions.y)
        }
        let w = room.walls.map(piece)
        walls = w
        doors = room.doors.map(piece)
        windows = room.windows.map(piece) + room.openings.map(piece)
        ceiling = w.map(\.height).max() ?? 0
        if let f = room.floors.first, f.polygonCorners.count >= 3 {
            floorArea = MeasureMath.polygonArea(f.polygonCorners)
        } else {
            // No floor outline: the area inside the walls' ends.
            let pts = w.flatMap { [$0.start, $0.end] }
            let xs = pts.map(\.x), zs = pts.map(\.y)
            floorArea = ((xs.max() ?? 0) - (xs.min() ?? 0)) * ((zs.max() ?? 0) - (zs.min() ?? 0))
        }
    }

    var wallArea: Float { walls.reduce(0) { $0 + $1.width * $1.height } }
    /// Paintable wall: the real doors and windows taken off.
    var paintable: Float { max(0, wallArea - (doors + windows).reduce(0) { $0 + $1.width * $1.height }) }

    func text(metric: Bool) -> String {
        var lines = ["\(L("Floor area")): \(MeasureMath.area(floorArea, metric: metric))",
                     "\(L("Ceiling height")): \(MeasureMath.length(ceiling, metric: metric))",
                     "\(L("Walls to paint")): \(MeasureMath.area(paintable, metric: metric))"]
        for (i, w) in walls.enumerated() { lines.append("\(L("Wall")) \(i + 1): \(MeasureMath.length(w.width, metric: metric)) × \(MeasureMath.length(w.height, metric: metric))") }
        for (i, d) in doors.enumerated() { lines.append("\(L("Door")) \(i + 1): \(MeasureMath.length(d.width, metric: metric)) × \(MeasureMath.length(d.height, metric: metric))") }
        for (i, w) in windows.enumerated() { lines.append("\(L("Window")) \(i + 1): \(MeasureMath.length(w.width, metric: metric)) × \(MeasureMath.length(w.height, metric: metric))") }
        return lines.joined(separator: "\n")
    }

    /// A clean top-down floor plan with each wall's length written along it.
    func planImage(metric: Bool, size: CGFloat = 900) -> UIImage {
        let all = (walls + doors + windows).flatMap { [$0.start, $0.end] }
        let minX = all.map(\.x).min() ?? 0, maxX = all.map(\.x).max() ?? 1
        let minZ = all.map(\.y).min() ?? 0, maxZ = all.map(\.y).max() ?? 1
        let span = max(maxX - minX, maxZ - minZ, 0.5)
        let pad: CGFloat = 70
        let k = (size - pad * 2) / CGFloat(span)
        func pt(_ p: SIMD2<Float>) -> CGPoint { CGPoint(x: pad + CGFloat(p.x - minX) * k, y: pad + CGFloat(p.y - minZ) * k) }
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: fmt).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: size, height: size))
            let g = c.cgContext
            g.setLineCap(.round)
            func stroke(_ p: Piece, _ color: UIColor, _ w: CGFloat) {
                g.setStrokeColor(color.cgColor); g.setLineWidth(w)
                g.move(to: pt(p.start)); g.addLine(to: pt(p.end)); g.strokePath()
            }
            walls.forEach { stroke($0, UIColor(white: 0.15, alpha: 1), 10) }
            doors.forEach { stroke($0, UIColor.systemOrange, 12) }
            windows.forEach { stroke($0, UIColor.systemBlue, 12) }
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 22, weight: .semibold), .foregroundColor: UIColor(white: 0.2, alpha: 1)]
            for w in walls {
                let m = CGPoint(x: (pt(w.start).x + pt(w.end).x) / 2, y: (pt(w.start).y + pt(w.end).y) / 2)
                let s = MeasureMath.length(w.width, metric: metric) as NSString
                let sz = s.size(withAttributes: attrs)
                let r = CGRect(x: m.x - sz.width / 2 - 6, y: m.y - sz.height / 2 - 3, width: sz.width + 12, height: sz.height + 6)
                UIColor.white.withAlphaComponent(0.9).setFill(); UIBezierPath(roundedRect: r, cornerRadius: 6).fill()
                s.draw(at: CGPoint(x: r.minX + 6, y: r.minY + 3), withAttributes: attrs)
            }
            let area = "\(L("Floor")) \(MeasureMath.area(floorArea, metric: metric))" as NSString
            area.draw(at: CGPoint(x: pad, y: size - pad + 16), withAttributes: [.font: UIFont.systemFont(ofSize: 26, weight: .bold), .foregroundColor: UIColor.black])
        }
    }
}

/// The room as a card: the plan, then the numbers that matter for buying things.
struct RoomPlanCard: View {
    let room: RoomSummary
    let metric: Bool
    @State private var coats = 2

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Image(uiImage: room.planImage(metric: metric)).resizable().scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            HStack(spacing: 12) {
                Label(L("Walls"), systemImage: "line.diagonal").foregroundStyle(HandyColor.textPrimary)
                Label(L("Doors"), systemImage: "line.diagonal").foregroundStyle(.orange)
                Label(L("Windows"), systemImage: "line.diagonal").foregroundStyle(.blue)
            }.font(HandyFont.micro)
            row(L("Floor area"), MeasureMath.area(room.floorArea, metric: metric), strong: true)
            row(L("Ceiling height"), MeasureMath.length(room.ceiling, metric: metric))
            row(L("Walls, doors, windows"), "\(room.walls.count) · \(room.doors.count) · \(room.windows.count)")
            row(L("Walls to paint (doors and windows off)"), MeasureMath.area(room.paintable, metric: metric))
            Stepper("\(L("Coats of paint")) \(coats)", value: $coats, in: 1...3).font(HandyFont.caption)
            let litres = Double(room.paintable) * Double(coats) / RoomMath.coveragePerLitre
            row(L("Paint"), metric ? String(format: "%.1f L", litres) : String(format: "%.1f gal", litres / RoomMath.litresPerGallon))
            row(L("Flooring (with 10% for cuts)"), MeasureMath.area(room.floorArea * 1.1, metric: metric))
            DisclosureGroup(L("Every wall, door and window")) {
                Text(room.text(metric: metric)).font(HandyFont.caption).monospacedDigit().textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.font(HandyFont.caption)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private func row(_ k: String, _ v: String, strong: Bool = false) -> some View {
        HStack { Text(k).font(strong ? HandyFont.bodyStrong : HandyFont.caption).foregroundStyle(strong ? HandyColor.textPrimary : HandyColor.textSecondary); Spacer(); Text(v).font(HandyFont.bodyStrong).monospacedDigit() }
    }
}
