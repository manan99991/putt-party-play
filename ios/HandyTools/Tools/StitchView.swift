import SwiftUI
import PhotosUI
import UIKit
import Photos

/// Long Screenshot — pick the screenshots you took while scrolling (any app), get one tall image.
/// The fixed header/footer appear once and the overlaps are removed automatically.
struct StitchView: View {
    @EnvironmentObject var store: StoreManager
    @State private var items: [PhotosPickerItem] = []
    @State private var shots: [UIImage] = []
    @State private var result: UIImage?
    @State private var resultPNG: Data?        // encoded once off-main, not on every body render
    @State private var working = false
    @State private var errorText: String?
    @State private var finding = false
    @State private var resultPDF: Data?
    @State private var savedNote: String?
    @State private var seams: [CGFloat] = []          // where each join is, in pixels from the top
    @State private var hiddenCount: Int?
    @State private var hiding = false

    private var overQuota: Bool { !Usage.hasRoom("stitch", limit: Limits.freeStitchPerDay) }

    var body: some View {
        ToolPage(title: "Long Screenshot", subtitle: "Take screenshots as you scroll, pick them here, get one tall image.", working: working) {
            HowTo("stitch", [
                "Tap Use the screenshots I just took — or pick them yourself, then fix the order.",
                "It lines them up and merges them into one tall image.",
                "Save it to Photos, share it, or send it as a PDF cut into pages.",
            ])
            Button { useLatest() } label: {
                HStack { if finding { BusySpinner().tint(.white) }; Label(L("Use the screenshots I just took"), systemImage: "sparkles.rectangle.stack") }.frame(maxWidth: .infinity)
            }
            .primaryButton().disabled(finding).accessibilityIdentifier("stitch-latest")
            PhotosPicker(selection: $items, maxSelectionCount: 12, matching: .screenshots) {
                Label(shots.isEmpty ? "Choose screenshots (top to bottom)" : "Choose different screenshots", systemImage: "rectangle.stack").frame(maxWidth: .infinity)
            }
            .secondaryButton()
            .onAppear { if Launch.sample, shots.isEmpty { shots = SampleAssets.screenshots() } }
            .onChange(of: items) { _, new in load(new) }

            if shots.isEmpty && result == nil {
                Text(L("Tip: overlap each screenshot a little with the previous one so the join is seamless."))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }

            if !shots.isEmpty && result == nil {
                HandyFlow(spacing: HandySpacing.s8) {
                        ForEach(Array(shots.enumerated()), id: \.offset) { i, img in
                            VStack(spacing: 4) {
                                Image(uiImage: img).resizable().scaledToFit().frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.small, style: .continuous))
                                HStack(spacing: 10) {
                                    Button { move(i, by: -1) } label: { Image(systemName: "chevron.left") }.disabled(i == 0).accessibilityLabel(L("Move earlier"))
                                    Text("\(i + 1)").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                                    Button { move(i, by: 1) } label: { Image(systemName: "chevron.right") }.disabled(i == shots.count - 1).accessibilityLabel(L("Move later"))
                                    Button { shots.remove(at: i) } label: { Image(systemName: "xmark.circle.fill") }.foregroundStyle(HandyColor.textSecondary).accessibilityLabel(L("Leave this one out"))
                                }.font(.system(size: 13)).buttonStyle(.plain).foregroundStyle(HandyColor.accent)
                            }
                        }
                    }
                HStack {
                    Text("\(shots.count) screenshot\(shots.count == 1 ? "" : "s"), in this order").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Spacer()
                    Button(L("Reverse order")) { shots.reverse() }.textButton().font(HandyFont.caption)
                }

                if !store.isPremium { QuotaChip(name: "stitch", limit: Limits.freeStitchPerDay).environmentObject(store) }
                if overQuota { LimitReachedBanner(message: "You've stitched today's \(Limits.freeStitchPerDay) free screenshots.") }

                Button { run() } label: {
                    HStack { if working { BusySpinner().tint(.white) }; Text(working ? "Stitching…" : "Stitch into one image") }.frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || overQuota || shots.count < 2)
                if working { ToolProgressBar(label: "Stitching your screenshots into one tall image…") }
            }

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            if let result {
                ScrollView {
                    Image(uiImage: result).resizable().scaledToFit()
                        .overlay {
                            // The joins, marked so they can be checked before sharing.
                            GeometryReader { g in
                                ForEach(Array(seams.enumerated()), id: \.offset) { _, y in
                                    Rectangle().fill(HandyColor.accent.opacity(0.8)).frame(height: 1.5)
                                        .offset(y: g.size.height * y / max(1, result.size.height * result.scale))
                                }
                            }.allowsHitTesting(false)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                }
                .frame(maxHeight: 420)
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                Text("\(Int(result.size.width)) × \(Int(result.size.height)) px").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                if !seams.isEmpty {
                    Label("\(L("Joined in")) \(seams.count) \(L(seams.count == 1 ? "place — the blue line shows where. Check nothing is doubled or missing." : "places — the blue lines show where. Check nothing is doubled or missing."))", systemImage: "line.3.horizontal")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    hiding = true
                    let src = result
                    Task {
                        let r = await Task.detached(priority: .userInitiated) { StitchExtras.hidePersonal(src) }.value
                        hiding = false
                        guard let r else { return }
                        hiddenCount = r.hidden
                        guard r.hidden > 0 else { return }
                        self.result = r.image
                        resultPNG = await Task.detached(priority: .userInitiated) { r.image.pngData() }.value
                        resultPDF = await Task.detached(priority: .utility) { StitchExtras.pdf(r.image) }.value
                        HandyHaptics.success()
                    }
                } label: {
                    HStack { if hiding { BusySpinner() }; Label(L("Hide faces and numbers before sharing"), systemImage: "eye.slash") }.frame(maxWidth: .infinity)
                }.secondaryButton().disabled(hiding || hiddenCount != nil).accessibilityIdentifier("stitch-hide")
                if let hiddenCount {
                    Text(hiddenCount == 0 ? L("No faces or personal numbers found.") : "\(L("Hid")) \(hiddenCount) \(L(hiddenCount == 1 ? "face or number" : "faces and numbers")). \(L("Names written as words aren't hidden — check before you share."))")
                        .font(HandyFont.caption).foregroundStyle(hiddenCount == 0 ? HandyColor.textSecondary : HandyColor.success).fixedSize(horizontal: false, vertical: true)
                }
                if let png = resultPNG {
                    KeepShare([.data(png, name: "Long screenshot", ext: "png")], tool: "Long screenshot")
                    if let pdf = resultPDF {
                        ShareLink(item: PDFFile(data: pdf), preview: SharePreview("Long screenshot.pdf")) {
                            Label(L("As a PDF"), systemImage: "doc.richtext").frame(maxWidth: .infinity)
                        }.secondaryButton()
                    }
                    if let pdf = resultPDF { Text("\(L("The PDF has")) \(StitchExtras.pageSlices(height: result.size.height * result.scale, pageHeight: (result.size.width * result.scale * 1.414).rounded()).count) \(L("pages, sized like A4 — easy to print or email.")) (\(ByteCountFormatter.string(fromByteCount: Int64(pdf.count), countStyle: .file)))").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
                    if let savedNote { Text(L(savedNote)).font(HandyFont.caption).foregroundStyle(HandyColor.success) }
                }
                Button(L("Start over")) { self.result = nil; resultPNG = nil; resultPDF = nil; savedNote = nil; shots = []; items = []; seams = []; hiddenCount = nil }.textButton()
            }
        }
    }

    /// One tap: the screenshots from your latest scroll (taken within a minute and a half of each other).
    private func useLatest() {
        result = nil; resultPNG = nil; resultPDF = nil; errorText = nil; savedNote = nil; finding = true
        Task {
            if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined { _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite) }
            let s = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            guard s == .authorized || s == .limited else {
                await MainActor.run { finding = false; errorText = "Tenzy needs Photos access to find your latest screenshots — or choose them yourself below." }
                return
            }
            let found = await StitchExtras.latestRun()
            await MainActor.run {
                finding = false
                if found.count >= 2 { shots = found }
                else { errorText = "Your latest screenshots weren't taken one after another. Scroll and take a few, or choose them yourself." }
            }
        }
    }

    private func move(_ i: Int, by d: Int) {
        let j = i + d
        guard shots.indices.contains(i), shots.indices.contains(j) else { return }
        shots.swapAt(i, j)
    }

    private func load(_ picked: [PhotosPickerItem]) {
        result = nil; errorText = nil
        Task {
            var out: [UIImage] = []
            for item in picked { if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { out.append(img) } }
            await MainActor.run { shots = out }
        }
    }

    private func run() {
        guard Usage.hasRoom("stitch", limit: Limits.freeStitchPerDay) else { return }
        working = true; errorText = nil
        let input = shots
        Task { @MainActor in
            // Stitch (per-image re-render, overlap search, tall composite) and the PNG encode both run
            // off the main thread — a 12-shot tall image would otherwise lock the UI for seconds.
            let made = await Task.detached(priority: .userInitiated) { Stitcher.stitchWithSeams(input) }.value
            seams = made?.seams ?? []; hiddenCount = nil
            if let out = made?.image {
                _ = Usage.use("stitch", limit: Limits.freeStitchPerDay)
                result = out
                resultPNG = await Task.detached(priority: .userInitiated) { out.pngData() }.value
                resultPDF = await Task.detached(priority: .utility) { StitchExtras.pdf(out) }.value
                working = false
                HandyHaptics.success()
            } else {
                working = false
                errorText = "Couldn't line those up. Make sure they're from the same screen and overlap a little."
            }
        }
    }
}
