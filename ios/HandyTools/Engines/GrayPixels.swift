import CoreGraphics

/// A small grayscale copy of any image, for measuring (brightness, sharpness, look-alike hashes).
/// Drawn through an 8-bit RGBA context and converted to luma by hand: an 8-bit *gray* context silently
/// draws nothing for some sources (extended-range / 16-bit images, e.g. HDR photos), leaving all zeros.
enum GrayPixels {
    /// `w`×`h` luma bytes, top row first. nil if the context couldn't be made.
    static func read(_ cg: CGImage, w: Int, h: Int, quality: CGInterpolationQuality = .default) -> [UInt8]? {
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let ok = rgba.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = quality
            ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)       // see-through areas read as white paper
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        var out = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) {
            let r = Int(rgba[i * 4]), g = Int(rgba[i * 4 + 1]), b = Int(rgba[i * 4 + 2])
            out[i] = UInt8((r * 299 + g * 587 + b * 114) / 1000)
        }
        return out
    }
}
