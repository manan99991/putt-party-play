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
    let done: ([UIImage]) -> Void
    @StateObject private var finder = PhotoFinderModel()
    @State private var picked: [String] = []
    @State private var allItems: [PhotosPickerItem] = []
    @State private var loading = false
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
                                ForEach(finder.matches, id: \.localIdentifier) { a in cell(a) }
                            }
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
                    var out: [UIImage] = []
                    for i in items { if let d = try? await i.loadTransferable(type: Data.self), let im = UIImage(data: d) { out.append(im) } }
                    finish(out)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: HandySpacing.s8) {
            Image(systemName: kind.icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(HandyColor.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(L(kind.title)).font(HandyFont.bodyStrong)
                Text(L("Found in your photos — tap one to use it.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
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
            var out: [UIImage] = []
            for id in ids { if let a = byID[id], let im = await PhotoFinder.image(a, side: 2600) { out.append(im) } }
            finish(out)
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
