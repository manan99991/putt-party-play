import SwiftUI
import Photos

/// Cleaner — find screenshots, large videos and near-duplicate photos, and remove the ones you pick.
/// Everything is scanned on-device; deletion always goes through iOS's own "Delete N items?" sheet.
struct CleanerView: View {
    private enum Cat: Int, CaseIterable { case screenshots, videos, duplicates
        var title: String { ["Screenshots", "Large videos", "Duplicates"][rawValue] } }

    @State private var cat: Cat = .screenshots
    @State private var authorized = PhotoCleaner.authorized
    @State private var items: [PhotoCleaner.Item] = []
    @State private var groups: [[PhotoCleaner.Item]] = []
    @State private var selected: Set<String> = []
    @State private var scanning = false
    @State private var progress = 0.0
    @State private var busy = false
    @State private var note: String?

    private var all: [PhotoCleaner.Item] { cat == .duplicates ? groups.flatMap { $0 } : items }
    private var selectedItems: [PhotoCleaner.Item] { all.filter { selected.contains($0.id) } }
    private var reclaim: Int64 { selectedItems.reduce(Int64(0)) { $0 + $1.bytes } }

    var body: some View {
        ToolPage(title: "Cleaner", subtitle: "Screenshots, big videos and duplicate photos — clear the ones you choose. iOS confirms every delete.") {
            if !authorized {
                VStack(spacing: HandySpacing.s12) {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 40)).foregroundStyle(HandyColor.accent).padding(.top, HandySpacing.s24)
                    Text("Allow photo access to scan for space you can free. Nothing leaves your phone, and deleting always asks you first.")
                        .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                    Button {
                        Task { let s = await PhotoCleaner.authorize(); authorized = (s == .authorized || s == .limited); if authorized { scan() } }
                    } label: { Label("Allow photo access", systemImage: "checkmark.shield").frame(maxWidth: .infinity) }.primaryButton()
                }.frame(maxWidth: .infinity)
            } else {
                Picker("", selection: $cat) { ForEach(Cat.allCases, id: \.rawValue) { Text($0.title).tag($0) } }
                    .pickerStyle(.segmented)
                    .onChange(of: cat) { _, _ in selected = []; scan() }

                if scanning {
                    VStack(spacing: 6) {
                        if cat == .duplicates { ProgressView(value: progress) } else { ProgressView() }
                        Text(cat == .duplicates ? "Scanning recent photos… \(Int(progress * 100))%" : "Scanning…")
                            .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, HandySpacing.s24)
                } else {
                    content
                }
                if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
            }
        }
        .onAppear { if authorized, items.isEmpty, groups.isEmpty { scan() } }
    }

    @ViewBuilder private var content: some View {
        if all.isEmpty {
            EmptyState(icon: "sparkles",
                       line: "Nothing to clean here",
                       sub: cat == .duplicates ? "No look-alike photos in your recent library." : cat == .videos ? "No large videos found." : "No screenshots found.")
        } else {
            HStack {
                Button(selected.count == all.count ? "Deselect all" : "Select all") {
                    selected = selected.count == all.count ? [] : Set(all.map { $0.id })
                }.textButton()
                Spacer()
                Text("\(all.count) item\(all.count == 1 ? "" : "s") · about \(PhotoCleaner.format(all.reduce(Int64(0)) { $0 + $1.bytes }))")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            if cat == .duplicates {
                ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                    Text("\(g.count) look-alikes · keep one").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
                    grid(g)
                }
            } else {
                grid(all)
            }
            Button { deleteSelected() } label: {
                HStack {
                    if busy { ProgressView().tint(.white) }
                    Text(selected.isEmpty ? "Select items to free space" : "Delete \(selectedItems.count) · free about \(PhotoCleaner.format(reclaim))")
                }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(selected.isEmpty || busy)
            Text("Deleting asks iOS to remove the items — you'll get the system confirmation, and they go to Recently Deleted for 30 days.")
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
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

    private func scan() {
        scanning = true; progress = 0; items = []; groups = []
        let c = cat
        Task {
            if c == .duplicates {
                let g = await PhotoCleaner.duplicates(progress: { p in Task { @MainActor in progress = p } })
                await MainActor.run { groups = g; scanning = false; preselectDuplicateExtras(g) }
            } else {
                let found = await Task.detached(priority: .userInitiated) { c == .videos ? PhotoCleaner.largeVideos() : PhotoCleaner.screenshots() }.value
                await MainActor.run { items = found; scanning = false }
            }
        }
    }

    /// Keep the first (most recent) of each duplicate group, pre-select the rest.
    private func preselectDuplicateExtras(_ g: [[PhotoCleaner.Item]]) {
        var s = Set<String>()
        for group in g { for item in group.dropFirst() { s.insert(item.id) } }
        selected = s
    }

    private func deleteSelected() {
        let assets = selectedItems.map { $0.asset }
        busy = true
        Task {
            let ok = await PhotoCleaner.delete(assets)
            await MainActor.run {
                busy = false
                guard ok else { note = "Nothing was deleted."; return }
                let ids = Set(assets.map { $0.localIdentifier })
                items.removeAll { ids.contains($0.id) }
                groups = groups.map { $0.filter { !ids.contains($0.id) } }.filter { $0.count > 1 }
                selected = []
                note = "Done — removed from your library."
                HandyHaptics.success()
            }
        }
    }
}

/// A photo-library thumbnail with a selection check and a size label.
private struct AssetThumb: View {
    let asset: PHAsset
    let selected: Bool
    let label: String
    let tap: () -> Void
    @State private var img: UIImage?

    var body: some View {
        Button(action: tap) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img { Image(uiImage: img).resizable().scaledToFill() }
                    else { Rectangle().fill(HandyColor.surface) }
                }
                .frame(width: 100, height: 100).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(selected ? HandyColor.accent : Color.clear, lineWidth: 3))
                .overlay(alignment: .bottomLeading) {
                    Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2).background(.black.opacity(0.55), in: Capsule()).padding(4)
                }
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20)).foregroundStyle(selected ? HandyColor.accent : .white)
                    .padding(5).shadow(color: .black.opacity(0.4), radius: 1)
            }
        }
        .buttonStyle(.plain)
        .task { load() }
    }

    private func load() {
        let o = PHImageRequestOptions(); o.deliveryMode = .opportunistic; o.resizeMode = .fast; o.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: o) { im, _ in
            if let im { img = im }
        }
    }
}
