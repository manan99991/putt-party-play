import SwiftUI
import PhotosUI
import UIKit

/// Studio — one photo in, the four things people actually need out: cut out the subject, make a
/// passport/ID photo, resize (to pixels or a size limit), or convert the format. On-device, free,
/// no watermark — the OS has the engines, it just never exposes them.
struct StudioView: View {
    @EnvironmentObject var store: StoreManager

    private enum Mode: Int, CaseIterable { case cutout, passport, resize, convert
        var title: String { ["Cut out", "Passport", "Resize", "Convert"][rawValue] } }
    private enum Output { case png(Data), jpg(Data), heic(Data) }

    @State private var pickedItem: PhotosPickerItem?
    @State private var original: UIImage?
    @State private var originalBytes = 0
    @State private var mode: Mode = .cutout
    @State private var preview: UIImage?
    @State private var output: Output?
    @State private var working = false
    @State private var errorText: String?

    // cut out
    @State private var bgIdx = 0
    private let backgrounds: [(String, UIColor?)] = [("Transparent", nil), ("White", .white), ("Black", .black), ("Light grey", UIColor(white: 0.9, alpha: 1)), ("Blue", UIColor(red: 0.84, green: 0.9, blue: 0.97, alpha: 1))]
    // passport
    @State private var specIdx = 0
    @State private var passportBG = true
    @State private var sheet: Data?
    // resize
    @State private var resizeIdx = 1
    private let resizeOptions: [(String, CGFloat)] = [("4096 px", 4096), ("2048 px", 2048), ("1280 px", 1280), ("800 px", 800)]
    @State private var sizeLimitIdx: Int? = nil
    // convert
    @State private var format: ImageStudio.Format = .jpg
    @State private var quality: Double = 0.85

    private var overQuota: Bool { !Usage.hasRoom("studio", limit: Limits.freeStudioPerDay) }

    var body: some View {
        ToolPage(title: "Studio", subtitle: "Cut out the subject, make a passport photo, resize, or convert — one photo, one place.") {
            if original == nil {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("Choose a photo", systemImage: "photo").frame(maxWidth: .infinity)
                }.secondaryButton()
            }

            if let original {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HandySpacing.s8) {
                        ForEach(Mode.allCases, id: \.rawValue) { m in HChip(text: m.title, selected: mode == m) { mode = m; preview = nil; output = nil; errorText = nil } }
                    }
                }

                ZStack {
                    if case .png = output { Checkerboard() }
                    Image(uiImage: preview ?? original).resizable().scaledToFit()
                }
                .frame(maxHeight: 280).frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))

                PhotosPicker(selection: $pickedItem, matching: .images) { Label("Choose a different photo", systemImage: "photo.on.rectangle.angled") }.textButton()

                switch mode {
                case .cutout: cutoutControls
                case .passport: passportControls
                case .resize: resizeControls
                case .convert: convertControls
                }

                if !store.isPremium { QuotaChip(name: "studio", limit: Limits.freeStudioPerDay).environmentObject(store) }
                if overQuota { LimitReachedBanner(message: "You've used today's \(Limits.freeStudioPerDay) free Studio edits.") }

                Button { run() } label: {
                    HStack { if working { ProgressView().tint(.white) }; Text(working ? "Working…" : actionLabel) }.frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || overQuota)
            }

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            if let output {
                resultActions(output)
            }
        }
        .onAppear { if Launch.sample, original == nil { original = SampleAssets.photo(); originalBytes = original?.jpegData(compressionQuality: 0.95)?.count ?? 0 } }
        .onChange(of: pickedItem) { _, item in
            Task {
                if let d = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    await MainActor.run { original = img.normalizedUp(); originalBytes = d.count; preview = nil; output = nil; sheet = nil; errorText = nil }
                }
            }
        }
    }

    // MARK: controls

    private var cutoutControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text("Background").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HStack(spacing: HandySpacing.s8) {
                ForEach(0..<backgrounds.count, id: \.self) { i in
                    Button { bgIdx = i } label: {
                        ZStack {
                            if backgrounds[i].1 == nil { Checkerboard().frame(width: 32, height: 32).clipShape(Circle()) }
                            else { Circle().fill(Color(backgrounds[i].1!)).frame(width: 32, height: 32) }
                            Circle().stroke(bgIdx == i ? HandyColor.accent : HandyColor.border, lineWidth: bgIdx == i ? 2.5 : 1).frame(width: 32, height: 32)
                        }
                    }.accessibilityLabel(backgrounds[i].0)
                }
                Spacer()
            }
        }
    }

    private var passportControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Picker("Size", selection: $specIdx) { ForEach(0..<ImageStudio.passportSpecs.count, id: \.self) { Text(ImageStudio.passportSpecs[$0].name).tag($0) } }
                .pickerStyle(.menu).tint(HandyColor.accent).frame(maxWidth: .infinity, alignment: .leading)
            Toggle("Clean white background", isOn: $passportBG).tint(HandyColor.accent).font(HandyFont.body)
            Text("Face the camera, even light. A helper — check your country's exact rules before submitting.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private var resizeControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text("Longest side").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HStack(spacing: HandySpacing.s8) {
                ForEach(0..<resizeOptions.count, id: \.self) { i in HChip(text: resizeOptions[i].0, selected: sizeLimitIdx == nil && resizeIdx == i) { resizeIdx = i; sizeLimitIdx = nil } }
            }
            Text("…or under a file size").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HandySpacing.s8) {
                    ForEach(Array(SizeTarget.presets.enumerated()), id: \.offset) { i, p in HChip(text: p.label, selected: sizeLimitIdx == i) { sizeLimitIdx = i } }
                }
            }
        }
    }

    private var convertControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Picker("Format", selection: $format) { ForEach(ImageStudio.Format.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            if format != .png {
                HStack { Text("Quality").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary); Slider(value: $quality, in: 0.3...1).tint(HandyColor.accent); Text("\(Int(quality * 100))%").font(HandyFont.caption).monospacedDigit() }
            }
            Text("Now \(SizeTarget.format(originalBytes)). Metadata is dropped in the copy.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private var actionLabel: String {
        switch mode { case .cutout: return "Cut out subject"; case .passport: return "Make passport photo"; case .resize: return "Resize photo"; case .convert: return "Convert to \(format.rawValue)" }
    }

    @ViewBuilder private func resultActions(_ out: Output) -> some View {
        switch out {
        case .png(let d):
            Text("\(SizeTarget.format(d.count)) · PNG").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            ShareLink(item: PNGFile(data: d), preview: SharePreview("Studio")) { Label("Save or share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        case .jpg(let d):
            Text("\(SizeTarget.format(d.count)) · JPG").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            ShareLink(item: JPEGFile(data: d), preview: SharePreview("Studio")) { Label("Save or share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
            if mode == .passport {
                Button { if let p = preview { sheet = ImageStudio.printSheet(p); if sheet != nil { HandyHaptics.success() } } } label: { Label("Make a 4×6 print sheet", systemImage: "squareshape.split.3x3").frame(maxWidth: .infinity) }.secondaryButton()
                if let sheet { ShareLink(item: JPEGFile(data: sheet), preview: SharePreview("Print sheet")) { Label("Save the print sheet", systemImage: "printer").frame(maxWidth: .infinity) }.primaryButton() }
            }
        case .heic(let d):
            Text("\(SizeTarget.format(d.count)) · HEIC").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            ShareLink(item: HEICFile(data: d), preview: SharePreview("Studio")) { Label("Save or share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        }
    }

    // MARK: run

    private func run() {
        guard let src = original else { return }
        guard Usage.use("studio", limit: Limits.freeStudioPerDay) else { return }
        working = true; errorText = nil; output = nil; sheet = nil
        let m = mode, bg = backgrounds[bgIdx].1, spec = ImageStudio.passportSpecs[specIdx], pbg = passportBG
        let rIdx = resizeIdx, sIdx = sizeLimitIdx, fmt = format, q = CGFloat(quality)
        Task { @MainActor in
            defer { working = false }
            switch m {
            case .cutout:
                guard let cut = ImageStudio.cutout(src) else { errorText = "Couldn't find a clear subject. Try a photo with a distinct foreground."; return }
                if let bg { let img = ImageStudio.composite(cut, on: bg); preview = img; if let d = img.jpegData(compressionQuality: 0.92) { output = .jpg(d) } }
                else { preview = cut; if let d = cut.pngData() { output = .png(d) } }
            case .passport:
                guard let img = ImageStudio.passport(src, spec: spec, background: pbg ? .white : nil) else { errorText = "Couldn't find a clear face. Use a straight-on portrait with the whole head visible."; return }
                preview = img; if let d = img.jpegData(compressionQuality: 0.95) { output = .jpg(d) }
            case .resize:
                if let sIdx {
                    guard let d = await SizeTarget.image(src, targetBytes: SizeTarget.presets[sIdx].bytes) else { errorText = "Couldn't get under that size without ruining it. Try a larger limit."; return }
                    preview = UIImage(data: d); output = .jpg(d)
                } else {
                    let img = src.resized(maxDimension: resizeOptions[rIdx].1)
                    preview = img; if let d = img.jpegData(compressionQuality: 0.9) { output = .jpg(d) }
                }
            case .convert:
                guard let d = ImageStudio.encode(src, as: fmt, quality: q) else { errorText = "This device can't write \(fmt.rawValue)."; return }
                preview = src
                switch fmt { case .jpg: output = .jpg(d); case .png: output = .png(d); case .heic: output = .heic(d) }
            }
            if output != nil { HandyHaptics.success() }
        }
    }
}

/// Transparent-background checkerboard so a cut-out reads as "no background".
struct Checkerboard: View {
    var body: some View {
        GeometryReader { geo in
            let s: CGFloat = 12
            Path { p in
                let cols = Int(geo.size.width / s) + 1, rows = Int(geo.size.height / s) + 1
                for r in 0..<rows { for c in 0..<cols where (r + c) % 2 == 0 { p.addRect(CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s, height: s)) } }
            }.fill(HandyColor.border.opacity(0.35))
        }
    }
}
