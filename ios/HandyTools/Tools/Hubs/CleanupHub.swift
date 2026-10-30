import SwiftUI
import Photos
import UIKit

/// Clean Up — free space (duplicates & look-alikes, large videos, screenshots, blurry & dark shots),
/// tidy contacts (merge duplicates, remove empties, .vcf backup first) and a Trash tab that explains
/// where things went. Scans reuse PhotoCleaner / CleanerIndex / ContactsEngine; deletes go through
/// PhotoKit, so iOS shows its own "Delete N items?" sheet and items land in Recently Deleted (30 days).
struct CleanupHub: View {
    private static let tabs = ["Space", "Contacts", "Trash"]

    private struct Category: Identifiable {
        let id: String; let name: String; let icon: String
        var items: [PhotoCleaner.Item]; var groups: [[PhotoCleaner.Item]]? = nil   // groups: duplicates only
        var bytes: Int64 { items.reduce(Int64(0)) { $0 + $1.bytes } }
    }
    private struct Trashed: Identifiable { let id = UUID(); let category: String; let count: Int; let bytes: Int64; let when: Date }

    @ObservedObject private var index = CleanerIndex.shared
    @State private var tab = 0
    // Space
    @State private var authorized = PhotoCleaner.authorized
    @State private var scanned = false
    @State private var scanning = false
    @State private var scanProgress: Double = 0
    @State private var scanLabel = ""
    @State private var cats: [Category] = []
    @State private var reviewing: String?          // category id in review
    @State private var selected: Set<String> = []
    @State private var busy = false
    @State private var note: String?
    @State private var trashed: [Trashed] = []
    // Contacts
    @State private var contactsOK = ContactsEngine.authorized()
    @State private var report: ContactsReport?
    @State private var sources: [String: String] = [:]
    @State private var dismissed: Set<String> = []     // "Keep both" groups (joined ids)
    @State private var contactsBusy = false
    @State private var contactsError: String?
    @State private var backupURL: URL?
    @State private var pendingMerge: [ContactRec]?
    @State private var confirmEmpty = false

    private var storage: (used: Int64, total: Int64)? { CleanupKit.storage() }
    private var usedText: String { storage.map { PhotoCleaner.format($0.used) } ?? "—" }
    private var totalReclaimable: Int64 { cats.reduce(Int64(0)) { $0 + $1.bytes } }
    private var current: Category? { cats.first { $0.id == reviewing } }
    private var selectedItems: [PhotoCleaner.Item] { (current?.items ?? []).filter { selected.contains($0.id) } }
    private var selectedBytes: Int64 { selectedItems.reduce(Int64(0)) { $0 + $1.bytes } }

    var body: some View {
        PowerToolPage(id: "cleanup", tabs: Self.tabs, selected: $tab) {
            Group {
                switch tab {
                case 0: spacePanel
                case 1: contactsPanel
                default: trashPanel
                }
            }
        }
        .onChange(of: index.duplicates) { _, _ in if scanned { refreshDuplicates() } }
        .task { if contactsOK && report == nil { scanContacts() } }
        .confirmationDialog("Merge these contacts?", isPresented: Binding(get: { pendingMerge != nil }, set: { if !$0 { pendingMerge = nil } }), titleVisibility: .visible) {
            Button("Merge \(pendingMerge?.count ?? 0) into one", role: .destructive) { if let g = pendingMerge { merge(g) }; pendingMerge = nil }
            Button("Cancel", role: .cancel) { pendingMerge = nil }
        } message: { Text("Every number and email is kept on one contact; the extra copies are removed. A .vcf backup is made first — this can't be undone otherwise.") }
        .confirmationDialog("Remove empty contacts?", isPresented: $confirmEmpty, titleVisibility: .visible) {
            Button("Back up, then remove \(emptyContacts.count)", role: .destructive) { removeEmpty() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("These have no name, number or email. A .vcf backup of all your contacts is saved first.") }
    }

    // MARK: Space

    @ViewBuilder private var spacePanel: some View {
        if !authorized {
            VStack(spacing: HandySpacing.s12) {
                Image(systemName: "photo.on.rectangle.angled").font(.system(size: 40)).foregroundStyle(HandyColor.accent).padding(.top, HandySpacing.s16)
                Text("Allow photo access to scan for space you can free. Nothing leaves your phone, and deleting always asks you first.")
                    .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                Button {
                    Task { let s = await PhotoCleaner.authorize(); authorized = (s == .authorized || s == .limited); if authorized { CleanerIndex.shared.prewarm() } }
                } label: { Label("Allow photo access", systemImage: "checkmark.shield").frame(maxWidth: .infinity) }.primaryButton()
            }.frame(maxWidth: .infinity)
        } else if let c = current {
            reviewPanel(c)
        } else {
            VStack(spacing: 4) {
                Text(scanned ? "Up to \(PhotoCleaner.format(totalReclaimable))" : "—").font(.system(size: 34, weight: .heavy)).monospacedDigit()
                Text(scanned ? "to free · of \(usedText) used" : (scanning ? scanLabel : "Tap Scan to find what you can free up."))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                if let s = storage, !scanning { Text("\(PhotoCleaner.format(s.total)) on this iPhone").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
            }.frame(maxWidth: .infinity).padding(.top, HandySpacing.s8)
            if scanning { ProgressView(value: scanProgress).tint(HandyColor.accent) }
            Button { scan() } label: {
                HStack { if scanning { ProgressView().tint(.white) }; Label(scanning ? "Scanning…" : (scanned ? "Rescan" : "Scan photos & videos"), systemImage: scanned ? "arrow.clockwise" : "magnifyingglass") }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(scanning)
            if scanned {
                if cats.isEmpty {
                    EmptyState(icon: "sparkles", line: "Nothing to clean here", sub: "No duplicates, big videos, screenshots or blurry shots in your recent library.")
                } else {
                    ForEach(cats) { c in categoryRow(c) }
                }
                if index.skippedInCloud > 0 {
                    HubNote("\(index.skippedInCloud) photo\(index.skippedInCloud == 1 ? "" : "s") in iCloud couldn't be checked. Download them in Photos to include them.")
                }
            }
            if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
            HubNote("Nothing is deleted outright — everything goes to Photos › Recently Deleted for 30 days. Files are shown in full so you can review before you act.")
        }
    }

    private func categoryRow(_ c: Category) -> some View {
        HStack(spacing: HandySpacing.s12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(HandyColor.accentSoft).frame(width: 44, height: 44)
                Image(systemName: c.icon).foregroundStyle(HandyColor.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name).font(HandyFont.bodyStrong)
                Text("\(c.items.count) item\(c.items.count == 1 ? "" : "s") · about \(PhotoCleaner.format(c.bytes))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Spacer()
            Button("Review") { openReview(c) }.compactButton()
        }.cardStyle(padding: HandySpacing.s12)
    }

    private func reviewPanel(_ c: Category) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HubSection("\(c.name) · \(c.items.count) items — tap to keep / select")
            FlowLayout(spacing: 6) {
                HubChip("Select all", selected: false) { selected = Set(c.items.map { $0.id }) }
                HubChip("Keep all", selected: false) { selected = [] }
                HubChip(c.groups != nil ? "Keep best, select rest" : "Keep newest, select rest", selected: false) { keepBest(c) }
            }
            if let groups = c.groups {
                ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                    Text("\(g.count) look-alikes · keep one").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    grid(g)
                }
            } else {
                grid(c.items)
            }
            Button { moveToTrash(c) } label: {
                HStack { if busy { ProgressView().tint(.white) }; Text(selected.isEmpty ? "Nothing selected" : "Move \(selectedItems.count) to Trash · frees \(PhotoCleaner.format(selectedBytes))") }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(selected.isEmpty || busy)
            Button { reviewing = nil; selected = [] } label: { Label("Back to categories", systemImage: "chevron.left").frame(maxWidth: .infinity) }.secondaryButton()
            if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
            HubNote("iOS asks you to confirm, then the items go to Photos › Recently Deleted for 30 days — you can put any of them back from there.")
        }
    }

    private func grid(_ list: [PhotoCleaner.Item]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], spacing: 6) {
            ForEach(list) { item in
                CleanupThumb(asset: item.asset, selected: selected.contains(item.id), label: PhotoCleaner.format(item.bytes)) {
                    if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
                    HandyHaptics.light()
                }
            }
        }
    }

    // MARK: Space flow

    private func scan() {
        scanning = true; scanned = false; scanProgress = 0; note = nil; cats = []; reviewing = nil; selected = []
        scanLabel = "Scanning your photos & videos…"
        CleanerIndex.shared.rescan()
        Task {
            let shots = await Task.detached(priority: .userInitiated) { PhotoCleaner.screenshots() }.value
            let vids = await Task.detached(priority: .userInitiated) { PhotoCleaner.videos(receivedOnly: false) }.value
            await MainActor.run { scanProgress = 0.2; scanLabel = "Looking for blurry & dark shots…" }
            let blurry = await Task.detached(priority: .userInitiated) {
                CleanupKit.blurryOrDark { p in Task { @MainActor in scanProgress = 0.2 + p * 0.4 } }
            }.value
            await MainActor.run { scanLabel = "Comparing look-alikes…" }
            // Wait for the background duplicate scan (bounded, so a huge library can't hang the button).
            var waited = 0
            while waited < 1200 {
                let running = await MainActor.run { () -> Bool in
                    scanProgress = 0.6 + CleanerIndex.shared.progress * 0.4
                    return CleanerIndex.shared.scanning
                }
                if !running { break }
                try? await Task.sleep(nanoseconds: 250_000_000); waited += 1
            }
            await MainActor.run {
                var out: [Category] = []
                let groups = index.duplicates ?? []
                if !groups.isEmpty { out.append(Category(id: "dupes", name: "Duplicate & look-alike photos", icon: "square.on.square", items: groups.flatMap { $0 }, groups: groups)) }
                if !vids.isEmpty { out.append(Category(id: "videos", name: "Large videos", icon: "film", items: vids.sorted { $0.bytes > $1.bytes })) }
                if !shots.isEmpty { out.append(Category(id: "shots", name: "Screenshots", icon: "iphone", items: shots)) }
                if !blurry.isEmpty { out.append(Category(id: "blurry", name: "Blurry & dark shots", icon: "cloud.fog", items: blurry)) }
                cats = out; scanned = true; scanning = false; scanProgress = 1
                HandyHaptics.light()
            }
        }
    }

    /// The background duplicate index finished (or changed) after our scan — refresh that card.
    private func refreshDuplicates() {
        let groups = index.duplicates ?? []
        cats.removeAll { $0.id == "dupes" }
        if !groups.isEmpty { cats.insert(Category(id: "dupes", name: "Duplicate & look-alike photos", icon: "square.on.square", items: groups.flatMap { $0 }, groups: groups), at: 0) }
    }

    private func openReview(_ c: Category) {
        reviewing = c.id; note = nil
        keepBest(c)   // sensible default: the best of each group / the newest is kept, the rest is pre-selected
    }

    /// Duplicates: keep the highest-resolution copy of each group. Other categories: keep the newest item.
    private func keepBest(_ c: Category) {
        var s = Set<String>()
        if let groups = c.groups {
            for g in groups {
                let best = g.max { ($0.asset.pixelWidth * $0.asset.pixelHeight) < ($1.asset.pixelWidth * $1.asset.pixelHeight) }
                for it in g where it.id != best?.id { s.insert(it.id) }
            }
        } else {
            let newest = c.items.max { ($0.asset.creationDate ?? .distantPast) < ($1.asset.creationDate ?? .distantPast) }
            for it in c.items where it.id != newest?.id { s.insert(it.id) }
        }
        selected = s
    }

    private func moveToTrash(_ c: Category) {
        let items = selectedItems
        let ids = Set(items.map { $0.id })
        let bytes = selectedBytes
        busy = true; note = nil
        Task {
            let ok = await PhotoCleaner.delete(items.map { $0.asset })   // iOS shows "Delete N items?" — that's the confirmation
            await MainActor.run {
                busy = false
                guard ok else { note = "Nothing was moved — you cancelled, or Photos said no."; return }
                CleanerIndex.shared.remove(ids: ids)
                if let i = cats.firstIndex(where: { $0.id == c.id }) {
                    cats[i].items.removeAll { ids.contains($0.id) }
                    if let g = cats[i].groups { cats[i].groups = g.map { $0.filter { !ids.contains($0.id) } }.filter { $0.count > 1 }; cats[i].items = (cats[i].groups ?? []).flatMap { $0 } }
                    if cats[i].items.isEmpty { cats.remove(at: i); reviewing = nil }
                }
                trashed.insert(Trashed(category: c.name, count: items.count, bytes: bytes, when: Date()), at: 0)
                selected = []
                note = "\(items.count) moved to Trash · about \(PhotoCleaner.format(bytes)) freed once Recently Deleted empties."
                HandyHaptics.success()
            }
        }
    }

    // MARK: Contacts

    private var emptyContacts: [ContactRec] { report.map { CleanupKit.emptyContacts($0) } ?? [] }
    private func groupKey(_ g: [ContactRec]) -> String { g.map { $0.id }.sorted().joined(separator: "|") }
    private var visibleGroups: [[ContactRec]] { (report?.duplicateGroups ?? []).filter { !dismissed.contains(groupKey($0)) } }

    @ViewBuilder private var contactsPanel: some View {
        if !contactsOK {
            EmptyState(icon: "person.2.fill", line: "Contacts needs access", sub: "To find duplicates and back up, it needs to read your contacts. Nothing is uploaded — it all stays on your phone.")
            Button { Task { contactsOK = await ContactsEngine.requestAccess(); if contactsOK { scanContacts() } } } label: { Label("Allow contacts access", systemImage: "lock.open").frame(maxWidth: .infinity) }.primaryButton()
        } else {
            if let backupURL {
                ShareLink(item: backupURL) { Label("Backup saved · share or keep the .vcf", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
            } else {
                Button { backup() } label: { HStack { if contactsBusy { ProgressView() }; Label("Back up all contacts (.vcf)", systemImage: "arrow.down.doc") }.frame(maxWidth: .infinity) }.secondaryButton().disabled(contactsBusy)
            }
            if contactsBusy && report == nil { HStack { ProgressView(); Text("Reading your contacts…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }
            if let r = report {
                let noName = r.incomplete.filter { !$0.hasName }.count, noNumber = r.incomplete.filter { !$0.hasNumber }.count
                HubSection("\(visibleGroups.count) likely duplicate\(visibleGroups.count == 1 ? "" : "s") · \(noName) with no name · \(noNumber) with no number")
                if visibleGroups.isEmpty && emptyContacts.isEmpty {
                    EmptyState(icon: "checkmark.seal", line: "Contacts are tidy.", sub: "\(r.total) contacts, no duplicates.")
                }
                ForEach(Array(visibleGroups.enumerated()), id: \.offset) { _, g in contactGroup(g) }
                if !emptyContacts.isEmpty {
                    Button { confirmEmpty = true } label: { Label("Also: remove \(emptyContacts.count) empty contact\(emptyContacts.count == 1 ? "" : "s")", systemImage: "person.crop.circle.badge.xmark").frame(maxWidth: .infinity) }.secondaryButton().disabled(contactsBusy)
                }
            }
            if let contactsError { Text(contactsError).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            HubNote("Everything runs on your phone; nothing is uploaded. A merge is permanent — iOS has no contacts trash — so a .vcf backup is made before the first change.")
        }
    }

    private func contactGroup(_ g: [ContactRec]) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(g.map { $0.hasName ? $0.name : "(no name)" }.joined(separator: " + ")).font(HandyFont.bodyStrong)
            let details = Array(Set(g.flatMap { $0.numbers + $0.emails })).sorted()
            if !details.isEmpty { Text(details.joined(separator: " · ")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            let from = Array(Set(g.compactMap { sources[$0.id] })).sorted()
            Text("from " + (from.isEmpty ? "this phone" : from.joined(separator: ", "))).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            FlowLayout(spacing: 6) {
                HubChip("Merge into one", selected: false) { pendingMerge = g }
                HubChip("Keep both", selected: false) { dismissed.insert(groupKey(g)) }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
    }

    private func scanContacts() {
        contactsBusy = true; contactsError = nil
        Task {
            let r = await Task.detached { ContactsEngine.scan() }.value
            let s = await Task.detached { CleanupKit.contactSources() }.value
            await MainActor.run { report = r; sources = s; contactsBusy = false }
        }
    }

    /// One backup per session, made before the first merge/remove (or on demand).
    private func ensureBackup() async -> Bool {
        if backupURL != nil { return true }
        guard let url = try? await Task.detached { try ContactsEngine.exportVCard() }.value else { return false }
        await MainActor.run { backupURL = url }
        return true
    }
    private func backup() {
        contactsBusy = true
        Task { let ok = await ensureBackup(); await MainActor.run { contactsBusy = false; if ok { HandyHaptics.success() } else { contactsError = "Couldn't create the backup. Try again." } } }
    }
    private func merge(_ g: [ContactRec]) {
        contactsBusy = true; contactsError = nil
        Task {
            guard await ensureBackup() else { await MainActor.run { contactsBusy = false; contactsError = "Couldn't back up first, so nothing was merged." }; return }
            do { try await Task.detached { try ContactsEngine.merge(g) }.value; await MainActor.run { HandyHaptics.success(); scanContacts() } }
            catch { await MainActor.run { contactsBusy = false; contactsError = "Couldn't merge those contacts." } }
        }
    }
    private func removeEmpty() {
        let ids = emptyContacts.map { $0.id }
        contactsBusy = true; contactsError = nil
        Task {
            guard await ensureBackup() else { await MainActor.run { contactsBusy = false; contactsError = "Couldn't back up first, so nothing was removed." }; return }
            do { try await Task.detached { try CleanupKit.deleteContacts(ids: ids) }.value; await MainActor.run { HandyHaptics.success(); scanContacts() } }
            catch { await MainActor.run { contactsBusy = false; contactsError = "Couldn't remove those contacts." } }
        }
    }

    // MARK: Trash

    private var trashPanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HubNote("Trash is Photos' own Recently Deleted album. Anything moved there stays 30 days, then iOS deletes it for good — restore or delete sooner from inside Photos.")
            Button { openPhotos() } label: { Label("Open Photos › Recently Deleted", systemImage: "arrow.up.forward.app").frame(maxWidth: .infinity) }.primaryButton()
            HubNote("In Photos: Albums → scroll to Utilities → Recently Deleted (Face ID to unlock) → Select → Recover or Delete.")
            if trashed.isEmpty {
                EmptyState(icon: "trash", line: "Nothing moved to Trash this session.", sub: "Scan on the Space tab to find what you can free up.")
            } else {
                let total = trashed.reduce(Int64(0)) { $0 + $1.bytes }
                let count = trashed.reduce(0) { $0 + $1.count }
                HubSection("\(count) items · about \(PhotoCleaner.format(total)) · this session")
                ForEach(trashed) { t in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.category).font(HandyFont.bodyStrong)
                            Text(t.when.formatted(date: .omitted, time: .shortened)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                        }
                        Spacer()
                        Text("\(t.count) · \(PhotoCleaner.format(t.bytes))").font(HandyFont.caption).monospacedDigit().foregroundStyle(HandyColor.textSecondary)
                    }.cardStyle(padding: HandySpacing.s12)
                }
            }
        }
    }

    private func openPhotos() {
        if let url = URL(string: "photos-redirect://") { UIApplication.shared.open(url) }
    }
}

/// Real photo-library thumbnail with a selection check and a size badge (same geometry as Cleaner's).
private struct CleanupThumb: View {
    let asset: PHAsset
    let selected: Bool
    let label: String
    let tap: () -> Void
    @State private var img: UIImage?
    @State private var unavailable = false

    var body: some View {
        Button(action: tap) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let img { Image(uiImage: img).resizable().scaledToFill() }
                    else if unavailable {
                        Rectangle().fill(HandyColor.surface).overlay(VStack(spacing: 4) { Image(systemName: "icloud.and.arrow.down").font(.system(size: 18)); Text("In iCloud").font(HandyFont.micro) }.foregroundStyle(HandyColor.textSecondary))
                    } else { Rectangle().fill(HandyColor.surface) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(selected ? HandyColor.accent : Color.clear, lineWidth: 3))
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 3) {
                        if asset.mediaType == .video { Image(systemName: "play.fill").font(.system(size: 8)) }
                        Text(label).font(.system(size: 10, weight: .medium))
                    }.foregroundStyle(.white).padding(.horizontal, 5).padding(.vertical, 2).background(.black.opacity(0.55), in: Capsule()).padding(4)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.system(size: 20)).foregroundStyle(selected ? HandyColor.accent : .white).padding(5).shadow(color: .black.opacity(0.4), radius: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selected ? "Selected, \(label)" : label)
        .task {
            let o = PHImageRequestOptions(); o.deliveryMode = .opportunistic; o.resizeMode = .fast; o.isNetworkAccessAllowed = false
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFill, options: o) { im, info in
                if let im { img = im; unavailable = false }
                else if (info?[PHImageErrorKey] != nil) || (info?[PHImageResultIsInCloudKey] as? Bool == true) { unavailable = true }
            }
        }
    }
}
