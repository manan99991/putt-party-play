import UIKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

/// Deterministic sample inputs for UI tests and screenshots (`-sample` launch flag): a photo with a
/// face-like subject and text, a pair of overlapping screenshots, a receipt, a short movie.
enum SampleAssets {
    static func photo(_ size: CGSize = CGSize(width: 1200, height: 1600)) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { c in
            let cg = c.cgContext
            let colors = [UIColor(red: 0.95, green: 0.78, blue: 0.55, alpha: 1).cgColor, UIColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 1).cgColor]
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                cg.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            // a "person": head + shoulders
            UIColor(red: 0.85, green: 0.65, blue: 0.5, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: size.width * 0.35, y: size.height * 0.28, width: size.width * 0.3, height: size.width * 0.36))
            UIColor(red: 0.2, green: 0.25, blue: 0.4, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: size.width * 0.15, y: size.height * 0.62, width: size.width * 0.7, height: size.height * 0.5))
            // eyes + mouth so Vision finds a face
            UIColor.black.setFill()
            cg.fillEllipse(in: CGRect(x: size.width * 0.43, y: size.height * 0.37, width: size.width * 0.035, height: size.width * 0.035))
            cg.fillEllipse(in: CGRect(x: size.width * 0.525, y: size.height * 0.37, width: size.width * 0.035, height: size.width * 0.035))
            let mouth = UIBezierPath(); mouth.move(to: CGPoint(x: size.width * 0.44, y: size.height * 0.46)); mouth.addQuadCurve(to: CGPoint(x: size.width * 0.56, y: size.height * 0.46), controlPoint: CGPoint(x: size.width * 0.5, y: size.height * 0.5)); mouth.lineWidth = 6; UIColor.black.setStroke(); mouth.stroke()
            ("SAMPLE 2026" as NSString).draw(at: CGPoint(x: size.width * 0.08, y: size.height * 0.08), withAttributes: [.font: UIFont.boldSystemFont(ofSize: size.width * 0.08), .foregroundColor: UIColor.white])
            ("Call 415-555-0123" as NSString).draw(at: CGPoint(x: size.width * 0.08, y: size.height * 0.9), withAttributes: [.font: UIFont.systemFont(ofSize: size.width * 0.05), .foregroundColor: UIColor.white])
        }
    }

    /// Two "screenshots" of a long chat with the same header/footer and a 40% overlap.
    static func screenshots() -> [UIImage] {
        let w: CGFloat = 1170, h: CGFloat = 2532, header: CGFloat = 220, footer: CGFloat = 180
        func page(_ offset: CGFloat) -> UIImage {
            let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
            return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { c in
                UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: w, height: h))
                UIColor(white: 0.95, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: w, height: header)); c.fill(CGRect(x: 0, y: h - footer, width: w, height: footer))
                ("Chat with Sam" as NSString).draw(at: CGPoint(x: 60, y: 120), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 44), .foregroundColor: UIColor.black])
                var y: CGFloat = header + 40 - offset
                var i = 0
                while y < h - footer {
                    if y > header - 100 {
                        let left = i % 2 == 0
                        let rect = CGRect(x: left ? 60 : w - 760, y: y, width: 700, height: 130)
                        (left ? UIColor(white: 0.9, alpha: 1) : UIColor(red: 0.2, green: 0.5, blue: 1, alpha: 1)).setFill()
                        UIBezierPath(roundedRect: rect, cornerRadius: 30).fill()
                        ("Message number \(i + 1) — lorem ipsum dolor" as NSString).draw(at: CGPoint(x: rect.minX + 30, y: rect.minY + 40), withAttributes: [.font: UIFont.systemFont(ofSize: 36), .foregroundColor: left ? UIColor.black : UIColor.white])
                    }
                    y += 180; i += 1
                }
            }
        }
        return [page(0), page(1200)]
    }

    /// Printed lines on a page of the given size and colour — the base for each kind of sample paper below.
    private static func paper(_ lines: [String], size: CGSize = CGSize(width: 1000, height: 1300), bg: UIColor = .white,
                              font: (Int) -> UIFont = { _ in .systemFont(ofSize: 44, weight: .medium) }, gap: CGFloat = 90) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { c in
            bg.setFill(); c.fill(CGRect(origin: .zero, size: size))
            for (i, l) in lines.enumerated() {
                (l as NSString).draw(at: CGPoint(x: 80, y: 110 + CGFloat(i) * gap), withAttributes: [.font: font(i), .foregroundColor: UIColor.black])
            }
        }
    }

    /// The right kind of made-up paper for what a flow is for, so a test or screenshot proves the real job (a card
    /// becomes a contact, a poster an event) instead of feeding a receipt to everything. All names and numbers invented.
    static func paper(for job: Block?) -> UIImage {
        switch job {
        case .businessCard?:
            return paper(["Maya Patel", "Product Designer", "Northwind Studio", "+1 312 555 0199", "maya@northwind.example", "northwind.example"],
                         size: CGSize(width: 1050, height: 640), font: { $0 == 0 ? .boldSystemFont(ofSize: 60) : .systemFont(ofSize: 40) }, gap: 80)
        case .calendarEvent?:
            let d = Calendar.current.date(byAdding: .day, value: 12, to: Date()) ?? Date()
            let day = d.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased()
            return paper(["BOOK SWAP NIGHT", "Bring a book, take a book", day, "6:30 PM - 9:00 PM", "Town Hall, 22 High Street"],
                         bg: UIColor(red: 1, green: 0.95, blue: 0.8, alpha: 1), font: { $0 == 0 ? .boldSystemFont(ofSize: 76) : .systemFont(ofSize: 48, weight: .semibold) }, gap: 130)
        case .priceCompare?:
            return paper(["Pasta, Brand A", "500 g", "$2.49", "", "Pasta, Brand B", "1 kg", "$3.99"], gap: 100)
        case .actionItems?:
            return paper(["TEAM TO-DO", "Sam: send the budget by Friday", "Jo: book the venue on Monday", "Kim: order the snacks", "Lee: print 20 name badges"],
                         font: { $0 == 0 ? .boldSystemFont(ofSize: 60) : .systemFont(ofSize: 44) }, gap: 110)
        case .wifiQr?:
            return paper(["FREE WIFI", "Network: CafeGuest", "Password: latte2026"], size: CGSize(width: 1000, height: 600),
                         font: { $0 == 0 ? .boldSystemFont(ofSize: 70) : .systemFont(ofSize: 52, weight: .semibold) }, gap: 120)
        case .returnBy?:
            // Bought a few days ago, so the return window is still open.
            let d = Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date()
            let f = DateFormatter(); f.dateFormat = "MM/dd/yyyy h:mm a"; f.locale = Locale(identifier: "en_US_POSIX")
            return paper(["HARBOR HOME GOODS", "18 Lake Ave, Naperville IL", f.string(from: d), "", "Table lamp           34.99", "Bulb 2-pack           6.50",
                          "", "Subtotal             41.49", "Tax                   3.11", "Total                44.60", "", "Returns within 30 days with receipt"],
                         size: CGSize(width: 900, height: 1300), font: { _ in .monospacedSystemFont(ofSize: 38, weight: .medium) }, gap: 84)
        default:
            return receipt()
        }
    }

    static func receipt() -> UIImage {
        let lines = ["BLUE BOTTLE COFFEE", "300 Webster St, Oakland CA", "03/14/2026 8:41 AM", "", "Cappuccino            4.75", "Almond Croissant      5.25", "Oat milk              0.75", "", "Subtotal             10.75", "Tax                   0.97", "Tip                   2.00", "Total                13.72", "", "VISA ****4421", "Thank you for visiting!"]
        let size = CGSize(width: 900, height: 1500)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { c in
            UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
            for (i, l) in lines.enumerated() {
                (l as NSString).draw(at: CGPoint(x: 80, y: 120 + CGFloat(i) * 84), withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 40, weight: .medium), .foregroundColor: UIColor.black])
            }
        }
    }

    static func document() -> UIImage {
        let size = CGSize(width: 1240, height: 1754)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { c in
            UIColor(white: 0.97, alpha: 1).setFill(); c.fill(CGRect(origin: .zero, size: size))
            ("RENTAL AGREEMENT" as NSString).draw(at: CGPoint(x: 120, y: 140), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 56), .foregroundColor: UIColor.black])
            let body = "Tenant shall indemnify and hold harmless the Landlord.\nThis Agreement shall automatically renew unless 60 days notice is given.\nAll disputes are subject to binding arbitration.\nSigned: ______________________   Date: ____________"
            body.draw(in: CGRect(x: 120, y: 260, width: 1000, height: 1300), withAttributes: [.font: UIFont.systemFont(ofSize: 36), .foregroundColor: UIColor.black])
        }
    }

    /// A 3-second H.264 movie with moving colour so compression tests mean something. Silent by default (unit tests
    /// rely on that); `withSound` adds a real AAC tone track, so a "remove the sound" check has something to remove.
    static func movie(seconds: Double = 2.5, size: CGSize = CGSize(width: 640, height: 360), withSound: Bool = false) async -> URL? {
        guard let silent = await silentMovie(seconds: seconds, size: size) else { return nil }
        guard withSound else { return silent }
        return await addTone(to: silent, seconds: seconds) ?? silent
    }

    /// The silent movie plus the sample tone as its sound track (named "sample-…" like every sample input).
    private static func addTone(to video: URL, seconds: Double) async -> URL? {
        let tmp = FileManager.default.temporaryDirectory
        let wav = tmp.appendingPathComponent("sample-tone-\(UUID().uuidString.prefix(6)).wav")
        guard (try? tone(seconds: seconds).write(to: wav)) != nil else { return nil }
        let v = AVURLAsset(url: video), a = AVURLAsset(url: wav)
        guard let vt = try? await v.loadTracks(withMediaType: .video).first,
              let at = try? await a.loadTracks(withMediaType: .audio).first,
              let vd = try? await v.load(.duration), let ad = try? await a.load(.duration) else { return nil }
        let comp = AVMutableComposition()
        guard let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let ca = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
              (try? cv.insertTimeRange(CMTimeRange(start: .zero, duration: vd), of: vt, at: .zero)) != nil,
              (try? ca.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(vd, ad)), of: at, at: .zero)) != nil,
              let s = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let out = tmp.appendingPathComponent("sample-\(UUID().uuidString.prefix(6)).mov")
        do { try await s.export(to: out, as: .mov) } catch { return nil }
        try? FileManager.default.removeItem(at: wav)
        try? FileManager.default.removeItem(at: video)   // only the input with sound is left, so testers check the right file
        return FileManager.default.fileExists(atPath: out.path) ? out : nil
    }

    private static func silentMovie(seconds: Double, size: CGSize) async -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sample-\(UUID().uuidString.prefix(6)).mov")
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return nil }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height), AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000]])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: Int(size.width), kCVPixelBufferHeightKey as String: Int(size.height)])
        writer.add(input)
        guard writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)
        let fps: Int32 = 24, frames = Int(seconds * Double(fps))
        for i in 0..<frames {
            while !input.isReadyForMoreMediaData { try? await Task.sleep(nanoseconds: 5_000_000) }
            guard let pool = adaptor.pixelBufferPool else { return nil }
            var pb: CVPixelBuffer?; CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
            guard let buf = pb else { return nil }
            CVPixelBufferLockBaseAddress(buf, [])
            if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
                let t = CGFloat(i) / CGFloat(frames)
                ctx.setFillColor(UIColor(hue: t, saturation: 0.6, brightness: 0.9, alpha: 1).cgColor); ctx.fill(CGRect(origin: .zero, size: size))
                for k in 0..<40 {
                    ctx.setFillColor(UIColor(hue: CGFloat(k) / 40, saturation: 0.9, brightness: 1, alpha: 1).cgColor)
                    let x = (CGFloat(k) * 97 + t * size.width * 2).truncatingRemainder(dividingBy: size.width)
                    ctx.fillEllipse(in: CGRect(x: x, y: CGFloat(k % 8) * size.height / 8 + 20, width: 90, height: 90))
                }
            }
            CVPixelBufferUnlockBaseAddress(buf, [])
            adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
        }
        input.markAsFinished()
        await writer.finishWriting()
        return writer.status == .completed ? url : nil
    }

    /// The photo as a phone camera saves it: JPEG with where (near Chicago) and when it was taken in its EXIF —
    /// so a "remove the location" step is tested on a photo that really has one.
    static func jpegWithLocation(_ img: UIImage, quality: CGFloat = 0.9) -> Data? {
        guard let cg = img.cgImage else { return img.jpegData(compressionQuality: quality) }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        let when = "2026:11:10 10:21:00"
        let props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Apple", kCGImagePropertyTIFFModel: "iPhone", kCGImagePropertyTIFFDateTime: when],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: when],
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 41.8781, kCGImagePropertyGPSLatitudeRef: "N",
                                            kCGImagePropertyGPSLongitude: 87.6298, kCGImagePropertyGPSLongitudeRef: "W",
                                            kCGImagePropertyGPSAltitude: 181.0],
        ]
        CGImageDestinationAddImage(dest, cg, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        // a copy of exactly what went in, so a tester can confirm the input really had a location
        try? (out as Data).write(to: FileManager.default.temporaryDirectory.appendingPathComponent("sample-photo-\(UUID().uuidString.prefix(6)).jpg"))
        return out as Data
    }

    static func jpegURL(_ img: UIImage, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name).appendingPathExtension("jpg")
        guard let d = img.jpegData(compressionQuality: 0.9), (try? d.write(to: url)) != nil else { return nil }
        return url
    }

    /// A two-page PDF with real, selectable text (a small invoice and its terms) — the stand-in for a picked PDF.
    static func pdf() -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { c in
            let h = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 26), .foregroundColor: UIColor.black]
            let b = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.black]
            c.beginPage()
            ("INVOICE 1042" as NSString).draw(at: CGPoint(x: 60, y: 60), withAttributes: h)
            ("Bill to: Rivera Design LLC, 88 Oak Lane, Austin TX 78701\nDate: 14 March 2026   Due: 13 April 2026" as NSString)
                .draw(in: CGRect(x: 60, y: 110, width: 492, height: 60), withAttributes: b)
            // The items as a real table: each cell in its own column.
            let th = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: UIColor.black]
            let rows = [["Item", "Qty", "Price"], ["Logo design", "1", "450.00"], ["Business cards", "2", "38.00"],
                        ["Website banner", "1", "120.00"], ["Total", "", "646.00"]]
            for (r, row) in rows.enumerated() {
                for (c, cell) in row.enumerated() {
                    (cell as NSString).draw(at: CGPoint(x: [60, 330, 450][c], y: 200 + CGFloat(r) * 28), withAttributes: r == 0 ? th : b)
                }
            }
            ("Questions: billing@example.com or +1 512 555 0199" as NSString).draw(at: CGPoint(x: 60, y: 360), withAttributes: b)
            c.beginPage()
            ("TERMS" as NSString).draw(at: CGPoint(x: 60, y: 60), withAttributes: h)
            ("Payment is due within 30 days. A late fee of 2% a month applies after the due date.\nAll work stays the property of the designer until paid in full.\nThis agreement renews each year unless either side gives 60 days written notice." as NSString)
                .draw(in: CGRect(x: 60, y: 110, width: 492, height: 600), withAttributes: b)
        }
    }

    /// A 2-second rising tone with a little wobble, as a plain WAV — a stand-in recording for voice tools in UI tests.
    static func tone(seconds: Double = 2) -> Data {
        let rate = 44_100, n = Int(Double(rate) * seconds)
        var samples = [UInt8](); samples.reserveCapacity(n * 2)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / Double(rate)
            let f = 220 + 220 * t / seconds + 12 * sin(2 * .pi * 5 * t)
            phase += 2 * .pi * f / Double(rate)
            let v = Int16(max(-32767, min(32767, sin(phase) * 12_000)))
            samples.append(UInt8(truncatingIfNeeded: v)); samples.append(UInt8(truncatingIfNeeded: v >> 8))
        }
        return Data(ChainText.wavHeader(sampleRate: rate, channels: 1, dataBytes: samples.count) + samples)
    }
}
