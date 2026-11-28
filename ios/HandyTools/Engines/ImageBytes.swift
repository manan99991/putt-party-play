import UIKit

/// A picture's JPEG / PNG bytes, made once per picture. Result screens used to call `jpegData` / `pngData` inside a
/// view's body, re-encoding a full-size photo on every redraw (opening or closing the Share sheet redraws). The
/// bytes are kept only while the picture itself is alive.
enum ImageBytes {
    private static let jpegs = NSMapTable<UIImage, NSData>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    private static let pngs = NSMapTable<UIImage, NSData>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    private static let lock = NSLock()

    static func jpeg(_ image: UIImage, quality: CGFloat = 0.92) -> Data? {
        lock.lock(); defer { lock.unlock() }
        if let d = jpegs.object(forKey: image) { return d as Data }
        guard let d = image.jpegData(compressionQuality: quality) else { return nil }
        jpegs.setObject(d as NSData, forKey: image)
        return d
    }

    static func png(_ image: UIImage) -> Data? {
        lock.lock(); defer { lock.unlock() }
        if let d = pngs.object(forKey: image) { return d as Data }
        guard let d = image.pngData() else { return nil }
        pngs.setObject(d as NSData, forKey: image)
        return d
    }
}
