import SwiftUI
import Photos

/// The passport photo screen, the same wherever it's opened (Studio, the Builder step, the Guide):
///  1. pick the country (the rules change with it);
///  2. a Passport-ready score with a meter, and the verdict in plain words;
///  3. the finished photo with the official guide lines drawn on it (top of head, chin, eye band), press and
///     hold for the original;
///  4. what was fixed, and each check with what was measured and how to fix it;
///  5. where it goes: Photos, the file for an online application, and a 4×6 in print sheet with cut lines.
struct PassportStudio: View {
    let original: UIImage
    @State var specID: String
    var retake: (() -> Void)? = nil

    @State private var options: PassportPhoto.Options? = nil
    @State private var made: PassportPhoto.Made?
    @State private var working = false
    @State private var noFace = false
    @State private var showGuides = true
    @State private var holding = false
    @State private var sheet: (data: Data, copies: Int)?
    @State private var saved: Bool?

    private var spec: PassportPhoto.Spec { PassportPhoto.spec(specID) }
    private var opts: PassportPhoto.Options { options ?? .defaults(for: spec) }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            countryPicker
            if working && made == nil {
                ToolProgressBar(label: L("Measuring your face against the rules…"))
            }
            if noFace {
                Label(L("No face found. Use a photo of you facing the camera, with your whole head and shoulders in view."), systemImage: "person.crop.square.badge.camera")
                    .font(HandyFont.body).foregroundStyle(HandyColor.danger).fixedSize(horizontal: false, vertical: true)
                    .cardStyle(padding: HandySpacing.s12)
                if let retake { Button { retake() } label: { Label(L("Choose another photo"), systemImage: "photo") .frame(maxWidth: .infinity) }.primaryButton() }
            }
            if let made {
                scoreCard(made)
                photo(made)
                if !made.fixes.isEmpty { fixesCard(made) }
                checksCard(made)
                editsCard
                landing(made)
                yourselfCard
            }
        }
        .task(id: "\(specID)|\(opts.background)|\(opts.light)|\(opts.straighten)") { await run() }
    }

    // MARK: country

    private var countryPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("Which passport or visa?")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(PassportPhoto.specs) { s in
                    HChip(text: L(s.short), selected: s.id == specID) { specID = s.id; options = nil; sheet = nil; saved = nil }
                        .accessibilityIdentifier("passport-\(s.id)")
                }
            }
            Text("\(L(spec.name)) · \(L("Head, chin to top:")) \(spec.headText)")
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: score

    private func tint(_ m: PassportPhoto.Made) -> Color {
        m.retake ? HandyColor.danger : (m.score >= 90 ? HandyColor.success : (m.score >= 70 ? HandyColor.amber : HandyColor.danger))
    }

    private func scoreCard(_ m: PassportPhoto.Made) -> some View {
        HStack(spacing: HandySpacing.s16) {
            ZStack {
                Circle().stroke(HandyColor.border, lineWidth: 10)
                Circle().trim(from: 0, to: CGFloat(m.score) / 100)
                    .stroke(tint(m), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: m.score)
                VStack(spacing: 0) {
                    Text("\(m.score)").font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(L("of 100")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Passport-ready score")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Text(L(m.verdict)).font(HandyFont.cardTitle).foregroundStyle(tint(m))
                Text(summary(m)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("passport-score")
    }

    private func summary(_ m: PassportPhoto.Made) -> String {
        let n = m.toFix.count
        if m.retake {
            let hard = m.checks.filter { $0.hard && $0.state == .fail }.map { L($0.title).lowercased() }
            return "\(L("Software can't fix this:")) \(hard.joined(separator: ", ")). \(L("Take another photo — tips below."))"
        }
        return "\(m.passing)/\(m.checks.count) \(L("checks passed"))" + (n == 0 ? "" : " · \(n) \(L("to look at"))")
    }

    // MARK: photo with guides

    private func photo(_ m: PassportPhoto.Made) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(uiImage: holding ? original : m.image).resizable().scaledToFit()
                .overlay { if showGuides && !holding { GeometryReader { geo in guides(m, in: geo.size) } } }
                .overlay(alignment: .topLeading) {
                    Text(holding ? L("Original") : "\(L(m.spec.short)) · \(Int(m.spec.px.width))×\(Int(m.spec.px.height))")
                        .font(HandyFont.micro).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.black.opacity(0.6), in: Capsule()).foregroundStyle(.white).padding(8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(maxWidth: .infinity).frame(maxHeight: 420)
                .onLongPressGesture(minimumDuration: 0.05, maximumDistance: 60, perform: {}, onPressingChanged: { holding = $0 })
                .accessibilityLabel(L("The finished passport photo. Press and hold to see the original."))
            HStack {
                Toggle(L("Show guide lines"), isOn: $showGuides).font(HandyFont.caption).tint(HandyColor.accent)
            }
            Text(L("Green band: where the top of your head may be. Blue band: where your eyes may be. Press and hold to see the original."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func guides(_ m: PassportPhoto.Made, in size: CGSize) -> some View {
        let k = size.width / m.spec.px.width
        let g = m.guides
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.green.opacity(0.18))
                .frame(width: size.width, height: max(2, (g.headBand.upperBound - g.headBand.lowerBound) * k))
                .offset(y: g.headBand.lowerBound * k)
            if let eb = g.eyeBand {
                Rectangle().fill(Color.blue.opacity(0.16))
                    .frame(width: size.width, height: max(2, (eb.upperBound - eb.lowerBound) * k))
                    .offset(y: eb.lowerBound * k)
            }
            line(y: g.crownY * k, width: size.width, color: .green, label: L("Top of head"))
            line(y: g.chinY * k, width: size.width, color: .green, label: "\(L("Chin")) · \(L("Head")) \(PassportPhoto.fmt((m.headMM * 10).rounded() / 10)) mm")
            if m.spec.eyes != nil { line(y: g.eyeY * k, width: size.width, color: .blue, label: L("Eyes")) }
            Rectangle().fill(Color.white.opacity(0.5)).frame(width: 1, height: size.height).offset(x: g.centreX * k)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func line(y: CGFloat, width: CGFloat, color: Color, label: String) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(color).frame(width: width, height: 1.5)
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 5).padding(.vertical, 1).background(color.opacity(0.85), in: Capsule())
                .offset(x: 6, y: 3)
        }
        .offset(y: y)
    }

    // MARK: what changed, and the checks

    private func fixesCard(_ m: PassportPhoto.Made) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("What Tenzy fixed"), systemImage: "wand.and.stars").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.accent)
            ForEach(m.fixes) { f in
                Label(L(f.text), systemImage: f.icon).font(HandyFont.body).fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private func checksCard(_ m: PassportPhoto.Made) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label("\(L("Checked against the rules")) · \(L(m.spec.short))", systemImage: "checklist").font(HandyFont.bodyStrong)
            ForEach(m.checks.sorted { $0.state.rawValue > $1.state.rawValue }) { c in
                HStack(alignment: .top, spacing: HandySpacing.s8) {
                    Image(systemName: c.state == .pass ? "checkmark.circle.fill" : (c.state == .warn ? "exclamationmark.circle.fill" : "xmark.circle.fill"))
                        .foregroundStyle(c.state == .pass ? HandyColor.success : (c.state == .warn ? HandyColor.amber : HandyColor.danger))
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L(c.title)).font(HandyFont.body)
                        Text(L(c.detail)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        if c.state != .pass {
                            Text(L(c.fix)).font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private var editsCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Toggle(L(spec.background == .white ? "Plain white background" : "Plain light grey background"), isOn: Binding(get: { opts.background }, set: { var o = opts; o.background = $0; options = o }))
            Toggle(L("Even out the light"), isOn: Binding(get: { opts.light }, set: { var o = opts; o.light = $0; options = o }))
            Toggle(L("Straighten a tilted head"), isOn: Binding(get: { opts.straighten }, set: { var o = opts; o.straighten = $0; options = o }))
            if spec.unaltered {
                Text(L("India asks for photos not altered by software, so only sizing and straightening are on. Turn the others on only if your photo office allows it."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.amber).fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(HandyFont.body).tint(HandyColor.accent)
        .cardStyle(padding: HandySpacing.s12)
    }

    private var yourselfCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L("Check these yourself"), systemImage: "person.fill.questionmark").font(HandyFont.bodyStrong)
            ForEach(spec.rules, id: \.self) { r in
                Label(L(r), systemImage: "circle").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Text("\(L("Measured on your phone against the official rules:")) \(spec.source). \(L("The office that takes the photo has the final say."))")
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    // MARK: where it goes

    @ViewBuilder private func landing(_ m: PassportPhoto.Made) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            if m.retake, let retake {
                Button { retake() } label: { Label(L("Take or choose another photo"), systemImage: "camera").frame(maxWidth: .infinity) }.primaryButton()
            }
            Button { Task { await save(m) } } label: {
                Label(saved == true ? L("Saved to Photos") : L("Save to Photos"), systemImage: saved == true ? "checkmark" : "photo.badge.plus").frame(maxWidth: .infinity)
            }
            .modifier(Prominent(on: !m.retake)).disabled(saved == true)
            .accessibilityIdentifier("passport-save")
            if saved == false { Text(L("Tenzy needs permission to add to Photos. You can allow it in Settings › Tenzy › Photos.")).font(HandyFont.micro).foregroundStyle(HandyColor.danger) }
            if let d = PassportPhoto.file(m) {
                ShareLink(item: JPEGFile(data: d), preview: SharePreview(L(m.spec.name))) {
                    Label("\(L(m.spec.printable ? "Share the file" : "Share the file to upload")) · \(Int(m.spec.px.width))×\(Int(m.spec.px.height)) · \(SizeTarget.format(d.count))", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }.secondaryButton()
            }
            if m.spec.printable {
                if let sheet {
                    ShareLink(item: JPEGFile(data: sheet.data), preview: SharePreview(L("Print sheet"))) {
                        Label("\(L("Save the print sheet")) · \(sheet.copies) \(L(sheet.copies == 1 ? "copy" : "copies"))", systemImage: "printer").frame(maxWidth: .infinity)
                    }.secondaryButton()
                    Text(L("Order it as a 4×6 in (10×15 cm) print at any photo counter or photo app, at 100% size, then cut along the lines."))
                        .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    Button { sheet = PassportPhoto.printSheet(m); if sheet != nil { HandyHaptics.success() } } label: {
                        Label(L("Make a 4×6 in print sheet"), systemImage: "squareshape.split.2x2").frame(maxWidth: .infinity)
                    }.secondaryButton().accessibilityIdentifier("passport-sheet")
                }
            }
        }
    }

    private struct Prominent: ViewModifier {
        let on: Bool
        func body(content: Content) -> some View { if on { content.primaryButton() } else { content.secondaryButton() } }
    }

    private func save(_ m: PassportPhoto.Made) async {
        guard let d = PassportPhoto.file(m) else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { saved = false; return }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetCreationRequest.forAsset().addResource(with: .photo, data: d, options: nil) }
            saved = true; HandyHaptics.success()
        } catch { saved = false }
    }

    // MARK: run

    private func run() async {
        working = true; noFace = false; sheet = nil; saved = nil
        let src = original, s = spec, o = opts
        let out = await Task.detached(priority: .userInitiated) { PassportPhoto.make(src, spec: s, options: o) }.value
        working = false
        if let out { made = out } else { made = nil; noFace = true }
    }
}

/// How to take a photo that passes, shown before picking one.
struct PassportTips: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(L("For a photo that passes"), systemImage: "lightbulb").font(HandyFont.caption.weight(.semibold))
            ForEach(["Stand in front of a plain light wall, facing a window", "Phone at eye level, about an arm's length away — or ask someone to take it", "Head and shoulders in view, looking straight at the lens", "Neutral face, mouth closed, glasses off"], id: \.self) { t in
                Text("• \(L(t))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: HandySpacing.s12)
    }
}

/// The front camera, for taking a passport photo on the spot. Falls back to the photo library without a camera.
struct SelfieCamera: UIViewControllerRepresentable {
    var front = true          // false: the back camera, for whiteboards, lists and calendars
    let done: (UIImage?) -> Void
    func makeCoordinator() -> Coord { Coord(done: done) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            p.sourceType = .camera
            if front, UIImagePickerController.isCameraDeviceAvailable(.front) { p.cameraDevice = .front }
        }
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(done: @escaping (UIImage?) -> Void) { self.done = done }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { done(info[.originalImage] as? UIImage) }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}
