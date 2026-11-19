import SwiftUI
import PhotosUI
import UIKit

/// Studio — start from the job: a product photo ready for a listing, a profile picture, a dark or dull photo
/// fixed, a passport or ID photo, the subject cut out, or a smaller file / another format. Every result is shown
/// before → after with what changed, then saved to Photos or shared. On-device, free, no watermark.
struct StudioView: View {
    @EnvironmentObject var store: StoreManager

    private enum Job: Int, CaseIterable {
        case listing, profile, fix, passport, cutout, smaller
        var title: String { ["Product photo for a listing", "Profile picture", "Fix a dark or dull photo", "Passport or ID photo", "Cut out the subject", "Smaller file or another format"][rawValue] }
        var icon: String { ["bag.fill", "person.crop.circle.fill", "sun.max.fill", "person.text.rectangle.fill", "scissors", "arrow.down.right.and.arrow.up.left"][rawValue] }
        var line: String { ["On pure white, centred, square — sized for Amazon, eBay, Etsy or Marketplace", "Your face centred for the round crop every app uses", "Brighter, clearer, sharper — see exactly what changed", "Measured to your country's rules, fixed, ready to print", "The background removed — see-through or a new colour", "Under a size limit, a pixel size, or JPG / PNG / HEIC"][rawValue] }
    }
    private enum Output { case png(Data), jpg(Data), heic(Data)
        var data: Data { switch self { case .png(let d), .jpg(let d), .heic(let d): return d } }
        var kind: String { switch self { case .png: return "PNG"; case .jpg: return "JPG"; case .heic: return "HEIC" } }
    }

    @State private var pickedItem: PhotosPickerItem?
    @State private var original: UIImage?
    @State private var originalBytes = 0
    @State private var job: Job?
    @State private var preview: UIImage?
    @State private var output: Output?
    @State private var changed: [String] = []
    @State private var working = false
    @State private var errorText: String?
    @State private var saved: Bool?

    // listing
    @State private var marketIdx = 0
    @State private var shadow = true
    // profile
    @State private var profileBG: ImageStudio.ProfileBackground = .keep
    // fix
    @State private var enhanceUpscale = false
    // cut out
    @State private var bgIdx = 0
    private let backgrounds: [(String, UIColor?)] = [("See-through", nil), ("White", .white), ("Black", .black), ("Light grey", UIColor(white: 0.9, alpha: 1)), ("Blue", UIColor(red: 0.84, green: 0.9, blue: 0.97, alpha: 1))]
    @State private var passportCounted = false
    // smaller / format
    @State private var resizeIdx = 1
    private let resizeOptions: [(String, CGFloat)] = [("4096 px", 4096), ("2048 px", 2048), ("1280 px", 1280), ("800 px", 800)]
    @State private var sizeLimitIdx: Int? = 0
    @State private var format: ImageStudio.Format = .jpg

    private var overQuota: Bool { !Usage.hasRoom("studio", limit: Limits.freeStudioPerDay) }

    var body: some View {
        ToolPage(title: "Studio", subtitle: "What's the photo for? Pick the job — Studio does the rest and shows you before and after.", working: working) {
            if original == nil {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label(L("Choose a photo"), systemImage: "photo").frame(maxWidth: .infinity)
                }.primaryButton()
            }
            if let original {
                if let job {
                    HStack {
                        Label(L(job.title), systemImage: job.icon).font(HandyFont.bodyStrong)
                        Spacer()
                        Button(L("Change")) { self.job = nil; reset() }.textButton()
                    }
                    if job == .passport {
                        if overQuota { LimitReachedBanner(message: "You've used today's \(Limits.freeStudioPerDay) free Studio edits.") }
                        else {
                            PassportStudio(original: original, specID: "us", retake: nil)
                                .id(ObjectIdentifier(original))
                                .onAppear { if !passportCounted { passportCounted = true; _ = Usage.use("studio", limit: Limits.freeStudioPerDay) } }
                        }
                    } else {
                        if let preview { CompareSlider(before: original, after: preview, circle: job == .profile) }
                        else { Image(uiImage: original).resizable().scaledToFit().frame(maxHeight: 280).frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous)) }
                        if !changed.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L("What changed")).font(HandyFont.caption.weight(.semibold))
                                ForEach(changed, id: \.self) { Label(L($0), systemImage: "checkmark").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                            }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
                        }
                        controls(job)
                        if !store.isPremium { QuotaChip(name: "studio", limit: Limits.freeStudioPerDay).environmentObject(store) }
                        if overQuota { LimitReachedBanner(message: "You've used today's \(Limits.freeStudioPerDay) free Studio edits.") }
                        if output == nil {
                            Button { run(job) } label: {
                                HStack { if working { ProgressView().tint(.white) }; Text(working ? L("Working…") : L(actionLabel(job))) }.frame(maxWidth: .infinity)
                            }.primaryButton().disabled(working || overQuota).accessibilityIdentifier("studio-run")
                        }
                        if working { ToolProgressBar(label: "Working on your photo…") }
                        if let errorText { Text(L(errorText)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
                        if let output { landing(output) }
                    }
                } else {
                    Image(uiImage: original).resizable().scaledToFit().frame(maxHeight: 200).frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    Text(L("What's it for?")).font(HandyFont.bodyStrong)
                    ForEach(Job.allCases, id: \.rawValue) { j in
                        Button { job = j; reset(); if j != .passport && j != .smaller { run(j) } } label: {
                            HStack(spacing: 12) {
                                Image(systemName: j.icon).font(.system(size: 20)).foregroundStyle(HandyColor.accent).frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L(j.title)).font(HandyFont.body.weight(.semibold)).foregroundStyle(HandyColor.textPrimary)
                                    Text(L(j.line)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").foregroundStyle(HandyColor.textSecondary)
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: 0)
                        }.buttonStyle(.plain).accessibilityIdentifier("studio-job-\(j.rawValue)")
                    }
                }
                PhotosPicker(selection: $pickedItem, matching: .images) { Label(L("Choose a different photo"), systemImage: "photo.on.rectangle.angled") }.textButton()
            }
        }
        .onAppear { if Launch.sample, original == nil { original = SampleAssets.photo(); originalBytes = original?.jpegData(compressionQuality: 0.95)?.count ?? 0 } }
        .onChange(of: pickedItem) { _, item in
            Task {
                if let d = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    await MainActor.run { original = img.normalizedUp(); originalBytes = d.count; reset(); passportCounted = false
                        if let job, job != .passport, job != .smaller { run(job) } }
                }
            }
        }
    }

    private func reset() { preview = nil; output = nil; changed = []; errorText = nil; saved = nil }

    // MARK: controls (only what changes the result; each change re-runs)

    @ViewBuilder private func controls(_ job: Job) -> some View {
        switch job {
        case .listing:
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Text(L("Where is it going?")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                HandyFlow(spacing: HandySpacing.s8) {
                    ForEach(Array(ImageStudio.markets.enumerated()), id: \.offset) { i, m in
                        HChip(text: m.name, selected: marketIdx == i) { marketIdx = i; reset(); run(.listing) }
                    }
                }
                Toggle(L("Soft shadow under the product"), isOn: $shadow).tint(HandyColor.accent).font(HandyFont.body)
                    .onChange(of: shadow) { _, _ in reset(); run(.listing) }
            }
        case .profile:
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Text(L("Background")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                HandyFlow(spacing: HandySpacing.s8) {
                    ForEach(ImageStudio.ProfileBackground.allCases, id: \.self) { b in
                        HChip(text: ["keep": "As it is", "blur": "Softly blurred", "plain": "Plain colour"][b.rawValue] ?? b.rawValue, selected: profileBG == b) { profileBG = b; reset(); run(.profile) }
                    }
                }
            }
        case .fix:
            Toggle(L("Also make it bigger (2×)"), isOn: $enhanceUpscale).tint(HandyColor.accent).font(HandyFont.body)
                .onChange(of: enhanceUpscale) { _, _ in reset(); run(.fix) }
        case .cutout:
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Text(L("Background")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                HStack(spacing: HandySpacing.s8) {
                    ForEach(0..<backgrounds.count, id: \.self) { i in
                        Button { bgIdx = i; reset(); run(.cutout) } label: {
                            ZStack {
                                if backgrounds[i].1 == nil { Checkerboard().frame(width: 32, height: 32).clipShape(Circle()) }
                                else { Circle().fill(Color(backgrounds[i].1!)).frame(width: 32, height: 32) }
                                Circle().stroke(bgIdx == i ? HandyColor.accent : HandyColor.border, lineWidth: bgIdx == i ? 2.5 : 1).frame(width: 32, height: 32)
                            }
                        }.accessibilityLabel(L(backgrounds[i].0))
                    }
                    Spacer()
                }
            }
        case .smaller:
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Text(L("Under a file size")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                HandyFlow(spacing: HandySpacing.s8) {
                    ForEach(Array(SizeTarget.presets.enumerated()), id: \.offset) { i, p in HChip(text: p.label, selected: sizeLimitIdx == i) { sizeLimitIdx = i; reset() } }
                }
                Text(L("…or a pixel size")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                HandyFlow(spacing: HandySpacing.s8) {
                    ForEach(0..<resizeOptions.count, id: \.self) { i in HChip(text: resizeOptions[i].0, selected: sizeLimitIdx == nil && resizeIdx == i) { resizeIdx = i; sizeLimitIdx = nil; reset() } }
                }
                Picker(L("Format"), selection: $format) { ForEach(ImageStudio.Format.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                    .onChange(of: format) { _, _ in reset() }
                Text("\(L("Now")) \(SizeTarget.format(originalBytes)). \(L("Location and camera details are left out of the copy."))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        case .passport: EmptyView()
        }
    }

    private func actionLabel(_ j: Job) -> String {
        switch j { case .listing: return "Make the listing photo"; case .profile: return "Make the profile picture"; case .fix: return "Fix the photo"
        case .passport: return "Make passport photo"; case .cutout: return "Cut out the subject"; case .smaller: return "Make the copy" }
    }

    // MARK: where it lands

    @ViewBuilder private func landing(_ out: Output) -> some View {
        Text("\(SizeTarget.format(out.data.count)) · \(out.kind)\(originalBytes > 0 ? " · \(L("was")) \(SizeTarget.format(originalBytes))" : "")")
            .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        Button {
            Task { let ok = await PhotoSaver.save(out.data); saved = ok; if ok { HandyHaptics.success() } }
        } label: { Label(L(saved == true ? "Saved to Photos" : "Save to Photos"), systemImage: saved == true ? "checkmark.circle.fill" : "photo.on.rectangle").frame(maxWidth: .infinity) }
            .primaryButton().disabled(saved == true).accessibilityIdentifier("studio-save")
        if saved == false {
            Button(L("Allow Tenzy to add photos — open Settings")) { Permission.openSettings() }.textButton()
        }
        Group {
            switch out {
            case .png(let d): ShareLink(item: PNGFile(data: d), preview: SharePreview("Studio")) { Label(L("Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
            case .jpg(let d): ShareLink(item: JPEGFile(data: d), preview: SharePreview("Studio")) { Label(L("Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
            case .heic(let d): ShareLink(item: HEICFile(data: d), preview: SharePreview("Studio")) { Label(L("Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
            }
        }.secondaryButton()
    }

    // MARK: run

    private func run(_ j: Job) {
        guard let src = original, j != .passport else { return }
        guard Usage.hasRoom("studio", limit: Limits.freeStudioPerDay) else { return }
        working = true; errorText = nil; output = nil; changed = []
        let market = ImageStudio.markets[marketIdx], sh = shadow, pbg = profileBG, up = enhanceUpscale, bg = backgrounds[bgIdx].1
        let rIdx = resizeIdx, sIdx = sizeLimitIdx, fmt = format
        Task { @MainActor in
            defer { working = false }
            switch j {
            case .listing:
                guard let cut = await Task.detached(priority: .userInitiated) { ImageStudio.cutout(src) }.value,
                      let img = await Task.detached(priority: .userInitiated) { ImageStudio.listing(cut, market: market, shadow: sh) }.value
                else { errorText = "Couldn't find the product. Try a photo with the item clearly in front."; return }
                preview = img
                changed = ["Background removed and replaced with pure white", "Centred and filling \(Int(market.fill * 100))% of a square", "\(Int(market.side)) × \(Int(market.side)) px for \(market.name)"] + (sh ? ["Soft shadow so it sits on the surface"] : [])
                if let d = await Task.detached(priority: .userInitiated) { img.jpegData(compressionQuality: 0.92) }.value { output = .jpg(d) }
            case .profile:
                guard let img = await Task.detached(priority: .userInitiated) { ImageStudio.profile(src, background: pbg) }.value
                else { errorText = "No face found. Try a photo where your face is clear and facing the camera."; return }
                preview = img
                changed = ["Face centred with room above the head", "Square 1080 × 1080 — fits Instagram, LinkedIn, WhatsApp and Slack"] + (pbg == .blur ? ["Background softly blurred"] : pbg == .plain ? ["Background replaced with a plain colour"] : [])
                if let d = await Task.detached(priority: .userInitiated) { img.jpegData(compressionQuality: 0.92) }.value { output = .jpg(d) }
            case .fix:
                guard let img = await Task.detached(priority: .userInitiated) { ImageStudio.enhance(src, upscale: up) }.value
                else { errorText = "Couldn't fix this photo. Try another image."; return }
                preview = img
                let c = await Task.detached(priority: .userInitiated) { ImageStudio.changes(from: src, to: img) }.value
                changed = c.isEmpty ? ["Light clean-up — this photo was already well exposed"] : c + ["Noise smoothed and detail sharpened"]
                if let d = await Task.detached(priority: .userInitiated) { img.jpegData(compressionQuality: 0.95) }.value { output = .jpg(d) }
            case .cutout:
                guard let cut = await Task.detached(priority: .userInitiated) { ImageStudio.cutout(src) }.value else { errorText = "Couldn't find a clear subject. Try a photo with a distinct foreground."; return }
                if let bg {
                    let img = await Task.detached(priority: .userInitiated) { ImageStudio.composite(cut, on: bg) }.value
                    preview = img; changed = ["Background replaced"]
                    if let d = await Task.detached(priority: .userInitiated) { img.jpegData(compressionQuality: 0.92) }.value { output = .jpg(d) }
                } else {
                    preview = cut; changed = ["Background removed — see-through"]
                    if let d = await Task.detached(priority: .userInitiated) { cut.pngData() }.value { output = .png(d) }
                }
            case .smaller:
                if let sIdx {
                    guard let d = await SizeTarget.image(src, targetBytes: SizeTarget.presets[sIdx].bytes) else { errorText = "Couldn't get under that size without ruining it. Try a larger limit."; return }
                    preview = UIImage(data: d); output = .jpg(d)
                    changed = ["\(SizeTarget.format(originalBytes)) → \(SizeTarget.format(d.count))"]
                } else {
                    let dim = resizeOptions[rIdx].1
                    let r = await Task.detached(priority: .userInitiated) { () -> (UIImage, Data?) in
                        let img = src.resized(maxDimension: dim)
                        return (img, ImageStudio.encode(img, as: fmt, quality: 0.9))
                    }.value
                    guard let d = r.1 else { errorText = "This phone can't write \(fmt.rawValue)."; return }
                    preview = r.0
                    switch fmt { case .jpg: output = .jpg(d); case .png: output = .png(d); case .heic: output = .heic(d) }
                    changed = ["Longest side \(Int(dim)) px, \(fmt.rawValue)", "\(SizeTarget.format(originalBytes)) → \(SizeTarget.format(d.count))"]
                }
            case .passport: return
            }
            if output != nil { _ = Usage.use("studio", limit: Limits.freeStudioPerDay); HandyHaptics.success() }
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
