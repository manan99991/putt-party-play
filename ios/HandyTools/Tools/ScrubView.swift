import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// Privacy Scrubber — see what a photo gives away, strip it, and black out faces / text / anything
/// you draw a box around. Redactions are permanent by design: solid blocks + a fresh encode, never a
/// blur that can be reversed.
struct ScrubView: View {
    @EnvironmentObject var store: StoreManager

    private struct Box: Identifiable { let id = UUID(); let rect: CGRect; let kind: Kind; var on: Bool
        enum Kind { case face, text, manual } }

    @State private var pickedItem: PhotosPickerItem?
    @State private var original: UIImage?
    @State private var originalData: Data?
    @State private var meta = Scrubber.Metadata()
    @State private var mapImage: UIImage?
    @State private var boxes: [Box] = []
    @State private var detecting = false
    @State private var drawing: CGRect?
    @State private var result: Data?
    @State private var working = false
    @State private var errorText: String?
    @State private var videoInURL: URL?
    @State private var videoOutURL: URL?
    @State private var videoWorking = false
    @State private var videoProgress = 0.0

    private var overQuota: Bool { !Usage.hasRoom("scrub", limit: Limits.freeScrubPerDay) }
    private var faceCount: Int { boxes.filter { $0.kind == .face }.count }
    private var textCount: Int { boxes.filter { $0.kind == .text }.count }

    var body: some View {
        ToolPage(title: "Privacy Scrubber", subtitle: "Strip hidden location data and black out faces or text — in a photo or a video, permanently.") {
            HowTo("scrub", [
                "Pick a photo or video to clean before you share it.",
                "It strips location and camera data and auto-selects faces plus personal text — plates, phone numbers, emails, IDs.",
                "Save or share the scrubbed copy — your original stays untouched.",
            ])
            if original == nil && videoInURL == nil {
                PhotosPicker(selection: $pickedItem, matching: .any(of: [.images, .videos])) {
                    Label("Choose a photo or video", systemImage: "photo").frame(maxWidth: .infinity)
                }.secondaryButton()
                Text("Blur can be undone. Our blocks can't — the pixels underneath are gone in the copy.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }

            if let vurl = videoInURL { videoPanel(vurl) }

            if let original {
                metadataCard
                canvas(original)
                controls
                PhotosPicker(selection: $pickedItem, matching: .any(of: [.images, .videos])) {
                    Label("Choose a different photo or video", systemImage: "photo.on.rectangle.angled")
                }.textButton()
            }

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            if let result {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Label("Clean copy ready — no location, no metadata, redactions permanent.", systemImage: "checkmark.shield.fill")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                    ShareLink(item: JPEGFile(data: result), preview: SharePreview("Clean copy")) {
                        Label("Save or share the clean copy", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }.primaryButton()
                }
            }
        }
        .onAppear { if Launch.sample, original == nil, let d = SampleAssets.photo().jpegData(compressionQuality: 0.9) { originalData = d; original = UIImage(data: d); meta = Scrubber.metadata(in: d); if let img = original { let f = Scrubber.detect(img); boxes = f.faces.map { Box(rect: $0, kind: .face, on: true) } + f.text.map { Box(rect: $0.rect, kind: .text, on: $0.personal) } } } }
        .onChange(of: pickedItem) { _, item in load(item) }
        .task(id: meta.coordinate?.latitude) {
            guard let c = meta.coordinate else { mapImage = nil; return }
            mapImage = await Scrubber.mapSnapshot(c)
        }
    }

    // MARK: pieces

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            if meta.hasGPS {
                Label("This photo contains your location", systemImage: "location.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.danger)
                if let mapImage {
                    Image(uiImage: mapImage).resizable().aspectRatio(contentMode: .fill).frame(height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                }
            } else {
                Label("No location data in this photo", systemImage: "location.slash").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success)
            }
            HStack(spacing: HandySpacing.s16) {
                if let d = meta.device { Label(d, systemImage: "camera").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                if let t = meta.taken { Label(t, systemImage: "calendar").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            }
            Text("All of this is removed from the clean copy.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private func canvas(_ img: UIImage) -> some View {
        GeometryReader { geo in
            let fit = fitRect(image: img.size, in: geo.size)
            ZStack(alignment: .topLeading) {
                Image(uiImage: img).resizable().scaledToFit().frame(width: geo.size.width, height: geo.size.height)
                ForEach(boxes) { b in
                    let r = denorm(b.rect, fit)
                    Rectangle()
                        .fill(b.on ? Color.black.opacity(0.85) : Color.clear)
                        .overlay(Rectangle().stroke(b.on ? HandyColor.accent : HandyColor.textSecondary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: b.on ? [] : [4, 3])))
                        .frame(width: r.width, height: r.height)
                        .offset(x: r.minX, y: r.minY)
                        .onTapGesture { toggle(b.id) }
                }
                if let d = drawing {
                    let r = denorm(d, fit)
                    Rectangle().fill(Color.black.opacity(0.5)).overlay(Rectangle().stroke(HandyColor.accent, lineWidth: 1.5))
                        .frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY)
                }
                if detecting { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 6)
                .onChanged { v in drawing = normRect(from: v.startLocation, to: v.location, fit) }
                .onEnded { v in
                    let r = normRect(from: v.startLocation, to: v.location, fit)
                    if r.width > 0.01 && r.height > 0.01 { boxes.append(Box(rect: r, kind: .manual, on: true)) }
                    drawing = nil
                })
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text("Tap a box to toggle it. Drag on the photo to add your own.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HStack(spacing: HandySpacing.s8) {
                HChip(text: "Faces (\(faceCount))", selected: boxes.contains { $0.kind == .face && $0.on }) { setAll(.face, on: !boxes.contains { $0.kind == .face && $0.on }) }
                HChip(text: "Text (\(textCount))", selected: boxes.contains { $0.kind == .text && $0.on }) { setAll(.text, on: !boxes.contains { $0.kind == .text && $0.on }) }
                if boxes.contains(where: { $0.kind == .manual }) {
                    Button("Clear drawn") { boxes.removeAll { $0.kind == .manual } }.textButton().font(HandyFont.caption)
                }
                Spacer()
            }
            if !store.isPremium { QuotaChip(name: "scrub", limit: Limits.freeScrubPerDay).environmentObject(store) }
            if overQuota { LimitReachedBanner(message: "You've scrubbed today's \(Limits.freeScrubPerDay) free photos.") }
            Button { make() } label: {
                HStack {
                    if working { ProgressView().tint(.white) }
                    Label(boxes.contains { $0.on } ? "Redact & make clean copy" : "Make clean copy (strip data)", systemImage: "checkmark.shield")
                }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(overQuota || detecting || working)
        }
    }

    @ViewBuilder private func videoPanel(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label("Faces and personal text (plates, phone numbers, emails) are found and blacked out automatically across the whole clip, and location/metadata is stripped. Best-effort — check the result before you share.",
                  systemImage: "video.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            ResultPreview(kind: .videoURL(videoOutURL ?? url))
            if !store.isPremium { QuotaChip(name: "scrub", limit: Limits.freeScrubPerDay).environmentObject(store) }
            if overQuota { LimitReachedBanner(message: "You've scrubbed today's \(Limits.freeScrubPerDay) free files.") }
            if let out = videoOutURL {
                Label("Clean video ready — faces & personal text hidden, metadata stripped.", systemImage: "checkmark.shield.fill")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                ShareLink(item: out) { Label("Save or share the clean video", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
            } else {
                Button { scrubVideo(url) } label: {
                    HStack {
                        if videoWorking { ProgressView().tint(.white) }
                        Label(videoWorking ? "Scrubbing… \(Int(videoProgress * 100))%" : "Black out faces & personal info", systemImage: "checkmark.shield")
                    }.frame(maxWidth: .infinity)
                }.primaryButton().disabled(overQuota || videoWorking)
            }
            PhotosPicker(selection: $pickedItem, matching: .any(of: [.images, .videos])) {
                Label("Choose a different photo or video", systemImage: "photo.on.rectangle.angled")
            }.textButton()
        }
    }

    // MARK: geometry

    private func fitRect(image: CGSize, in c: CGSize) -> CGRect {
        let s = min(c.width / image.width, c.height / image.height)
        let w = image.width * s, h = image.height * s
        return CGRect(x: (c.width - w) / 2, y: (c.height - h) / 2, width: w, height: h)
    }
    private func denorm(_ r: CGRect, _ fit: CGRect) -> CGRect {
        CGRect(x: fit.minX + r.minX * fit.width, y: fit.minY + r.minY * fit.height, width: r.width * fit.width, height: r.height * fit.height)
    }
    private func normRect(from a: CGPoint, to b: CGPoint, _ fit: CGRect) -> CGRect {
        func n(_ p: CGPoint) -> CGPoint { CGPoint(x: min(max((p.x - fit.minX) / fit.width, 0), 1), y: min(max((p.y - fit.minY) / fit.height, 0), 1)) }
        let p = n(a), q = n(b)
        return CGRect(x: min(p.x, q.x), y: min(p.y, q.y), width: abs(p.x - q.x), height: abs(p.y - q.y))
    }

    // MARK: actions

    private func toggle(_ id: UUID) { if let i = boxes.firstIndex(where: { $0.id == id }) { boxes[i].on.toggle(); HandyHaptics.light() } }
    private func setAll(_ kind: Box.Kind, on: Bool) { for i in boxes.indices where boxes[i].kind == kind { boxes[i].on = on } }

    private func load(_ item: PhotosPickerItem?) {
        guard let item else { return }
        result = nil; errorText = nil; boxes = []; videoOutURL = nil
        Task {
            // Video → the automatic whole-clip scrub flow; photo → the box editor.
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                let m = try? await item.loadTransferable(type: MovieImport.self)
                await MainActor.run { original = nil; originalData = nil; meta = Scrubber.Metadata(); mapImage = nil; videoInURL = m?.url }
                return
            }
            guard let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) else { return }
            await MainActor.run {
                videoInURL = nil
                originalData = d; original = img.normalizedUp(); meta = Scrubber.metadata(in: d); detecting = true
            }
            let found = Scrubber.detect(img)
            await MainActor.run {
                boxes = found.faces.map { Box(rect: $0, kind: .face, on: true) } + found.text.map { Box(rect: $0.rect, kind: .text, on: $0.personal) }
                detecting = false
            }
        }
    }

    private func scrubVideo(_ url: URL) {
        guard Usage.hasRoom("scrub", limit: Limits.freeScrubPerDay) else { return }
        videoWorking = true; videoProgress = 0; errorText = nil
        Task { @MainActor in
            let out = await Scrubber.scrubVideo(url, progress: { f in Task { @MainActor in videoProgress = f } })
            videoWorking = false
            if let out { _ = Usage.use("scrub", limit: Limits.freeScrubPerDay); videoOutURL = out; HandyHaptics.success() }
            else { errorText = "Couldn't scrub that video — it may be protected or in an unusual format." }
        }
    }

    private func make() {
        guard let original else { return }
        guard Usage.hasRoom("scrub", limit: Limits.freeScrubPerDay) else { return }
        let rects = boxes.filter { $0.on }.map { $0.rect }
        working = true; errorText = nil
        Task { @MainActor in
            // Full-size re-draw + JPEG encode runs off the main thread so a large photo can't freeze it.
            let d = await Task.detached(priority: .userInitiated) { Scrubber.render(original, rects: rects) }.value
            working = false
            if let d { _ = Usage.use("scrub", limit: Limits.freeScrubPerDay); result = d; HandyHaptics.success() }
            else { errorText = "Couldn't make the clean copy. Try another photo." }
        }
    }
}
