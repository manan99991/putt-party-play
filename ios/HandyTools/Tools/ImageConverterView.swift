import SwiftUI
import PhotosUI
import UIKit

/// Convert and shrink photos — HEIC → JPG/PNG, resize, compress, in a batch. Great for uploads,
/// forms, and sites that reject iPhone HEICs. All on the phone.
struct ImageConverterView: View {
    @EnvironmentObject var store: StoreManager
    @State private var items: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var format = 0        // 0 JPG, 1 PNG
    @State private var sizeIdx = 0       // 0 original, 1 2048, 2 1024
    @State private var quality = 0.8
    @State private var outputs: [URL] = []
    @State private var working = false

    private let sizes: [(String, CGFloat?)] = [("Original", nil), ("Max 2048", 2048), ("Max 1024", 1024)]
    private var overQuota: Bool { !Usage.hasRoom("imgconvert", limit: Limits.freeConvertPerDay) }
    private var maxPick: Int { store.isPremium ? 0 : 5 }

    var body: some View {
        ToolPage(title: "Image Converter", subtitle: "HEIC → JPG/PNG, resize and compress — in a batch.") {
            PhotosPicker(selection: $items, maxSelectionCount: maxPick, matching: .images) {
                Label(images.isEmpty ? "Pick photos" : "Pick different photos", systemImage: "photo.stack").frame(maxWidth: .infinity)
            }
            .compactButton()
            .onChange(of: items) { _, new in load(new) }

            if !images.isEmpty {
                Text("\(images.count) photo\(images.count == 1 ? "" : "s")").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)

                Picker("Format", selection: $format) { Text("JPG").tag(0); Text("PNG").tag(1) }.pickerStyle(.segmented)
                Picker("Size", selection: $sizeIdx) { ForEach(0..<sizes.count, id: \.self) { i in Text(sizes[i].0).tag(i) } }.pickerStyle(.segmented)
                if format == 0 {
                    HStack { Text("Quality").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        Slider(value: $quality, in: 0.3...1).tint(HandyColor.accent)
                        Text("\(Int(quality * 100))%").font(HandyFont.caption).monospacedDigit() }
                }
                if !store.isPremium { QuotaChip(name: "imgconvert", limit: Limits.freeConvertPerDay).environmentObject(store) }
                if overQuota { LimitReachedBanner(message: "You've converted today's \(Limits.freeConvertPerDay) free batches.") }
                if !store.isPremium { Text("Free converts up to 5 at once. Pro: unlimited batches.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }

                Button { convert() } label: {
                    HStack { if working { ProgressView().tint(.white) }; Text(working ? "Converting…" : "Convert \(images.count)") }.frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || overQuota)
            }

            if !outputs.isEmpty {
                ShareLink(items: outputs) { Label("Save or share (\(outputs.count))", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
            }
        }
    }

    private func load(_ picked: [PhotosPickerItem]) {
        outputs = []
        Task {
            var out: [UIImage] = []
            for item in picked { if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { out.append(img) } }
            images = out
        }
    }

    private func convert() {
        guard Usage.use("imgconvert", limit: Limits.freeConvertPerDay) else { return }
        working = true; outputs = []
        let imgs = images, fmt = format, maxDim = sizes[sizeIdx].1, q = quality
        Task { @MainActor in
            var urls: [URL] = []
            for (i, img) in imgs.enumerated() {
                let resized = maxDim.map { img.resized(maxDimension: $0) } ?? img
                let data: Data?; let ext: String
                if fmt == 1 { data = resized.pngData(); ext = "png" } else { data = resized.jpegData(compressionQuality: q); ext = "jpg" }
                guard let d = data else { continue }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy-\(i + 1)-\(UUID().uuidString.prefix(4)).\(ext)")
                try? d.write(to: url); urls.append(url)
            }
            outputs = urls; working = false; HandyHaptics.success()
        }
    }
}

extension UIImage {
    /// Scale down so the longest side is at most `maxDimension` (never upscales).
    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: fmt).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
