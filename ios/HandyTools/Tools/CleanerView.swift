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
    // Drag-to-select: turn on "Select", then sweep a finger across thumbnails, like Photos.
    @State private var selecting = false
    @State private var cellFrames: [String: CGRect] = [:]
    @State private var localScanning = false
    @State private var sortBySize = true                   // largest first — what you want when freeing space
    @State private var receivedOnly = false                // videos tab: only videos not recorded on this phone
    @State private var busy = false
    @State private var note: String?
    @State private var extraRows: [PhotoCleaner.PlanRow] = []     // bursts, old screenshots, videos sent to you
    @State private var planOff: Set<String> = []
    @State private var freeBefore: Int64?
    @State private var cleanedBytes: Int64 = 0
    // "Keep only my newest N screenshots" — starts at the number the screenshot alert watches for.
    @State private var keepN = Int(AlertStore.rule(.screenshots)?.limit ?? 100)
    @State private var keepCustom = ""
    @State private var keepFavourites = true

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
                        subtitle: "How much space you can free, biggest wins first — one tap clears it, keeping the best of every set. iPhone confirms every delete.",
                        footer: footer, working: busy) {
            HowTo("cleaner", [
                "Open it and it finds the safe wins for you — duplicate copies you can clear in one tap.",
                "Below that, review screenshots and big videos; tap to pick, or Select + drag across a run.",
                "Delete when ready — iOS always asks you to confirm, and items go to Recently Deleted for 30 days.",
            ])
            if !authorized {
                authGate
            } else {
                cleanupHero
                DisclosureGroup {
                    VStack(spacing: HandySpacing.s8) {
                        SmartAlertCard(kind: .screenshots)
                        SmartAlertCard(kind: .lowSpace)
                        SmartAlertCard(kind: .bigVideos)
                    }.padding(.top, HandySpacing.s8)
                } label: { Label(L("Notify me when it's time to clean up"), systemImage: "bell.badge").font(HandyFont.bodyStrong) }
                .tint(HandyColor.accent)
                Picker(L(""), selection: $cat) { ForEach(Cat.allCases, id: \.rawValue) { Text($0.title).tag($0) } }
                    .pickerStyle(.segmented)
                    .onChange(of: cat) { _, _ in refreshForCat() }

                if cat == .videos {
                    Picker(L("Source"), selection: $receivedOnly) {
                        Text(L("Large videos")).tag(false)
                        Text(L("Received")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: receivedOnly) { _, _ in selected = []; scanLocal() }
                    Text(L("Received = saved, downloaded or forwarded to you — not recorded on this phone."))
                        .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }

                if isScanning {
                    scanningView
                } else {
                    if cat == .screenshots && !items.isEmpty { keepNewestCard }
                    content
                }
                if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
            }
        }
        .onAppear { if authorized { CleanerIndex.shared.prewarm(); refreshForCat(); loadPlan() } }
        .onChange(of: index.duplicates) { _, _ in if cat == .duplicates { preselectDuplicateExtras() } }
    }

    // MARK: hero — the safe win, done for you

    /// Duplicate copies that are safe to clear automatically: every look-alike except the one we keep.
    private var safeDupExtras: [PhotoCleaner.Item] { (index.duplicates ?? []).flatMap { $0.dropFirst() } }
    private var safeReclaim: Int64 { safeDupExtras.reduce(Int64(0)) { $0 + $1.bytes } }

    /// Everything worth clearing, biggest first: duplicate copies (one of each kept), burst frames (the best kept),
    /// screenshots older than a month, videos other people sent. Favourites are never in it.
    private var planRows: [PhotoCleaner.PlanRow] {
        PhotoCleaner.plan([PhotoCleaner.PlanRow(id: "dups", title: "Duplicate copies", why: "The best copy of each is kept", items: safeDupExtras.filter { !$0.asset.isFavorite })] + extraRows)
    }
    private var planIncluded: [PhotoCleaner.Item] { planRows.filter { !planOff.contains($0.id) }.flatMap(\.items) }
    private var planBytes: Int64 { planIncluded.reduce(0) { $0 + $1.bytes } }

    private func loadPlan() {
        guard authorized else { return }
        freeBefore = PhotoCleaner.freeBytes()
        Task.detached(priority: .utility) {
            let b = PhotoCleaner.bursts()
            let old = PhotoCleaner.oldScreenshots()
            let sent = PhotoCleaner.videos(receivedOnly: true)
            let rows = [
                PhotoCleaner.PlanRow(id: "bursts", title: "Extra burst shots", why: b.isEmpty ? "" : "Keeping one of each burst — \(b.first!.why)", items: b.flatMap(\.extras)),
                PhotoCleaner.PlanRow(id: "oldshots", title: "Screenshots older than a month", why: "Favourites left alone", items: old),
                PhotoCleaner.PlanRow(id: "sent", title: "Videos sent to you", why: "Saved or forwarded — not recorded on this phone", items: sent),
            ]
            await MainActor.run { extraRows = rows }
        }
    }

    @ViewBuilder private var cleanupHero: some View {
        let rows = planRows
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            if let freeBefore {
                Text("\(L("Free on your phone now:")) \(PhotoCleaner.format(freeBefore))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            if index.scanning && rows.isEmpty {
                ToolProgressBar(label: "Finding space you can free…")
            } else if rows.isEmpty {
                Label(L("Nothing safe to clear — your library's already tidy."), systemImage: "checkmark.seal.fill")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.success)
            } else {
                Text("\(L("Free about")) \(PhotoCleaner.format(planBytes))").font(.system(size: 28, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("cleaner-plan-total")
                Text(L("Biggest wins first. Switch off anything you want to keep.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                ForEach(rows) { r in
                    Toggle(isOn: Binding(get: { !planOff.contains(r.id) }, set: { on in if on { planOff.remove(r.id) } else { planOff.insert(r.id) } })) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(L(r.title)) · \(r.items.count)").font(HandyFont.body.weight(.semibold))
                            Text("\(PhotoCleaner.format(r.bytes))\(r.why.isEmpty ? "" : " · " + L(r.why))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }.tint(HandyColor.accent)
                }
                Button { cleanPlan() } label: {
                    HStack { if busy { BusySpinner().tint(.white) }
                        Label("\(L("Clean")) \(planIncluded.count) \(L(planIncluded.count == 1 ? "item" : "items"))", systemImage: "sparkles") }.frame(maxWidth: .infinity)
                }.primaryButton().disabled(busy || planIncluded.isEmpty).accessibilityIdentifier("cleaner-plan-clean")
                Text(L("iPhone asks you to confirm. Everything goes to Recently Deleted for 30 days, so nothing is lost by mistake."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            if cleanedBytes > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(L("Cleared about")) \(PhotoCleaner.format(cleanedBytes))", systemImage: "checkmark.circle.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success)
                    if let freeBefore { Text("\(L("Free space")): \(PhotoCleaner.format(freeBefore)) → \(L("about")) \(PhotoCleaner.format(freeBefore + cleanedBytes)) \(L("once Recently Deleted is emptied"))").font(HandyFont.caption) }
                    Text(L("To get the space back now: Photos → Albums → Recently Deleted → Select → Delete All.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    Button(L("Open Photos")) { if let u = URL(string: "photos-redirect://") { UIApplication.shared.open(u) } }.textButton()
                }.padding(.top, 4)
            }
        }.cardStyle()
    }

    private func cleanPlan() {
        let items = planIncluded
        guard !items.isEmpty else { return }
        let ids = Set(items.map(\.id))
        let freed = items.reduce(Int64(0)) { $0 + $1.bytes }
        busy = true
        Task {
            let ok = await PhotoCleaner.delete(items.map(\.asset))
            await MainActor.run {
                busy = false
                guard ok else { note = "Nothing was deleted."; return }
                CleanerIndex.shared.remove(ids: ids)
                selected.subtract(ids)
                extraRows = extraRows.map { PhotoCleaner.PlanRow(id: $0.id, title: $0.title, why: $0.why, items: $0.items.filter { !ids.contains($0.id) }) }
                cleanedBytes += freed
                HandyHaptics.success()
            }
        }
    }

    // MARK: keep only the newest screenshots

    /// The older screenshots past the newest `keepN` (items arrive newest first), favourites left alone if asked.
    private var olderScreenshots: [PhotoCleaner.Item] {
        PhotoCleaner.beyondNewest(items, keep: keepN, protect: { keepFavourites && $0.asset.isFavorite })
    }

    private var keepNewestCard: some View {
        let older = olderScreenshots
        let bytes = older.reduce(Int64(0)) { $0 + $1.bytes }
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Keep only my newest screenshots"), systemImage: "rectangle.stack.badge.minus").font(HandyFont.bodyStrong)
            HStack(spacing: 6) {
                Text(L("Keep my newest")).font(HandyFont.body)
                Text("\(keepN)").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.accent)
            }
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach([50, 100, 200, 500], id: \.self) { n in
                    HChip(text: "\(n)", selected: keepN == n && keepCustom.isEmpty) { keepN = n; keepCustom = "" }
                }
                TextField(L("Other"), text: $keepCustom).keyboardType(.numberPad).frame(width: 80).textFieldStyle(.handy)
                    .onChange(of: keepCustom) { _, t in if let v = Int(t.filter(\.isNumber)), v >= 0 { keepN = v } }
                    .accessibilityLabel(L("Another number to keep"))
            }
            Toggle(L("Never touch favourites"), isOn: $keepFavourites).font(HandyFont.caption).tint(HandyColor.accent)
            if older.isEmpty {
                Label("\(L("You have")) \(items.count) \(L("screenshots — nothing older to clear."))", systemImage: "checkmark.seal.fill")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("\(L("You have")) \(items.count) \(L("screenshots.")) \(older.count) \(L("older ones would go — about")) \(PhotoCleaner.format(bytes)).")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                Button {
                    selected = Set(older.map(\.id)); sortBySize = false
                    note = "Selected \(older.count) older screenshot\(older.count == 1 ? "" : "s"). Scroll to check them, then tap Delete — iPhone asks you to confirm, and they stay in Recently Deleted for 30 days."
                } label: {
                    Label("\(L("Select the")) \(older.count) \(L("older screenshots"))", systemImage: "checkmark.circle").frame(maxWidth: .infinity)
                }.primaryButton().disabled(busy).accessibilityIdentifier("keep-newest-select")
            }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private var authGate: some View {
        VStack(spacing: HandySpacing.s12) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 40)).foregroundStyle(HandyColor.accent).padding(.top, HandySpacing.s24)
            Text(L("Allow photo access to scan for space you can free. Nothing leaves your phone, and deleting always asks you first."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button {
                if Permission.photosDenied { Permission.openSettings(); return }
                Task {
                    let s = await PhotoCleaner.authorize()
                    authorized = (s == .authorized || s == .limited)
                    if authorized { CleanerIndex.shared.prewarm(); refreshForCat(); loadPlan() }
                }
            } label: { Label(Permission.photosDenied ? "Open Settings to allow photos" : "Allow photo access",
                             systemImage: Permission.photosDenied ? "gearshape" : "checkmark.shield").frame(maxWidth: .infinity) }.primaryButton()
        }.frame(maxWidth: .infinity)
    }

    /// What the duplicate check looked at, in plain words — it never says "tidy" without saying what it checked.
    private var checkedLine: String {
        var line = index.photosChecked + index.videosChecked > 0
            ? String(format: L("Checked all %@ photos and %@ videos for copies."), index.photosChecked.formatted(), index.videosChecked.formatted())
            : L("No look-alike photos or videos found.")
        if index.skippedInCloud > 0 {
            line += " " + String(format: L("%@ in iCloud only couldn't be checked — download them in Photos to include them."), index.skippedInCloud.formatted())
        }
        return line
    }

    private var scanningView: some View {
        VStack(spacing: 6) {
            if cat == .duplicates { ProgressView(value: index.progress) } else { BusySpinner() }
            Text(cat == .duplicates ? "\(L("Checking your whole library for copies…")) \(Int(index.progress * 100))%" : L("Scanning…"))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            if cat == .duplicates {
                Text(index.timeLeft ?? L("The first check reads every photo once; after that only new ones."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            }
        }.frame(maxWidth: .infinity).padding(.vertical, HandySpacing.s24)
    }

    @ViewBuilder private var content: some View {
        if all.isEmpty {
            EmptyState(icon: "sparkles",
                       line: "Nothing to clean here",
                       sub: cat == .duplicates ? checkedLine : cat == .videos ? (receivedOnly ? "No received or downloaded videos found." : "No large videos found.") : "No screenshots found.")
        } else {
            HStack {
                Text("\(all.count) item\(all.count == 1 ? "" : "s") · about \(PhotoCleaner.format(totalBytes))")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Spacer()
            }
            Picker(L("Sort"), selection: $sortBySize) {
                Text(L("Largest first")).tag(true)
                Text(L("Most recent")).tag(false)
            }
            .pickerStyle(.segmented)
            ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                if cat == .duplicates {
                    Text(checkedLine).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(sortedGroups.enumerated()), id: \.offset) { _, g in
                        Text("\(g.count) look-alikes · keep one").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
                        grid(g)
                    }
                } else {
                    grid(sortedItems)
                }
            }
            .onPreferenceChange(PaintCellFrames.self) { cellFrames = $0 }
            .paintSelect(active: selecting, frames: cellFrames, selected: $selected, proxy: proxy)
            }
            Text(L("Deleting asks iOS to remove the items — you'll get the system confirmation, and they go to Recently Deleted for 30 days."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
    }

    /// Pinned at the bottom (above the ad) so the delete action and the running total are always in
    /// view, however far down the grid you've scrolled.
    private var actionBar: some View {
        VStack(spacing: HandySpacing.s8) {
            HStack(spacing: HandySpacing.s16) {
                Button(selecting ? "Done" : "Select") { selecting.toggle() }.textButton()
                Button(allSelected ? "Deselect all" : "Select all") {
                    selected = allSelected ? [] : Set(all.map { $0.id })
                }.textButton()
                Spacer()
                Text("\(selected.count) selected").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            if selecting {
                Text(L("Drag across photos to select or deselect a whole run."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.accent).frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { deleteSelected() } label: {
                HStack {
                    if busy { BusySpinner().tint(.white) }
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
                .paintCell(item.id)
                .id(item.id)
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
                            Text(L("In iCloud")).font(HandyFont.micro)
                        }.foregroundStyle(HandyColor.textSecondary))
                    }
                    else { Rectangle().fill(HandyColor.surface) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)).contentShape(Rectangle())
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
