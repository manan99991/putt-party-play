import XCTest
import Photos
import AVFoundation
@testable import HandyTools

/// Copies are found anywhere in the library (26 Nov). Manan cleared duplicates, then found two 31.1 MB copies of the
/// same clip by eye: the check only looked at the newest 500 items, so an older pair was never compared. Now every photo
/// and video is checked; these prove the matching finds twins wherever they sit, and nothing else.
final class CleanerDuplicatesTests: XCTestCase {
    typealias P = PhotoCleaner

    private static func next(_ s: inout UInt64) -> UInt64 {   // splitmix64: repeatable "random" hashes
        s &+= 0x9E3779B97F4A7C15
        var z = s; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    func testTwinHashesAreFoundAnywhereAndNothingElse() {
        var s: UInt64 = 42
        var hashes = (0..<3000).map { _ in (Self.next(&s), Self.next(&s)) }
        hashes[2900] = hashes[7]                                          // an exact copy, far down the library
        var near = hashes[1500]; near.0 ^= 0b1011; near.1 ^= 1 << 40       // 4 bits apart: a re-saved copy
        hashes[2999] = near
        var far = hashes[600]; for b in 0..<11 { far.0 ^= 1 << UInt64(b * 5) }   // 11 bits apart: past the line
        hashes[2998] = far
        let pairs = P.nearHashPairs(hashes, within: 10).map { "\($0.0)-\($0.1)" }
        XCTAssertEqual(pairs, ["7-2900", "1500-2999"], "the two copies, and not the one 11 bits off or any unrelated photo")

        // The slice shortcut gives exactly what comparing every pair would.
        var small = Array(hashes.prefix(300)) + [hashes[7], near, far]
        small[299] = small[12]; small[298].1 ^= 1 << 63
        var brute: [String] = []
        for i in 0..<small.count { for j in (i + 1)..<small.count where P.hamming(small[i], small[j]) <= 10 { brute.append("\(i)-\(j)") } }
        XCTAssertEqual(P.nearHashPairs(small, within: 10).map { "\($0.0)-\($0.1)" }, brute)
        XCTAssertFalse(brute.isEmpty)
    }

    func testOnlyClipsTheSameLengthAreCompared() {
        // Lengths 10% apart never pair (the line is a second, or 8% of the longer clip).
        var lengths = (0..<200).map { 20 * pow(1.1, Double($0)) }
        lengths[150] = lengths[3]               // a copy of an early clip, far down the list
        lengths[199] = lengths[100] + 0.4       // a copy that came out a hair longer
        lengths[0] = 0; lengths[1] = 0          // unreadable clips are left out, not paired with each other
        XCTAssertEqual(P.sameLengthPairs(lengths).map { "\($0.0)-\($0.1)" }, ["3-150", "100-199"])
        XCTAssertEqual(P.sameLengthPairs([31.2, 31.2]).map { "\($0.0)-\($0.1)" }, ["0-1"], "Manan's two 31.1 MB clips")
        XCTAssertTrue(P.sameLengthPairs([8, 9.5]).isEmpty, "a 1.5-second difference on short clips isn't a copy")
    }

    func testGroupsAreOneItemAndItsTwinsNotChains() {
        let g = P.seededGroups(count: 10, matches: [(0, 5), (9, 0), (5, 9), (2, 3), (3, 7)])
        XCTAssertEqual(g, [[0, 5, 9], [2, 3]], "7 looks like 3, not like 2, so it isn't pulled into 2's group")
        XCTAssertTrue(P.seededGroups(count: 3, matches: []).isEmpty)
    }

    func testTheSavedIndexOnlyTrustsAnUneditedPhoto() {
        var i = P.DupHashIndex()
        i.set("a", modified: 100, hash: (1, 2))
        XCTAssertEqual(i.hash("a", modified: 100).map { [$0.0, $0.1] }, [1, 2])
        XCTAssertNil(i.hash("a", modified: 101), "an edited photo is read again")
        XCTAssertNil(i.hash("b", modified: 100))
        i.keepOnly(["b"])
        XCTAssertNil(i.hash("a", modified: 100), "a deleted photo is forgotten")
    }

    // MARK: the real thing, in the simulator's photo library

    /// Two copies of an older clip, behind more than 500 newer photos — the case that was missed — are found as one
    /// group, and none of the 520 newer (all different) photos is called a copy.
    func testTwoCopiesOfAnOlderClipBehind500NewerPhotosAreFound() async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        XCTAssertEqual(status, .authorized, "the test simulator grants photo access (ios.yml)")
        guard status == .authorized else { return }
        let base = Date(timeIntervalSince1970: 1_717_200_000)        // June 2024
        let clip = try await makeClip()
        defer { try? FileManager.default.removeItem(at: clip) }
        try await PHPhotoLibrary.shared().performChanges {
            for k in 0..<2 {
                let r = PHAssetCreationRequest.forAsset()
                r.addResource(with: .video, fileURL: clip, options: nil)
                r.creationDate = base.addingTimeInterval(Double(k) * 60)
            }
        }
        try await PHPhotoLibrary.shared().performChanges {
            for i in 0..<520 {
                let r = PHAssetChangeRequest.creationRequestForAsset(from: Self.noise(i))
                r.creationDate = base.addingTimeInterval(30 * 86_400 + Double(i) * 600)   // a month later, all newer
            }
        }
        func ids(_ type: PHAssetMediaType, from: Date, to: Date) -> Set<String> {
            let o = PHFetchOptions(); o.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", from as NSDate, to as NSDate)
            var out = Set<String>(); PHAsset.fetchAssets(with: type, options: o).enumerateObjects { a, _, _ in out.insert(a.localIdentifier) }
            return out
        }
        let copies = ids(.video, from: base, to: base.addingTimeInterval(61))
        let newer = ids(.image, from: base.addingTimeInterval(30 * 86_400), to: base.addingTimeInterval(30 * 86_400 + 520 * 600))
        XCTAssertEqual(copies.count, 2); XCTAssertEqual(newer.count, 520)

        // The case really is "behind the newest 500".
        let o = PHFetchOptions(); o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        var position = 0, firstCopy = -1
        PHAsset.fetchAssets(with: o).enumerateObjects { a, _, stop in
            if copies.contains(a.localIdentifier) { firstCopy = position; stop.pointee = true }
            position += 1
        }
        XCTAssertGreaterThan(firstCopy, 500, "the copies sit behind more than 500 newer items")

        let found = await P.duplicates { _ in }
        let group = found.groups.first { Set($0.map(\.id)).isSuperset(of: copies) }
        XCTAssertNotNil(group, "the two copies are one group — \(found.groups.count) groups, \(found.skipped) not checked, \(found.photos) photos, \(found.videos) videos")
        XCTAssertFalse(found.groups.contains { g in g.contains { newer.contains($0.id) } }, "no different photo is called a copy")
        XCTAssertGreaterThanOrEqual(found.photos, 520); XCTAssertGreaterThanOrEqual(found.videos, 2)
        XCTAssertTrue(P.DupHashIndex.exists, "the photo hashes are kept, so the next check reads only new photos")

        // The second check reads from the saved index and finds the same.
        let again = await P.duplicates { _ in }
        XCTAssertNotNil(again.groups.first { Set($0.map(\.id)).isSuperset(of: copies) })
        XCTAssertEqual(again.photos, found.photos)
    }

    /// A different picture each time: 8×8 blocks of grey picked by the seed.
    private static func noise(_ seed: Int) -> UIImage {
        var s = UInt64(seed) &* 7919 &+ 1
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: f).image { c in
            for y in 0..<8 { for x in 0..<8 {
                UIColor(white: CGFloat(next(&s) % 256) / 255, alpha: 1).setFill()
                c.fill(CGRect(x: x * 8, y: y * 8, width: 8, height: 8))
            } }
        }
    }

    /// A 2-second clip with something moving.
    private func makeClip() async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dup-\(UUID().uuidString).mp4")
        let w = 640, h = 360, frames = 60
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h])
        writer.add(input)
        XCTAssertTrue(writer.startWriting()); writer.startSession(atSourceTime: .zero)
        for i in 0..<frames {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 2_000_000) }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
            let buf = try XCTUnwrap(pb)
            CVPixelBufferLockBaseAddress(buf, [])
            let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: w, height: h, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buf),
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
            ctx.setFillColor(UIColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1).cgColor); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.setFillColor(UIColor.brown.cgColor); ctx.fill(CGRect(x: 200 + i * 2, y: 60, width: 90, height: 240))
            CVPixelBufferUnlockBaseAddress(buf, [])
            adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWriting()
        return url
    }
}
