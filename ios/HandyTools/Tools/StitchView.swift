import SwiftUI
import PhotosUI
import UIKit

/// Long Screenshot — pick the screenshots you took while scrolling (any app), get one tall image.
/// The fixed header/footer appear once and the overlaps are removed automatically.
struct StitchView: View {
    @EnvironmentObject var store: StoreManager
    @State private var items: [PhotosPickerItem] = []
    @State private var shots: [UIImage] = []
    @State private var result: UIImage?
    @State private var working = false
    @State private var errorText: String?

    private var overQuota: Bool { !Usage.hasRoom("stitch", limit: Limits.freeStitchPerDay) }

    var body: some View {
        ToolPage(title: "Long Screenshot", subtitle: "Take screenshots as you scroll, pick them here, get one tall image.") {
            PhotosPicker(selection: $items, maxSelectionCount: 12, matching: .screenshots) {
                Label(shots.isEmpty ? "Choose screenshots (top to bottom)" : "Choose different screenshots", systemImage: "rectangle.stack").frame(maxWidth: .infinity)
            }
            .secondaryButton()
            .onChange(of: items) { _, new in load(new) }

            if shots.isEmpty && result == nil {
                Text("Tip: overlap each screenshot a little with the previous one so the join is seamless.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }

            if !shots.isEmpty && result == nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HandySpacing.s8) {
                        ForEach(Array(shots.enumerated()), id: \.offset) { i, img in
                            VStack(spacing: 4) {
                                Image(uiImage: img).resizable().scaledToFit().frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.small, style: .continuous))
                                Text("\(i + 1)").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                            }
                        }
                    }
                }
                HStack {
                    Text("\(shots.count) screenshot\(shots.count == 1 ? "" : "s"), in this order").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Spacer()
                    Button("Reverse order") { shots.reverse() }.textButton().font(HandyFont.caption)
                }

                if !store.isPremium { QuotaChip(name: "stitch", limit: Limits.freeStitchPerDay).environmentObject(store) }
                if overQuota { LimitReachedBanner(message: "You've stitched today's \(Limits.freeStitchPerDay) free screenshots.") }

                Button { run() } label: {
                    HStack { if working { ProgressView().tint(.white) }; Text(working ? "Stitching…" : "Stitch into one image") }.frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || overQuota || shots.count < 2)
            }

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            if let result {
                ScrollView {
                    Image(uiImage: result).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                }
                .frame(maxHeight: 420)
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                Text("\(Int(result.size.width)) × \(Int(result.size.height)) px").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                if let png = result.pngData() {
                    ShareLink(item: PNGFile(data: png), preview: SharePreview("Long screenshot")) {
                        Label("Save or share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }.primaryButton()
                }
                Button("Start over") { self.result = nil; shots = []; items = [] }.textButton()
            }
        }
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
        guard Usage.use("stitch", limit: Limits.freeStitchPerDay) else { return }
        working = true; errorText = nil
        let input = shots
        Task { @MainActor in
            let out = Stitcher.stitch(input)
            working = false
            if let out { result = out; HandyHaptics.success() }
            else { errorText = "Couldn't line those up. Make sure they're from the same screen and overlap a little." }
        }
    }
}
