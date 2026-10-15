import SwiftUI
import PhotosUI
import ImageIO
import MapKit
import UniformTypeIdentifiers

/// Shows the hidden data inside a photo (GPS, device, time) and makes a clean copy with none of it.
struct ExifView: View {
    @State private var pick: PhotosPickerItem?
    @State private var data: Data?
    @State private var image: UIImage?
    @State private var rows: [(String, String)] = []
    @State private var cleanURL: URL?
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var mapImage: UIImage?

    var body: some View {
        ToolPage(title: "Photo Metadata", subtitle: "See where and when a photo was taken — and strip that before you send it to a stranger.") {
            PhotosPicker(selection: $pick, matching: .images) { Label("Choose a photo", systemImage: "photo").frame(maxWidth: .infinity) }
                .primaryButton()
            if let image { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200).clipShape(RoundedRectangle(cornerRadius: 12)) }
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                        HStack(alignment: .top) { Text(r.0).foregroundStyle(HandyColor.textSecondary).frame(width: 110, alignment: .leading); Text(r.1).foregroundStyle(HandyColor.textPrimary) }.font(.system(size: 15))
                        // Hero: when location exists, a 120pt static MapKit snapshot with a pin,
                        // right under the location row — the "oh" moment that makes people strip it.
                        if r.0.contains("Location"), let mapImage {
                            Image(uiImage: mapImage).resizable().aspectRatio(contentMode: .fill)
                                .frame(height: 120).clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                        }
                    }
                }.cardStyle(padding: HandySpacing.s12)
                Button { strip() } label: { Label("Make a clean copy (no metadata)", systemImage: "eraser").frame(maxWidth: .infinity) }.secondaryButton()
                if let cleanURL { ShareLink(item: cleanURL) { Label("Share clean copy", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton() }
            }
        }
        .onChange(of: pick) { _, item in Task { await load(item) } }
        .task(id: coordinate?.latitude) {
            guard let c = coordinate else { mapImage = nil; return }
            mapImage = await ExifView.mapSnapshot(center: c)
        }
    }

    /// Static 120pt-tall map snapshot with an accent pin at the photo's GPS point.
    private static func mapSnapshot(center: CLLocationCoordinate2D) async -> UIImage? {
        let opts = MKMapSnapshotter.Options()
        opts.region = MKCoordinateRegion(center: center, latitudinalMeters: 2500, longitudinalMeters: 2500)
        opts.size = CGSize(width: 640, height: 240)
        guard let shot = try? await MKMapSnapshotter(options: opts).start() else { return nil }
        return UIGraphicsImageRenderer(size: opts.size).image { _ in
            shot.image.draw(at: .zero)
            let p = shot.point(for: center)
            let r: CGFloat = 11
            UIColor(HandyColor.accent).setFill()
            UIBezierPath(ovalIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)).fill()
            UIColor.white.setStroke()
            UIBezierPath(ovalIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)).stroke()
        }
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item, let d = try? await item.loadTransferable(type: Data.self) else { return }
        data = d; image = UIImage(data: d); cleanURL = nil
        guard let src = CGImageSourceCreateWithData(d as CFData, nil), let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] else { return }
        var r: [(String, String)] = []
        let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]
        if let w = props[kCGImagePropertyPixelWidth as String], let h = props[kCGImagePropertyPixelHeight as String] { r.append(("Size", "\(w) × \(h)")) }
        if let t = exif[kCGImagePropertyExifDateTimeOriginal as String] { r.append(("Taken", "\(t)")) }
        if let m = tiff[kCGImagePropertyTIFFModel as String] { r.append(("Device", "\(m)")) }
        if let l = exif[kCGImagePropertyExifLensModel as String] { r.append(("Lens", "\(l)")) }
        if let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double, let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double {
            let ns = (gps[kCGImagePropertyGPSLatitudeRef as String] as? String) == "S" ? -1.0 : 1.0
            let ew = (gps[kCGImagePropertyGPSLongitudeRef as String] as? String) == "W" ? -1.0 : 1.0
            r.append(("📍 Location", String(format: "%.5f, %.5f", lat * ns, lon * ew)))
            coordinate = CLLocationCoordinate2D(latitude: lat * ns, longitude: lon * ew)
        } else { r.append(("Location", "none")); coordinate = nil }
        if let s = tiff[kCGImagePropertyTIFFSoftware as String] { r.append(("Software", "\(s)")) }
        rows = r
    }

    private func strip() {
        guard let data, let src = CGImageSourceCreateWithData(data as CFData, nil) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clean-\(Int(Date().timeIntervalSince1970)).jpg")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return }
        // Re-encode with an explicitly empty metadata set: no EXIF, no GPS, no TIFF.
        let noMeta: [String: Any] = [kCGImagePropertyExifDictionary as String: [:], kCGImagePropertyGPSDictionary as String: [:], kCGImagePropertyTIFFDictionary as String: [:],
                                     kCGImageDestinationLossyCompressionQuality as String: 0.92]
        CGImageDestinationAddImageFromSource(dest, src, 0, noMeta as CFDictionary)
        if CGImageDestinationFinalize(dest) { cleanURL = url; Interstitials.shared.showIfReady() }
    }
}
