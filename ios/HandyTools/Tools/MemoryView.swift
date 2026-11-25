import SwiftUI
import Photos

/// Memory — ask your own photos anything. Your camera roll is full of screenshots you saved so you'd
/// have them — Wi-Fi passwords, codes, confirmations, the parking spot — and then can't find. This
/// reads them once, on device, and lets you just ask. Private, offline, free.
struct MemoryView: View {
    static let collections = ["Wi-Fi password", "Confirmation number", "Where I parked", "Flight", "Tracking number", "Receipt", "Address", "Gift card code", "Recipe", "Ticket"]
    @State private var counts: [String: Int] = [:]
    @EnvironmentObject var store: StoreManager
    @ObservedObject private var index = MemoryIndex.shared
    @State private var query = ""
    @State private var authorized = false
    @State private var checkedAuth = false
    @State private var results: [MemoryEngine.Match] = []
    @State private var aiAnswer: String?
    @State private var answering = false
    @State private var searched = false
    @State private var viewing: MemoryEngine.Entry?

    var body: some View {
        ToolPage(title: "Search My Photos", subtitle: "Ask your own photos and videos anything — by what they say (a Wi-Fi password, a confirmation number, where you parked) or what they show (you in a red dress, your dog at the beach). Read on your phone, never uploaded.") {
            HowTo("memory", [
                "Build the index once — it reads your phone's own photos on-device; a big library fills in as you watch.",
                "Ask in plain words: \u{201C}the Wi-Fi password I saved\u{201D}, \u{201C}me in a red dress\u{201D}, \u{201C}my parking spot\u{201D}.",
                "You get the answer or the matching photos, each with why it matched.",
            ])

            if !authorized {
                permissionCard
            } else {
                searchBar
                if query.isEmpty, !index.entries.isEmpty {
                    // The things people actually screenshot and then can't find — one tap to ask.
                    // Collections that fill themselves: each one shows how many of your pictures it holds.
                    HandyFlow(spacing: HandySpacing.s8) {
                        ForEach(Self.collections, id: \.self) { q in
                            HChip(text: counts[q].map { $0 > 0 ? "\(L(q)) · \($0 >= 99 ? "99+" : String($0))" : L(q) } ?? L(q), selected: false) { query = L(q); runSearch() }
                        }
                    }
                    .accessibilityIdentifier("memory-suggestions")
                    .task(id: index.entries.count) {
                        let entries = index.entries
                        let asks = Self.collections.map { ($0, L($0)) }
                        counts = await Task.detached(priority: .utility) {
                            Dictionary(uniqueKeysWithValues: asks.map { ($0.0, MemoryEngine.search($0.1, in: entries, top: 99).count) })
                        }.value
                    }
                }
                if index.indexing { indexingCard }
                else if index.entries.isEmpty { emptyIndexCard }

                if answering { HStack { BusySpinner(); Text(L("Looking through your photos…")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }
                if let aiAnswer, !aiAnswer.isEmpty {
                    answerCard(aiAnswer)
                    if !results.isEmpty { Text(L("Pulled from your photos below — tap any to open the original.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                }
                if searched && results.isEmpty && !answering {
                    Text(L("Nothing matched that. Try different words — what the photo shows (a colour, an object) or text that was on it — or re-index if it's recent.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                ForEach(results) { m in resultRow(m) }

                if !index.entries.isEmpty {
                    HStack {
                        Text(index.indexing ? "Indexing \(index.done) of \(index.total)… you can search what's ready" : "\(index.entries.count) photos & videos indexed")
                            .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                        Spacer()
                        Button { index.refresh() } label: { Label(L("Re-index"), systemImage: "arrow.clockwise") }.textButton().disabled(index.indexing)
                    }
                }
            }
            Text(L("Reads the text and recognises what's in your photos — objects and colours — on device. For a one-line answer in plain language, Apple Intelligence (iPhone 15 Pro or newer) extracts it; otherwise you get the best-matching photos, each with why it matched.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .task { await checkAuth() }
        .onDisappear { index.leftTheTool() }
        .sheet(item: $viewing) { e in MemoryImageViewer(entry: e) }
    }

    // MARK: states

    private var permissionCard: some View {
        VStack(spacing: HandySpacing.s16) {
            EmptyState(icon: "photo.on.rectangle.angled", line: "Memory reads your photos", sub: "It needs access to your photos to find things in them. Nothing is uploaded — it all stays on your phone.")
            Button {
                if Permission.photosDenied { Permission.openSettings() }
                else { Task { await requestAccess() } }
            } label: { Label(Permission.photosDenied ? "Open Settings to allow photos" : "Allow photo access",
                             systemImage: Permission.photosDenied ? "gearshape" : "lock.open").frame(maxWidth: .infinity) }.primaryButton()
        }
    }

    private var searchBar: some View {
        HStack(spacing: HandySpacing.s8) {
            Image(systemName: "magnifyingglass").foregroundStyle(HandyColor.textSecondary)
            TextField(L("Ask your photos anything"), text: $query).submitLabel(.search).onSubmit { runSearch() }
            if !query.isEmpty { Button { query = ""; results = []; aiAnswer = nil; searched = false } label: { Image(systemName: "xmark.circle.fill").accessibilityLabel(L("Clear")).foregroundStyle(HandyColor.textSecondary) }.buttonStyle(.plain) }
            Button { runSearch() } label: { Text(L("Ask")).font(HandyFont.bodyStrong) }.disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || index.entries.isEmpty)
        }
        .padding(HandySpacing.s12)
        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }

    private var indexingCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack { BusySpinner(); Text(index.total > 0 ? "Building your photo index — \(index.done) of \(index.total)" : "Building your photo index…").font(HandyFont.body) }
            ProgressView(value: index.progress).tint(HandyColor.accent)
            Text(L("One time only, on your phone. Search what's ready now. Leave whenever you like — it carries on quietly, and finishes while your phone charges. After that, only new photos are read.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }.cardStyle()
    }

    private var emptyIndexCard: some View {
        VStack(spacing: HandySpacing.s12) {
            Text(L("Build a private index of your whole photo library — it reads each photo once, on your phone, so you can ask anything. A big library fills in gradually and you can search as it goes; after that it's instant and keeps itself up to date.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
            Button { index.refresh() } label: { Label(L("Build my photo index"), systemImage: "sparkles").frame(maxWidth: .infinity) }.primaryButton()
        }.cardStyle()
    }

    private func answerCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(spacing: 6) { Image(systemName: "sparkles").foregroundStyle(HandyColor.accent); Text(L("Answer")).font(HandyFont.bodyStrong) }
            Text(text).font(HandyFont.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: HandySpacing.s8) {
                Button { Copier.copy(text); ClipStore.add(text) } label: { Label(L("Copy"), systemImage: "doc.on.doc") }.compactButton()
                ShareLink(item: text) { Label(L("Share"), systemImage: "square.and.arrow.up") }.compactButton()
            }
        }.cardStyle()
    }

    private func rowText(_ e: MemoryEngine.Entry) -> String {
        let line = MemoryEngine.bestLine(for: query, in: e).trimmingCharacters(in: .whitespacesAndNewlines)
        if !line.isEmpty { return line }
        // Visual-only match (no text on the photo): describe what's in it.
        let bits = ((e.colors ?? []) + (e.labels ?? [])).prefix(4)
        return bits.isEmpty ? ((e.isScreenshot ?? false) ? "Screenshot" : "Photo") : "Shows " + bits.joined(separator: ", ")
    }

    private func resultRow(_ m: MemoryEngine.Match) -> some View {
        let e = m.entry
        return VStack(alignment: .leading, spacing: 6) {
            // Why this photo surfaced — shown above it, so the match is never a mystery.
            Label(m.reason, systemImage: "magnifyingglass").font(HandyFont.micro).foregroundStyle(HandyColor.accent).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            HStack(alignment: .top, spacing: HandySpacing.s12) {
                Button { viewing = e } label: {
                    HStack(alignment: .top, spacing: HandySpacing.s12) {
                        MemoryThumb(id: e.id)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rowText(e)).font(HandyFont.body).foregroundStyle(HandyColor.textPrimary).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                            Text(MemoryEngine.dateString(e.date)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                        }
                        Image(systemName: "chevron.right").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                }.buttonStyle(.plain)
                Button { let line = MemoryEngine.bestLine(for: query, in: e); Copier.copy(line); ClipStore.add(line) } label: { Image(systemName: "doc.on.doc").accessibilityLabel(L("Copy")) }.buttonStyle(.plain).foregroundStyle(HandyColor.accent)
            }
        }
        .padding(HandySpacing.s12)
        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }

    // MARK: logic

    private func checkAuth() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorized = (status == .authorized || status == .limited)
        checkedAuth = true
        // First time: wait for the explicit "Build index" tap (consent). If an index already exists,
        // quietly catch up any photos taken since last time so this open is instant and self-maintaining.
        if authorized, !index.entries.isEmpty || index.indexing, Launch.sample == false { index.catchUpIfNeeded() }
    }

    private func requestAccess() async {
        let status = await PhotoCleaner.authorize()
        authorized = (status == .authorized || status == .limited)
    }

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        searched = true; aiAnswer = nil
        results = MemoryEngine.search(q, in: index.entries)
        guard AIEngine.isAvailable, !results.isEmpty else { return }
        answering = true
        let entries = results.map { $0.entry }
        Task { @MainActor in
            aiAnswer = await MemoryEngine.answer(question: q, from: entries)
            answering = false
        }
    }
}

/// Async thumbnail for a result row, loaded from the photo library by asset id.
private struct MemoryThumb: View {
    let id: String
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Rectangle().fill(HandyColor.accentSoft).overlay(Image(systemName: "photo").foregroundStyle(HandyColor.accent)) }
        }
        .frame(width: 54, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)).contentShape(Rectangle())
        .task(id: id) { image = await MemoryEngine.thumbnail(id: id) }
    }
}

/// Full view of the source screenshot an answer came from: the image at the top (scaled to fit,
/// scroll to pan a tall screenshot), the exact text that was read from it underneath, and a copy
/// button. Loads the full-resolution original, or the cached thumbnail if it's no longer in the
/// library.
private struct MemoryImageViewer: View {
    let entry: MemoryEngine.Entry
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s16) {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    } else if loading {
                        BusySpinner().frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        VStack(spacing: HandySpacing.s8) {
                            Image(systemName: "photo.badge.exclamationmark").font(.system(size: 32)).foregroundStyle(HandyColor.textSecondary)
                            Text(L("This photo isn't in your library anymore. Anything read from it is below.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity, minHeight: 200)
                    }
                    if !entry.text.isEmpty {
                        Text(L("Text read from this photo")).font(HandyFont.bodyStrong)
                        Text(entry.text).font(HandyFont.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        let bits = (entry.colors ?? []) + (entry.labels ?? [])
                        if !bits.isEmpty {
                            Text(L("What's in this photo")).font(HandyFont.bodyStrong)
                            Text(bits.prefix(10).joined(separator: ", ")).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }.padding(HandySpacing.s16)
            }
            .background(HandyColor.bg)
            .navigationTitle(MemoryEngine.dateString(entry.date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { Copier.copy(entry.text); ClipStore.add(entry.text) } label: { Image(systemName: "doc.on.doc").accessibilityLabel(L("Copy")) }
                        .disabled(entry.text.isEmpty)
                }
            }
        }
        .task {
            image = await MemoryEngine.fullImage(id: entry.id)
            loading = false
        }
    }
}
