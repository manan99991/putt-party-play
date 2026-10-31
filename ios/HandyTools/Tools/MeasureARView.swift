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
    @State private var showSensors = false   // Level, compass and the other sensors, folded in here.
    @State private var capturing = false
    @State private var photo: MeasurePhoto?

    private struct MeasurePhoto: Identifiable { let id = UUID(); let url: URL; let image: UIImage }

    var body: some View {
        ToolPage(title: "Measure", subtitle: "Tap to place points on real surfaces — distance, perimeter and area, or height from the floor.") {
            HowTo("measure", [
                "Move the phone slowly so it can map the surface.",
                "Tap to drop a start point, move, then tap to drop the end.",
                "Read the distance; add more points for an area or a running total.",
            ])
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
                            if let big = bigReadout {
                                Text(big).font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                            }
                            Text(statusLine).font(HandyFont.caption).multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.bottom, HandySpacing.s12)
                    }.allowsHitTesting(false)
                }
                HandyFlow(spacing: HandySpacing.s8) {
                    ForEach(Mode.allCases, id: \.rawValue) { m in HChip(text: m.title, selected: mode == m) { mode = m; ar.reset() } }
                }
                Picker("Units", selection: $metric) { Text("ft/in").tag(false); Text("m/cm").tag(true) }.pickerStyle(.segmented).frame(width: 160)
                HStack(spacing: HandySpacing.s8) {
                    Button { ar.place() } label: { Label(primaryActionLabel, systemImage: "plus.circle.fill").frame(maxWidth: .infinity) }.primaryButton().disabled(!ar.hasSurface)
                    if mode == .area && ar.points.count >= 3 {
                        Button { ar.closeLoop() } label: { Image(systemName: "checkmark.circle.fill").frame(width: 36, height: 36) }.compactButton()
                    }
                    Button { ar.undo() } label: { Image(systemName: "arrow.uturn.backward").frame(width: 36, height: 36) }.compactButton().disabled(ar.points.isEmpty)
                    Button { ar.reset() } label: { Image(systemName: "trash").frame(width: 36, height: 36) }.compactButton().disabled(ar.points.isEmpty)
                }
                results
            } else {
                LimitNote("AR measuring needs a real iPhone with ARKit — it isn't available here.")
            }
            Button { showSensors = true } label: {
                Label("Level, compass & sensors", systemImage: "level").frame(maxWidth: .infinity)
            }.secondaryButton()
            Text(ar.lidar ? "LiDAR detected — expect ±1 cm on flat surfaces." : "Accuracy is typically ±1–2 cm up to a few metres; move the phone slowly first so it learns the room.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .onAppear { ar.start() }
        .onDisappear { ar.stop() }
        .sheet(isPresented: $showSensors) {
            NavigationStack {
                InstrumentsView()
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showSensors = false } } }
            }
        }
        .sheet(item: $photo) { p in
            NavigationStack {
                ScrollView {
                    Image(uiImage: p.image).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous)).padding(HandySpacing.s16)
                }
                .background(HandyColor.bg)
                .navigationTitle("Measurement photo").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { photo = nil } }
                    ToolbarItem(placement: .primaryAction) { ShareLink(item: p.url) { Image(systemName: "square.and.arrow.up") } }
                }
            }
        }
    }

    /// Capture the AR view with the measurement burned in — a shareable "will it fit?" photo.
    private func capturePhoto() {
        capturing = true
        Task {
            let base = await ar.snapshot()
            let composed = base.map { label($0, with: summary) }
            defer { capturing = false }
            guard let composed else { return }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Measurement-\(UUID().uuidString.prefix(4)).png")
            if let d = composed.pngData() { try? d.write(to: url) }
            photo = MeasurePhoto(url: url, image: composed)
        }
    }

    /// Draw the measurement summary onto a dark caption bar across the bottom of the snapshot.
    private func label(_ base: UIImage, with text: String) -> UIImage {
        let size = base.size
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = base.scale
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            base.draw(in: CGRect(origin: .zero, size: size))
            let pad: CGFloat = size.width * 0.04
            let font = UIFont.systemFont(ofSize: max(16, size.width * 0.045), weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
            let bound = (text as NSString).boundingRect(with: CGSize(width: size.width - pad * 2, height: .greatestFiniteMagnitude),
                                                        options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
            let barH = bound.height + pad * 1.6
            UIColor.black.withAlphaComponent(0.6).setFill()
            ctx.fill(CGRect(x: 0, y: size.height - barH, width: size.width, height: barH))
            (text as NSString).draw(with: CGRect(x: pad, y: size.height - barH + pad * 0.8, width: size.width - pad * 2, height: bound.height),
                                    options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
        }
    }

    private var statusLine: String {
        if !ar.hasSurface { return "Point at a surface and move the phone slowly…" }
        switch mode {
        case .distance:
            return ar.points.isEmpty ? "Tap to set the start, then move and tap again"
                                     : "Live distance from the last point · tap to add another"
        case .area:
            if ar.points.count < 3 { return "Tap each corner of the floor — \(3 - ar.points.count) more to start an area" }
            return "Running area shown above · add corners or tap Close to finish"
        case .height:
            return ar.points.isEmpty ? "Tap the floor at the base of what you're measuring"
                                     : "Now aim at the top — the height updates live"
        }
    }

    /// The big number, correct for the mode: live length (Distance), live/placed height (Height), or the
    /// running floor area once there are enough corners (Area) — never a stray linear number in Area.
    private var bigReadout: String? {
        switch mode {
        case .distance:
            guard let live = ar.liveDistance else { return nil }
            return MeasureMath.length(live, metric: metric)
        case .height:
            if ar.points.count >= 2 { return MeasureMath.length(MeasureMath.height(from: ar.points[0], to: ar.points[1]), metric: metric) }
            guard let h = ar.liveHeight else { return nil }
            return MeasureMath.length(h, metric: metric)
        case .area:
            guard ar.points.count >= 3 else { return nil }
            return MeasureMath.area(MeasureMath.polygonArea(ar.points), metric: metric)
        }
    }

    private var primaryActionLabel: String {
        switch mode {
        case .distance: return ar.points.isEmpty ? "Set start point" : "Add point"
        case .area:     return ar.points.isEmpty ? "Tap first corner" : "Add corner"
        case .height:   return ar.points.isEmpty ? "Tap the base" : "Set the top"
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
                    Button { capturePhoto() } label: { Label(capturing ? "…" : "Photo", systemImage: "camera") }.compactButton().disabled(capturing)
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

    /// Draw the closing edge of an area (last corner back to the first) so the shape reads as finished.
    func closeLoop() {
        guard points.count >= 3 else { return }
        addLine(points[points.count - 1], points[0])
        HandyHaptics.success()
    }

    /// A still of the live AR view (with the drawn points and lines) to caption and share.
    func snapshot() async -> UIImage? {
        guard let v = view else { return nil }
        return await withCheckedContinuation { cont in
            v.snapshot(saveToHDR: false) { img in cont.resume(returning: img) }
        }
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
