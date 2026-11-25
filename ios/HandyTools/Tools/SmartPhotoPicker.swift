import SwiftUI
import Photos
import PhotosUI
import UIKit.UIGestureRecognizerSubclass

/// The photo picker that already knows what you're looking for: a tool that needs a receipt opens on "Receipts and
/// warranty cards" — only the photos that look like one, newest first — with "All photos" one tap away for anything
/// it missed. Tap a photo to use it (or tick several where the tool takes more than one). Everything is read on the
/// phone; nothing is uploaded.
struct SmartPhotoPicker: View {
    let kind: PhotoFinder.Kind
    var maxCount = 1
    var done: ([UIImage]) -> Void = { _ in }
    /// When set, the picked photos come back as their own original files (bytes + extension) instead of pictures.
    var doneFiles: (([(Data, String)]) -> Void)? = nil
    @StateObject private var finder = PhotoFinderModel()
    @State private var picked: [String] = []
    @State private var allItems: [PhotosPickerItem] = []
    @State private var loading = false
    /// Where each photo sits on screen, so a swipe across them picks every one it passes over.
    @State private var frames: [String: CGRect] = [:]
    @State private var swipeAdds: Bool?
    @State private var lastSwipe: CGPoint?
    /// Where a swipe started (a photo's place in the grid) and what was picked before it, so a swipe picks every photo
    /// from where it started to where the finger is — like Photos — even if a quick swipe skipped some touch reports.
    @State private var swipeFrom: Int?
    @State private var swipeBase: [String] = []
    /// Under UI tests only: which photo the swipe started and ended on, so a failed swipe check says why.
    @State private var swipeTrace = ""
    /// Under UI tests only: each thumbnail's loaded size, so a test knows the real picture is drawn.
    @State private var thumbSizes: [String: CGSize] = [:]
    @Environment(\.dismiss) private var dismiss

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s12) {
                    header
                    if finder.access == .denied || finder.access == .restricted {
                        deniedCard
                    } else {
                        if !finder.matches.isEmpty {
                            LazyVGrid(columns: cols, spacing: 6) {
                                ForEach(finder.matches, id: \.localIdentifier) { a in
                                    cell(a).background(GeometryReader { g in
                                        Color.clear.preference(key: CellFrames.self, value: [a.localIdentifier: g.frame(in: .named("finder-grid"))])
                                    })
                                }
                            }
                            .coordinateSpace(name: "finder-grid")
                            .onPreferenceChange(CellFrames.self) { frames = $0 }
                            .gesture(SwipeSelect(enabled: maxCount > 1, began: { swipe(at: $0, first: true) }, moved: { swipe(at: $0, first: false) },
                                                 ended: { swipeAdds = nil; lastSwipe = nil; swipeFrom = nil }))
                        }
                        status
                    }
                }
                .padding(.horizontal, HandySpacing.gutter).padding(.vertical, HandySpacing.s12)
            }
            .background(HandyColor.bg)
            .safeAreaInset(edge: .bottom) { bottomBar }
            .navigationTitle(L("Choose a photo")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { finder.stop(); dismiss() } } }
            .task {
                // UI tests: tall phone screenshots at the top of the library, the shape that exposed the 25 Nov tap bug.
                if Launch.uitest, Launch.args.contains("-seedtall") { await Self.seedTallShots() }
                finder.start(kind)
            }
            .onDisappear { finder.stop() }
            .onChange(of: allItems) { _, items in
                guard !items.isEmpty else { return }
                loading = true
                Task {
                    var files: [(Data, String)] = []
                    for i in items {
                        if let d = try? await i.loadTransferable(type: Data.self) { files.append((d, i.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg")) }
                    }
                    finishFiles(files)
                }
            }
        }
    }

    /// Six tall (phone-screenshot shaped) pictures, each a different colour, saved to the library once (UI tests only).
    static func seedTallShots() async {
        let key = "uitest.seededTall"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        let shots = (0..<6).map { k in
            UIGraphicsImageRenderer(size: CGSize(width: 590, height: 1278), format: f).image { ctx in
                UIColor(hue: CGFloat(k) / 6, saturation: 0.6, brightness: 0.8, alpha: 1).setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 590, height: 1278))
                ("\(k + 1)" as NSString).draw(at: CGPoint(x: 220, y: 520), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 200), .foregroundColor: UIColor.white])
            }
        }
        do {
            try await PHPhotoLibrary.shared().performChanges { for img in shots { PHAssetChangeRequest.creationRequestForAsset(from: img) } }
            UserDefaults.standard.set(true, forKey: key)
        } catch {}
    }

    private var header: some View {
        HStack(spacing: HandySpacing.s8) {
            Image(systemName: kind.icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(HandyColor.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(L(kind.title)).font(HandyFont.bodyStrong)
                // What it's looking for, in plain words, then how to pick.
                Text(L(kind.lookingFor)).font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                Text(maxCount > 1 ? L("Tap photos, or swipe a finger across them to pick several at once.")
                     : L("Tap one to use it. Not here? All photos is at the bottom."))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var status: some View {
        if !finder.finished {
            HStack(spacing: 8) {
                ProgressView()
                Text(finder.total == 0 ? L("Looking through your photos…")
                     : "\(L("Looking through your photos")) — \(finder.looked) \(L("of")) \(finder.total)")
                    .font(HandyFont.caption.monospacedDigit()).foregroundStyle(HandyColor.textSecondary)
            }
            .accessibilityIdentifier("finder-looking")
        } else if finder.matches.isEmpty {
            EmptyState(icon: kind.icon, line: "None found in your recent photos",
                       sub: "Tap All photos below to pick any picture yourself.")
        } else {
            Text("\(finder.matches.count) \(L("found in your last")) \(finder.total) \(L("photos"))")
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        if finder.access == .limited {
            Text(L("Tenzy can only see the photos you've shared with it. To look through all of them, allow Full Access in Settings."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.amber).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var deniedCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("To find these for you, Tenzy needs to look through your photos — on this phone only, nothing is uploaded."))
                .font(HandyFont.body).fixedSize(horizontal: false, vertical: true)
            Button { Permission.openSettings() } label: { Label(L("Allow in Settings"), systemImage: "gearshape").frame(maxWidth: .infinity) }.secondaryButton()
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    /// Swipe sideways across photos to pick them all, the way Photos does: the first photo touched decides whether the
    /// swipe ticks or unticks every photo it passes over.
    private func swipe(at p: CGPoint, first: Bool) {
        let ids = finder.matches.map(\.localIdentifier)
        // The swipe's first photo is the closest one to the press, however far; after that only photos near the finger.
        guard let here = nearest(p, ids, within: first ? .infinity : 40) else { return }
        if first || swipeFrom == nil {
            swipeFrom = here
            swipeBase = picked
            swipeAdds = !picked.contains(ids[here])
        }
        guard let from = swipeFrom else { return }
        if Launch.uitest {
            let at = "\(here)@\(Int(p.x)),\(Int(p.y))"
            swipeTrace = first ? "start \(at)" : (swipeTrace.components(separatedBy: " end ").first ?? "") + " end \(at)"
        }
        let span = ids[min(from, here)...max(from, here)]
        let before = picked.count
        if swipeAdds == true {
            var next = swipeBase
            for id in span where !next.contains(id) && next.count < maxCount { next.append(id) }
            picked = next
        } else {
            picked = swipeBase.filter { !span.contains($0) }
        }
        if picked.count != before { HandyHaptics.light() }
    }

    /// The photo under the finger — or the closest one when it's in the gap between two.
    private func nearest(_ p: CGPoint, _ ids: [String], within limit: CGFloat = 40) -> Int? {
        var best: (i: Int, d: CGFloat)?
        for (i, id) in ids.enumerated() {
            guard let f = frames[id] else { continue }
            let dx = max(f.minX - p.x, 0, p.x - f.maxX), dy = max(f.minY - p.y, 0, p.y - f.maxY)
            let d = dx * dx + dy * dy
            if d == 0 { return i }
            if best == nil || d < best!.d { best = (i, d) }
        }
        guard let best, best.d < limit * limit else { return nil }
        return best.i
    }

    private func cell(_ a: PHAsset) -> some View {
        let on = picked.contains(a.localIdentifier)
        return Button {
            if maxCount == 1 { use([a.localIdentifier]); return }
            if on { picked.removeAll { $0 == a.localIdentifier } } else if picked.count < maxCount { picked.append(a.localIdentifier) }
        } label: {
            AssetThumb(asset: a, loaded: Launch.uitest ? { sz in thumbSizes[a.localIdentifier] = sz } : nil)
                .overlay(alignment: .topTrailing) {
                    if maxCount > 1 {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 22))
                            .foregroundStyle(on ? HandyColor.accent : .white).shadow(radius: 2).padding(6)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? HandyColor.accent : .clear, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("Photo"))
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("finder-photo")
        .accessibilityValue(Launch.uitest ? (thumbSizes[a.localIdentifier].map { "loaded \(Int($0.width))x\(Int($0.height))" } ?? "empty") : "")
    }

    private var bottomBar: some View {
        VStack(spacing: HandySpacing.s8) {
            if maxCount > 1, !picked.isEmpty {
                Button { use(picked) } label: {
                    Text("\(L("Use")) \(picked.count) \(L(picked.count == 1 ? "photo" : "photos"))").frame(maxWidth: .infinity)
                }.primaryButton().accessibilityIdentifier("finder-use").accessibilityValue(Launch.uitest ? swipeTrace : "")
            }
            PhotosPicker(selection: $allItems, maxSelectionCount: maxCount, matching: .images) {
                HStack { if loading { ProgressView() }; Label(L("All photos"), systemImage: "photo.on.rectangle") }.frame(maxWidth: .infinity)
            }
            .secondaryButton().accessibilityIdentifier("finder-all")
        }
        .padding(.horizontal, HandySpacing.gutter).padding(.vertical, HandySpacing.s8)
        .background(.ultraThinMaterial)
    }

    private func use(_ ids: [String]) {
        loading = true
        Task {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            var byID: [String: PHAsset] = [:]
            assets.enumerateObjects { a, _, _ in byID[a.localIdentifier] = a }
            if doneFiles != nil {
                var files: [(Data, String)] = []
                for id in ids { if let a = byID[id], let f = await PhotoFinder.original(a) { files.append(f) } }
                finishFiles(files)
            } else {
                var out: [UIImage] = []
                // A menu board's small print needs every pixel the camera took (23 Nov: a 5-screen board read at
                // 2,600 px lost most of its dishes); everything else is plenty at 2,600.
                let side: CGFloat = kind == .menu ? 6000 : 2600
                for id in ids { if let a = byID[id], let im = await PhotoFinder.image(a, side: side) { out.append(im) } }
                finish(out)
            }
        }
    }

    private func finishFiles(_ files: [(Data, String)]) {
        if let doneFiles {
            finder.stop(); dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { doneFiles(files) }
        } else {
            finish(files.compactMap { UIImage(data: $0.0) })
        }
    }

    private func finish(_ images: [UIImage]) {
        finder.stop()
        dismiss()
        // The tool opens what was picked once this sheet has gone (a second sheet can't open over it).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { done(images) }
    }
}

/// One square photo from the library.
private struct AssetThumb: View {
    let asset: PHAsset
    var loaded: ((CGSize) -> Void)? = nil
    @State private var img: UIImage?
    var body: some View {
        Color.clear.aspectRatio(1, contentMode: .fit)
            .overlay { if let img { Image(uiImage: img).resizable().scaledToFill() } else { HandyColor.surface } }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)).contentShape(Rectangle())
            // A just-saved or iCloud photo can say "not ready yet" the first time: ask again a few times before giving up.
            .task(id: asset.localIdentifier) {
                for wait in [0, 400, 1200, 3000] as [UInt64] {
                    if wait > 0 { try? await Task.sleep(nanoseconds: wait * 1_000_000) }
                    if Task.isCancelled { return }
                    if let i = await PhotoFinder.image(asset, side: 300) { img = i; loaded?(i.size); return }
                }
            }

    }
}

/// A tool's "choose a photo" button that opens the smart picker for what the tool needs — receipts for Warranty,
/// cards for Business Cards, menus for Menu… — with All photos a tap away.
struct SmartPhotoButton<Content: View>: View {
    let kind: PhotoFinder.Kind
    var max = 1
    let picked: ([UIImage]) -> Void
    @ViewBuilder let label: () -> Content
    @State private var open = false
    var body: some View {
        Button { open = true } label: { label() }
            .sheet(isPresented: $open) { SmartPhotoPicker(kind: kind, maxCount: max, done: picked) }
    }
}

private struct CellFrames: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue()) { $1 } }
}

/// The same, for flows that need each photo's own original file (bytes + extension), not a re-saved picture.
struct SmartPhotoFilesButton<Content: View>: View {
    let kind: PhotoFinder.Kind
    var max = 1
    let picked: ([(Data, String)]) -> Void
    @ViewBuilder let label: () -> Content
    @State private var open = false
    var body: some View {
        Button { open = true } label: { label() }
            .sheet(isPresented: $open) { SmartPhotoPicker(kind: kind, maxCount: max, doneFiles: picked) }
    }
}

/// The sideways swipe, done in UIKit so it wins over the page's scrolling only when the finger moves sideways: a
/// SwiftUI drag inside a scroll view gets cancelled the moment the scroll view's own pan starts (the first swipe test
/// picked just one photo). Mostly-vertical drags fail at once and the page scrolls as normal.
private struct SwipeSelect: UIGestureRecognizerRepresentable {
    var enabled: Bool
    var began: (CGPoint) -> Void
    var moved: (CGPoint) -> Void
    var ended: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }
    func makeUIGestureRecognizer(context: Context) -> PressPan {
        let g = PressPan()
        g.delegate = context.coordinator
        g.maximumNumberOfTouches = 1
        return g
    }
    func updateUIGestureRecognizer(_ g: PressPan, context: Context) { g.isEnabled = enabled }
    func handleUIGestureRecognizerAction(_ g: PressPan, context: Context) {
        let p = context.converter.location(in: .named("finder-grid"))
        switch g.state {
        case .began:
            // The press point, recorded by the recogniser itself on touch-down (the delegate isn't guaranteed to be
            // asked — SwiftUI manages it — and a pan's own translation leaves out the distance it needed to recognise,
            // so a quick swipe started one photo late three times), then where the finger is now.
            let now = g.location(in: g.view)
            let d = g.pressPoint.map { CGPoint(x: now.x - $0.x, y: now.y - $0.y) } ?? g.translation(in: g.view)
            began(CGPoint(x: p.x - d.x, y: p.y - d.y)); moved(p)
        case .changed: moved(p)
        case .ended:
            // Where the finger lifted counts too — a quick swipe's last report can come only with the lift.
            moved(p); ended()
        default: ended()
        }
    }

    /// A pan that remembers where the finger first came down, in its own view.
    final class PressPan: UIPanGestureRecognizer {
        private(set) var pressPoint: CGPoint?
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            if numberOfTouches == 0 { pressPoint = touches.first?.location(in: view) }
            super.touchesBegan(touches, with: event)
        }
        override func reset() { super.reset(); pressPoint = nil }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let pan = g as? UIPanGestureRecognizer else { return true }
            let v = pan.velocity(in: pan.view), t = pan.translation(in: pan.view)
            let dx = abs(v.x) + abs(t.x), dy = abs(v.y) + abs(t.y)
            return dx > dy
        }
        // The page's scrolling waits for a sideways swipe to fail before it starts.
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            other.view is UIScrollView && other is UIPanGestureRecognizer
        }
    }
}
