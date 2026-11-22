import SwiftUI
import CoreLocation
import ImageIO

/// What a photo flow actually did, shown above its result so it's never a silent "2 MB · JPG":
///  • the size before and after, and the pixels kept;
///  • what was taken out of the file (location with a map, the phone that took it, the time) — read from
///    the original and checked again on the result;
///  • what's still showing in the picture itself (faces, readable text), with one tap to hide it;
///  • press and hold the photo to see the original, to judge the quality for yourself;
///  • the next thing people usually do.
struct PhotoResultInsight: View {
    let original: Data
    let result: Data
    let stripped: Bool             // the flow removes hidden details
    var hideFaces: (() -> Void)?   // runs "hide faces and numbers" on the result
    var fitIt: (() -> Void)?       // opens Fit It with the result
    var limitBytes: Int? = nil     // the size it had to get under (upload limit), checked on the file

    @State private var before = Scrubber.Metadata()
    @State private var after = Scrubber.Metadata()
    @State private var extra: [String] = []
    @State private var map: UIImage?
    @State private var faces = 0
    @State private var texts = 0
    @State private var holding = false

    private var beforeImage: UIImage? { UIImage(data: original) }
    private var afterImage: UIImage? { UIImage(data: result) }
    private func px(_ i: UIImage?) -> String { i.map { "\(Int($0.size.width * $0.scale)) × \(Int($0.size.height * $0.scale))" } ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            sizeCard
            if stripped { removedCard }
            if faces + texts > 0, let hideFaces { stillShowing(hideFaces) }
            compare
        }
        .task(id: result.count) { await read() }
    }

    // MARK: size

    private var sizeCard: some View {
        let a = original.count, b = result.count
        let pct = a > 0 ? Int((1 - Double(b) / Double(a)) * 100) : 0
        let samePx = px(beforeImage) == px(afterImage)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(SizeTarget.format(a)).font(HandyFont.cardTitle).foregroundStyle(HandyColor.textSecondary).strikethrough(b < a)
                Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold)).foregroundStyle(HandyColor.textSecondary)
                Text(SizeTarget.format(b)).font(HandyFont.cardTitle).foregroundStyle(HandyColor.success)
                Spacer()
                if pct > 0 { Text("\(pct)% \(L("smaller"))").font(HandyFont.caption).foregroundStyle(HandyColor.success) }
            }
            Text(samePx ? "\(L("Full size kept")) · \(px(afterImage))" : "\(px(beforeImage)) → \(px(afterImage))")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            if let limitBytes {
                let ok = b <= limitBytes
                Label("\(L(ok ? "Under" : "Still over")) \(SizeTarget.format(limitBytes))", systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(HandyFont.caption).foregroundStyle(ok ? Color.green : Color.orange)
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .combine)
    }

    // MARK: what was removed

    private var removedCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Taken out of the file"), systemImage: "checkmark.shield.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success)
            if let map { Image(uiImage: map).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) }
            if let c = before.coordinate {
                row("location.slash.fill", L("Where it was taken"), String(format: "%.4f, %.4f", c.latitude, c.longitude), gone: after.coordinate == nil)
            } else {
                row("location.slash", L("Where it was taken"), L("This photo had no location"), gone: true)
            }
            if let d = before.device { row("iphone.slash", L("The phone that took it"), d, gone: after.device == nil) }
            if let t = before.taken { row("clock.badge.xmark", L("When it was taken"), t, gone: after.taken == nil) }
            if !extra.isEmpty { row("eye.slash", L("Other hidden details"), extra.prefix(4).joined(separator: ", "), gone: true) }
            Text(L("Checked again on the new copy: none of this is in it. The picture itself is unchanged.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private func row(_ icon: String, _ title: String, _ value: String, gone: Bool) -> some View {
        HStack(alignment: .top, spacing: HandySpacing.s8) {
            Image(systemName: icon).foregroundStyle(gone ? HandyColor.success : HandyColor.danger).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Text(value).font(HandyFont.body).strikethrough(gone).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text(gone ? L("Removed") : L("Still there")).font(HandyFont.micro).foregroundStyle(gone ? HandyColor.success : HandyColor.danger)
        }
    }

    // MARK: still in the picture

    private func stillShowing(_ hide: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Still visible in the picture"), systemImage: "eye.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.amber)
            Text([faces > 0 ? "\(faces) \(L(faces == 1 ? "face" : "faces"))" : nil, texts > 0 ? "\(texts) \(L(texts == 1 ? "piece of personal text (a number, a plate, an address)" : "pieces of personal text (numbers, plates, addresses)"))" : nil]
                .compactMap { $0 }.joined(separator: " · "))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            Button { hide() } label: { Label(L("Hide them too"), systemImage: "eye.slash.fill").frame(maxWidth: .infinity) }.secondaryButton()
                .accessibilityIdentifier("insight-hide")
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    // MARK: before / after

    @ViewBuilder private var compare: some View {
        if let a = afterImage, let b = beforeImage {
            VStack(alignment: .leading, spacing: 4) {
                Image(uiImage: holding ? b : a).resizable().scaledToFit().frame(maxWidth: .infinity).frame(maxHeight: 360).opensFullSize(a)
                    .overlay(alignment: .topLeading) {
                        Text(holding ? L("Original") : L("New copy")).font(HandyFont.micro).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.black.opacity(0.6), in: Capsule()).foregroundStyle(.white).padding(8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onLongPressGesture(minimumDuration: 0.05, maximumDistance: 60, perform: {}, onPressingChanged: { holding = $0 })
                    .accessibilityLabel(L("The new copy. Press and hold to see the original."))
                Text(L("Press and hold the photo to see the original.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                if let fitIt {
                    Button { fitIt() } label: { Label(L("Fit it under a size limit"), systemImage: "arrow.down.right.and.arrow.up.left").frame(maxWidth: .infinity) }
                        .compactButton()
                }
            }
        }
    }

    // MARK: reading

    private func read() async {
        before = Scrubber.metadata(in: original)
        after = Scrubber.metadata(in: result)
        extra = Self.otherDetails(original).filter { !Self.otherDetails(result).contains($0) }
        if stripped, let c = before.coordinate { map = await Scrubber.mapSnapshot(c) }
        if let img = afterImage {
            let found = await Task.detached(priority: .utility) { Scrubber.detect(img.resized(maxDimension: 1600)) }.value
            faces = found.faces.count; texts = found.text.filter(\.personal).count
        }
    }

    /// The other things a camera writes into a photo, by plain name — so "removed" is specific.
    static func otherDetails(_ data: Data) -> [String] {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] else { return [] }
        let exif = p[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let tiff = p[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        let aux = p[kCGImagePropertyExifAuxDictionary as String] as? [String: Any] ?? [:]
        var out: [String] = []
        if exif[kCGImagePropertyExifLensModel as String] != nil { out.append("lens") }
        if tiff[kCGImagePropertyTIFFSoftware as String] != nil { out.append("software version") }
        if exif[kCGImagePropertyExifBodySerialNumber as String] != nil || aux[kCGImagePropertyExifAuxSerialNumber as String] != nil { out.append("camera serial number") }
        if tiff[kCGImagePropertyTIFFArtist as String] != nil || exif[kCGImagePropertyExifCameraOwnerName as String] != nil { out.append("owner's name") }
        if exif[kCGImagePropertyExifSubjectArea as String] != nil { out.append("focus point") }
        if p[kCGImagePropertyMakerAppleDictionary as String] != nil { out.append("Apple camera notes") }
        return out
    }
}
