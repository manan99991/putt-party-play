import SwiftUI
import Photos

/// Memory — ask your own photos anything. Your camera roll is full of screenshots you saved so you'd
/// have them — Wi-Fi passwords, codes, confirmations, the parking spot — and then can't find. This
/// reads them once, on device, and lets you just ask. Private, offline, free.
struct MemoryView: View {
    @EnvironmentObject var store: StoreManager
    @StateObject private var index = MemoryIndex()
    @State private var query = ""
    @State private var authorized = false
    @State private var checkedAuth = false
    @State private var results: [MemoryEngine.Entry] = []
    @State private var aiAnswer: String?
    @State private var answering = false
    @State private var searched = false
    @State private var viewing: MemoryEngine.Entry?

    var body: some View {
        ToolPage(title: "Memory", subtitle: "Ask your own screenshots anything — the Wi-Fi password, a confirmation number, where you parked. Read on your phone, never uploaded.") {
            HowTo("memory", [
                "Tap Index to read your screenshots once — it stays on your phone.",
                "Ask in plain words: \u{201C}the Wi-Fi password I saved\u{201D}, \u{201C}my parking spot\u{201D}.",
                "You get the answer, plus the screenshot it came from.",
            ])

            if !authorized {
                permissionCard
            } else {
                searchBar
                if index.indexing { indexingCard }
                else if index.entries.isEmpty { emptyIndexCard }

                if answering { HStack { ProgressView(); Text("Looking through your screenshots…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }
                if let aiAnswer, !aiAnswer.isEmpty {
                    answerCard(aiAnswer)
                    if !results.isEmpty { Text("Pulled from your screenshots below — tap any to open the original.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                }
                if searched && results.isEmpty && !answering {
                    Text("Nothing matched that. Try the words that were actually on the screenshot, or re-index if it's recent.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                ForEach(results) { e in resultRow(e) }

                if !index.entries.isEmpty {
                    HStack {
                        Text("\(index.entries.count) screenshots read\(index.indexedAt != nil ? "" : "")").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                        Spacer()
                        Button { index.refresh() } label: { Label("Re-index", systemImage: "arrow.clockwise") }.textButton().disabled(index.indexing)
                    }
                }
            }
            Text("Reads the text in your screenshots with on-device OCR. For a one-line answer in plain language, Apple Intelligence (iPhone 15 Pro or newer) extracts it; otherwise you get the best-matching screenshot.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .task { await checkAuth() }
        .sheet(item: $viewing) { e in MemoryImageViewer(entry: e) }
    }

    // MARK: states

    private var permissionCard: some View {
        VStack(spacing: HandySpacing.s16) {
            EmptyState(icon: "photo.on.rectangle.angled", line: "Memory reads your screenshots", sub: "It needs access to your photos to find things in them. Nothing is uploaded — it all stays on your phone.")
            Button { Task { await requestAccess() } } label: { Label("Allow photo access", systemImage: "lock.open").frame(maxWidth: .infinity) }.primaryButton()
        }
    }

    private var searchBar: some View {
        HStack(spacing: HandySpacing.s8) {
            Image(systemName: "magnifyingglass").foregroundStyle(HandyColor.textSecondary)
            TextField("Ask your screenshots…", text: $query).submitLabel(.search).onSubmit { runSearch() }
            if !query.isEmpty { Button { query = ""; results = []; aiAnswer = nil; searched = false } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(HandyColor.textSecondary) }.buttonStyle(.plain) }
            Button { runSearch() } label: { Text("Ask").font(HandyFont.bodyStrong) }.disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || index.entries.isEmpty)
        }
        .padding(HandySpacing.s12)
        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }

    private var indexingCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack { ProgressView(); Text("Reading your screenshots…").font(HandyFont.body) }
            ProgressView(value: index.progress).tint(HandyColor.accent)
            Text("One-time per screenshot — after this it's instant.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }.cardStyle()
    }

    private var emptyIndexCard: some View {
        VStack(spacing: HandySpacing.s12) {
            Text("Read your screenshots once so you can search them. It happens on your phone and is cached, so it's only slow the first time.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
            Button { index.refresh() } label: { Label("Index my screenshots", systemImage: "sparkles").frame(maxWidth: .infinity) }.primaryButton()
        }.cardStyle()
    }

    private func answerCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(spacing: 6) { Image(systemName: "sparkles").foregroundStyle(HandyColor.accent); Text("Answer").font(HandyFont.bodyStrong) }
            Text(text).font(HandyFont.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            Button { UIPasteboard.general.string = text; ClipStore.add(text); HandyHaptics.success() } label: { Label("Copy", systemImage: "doc.on.doc") }.compactButton()
        }.cardStyle()
    }

    private func resultRow(_ e: MemoryEngine.Entry) -> some View {
        HStack(alignment: .top, spacing: HandySpacing.s12) {
            Button { viewing = e } label: {
                HStack(alignment: .top, spacing: HandySpacing.s12) {
                    MemoryThumb(id: e.id)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(MemoryEngine.bestLine(for: query, in: e)).font(HandyFont.body).foregroundStyle(HandyColor.textPrimary).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                        Text(MemoryEngine.dateString(e.date)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    }
                    Image(systemName: "chevron.right").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }.buttonStyle(.plain)
            Button { UIPasteboard.general.string = MemoryEngine.bestLine(for: query, in: e); ClipStore.add(MemoryEngine.bestLine(for: query, in: e)); HandyHaptics.success() } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain).foregroundStyle(HandyColor.accent)
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
        if authorized, index.entries.isEmpty, !index.indexing, Launch.sample == false { /* wait for explicit Index tap */ }
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
        Task { @MainActor in
            aiAnswer = await MemoryEngine.answer(question: q, from: results)
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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                        ProgressView().frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        VStack(spacing: HandySpacing.s8) {
                            Image(systemName: "photo.badge.exclamationmark").font(.system(size: 32)).foregroundStyle(HandyColor.textSecondary)
                            Text("This screenshot isn't in your photo library anymore. The text it was read from is below.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity, minHeight: 200)
                    }
                    if !entry.text.isEmpty {
                        Text("Text read from this screenshot").font(HandyFont.bodyStrong)
                        Text(entry.text).font(HandyFont.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(HandySpacing.s16)
            }
            .background(HandyColor.bg)
            .navigationTitle(MemoryEngine.dateString(entry.date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { UIPasteboard.general.string = entry.text; ClipStore.add(entry.text); HandyHaptics.success() } label: { Image(systemName: "doc.on.doc") }
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
