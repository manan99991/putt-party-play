import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

/// Fit It — hit an exact size limit. Photo, video, or PDF in; pick the limit the portal / email /
/// form demands; get a copy that lands just under it. The one thing no stock share sheet can do.
struct FitItView: View {
    @EnvironmentObject var store: StoreManager

    private enum Source { case image(UIImage), video(URL), pdf(Data) }
    private enum Output { case data(Data, ext: String), file(URL) }

    @State private var pickedItem: PhotosPickerItem?
    @State private var showFiles = false
    @State private var source: Source?
    @State private var sourceName = ""
    @State private var sourceBytes = 0
    @State private var targetBytes = 2_000_000
    @State private var customValue = ""
    @State private var customUnitMB = true
    @State private var output: Output?
    @State private var outputBytes = 0
    @State private var working = false
    @State private var errorText: String?
    @State private var fitNote: String?   // "smallest we could do" when a video can't reach the target

    private var overQuota: Bool { !Usage.hasRoom("fitit", limit: Limits.freeFitPerDay) }

    /// Size targets to offer. A video can never reach the tiny photo-upload limits (50–500 KB), so
    /// those are hidden when the source is a video — don't offer a target that always fails.
    private var availablePresets: [(label: String, bytes: Int)] {
        if case .video = source { return SizeTarget.presets.filter { $0.bytes >= 1_000_000 } }
        return SizeTarget.presets
    }

    var body: some View {
        ToolPage(title: "Fit It", subtitle: "Shrink a photo, video, or PDF to land just under the size limit you need.") {
            HowTo("fitit", [
                "Pick a photo or PDF that is too big to send.",
                "Choose the size it must come under, or type a custom limit.",
                "Fit It shrinks it just under the limit and keeps it sharp — then share.",
            ])
            if source == nil {
                PhotosPicker(selection: $pickedItem, matching: .any(of: [.images, .videos])) {
                    Label("Choose a photo or video", systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity)
                }.secondaryButton()
                Button { showFiles = true } label: { Label("Choose a PDF", systemImage: "doc.fill").frame(maxWidth: .infinity) }.secondaryButton()
                Text("Typical limits: email 25 MB, most portals 2 MB, government photo uploads 50–200 KB.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            } else {
                sourceCard
                targetPicker

                if !store.isPremium { QuotaChip(name: "fitit", limit: Limits.freeFitPerDay).environmentObject(store) }
                if overQuota { LimitReachedBanner(message: "You've used today's \(Limits.freeFitPerDay) free fits.") }

                Button { run() } label: {
                    HStack { if working { ProgressView().tint(.white) }; Text(working ? "Fitting…" : "Fit under \(SizeTarget.format(targetBytes))") }.frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || overQuota || targetBytes <= 0)

                HStack {
                    PhotosPicker(selection: $pickedItem, matching: .any(of: [.images, .videos])) { Label("Different photo/video", systemImage: "photo") }.textButton()
                    Button { showFiles = true } label: { Label("Different PDF", systemImage: "doc") }.textButton()
                    Spacer()
                }
            }

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            if output != nil { resultCard }
        }
        .onChange(of: pickedItem) { _, item in loadPhotoItem(item) }
        .onAppear { if Launch.sample, source == nil { let img = SampleAssets.photo(); source = .image(img); sourceName = "Sample photo"; sourceBytes = img.jpegData(compressionQuality: 0.95)?.count ?? 0; targetBytes = 200_000 } }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf]) { res in
            if case .success(let url) = res { loadPDF(url) }
        }
    }

    // MARK: pieces

    private var sourceCard: some View {
        HStack(spacing: HandySpacing.s12) {
            Image(systemName: sourceIcon).font(.system(size: 22)).foregroundStyle(HandyColor.accent).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(sourceName).font(HandyFont.bodyStrong).lineLimit(1)
                Text("Now \(SizeTarget.format(sourceBytes))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Spacer()
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private var sourceIcon: String {
        switch source { case .image: return "photo"; case .video: return "film"; case .pdf: return "doc.fill"; case .none: return "questionmark" }
    }

    private var targetPicker: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text("Must be under").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(availablePresets, id: \.bytes) { p in
                    HChip(text: p.label, selected: targetBytes == p.bytes && customValue.isEmpty) { targetBytes = p.bytes; customValue = ""; errorText = nil }
                }
            }
            HStack(spacing: HandySpacing.s8) {
                TextField("Custom", text: $customValue)
                    .keyboardType(.decimalPad)
                    .padding(HandySpacing.s12)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .onChange(of: customValue) { _, _ in applyCustom() }
                Picker("Unit", selection: $customUnitMB) { Text("MB").tag(true); Text("KB").tag(false) }
                    .pickerStyle(.segmented).frame(width: 120)
                    .onChange(of: customUnitMB) { _, _ in applyCustom() }
            }
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s12) {
                Image(systemName: fitNote == nil ? "checkmark.circle.fill" : "exclamationmark.circle.fill").foregroundStyle(fitNote == nil ? HandyColor.success : HandyColor.accent).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(fitNote == nil ? "Fits — \(SizeTarget.format(outputBytes))" : "Smallest — \(SizeTarget.format(outputBytes))").font(HandyFont.bodyStrong)
                    Text("Down from \(SizeTarget.format(sourceBytes)) · \(savingsText)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    if let fitNote { Text(fitNote).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
                }
                Spacer()
            }
            if case .pdf = source {
                Text("Pages are flattened to reach the size, so text won't be selectable in the copy.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            shareButton
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    private var savingsText: String {
        guard sourceBytes > 0 else { return "" }
        let pct = Int((1 - Double(outputBytes) / Double(sourceBytes)) * 100)
        return "\(max(0, pct))% smaller"
    }

    @ViewBuilder private var shareButton: some View {
        switch output {
        case .data(let d, let ext) where ext == "pdf":
            ShareLink(item: PDFFile(data: d), preview: SharePreview("Fitted PDF")) { Label("Save or share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        case .data(let d, _):
            ShareLink(item: JPEGFile(data: d), preview: SharePreview("Fitted photo")) { Label("Save or share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        case .file(let url):
            ShareLink(item: url) { Label("Save or share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        case .none:
            EmptyView()
        }
    }

    // MARK: loading

    private func reset() { output = nil; outputBytes = 0; errorText = nil; fitNote = nil }

    private func loadPhotoItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        reset()
        Task {
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                if let movie = try? await item.loadTransferable(type: MovieImport.self) {
                    await MainActor.run {
                        source = .video(movie.url); sourceName = "Video"; sourceBytes = SizeTarget.fileSize(movie.url) ?? 0
                        if targetBytes < 1_000_000 { targetBytes = 2_000_000 }   // a photo-size target can't fit a video
                    }
                }
            } else if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                await MainActor.run { source = .image(img); sourceName = "Photo"; sourceBytes = d.count }
            }
        }
    }

    private func loadPDF(_ url: URL) {
        reset()
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        guard let d = try? Data(contentsOf: url) else { errorText = "Couldn't read that PDF."; return }
        source = .pdf(d); sourceName = url.lastPathComponent; sourceBytes = d.count
    }

    private func applyCustom() {
        let cleaned = customValue.replacingOccurrences(of: ",", with: ".")
        guard let v = Double(cleaned), v > 0 else { return }
        targetBytes = Int(v * (customUnitMB ? 1_000_000 : 1_000))
        errorText = nil
    }

    // MARK: run

    private func run() {
        guard let source else { return }
        guard Usage.hasRoom("fitit", limit: Limits.freeFitPerDay) else { return }   // gate only — charge on success
        working = true; errorText = nil; fitNote = nil; output = nil
        let target = targetBytes
        Task { @MainActor in
            defer { working = false }
            switch source {
            case .image(let img):
                guard let d = await SizeTarget.image(img, targetBytes: target) else { errorText = "Couldn't get this photo under \(SizeTarget.format(target)) without ruining it. Try a slightly larger limit."; return }
                output = .data(d, ext: "jpg"); outputBytes = d.count
            case .pdf(let data):
                guard let d = await SizeTarget.pdf(data, targetBytes: target) else { errorText = "Couldn't get this PDF under \(SizeTarget.format(target)). Try a larger limit or fewer pages."; return }
                output = .data(d, ext: "pdf"); outputBytes = d.count
            case .video(let url):
                // Best-effort: always hand back the smallest we can make, and say so if it's still over.
                guard let r = await SizeTarget.videoBestEffort(url: url, targetBytes: target) else { errorText = "Couldn't process this video — it may be DRM-protected or damaged."; return }
                output = .file(r.url); outputBytes = SizeTarget.fileSize(r.url) ?? 0
                if !r.fits { fitNote = "Smallest without wrecking it. To get under \(SizeTarget.format(target)), trim it shorter first." }
            }
            _ = Usage.use("fitit", limit: Limits.freeFitPerDay)   // only now, on a real result
            HandyHaptics.success()
        }
    }
}

