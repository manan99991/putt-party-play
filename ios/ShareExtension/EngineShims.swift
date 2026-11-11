import UIKit
import AVFoundation

// The share sheet runs photo and text tools only. The engines it borrows from the app mention two video helpers
// and one image helper that live in app-only files, so they get small stand-ins here. Video tools are never offered
// in the share sheet, so the video stand-in is never reached.

enum VideoEngine {
    static func tempURL(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
    }
    static func transcodeH264(_ asset: AVAsset, maxDimension: CGFloat? = nil, videoBps: Int? = nil,
                              timeout: TimeInterval = 180, progress: ((Double) -> Void)? = nil) async -> URL? { nil }
}

extension UIImage {
    /// Redraws the image so its pixels are upright (same as the app's helper).
    func normalizedUp() -> UIImage {
        if imageOrientation == .up { return self }
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = scale
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}
