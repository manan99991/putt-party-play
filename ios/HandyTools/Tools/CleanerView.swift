import SwiftUI
import Photos

/// Cleaner — find screenshots, large videos and near-duplicate photos & videos, and remove the ones
/// you pick. Scanning is on-device; deletion always goes through iOS's own "Delete N items?" sheet.
/// Duplicates are pre-scanned in the background (see CleanerIndex) so the tab is ready on open.
struct CleanerView: View {
    private enum Cat: Int, CaseIterable { case screenshots, videos, duplicates
        var title: String { ["Screenshots", "Large videos", "Duplicates"][rawValue] } }

    @ObservedObject private var index = CleanerIndex.shared

    @State private var cat: Cat = .screenshots
    @State private var authorized = PhotoCleaner.authorized
    @State private var items: [PhotoCleaner.Item] = []     // screenshots / large videos (cheap, on-demand)
    @State private var selected: Set<String> = []
    @State private var localScanning = false
    @State private var sortBySize = true                   // largest first — what you want when freeing space
    @State private var receivedOnly = false                // videos tab: only videos not recorded on this phone
    @State private var busy = false
    @State private var note: String?

    // MARK: derived

    private var groups: [[PhotoCleaner.Item]] { index.duplicates ?? [] }
    private var isScanning: Bool { cat == .duplicates ? (index.scanning && groups.isEmpty) : localScanning }

    private var sortedItems: [PhotoCleaner.Item] {
        sortBySize ? items.sorted { $0.bytes > $1.bytes } : items     // items arrive newest-first
    }
    private func groupBytes(_ g: [PhotoCleaner.Item]) -> Int64 { g.reduce(Int64(0)) { $0 + $1.bytes } }
    private var sortedGroups: [[PhotoCleaner.Item]] {
        sortBySize ? groups.sorted { groupBytes($0) > groupBytes($1) } : groups
    }

    private var all: [PhotoCleaner.Item] { cat == .duplicates ? groups.flatMap { $0 } : items }
    private var selectedItems: [PhotoCleaner.Item] { all.filter { selected.contains($0.id) } }
    private var reclaim: Int64 { selectedItems.reduce(Int64(0)) { $0 + $1.bytes } }
    private var totalBytes: Int64 { all.reduce(Int64(0)) { $0 + $1.bytes } }
    private var allSelected: Bool { !all.isEmpty && selected.count == all.count }

    // MARK: body

    var body: some View {
        let footer: AnyView? = (authorized && !all.isEmpty && !isScanning) ? AnyView(actionBar) : nil
        return ToolPage(title: "Cleaner",
                        subtitle: "Screenshots, big videos and duplicate photos & videos — clear the ones you choose. iOS confirms every delete.",
                        footer: footer) {
            HowTo("cleaner", [
                "Switch between Large, Duplicates and Received across the top.",
                "Tap items to select, or Select all; the bar shows how much space you will free.",
                "Delete when ready — iOS always asks you to confirm before anything is removed.",
            ])
            if !authorized {
                authGate
            } else {
                Picker("", selection: $cat) { ForEach(Cat.allCases, id: \.rawValue) { Text($0.title).tag($0) } }
                    .pickerStyle(.segmented)
                    .onChange(of: cat) { _, _ in refreshForCat() }

                if cat == .videos {
                    Picker("Source", selection: $receivedOnly) {
                        Text("Large videos").tag(false)
                        Text("Received").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: receivedOnly) { _, _ in selected = []; scanLocal() }
                    Text("Received = saved, downloaded or forwarded to you — not recorded on this phone.")
                        .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }

                if isScanning {
                    scanningView
                } else {
                    content
                }
                if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
            }
        }
        .onAppear { if authorized { refreshForCat() } }
        .onChange(of: index.duplicates) { _, _ in if cat == .duplicates { preselectDuplicateExtras() } }
    }

    private var authGate: some View {
        VStack(spacing: HandySpacing.s12) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 40)).foregroundStyle(HandyColor.accent).padding(.top, HandySpacing.s24)
            Text("Allow photo access to scan for space you can free. Nothing leaves your phone, and deleting always asks you first.")
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button {
                Task {
                    let s = await PhotoCleaner.authorize()
                    authorized = (s == .authorized || s == .limited)
                    if authorized { CleanerIndex.shared.prewarm(); refreshForCat() }
                }
            } label: { Label("Allow photo access", systemImage: "checkmark.shield").frame(maxWidth: .infinity) }.primaryButton()
        }.frame(maxWidth: .infinity)
    }

    private var scanningView: some View {
        VStack(spacing: 6) {
            if cat == .duplicates { ProgressView(value: index.progress) } else { ProgressView() }
            Text(cat == .duplicates ? "Scanning your photos & videos… \(Int(index.progress * 100))%" : "Scanning…")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }.frame(maxWidth: .infinity).padding(.vertical, HandySpacing.s24)
    }

    @ViewBuilder private var content: some View {
        if all.isEmpty {
            EmptyState(icon: "sparkles",
                       line: "Nothing to clean here",
                       sub: cat == .duplicates ? "No look-alike photos or videos in your recent library." : cat == .videos ? (receivedOnly ? "No received or downloaded videos found." : "No large videos found.") : "No screenshots found.")
        } else {
            HStack {
                Text("\(all.count) item\(all.count == 1 ? "" : "s") · about \(PhotoCleaner.format(totalBytes))")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Spacer()
            }
            Picker("Sort", selection: $sortBySize) {
                Text("Largest first").tag(true)
                Text("Most recent").tag(false)
            }
            .pickerStyle(.segmented)
            if cat == .duplicates {
                ForEach(Array(sortedGroups.enumerated()), id: \.offset) { _, g in
                    Text("\(g.count) look-alikes · keep one").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
                    grid(g)
                }
            } else {
                grid(sortedItems)
            }
            Text("Deleting asks iOS to remove the items — you'll get the system confirmation, and they go to Recently Deleted for 30 days.")
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
    }

    /// Pinned at the bottom (above the ad) so the delete action and the running total are always in
    /// view, however far down the grid you've scrolled.
    private var actionBar: some View {
        VStack(spacing: HandySpacing.s8) {
            HStack {
                Button(allSelected ? "Deselect all" : "Select all") {
                    selected = allSelected ? [] : Set(all.map { $0.id })
                }.textButton()
                Spacer()
                Text("\(selected.count) selected").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Button { deleteSelected() } label: {
                HStack {
                    if busy { ProgressView().tint(.white) }
                    Text(selected.isEmpty ? "Select items to free space" : "Delete \(selectedItems.count) · free about \(PhotoCleaner.format(reclaim))")
                }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(selected.isEmpty || busy)
        }
        .padding(.horizontal, HandySpacing.gutter)
        .padding(.vertical, HandySpacing.s8)
        .background(HandyColor.surface)
        .overlay(alignment: .top) { Divider() }
    }

    private func grid(_ list: [PhotoCleaner.Item]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], spacing: 6) {
            ForEach(list) { item in
                AssetThumb(asset: item.asset, selected: selected.contains(item.id), label: PhotoCleaner.format(item.bytes)) {
                    if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
                }
            }
        }
    }

    // MARK: scan flow

    /// Called on appear and whenever the category changes: resets the selection and loads the right
    /// data — the cheap fetches run on demand; duplicates reuse the background scan if it's ready.
    private func refreshForCat() {
        selected = []
        note = nil
        switch cat {
        case .duplicates:
            CleanerIndex.shared.prewarm()
            if !groups.isEmpty { preselectDuplicateExtras() }
        case .screenshots, .videos:
            scanLocal()
        }
    }

    private func scanLocal() {
        localScanning = true; items = []
        let c = cat
        Task {
            let recv = receivedOnly
            let found = await Task.detached(priority: .userInitiated) { () -> [PhotoCleaner.Item] in
                c == .videos ? PhotoCleaner.videos(receivedOnly: recv) : PhotoCleaner.screenshots()
            }.value
            await MainActor.run { if cat == c { items = found; localScanning = false } }
        }
    }

    /// Keep the first (most recent) of each duplicate group, pre-select the rest to delete.
    private func preselectDuplicateExtras() {
        var s = Set<String>()
        for group in groups { for item in group.dropFirst() { s.insert(item.id) } }
        selected = s
    }

    private func deleteSelected() {
        let assets = selectedItems.map { $0.asset }
        let ids = Set(assets.map { $0.localIdentifier })
        busy = true
        Task {
            let ok = await PhotoCleaner.delete(assets)
            await MainActor.run {
                busy = false
                guard ok else { note = "Nothing was deleted."; return }
                items.removeAll { ids.contains($0.id) }
                CleanerIndex.shared.remove(ids: ids)
                selected = []
                note = "Done — removed from your library."
                HandyHaptics.success()
            }
        }
    }
}

/// A photo-library thumbnail with a selection check and a size label.
///
/// The cell is a true square that fills its grid column (`Color.clear` + `aspectRatio`), the image is
/// an overlay clipped to that square, and `contentShape(Rectangle())` pins the tap area to exactly the
/// square — so a tap can never register on a neighbouring tile, whatever the photo's aspect ratio.
private struct AssetThumb: View {
    let asset: PHAsset
    let selected: Bool
    let label: String
    let tap: () -> Void
    @State private var img: UIImage?
    @State private var unavailable = false   // iCloud-only or unreadable: say so instead of a blank tile

    var body: some View {
        Button(action: tap) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let img { Image(uiImage: img).resizable().scaledToFill() }
                    else if unavailable {
                        Rectangle().fill(HandyColor.surface).overlay(VStack(spacing: 4) {
                            Image(systemName: "icloud.and.arrow.down").font(.system(size: 18))
                            Text("In iCloud").font(HandyFont.micro)
                        }.foregroundStyle(HandyColor.textSecondary))
                    }
                    else { Rectangle().fill(HandyColor.surface) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(selected ? HandyColor.accent : Color.clear, lineWidth: 3))
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 3) {
                        if asset.mediaType == .video { Image(systemName: "play.fill").font(.system(size: 8)) }
                        Text(label).font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2).background(.black.opacity(0.55), in: Capsule()).padding(4)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20)).foregroundStyle(selected ? HandyColor.accent : .white)
                        .padding(5).shadow(color: .black.opacity(0.4), radius: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task { load() }
    }

    private func load() {
        let o = PHImageRequestOptions(); o.deliveryMode = .opportunistic; o.resizeMode = .fast; o.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFill, options: o) { im, info in
            if let im { img = im; unavailable = false }
            else if (info?[PHImageErrorKey] != nil) || (info?[PHImageCancelledKey] as? Bool == true) || (info?[PHImageResultIsInCloudKey] as? Bool == true) {
                // Network is off on purpose (grid stays fast), so an iCloud-only photo lands here.
                unavailable = true
            }
        }
    }
}
