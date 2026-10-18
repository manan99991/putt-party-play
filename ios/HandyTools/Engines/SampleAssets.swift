import UIKit
import AVFoundation

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

    /// A 3-second silent H.264 movie with moving colour so compression tests mean something.
    static func movie(seconds: Double = 3, size: CGSize = CGSize(width: 1280, height: 720)) async -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sample-\(UUID().uuidString.prefix(6)).mov")
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return nil }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height), AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000]])
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

    static func jpegURL(_ img: UIImage, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name).appendingPathExtension("jpg")
        guard let d = img.jpegData(compressionQuality: 0.9), (try? d.write(to: url)) != nil else { return nil }
        return url
    }
}
