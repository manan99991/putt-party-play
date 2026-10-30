import Foundation
import Photos
import UIKit
import Contacts

/// Extras the Clean Up hub needs on top of PhotoCleaner / ContactsEngine: device storage numbers,
/// a blurry-or-dark photo scan (Laplacian variance + mean brightness on a 64 px thumbnail), the
/// contact-source map, and deleting empty contacts. All on-device.
enum CleanupKit {

    // MARK: storage

    /// (used, total) bytes for the device volume — what Settings › Storage shows, give or take.
    static func storage() -> (used: Int64, total: Int64)? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let v = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]),
              let total = v.volumeTotalCapacity, let avail = v.volumeAvailableCapacityForImportantUsage, total > 0 else { return nil }
        return (max(0, Int64(total) - avail), Int64(total))
    }

    // MARK: blurry & dark

    /// Recent camera photos that are soft (low Laplacian variance) or very dark (low mean luma).
    /// Screenshots are skipped (flat UI reads as "blurry"). iCloud-only photos are skipped too —
    /// network stays off so the scan is quick. `progress` is 0…1.
    static func blurryOrDark(scanLimit: Int = 400, progress: @escaping (Double) -> Void) -> [PhotoCleaner.Item] {
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "(mediaSubtype & %d) == 0", Int(PHAssetMediaSubtype.photoScreenshot.rawValue))
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        o.fetchLimit = scanLimit
        var assets: [PHAsset] = []
        PHAsset.fetchAssets(with: .image, options: o).enumerateObjects { a, _, _ in assets.append(a) }
        guard !assets.isEmpty else { progress(1); return [] }

        let mgr = PHImageManager.default()
        let req = PHImageRequestOptions()
        req.isSynchronous = true; req.deliveryMode = .fastFormat; req.resizeMode = .fast; req.isNetworkAccessAllowed = false
        var out: [PhotoCleaner.Item] = []
        for (i, a) in assets.enumerated() {
            if i % 10 == 0 { progress(Double(i) / Double(assets.count)) }
            var image: UIImage?
            mgr.requestImage(for: a, targetSize: CGSize(width: 96, height: 96), contentMode: .aspectFit, options: req) { im, _ in image = im }
            guard let cg = image?.cgImage, let s = sharpness(cg) else { continue }
            if s.variance < 18 || s.mean < 38 { out.append(PhotoCleaner.Item(asset: a, bytes: PhotoCleaner.estimatedBytes(of: a))) }
        }
        progress(1)
        return out
    }

    /// Laplacian variance (focus measure) and mean brightness over a 64×64 grey render.
    static func sharpness(_ cg: CGImage) -> (variance: Double, mean: Double)? {
        let w = 64, h = 64
        var px = [UInt8](repeating: 0, count: w * h)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var sum = 0.0, sumSq = 0.0, lum = 0.0
        var n = 0
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let c = Double(px[y * w + x])
                let lap = Double(px[(y - 1) * w + x]) + Double(px[(y + 1) * w + x]) + Double(px[y * w + x - 1]) + Double(px[y * w + x + 1]) - 4 * c
                sum += lap; sumSq += lap * lap; lum += c; n += 1
            }
        }
        guard n > 0 else { return nil }
        let meanLap = sum / Double(n)
        return (sumSq / Double(n) - meanLap * meanLap, lum / Double(n))
    }

    // MARK: contacts

    /// Contact identifier → where it lives ("iCloud", "Gmail", "Exchange", …), from the account containers.
    static func contactSources() -> [String: String] {
        let store = CNContactStore()
        var map: [String: String] = [:]
        guard let containers = try? store.containers(matching: nil) else { return map }
        for c in containers {
            let name = c.name.isEmpty ? (c.type == .cardDAV ? "iCloud" : c.type == .exchange ? "Exchange" : c.type == .local ? "Phone" : "Account") : c.name
            let pred = CNContact.predicateForContactsInContainer(withIdentifier: c.identifier)
            if let found = try? store.unifiedContacts(matching: pred, keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]) {
                for f in found { map[f.identifier] = name }
            }
        }
        return map
    }

    /// Contacts with no name, no number and no email — nothing to lose by removing them.
    static func emptyContacts(_ report: ContactsReport) -> [ContactRec] {
        report.incomplete.filter { !$0.hasName && !$0.hasNumber && $0.emails.isEmpty }
    }

    /// Delete contacts by identifier. Permanent (iOS has no contacts trash) — the hub backs up first.
    static func deleteContacts(ids: [String]) throws {
        let store = CNContactStore()
        let save = CNSaveRequest()
        var any = false
        for id in ids {
            guard let c = try? store.unifiedContact(withIdentifier: id, keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]),
                  let m = c.mutableCopy() as? CNMutableContact else { continue }
            save.delete(m); any = true
        }
        if any { try store.execute(save) }
    }
}
