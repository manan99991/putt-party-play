import SwiftUI
import Photos
import PhotosUI

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
                                                 ended: { swipeAdds = nil; lastSwipe = nil }))
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
            .task { finder.start(kind) }
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

    private var header: some View {
        HStack(spacing: HandySpacing.s8) {
            Image(systemName: kind.icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(HandyColor.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(L(kind.title)).font(HandyFont.bodyStrong)
                Text(maxCount > 1 ? L("Tap photos, or swipe a finger across them to pick several at once.")
                     : (kind == .any ? L("Tap one to use it.") : L("Found in your photos — tap one to use it.")))
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
        // A quick swipe skips over photos between two touch reports — walk the line between them so none is missed.
        let from = first ? p : (lastSwipe ?? p)
        lastSwipe = p
        let steps = max(1, Int((hypot(p.x - from.x, p.y - from.y) / 8).rounded(.up)))
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let q = CGPoint(x: from.x + (p.x - from.x) * t, y: from.y + (p.y - from.y) * t)
            guard let id = frames.first(where: { $0.value.contains(q) })?.key else { continue }
            if swipeAdds == nil || (first && i == 0) { swipeAdds = !picked.contains(id) }
            if swipeAdds == true, !picked.contains(id), picked.count < maxCount { picked.append(id); HandyHaptics.light() }
            if swipeAdds == false, picked.contains(id) { picked.removeAll { $0 == id }; HandyHaptics.light() }
        }
    }

    private func cell(_ a: PHAsset) -> some View {
        let on = picked.contains(a.localIdentifier)
        return Button {
            if maxCount == 1 { use([a.localIdentifier]); return }
            if on { picked.removeAll { $0 == a.localIdentifier } } else if picked.count < maxCount { picked.append(a.localIdentifier) }
        } label: {
            AssetThumb(asset: a)
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
    }

    private var bottomBar: some View {
        VStack(spacing: HandySpacing.s8) {
            if maxCount > 1, !picked.isEmpty {
                Button { use(picked) } label: {
                    Text("\(L("Use")) \(picked.count) \(L(picked.count == 1 ? "photo" : "photos"))").frame(maxWidth: .infinity)
                }.primaryButton().accessibilityIdentifier("finder-use")
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
                for id in ids { if let a = byID[id], let im = await PhotoFinder.image(a, side: 2600) { out.append(im) } }
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
    @State private var img: UIImage?
    var body: some View {
        Color.clear.aspectRatio(1, contentMode: .fit)
            .overlay { if let img { Image(uiImage: img).resizable().scaledToFill() } else { HandyColor.surface } }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .task(id: asset.localIdentifier) { img = await PhotoFinder.image(asset, side: 300) }
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
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let g = UIPanGestureRecognizer()
        g.delegate = context.coordinator
        g.maximumNumberOfTouches = 1
        return g
    }
    func updateUIGestureRecognizer(_ g: UIPanGestureRecognizer, context: Context) { g.isEnabled = enabled }
    func handleUIGestureRecognizerAction(_ g: UIPanGestureRecognizer, context: Context) {
        let p = context.converter.location(in: .named("finder-grid"))
        switch g.state {
        case .began:
            // The press point, then where the finger is now.
            let t = g.translation(in: g.view)
            began(CGPoint(x: p.x - t.x, y: p.y - t.y)); moved(p)
        case .changed: moved(p)
        default: ended()
        }
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
