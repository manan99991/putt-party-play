import SwiftUI
import ARKit
import RealityKit
import RoomPlan
import simd

/// Measure — starts from the job, not the tape:
///  • Length (a sofa, a gap), Wall or window (two opposite corners → width × height), Floor or table (corners in
///    order, closes itself when you come back to the first), Height (floor, then the top), and Whole room
///    (on iPhones with LiDAR: walk round once and get a floor plan with every wall, door and window).
///  • One step at a time, said on screen ("Step 1 of 2 — put the circle on a corner and tap"); tap where you
///    want the point, or aim the circle and tap the button.
///  • Big markers with the length written on every line, in the scene.
///  • Areas worked out on the real surface (wall, floor or table), with checks: corners out of order are put
///    back in order; corners that aren't on one flat surface are flagged.
///  • Will it fit? and what to buy (paint, flooring, tiles); a photo with the numbers on; saved rooms.
struct MeasureARView: View {
    @StateObject private var ar = ARMeasure()
    @AppStorage("measure.metric") private var metric = !(Locale.current.measurementSystem == .us)

    enum Job: Int, CaseIterable, Identifiable {
        case length, wall, floor, height, room
        var id: Int { rawValue }
        var title: String { ["Length", "Wall or window", "Floor or table", "Height", "Whole room"][rawValue] }
        var icon: String { ["ruler", "rectangle.portrait", "square.dashed", "arrow.up.and.down", "cube.transparent"][rawValue] }
        var line: String { ["A sofa, a table, a gap", "Paint, wallpaper, blinds", "Flooring, a rug, tiles", "A TV, a shelf, the ceiling", "A floor plan in one walk"][rawValue] }
    }
    @State private var job: Job?
    @State private var showSensors = false
    @State private var capturing = false
    @State private var photo: MeasurePhoto?
    @State private var scanning = false
    @State private var room: RoomSummary?

    private struct MeasurePhoto: Identifiable { let id = UUID(); let url: URL; let image: UIImage }
    @State private var saved: [RoomMath.Saved] = RoomMath.load()
    @State private var naming = false
    @State private var saveName = ""
    @State private var ceiling: Double = 0          // in the units shown; 0 = use the usual height
    @State private var doors = 1
    @State private var windows = 1
    @State private var coats = 2
    @State private var tileSide = 0.30              // metres
    @State private var viewing: RoomMath.Saved?
    @State private var itemW = ""
    @State private var itemH = ""

    private var roomSupported: Bool { RoomCaptureSession.isSupported }

    var body: some View {
        ToolPage(title: "Measure", subtitle: "Pick what you're measuring. Tenzy walks you through it, writes the size on every line, and works out what to buy.") {
            if !ARWorldTrackingConfiguration.isSupported {
                LimitNote("AR measuring needs a real iPhone with ARKit — it isn't available here.")
            } else if let job {
                if job == .room { roomPanel } else { measuring(job) }
            } else {
                chooser
            }
            savedSection
            Button { showSensors = true } label: {
                Label(L("Level, compass & sensors"), systemImage: "level").frame(maxWidth: .infinity)
            }.secondaryButton()
        }
        .onDisappear { ar.stop() }
        .sheet(isPresented: $showSensors) {
            NavigationStack {
                InstrumentsView()
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { showSensors = false } } }
            }
        }
        .fullScreenCover(isPresented: $scanning) {
            RoomScanScreen { r in scanning = false; if let r { room = RoomSummary(r) } }.ignoresSafeArea()
        }
        .alert(L("Name this measurement"), isPresented: $naming) {
            TextField(L("e.g. Sofa wall, bedroom window"), text: $saveName)
            Button(L("Save")) { saveNow() }
            Button(L("Cancel"), role: .cancel) {}
        }
        .sheet(item: $viewing) { m in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: HandySpacing.s12) {
                        if let img = RoomMath.image(m) { Image(uiImage: img).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous)) }
                        Text(m.value).font(HandyFont.bodyStrong).textSelection(.enabled)
                        Text(m.date.formatted(date: .abbreviated, time: .shortened)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }.padding(HandySpacing.gutter)
                }
                .background(HandyColor.bg)
                .navigationTitle(m.name).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { viewing = nil } }
                    ToolbarItem(placement: .primaryAction) { ShareLink(item: "\(m.name): \(m.value)") { Image(systemName: "square.and.arrow.up") } }
                }
            }
        }
        .sheet(item: $photo) { p in
            NavigationStack {
                ScrollView {
                    Image(uiImage: p.image).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous)).padding(HandySpacing.s16)
                }
                .background(HandyColor.bg)
                .navigationTitle(L("Measurement photo")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { photo = nil } }
                    ToolbarItem(placement: .primaryAction) { ShareLink(item: p.url) { Image(systemName: "square.and.arrow.up") } }
                }
            }
        }
    }

    // MARK: 1 · what are you measuring?

    private var chooser: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Text(L("What are you measuring?")).font(HandyFont.cardTitle)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: HandySpacing.s12), GridItem(.flexible(), spacing: HandySpacing.s12)], spacing: HandySpacing.s12) {
                ForEach(Job.allCases.filter { $0 != .room || roomSupported }) { j in
                    Button { start(j) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: j.icon).font(.system(size: 26, weight: .semibold)).foregroundStyle(HandyColor.accent)
                            Text(L(j.title)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                            Text(L(j.line)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                        .multilineTextAlignment(.leading)
                        .cardStyle(padding: HandySpacing.s12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("measure-job-\(j.rawValue)")
                }
            }
            if !roomSupported {
                Text(L("Whole-room floor plans need an iPhone with LiDAR (the Pro models)."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
        }
    }

    private func start(_ j: Job) {
        job = j; itemW = ""; itemH = ""
        if j == .room { scanning = true; return }
        ar.job = j; ar.reset(); ar.start()
    }

    // MARK: 2 · measuring, one step at a time

    private func measuring(_ j: Job) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack {
                Label(L(j.title), systemImage: j.icon).font(HandyFont.bodyStrong)
                Spacer()
                Button { ar.stop(); job = nil } label: { Label(L("Change"), systemImage: "chevron.left") }.textButton()
            }
            ZStack {
                ARContainer(ar: ar)
                    .frame(height: 460)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .onTapGesture(coordinateSpace: .local) { p in ar.place(at: p) }
                VStack(spacing: 0) {
                    stepBanner(j)
                    Spacer()
                    ZStack {
                        Circle().stroke(.white, lineWidth: 3).frame(width: 30, height: 30).shadow(radius: 2)
                        Circle().fill(ar.hasSurface ? HandyColor.success : HandyColor.danger).frame(width: 8, height: 8)
                    }
                    Spacer()
                    if let big = bigReadout(j) {
                        Text(big).font(.system(size: 36, weight: .bold, design: .rounded)).monospacedDigit()
                            .foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 6)
                            .background(.black.opacity(0.55), in: Capsule())
                            .padding(.bottom, HandySpacing.s12)
                    }
                }
                .allowsHitTesting(false)
            }
            HStack(spacing: HandySpacing.s8) {
                Button { ar.place(at: nil) } label: { Label(L(placeLabel(j)), systemImage: "plus.circle.fill").frame(maxWidth: .infinity) }
                    .primaryButton().disabled(!ar.hasSurface || ar.done)
                    .accessibilityIdentifier("measure-place")
                if j == .floor && ar.points.count >= 3 && !ar.closed {
                    Button { ar.close() } label: { Label(L("Finish"), systemImage: "checkmark.circle.fill") }.compactButton()
                }
                Button { ar.undo() } label: { Image(systemName: "arrow.uturn.backward").accessibilityLabel(L("Undo")).frame(width: 36, height: 36) }
                    .compactButton().disabled(ar.points.isEmpty)
                Button { ar.reset() } label: { Image(systemName: "arrow.counterclockwise").accessibilityLabel(L("Start over")).frame(width: 36, height: 36) }
                    .compactButton().disabled(ar.points.isEmpty)
            }
            Picker(L("Units"), selection: $metric) { Text(L("ft/in")).tag(false); Text(L("m/cm")).tag(true) }
                .pickerStyle(.segmented).frame(width: 180)
                .onChange(of: metric) { _, m in ar.metric = m; ar.redraw() }
                .onAppear { ar.metric = metric }
            results(j)
            if j == .floor, ar.closed, ar.points.count >= 3 { buyCard }
            Text(ar.lidar ? L("LiDAR on this iPhone: expect about ±1 cm on flat surfaces.") : L("Expect about ±1–2 cm up to a few metres. Move slowly first so Tenzy can see the room."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private func stepBanner(_ j: Job) -> some View {
        let s = step(j)
        return VStack(alignment: .leading, spacing: 2) {
            if let n = s.count { Text(n).font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.8)) }
            Text(L(s.text)).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
            if let w = ar.warning { Label(L(w), systemImage: "exclamationmark.triangle.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(.yellow) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(10)
        .accessibilityElement(children: .combine)
    }

    /// What to do now, in plain words, and which step it is.
    private func step(_ j: Job) -> (count: String?, text: String) {
        let n = ar.points.count
        if !ar.hasSurface && n == 0 { return (nil, "Move the phone slowly, pointing at the floor or the wall, until the dot turns green.") }
        switch j {
        case .length:
            if n == 0 { return ("STEP 1 OF 2", "Put the circle on one end and tap.") }
            if n == 1 { return ("STEP 2 OF 2", "Move to the other end — the length updates live — and tap.") }
            return ("DONE", "Measured. Tap again to add another length, or check it below.")
        case .wall:
            if n == 0 { return ("STEP 1 OF 2", "Tap the bottom-left corner of the wall, window or door.") }
            if n == 1 { return ("STEP 2 OF 2", "Now tap the opposite corner, top-right.") }
            return ("DONE", "Width, height and area are below. Start over to measure another.")
        case .floor:
            if ar.closed { return ("DONE", "Area and what to buy are below.") }
            if n == 0 { return ("CORNER 1", "Tap the first corner of the floor or table.") }
            if n < 3 { return ("CORNER \(n + 1)", "Go round the edge and tap the next corner.") }
            return ("CORNER \(n + 1)", "Tap the next corner, or tap the first corner again (or Finish) to close the shape.")
        case .height:
            if n == 0 { return ("STEP 1 OF 2", "Tap the floor right below what you're measuring.") }
            if n == 1 { return ("STEP 2 OF 2", "Aim at the top — the height updates live — and tap.") }
            return ("DONE", "Height is below.")
        case .room: return (nil, "")
        }
    }

    private func placeLabel(_ j: Job) -> String {
        switch j {
        case .length: return ar.points.isEmpty ? "Set this end" : "Set the other end"
        case .wall: return ar.points.isEmpty ? "Set first corner" : "Set opposite corner"
        case .floor: return "Add corner"
        case .height: return ar.points.isEmpty ? "Set the floor" : "Set the top"
        case .room: return ""
        }
    }

    private func bigReadout(_ j: Job) -> String? {
        let n = ar.points.count
        switch j {
        case .length:
            if let live = ar.liveDistance, !ar.done || n == 1 { return MeasureMath.length(live, metric: metric) }
            return n >= 2 ? MeasureMath.length(MeasureMath.pathLength(ar.points), metric: metric) : nil
        case .wall:
            if n >= 2 { let r = MeasureMath.rectangle(ar.points[0], ar.points[1]); return "\(MeasureMath.length(r.width, metric: metric)) × \(MeasureMath.length(r.height, metric: metric))" }
            if n == 1, let c = ar.cursor { let r = MeasureMath.rectangle(ar.points[0], c); return "\(MeasureMath.length(r.width, metric: metric)) × \(MeasureMath.length(r.height, metric: metric))" }
            return nil
        case .floor:
            guard n >= 3 else { return ar.liveDistance.map { MeasureMath.length($0, metric: metric) } }
            return MeasureMath.area(MeasureMath.surface(ar.points).area, metric: metric)
        case .height:
            if n >= 2 { return MeasureMath.length(MeasureMath.height(from: ar.points[0], to: ar.points[1]), metric: metric) }
            return ar.liveHeight.map { MeasureMath.length($0, metric: metric) }
        case .room: return nil
        }
    }

    // MARK: 3 · the result

    @ViewBuilder private func results(_ j: Job) -> some View {
        let n = ar.points.count
        let ready = (j == .length && n >= 2) || (j == .wall && n >= 2) || (j == .height && n >= 2) || (j == .floor && n >= 3)
        if ready {
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                switch j {
                case .length:
                    ForEach(Array(zip(ar.points.dropFirst(), ar.points).enumerated()), id: \.offset) { i, pair in
                        row("\(L("Length")) \(i + 1)", MeasureMath.length(MeasureMath.distance(pair.0, pair.1), metric: metric))
                    }
                    if n > 2 { row(L("Total"), MeasureMath.length(MeasureMath.pathLength(ar.points), metric: metric), strong: true) }
                    fit(space: MeasureMath.distance(ar.points[0], ar.points[1]), spaceH: nil)
                case .wall:
                    let r = MeasureMath.rectangle(ar.points[0], ar.points[1])
                    row(L("Width"), MeasureMath.length(r.width, metric: metric))
                    row(L("Height"), MeasureMath.length(r.height, metric: metric))
                    row(L("Area"), MeasureMath.area(r.area, metric: metric), strong: true)
                    if r.height < 0.15 { note(L("The two corners are almost level — tap a bottom corner, then the top corner opposite it.")) }
                    row("\(L("Paint for this wall")) (\(coats) \(L("coats")))", paintFor(r.area))
                    fit(space: r.width, spaceH: r.height)
                case .height:
                    row(L("Height"), MeasureMath.length(MeasureMath.height(from: ar.points[0], to: ar.points[1]), metric: metric), strong: true)
                case .floor:
                    let s = MeasureMath.surface(ar.points)
                    row(L("Area"), MeasureMath.area(s.area, metric: metric), strong: true)
                    row(L("Edge all round"), MeasureMath.length(s.perimeter, metric: metric))
                    if s.reordered { note(L("The corners were tapped out of order, so Tenzy put them back in order round the edge.")) }
                    if !s.flat { warn(L("These corners aren't on one flat surface (some may be on the wall or furniture). Start over and tap only floor corners.")) }
                    if !ar.closed { note(L("Tap Finish (or the first corner again) when you've tapped every corner.")) }
                case .room: EmptyView()
                }
                HStack {
                    Button { Copier.copy(summary(j)) } label: { Label(L("Copy"), systemImage: "doc.on.doc") }.compactButton()
                    Button { capturePhoto(j) } label: { Label(capturing ? "…" : L("Photo"), systemImage: "camera") }.compactButton().disabled(capturing)
                    ShareLink(item: summary(j)) { Label(L("Share"), systemImage: "square.and.arrow.up") }.compactButton()
                    Button { saveName = ""; naming = true } label: { Label(L("Save"), systemImage: "bookmark") }.compactButton()
                        .accessibilityIdentifier("measure-save")
                    Spacer()
                }
            }.cardStyle(padding: HandySpacing.s12)
        }
    }

    private func row(_ k: String, _ v: String, strong: Bool = false) -> some View {
        HStack { Text(k).font(strong ? HandyFont.bodyStrong : HandyFont.caption).foregroundStyle(strong ? HandyColor.textPrimary : HandyColor.textSecondary); Spacer(); Text(v).font(HandyFont.bodyStrong).monospacedDigit() }
    }
    private func note(_ t: String) -> some View {
        Label(t, systemImage: "info.circle").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
    }
    private func warn(_ t: String) -> some View {
        Label(t, systemImage: "exclamationmark.triangle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.amber).fixedSize(horizontal: false, vertical: true)
    }

    private func paintFor(_ m2: Float) -> String {
        let litres = Double(m2) * Double(coats) / RoomMath.coveragePerLitre
        return metric ? String(format: "%.1f L", litres) : String(format: "%.2f gal", litres / RoomMath.litresPerGallon)
    }

    /// Will it fit? The thing's size in the units shown; the answer with the room to spare.
    private func fit(space: Float, spaceH: Float?) -> some View {
        let unit: Float = metric ? 0.01 : 0.0254
        let w = Float(itemW.replacingOccurrences(of: ",", with: ".")).map { $0 * unit }
        let h = Float(itemH.replacingOccurrences(of: ",", with: ".")).map { $0 * unit }
        return VStack(alignment: .leading, spacing: 6) {
            Text(L("Will it fit?")).font(HandyFont.bodyStrong)
            HStack {
                TextField(metric ? L("Its width, cm") : L("Its width, inches"), text: $itemW).keyboardType(.decimalPad).textFieldStyle(.handy)
                if spaceH != nil { TextField(metric ? L("Its height, cm") : L("Its height, inches"), text: $itemH).keyboardType(.decimalPad).textFieldStyle(.handy) }
            }
            if let w {
                let worst = Self.worstGap(space: space, spaceH: spaceH, w: w, h: h)
                Label(worst >= 0 ? "\(L("Fits, with")) \(MeasureMath.length(worst, metric: metric)) \(L("to spare"))" : "\(L("Too big by")) \(MeasureMath.length(-worst, metric: metric))",
                      systemImage: worst >= 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(HandyFont.bodyStrong).foregroundStyle(worst >= 0.02 ? HandyColor.success : (worst >= 0 ? HandyColor.amber : HandyColor.danger))
                if worst >= 0 && worst < 0.02 { Text(L("Only just — allow for skirting boards and handles.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            }
        }
        .padding(.top, 4)
    }

    /// The tightest side: room to spare (positive) or how much too big (negative).
    static func worstGap(space: Float, spaceH: Float?, w: Float, h: Float?) -> Float {
        var gap = MeasureMath.spare(space: space, item: w)
        if let spaceH, let h { gap = min(gap, MeasureMath.spare(space: spaceH, item: h)) }
        return gap
    }

    // MARK: what to buy (floors)

    private var ceilingMetres: Double { ceiling <= 0 ? 2.4 : (metric ? ceiling : ceiling * 0.3048) }

    private var needs: RoomMath.Needs {
        let s = MeasureMath.surface(ar.points)
        return RoomMath.needs(floorArea: Double(s.area), perimeter: Double(s.perimeter),
                              ceiling: ceilingMetres, doors: doors, windows: windows, coats: coats, tileSide: tileSide, metric: metric)
    }

    private func areaText(_ m2: Double) -> String { MeasureMath.area(Float(m2), metric: metric) }

    private var buyCard: some View {
        let n = needs
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("What to buy for this room"), systemImage: "cart").font(HandyFont.bodyStrong)
            Stepper(value: Binding(get: { ceiling <= 0 ? (metric ? 2.4 : 8) : ceiling }, set: { ceiling = $0 }),
                    in: metric ? 1.8...6 : 6...20, step: metric ? 0.1 : 0.5) {
                Text("\(L("Ceiling height")) \(metric ? String(format: "%.1f m", ceiling <= 0 ? 2.4 : ceiling) : String(format: "%.1f ft", ceiling <= 0 ? 8 : ceiling))").font(HandyFont.caption)
            }
            Stepper("\(L("Doors")) \(doors)", value: $doors, in: 0...6).font(HandyFont.caption)
            Stepper("\(L("Windows")) \(windows)", value: $windows, in: 0...10).font(HandyFont.caption)
            Stepper("\(L("Coats of paint")) \(coats)", value: $coats, in: 1...3).font(HandyFont.caption)
            row(L("Wall area"), areaText(n.wallArea))
            row(L("Paint"), RoomMath.paintText(n, metric: metric))
            row(L("Flooring (with 10% for cuts)"), areaText(n.flooring))
            HandyFlow(spacing: HandySpacing.s8) {
                Text(L("Tile size")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                ForEach(metric ? [0.2, 0.3, 0.6] : [0.1524, 0.3048, 0.6096], id: \.self) { t in
                    HChip(text: metric ? "\(Int(t * 100)) cm" : "\(Int((t / 0.0254).rounded()))\"", selected: abs(tileSide - t) < 0.001) { tileSide = t }
                }
            }
            row(L("Tiles (10% spare)"), "\(n.tiles)")
            Text(L("Usual numbers: a litre of paint covers about 10 m² per coat; check the can. Doors and windows are taken off the walls.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            ShareLink(item: buyList(n)) { Label(L("Share the shopping list"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
        }
        .cardStyle()
    }

    private func buyList(_ n: RoomMath.Needs) -> String {
        ["\(L("Room")): \(summary(.floor))",
         "\(L("Paint")) (\(coats) \(L("coats"))): \(RoomMath.paintText(n, metric: metric))",
         "\(L("Flooring")): \(areaText(n.flooring))",
         "\(L("Tiles")): \(n.tiles)"].joined(separator: "\n")
    }

    // MARK: whole room (LiDAR)

    @ViewBuilder private var roomPanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack {
                Label(L("Whole room"), systemImage: "cube.transparent").font(HandyFont.bodyStrong)
                Spacer()
                Button { job = nil; room = nil } label: { Label(L("Change"), systemImage: "chevron.left") }.textButton()
            }
            if let room {
                RoomPlanCard(room: room, metric: metric)
                ShareLink(item: room.text(metric: metric)) { Label(L("Share the room's sizes"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
                Button { saveName = L("Room"); RoomMath.add(name: L("Room"), value: room.text(metric: metric), photo: room.planImage(metric: metric)); saved = RoomMath.load(); CopyToast.shared.flash(L("Saved to My measurements")) } label: {
                    Label(L("Save this room"), systemImage: "bookmark").frame(maxWidth: .infinity)
                }.secondaryButton()
            } else {
                Text(L("Walk slowly round the room with the camera on the walls. Tenzy finds every wall, door and window and draws the floor plan.")).font(HandyFont.body).fixedSize(horizontal: false, vertical: true)
            }
            Button { scanning = true } label: { Label(room == nil ? L("Start the room scan") : L("Scan again"), systemImage: "camera.viewfinder").frame(maxWidth: .infinity) }.primaryButton()
        }
    }

    // MARK: saving and sharing

    private func summary(_ j: Job) -> String {
        let p = ar.points
        switch j {
        case .length:
            return "\(L("Length")): " + zip(p.dropFirst(), p).map { MeasureMath.length(MeasureMath.distance($0.0, $0.1), metric: metric) }.joined(separator: " + ") + (p.count > 2 ? " = \(MeasureMath.length(MeasureMath.pathLength(p), metric: metric))" : "")
        case .wall:
            guard p.count >= 2 else { return "" }
            let r = MeasureMath.rectangle(p[0], p[1])
            return "\(L("Width")) \(MeasureMath.length(r.width, metric: metric)) × \(L("height")) \(MeasureMath.length(r.height, metric: metric)) = \(MeasureMath.area(r.area, metric: metric))"
        case .floor:
            let s = MeasureMath.surface(p)
            return "\(L("Area")) \(MeasureMath.area(s.area, metric: metric)), \(L("edge all round")) \(MeasureMath.length(s.perimeter, metric: metric))"
        case .height:
            guard p.count >= 2 else { return "" }
            return "\(L("Height")) \(MeasureMath.length(MeasureMath.height(from: p[0], to: p[1]), metric: metric))"
        case .room: return room?.text(metric: metric) ?? ""
        }
    }

    private func capturePhoto(_ j: Job) {
        capturing = true
        let text = summary(j)
        Task {
            let base = await ar.snapshot()
            let composed = base.map { label($0, with: text) }
            defer { capturing = false }
            guard let composed else { return }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Measurement-\(UUID().uuidString.prefix(4)).png")
            if let d = composed.pngData() { try? d.write(to: url) }
            photo = MeasurePhoto(url: url, image: composed)
        }
    }

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

    @ViewBuilder private var savedSection: some View {
        if !saved.isEmpty {
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Text(L("My measurements")).font(HandyFont.cardTitle)
                ForEach(saved) { m in
                    HStack(spacing: HandySpacing.s12) {
                        if let img = RoomMath.image(m) {
                            Image(uiImage: img).resizable().scaledToFill().frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)).contentShape(Rectangle())
                        } else {
                            Image(systemName: "ruler").frame(width: 48, height: 48).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.name).font(HandyFont.bodyStrong)
                            Text(m.value).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
                        }
                        Spacer()
                        Button(role: .destructive) { RoomMath.remove(m); saved = RoomMath.load() } label: { Image(systemName: "trash").accessibilityLabel(L("Delete")) }
                            .buttonStyle(.plain).foregroundStyle(HandyColor.textSecondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { viewing = m }
                    .cardStyle(padding: HandySpacing.s12)
                }
            }
        }
    }

    private func saveNow() {
        guard let j = job else { return }
        let name = saveName, value = summary(j)
        Task {
            let base = await ar.snapshot()
            let img = base.map { label($0, with: value) }
            RoomMath.add(name: name, value: value, photo: img)
            saved = RoomMath.load()
            HandyHaptics.success()
            CopyToast.shared.flash(L("Saved to My measurements"))
        }
    }
}

// MARK: - AR session

@MainActor final class ARMeasure: NSObject, ObservableObject, ARSessionDelegate {
    @Published var points: [SIMD3<Float>] = []
    @Published var liveDistance: Float?
    @Published var liveHeight: Float?
    @Published var cursor: SIMD3<Float>?
    @Published var hasSurface = false
    @Published var closed = false
    @Published var warning: String?
    @Published var lidar = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    var job: MeasureARView.Job = .length
    var metric = true
    weak var view: ARView?
    private var drawn: [AnchorEntity] = []
    private var recent: [SIMD3<Float>] = []
    private var running = false

    /// Done = this job has all its points (more taps start nothing new until Start over).
    var done: Bool {
        switch job {
        case .wall, .height: return points.count >= 2
        case .floor: return closed
        default: return false
        }
    }

    func start() {
        guard let v = view, ARWorldTrackingConfiguration.isSupported, !running else { return }
        let cfg = ARWorldTrackingConfiguration()
        cfg.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) { cfg.sceneReconstruction = .mesh }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) { cfg.frameSemantics.insert(.smoothedSceneDepth) }
        cfg.environmentTexturing = .none
        v.session.delegate = self
        v.session.run(cfg, options: [.resetTracking, .removeExistingAnchors])
        running = true
    }
    func stop() { view?.session.pause(); running = false }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in self.updateCursor() }
    }

    /// Plain words when tracking is poor, so a point isn't placed somewhere wrong without the person knowing.
    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let text: String?
        switch camera.trackingState {
        case .normal: text = nil
        case .notAvailable: text = "Camera tracking isn't available right now."
        case .limited(.excessiveMotion): text = "Slow down — move the phone more gently."
        case .limited(.insufficientFeatures): text = "Too plain or too dark here — add light or aim at something with detail."
        case .limited(.initializing), .limited(.relocalizing): text = "Getting ready — move the phone slowly from side to side."
        case .limited: text = "Move the phone slowly so Tenzy can see the room."
        @unknown default: text = nil
        }
        Task { @MainActor in self.warning = text }
    }

    private func hit(_ p: CGPoint) -> SIMD3<Float>? {
        guard let v = view else { return nil }
        let r = v.raycast(from: p, allowing: .existingPlaneGeometry, alignment: .any).first
            ?? v.raycast(from: p, allowing: .estimatedPlane, alignment: .any).first
        return r.map { SIMD3<Float>($0.worldTransform.columns.3.x, $0.worldTransform.columns.3.y, $0.worldTransform.columns.3.z) }
    }

    /// The live point under the circle, smoothed over the last few frames so the reading doesn't jitter.
    private func updateCursor() {
        guard let v = view else { return }
        if let c = hit(CGPoint(x: v.bounds.midX, y: v.bounds.midY)) {
            if let last = recent.last, simd_distance(last, c) > 0.08 { recent = [] }   // jumped to another surface
            recent.append(c); if recent.count > 5 { recent.removeFirst() }
            cursor = recent.reduce(SIMD3<Float>(repeating: 0), +) / Float(recent.count)
        } else { cursor = nil; recent = [] }
        hasSurface = cursor != nil
        if let c = cursor, let last = points.last, !done {
            liveDistance = simd_distance(c, last)
            liveHeight = MeasureMath.height(from: points[0], to: c)
        } else { liveDistance = nil; liveHeight = nil }
    }

    /// Place a point where the person tapped, or under the circle when `at` is nil.
    func place(at p: CGPoint?) {
        guard !done else { HandyHaptics.light(); return }
        let spot = p.flatMap(hit) ?? (p == nil ? cursor : nil)
        guard let c = spot else { warning = "No surface there yet — move the phone slowly, then try again."; return }
        warning = nil
        // Floor: tapping back on the first corner closes the shape.
        if job == .floor, points.count >= 3, simd_distance(c, points[0]) < 0.06 { close(); return }
        points.append(c)
        HandyHaptics.light()
        if job == .wall || job == .height, points.count == 2 { HandyHaptics.success() }
        redraw()
    }

    func close() {
        guard points.count >= 3 else { return }
        closed = true
        // Put corners tapped out of order back in order, so the drawn shape matches the area.
        points = MeasureMath.surface(points).points
        HandyHaptics.success(); redraw()
    }

    func undo() {
        if closed { closed = false } else if !points.isEmpty { points.removeLast() }
        redraw()
    }
    func reset() { points = []; closed = false; warning = nil; redraw() }

    /// Redraw every marker, line and size label from the points, for the current job.
    func redraw() {
        guard let v = view else { drawn = []; return }
        drawn.forEach { v.scene.removeAnchor($0) }; drawn = []
        for p in points { add(dot(at: p)) }
        switch job {
        case .wall where points.count == 2:
            let c = MeasureMath.rectangleCorners(points[0], points[1])
            for i in 0..<4 { add(line(c[i], c[(i + 1) % 4])) }
            add(label(MeasureMath.length(MeasureMath.distance(c[0], c[1]), metric: metric), at: (c[0] + c[1]) / 2))
            add(label(MeasureMath.length(MeasureMath.distance(c[1], c[2]), metric: metric), at: (c[1] + c[2]) / 2))
        case .height where points.count == 2:
            let top = SIMD3<Float>(points[0].x, points[1].y, points[0].z)
            add(line(points[0], top))
            add(label(MeasureMath.length(MeasureMath.height(from: points[0], to: points[1]), metric: metric), at: (points[0] + top) / 2))
        default:
            let path = closed ? points + [points[0]] : points
            for (a, b) in zip(path, path.dropFirst()) {
                add(line(a, b))
                add(label(MeasureMath.length(simd_distance(a, b), metric: metric), at: (a + b) / 2))
            }
            if job == .floor, closed {
                let s = MeasureMath.surface(points)
                add(label(MeasureMath.area(s.area, metric: metric), at: s.points.reduce(SIMD3<Float>(repeating: 0), +) / Float(s.points.count), big: true))
            }
        }
    }

    private func add(_ a: AnchorEntity) { view?.scene.addAnchor(a); drawn.append(a) }

    private func dot(at p: SIMD3<Float>) -> AnchorEntity {
        let a = AnchorEntity(world: p)
        a.addChild(ModelEntity(mesh: .generateSphere(radius: 0.012), materials: [UnlitMaterial(color: .white)]))
        a.addChild(ModelEntity(mesh: .generateSphere(radius: 0.008), materials: [UnlitMaterial(color: .systemYellow)]))
        return a
    }

    private func line(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> AnchorEntity {
        let mid = (a + b) / 2
        let anchor = AnchorEntity(world: mid)
        let bar = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.006, 0.006, max(0.001, simd_distance(a, b)))), materials: [UnlitMaterial(color: .systemYellow)])
        bar.look(at: b, from: mid, relativeTo: nil)
        anchor.addChild(bar)
        return anchor
    }

    /// The size written in the scene on a dark tag that always faces the camera.
    private func label(_ text: String, at p: SIMD3<Float>, big: Bool = false) -> AnchorEntity {
        let anchor = AnchorEntity(world: p + SIMD3<Float>(0, 0.025, 0))
        let holder = Entity()
        holder.components.set(BillboardComponent())
        let mesh = MeshResource.generateText(text, extrusionDepth: 0.0005, font: .systemFont(ofSize: big ? 0.05 : 0.032, weight: .bold),
                                             containerFrame: .zero, alignment: .center, lineBreakMode: .byClipping)
        let t = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
        let b = mesh.bounds
        t.position = SIMD3<Float>(-b.center.x, -b.center.y, 0.001)
        var plate = UnlitMaterial(color: .black)
        plate.blending = .transparent(opacity: 0.7)
        let bg = ModelEntity(mesh: .generatePlane(width: b.extents.x + 0.024, height: b.extents.y + 0.014, cornerRadius: 0.008), materials: [plate])
        holder.addChild(bg); holder.addChild(t)
        anchor.addChild(holder)
        return anchor
    }

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
        // Apple's own "move iPhone to start" coaching, while the room is first being mapped.
        let coach = ARCoachingOverlayView()
        coach.session = v.session
        coach.goal = .anyPlane
        coach.activatesAutomatically = true
        coach.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        v.addSubview(coach)
        return v
    }
    func updateUIView(_ uiView: ARView, context: Context) {}
}
