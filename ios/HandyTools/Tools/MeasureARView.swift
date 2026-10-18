import SwiftUI
import ARKit
import RealityKit
import simd

/// Measure — an AR tape: tap to drop points on real surfaces, read distance as you go, chain points
/// for perimeter, close the loop for area, or measure height from the floor. Uses LiDAR when the
/// phone has it. Results you can copy into a message.
struct MeasureARView: View {
    @StateObject private var ar = ARMeasure()
    @AppStorage("measure.metric") private var metric = !(Locale.current.measurementSystem == .us)
    private enum Mode: Int, CaseIterable { case distance, area, height
        var title: String { ["Distance", "Area", "Height"][rawValue] } }
    @State private var mode: Mode = .distance

    var body: some View {
        ToolPage(title: "Measure", subtitle: "Tap to place points on real surfaces — distance, perimeter and area, or height from the floor.") {
            if ARWorldTrackingConfiguration.isSupported {
                ZStack {
                    ARContainer(ar: ar)
                        .frame(height: 440)
                        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                        .onTapGesture { ar.place() }
                    // reticle + live readout
                    VStack {
                        Spacer()
                        ZStack {
                            Circle().stroke(.white, lineWidth: 2).frame(width: 22, height: 22).shadow(radius: 2)
                            Circle().fill(ar.hasSurface ? HandyColor.success : HandyColor.danger).frame(width: 6, height: 6)
                        }
                        Spacer()
                        VStack(spacing: 4) {
                            if let live = ar.liveDistance, mode != .height || ar.points.count == 1 {
                                Text(MeasureMath.length(mode == .height ? ar.liveHeight ?? 0 : live, metric: metric)).font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                            }
                            Text(statusLine).font(HandyFont.caption)
                        }
                        .foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.bottom, HandySpacing.s12)
                    }.allowsHitTesting(false)
                }
                HStack(spacing: HandySpacing.s8) {
                    ForEach(Mode.allCases, id: \.rawValue) { m in HChip(text: m.title, selected: mode == m) { mode = m; ar.reset() } }
                    Spacer()
                }
                Picker("Units", selection: $metric) { Text("ft/in").tag(false); Text("m/cm").tag(true) }.pickerStyle(.segmented).frame(width: 160)
                HStack(spacing: HandySpacing.s8) {
                    Button { ar.place() } label: { Label("Add point", systemImage: "plus.circle.fill").frame(maxWidth: .infinity) }.primaryButton().disabled(!ar.hasSurface)
                    Button { ar.undo() } label: { Image(systemName: "arrow.uturn.backward").frame(width: 36, height: 36) }.compactButton().disabled(ar.points.isEmpty)
                    Button { ar.reset() } label: { Image(systemName: "trash").frame(width: 36, height: 36) }.compactButton().disabled(ar.points.isEmpty)
                }
                results
            } else {
                LimitNote("AR measuring needs a real iPhone with ARKit — it isn't available here.")
            }
            Text(ar.lidar ? "LiDAR detected — expect ±1 cm on flat surfaces." : "Accuracy is typically ±1–2 cm up to a few metres; move the phone slowly first so it learns the room.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .onAppear { ar.start() }
        .onDisappear { ar.stop() }
    }

    private var statusLine: String {
        if !ar.hasSurface { return "Point at a surface and move slowly…" }
        switch mode {
        case .distance: return ar.points.isEmpty ? "Tap to set the first point" : "\(ar.points.count) point\(ar.points.count == 1 ? "" : "s") · tap for the next"
        case .area: return ar.points.count < 3 ? "Walk the corners — \(ar.points.count)/3 minimum" : "Area: \(MeasureMath.area(MeasureMath.polygonArea(ar.points), metric: metric)) · add corners or finish"
        case .height: return ar.points.isEmpty ? "Tap the floor at the base" : "Now aim at the top — the height updates live"
        }
    }

    @ViewBuilder private var results: some View {
        if ar.points.count >= 2 || (mode == .height && ar.points.count == 1 && ar.liveHeight != nil) {
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                switch mode {
                case .distance:
                    ForEach(Array(zip(ar.points.dropFirst(), ar.points).enumerated()), id: \.offset) { i, pair in
                        HStack { Text("Segment \(i + 1)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary); Spacer(); Text(MeasureMath.length(MeasureMath.distance(pair.0, pair.1), metric: metric)).font(HandyFont.bodyStrong).monospacedDigit() }
                    }
                    if ar.points.count > 2 { HStack { Text("Total").font(HandyFont.bodyStrong); Spacer(); Text(MeasureMath.length(MeasureMath.pathLength(ar.points), metric: metric)).font(HandyFont.bodyStrong).monospacedDigit() } }
                case .area:
                    HStack { Text("Perimeter").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary); Spacer(); Text(MeasureMath.length(MeasureMath.pathLength(ar.points + [ar.points[0]]), metric: metric)).monospacedDigit() }
                    if ar.points.count >= 3 { HStack { Text("Area").font(HandyFont.bodyStrong); Spacer(); Text(MeasureMath.area(MeasureMath.polygonArea(ar.points), metric: metric)).font(HandyFont.bodyStrong).monospacedDigit() } }
                case .height:
                    HStack { Text("Height").font(HandyFont.bodyStrong); Spacer(); Text(MeasureMath.length(ar.points.count >= 2 ? MeasureMath.height(from: ar.points[0], to: ar.points[1]) : (ar.liveHeight ?? 0), metric: metric)).font(HandyFont.bodyStrong).monospacedDigit() }
                }
                HStack {
                    Button { UIPasteboard.general.string = summary; HandyHaptics.success() } label: { Label("Copy", systemImage: "doc.on.doc") }.compactButton()
                    ShareLink(item: summary) { Label("Share", systemImage: "square.and.arrow.up") }.compactButton()
                    Spacer()
                }
            }.cardStyle(padding: HandySpacing.s12)
        }
    }

    private var summary: String {
        switch mode {
        case .distance: return "Measured: " + zip(ar.points.dropFirst(), ar.points).map { MeasureMath.length(MeasureMath.distance($0.0, $0.1), metric: metric) }.joined(separator: " + ") + (ar.points.count > 2 ? " = \(MeasureMath.length(MeasureMath.pathLength(ar.points), metric: metric))" : "")
        case .area: return "Area \(MeasureMath.area(MeasureMath.polygonArea(ar.points), metric: metric)), perimeter \(MeasureMath.length(MeasureMath.pathLength(ar.points + [ar.points[0]]), metric: metric))"
        case .height: return "Height \(MeasureMath.length(ar.points.count >= 2 ? MeasureMath.height(from: ar.points[0], to: ar.points[1]) : (ar.liveHeight ?? 0), metric: metric))"
        }
    }
}

// MARK: - AR session

@MainActor final class ARMeasure: NSObject, ObservableObject, ARSessionDelegate {
    @Published var points: [SIMD3<Float>] = []
    @Published var liveDistance: Float?
    @Published var liveHeight: Float?
    @Published var hasSurface = false
    @Published var lidar = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    weak var view: ARView?
    private var anchors: [AnchorEntity] = []
    private var lines: [AnchorEntity] = []
    private var cursor: SIMD3<Float>?

    func start() {
        guard let v = view, ARWorldTrackingConfiguration.isSupported else { return }
        let cfg = ARWorldTrackingConfiguration()
        cfg.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) { cfg.sceneReconstruction = .mesh }
        cfg.environmentTexturing = .none
        v.session.delegate = self
        v.session.run(cfg, options: [.resetTracking, .removeExistingAnchors])
    }
    func stop() { view?.session.pause() }

    /// Called every frame from the delegate: raycast the screen centre to keep the cursor live.
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in self.updateCursor() }
    }

    private func updateCursor() {
        guard let v = view else { return }
        let center = CGPoint(x: v.bounds.midX, y: v.bounds.midY)
        let hit = v.raycast(from: center, allowing: .estimatedPlane, alignment: .any).first
        cursor = hit.map { SIMD3<Float>($0.worldTransform.columns.3.x, $0.worldTransform.columns.3.y, $0.worldTransform.columns.3.z) }
        hasSurface = cursor != nil
        if let c = cursor, let last = points.last {
            liveDistance = simd_distance(c, last)
            liveHeight = MeasureMath.height(from: points[0], to: c)
        } else { liveDistance = nil; liveHeight = nil }
    }

    func place() {
        guard let c = cursor, let v = view else { return }
        points.append(c)
        let a = AnchorEntity(world: c)
        let dot = ModelEntity(mesh: .generateSphere(radius: 0.006), materials: [UnlitMaterial(color: .systemOrange)])
        a.addChild(dot); v.scene.addAnchor(a); anchors.append(a)
        if points.count >= 2 { addLine(points[points.count - 2], c) }
        HandyHaptics.light()
    }

    private func addLine(_ a: SIMD3<Float>, _ b: SIMD3<Float>) {
        guard let v = view else { return }
        let len = simd_distance(a, b)
        let mid = (a + b) / 2
        let anchor = AnchorEntity(world: mid)
        let bar = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.003, 0.003, len)), materials: [UnlitMaterial(color: .white)])
        bar.look(at: b, from: mid, relativeTo: nil)
        anchor.addChild(bar)
        v.scene.addAnchor(anchor); lines.append(anchor)
    }

    func undo() {
        guard !points.isEmpty else { return }
        points.removeLast()
        if let a = anchors.popLast() { view?.scene.removeAnchor(a) }
        if let l = lines.popLast() { view?.scene.removeAnchor(l) }
    }
    func reset() {
        points = []
        anchors.forEach { view?.scene.removeAnchor($0) }; lines.forEach { view?.scene.removeAnchor($0) }
        anchors = []; lines = []
    }
}

private struct ARContainer: UIViewRepresentable {
    let ar: ARMeasure
    func makeUIView(context: Context) -> ARView {
        let v = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        v.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableHDR]
        ar.view = v
        ar.start()
        return v
    }
    func updateUIView(_ uiView: ARView, context: Context) {}
}
