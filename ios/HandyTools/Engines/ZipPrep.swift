import Foundation
import UIKit
import UniformTypeIdentifiers

/// Getting photos ready before they're zipped: smaller for email (long side 2560 px, good JPEG) and/or
/// without where they were taken. Re-encoding as JPEG drops the location and camera details. Pure parts
/// unit-tested.
enum ZipPrep {
    static let emailLimit = 25 * 1_000_000      // what most email services accept

    static func isPhoto(_ name: String) -> Bool {
        guard let t = UTType(filenameExtension: (name as NSString).pathExtension.lowercased()) else { return false }
        return t.conforms(to: .image) && !t.conforms(to: .gif)   // a GIF would lose its animation
    }

    /// "IMG_0042.HEIC" → "IMG_0042.jpg" once it's re-saved as a JPEG.
    static func jpegName(_ name: String) -> String {
        ((name as NSString).deletingPathExtension.isEmpty ? "Photo" : (name as NSString).deletingPathExtension) + ".jpg"
    }

    /// The photo again as a JPEG — shrunk when asked — with no location or camera details. nil keeps the original.
    static func prepared(_ data: Data, shrink: Bool) -> Data? {
        guard let img = UIImage(data: data) else { return nil }
        let out = shrink ? img.resized(maxDimension: 2560) : img
        return out.jpegData(compressionQuality: shrink ? 0.72 : 0.92)
    }

    /// Plain words about the size against the email limit.
    static func emailNote(bytes: Int) -> String? {
        bytes > emailLimit ? "Over 25 MB — too big for most email. Turn on Make photos smaller, or send it through a link (iCloud, Drive)." : nil
    }
}
